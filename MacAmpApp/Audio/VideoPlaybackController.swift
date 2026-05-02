import AVFoundation
import Observation

/// Manages AVPlayer-based video playback with proper observer lifecycle.
/// Extracted from AudioPlayer for single responsibility and cleaner separation.
///
/// **Layer:** Mechanism (AVPlayer wrapper)
/// **Responsibilities:**
/// - Owns AVPlayer lifecycle and observer cleanup
/// - Manages video playback state (play, pause, seek)
/// - Provides callbacks for playback events (ended, time updates)
/// - Does NOT make routing decisions - that stays in AudioPlayer (Mechanism layer)
@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - AVPlayer State

    /// The underlying AVPlayer instance for video playback
    @ObservationIgnored private(set) var player: AVPlayer?

    /// Formatted metadata string for display (codec, resolution, etc.)
    private(set) var metadataString: String = ""

    // MARK: - Observer Management

    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var timeObserver: Any?

    /// Task for async metadata loading (cancelled on cleanup to prevent race conditions)
    @ObservationIgnored private var metadataTask: Task<Void, Never>?

    // MARK: - Playback State (for AudioPlayer sync)

    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var progress: Double = 0

    // MARK: - Volume Sync

    /// Volume level (0.0 to 1.0), synced from AudioPlayer
    var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }

    // MARK: - Callbacks

    /// Called when video playback reaches end
    var onPlaybackEnded: (() -> Void)?

    /// Called periodically during playback with time updates (for UI sync)
    /// Parameters: currentTime, duration, progress
    var onTimeUpdate: ((Double, Double, Double) -> Void)?

    // MARK: - Initialization

    init() {}

    isolated deinit {
        // isolated deinit runs on @MainActor — safe to access all properties directly
        metadataTask?.cancel()
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
    }

    // MARK: - Video Loading

    /// Load and prepare a video file for playback.
    ///
    /// `audioMixBuilder`, when supplied, is invoked AFTER the asset is
    /// constructed but BEFORE the `AVPlayerItem` is. This is the only
    /// way to satisfy ADR-7's "`audioMix` is set once before `play()`"
    /// invariant — assigning `audioMix` to an already-constructed
    /// `AVPlayerItem` (or while the surrounding `AVPlayer` is playing)
    /// counts as mid-playback mutation. Builder returns the configured
    /// mix or nil (for example: no audio track in the asset, or the
    /// caller has gone stale and wants to no-op the mix only).
    ///
    /// `isStillRelevant`, when supplied, is rechecked AFTER the
    /// builder returns and BEFORE any AVPlayerItem / AVPlayer /
    /// observer mutation. A `false` result aborts the load entirely —
    /// no player is constructed, no observers are installed, no state
    /// fields on this controller are mutated. Used by the caller's
    /// generation counter to short-circuit a load that has been
    /// superseded while its asset was loading. Distinguishing "stale"
    /// from "no mix" requires a separate signal; `nil` from the
    /// builder is reserved for the "build a player without a tap" path
    /// (no audio track or builder declined for a non-stale reason).
    func loadVideo(
        url: URL,
        autoPlay: Bool = true,
        audioMixBuilder: ((AVURLAsset) async -> AVMutableAudioMix?)? = nil,
        isStillRelevant: (() -> Bool)? = nil
    ) async {
        // Clean up any existing video player (pauses the outgoing
        // player; safe ordering for any audioMix that needs to be
        // released before the next item adopts it).
        cleanup()

        let asset = AVURLAsset(url: url)

        let audioMix: AVMutableAudioMix?
        if let audioMixBuilder {
            audioMix = await audioMixBuilder(asset)
        } else {
            audioMix = nil
        }

        // Stale-check after the audioMix builder's await but BEFORE any
        // observer/player mutation. Any audioMix that was built ends up
        // dropped here — the +1 retain inside `MTAudioProcessingTapCreate`
        // is balanced by the AVMutableAudioMix's deinit chain dropping
        // the tap, which fires `tapFinalize` and releases the Context.
        if let isStillRelevant, !isStillRelevant() {
            AppLog.debug(.audio, "VideoPlaybackController: load aborted (stale)")
            return
        }

        let playerItem = AVPlayerItem(asset: asset)
        if let audioMix {
            playerItem.audioMix = audioMix  // ADR-7: set ONCE, before AVPlayer exists.
        }

        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer
        player?.volume = volume

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self, weak playerItem] _ in
            Task { @MainActor in
                guard let self, let playerItem else { return }
                // Identity guard: if a superseding loadVideo has
                // replaced the active item, ignore this (stale)
                // end-of-stream notification.
                guard self.player?.currentItem === playerItem else { return }
                self.handlePlaybackEnded()
            }
        }

        setupTimeObserver()

        if autoPlay {
            player?.play()
            isPlaying = true
            isPaused = false
        }

        AppLog.debug(.audio, "VideoPlaybackController: Loading video file: \(url.lastPathComponent)")

        metadataTask = Task { @MainActor in
            let metadata = await MetadataLoader.loadVideoMetadata(from: url)
            guard !Task.isCancelled else { return }
            self.metadataString = metadata.displayString
        }
    }

    // MARK: - Playback Control

    func play() {
        guard let player else {
            AppLog.warn(.audio, "VideoPlaybackController: No video loaded to play")
            return
        }
        player.play()
        isPlaying = true
        isPaused = false
        AppLog.debug(.audio, "VideoPlaybackController: Play")
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isPaused = true
        AppLog.debug(.audio, "VideoPlaybackController: Pause")
    }

    func stop() {
        cleanup()  // cleanup() now resets all state
        AppLog.debug(.audio, "VideoPlaybackController: Stop")
    }

    // MARK: - Seeking

    /// Seek to a specific time
    /// - Parameters:
    ///   - time: Target time in seconds
    ///   - resume: Whether to resume playback after seek (nil = maintain current state)
    ///   - completion: Called when seek completes with actual seek position (must be @Sendable for Swift 6)
    func seek(to time: Double, resume: Bool?, completion: (@Sendable (Double) -> Void)? = nil) {
        guard let player else {
            AppLog.warn(.audio, "VideoPlaybackController: Cannot seek - no video loaded")
            return
        }

        // `resume: nil` means "maintain the user's current intent." We
        // re-evaluate that intent inside the completion (against
        // `self.isPlaying` / `self.isPaused`) so a pause issued during
        // the seek is honoured AND loaded-but-idle stays loaded-idle
        // (not converted to paused). `resume: true/false` is an
        // explicit user choice and overrides the implicit state.
        let explicitResume: Bool? = resume

        let timescale = player.currentItem?.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
        let targetTime = CMTime(seconds: max(0, time), preferredTimescale: timescale)

        // Use default tolerance (not .zero) to allow seeking to nearest keyframe
        // This is MUCH faster and avoids -12860 errors from trying to decode exact frames
        player.seek(to: targetTime) { [weak self, weak player] finished in
            Task { @MainActor in
                guard let self, let player, finished else { return }
                // Identity guard: a superseding `loadVideo` may have
                // replaced `self.player` while we were seeking. Ignore
                // the stale completion to avoid mutating transport
                // state for an old player.
                guard self.player === player else { return }

                let actualTime = player.currentTime().seconds
                self.currentTime = actualTime

                if let dur = player.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                    self.progress = dur > 0 ? actualTime / dur : 0
                }

                if let explicitResume {
                    // Explicit user choice — apply unambiguously.
                    if explicitResume {
                        player.play()
                        self.isPlaying = true
                        self.isPaused = false
                    } else {
                        player.pause()
                        self.isPlaying = false
                        self.isPaused = true
                    }
                } else {
                    // Implicit nil — preserve current intent. The
                    // distinction between "paused" (user-initiated) and
                    // "loaded-but-idle" (autoPlay=false, never started)
                    // matters; touch only `isPlaying` and leave
                    // `isPaused` as it was.
                    if self.isPlaying {
                        player.play()
                    } else {
                        player.pause()
                    }
                }

                completion?(actualTime)
            }
        }
        AppLog.debug(.audio, "VideoPlaybackController: Seek to \(time)s")
    }

    /// Seek to a percentage of the video (0.0 to 1.0)
    func seekToPercent(_ percent: Double, resume: Bool?, completion: (@Sendable (Double) -> Void)? = nil) {
        guard let player,
              let dur = player.currentItem?.duration.seconds,
              dur.isFinite else {
            AppLog.warn(.audio, "VideoPlaybackController: No video or invalid duration")
            return
        }
        let targetTime = percent * dur
        seek(to: targetTime, resume: resume, completion: completion)
    }

    // MARK: - Time Observer

    /// Setup periodic time observer for video playback
    private func setupTimeObserver() {
        tearDownTimeObserver()  // Clean first
        guard let player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self, weak player] time in
            Task { @MainActor in
                guard let self, let player else { return }
                // Identity guard: a superseding loadVideo may have
                // replaced `self.player` while this periodic tick was
                // queued. Ignore the stale callback.
                guard self.player === player else { return }
                let seconds = time.seconds
                self.currentTime = seconds

                if let item = player.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite {
                        self.duration = dur
                        self.progress = dur > 0 ? seconds / dur : 0
                        self.onTimeUpdate?(seconds, dur, self.progress)
                    }
                }
            }
        }
        AppLog.debug(.audio, "VideoPlaybackController: Time observer setup")
    }

    /// Teardown video time observer to prevent memory leaks
    private func tearDownTimeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
    }

    // MARK: - Cleanup

    /// Cleanup all video resources and reset state
    func cleanup() {
        // Cancel any in-flight metadata loading to prevent race conditions
        metadataTask?.cancel()
        metadataTask = nil

        tearDownTimeObserver()
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
        player = nil

        // Reset playback state to prevent stale values
        isPlaying = false
        isPaused = false
        currentTime = 0
        duration = 0
        progress = 0
        metadataString = ""

        AppLog.debug(.audio, "VideoPlaybackController: Cleanup complete")
    }

    // MARK: - Private

    private func handlePlaybackEnded() {
        isPlaying = false
        isPaused = false
        onPlaybackEnded?()
    }
}
