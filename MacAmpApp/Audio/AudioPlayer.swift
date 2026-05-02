// swiftlint:disable file_length
import Foundation
import AVFoundation
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
    var currentTrackURL: URL?
    var currentTitle: String = "No Track Loaded"
    var currentDuration: Double = 0.0
    var currentTime: Double = 0.0
    var playbackProgress: Double = 0.0

    // MARK: - Stream Bridge State (observable, updated via engine callback)
    private(set) var isBridgeActive: Bool = false

    /// True when the audio engine is running AND producing audio output.
    var isEngineRendering: Bool { engine.isEngineRunning && (isPlaying || isBridgeActive) }

    /// Audio volume (0.0-1.0 linear amplitude).
    ///
    /// Persistence is **call-site-driven** — call `commitVolumeToDefaults()`
    /// (or `PlaybackCoordinator.commitVolume()`) at gesture-end. The setter
    /// only propagates to audio backends; writing `UserDefaults` per gesture
    /// tick was shown to starve the main thread (mwvi Phase 0, Mechanism B).
    var volume: Float = 0.75 {
        didSet {
            engine?.setVolume(volume)
            videoPlaybackController.volume = volume
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

    // MARK: - Video Tap (S3-2 in-place DSP on AVPlayer audio path)

    /// One-tap-per-AVPlayerItem (ADR-7). Replaced when a new video item is
    /// loaded; cleared when transport stops or media type switches away
    /// from video. Attach kicks off asynchronously because the asset's
    /// audio tracks are loaded lazily; until attach completes the video
    /// plays without DSP (Phase 2 is pass-through anyway).
    @ObservationIgnored private var videoTapContext: VideoTapContext?

    /// Build a Context, store it, and kick off `VideoTap.attach` on a
    /// `MainActor` Task. Returns the Context immediately; attach failure
    /// is logged and the stored Context is cleared if it has not been
    /// replaced by a subsequent attach.
    @discardableResult
    func attachVideoTap(to playerItem: AVPlayerItem) -> VideoTapContext {
        let context = VideoTapContext()
        videoTapContext = context
        Task { @MainActor [weak self] in
            do {
                try await VideoTap.attach(to: playerItem, context: context)
            } catch {
                AppLog.error(.audio, "Video tap attach failed: \(error)")
                if self?.videoTapContext === context {
                    self?.videoTapContext = nil
                }
            }
        }
        return context
    }

    /// Detach the tap from the player item. AVPlayer's deallocation chain
    /// fires `tapFinalize` (possibly asynchronously) which releases the
    /// Context's +1 retain. The stored Context reference is cleared if it
    /// matches.
    func detachVideoTap(_ context: VideoTapContext, from playerItem: AVPlayerItem) {
        VideoTap.detach(from: playerItem)
        if videoTapContext === context {
            videoTapContext = nil
        }
    }

    /// Detach + clear the currently stored video tap Context, if any.
    /// Safe to call when no tap is attached.
    private func detachVideoTapIfNeeded() {
        guard let context = videoTapContext else { return }
        if let item = videoPlaybackController.player?.currentItem {
            detachVideoTap(context, from: item)
        } else {
            videoTapContext = nil
        }
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
        engine.onEngineWillReconfigure = { [weak self] snapshot in
            self?.handleEngineWillReconfigure(snapshot: snapshot)
        }
        engine.onEngineDidReconfigure = { [weak self] in
            self?.handleEngineDidReconfigure()
        }

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
                detachVideoTapIfNeeded()
                videoPlaybackController.cleanup()
                AppLog.debug(.audio, "Switching from video to audio - cleanup complete")
            } else if currentMediaType == .audio {
                engine.removeVisualizerTapIfNeeded()
                AppLog.debug(.audio, "Switching from audio to video - tap removed")
            }
        }

        currentMediaType = mediaType

        switch mediaType {
        case .audio:
            loadAudioFile(url: track.url)
        case .video:
            // Detach any prior tap before loadVideo internally drops the old player.
            detachVideoTapIfNeeded()
            videoPlaybackController.loadVideo(url: track.url, autoPlay: false)
            if let newItem = videoPlaybackController.player?.currentItem {
                attachVideoTap(to: newItem)
            }
            transition(to: .playing)
        }

        if equalizer.eqAutoEnabled {
            equalizer.applyAutoPreset(for: track)
        }

        play()
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
            detachVideoTapIfNeeded()
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
            wasStreamBridge: snapshot.wasStreamBridge
        )
        pendingReconfigureSnapshot = corrected
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
        guard let snapshot = pendingReconfigureSnapshot else { return }
        pendingReconfigureSnapshot = nil

        // 1. Re-apply volume + balance — engine nodes may have been recreated.
        engine.setVolume(volume)
        engine.setBalance(balance)

        // 2. Local-file path: ALWAYS reschedule from saved time, even when paused.
        //    play() does NOT itself reschedule (see line 417), so a subsequent
        //    play() would resume the now-detached pre-restart segment.
        if !snapshot.wasStreamBridge && engine.audioFile != nil {
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
        guard currentMediaType == .audio && isEngineRendering else { return nil }
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
