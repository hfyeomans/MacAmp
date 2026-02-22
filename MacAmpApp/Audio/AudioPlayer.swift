// swiftlint:disable file_length
import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class AudioPlayer { // swiftlint:disable:this type_body_length
    private enum Keys {
        static let volume = "volume"
        static let balance = "balance"
    }

    // AVAudioEngine-based playback - NOT observable (engine implementation details)
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let playerNode = AVAudioPlayerNode()
    @ObservationIgnored private var audioFile: AVAudioFile?
    @ObservationIgnored nonisolated(unsafe) private var progressTimer: Timer?  // nonisolated(unsafe) for deinit access
    @ObservationIgnored private var playheadOffset: Double = 0 // seconds offset for current scheduled segment

    // MARK: - Stream Loopback Bridge (Phase 2)
    @ObservationIgnored private var streamSourceNode: AVAudioSourceNode?
    @ObservationIgnored private var streamRingBuffer: LockFreeRingBuffer?
    /// Whether the stream loopback bridge is active (streamSourceNode connected to engine graph)
    private(set) var isBridgeActive: Bool = false

    // MARK: - Extracted Controllers
    private let equalizer = EqualizerController()
    private let visualizerPipeline = VisualizerPipeline()

    /// Legacy toggle - derives from AppSettings.visualizerMode (forwarded to pipeline)
    var useSpectrumVisualizer: Bool {
        get { AppSettings.instance().visualizerMode == .spectrum }
        set {
            AppSettings.instance().visualizerMode = newValue ? .spectrum : .none
            visualizerPipeline.useSpectrum = newValue  // Sync cached value to avoid per-frame lookup
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

    private(set) var playbackState: PlaybackState = .idle
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    /// True when the engine is running with either source (local file or stream bridge).
    /// Used by VisualizerView to gate visualization — replaces isPlaying for viz checks.
    var isEngineRendering: Bool { audioEngine.isRunning && (isPlaying || isBridgeActive) }
    @ObservationIgnored private var currentSeekID: UUID = UUID() // Identifies which seek operation scheduled the current audio
    @ObservationIgnored private var isHandlingCompletion = false // Prevents re-entrant onPlaybackEnded calls
    @ObservationIgnored private var seekGuardActive = false
    var currentTrackURL: URL? // Placeholder for the currently playing track
    var currentTitle: String = "No Track Loaded"
    var currentDuration: Double = 0.0
    var currentTime: Double = 0.0
    var playbackProgress: Double = 0.0 // New: 0.0 to 1.0

    /// Audio volume (0.0-1.0 linear amplitude).
    /// IMPORTANT: All external volume changes must go through PlaybackCoordinator.setVolume()
    /// to ensure all backends (audio, stream, video) stay in sync. Direct assignment to this
    /// property only updates playerNode and persists — it does NOT propagate to other backends.
    var volume: Float = 0.75 {
        didSet {
            playerNode.volume = volume
            streamSourceNode?.volume = volume
            UserDefaults.standard.set(volume, forKey: Keys.volume)
        }
    }
    var balance: Float = 0.0 { // -1.0 (left) to 1.0 (right)
        didSet {
            playerNode.pan = balance
            streamSourceNode?.pan = balance
            UserDefaults.standard.set(balance, forKey: Keys.balance)
        }
    }

    // Playlist management (extracted to separate controller)
    let playlistController = PlaylistController()

    // Computed forwarding for backwards compatibility
    var playlist: [Track] { playlistController.playlist }
    var currentTrack: Track? // Currently playing track (owned by AudioPlayer for playback state)
    /// Called when a placeholder track is replaced with loaded metadata (title/artist arrived)
    var onTrackMetadataUpdate: ((Track) -> Void)?
    /// Called when end-of-track auto-advance produces a track for the coordinator to play
    var onPlaylistAdvanceRequest: ((Track) -> Void)?
    var shuffleEnabled: Bool {
        get { playlistController.shuffleEnabled }
        set { playlistController.shuffleEnabled = newValue }
    }

    // Video playback support (extracted to VideoPlaybackController)
    let videoPlaybackController = VideoPlaybackController()
    var currentMediaType: MediaType = .audio

    // Computed forwarding for backwards compatibility
    var videoPlayer: AVPlayer? { videoPlaybackController.player }
    var videoMetadataString: String { videoPlaybackController.metadataString }

    enum MediaType {
        case audio  // MP3, FLAC, WAV, etc.
        case video  // MP4, MOV, M4V
    }

    /// Repeat mode (Winamp 5 Modern: off/all/one with "1" badge)
    /// Backed by AppSettings for persistence
    var repeatMode: AppSettings.RepeatMode {
        get { AppSettings.instance().repeatMode }
        set { AppSettings.instance().repeatMode = newValue }
    }

    // Equalizer forwarding (backed by EqualizerController)
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
    var channelCount: Int = 2 // 1 = mono, 2 = stereo
    var bitrate: Int = 0 // in kbps
    var sampleRate: Int = 0 // in Hz (will display as kHz)

    init() {
        if let saved = UserDefaults.standard.object(forKey: Keys.volume) as? Float {
            self.volume = saved
        }
        if let saved = UserDefaults.standard.object(forKey: Keys.balance) as? Float {
            self.balance = saved
        }

        setupEngine()
        // Note: EQ configuration handled by EqualizerController's init

        // Apply restored volume/balance to audio nodes
        playerNode.volume = volume
        playerNode.pan = balance

        // Sync initial visualizer mode to pipeline (avoids per-frame AppSettings lookup)
        visualizerPipeline.useSpectrum = AppSettings.instance().visualizerMode == .spectrum

        // Setup video playback callbacks
        videoPlaybackController.onPlaybackEnded = { [weak self] in
            Task { @MainActor in
                self?.onPlaybackEnded()
            }
        }
        videoPlaybackController.onTimeUpdate = { [weak self] time, duration, progress in
            guard let self else { return }
            // Sync UI-bound properties during video playback
            self.currentTime = time
            self.currentDuration = duration
            self.playbackProgress = progress
        }
        videoPlaybackController.volume = volume
    }

    deinit {
        // Invalidate progress timer if running
        progressTimer?.invalidate()

        // removeTap() asserts main queue (poll timer must invalidate on main).
        // deinit is nonisolated, so dispatch synchronously if already on main,
        // otherwise async (best-effort cleanup — tap will also be removed when
        // the mixer node is deallocated).
        let pipeline = visualizerPipeline
        if Thread.isMainThread {
            pipeline.removeTap()
        } else {
            DispatchQueue.main.async {
                pipeline.removeTap()
            }
        }

        // Video controller has its own deinit that calls cleanup()
    }

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
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
        }
        if self.isPaused != isPaused {
            self.isPaused = isPaused
        }
    }

    private func shouldIgnoreCompletion(from seekID: UUID?) -> Bool {
        if let seekID, seekID != currentSeekID {
            return true
        }
        if seekGuardActive && seekID == nil {
            return true
        }
        if case .stopped(let reason) = playbackState,
           reason == .manual || reason == .ejected {
            return true
        }
        return false
    }

    // MARK: - Track Management

    func addTrack(url: URL) {
        let normalizedURL = url.standardizedFileURL

        // Check for duplicates using playlistController
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

        let shouldAutoplay = currentTrack == nil

        playlistController.addPlaceholder(placeholder)

        if shouldAutoplay {
            playTrack(track: placeholder)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.playlistController.removePendingURL(normalizedURL) }

            AppLog.debug(.audio, "Loading metadata for \(normalizedURL.lastPathComponent)")
            let metadata = await MetadataLoader.loadTrackMetadata(from: normalizedURL)
            let track = Track(url: normalizedURL, title: metadata.title, artist: metadata.artist, duration: metadata.duration)
            AppLog.debug(.audio, "Metadata loaded - title: '\(track.title)', artist: '\(track.artist)', duration: \(track.duration)s")

            if self.playlistController.replacePlaceholder(id: placeholder.id, with: track) {
                if self.currentTrack?.id == placeholder.id {
                    AppLog.debug(.audio, "Updating current track metadata")
                    self.currentTrack = track
                    self.currentTitle = "\(track.title) - \(track.artist)"
                    self.currentDuration = track.duration
                    self.currentTrackURL = track.url

                    // Notify coordinator that metadata updated
                    self.onTrackMetadataUpdate?(track)
                }
            } else if !self.playlistController.containsTrack(url: normalizedURL) {
                self.playlistController.addTrack(track)
            }
        }
    }

    /// Add a stream track directly to the playlist (no metadata loading)
    func addStreamTrack(_ track: Track) {
        playlistController.addTrack(track)
    }

    /// Remove a track at the specified index
    func removeTrack(at index: Int) {
        playlistController.removeTrack(at: index)
    }

    /// Replace the entire playlist with the specified tracks
    func replacePlaylist(with tracks: [Track]) {
        playlistController.clear()
        for track in tracks {
            playlistController.addTrack(track)
        }
        AppLog.debug(.audio, "Replaced playlist with \(tracks.count) tracks")
    }

    /// Clear all tracks from the playlist
    func clearPlaylist() {
        playlistController.clear()
    }

    /// Play an EXISTING track from the playlist
    /// Does NOT modify the playlist - only plays the specified track
    func playTrack(track: Track) {
        // Guard against stream URLs - AudioPlayer can only play local files
        guard !track.isStream else {
            AppLog.error(.audio, "Cannot play internet radio streams. Stream URL: \(track.url). Use PlaybackCoordinator to route streams to StreamPlayer.")
            return
        }

        updatePlaylistPosition(with: track)

        // Invalidate seekID BEFORE stopping to prevent completion handler from re-scheduling audio
        currentSeekID = UUID()  // Invalidate any pending completion handlers
        seekGuardActive = true  // Extra protection

        // Don't call stop() here - it triggers completion handlers mid-transition
        // Instead, directly stop the player node and reset state
        playerNode.stop()
        progressTimer?.invalidate()

        // Clear seek guard after brief delay (matches seek() pattern)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
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
        playlistController.resetEnded()  // Reset playlist end flag

        AppLog.info(.audio, "Playing track '\(track.title)'")

        // Detect media type and route appropriately
        let mediaType = detectMediaType(url: track.url)

        // CRITICAL: Cleanup old media type BEFORE setting new one
        // This ensures proper cleanup when switching between audio and video
        if currentMediaType != mediaType {
            if currentMediaType == .video {
                // Switching FROM video to audio - cleanup video
                videoPlaybackController.cleanup()
                AppLog.debug(.audio, "Switching from video to audio - cleanup complete")
            } else if currentMediaType == .audio {
                // Switching FROM audio to video - remove visualizer tap
                removeVisualizerTapIfNeeded()
                AppLog.debug(.audio, "Switching from audio to video - tap removed")
            }
        }

        currentMediaType = mediaType

        switch mediaType {
        case .audio:
            loadAudioFile(url: track.url)
        case .video:
            // Delegate to VideoPlaybackController - don't auto-play yet, we call play() below
            videoPlaybackController.loadVideo(url: track.url, autoPlay: false)
            transition(to: .playing)
        }

        // Apply EQ auto preset if enabled
        if equalizer.eqAutoEnabled {
            equalizer.applyAutoPreset(for: track)
        }

        // Start playback
        play()
    }

    // Detect if URL is video or audio file
    private func detectMediaType(url: URL) -> MediaType {
        let videoExtensions = ["mp4", "mov", "m4v", "avi"]
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) ? .video : .audio
    }

    /// Private: Load audio file for playback (does NOT modify playlist)
    private func loadAudioFile(url: URL) {
        // Video cleanup now happens in playTrack() BEFORE calling this
        // currentMediaType is already set to .audio by playTrack()

        do {
            audioFile = try AVAudioFile(forReading: url)
            rewireForCurrentFile()
            currentSeekID = UUID()
            _ = scheduleFrom(time: 0, seekID: currentSeekID)
            playerNode.volume = volume
            playerNode.pan = balance

            // Update audio properties asynchronously
            Task { @MainActor [weak self] in
                if let props = await MetadataLoader.loadAudioProperties(from: url) {
                    self?.channelCount = props.channelCount
                    self?.bitrate = props.bitrate
                    self?.sampleRate = props.sampleRate
                }
            }
        } catch {
            AppLog.error(.audio, "Failed to open file: \(error)")
        }
    }

    func play() {
        // If playlist has ended, restart from the beginning
        if playlistController.hasEnded && !playlist.isEmpty {
            playTrack(track: playlist[0])
            return
        }

        // Handle video playback
        if currentMediaType == .video {
            videoPlaybackController.play()
            transition(to: .playing)
            AppLog.debug(.audio, "Play (Video)")
            return
        }

        // Audio playback
        guard let file = audioFile else {
            AppLog.warn(.audio, "No track loaded to play.")
            return
        }

        // Check if we're at the end of the track (within 0.01s threshold)
        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate
        if currentTime >= fileDuration - 0.01 {
            // We're at the end - move to next track instead of trying to play
            onPlaybackEnded()
            return
        }

        startEngineIfNeeded()
        installVisualizerTapIfNeeded()
        if !playerNode.isPlaying {
            playerNode.play()
        }
        startProgressTimer()
        transition(to: .playing)
        seekGuardActive = false
        AppLog.debug(.audio, "Play")
    }

    func pause() {
        // Handle video playback
        if currentMediaType == .video {
            videoPlaybackController.pause()
            transition(to: .paused)
            AppLog.debug(.audio, "Pause (Video)")
            return
        }

        // Audio playback
        guard playerNode.isPlaying else { return }
        playerNode.pause()
        removeVisualizerTapIfNeeded()
        transition(to: .paused)
        seekGuardActive = false
        AppLog.debug(.audio, "Pause")
    }

    func stop() {
        transition(to: .stopped(.manual))

        // Handle video playback cleanup
        if currentMediaType == .video {
            videoPlaybackController.stop()
            currentMediaType = .audio
            AppLog.debug(.audio, "Stop (Video) - cleaned up AVPlayer")
        }

        // Audio playback cleanup
        playerNode.stop()
        currentSeekID = UUID()
        _ = scheduleFrom(time: 0, seekID: currentSeekID)  // Ignore return - reset to beginning

        // Clear currentTrack so UI doesn't show stale info during stream playback
        currentTrack = nil
        currentTitle = "No Track Loaded"
        currentTrackURL = nil
        currentDuration = 0.0

        currentTime = 0
        playbackProgress = 0
        progressTimer?.invalidate()
        removeVisualizerTapIfNeeded()

        // Reset audio properties
        bitrate = 0
        sampleRate = 0
        channelCount = 2

        seekGuardActive = false
        AppLog.debug(.audio, "Stop")
    }

    func eject() {
        stop()
        transition(to: .stopped(.ejected))
        playlistController.clear()
        currentTrack = nil
        currentTrackURL = nil
        currentTitle = "No Track Loaded"
        currentDuration = 0.0
        currentTime = 0.0
        playbackProgress = 0.0
        appliedAutoPresetTrack = nil
        audioFile = nil
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

    // MARK: - Engine Wiring
    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(equalizer.eqNode)
        // Do not start the engine here; start after the graph is connected
        // to avoid AVAudioEngineGraph initialize assertions on some macOS versions.
    }

    private func rewireForCurrentFile() {
        // Stop the engine and reset it before rewiring to avoid format conflicts
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        // Disconnect and reconnect graph for the file's format
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(equalizer.eqNode)
        // Also disconnect stream source node if it was connected
        if let node = streamSourceNode {
            audioEngine.disconnectNodeOutput(node)
        }

        guard audioFile != nil else { return }

        // Connect with the new format - use nil format to let the engine determine the best format
        audioEngine.connect(playerNode, to: equalizer.eqNode, format: nil)
        audioEngine.connect(equalizer.eqNode, to: audioEngine.mainMixerNode, format: nil)

        // Verify mixer→output connection after reset (lesson #4: may break silently)
        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        // Prepare the engine with the new configuration
        audioEngine.prepare()

        // Restart the engine with the new configuration
        startEngineIfNeeded()
        installVisualizerTapIfNeeded()
        isBridgeActive = false
    }

    // MARK: - Stream Loopback Bridge (2.3, 2.4a-c)

    /// Build the render block in a nonisolated context to avoid @MainActor isolation on audio thread.
    /// Follows VisualizerPipeline.makeTapHandler() pattern — lesson learned #1.
    private nonisolated static func makeStreamRenderBlock(
        ringBuffer: LockFreeRingBuffer
    ) -> AVAudioSourceNodeRenderBlock {
        // 2.7c: Capture generation at creation for ABR detection
        let lastGeneration = ringBuffer.currentGeneration()
        // Use nonisolated(unsafe) var for the mutable generation tracker
        // This is safe: only accessed from the single render thread (SPSC consumer)
        nonisolated(unsafe) var cachedGeneration = lastGeneration

        return { isSilence, _, frameCount, audioBufferList -> OSStatus in
            // 2.2h + 2.7c: Real-time safe — zero allocations, zero locks, zero ARC, zero logging

            // Check generation ID for ABR format changes (2.7c)
            let currentGen = ringBuffer.currentGeneration()
            if currentGen != cachedGeneration {
                // Format changed — fill silence during transition (2.7d: acceptable for radio)
                cachedGeneration = currentGen
                let ablPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for i in 0..<ablPtr.count {
                    if let data = ablPtr[i].mData {
                        memset(data, 0, Int(ablPtr[i].mDataByteSize))
                    }
                }
                isSilence.pointee = true
                return noErr
            }

            // Read from ring buffer directly into audioBufferList (interleaved format match)
            let ablPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard ablPtr.count == 1,
                  let data = ablPtr[0].mData?.assumingMemoryBound(to: Float.self) else {
                isSilence.pointee = true
                return noErr
            }

            let framesRead = ringBuffer.read(into: data, frameCount: Int(frameCount))

            if framesRead < Int(frameCount) {
                // Fill remaining with silence to prevent glitches
                let silenceStart = framesRead * ringBuffer.channelCount
                let silenceCount = (Int(frameCount) - framesRead) * ringBuffer.channelCount
                memset(data + silenceStart, 0, silenceCount * MemoryLayout<Float>.size)
                if framesRead == 0 {
                    isSilence.pointee = true
                }
            }

            return noErr
        }
    }

    /// Activate stream bridge: wire streamSourceNode into engine graph.
    /// Called by PlaybackCoordinator when starting stream playback.
    /// Follows rewireForCurrentFile() stop/reset pattern (lesson #3).
    func activateStreamBridge(ringBuffer: LockFreeRingBuffer, sampleRate: Float64) {
        streamRingBuffer = ringBuffer

        // Build render block via nonisolated static func (lesson #1: no @MainActor isolation)
        let renderBlock = Self.makeStreamRenderBlock(ringBuffer: ringBuffer)

        // Source node block format: interleaved at stream sample rate (lesson #2)
        guard let blockFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: true
        ) else { return }

        let sourceNode = AVAudioSourceNode(format: blockFormat, renderBlock: renderBlock)

        // Stop/reset engine before rewiring (lesson #3: hot-swap causes -10868)
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        // Disconnect old source nodes
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(equalizer.eqNode)
        if let oldNode = streamSourceNode {
            audioEngine.disconnectNodeOutput(oldNode)
            audioEngine.detach(oldNode)
        }

        // Attach and connect new source node
        audioEngine.attach(sourceNode)

        // Graph format: non-interleaved at device sample rate (lesson #2)
        let deviceFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        let graphFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: deviceFormat.sampleRate,
            channels: 2,
            interleaved: false
        )

        audioEngine.connect(sourceNode, to: equalizer.eqNode, format: graphFormat)
        audioEngine.connect(equalizer.eqNode, to: audioEngine.mainMixerNode, format: nil)

        // Verify mixer→output connection after reset (lesson #4)
        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        streamSourceNode = sourceNode

        // Apply current volume and balance to stream source node
        sourceNode.volume = volume
        sourceNode.pan = balance

        // Start engine
        audioEngine.prepare()
        startEngineIfNeeded()
        installVisualizerTapIfNeeded()
        isBridgeActive = true
    }

    /// Deactivate stream bridge: disconnect streamSourceNode, rewire playerNode back.
    /// Called by PlaybackCoordinator when stopping stream or switching to local file.
    func deactivateStreamBridge() {
        guard isBridgeActive else { return }

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }

        if let node = streamSourceNode {
            audioEngine.disconnectNodeOutput(node)
            audioEngine.detach(node)
        }
        audioEngine.disconnectNodeOutput(equalizer.eqNode)

        // Reconnect playerNode → eqNode → mixer for local file path
        audioEngine.connect(playerNode, to: equalizer.eqNode, format: nil)
        audioEngine.connect(equalizer.eqNode, to: audioEngine.mainMixerNode, format: nil)

        // Verify mixer→output connection after reset (lesson #4)
        if audioEngine.outputConnectionPoints(for: audioEngine.mainMixerNode, outputBus: 0).isEmpty {
            audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        }

        audioEngine.prepare()

        streamSourceNode = nil
        streamRingBuffer = nil
        isBridgeActive = false

        removeVisualizerTapIfNeeded()
        visualizerPipeline.clearData()
    }

    /// Schedules audio playback from a specific time
    /// Returns: true if audio was scheduled, false if track ended
    private func scheduleFrom(time: Double, seekID: UUID? = nil) -> Bool {
        guard let file = audioFile else {
            AppLog.warn(.audio, "scheduleFrom: No audio file loaded")
            return false
        }

        let sampleRate = file.processingFormat.sampleRate

        // FIX: Use file.length directly instead of currentDuration
        // This eliminates race condition with async track loading
        let fileDuration = Double(file.length) / sampleRate

        // SPECIAL CASE: If seeking to or past the end (within 0.01s threshold), trigger completion immediately
        // This prevents frame calculation wrap-around issues when time == fileDuration exactly
        if time >= fileDuration - 0.01 {
            playheadOffset = fileDuration
            playerNode.stop()

            // Don't call onPlaybackEnded here - let seek() handle track completion
            // Instead, just return false to signal no audio was scheduled
            return false  // No audio scheduled - track ended
        }

        let startFrame = AVAudioFramePosition(max(0, min(time, fileDuration)) * sampleRate)

        let totalFrames = file.length
        let framesRemaining = max(0, totalFrames - startFrame)

        // Store the new starting time for progress tracking
        playheadOffset = Double(startFrame) / sampleRate

        // Stop the player and clear existing buffers
        playerNode.stop()

        // Schedule the new segment if there's audio left to play
        if framesRemaining > 0 {
            // Capture the seek ID to identify this completion (defaults to currentSeekID)
            let completionID = seekID ?? currentSeekID
            playerNode.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(framesRemaining),
                at: nil,
                completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.onPlaybackEnded(fromSeekID: completionID)
                    }
                }
            )

            // Ensure we have currentDuration for UI (non-critical for seeking)
            if fileDuration.isFinite && fileDuration > 0 {
                Task { @MainActor in
                    self.currentDuration = fileDuration
                }
            }

            return true  // Audio was scheduled successfully
        } else {
            onPlaybackEnded()
            return false  // No audio scheduled - track ended
        }
    }

    private func startEngineIfNeeded() {
        if !audioEngine.isRunning {
            audioEngine.prepare()
            do { try audioEngine.start() } catch { AppLog.error(.audio, "AudioEngine start error: \(error)") }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset
                    self.currentTime = current
                    if self.currentDuration > 0 {
                        let newProgress = current / self.currentDuration
                        self.playbackProgress = newProgress
                    } else {
                        self.playbackProgress = 0
                    }
                }
            }
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Visualizer Tap (delegated to VisualizerPipeline)

    private func installVisualizerTapIfNeeded() {
        guard !visualizerPipeline.isTapInstalled else { return }
        visualizerPipeline.installTap(on: audioEngine.mainMixerNode)
    }

    private func removeVisualizerTapIfNeeded() {
        visualizerPipeline.removeTap()
        visualizerPipeline.clearData()
    }

    // MARK: - Seeking / Scrubbing

    /// Seek to a percentage of the track (0.0 to 1.0)
    /// This method calculates time using file.length directly, avoiding race conditions
    func seekToPercent(_ percent: Double, resume: Bool? = nil) {
        // VIDEO SEEKING - delegate to VideoPlaybackController
        if currentMediaType == .video {
            videoPlaybackController.seekToPercent(percent, resume: resume) { [weak self] (actualTime: Double) in
                Task { @MainActor in
                    guard let self else { return }
                    self.currentTime = actualTime
                    self.playbackProgress = self.videoPlaybackController.progress
                    self.currentDuration = self.videoPlaybackController.duration
                    self.transition(to: self.videoPlaybackController.isPlaying ? .playing : .paused)
                }
            }
            return
        }

        // AUDIO SEEKING
        guard let file = audioFile else {
            AppLog.warn(.audio, "seekToPercent: No audio file loaded")
            return
        }

        // Calculate target time using file.length directly (no dependency on currentDuration)
        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate
        let targetTime = percent * fileDuration

        // Use regular seek with the calculated time
        seek(to: targetTime, resume: resume)
    }

    func seek(to time: Double, resume: Bool? = nil) {
        // VIDEO SEEKING - delegate to VideoPlaybackController
        if currentMediaType == .video {
            videoPlaybackController.seek(to: time, resume: resume) { [weak self] (actualTime: Double) in
                Task { @MainActor in
                    guard let self else { return }
                    self.currentTime = actualTime
                    self.playbackProgress = self.videoPlaybackController.progress
                    self.currentDuration = self.videoPlaybackController.duration
                    self.transition(to: self.videoPlaybackController.isPlaying ? .playing : .paused)
                }
            }
            return
        }

        // AUDIO SEEKING
        // Guard: Ensure file is loaded before seeking
        guard let file = audioFile else {
            AppLog.warn(.audio, "seek: Cannot seek - no audio file loaded")
            return
        }

        let shouldPlay = resume ?? isPlaying
        seekGuardActive = true

        // CRITICAL FIX: Activate seek guard to prevent old completion handlers from corrupting state.
        // When playerNode.stop() is called in scheduleFrom, it triggers the completion handler
        // from the PREVIOUS segment, which calls onPlaybackEnded() and sets playbackProgress=1.0
        // Generate new seek ID to identify completions from THIS seek operation
        currentSeekID = UUID()

        // Stop progress timer BEFORE seeking
        progressTimer?.invalidate()

        // Calculate playbackProgress using file duration directly BEFORE scheduling
        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate
        let targetProgress = fileDuration > 0 ? time / fileDuration : 0

        // Schedule the new audio segment - returns false if track ended
        // Pass current seek ID so completion handler can identify itself
        let audioScheduled = scheduleFrom(time: time, seekID: currentSeekID)

        // Update state AFTER scheduling to ensure consistency
        currentTime = time
        playbackProgress = targetProgress

        // CRITICAL: Only start playback if audio was actually scheduled
        // If scheduleFrom returned false, it means we sought to the end
        if audioScheduled && shouldPlay {
            startEngineIfNeeded()
            installVisualizerTapIfNeeded()
            playerNode.play()
            startProgressTimer()  // Restart timer with fresh state
            transition(to: .playing)
        } else if !audioScheduled {
            // No audio scheduled - we're at the end of the track
            transition(to: .stopped(.completed))
            // Timer already invalidated above

            // Trigger track completion logic after the seek guard is cleared
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                // Now safe to call onPlaybackEnded once seek guard is relaxed
                self?.onPlaybackEnded()
            }
        } else {
            transition(to: .paused)
            // Timer already invalidated above
        }

        // Clear seek guard after a brief delay to allow old completion handler to fire and be ignored
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            self?.seekGuardActive = false
        }
    }
    
    // MARK: - Visualizer Forwarding (backed by VisualizerPipeline)

    func getFrequencyData(bands: Int) -> [Float] {
        visualizerPipeline.getFrequencyData(bands: bands, isPlaying: isEngineRendering)
    }

    func getRMSData(bands: Int) -> [Float] {
        visualizerPipeline.getRMSData(bands: bands)
    }

    func getWaveformSamples(count: Int) -> [Float] {
        visualizerPipeline.getWaveformSamples(count: count)
    }

    func snapshotButterchurnFrame() -> ButterchurnFrame? {
        guard currentMediaType == .audio && isEngineRendering else { return nil }
        return visualizerPipeline.snapshotButterchurnFrame()
    }

    private func onPlaybackEnded(fromSeekID: UUID? = nil) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // CRITICAL: Prevent re-entrant calls (infinite loop protection)
            guard !self.isHandlingCompletion else { return }

            // CRITICAL: Don't process completion if it's from an old seek operation
            // playerNode.stop() triggers the old segment's completion handler
            // But allow completions from the CURRENT seek operation (matching seekID)
            if self.shouldIgnoreCompletion(from: fromSeekID) {
                return
            }

            // Set re-entrancy guard
            self.isHandlingCompletion = true

            self.transition(to: .stopped(.completed))
            self.progressTimer?.invalidate()
            self.playbackProgress = 1
            self.currentTime = self.currentDuration
            let action = self.nextTrack()
            switch action {
            case .requestCoordinatorPlayback(let track), .playLocally(let track):
                self.onPlaylistAdvanceRequest?(track)
            default:
                break
            }
            if !self.isPlaying {
                self.removeVisualizerTapIfNeeded()
            }
            self.seekGuardActive = false

            // Clear re-entrancy guard after nextTrack completes
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.isHandlingCompletion = false
            }
        }
    }

    // MARK: - Playlist navigation

    /// Action types returned by playlist navigation (for PlaybackCoordinator)
    enum PlaylistAdvanceAction {
        case none
        case restartCurrent
        case playLocally(Track)
        case requestCoordinatorPlayback(Track)
    }

    /// Update playlist position after playing a track
    func updatePlaylistPosition(with track: Track?) {
        playlistController.updatePosition(with: track)
    }

    /// Advance to next track in playlist
    /// - Parameter isManualSkip: Whether this is a user-initiated skip (affects repeat-one behavior)
    /// - Returns: Action for PlaybackCoordinator to handle
    @discardableResult
    func nextTrack(isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        // Sync current track with playlistController before navigation
        playlistController.updatePosition(with: currentTrack)

        let action = playlistController.nextTrack(isManualSkip: isManualSkip)
        return handlePlaylistAction(action)
    }

    /// Advance to next track with external position context.
    /// Used by PlaybackCoordinator when audioPlayer.currentTrack is nil (e.g., during stream playback).
    /// - Parameters:
    ///   - track: External track for position resolution (typically coordinator's currentTrack)
    ///   - isManualSkip: Whether this is a user-initiated skip
    /// - Returns: Action for PlaybackCoordinator to handle
    @discardableResult
    func nextTrack(from track: Track?, isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        let action = playlistController.nextTrack(from: track, isManualSkip: isManualSkip)
        return handlePlaylistAction(action)
    }

    /// Go to previous track in playlist
    /// - Returns: Action for PlaybackCoordinator to handle
    @discardableResult
    func previousTrack() -> PlaylistAdvanceAction {
        // Sync current track with playlistController before navigation
        playlistController.updatePosition(with: currentTrack)

        let action = playlistController.previousTrack()
        return handlePlaylistAction(action)
    }

    /// Go to previous track with external position context.
    /// Used by PlaybackCoordinator when audioPlayer.currentTrack is nil (e.g., during stream playback).
    /// - Parameter track: External track for position resolution (typically coordinator's currentTrack)
    /// - Returns: Action for PlaybackCoordinator to handle
    @discardableResult
    func previousTrack(from track: Track?) -> PlaylistAdvanceAction {
        let action = playlistController.previousTrack(from: track)
        return handlePlaylistAction(action)
    }

    /// Handle action returned from PlaylistController
    private func handlePlaylistAction(_ action: PlaylistController.AdvanceAction) -> PlaylistAdvanceAction {
        switch action {
        case .none:
            return .none

        case .restartCurrent:
            // Always resume: repeat-one at end-of-track means "restart and play"
            // (isPlaying is already false after onPlaybackEnded transition)
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
