// swiftlint:disable file_length
import Foundation
import Combine
import AVFoundation
import Accelerate
import Observation

// Helper to convert FourCC codes to strings
extension String {
    init(fourCC: FourCharCode) {
        let bytes = [
            UInt8((fourCC >> 24) & 0xFF),
            UInt8((fourCC >> 16) & 0xFF),
            UInt8((fourCC >> 8) & 0xFF),
            UInt8(fourCC & 0xFF)
        ]
        self = String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

// VisualizerScratchBuffers, VisualizerSharedBuffer, and ButterchurnFrame
// have been extracted to VisualizerPipeline.swift

// Track, PlaybackStopReason, and PlaybackState have been extracted to Models/Track.swift

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
    @ObservationIgnored private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    @ObservationIgnored private var audioFile: AVAudioFile?
    @ObservationIgnored nonisolated(unsafe) private var progressTimer: Timer?  // nonisolated(unsafe) for deinit access
    @ObservationIgnored private var playheadOffset: Double = 0 // seconds offset for current scheduled segment

    // MARK: - Extracted Controllers
    let visualizerPipeline = VisualizerPipeline()

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
    @ObservationIgnored private var currentSeekID: UUID = UUID() // Identifies which seek operation scheduled the current audio
    @ObservationIgnored private var isHandlingCompletion = false // Prevents re-entrant onPlaybackEnded calls
    @ObservationIgnored private var seekGuardActive = false
    @ObservationIgnored private var autoEQTask: Task<Void, Never>?
    var currentTrackURL: URL? // Placeholder for the currently playing track
    var currentTitle: String = "No Track Loaded"
    var currentDuration: Double = 0.0
    var currentTime: Double = 0.0
    var playbackProgress: Double = 0.0 // New: 0.0 to 1.0

    var volume: Float = 0.75 { // 0.0 to 1.0
        didSet {
            playerNode.volume = volume
            videoPlaybackController.volume = volume
            UserDefaults.standard.set(volume, forKey: Keys.volume)
        }
    }
    var balance: Float = 0.0 { // -1.0 (left) to 1.0 (right)
        didSet {
            playerNode.pan = balance
            UserDefaults.standard.set(balance, forKey: Keys.balance)
        }
    }

    // Playlist management (extracted to separate controller)
    let playlistController = PlaylistController()

    // Computed forwarding for backwards compatibility
    var playlist: [Track] { playlistController.playlist }
    var currentTrack: Track? // Currently playing track (owned by AudioPlayer for playback state)
    var externalPlaybackHandler: ((Track) -> Void)?
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

    // Equalizer properties
    var preamp: Float = 0.0 // -12.0 to 12.0 dB (typical range)
    var eqBands: [Float] = Array(repeating: 0.0, count: 10) // 10 bands, -12.0 to 12.0 dB
    var isEqOn: Bool = false // New: EQ On/Off state
    var eqAutoEnabled: Bool = false
    var useLogScaleBands: Bool = true
    // EQ preset persistence (extracted to separate store)
    let eqPresetStore = EQPresetStore()

    // Computed forwarding for backwards compatibility
    var userPresets: [EQPreset] { eqPresetStore.userPresets }
    var visualizerLevels: [Float] { visualizerPipeline.levels }
    var appliedAutoPresetTrack: String?
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
        configureEQ()
        // Note: eqPresetStore loads presets in its own init

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
        // Ensure visualizer tap and poll timer are stopped
        visualizerPipeline.removeTap()

        // Invalidate progress timer if running
        progressTimer?.invalidate()

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
                    self.externalPlaybackHandler?(track)
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
        if eqAutoEnabled {
            applyAutoPreset(for: track)
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

    // Equalizer control methods
    func setPreamp(value: Float) {
        preamp = value
        eqNode.globalGain = value
        // Ensure EQ is enabled when adjusting preamp
        if !isEqOn && value != 0 {
            toggleEq(isOn: true)
        }
        AppLog.debug(.audio, "Set Preamp to \(value), EQ is \(isEqOn ? "ON" : "OFF")")
    }

    func setEqBand(index: Int, value: Float) {
        guard index >= 0 && index < eqBands.count else { return }
        eqBands[index] = value
        eqNode.bands[index].gain = value
        AppLog.debug(.audio, "Set EQ Band \(index) to \(value)")
    }

    func toggleEq(isOn: Bool) {
        isEqOn = isOn
        eqNode.bypass = !isOn
        AppLog.debug(.audio, "EQ is now \(isOn ? "On" : "Off")")
    }

    // Presets
    func applyPreset(_ preset: EqfPreset) {
        setPreamp(value: preset.preampDB)
        for (i, g) in preset.bandsDB.enumerated() { setEqBand(index: i, value: g) }
        toggleEq(isOn: true)
    }

    func applyEQPreset(_ preset: EQPreset) {
        setPreamp(value: preset.preamp)
        for (i, g) in preset.bands.enumerated() { setEqBand(index: i, value: g) }
        toggleEq(isOn: true)
        AppLog.info(.audio, "Applied EQ preset: \(preset.name)")
    }

    func getCurrentEQPreset(name: String) -> EQPreset {
        return EQPreset(name: name, preamp: preamp, bands: Array(eqBands))
    }

    func saveUserPreset(named rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let preset = getCurrentEQPreset(name: trimmedName)
        eqPresetStore.storeUserPreset(preset)
        AppLog.info(.audio, "Saved user EQ preset '\(trimmedName)'")
    }

    func deleteUserPreset(id: UUID) {
        eqPresetStore.deleteUserPreset(id: id)
    }

    func importEqfPreset(from url: URL) {
        Task { [weak self] in
            guard let self = self else { return }
            if let preset = await self.eqPresetStore.importEqfPreset(from: url) {
                self.applyEQPreset(preset)
            }
        }
    }

    func savePresetForCurrentTrack() {
        guard let t = currentTrack else { return }
        let p = EqfPreset(name: t.title, preampDB: preamp, bandsDB: eqBands)
        eqPresetStore.savePreset(p, forTrackURL: t.url.absoluteString)
        AppLog.debug(.audio, "Saved per-track EQ preset for \(t.title)")
    }

    private func applyAutoPreset(for track: Track) {
        guard eqAutoEnabled else { return }
        if let preset = eqPresetStore.preset(forTrackURL: track.url.absoluteString) {
            applyPreset(preset)
            appliedAutoPresetTrack = track.title
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self = self else { return }
                if self.appliedAutoPresetTrack == track.title {
                    self.appliedAutoPresetTrack = nil
                }
            }
            AppLog.debug(.audio, "Applied per-track EQ preset for \(track.title)")
        } else {
            generateAutoPreset(for: track)
        }
    }

    func setAutoEQEnabled(_ isEnabled: Bool) {
        guard eqAutoEnabled != isEnabled else { return }
        eqAutoEnabled = isEnabled
        if isEnabled, let current = currentTrack {
            applyAutoPreset(for: current)
        } else {
            autoEQTask?.cancel()
            autoEQTask = nil
            appliedAutoPresetTrack = nil
        }
    }

    private func generateAutoPreset(for track: Track) {
        autoEQTask?.cancel()
        autoEQTask = nil
        AppLog.debug(.audio, "AutoEQ: automatic analysis disabled, no preset generated for \(track.title)")
    }

    // MARK: - Engine Wiring
    private func setupEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eqNode)
        // Do not start the engine here; start after the graph is connected
        // to avoid AVAudioEngineGraph initialize assertions on some macOS versions.
    }

    private func configureEQ() {
        // Winamp 10-band centers (Hz): 60,170,310,600,1k,3k,6k,12k,14k,16k
        let freqs: [Float] = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]
        for i in 0..<min(eqNode.bands.count, freqs.count) {
            let band = eqNode.bands[i]
            if i == 0 {
                band.filterType = .lowShelf
            } else if i == freqs.count - 1 {
                band.filterType = .highShelf
            } else {
                band.filterType = .parametric
            }
            band.frequency = freqs[i]
            band.bandwidth = 1.0 // Octaves for parametric; harmless for shelves
            band.gain = eqBands[i]
            band.bypass = false
        }
        eqNode.globalGain = preamp
        eqNode.bypass = !isEqOn
    }

    private func rewireForCurrentFile() {
        // Stop the engine and reset it before rewiring to avoid format conflicts
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
        }
        
        // Disconnect and reconnect graph for the file's format
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(eqNode)
        
        guard audioFile != nil else { return }
        
        // Connect with the new format - use nil format to let the engine determine the best format
        audioEngine.connect(playerNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Prepare the engine with the new configuration
        audioEngine.prepare()
        
        // Restart the engine with the new configuration
        startEngineIfNeeded()
        installVisualizerTapIfNeeded()
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
    
    // MARK: - Visualizer Support

    func getFrequencyData(bands: Int) -> [Float] {
        // Return normalized frequency data for spectrum analyzer
        // Map our 20 visualizer levels to the requested number of bands
        guard bands > 0 else { return [] }
        
        var result = [Float](repeating: 0, count: bands)
        
        if isPlaying && !visualizerLevels.isEmpty {
            // Map visualizer levels to requested bands with logarithmic scaling
            let sourceCount = visualizerLevels.count
            
            for i in 0..<bands {
                // Map band index to source index
                let sourceIndex = (i * sourceCount) / bands
                let nextIndex = min(sourceIndex + 1, sourceCount - 1)
                
                // Interpolate between source values for smoother visualization
                let fraction = Float(i * sourceCount % bands) / Float(bands)
                let value1 = visualizerLevels[sourceIndex]
                let value2 = visualizerLevels[nextIndex]
                
                // Interpolate and apply logarithmic scaling for better perception
                let interpolated = value1 * (1 - fraction) + value2 * fraction
                
                // Apply logarithmic scaling to make quiet sounds more visible
                // This mimics how human hearing perceives sound levels
                let scaled = log10(1.0 + interpolated * 9.0) // Maps 0-1 to log scale
                
                // Normalize to 0-1 range with slight boost
                result[i] = min(1.0, max(0.0, scaled * 0.8))
            }
        } else if isPlaying {
            // Provide some minimal random movement when no data available
            for i in 0..<bands {
                result[i] = Float.random(in: 0.0...0.1)
            }
        }
        
        return result
    }

    /// Get RMS data mapped to requested number of bands (forwarded to VisualizerPipeline)
    func getRMSData(bands: Int) -> [Float] {
        visualizerPipeline.getRMSData(bands: bands)
    }

    /// Get waveform samples resampled to requested count (forwarded to VisualizerPipeline)
    func getWaveformSamples(count: Int) -> [Float] {
        visualizerPipeline.getWaveformSamples(count: count)
    }

    // MARK: - Butterchurn Audio Data

    /// Thread-safe snapshot of current Butterchurn audio data
    /// Returns nil if not playing local audio (video or stream playback)
    /// Called by ButterchurnBridge at 30 FPS to push data to JavaScript
    func snapshotButterchurnFrame() -> ButterchurnFrame? {
        // Only return data for local audio playback via AVAudioEngine
        // Video uses AVPlayer (no tap), streams use StreamPlayer (no PCM access)
        guard currentMediaType == .audio && isPlaying else { return nil }

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
                self.externalPlaybackHandler?(track)
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

    /// Go to previous track in playlist
    /// - Returns: Action for PlaybackCoordinator to handle
    @discardableResult
    func previousTrack() -> PlaylistAdvanceAction {
        // Sync current track with playlistController before navigation
        playlistController.updatePosition(with: currentTrack)

        let action = playlistController.previousTrack()
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
