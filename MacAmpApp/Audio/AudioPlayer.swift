// swiftlint:disable file_length
import Foundation
import AVFoundation
import CoreAudio
import Observation
import os

@Observable
@MainActor
final class AudioPlayer { // swiftlint:disable:this type_body_length
    private enum Keys {
        static let volume = "volume"
        static let balance = "balance"
    }

    // MARK: - Engine Controller (owns AVAudioEngine, playerNode, graph wiring, stream bridge)
    @ObservationIgnored private var engine: AudioEngineController!

    // MARK: - Extracted Controllers
    private let equalizer = EqualizerController()
    private let visualizerPipeline = VisualizerPipeline()

    /// Legacy toggle - derives from AppSettings.visualizerMode (forwarded to pipeline)
    var useSpectrumVisualizer: Bool {
        get { AppSettings.instance().visualizerMode == .spectrum }
        set {
            AppSettings.instance().visualizerMode = newValue ? .spectrum : .none
            visualizerPipeline.useSpectrum = newValue
        }
    }

    /// Visualizer smoothing (forwarded to pipeline)
    var visualizerSmoothing: Float {
        get { visualizerPipeline.smoothing }
        set { visualizerPipeline.smoothing = newValue }
    }

    /// Visualizer peak falloff (forwarded to pipeline)
    var visualizerPeakFalloff: Float {
        get { visualizerPipeline.peakFalloff }
        set { visualizerPipeline.peakFalloff = newValue }
    }

    // MARK: - Playback State

    private(set) var playbackState: PlaybackState = .idle
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    @ObservationIgnored private var currentSeekID: UUID = UUID()
    @ObservationIgnored private var isHandlingCompletion = false
    @ObservationIgnored private var seekGuardActive = false
    @ObservationIgnored private var playlistGeneration: UInt64 = 0

    /// Snapshot captured by the engine config observer's onWill callback,
    /// consumed by the matching onDid callback. Carries the pre-rewire state
    /// AudioPlayer needs to decide whether to resume after the route change.
    /// nil except during the ~150 ms gap between will and did.
    @ObservationIgnored private var pendingReconfigureSnapshot: PreReconfigureSnapshot?

    /// Watchdog-suppression state. Decoupled into two fields so
    /// overlapping signals (engine reconfigure observer + HAL default-
    /// output property listener firing for the same route change) can
    /// max-coalesce their deadlines without one clobbering the other.
    ///
    /// `videoBurstGateOpen` is `true` between
    /// `handleEngineWillReconfigure` and `handleEngineDidReconfigure`.
    /// While true the watchdog is gated regardless of the finite
    /// deadline. The matching `did` clears it.
    ///
    /// `videoReconfigureGateUntilHost` is the finite deadline armed by
    /// `armVideoRouteChangeGate(seconds:)` (engine `did` settle window,
    /// HAL listener route-change gate). `max()` coalescing means a
    /// later-fired but-shorter signal can't shorten an earlier longer
    /// one.
    ///
    /// Watchdog gates while `videoBurstGateOpen || mach_absolute_time()
    /// < videoReconfigureGateUntilHost`. Both clear → watchdog runs
    /// normally.
    ///
    /// Why decoupled: `handleEngineWillReconfigure` previously set the
    /// deadline to `UInt64.max` to mean "burst open". A HAL listener
    /// arming `now + 5 s` BEFORE the engine `will` would then be lost
    /// when `did` overwrote the deadline with the 2 s settle window.
    /// Two fields preserves both signals.
    @ObservationIgnored private var videoBurstGateOpen: Bool = false
    @ObservationIgnored private var videoReconfigureGateUntilHost: UInt64 = 0

    /// Post-burst grace window (seconds). Watchdog stays gated this long
    /// after `handleEngineDidReconfigure` so HAL has time to stabilize
    /// before stall detection resumes.
    private static let videoReconfigureSettleSeconds: Double = 2.0

    /// Host-time stall threshold. The watchdog demotes the bridge if no
    /// tap callback fires within this window AND the AVPlayer side
    /// reports `isPlaying`. 3 s is calibrated to absorb HAL's typical
    /// 1.5–2.5 s route-transition tail without masking real tap deaths.
    private static let videoTapStallThresholdSeconds: Double = 3.0

    /// Bounded gate window armed by the HAL default-output property
    /// listener. Catches AirPlay/AirPods route changes that don't fire
    /// `AVAudioEngineConfigurationChange` (Apple's engine notification
    /// only fires when the engine's effective configuration actually
    /// changes — a same-format route swap doesn't qualify, but HAL still
    /// destabilizes the AVPlayer audio render thread).
    private static let videoRouteChangeGateSeconds: Double = 5.0

    /// Dedicated queue for the HAL default-output property listener.
    /// Retained for the lifetime of `halDefaultOutputListenerBlock` so
    /// `AudioObjectRemovePropertyListenerBlock` can match the install
    /// pair exactly at teardown.
    @ObservationIgnored private var halDefaultOutputListenerQueue: DispatchQueue?

    /// Listener block stored so removal is exact and deterministic. The
    /// HAL APIs require the same block instance passed to add() to be
    /// passed to remove(), or the removal silently no-ops.
    @ObservationIgnored private var halDefaultOutputListenerBlock: AudioObjectPropertyListenerBlock?
    var currentTrackURL: URL?
    var currentTitle: String = "No Track Loaded"
    var currentDuration: Double = 0.0
    var currentTime: Double = 0.0
    var playbackProgress: Double = 0.0

    // MARK: - Stream Bridge State (observable, updated via engine callback)
    private(set) var isBridgeActive: Bool = false

    // MARK: - Video Bridge State

    /// Tap currently routing video audio into the engine. nil when no video
    /// is playing or the tap attach failed (direct AVPlayer audio path).
    @ObservationIgnored private var videoAudioTap: VideoAudioTap?

    /// Ring buffer paired with `videoAudioTap` — kept here so AudioPlayer owns
    /// its lifetime alongside the tap and engine bridge activation.
    @ObservationIgnored private var videoRingBuffer: LockFreeRingBuffer?

    /// In-flight async setup for the current video track. Cancelled by
    /// teardown paths (stop, playTrack-switch, deinit) so a stale Task
    /// can't mutate AudioPlayer state or activate the bridge after the
    /// session has been replaced. Identity guards inside the Task body
    /// (`videoAudioTap === tap`) catch any race that slips past
    /// cancellation, including same-URL replay.
    @ObservationIgnored private var videoLoadTask: Task<Void, Never>?

    /// 250 ms watchdog observing `videoAudioTap` for stalls. Engages the
    /// AVPlayer fallback when the tap stops calling back beyond
    /// `videoTapStallThresholdSeconds` or signals `fallbackRequested`
    /// from a C-side prepare/process failure. Cancelled by
    /// `tearDownVideoBridge` and by the fallback itself (step 1).
    @ObservationIgnored private var videoTapWatchdogTask: Task<Void, Never>?

    /// True once the watchdog has demoted the video session to direct
    /// AVPlayer audio. Sticky for the current track; cleared at the start
    /// of the next `playTrack`. Observable so `PlaybackCoordinator`'s
    /// capability surface (Phase 6 §11.2) re-evaluates when it flips.
    private(set) var videoTapFallbackActive: Bool = false

