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
/// - Does NOT make routing decisions - that stays in AudioPlayer (Bridge layer)
@MainActor
@Observable
final class VideoPlaybackController {
    // MARK: - AVPlayer State

    /// The underlying AVPlayer instance for video playback
    @ObservationIgnored private(set) var player: AVPlayer?

    /// Formatted metadata string for display (codec, resolution, etc.)
    private(set) var metadataString: String = ""

    // MARK: - Observer Management
    // Note: nonisolated(unsafe) allows deinit to access these for cleanup
    // Safe because at deinit time there are no concurrent references

    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
    @ObservationIgnored nonisolated(unsafe) private var _playerForCleanup: AVPlayer?

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

    deinit {
        // Ensure observers are removed when controller is deallocated
        // Note: Using nonisolated(unsafe) properties directly since deinit is nonisolated
        // and we cannot call @MainActor cleanup() from here

        // Remove time observer
        if let observer = timeObserver, let player = _playerForCleanup {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil

        // Remove notification observer
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endObserver = nil

        // Pause player for clean shutdown
        _playerForCleanup?.pause()
        _playerForCleanup = nil
    }

    // MARK: - Video Loading

    /// Load and prepare a video file for playback
    /// - Parameters:
    ///   - url: URL of the video file
    ///   - autoPlay: Whether to start playback immediately (default: true)
    func loadVideo(url: URL, autoPlay: Bool = true) {
        // Clean up any existing video player
        cleanup()

        // Create video player
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        _playerForCleanup = newPlayer  // Keep in sync for deinit access
        player?.volume = volume

        // Observe video completion
        if let playerItem = player?.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handlePlaybackEnded()
                }
            }
        }

        // Setup time observer BEFORE play
        setupTimeObserver()

        // Start video playback if autoPlay
        if autoPlay {
            player?.play()
            isPlaying = true
            isPaused = false
        }

        AppLog.debug(.audio, "VideoPlaybackController: Loading video file: \(url.lastPathComponent)")

        // Extract and format video metadata for display (cancellable to prevent race conditions)
        metadataTask = Task { @MainActor in
            let metadata = await MetadataLoader.loadVideoMetadata(from: url)
            guard !Task.isCancelled else { return }  // Prevent stale metadata from overwriting
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

        let shouldPlay = resume ?? isPlaying

        let timescale = player.currentItem?.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
        let targetTime = CMTime(seconds: max(0, time), preferredTimescale: timescale)

        // Use default tolerance (not .zero) to allow seeking to nearest keyframe
        // This is MUCH faster and avoids -12860 errors from trying to decode exact frames
        player.seek(to: targetTime) { [weak self] finished in
            Task { @MainActor in
                guard let self, finished else { return }

                // Update to actual seek position (may differ slightly from requested)
                let actualTime = player.currentTime().seconds
                self.currentTime = actualTime

                if let dur = player.currentItem?.duration.seconds, dur.isFinite {
                    self.duration = dur
                    self.progress = dur > 0 ? actualTime / dur : 0
                }

                if shouldPlay {
                    player.play()
                    self.isPlaying = true
                    self.isPaused = false
                } else {
                    player.pause()
                    self.isPlaying = false
                    self.isPaused = true
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
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                self.currentTime = seconds

                if let item = player.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite {
                        self.duration = dur
                        self.progress = dur > 0 ? seconds / dur : 0

                        // Notify AudioPlayer to sync its UI-bound properties
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
        _playerForCleanup = nil  // Keep in sync

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