    /// Observable mirror of `engine.isVideoBridgeActive`. SwiftUI consumers
    /// (capability surface, visualizer guards) need an Observation-tracked
    /// property; the engine itself is `@ObservationIgnored`. Updated via
    /// `engine.onVideoBridgeStateChanged` — parallel to the stream
    /// `isBridgeActive` mirror.
    private(set) var isVideoBridgeActive: Bool = false

    /// True when the audio engine is running AND producing audio output.
    var isEngineRendering: Bool {
        engine.isEngineRunning && (isPlaying || isBridgeActive || isVideoBridgeActive)
    }

    /// Audio volume (0.0-1.0 linear amplitude).
    ///
    /// Persistence is **call-site-driven** — call `commitVolumeToDefaults()`
    /// (or `PlaybackCoordinator.commitVolume()`) at gesture-end. The setter
    /// only propagates to audio backends; writing `UserDefaults` per gesture
    /// tick was shown to starve the main thread (mwvi Phase 0, Mechanism B).
    var volume: Float = 0.75 {
        didSet {
            engine?.setVolume(volume)
            // Forward to AVPlayer only while it's the audible path: a
            // video session WITHOUT an active engine bridge. That covers
            // tap-fallback (watchdog demoted us), tap attach-failure
            // (silent video / asset error), and engine activation
            // failure — all the paths where AVPlayer plays its own audio
            // direct. During an active bridge AVPlayer is muted and the
            // engine drives the signal; forwarding would double-stack.
            // Plan §11.6 specs `videoTapFallbackActive`; this gate is
            // strictly broader so the non-watchdog AVPlayer-audible
            // paths stay in sync.
            if currentMediaType == .video, engine?.isVideoBridgeActive != true {
                videoPlaybackController.volume = volume
            }
        }
    }
    /// Audio balance (-1.0 left to 1.0 right).
    ///
    /// Persistence is call-site-driven — see `commitBalanceToDefaults()` /
    /// `PlaybackCoordinator.commitBalance()`.
    var balance: Float = 0.0 {
        didSet {
            engine?.setBalance(balance)
        }
    }

    /// Commit the current `volume` to `UserDefaults`.
    /// Approved callers (plan §6.1): `PlaybackCoordinator.commitVolume()`.
    internal func commitVolumeToDefaults() {
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }

    /// Commit the current `balance` to `UserDefaults`.
    /// Approved callers (plan §6.1, mirrored per todo 1B.9):
    /// `PlaybackCoordinator.commitBalance()`.
    internal func commitBalanceToDefaults() {
        UserDefaults.standard.set(balance, forKey: Keys.balance)
    }

    // MARK: - Playlist (extracted to PlaylistController)

    let playlistController = PlaylistController()
    var playlist: [Track] { playlistController.playlist }
    var playlistPosition: Int? { playlistController.currentPosition }
    var playlistCount: Int { playlistController.count }
    var currentTrack: Track?
    var onTrackMetadataUpdate: ((Track) -> Void)?
    var onPlaylistAdvanceRequest: ((Track) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    /// Fired once at the end of an engine reconfigure burst, after AudioPlayer
    /// has re-applied volume/balance and rescheduled local-file playback.
    /// PlaybackCoordinator hooks this to refresh the stream-decode thread's
    /// audio IO workgroup, since the post-reconfigure outputNode may live on
    /// a different audio HAL device with a different real-time workgroup.
    var onEngineReconfigured: (() -> Void)?
    var shuffleEnabled: Bool {
        get { playlistController.shuffleEnabled }
        set { playlistController.shuffleEnabled = newValue }
    }

    // MARK: - Video (extracted to VideoPlaybackController)

    let videoPlaybackController = VideoPlaybackController()
    var currentMediaType: MediaType = .audio
    var videoPlayer: AVPlayer? { videoPlaybackController.player }
    var videoMetadataString: String { videoPlaybackController.metadataString }

    enum MediaType {
        case audio
        case video
    }

    /// Repeat mode (Winamp 5 Modern: off/all/one with "1" badge)
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }

    // MARK: - Equalizer Forwarding

    var preamp: Float {
        get { equalizer.preamp }
        set { equalizer.preamp = newValue }
    }
    var eqBands: [Float] {
        get { equalizer.eqBands }
        set { equalizer.eqBands = newValue }
    }
    var isEqOn: Bool {
        get { equalizer.isEqOn }
        set { equalizer.isEqOn = newValue }
    }
    var eqAutoEnabled: Bool {
        get { equalizer.eqAutoEnabled }
        set { equalizer.eqAutoEnabled = newValue }
    }
    var useLogScaleBands: Bool {
        get { equalizer.useLogScaleBands }
        set { equalizer.useLogScaleBands = newValue }
    }
    var eqPresetStore: EQPresetStore { equalizer.eqPresetStore }
    var userPresets: [EQPreset] { equalizer.userPresets }
    var visualizerLevels: [Float] { visualizerPipeline.levels }
    var appliedAutoPresetTrack: String? {
        get { equalizer.appliedAutoPresetTrack }
        set { equalizer.appliedAutoPresetTrack = newValue }
    }
    var channelCount: Int = 2
    var bitrate: Int = 0
    var sampleRate: Int = 0

    // MARK: - Init / Deinit

    init() {
        if let saved = UserDefaults.standard.object(forKey: Keys.volume) as? Float {
            self.volume = saved
        }
        if let saved = UserDefaults.standard.object(forKey: Keys.balance) as? Float {
            self.balance = saved
        }

        engine = AudioEngineController(eqNode: equalizer.eqNode, visualizerPipeline: visualizerPipeline)

        // Wire engine callbacks
        engine.onProgressUpdate = { [weak self] currentTime, progress in
            guard let self else { return }
            self.currentTime = currentTime
            if self.currentDuration > 0 {
                self.playbackProgress = progress
            } else {
                self.playbackProgress = 0
            }
        }
        engine.onPlaybackEnded = { [weak self] seekID in
            self?.onPlaybackEnded(fromSeekID: seekID)
        }
        engine.onBridgeStateChanged = { [weak self] isActive in
            self?.isBridgeActive = isActive
        }
        engine.onVideoBridgeStateChanged = { [weak self] isActive in
            self?.isVideoBridgeActive = isActive
        }
        engine.onEngineWillReconfigure = { [weak self] snapshot in
            self?.handleEngineWillReconfigure(snapshot: snapshot)
        }
        engine.onEngineDidReconfigure = { [weak self] in
            self?.handleEngineDidReconfigure()
        }

        // HAL-level default-output listener. Catches AirPlay/AirPods
        // route changes that AVAudioEngineConfigurationChange misses;
        // arms the watchdog gate so the bridge survives the multi-second
        // HAL transition window without false demotion.
        installHALDefaultOutputListener()

        // Apply restored volume/balance to engine nodes
        engine.setVolume(volume)
        engine.setBalance(balance)

        // Sync initial visualizer mode
        visualizerPipeline.useSpectrum = AppSettings.instance().visualizerMode == .spectrum

        // Setup video playback callbacks
        videoPlaybackController.onPlaybackEnded = { [weak self] in
            Task { @MainActor in
                self?.onPlaybackEnded()
            }
        }
        videoPlaybackController.onTimeUpdate = { [weak self] time, duration, progress in
            guard let self else { return }
            self.currentTime = time
            self.currentDuration = duration
            self.playbackProgress = progress
        }
        videoPlaybackController.volume = volume
    }

    isolated deinit {
        // Drop the HAL listener first so no late callback can hop to
        // MainActor and touch state mid-teardown.
        removeHALDefaultOutputListener()
        // Tear down the video bridge BEFORE engine.shutdown() so the
        // detachAudioTap audioMix=nil-before-detach ordering and the
        // videoLoadTask cancellation both run while the engine is still
        // alive. shutdown() drops the stream bridge.
        tearDownVideoBridge()
        engine.shutdown()
    }

    // MARK: - State Machine

    private func transition(to newState: PlaybackState) {
        guard playbackState != newState else { return }
        playbackState = newState
        switch newState {
        case .playing:
            setDerivedState(isPlaying: true, isPaused: false)
        case .paused:
            setDerivedState(isPlaying: false, isPaused: true)
        default:
            setDerivedState(isPlaying: false, isPaused: false)
        }
    }

    private func setDerivedState(isPlaying: Bool, isPaused: Bool) {
        if self.isPlaying != isPlaying { self.isPlaying = isPlaying }
        if self.isPaused != isPaused { self.isPaused = isPaused }
    }

    private func shouldIgnoreCompletion(from seekID: UUID?) -> Bool {
        if let seekID, seekID != currentSeekID { return true }
        if seekGuardActive && seekID == nil { return true }
        if case .stopped(let reason) = playbackState,
           reason == .manual || reason == .ejected { return true }
        return false
    }

    // MARK: - Track Management

    func addTrack(url: URL) {
        let normalizedURL = url.standardizedFileURL

        if playlistController.containsTrack(url: normalizedURL) {
            AppLog.debug(.audio, "Track already pending or in playlist: \(normalizedURL.lastPathComponent)")
            return
        }

        AppLog.debug(.audio, "Adding track from \(normalizedURL.lastPathComponent)")
        playlistController.addPendingURL(normalizedURL)

        let placeholder = Track(
            url: normalizedURL,
            title: normalizedURL.lastPathComponent,
            artist: "Loading...",
            duration: 0.0
        )

        playlistController.addPlaceholder(placeholder)

        let generation = playlistGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.playlistController.removePendingURL(normalizedURL) }

            AppLog.debug(.audio, "Loading metadata for \(normalizedURL.lastPathComponent)")
            let metadata = await MetadataLoader.loadTrackMetadata(from: normalizedURL)

            // Reject stale metadata if playlist was cleared/replaced while loading
            guard self.playlistGeneration == generation else {
                AppLog.debug(.audio, "Discarding stale metadata for \(normalizedURL.lastPathComponent) — playlist changed")
                return
            }

            let track = Track(url: normalizedURL, title: metadata.title, artist: metadata.artist, duration: metadata.duration)
            AppLog.debug(.audio, "Metadata loaded - title: '\(track.title)', artist: '\(track.artist)', duration: \(track.duration)s")

            if self.playlistController.replacePlaceholder(id: placeholder.id, with: track) {
                if self.currentTrack?.id == placeholder.id {
                    AppLog.debug(.audio, "Updating current track metadata")
                    self.currentTrack = track
                    self.currentTitle = "\(track.title) - \(track.artist)"
                    // Don't overwrite currentDuration from metadata (AVAsset.duration)
                    // when the engine has the current audio file loaded. Engine file
                    // duration is the authoritative runtime source — metadata duration
                    // can diverge on VBR/compressed files, causing seek bar drift.
                    // Use metadata duration only for non-audio or before file loads.
                    if self.currentMediaType != .audio || self.engine.currentFileDuration <= 0 {
                        self.currentDuration = track.duration
                    }
                    self.currentTrackURL = track.url
                    self.onTrackMetadataUpdate?(track)
                }
            } else if !self.playlistController.containsTrack(url: normalizedURL) {
                self.playlistController.addTrack(track)
            }
        }
    }

    func addStreamTrack(_ track: Track) {
        playlistController.addTrack(track)
    }

    func removeTrack(at index: Int) {
        playlistController.removeTrack(at: index)
    }

    func replacePlaylist(with tracks: [Track]) {
        playlistGeneration &+= 1
        playlistController.clear()
        for track in tracks { playlistController.addTrack(track) }
        AppLog.debug(.audio, "Replaced playlist with \(tracks.count) tracks")
    }

    func clearPlaylist() {
        playlistGeneration &+= 1
        playlistController.clear()
    }

    func playTrack(track: Track) {
        cancelPendingReconfigure()
        guard !track.isStream else {
            AppLog.error(.audio, "Cannot play internet radio streams. Stream URL: \(track.url). Use PlaybackCoordinator to route streams to StreamPlayer.")
            return
        }

        updatePlaylistPosition(with: track)

        // Fresh slate per track — last session's tap fallback must not
        // suppress this track's capability surface.
        videoTapFallbackActive = false

        currentSeekID = UUID()
        seekGuardActive = true

        engine.stopAudio()
        engine.invalidateProgressTimer()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            self.seekGuardActive = false
        }

        currentTrack = track
        currentTitle = "\(track.title) - \(track.artist)"
        currentDuration = track.duration
        currentTrackURL = track.url
        currentTime = 0
        playbackProgress = 0
        transition(to: .preparing)
        seekGuardActive = false
        playlistController.resetEnded()

        AppLog.info(.audio, "Playing track '\(track.title)'")

        let mediaType = detectMediaType(url: track.url)

        if currentMediaType != mediaType {
            if currentMediaType == .video {
                tearDownVideoBridge()
                videoPlaybackController.cleanup()
                AppLog.debug(.audio, "Switching from video to audio - cleanup complete")
            }
            // audio→video: keep the visualizer tap installed. Video now
            // feeds the engine through the bridge, so the same tap that
            // drives the spectrum + Milkdrop frame for audio sessions
            // works for video sessions too (plan §11.4).
        }

        currentMediaType = mediaType

        switch mediaType {
        case .audio:
            loadAudioFile(url: track.url)
        case .video:
            // Tear down any previous video bridge before starting the new one
            // so back-to-back video tracks don't double-attach taps.
            tearDownVideoBridge()
            startVideoTrack(track)
            return  // eqAutoEnabled + play() handled inside the async setup
        }

        if equalizer.eqAutoEnabled {
            equalizer.applyAutoPreset(for: track)
        }

        play()
    }

    /// Build a ring buffer + VideoAudioTap, kick off async tap attach, activate
    /// the engine video bridge on success, and start playback. Mute the
    /// AVPlayer's direct audio (`volume = 0`) only after the tap is in place
    /// so the bridge is the sole output path. On attach failure (silent
    /// video, asset load error), the tap and ring are released and AVPlayer
    /// drives its own audio at the user's volume — capability flags reflect
    /// the absence of engine routing.
    private func startVideoTrack(_ track: Track) {
        let sampleRate = engine.outputSampleRate
        // 16384 frames = ~340 ms of producer-side headroom at 48 kHz —
        // capacity, not steady-state latency. Real-world fill levels hover
        // far below capacity once the consumer keeps pace. The previous
        // 4096-frame (~85 ms) ring left no margin for transient tap jitter
        // (decode spikes, route-change preludes, render-thread preemption);
        // dropouts on the consumer side correlated with perceptible video
        // hitches. The bigger ring absorbs that jitter without changing
        // typical audio latency.
        let ring = LockFreeRingBuffer(capacity: 16384, channelCount: 2)
        let tap = VideoAudioTap(ringBuffer: ring, expectedSampleRate: sampleRate)
        videoRingBuffer = ring
        videoAudioTap = tap

        videoLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let attached = await self.videoPlaybackController.loadVideo(
                url: track.url,
                autoPlay: false,
                audioTap: tap
            )

            // Identity check: bail if a newer setup ran during the await
            // (playTrack-switch, stop, same-URL replay, deinit). URL
            // equality is NOT enough — replay of the same track produces
            // a fresh tap that we'd otherwise match. The path that
            // supplanted us already ran tearDownVideoBridge / cleanup, so
            // we don't touch shared state here — the orphaned `ring` and
            // `tap` locals fall out of scope as the closure returns.
            guard !Task.isCancelled, self.videoAudioTap === tap else {
                return
            }

            // Clear our slot in `videoLoadTask` now that we've claimed
            // the active load. The `play()` guard uses `videoLoadTask !=
            // nil` to defer user-initiated play during the load window;
            // leaving the field set after we complete would permanently
            // block resume / remote-play. tearDownVideoBridge clears it
            // for the cancelled / superseded paths.
            defer { self.videoLoadTask = nil }

            if attached {
                self.engine.activateVideoBridge(ringBuffer: ring, sampleRate: sampleRate)
                if self.engine.isVideoBridgeActive {
                    self.engine.setVolume(self.volume)
                    self.engine.setBalance(self.balance)
                    self.startVideoTapWatchdog(for: tap)
                } else {
                    // Tap attached but engine refused to start the bridge
                    // (HAL device error, etc.). The audioMix is wired up,
                    // so AVPlayer is still muted — detach so the user
                    // gets direct AVPlayer audio at their slider level.
                    AppLog.error(.audio, "Video bridge activation failed — falling back to direct AVPlayer audio")
                    self.videoPlaybackController.detachAudioTap()
                    self.videoAudioTap = nil
                    self.videoRingBuffer = nil
                    self.videoPlaybackController.volume = self.volume
                }
            } else {
                // Tap attach failed (silent video, asset load error,
                // converter setup failure). AVPlayer becomes the audible
                // path — re-sync the controller's stored volume to the
                // current AudioPlayer level. While the bridge was being
                // set up, volume.didSet's gate skipped forwarding because
                // we expected the bridge to take over; now that it didn't,
                // AVPlayer needs the user's slider position.
                self.videoAudioTap = nil
                self.videoRingBuffer = nil
                self.videoPlaybackController.volume = self.volume
            }

            if self.equalizer.eqAutoEnabled {
                self.equalizer.applyAutoPreset(for: track)
            }

            self.videoPlaybackController.play()
            self.transition(to: .playing)
        }
    }

    /// Drop the active video bridge: deactivate the engine source node,
    /// detach the tap, and release the tap + ring buffer references. Safe
    /// to call when no bridge is active. Caller is responsible for the
    /// matching `videoPlaybackController` cleanup (or `cleanup()` will run
    /// `detachAudioTap()` itself, which is idempotent with this).
    private func tearDownVideoBridge() {
        stopVideoTapWatchdog()
        videoLoadTask?.cancel()
        videoLoadTask = nil
        if engine.isVideoBridgeActive {
            engine.deactivateVideoBridge()
        }
        videoPlaybackController.detachAudioTap()
        videoAudioTap = nil
        videoRingBuffer = nil
        // Do NOT re-sync videoPlaybackController.volume here. This helper
        // runs on stop, video-to-video switch, eject, and isolated deinit.
        // In the video-to-video case the old AVPlayer is still alive at
        // this point (its cleanup runs inside the next loadVideo), and a
        // restore would un-mute it for one main-loop tick — exactly the
        // double-audio failure mode this gating system exists to prevent.
        // Volume restore belongs only on direct-audio-continuation paths
        // (attach-failure branch in startVideoTrack, tap-fallback) where
        // AVPlayer becomes the sole audible path.
    }

    /// Spawn the 250 ms watchdog Task that observes `tap` for callback
    /// stalls (>1 s gap) and `fallbackRequested` flips. Identity-keyed:
    /// when a different setup replaces `videoAudioTap`, the next tick
    /// breaks. Caller must invoke this only after `engine.activateVideoBridge`
    /// has succeeded for `tap`.
    private func startVideoTapWatchdog(for tap: VideoAudioTap) {
        videoTapWatchdogTask?.cancel()
        videoTapWatchdogTask = Task { @MainActor [weak self] in
            // Baseline for the host-time stall calculation. Reset on each
            // pause→play transition so a long pause doesn't leave a stale
            // `lastCallbackHostTime` that immediately demotes on resume.
            // Initialized as if the watchdog start itself were a "resume",
            // covering the post-attach window before the first callback.
            var resumeBaselineHost: UInt64 = mach_absolute_time()
            var wasPlaying: Bool = false
            // Tracks whether the prior tick was inside the reconfigure
            // gate. On the FIRST ungated tick we run a one-shot clean-up
            // that mirrors the gated tick — clears `fallbackRequested`,
            // resets the baseline, forces the next isPlaying observation
            // to count as a resume edge. This absorbs any flag raised
            // between the last gated tick and the deadline expiry (HAL
            // settle tail can fire its final noise milliseconds after
            // the deadline elapses).
            var wasReconfigureGated: Bool = false
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { break }
                guard let self else { break }
                // Identity / liveness guards. If the user advanced to a
                // new track, paused-and-stopped, or the bridge tore down
                // for any reason, drop the watchdog without engaging.
                guard self.videoAudioTap === tap else { break }
                guard self.engine.isVideoBridgeActive else { break }
                if self.videoTapFallbackActive { break }

                // Engine reconfigure burst + post-burst settle window.
                // HAL halts the AVPlayer audio render thread while the new
                // route comes up, so callbacks pause and tap.fallbackRequested
                // may briefly trip on source-pull errors — both are expected
                // HAL artifacts, not real tap failures. The gate spans the
                // entire window (will → did + settle); the 150 ms quiet
                // window between will/did is too short on its own (HAL
                // recovery routinely takes seconds).
                //
                // Skip stall + flag checks, reset the resume baseline so
                // the post-gate first iteration measures from now, force
                // a resume-edge reset on whichever post-gate iteration
                // first sees `isPlaying`, and clear any stale
                // `fallbackRequested` set during the burst so it can't
                // demote the moment the gate clears (Oracle MUST-FIX).
                // A real post-gate failure will re-trip the flag from
                // the C-side tap callback.
                if self.videoBurstGateOpen
                    || mach_absolute_time() < self.videoReconfigureGateUntilHost {
                    resumeBaselineHost = mach_absolute_time()
                    wasPlaying = false
                    tap.clearFallbackRequested()
                    wasReconfigureGated = true
                    continue
                }

                // First tick after the gate expires: HAL noise can land
                // between the last gated tick and the deadline elapsing,
                // setting fallbackRequested in a window the gate didn't
                // cover. Run one more clean-up tick before checking the
                // flag for real, so a single late-edge spurious trip
                // can't demote.
                if wasReconfigureGated {
                    wasReconfigureGated = false
                    resumeBaselineHost = mach_absolute_time()
                    wasPlaying = false
                    tap.clearFallbackRequested()
                    continue
                }

                // Immediate trigger: the C-side prepare or process callback
                // already gave up (AudioConverterNew failure, channel-map
                // mismatch, source-pull error, mid-stream converter fault).
                // Don't wait out the host-time timeout.
                if tap.fallbackRequested {
                    self.engageVideoTapFallback()
                    return
                }

                // Host-time stall trigger. Only meaningful while AVPlayer
                // is actually playing — paused video legitimately produces
                // no callbacks.
                let isPlaying = self.videoPlaybackController.isPlaying
                if isPlaying && !wasPlaying {
                    resumeBaselineHost = mach_absolute_time()
                }
                wasPlaying = isPlaying
                guard isPlaying else { continue }

                // Use the more recent of the resume baseline and the last
                // callback host time. If a callback arrived since resume,
                // `last` wins and we're measuring true tap latency. If
                // none has arrived yet, `resumeBaselineHost` wins and the
                // window starts from resume, not from the stale pre-pause
                // callback.
                //
                // Threshold is 3 s, not 1 s. macOS HAL route transitions
                // (BT/AirPods auto-routing in particular, where the
                // AVAudioEngine notification doesn't fire) can stall the
                // AVPlayer audio render thread for 1.5–2.5 s while the
                // new route comes up. A real tap failure still demotes —
                // just 2 s later than before, which is invisible to the
                // user (AVPlayer fallback restores audio immediately on
                // demote anyway).
                let last = tap.lastCallbackHostTime
                let baseline = max(last, resumeBaselineHost)
                let elapsed = AVAudioTime.seconds(forHostTime: mach_absolute_time() &- baseline)
                if elapsed > Self.videoTapStallThresholdSeconds {
                    self.engageVideoTapFallback()
                    return
                }
            }
        }
    }

    private func stopVideoTapWatchdog() {
        videoTapWatchdogTask?.cancel()
        videoTapWatchdogTask = nil
    }

    /// Demote the active video session from the engine bridge to direct
    /// AVPlayer audio. Plan §10.2 ordering, must run on @MainActor:
    /// idempotency guard → cancel watchdog → set fallback flag → log →
    /// deactivate engine bridge → detach tap (audioMix=nil first) →
    /// release tap/ring refs → restore AVPlayer volume → reset seek
    /// guard. Sticky for the current track; cleared at the start of the
    /// next `playTrack`.
    private func engageVideoTapFallback() {
        guard !videoTapFallbackActive else { return }
        stopVideoTapWatchdog()
        videoTapFallbackActive = true
        AppLog.error(.audio, "Video audio tap stalled — restoring AVPlayer.volume fallback")
        if engine.isVideoBridgeActive {
            engine.deactivateVideoBridge()
        }
        videoPlaybackController.detachAudioTap()
        videoAudioTap = nil
        videoRingBuffer = nil
        // AVPlayer becomes the sole audible path. Re-sync the controller's
        // volume so the user's slider position takes effect immediately —
        // the bridge-active gate in `volume.didSet` had been suppressing
        // forwarding, and the bridge is now down.
        videoPlaybackController.volume = volume
        seekGuardActive = false
    }

    private func detectMediaType(url: URL) -> MediaType {
        let videoExtensions = ["mp4", "mov", "m4v", "avi"]
        return videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .audio
    }

    private func loadAudioFile(url: URL) {
        do {
            try engine.loadFile(url: url)
            currentSeekID = UUID()
            _ = engine.scheduleFrom(time: 0, seekID: currentSeekID)
            engine.setVolume(volume)
            engine.setBalance(balance)

            // Sync currentDuration from file (fallback when metadata duration is 0/missing)
            let fileDuration = engine.currentFileDuration
            if fileDuration.isFinite && fileDuration > 0 {
                currentDuration = fileDuration
            }

            Task { @MainActor [weak self] in
                if let props = await MetadataLoader.loadAudioProperties(from: url) {
                    self?.channelCount = props.channelCount
                    self?.bitrate = props.bitrate
                    self?.sampleRate = props.sampleRate
                }
            }
        } catch {
            AppLog.error(.audio, "Failed to open file: \(error)")
            engine.clearFile()
            transition(to: .stopped(.manual))
        }
    }

    // MARK: - Transport

    func play() {
        cancelPendingReconfigure()
        if playlistController.hasEnded && !playlist.isEmpty {
            playTrack(track: playlist[0])
            return
        }

        if currentMediaType == .video {
            // While the load Task is in-flight the tap hasn't attached
            // and AVPlayer is still at user volume — calling play() now
            // would emit direct AVPlayer audio before the engine bridge
            // takes over (plan §8.4 ordering violation, audible as a
            // brief un-bridged blip on remote-play / media-key triggers).
            // The Task itself plays + transitions once attach completes.
            guard videoLoadTask == nil else {
                AppLog.debug(.audio, "Play (Video) — load task in flight; deferring to Task completion")
                return
            }
            videoPlaybackController.play()
            transition(to: .playing)
            AppLog.debug(.audio, "Play (Video)")
            return
        }

        guard engine.audioFile != nil else {
            AppLog.warn(.audio, "No track loaded to play.")
            return
        }

        let fileDuration = engine.currentFileDuration
        if currentTime >= fileDuration - 0.01 {
            onPlaybackEnded()
            return
        }

        guard engine.startEngineIfNeeded() else {
            AppLog.error(.audio, "Play aborted — engine failed to start")
            return
        }

        engine.installVisualizerTapIfNeeded()
        engine.playAudio()
        engine.startProgressTimer()
        transition(to: .playing)
        seekGuardActive = false
        AppLog.debug(.audio, "Play")
    }

    func pause() {
        cancelPendingReconfigure()
        if currentMediaType == .video {
            videoPlaybackController.pause()
            transition(to: .paused)
            AppLog.debug(.audio, "Pause (Video)")
            return
        }

        guard engine.isPlayerNodePlaying else { return }
        engine.pauseAudio()
        engine.removeVisualizerTapIfNeeded()
        transition(to: .paused)
        seekGuardActive = false
        AppLog.debug(.audio, "Pause")
    }

    func stop() {
        cancelPendingReconfigure()
        transition(to: .stopped(.manual))

        if currentMediaType == .video {
            tearDownVideoBridge()
            videoPlaybackController.stop()
            currentMediaType = .audio
            AppLog.debug(.audio, "Stop (Video) - cleaned up AVPlayer")
        }

        engine.stopAudio()
        currentSeekID = UUID()
        _ = engine.scheduleFrom(time: 0, seekID: currentSeekID)

        currentTrack = nil
        currentTitle = "No Track Loaded"
        currentTrackURL = nil
        currentDuration = 0.0
        currentTime = 0
        playbackProgress = 0
        engine.invalidateProgressTimer()
        engine.removeVisualizerTapIfNeeded()

        bitrate = 0
        sampleRate = 0
        channelCount = 2
        seekGuardActive = false
        AppLog.debug(.audio, "Stop")
    }

    func eject() {
        stop()
        transition(to: .stopped(.ejected))
        playlistGeneration &+= 1
        playlistController.clear()
        currentTrack = nil
        currentTrackURL = nil
        currentTitle = "No Track Loaded"
        currentDuration = 0.0
        currentTime = 0.0
        playbackProgress = 0.0
        appliedAutoPresetTrack = nil
        engine.clearFile()
        bitrate = 0
        sampleRate = 0
        channelCount = 2
        AppLog.info(.audio, "Eject - cleared playlist and reset playback state")
    }

    // MARK: - Equalizer Forwarding (backed by EqualizerController)

    func setPreamp(value: Float) { equalizer.setPreamp(value: value) }
    func setEqBand(index: Int, value: Float) { equalizer.setEqBand(index: index, value: value) }
    func toggleEq(isOn: Bool) { equalizer.toggleEq(isOn: isOn) }
    func applyPreset(_ preset: EqfPreset) { equalizer.applyPreset(preset) }
    func applyEQPreset(_ preset: EQPreset) { equalizer.applyEQPreset(preset) }
    func getCurrentEQPreset(name: String) -> EQPreset { equalizer.getCurrentEQPreset(name: name) }
    func saveUserPreset(named name: String) { equalizer.saveUserPreset(named: name) }
    func deleteUserPreset(id: UUID) { equalizer.deleteUserPreset(id: id) }
    func importEqfPreset(from url: URL) { equalizer.importEqfPreset(from: url) }

    func savePresetForCurrentTrack() {
        guard let t = currentTrack else { return }
        equalizer.savePresetForCurrentTrack(t)
    }

    func setAutoEQEnabled(_ isEnabled: Bool) {
        equalizer.setAutoEQEnabled(isEnabled, currentTrack: currentTrack)
    }

    // MARK: - Stream Bridge Forwarding (backed by AudioEngineController)

    func activateStreamBridge(ringBuffer: LockFreeRingBuffer, sampleRate: Float64) {
        engine.activateStreamBridge(ringBuffer: ringBuffer, sampleRate: sampleRate)
        engine.setVolume(volume)
        engine.setBalance(balance)
    }

    func deactivateStreamBridge() {
        engine.deactivateStreamBridge()
    }

    /// No-op when the stream bridge is inactive.
    func setStreamSilenced(_ silenced: Bool) {
        engine.setStreamSilenced(silenced)
    }

    #if DEBUG
    var isStreamSilenceGateActive: Bool { engine.isStreamSilenceGateActive }

    /// Test seam for the watchdog → fallback path. Phase 5 unit tests
    /// drive the deterministic state machine here; the timing-sensitive
    /// host-time stall detection is exercised by manual playback.
    func _testEngageVideoTapFallback() { engageVideoTapFallback() }

    /// Test seam: install a tap + ring under AudioPlayer's ownership and
    /// run the engine bridge so the watchdog can observe a live state.
    /// Used by `VideoTapFallbackTests.watchdogEngagesOnFallbackRequested`
    /// to assert the immediate-trigger path end-to-end.
    func _testActivateVideoBridgeAndStartWatchdog(
        tap: VideoAudioTap,
        ringBuffer: LockFreeRingBuffer
    ) {
        videoAudioTap = tap
        videoRingBuffer = ringBuffer
        engine.activateVideoBridge(ringBuffer: ringBuffer, sampleRate: 48_000)
        startVideoTapWatchdog(for: tap)
    }

    /// Test seam: simulate an active reconfigure burst (snapshot non-nil
    /// AND burst gate open). Pairs with `_testEndVideoReconfigureBurst`
    /// for burst → settle transitions. Pass nil to fully release.
    func _testSetPendingReconfigureSnapshot(_ snapshot: PreReconfigureSnapshot?) {
        pendingReconfigureSnapshot = snapshot
        if snapshot == nil {
            videoBurstGateOpen = false
            videoReconfigureGateUntilHost = 0
        } else {
            videoBurstGateOpen = true
        }
    }

    /// Test seam: arm the post-burst settle window with a custom duration
    /// (production uses `videoReconfigureSettleSeconds`). Used to exercise
    /// the gate-clears → fresh-failure-demotes path without 2s sleeps.
    /// Uses max() coalescing exactly like production.
    func _testEndVideoReconfigureBurst(settleSeconds: Double) {
        pendingReconfigureSnapshot = nil
        videoBurstGateOpen = false
        armVideoRouteChangeGate(seconds: settleSeconds)
    }

    /// Test seam: simulate a user-intent path (play/pause/stop/seek/playTrack)
    /// firing during a burst. Should clear `pendingReconfigureSnapshot` but
    /// MUST NOT clear `videoReconfigureGateUntilHost` — the watchdog gate
    /// is the HAL-stabilization concern, independent of resume context.
    func _testCancelPendingReconfigure() {
        cancelPendingReconfigure()
    }

    /// Test seam: invoke the production reconfigure-end handler exactly as
    /// the engine observer would, then optionally compress the resulting
    /// settle window for time-bounded tests. Validates the production
    /// lifecycle including the cancel-then-did-handler orphan-gate fix
    /// (gate must arm even when the snapshot was already canceled).
    func _testHandleEngineDidReconfigure(overrideSettleSeconds: Double? = nil) {
        handleEngineDidReconfigure()
        if let seconds = overrideSettleSeconds {
            let settleTicks = AVAudioTime.hostTime(forSeconds: seconds)
            videoReconfigureGateUntilHost = mach_absolute_time() &+ settleTicks
        }
    }

    /// Test seam: invoke the bounded gate helper that the HAL listener
    /// uses. Validates the `max()` coalescing — repeated calls must
    /// extend (or no-op) the deadline, never shorten it.
    func _testArmVideoRouteChangeGate(seconds: Double) {
        armVideoRouteChangeGate(seconds: seconds)
    }

    /// Test seam: read the current gate deadline (for asserting
    /// monotonic max() semantics in the helper test).
    var _testVideoReconfigureGateUntilHost: UInt64 {
        videoReconfigureGateUntilHost
    }
    #endif

    /// The audio IO workgroup from the engine output node.
    /// Valid only while the engine is running (i.e., after bridge activation).
    var audioWorkgroup: os_workgroup_t? {
        engine.audioWorkgroup
    }

    // MARK: - Seeking / Scrubbing

    func seekToPercent(_ percent: Double, resume: Bool? = nil) {
        if currentMediaType == .video {
            videoPlaybackController.seekToPercent(percent, resume: resume, completion: videoSeekCompletion)
            return
        }

        guard engine.audioFile != nil else {
            AppLog.warn(.audio, "seekToPercent: No audio file loaded")
            return
        }

        let fileDuration = engine.currentFileDuration
        let targetTime = percent * fileDuration
        seek(to: targetTime, resume: resume)
    }

    func seek(to time: Double, resume: Bool? = nil) {
        cancelPendingReconfigure()
        if currentMediaType == .video {
            videoPlaybackController.seek(to: time, resume: resume, completion: videoSeekCompletion)
            return
        }

        guard engine.audioFile != nil else {
            AppLog.warn(.audio, "seek: Cannot seek - no audio file loaded")
            return
        }

        let shouldPlay = resume ?? isPlaying
        seekGuardActive = true
        currentSeekID = UUID()
        engine.invalidateProgressTimer()

        let fileDuration = engine.currentFileDuration
        let targetProgress = fileDuration > 0 ? time / fileDuration : 0

        let audioScheduled = engine.scheduleFrom(time: time, seekID: currentSeekID)

        currentTime = time
        playbackProgress = targetProgress

        if audioScheduled && shouldPlay {
            engine.startEngineIfNeeded()
            engine.installVisualizerTapIfNeeded()
            engine.playAudio()
            engine.startProgressTimer()
            transition(to: .playing)
        } else if !audioScheduled {
            transition(to: .stopped(.completed))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self?.onPlaybackEnded()
            }
        } else {
            transition(to: .paused)
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            self?.seekGuardActive = false
        }
    }

    // MARK: - Engine Reconfiguration Handlers

    /// Discard any in-flight reconfigure-resume context. Called from user-intent
    /// entry points (play/pause/stop/seek/playTrack) so that a stale `onDid`
    /// callback fired during the 150 ms debounce window can't override the
    /// user's new intent. handleEngineDidReconfigure early-returns when
    /// `pendingReconfigureSnapshot` is nil, so the snapshot nil-out is the
    /// cancel hook.
    ///
    /// Also clears `seekGuardActive` and `isHandlingCompletion` — the will-handler
    /// armed both, and the did-handler is the only path that schedules their
    /// 100/200 ms release tasks. Without this clear, the early-returned did
    /// would leave both guards stuck on indefinitely, wedging the next
    /// `onPlaybackEnded` completion. (No-op when no burst is in flight; both
    /// fields are independently managed by the seek() / onPlaybackEnded paths.)
    private func cancelPendingReconfigure() {
        pendingReconfigureSnapshot = nil
        seekGuardActive = false
        isHandlingCompletion = false
    }

    /// Invoked at the START of an output-route reconfigure burst (Control Center,
    /// AirPlay, HDMI hot-plug, sleep/wake). Captures the engine's pre-rewire
    /// snapshot and arms seek guards before the engine restart fires a stale
    /// playerNode completion. The matching `handleEngineDidReconfigure` consumes
    /// the stored snapshot to decide whether to resume.
    ///
    /// **Pairing note:** if `stop()` or `deinit` interrupts the burst before
    /// `onDidReconfigure` fires, the 100/200 ms guard release tasks scheduled
    /// inside `handleEngineDidReconfigure` never run. The user-intent entry
    /// points (play/pause/stop/seek/playTrack) cover this gap by calling
    /// `cancelPendingReconfigure()`, which clears both guards. The only
    /// remaining "stuck guards" case is observer-stop / deinit during a burst
    /// without any subsequent user action — and at that point AudioPlayer
    /// itself is being torn down, so the leftover state is harmless.
    private func handleEngineWillReconfigure(snapshot: PreReconfigureSnapshot) {
        // Diagnostic: confirms which output-route changes actually fire the
        // observer. macOS HAL routes through this notification for HDMI,
        // BT, AirPods (via AirPlay subsystem), built-in toggle, etc.
        AppLog.info(.audio, "Engine will reconfigure — output route change pending (videoBridge=\(snapshot.wasVideoBridge), streamBridge=\(snapshot.wasStreamBridge))")

        // The engine captures its snapshot at notification-receipt time, by
        // which point the system has ALREADY auto-stopped the engine —
        // `playerNode.isPlaying` is false and `playerNode.lastRenderTime` is
        // nil. The engine's `wasPlaying` / `currentTime` fields are therefore
        // unreliable. Override with AudioPlayer's own state: `isPlaying` is
        // transition-managed (reflects user intent, not engine running state)
        // and `currentTime` is updated by the progress timer ~100 ms before
        // the reconfigure — accurate to within one tick.
        let corrected = PreReconfigureSnapshot(
            wasPlaying: isPlaying,
            currentTime: currentTime,
            wasStreamBridge: snapshot.wasStreamBridge,
            wasVideoBridge: snapshot.wasVideoBridge
        )
        pendingReconfigureSnapshot = corrected
        // Open the watchdog gate for the entire burst. `did` clears it
        // and arms a finite settle deadline. Decoupled from the deadline
        // field so an earlier HAL-armed deadline isn't clobbered by the
        // burst flag.
        videoBurstGateOpen = true
        // Bump currentSeekID BEFORE engine restart so the impending stale
        // playerNode completion (carrying the OLD seekID) is filtered by
        // shouldIgnoreCompletion. Same pattern as seek() / playTrack().
        currentSeekID = UUID()
        seekGuardActive = true
        isHandlingCompletion = true
    }

    /// Invoked once at the END of a reconfigure burst (150 ms quiet window).
    /// The engine has been restarted and stream-bridge graph format refreshed
    /// for the new output device. AudioPlayer re-applies volume + balance,
    /// reschedules the local-file player from the saved time, and releases
    /// seek guards on the same 100/200 ms cadence as `seek()`.
    private func handleEngineDidReconfigure() {
        // Close the burst gate FIRST, regardless of whether resume context
        // survived. If user-intent (`cancelPendingReconfigure()`) already
        // cleared the snapshot, the early-return below would otherwise
        // leave `videoBurstGateOpen` at true forever and permanently
        // neuter the watchdog.
        videoBurstGateOpen = false
        // Arm the finite settle deadline via the bounded helper so a
        // longer HAL-listener deadline armed before/during the burst
        // is preserved (max coalescing). The settle covers HAL's
        // multi-second route-stabilization tail past the engine's
        // 150 ms quiet window.
        armVideoRouteChangeGate(seconds: Self.videoReconfigureSettleSeconds)

        guard let snapshot = pendingReconfigureSnapshot else { return }
        pendingReconfigureSnapshot = nil

        // 1. Re-apply volume + balance — engine nodes may have been recreated.
        engine.setVolume(volume)
        engine.setBalance(balance)

        // 2. Local-file path: ALWAYS reschedule from saved time, even when paused.
        //    play() does NOT itself reschedule (see line 417), so a subsequent
        //    play() would resume the now-detached pre-restart segment.
        //    Gate on currentMediaType too — engine.audioFile can be stale from
        //    a prior local-audio session while a tap-failed video plays its
        //    own audio direct, and we mustn't reschedule that.
        if !snapshot.wasStreamBridge && !snapshot.wasVideoBridge
            && currentMediaType == .audio
            && engine.audioFile != nil {
            _ = engine.scheduleFrom(time: snapshot.currentTime, seekID: currentSeekID)
            currentTime = snapshot.currentTime
            if snapshot.wasPlaying {
                engine.startEngineIfNeeded()
                engine.installVisualizerTapIfNeeded()
                engine.playAudio()
                engine.startProgressTimer()
                transition(to: .playing)
            } else {
                transition(to: .paused)
            }
        }
        // 3. Stream-bridge path: AVAudioSourceNode + ring buffer survived; the
        //    workgroup refresh is delegated to PlaybackCoordinator (Phase 1.1.7).
        // 4. Video-bridge path: AVPlayer manages its own clock — paused stays
        //    paused. Phase 3 (plan §8.1) wires the actual videoSourceNode
        //    refresh in handleEngineDidReconfigure on the engine side.

        // 5. Release seek guards on the same cadence as seek() / onPlaybackEnded.
        //    Modern Duration API (Swift 5.7+) — matches the pattern introduced
        //    in AudioEngineConfigurationObserver.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.seekGuardActive = false
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.isHandlingCompletion = false
        }

        // 6. Notify external subscribers (PlaybackCoordinator refreshes the
        //    stream workgroup; future subscribers may update Now Playing, etc.).
        onEngineReconfigured?()
    }

    /// Extend the video reconfigure gate by `seconds` from now, never
    /// shortening it. This is the safe entry point for any signal that
    /// indicates HAL is mid-route-change (engine observer, HAL property
    /// listener, future signals). `max()` coalesces overlapping signals
    /// — e.g. an AirPlay switch that fires both the HAL listener and
    /// later the engine observer extends the gate to whichever deadline
    /// is later, never collapsing it short.
    ///
    /// **Critical:** unlike `handleEngineWillReconfigure` which sets the
    /// gate to `UInt64.max` and relies on a matching `did` to convert
    /// it to a finite deadline, this method always installs a finite
    /// deadline directly. Callers without a guaranteed paired close
    /// (the HAL listener especially — there's no "did" notification for
    /// AirPlay route changes) must use this path, never the burst-style
    /// `UInt64.max` open-ended gate.
    private func armVideoRouteChangeGate(seconds: Double) {
        let deadline = mach_absolute_time() &+ AVAudioTime.hostTime(forSeconds: seconds)
        videoReconfigureGateUntilHost = max(videoReconfigureGateUntilHost, deadline)
    }

    /// Install a HAL property listener on the system default output
    /// device. Fires immediately on ANY default-output change including
    /// AirPlay/AirPods routes that bypass `AVAudioEngineConfigurationChange`.
    /// The block hops to `@MainActor` and arms the bounded video route
    /// gate scoped to active or in-flight video sessions only.
    private func installHALDefaultOutputListener() {
        let queue = DispatchQueue(label: "com.macamp.audio.haldefaultoutput", qos: .userInitiated)
        halDefaultOutputListenerQueue = queue

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Hop to MainActor — never touch SwiftUI-observed state,
            // AVAudioEngine, or AudioPlayer fields from the HAL queue.
            Task { @MainActor [weak self] in
                self?.handleHALDefaultOutputChange()
            }
        }
        halDefaultOutputListenerBlock = block

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            block
        )
        if status != noErr {
            AppLog.warn(.audio, "AudioPlayer: HAL default-output listener install failed (status: \(status))")
            halDefaultOutputListenerBlock = nil
            halDefaultOutputListenerQueue = nil
        }
    }

    /// Remove the HAL property listener installed in
    /// `installHALDefaultOutputListener`. Idempotent. The same block
    /// instance must be passed to `Remove` as was passed to `Add` or the
    /// removal silently no-ops — that's why we store the block.
    private func removeHALDefaultOutputListener() {
        guard let block = halDefaultOutputListenerBlock,
              let queue = halDefaultOutputListenerQueue else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            block
        )
        halDefaultOutputListenerBlock = nil
        halDefaultOutputListenerQueue = nil
    }

    /// Invoked on `@MainActor` from the HAL listener block when the
    /// system default output device changes. Scoped to active or
    /// in-flight video sessions: arming the gate when no video bridge
    /// could possibly be affected would let unrelated route changes
    /// mask real tap failures on a newly-started video.
    private func handleHALDefaultOutputChange() {
        guard currentMediaType == .video,
              !videoTapFallbackActive,
              engine.isVideoBridgeActive
                || videoAudioTap != nil
                || videoLoadTask != nil
        else { return }

        AppLog.info(.audio, "HAL default output device changed — arming video route gate (\(Self.videoRouteChangeGateSeconds)s)")
        armVideoRouteChangeGate(seconds: Self.videoRouteChangeGateSeconds)
    }

    /// Shared completion handler for video seek operations.
    /// Syncs video playback state back to AudioPlayer after AVPlayer seek completes.
    private var videoSeekCompletion: @Sendable (Double) -> Void {
        { [weak self] (actualTime: Double) in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = actualTime
                self.playbackProgress = self.videoPlaybackController.progress
                self.currentDuration = self.videoPlaybackController.duration
                self.transition(to: self.videoPlaybackController.isPlaying ? .playing : .paused)
            }
        }
    }

    // MARK: - Visualizer Forwarding (backed by VisualizerPipeline)

    func getFrequencyData(bands: Int) -> [Float] {
        visualizerPipeline.getFrequencyData(bands: bands, isPlaying: isEngineRendering)
    }

    func getWaveformSamples(count: Int) -> [Float] {
        visualizerPipeline.getWaveformSamples(count: count)
    }

    func snapshotButterchurnFrame() -> ButterchurnFrame? {
        guard isEngineRendering else { return nil }
        // Video runs through the engine when the bridge is active; the
        // tap-fallback path bypasses the engine entirely and produces
        // nothing visualizable.
        if currentMediaType == .video, !engine.isVideoBridgeActive { return nil }
        return visualizerPipeline.snapshotButterchurnFrame()
    }

    // MARK: - Playback Completion

    private func onPlaybackEnded(fromSeekID: UUID? = nil) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard !self.isHandlingCompletion else { return }

            if self.shouldIgnoreCompletion(from: fromSeekID) { return }

            self.isHandlingCompletion = true
            self.transition(to: .stopped(.completed))
            self.engine.invalidateProgressTimer()
            self.playbackProgress = 1
            // Use engine file duration (authoritative for audio) to avoid jump if
            // currentDuration was set from metadata (AVAsset.duration).
            // For video, engine.audioFile may be stale — use currentDuration.
            if self.currentMediaType == .audio, self.engine.currentFileDuration > 0 {
                self.currentTime = self.engine.currentFileDuration
            } else {
                self.currentTime = self.currentDuration
            }
            let action = self.nextTrack()
            switch action {
            case .requestCoordinatorPlayback(let track), .playLocally(let track):
                self.onPlaylistAdvanceRequest?(track)
            case .none:
                self.onPlaybackFinished?()
            default:
                break
            }
            if !self.isPlaying {
                self.engine.removeVisualizerTapIfNeeded()
            }
            self.seekGuardActive = false

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.isHandlingCompletion = false
            }
        }
    }

    // MARK: - Playlist Navigation

    enum PlaylistAdvanceAction {
        case none
        case restartCurrent
        case playLocally(Track)
        case requestCoordinatorPlayback(Track)
    }

    func updatePlaylistPosition(with track: Track?) {
        playlistController.updatePosition(with: track)
    }

    @discardableResult
    func nextTrack(isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        playlistController.updatePosition(with: currentTrack)
        let action = playlistController.nextTrack(isManualSkip: isManualSkip)
        return handlePlaylistAction(action)
    }

    @discardableResult
    func nextTrack(from track: Track?, isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        let action = playlistController.nextTrack(from: track, isManualSkip: isManualSkip)
        return handlePlaylistAction(action)
    }

    @discardableResult
    func previousTrack() -> PlaylistAdvanceAction {
        playlistController.updatePosition(with: currentTrack)
        let action = playlistController.previousTrack()
        return handlePlaylistAction(action)
    }

    @discardableResult
    func previousTrack(from track: Track?) -> PlaylistAdvanceAction {
        let action = playlistController.previousTrack(from: track)
        return handlePlaylistAction(action)
    }

    private func handlePlaylistAction(_ action: PlaylistController.AdvanceAction) -> PlaylistAdvanceAction {
        switch action {
        case .none:
            return .none
        case .restartCurrent:
            seek(to: 0, resume: true)
            return .restartCurrent
        case .playTrack(let track):
            playTrack(track: track)
            return .playLocally(track)
        case .requestCoordinatorPlayback(let track):
            return .requestCoordinatorPlayback(track)
        case .endOfPlaylist:
            return .none
        }
    }
}
