
import Foundation
import Combine
import AVFoundation
import Accelerate

private final class VisualizerScratchBuffers {
    private(set) var mono: [Float] = []
    private(set) var rms: [Float] = []
    private(set) var spectrum: [Float] = []

    func prepare(frameCount: Int, bars: Int) {
        if mono.count != frameCount {
            mono = Array(repeating: 0, count: frameCount)
        } else {
            mono.withUnsafeMutableBufferPointer { pointer in
                guard let baseAddress = pointer.baseAddress else { return }
                vDSP_vclr(baseAddress, 1, vDSP_Length(frameCount))
            }
        }

        if rms.count != bars {
            rms = Array(repeating: 0, count: bars)
        }

        if spectrum.count != bars {
            spectrum = Array(repeating: 0, count: bars)
        }
    }

    func withMono<R>(_ body: (inout [Float]) -> R) -> R {
        body(&mono)
    }

    func withMonoReadOnly<R>(_ body: ([Float]) -> R) -> R {
        body(mono)
    }

    func withRms<R>(_ body: (inout [Float]) -> R) -> R {
        body(&rms)
    }

    func withSpectrum<R>(_ body: (inout [Float]) -> R) -> R {
        body(&spectrum)
    }

    func snapshotRms() -> [Float] {
        rms
    }

    func snapshotSpectrum() -> [Float] {
        spectrum
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

struct Track: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var title: String
    var artist: String
    var duration: Double

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

enum PlaybackStopReason: Equatable {
    case manual
    case completed
    case ejected
}

enum PlaybackState: Equatable {
    case idle
    case preparing
    case playing
    case paused
    case stopped(PlaybackStopReason)
}

@MainActor
class AudioPlayer: ObservableObject {
    // AVAudioEngine-based playback
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var playheadOffset: Double = 0 // seconds offset for current scheduled segment
    private var visualizerTapInstalled = false
    private var visualizerPeaks: [Float] = Array(repeating: 0.0, count: 20)
    private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    @Published var useSpectrumVisualizer: Bool = true
    @Published var visualizerSmoothing: Float = 0.6 // 0..1 (higher = smoother)
    @Published var visualizerPeakFalloff: Float = 1.2 // units per second

    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    private var currentSeekID: UUID = UUID() // Identifies which seek operation scheduled the current audio
    private var isHandlingCompletion = false // Prevents re-entrant onPlaybackEnded calls
    private var trackHasEnded = false // Tracks when playlist has finished
    private var seekGuardActive = false
    private var autoEQTask: Task<Void, Never>?
    private var pendingTrackURLs = Set<URL>()
    @Published var currentTrackURL: URL? // Placeholder for the currently playing track
    @Published var currentTitle: String = "No Track Loaded"
    @Published var currentDuration: Double = 0.0
    @Published var currentTime: Double = 0.0
    @Published var playbackProgress: Double = 0.0 // New: 0.0 to 1.0

    @Published var volume: Float = 1.0 { // 0.0 to 1.0
        didSet { playerNode.volume = volume }
    }
    @Published var balance: Float = 0.0 { // -1.0 (left) to 1.0 (right)
        didSet { playerNode.pan = balance }
    }

    @Published var playlist: [Track] = [] // New: List of tracks
    @Published var currentTrack: Track? // New: Currently playing track
    @Published var shuffleEnabled: Bool = false
    @Published var repeatEnabled: Bool = false

    // Equalizer properties
    @Published var preamp: Float = 0.0 // -12.0 to 12.0 dB (typical range)
    @Published var eqBands: [Float] = Array(repeating: 0.0, count: 10) // 10 bands, -12.0 to 12.0 dB
    @Published var isEqOn: Bool = false // New: EQ On/Off state
    @Published var eqAutoEnabled: Bool = false
    @Published var useLogScaleBands: Bool = true
    var perTrackPresets: [String: EqfPreset] = [:]
    private let presetsFileName = "perTrackPresets.json"
    @Published private(set) var userPresets: [EQPreset] = []
    private let userPresetDefaultsKey = "MacAmp.UserEQPresets.v1"
    @Published var visualizerLevels: [Float] = Array(repeating: 0.0, count: 20)
    @Published var appliedAutoPresetTrack: String? = nil
    @Published var channelCount: Int = 2 // 1 = mono, 2 = stereo
    @Published var bitrate: Int = 0 // in kbps
    @Published var sampleRate: Int = 0 // in Hz (will display as kHz)

    init() {
        setupEngine()
        configureEQ()
        loadPerTrackPresets()
        loadUserPresets()
    }

    deinit {}

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

        let duplicateInPlaylist = playlist.contains { $0.url.standardizedFileURL == normalizedURL }
        if duplicateInPlaylist || pendingTrackURLs.contains(normalizedURL) {
            print("AudioPlayer: Track already pending or in playlist: \(normalizedURL.lastPathComponent)")
            return
        }

        print("AudioPlayer: Adding track from \(normalizedURL.lastPathComponent)")
        pendingTrackURLs.insert(normalizedURL)

        let placeholder = Track(
            url: normalizedURL,
            title: normalizedURL.lastPathComponent,
            artist: "Loading...",
            duration: 0.0
        )

        let shouldAutoplay = currentTrack == nil

        playlist.append(placeholder)
        print("AudioPlayer: Queued placeholder '\(placeholder.title)' (total: \(playlist.count) tracks)")

        if shouldAutoplay {
            playTrack(track: placeholder)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.pendingTrackURLs.remove(normalizedURL) }

            print("DEBUG AudioPlayer: Loading metadata for \(normalizedURL.lastPathComponent)")
            let track = await self.loadTrackMetadata(url: normalizedURL)
            print("DEBUG AudioPlayer: Metadata loaded - title: '\(track.title)', artist: '\(track.artist)', duration: \(track.duration)s")

            if let index = self.playlist.firstIndex(where: { $0.id == placeholder.id }) {
                print("DEBUG AudioPlayer: Updating placeholder at index \(index)")
                self.playlist[index] = track

                if self.currentTrack?.id == placeholder.id {
                    print("DEBUG AudioPlayer: Updating current track metadata")
                    self.currentTrack = track
                    self.currentTitle = "\(track.title) - \(track.artist)"
                    self.currentDuration = track.duration
                    self.currentTrackURL = track.url
                }
            } else if !self.playlist.contains(where: { $0.url.standardizedFileURL == normalizedURL }) {
                print("DEBUG AudioPlayer: Appending track to playlist")
                self.playlist.append(track)
            }

            print("DEBUG AudioPlayer: Added '\(track.title)' to playlist (total: \(self.playlist.count) tracks)")
        }
    }

    /// Play an EXISTING track from the playlist
    /// Does NOT modify the playlist - only plays the specified track
    func playTrack(track: Track) {
        // CRITICAL: Don't call stop() here - it triggers completion handlers mid-transition.
        // Instead, directly stop the player node and reset state
        playerNode.stop()
        progressTimer?.invalidate()

        currentTrack = track
        currentTitle = "\(track.title) - \(track.artist)"
        currentDuration = track.duration
        currentTrackURL = track.url
        currentTime = 0
        playbackProgress = 0
        transition(to: .preparing)
        seekGuardActive = false
        trackHasEnded = false  // Reset playlist end flag

        print("AudioPlayer: Playing track '\(track.title)'")

        // Load the audio file for playback
        loadAudioFile(url: track.url)

        // Apply EQ auto preset if enabled
        if eqAutoEnabled {
            applyAutoPreset(for: track)
        }

        // Start playback
        play()
    }

    /// Private: Load audio file for playback (does NOT modify playlist)
    private func loadAudioFile(url: URL) {
        do {
            audioFile = try AVAudioFile(forReading: url)
            rewireForCurrentFile()
            currentSeekID = UUID()
            let _ = scheduleFrom(time: 0, seekID: currentSeekID)
            playerNode.volume = volume
            playerNode.pan = balance

            // Update audio properties synchronously
            updateAudioProperties(for: url)
        } catch {
            print("AudioEngine: Failed to open file: \(error)")
        }
    }

    /// Private: Load track metadata asynchronously
    private func loadTrackMetadata(url: URL) async -> Track {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)
            let durationCM = try await asset.load(.duration)

            let titleItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle).first
            let artistItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtist).first
            let title = (try? await titleItem?.load(.stringValue)) ?? url.lastPathComponent
            let artist = (try? await artistItem?.load(.stringValue)) ?? "Unknown Artist"
            let duration = durationCM.seconds

            return Track(url: url, title: title, artist: artist, duration: duration)
        } catch {
            print("AudioPlayer: Failed to load metadata for \(url.lastPathComponent): \(error)")
            return Track(url: url, title: url.lastPathComponent, artist: "Unknown", duration: 0.0)
        }
    }

    /// Private: Update audio properties (channel count, bitrate, sample rate)
    private func updateAudioProperties(for url: URL) {
        let asset = AVURLAsset(url: url)
        Task { @MainActor in
            do {
                let audioTracks = try await asset.load(.tracks)

                if let firstAudioTrack = audioTracks.first(where: { $0.mediaType == .audio }) {
                    let audioDesc = try await firstAudioTrack.load(.formatDescriptions)
                    let estimatedDataRate = try await firstAudioTrack.load(.estimatedDataRate)

                    if let desc = audioDesc.first {
                        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
                        if let streamDesc = audioStreamBasicDescription?.pointee {
                            // Channel count
                            let channelsPerFrame = streamDesc.mChannelsPerFrame
                            self.channelCount = Int(channelsPerFrame)
                            print("AudioPlayer: Detected \(channelsPerFrame) channel(s) - \(channelsPerFrame == 1 ? "Mono" : "Stereo")")

                            // Sample rate
                            let sampleRateHz = Int(streamDesc.mSampleRate)
                            self.sampleRate = sampleRateHz
                            print("AudioPlayer: Sample rate: \(sampleRateHz) Hz (\(sampleRateHz/1000) kHz)")
                        }
                    }

                    // Bitrate (convert from bits per second to kbps)
                    let bitrateKbps = Int(estimatedDataRate / 1000)
                    self.bitrate = bitrateKbps
                    print("AudioPlayer: Bitrate: \(bitrateKbps) kbps")
                }
            } catch {
                print("AudioPlayer: Failed to load audio properties: \(error)")
            }
        }
    }

    /// Legacy method: Load track and add to playlist
    /// DEPRECATED: Use addTrack(url:) for new tracks or playTrack(track:) for existing tracks
    @available(*, deprecated, message: "Use addTrack(url:) for new tracks or playTrack(track:) for existing tracks")
    func loadTrack(url: URL) {
        print("AudioPlayer: WARNING - loadTrack() is deprecated, use addTrack() instead")
        addTrack(url: url)
    }

    func play() {
        // If playlist has ended, restart from the beginning
        if trackHasEnded && !playlist.isEmpty {
            playTrack(track: playlist[0])
            return
        }

        guard let file = audioFile else {
            print("AudioPlayer: No track loaded to play.")
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
        print("AudioPlayer: Play")
    }

    func pause() {
        guard playerNode.isPlaying else { return }
        playerNode.pause()
        transition(to: .paused)
        seekGuardActive = false
        print("AudioPlayer: Pause")
    }

    func stop() {
        transition(to: .stopped(.manual))
        playerNode.stop()
        currentSeekID = UUID()
        let _ = scheduleFrom(time: 0, seekID: currentSeekID)  // Ignore return - reset to beginning
        currentTime = 0
        playbackProgress = 0
        progressTimer?.invalidate()
        removeVisualizerTapIfNeeded()
        // Reset audio properties when stopping
        if currentTrack == nil {
            bitrate = 0
            sampleRate = 0
            channelCount = 2
        }
        seekGuardActive = false
        print("AudioPlayer: Stop")
    }

    

    func eject() {
        stop()
        transition(to: .stopped(.ejected))
        playlist.removeAll()
        currentTrack = nil
        currentTrackURL = nil
        currentTitle = "No Track Loaded"
        currentDuration = 0.0
        currentTime = 0.0
        playbackProgress = 0.0
        trackHasEnded = false
        appliedAutoPresetTrack = nil
        audioFile = nil
        bitrate = 0
        sampleRate = 0
        channelCount = 2
        print("AudioPlayer: Eject - cleared playlist and reset playback state")
    }

    // Equalizer control methods
    func setPreamp(value: Float) {
        preamp = value
        eqNode.globalGain = value
        // Ensure EQ is enabled when adjusting preamp
        if !isEqOn && value != 0 {
            toggleEq(isOn: true)
        }
        print("Set Preamp to \(value), EQ is \(isEqOn ? "ON" : "OFF")")
    }

    func setEqBand(index: Int, value: Float) {
        guard index >= 0 && index < eqBands.count else { return }
        eqBands[index] = value
        eqNode.bands[index].gain = value
        print("Set EQ Band \(index) to \(value)")
    }

    func toggleEq(isOn: Bool) {
        isEqOn = isOn
        eqNode.bypass = !isOn
        print("EQ is now \(isOn ? "On" : "Off")")
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
        print("Applied EQ preset: \(preset.name)")
    }

    func getCurrentEQPreset(name: String) -> EQPreset {
        return EQPreset(name: name, preamp: preamp, bands: Array(eqBands))
    }

    func saveUserPreset(named rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let preset = getCurrentEQPreset(name: trimmedName)
        storeUserPreset(preset)
        print("AudioPlayer: Saved user EQ preset '\(trimmedName)'")
    }

    func deleteUserPreset(id: UUID) {
        if let index = userPresets.firstIndex(where: { $0.id == id }) {
            let removed = userPresets.remove(at: index)
            persistUserPresets()
            print("AudioPlayer: Deleted user EQ preset '\(removed.name)'")
        }
    }

    func importEqfPreset(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let eqfPreset = EQFCodec.parse(data: data) else {
                print("AudioPlayer: Failed to parse EQF preset at \(url.lastPathComponent)")
                return
            }
            let suggestedName = eqfPreset.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = url.deletingPathExtension().lastPathComponent
            let finalName = (suggestedName?.isEmpty == false ? suggestedName! : fallbackName)
            let preset = EQPreset(name: finalName, preamp: eqfPreset.preampDB, bands: eqfPreset.bandsDB)
            storeUserPreset(preset)
            applyEQPreset(preset)
            print("AudioPlayer: Imported EQ preset '\(finalName)' from EQF")
        } catch {
            print("AudioPlayer: Failed to load EQF preset: \(error)")
        }
    }

    func savePresetForCurrentTrack() {
        guard let t = currentTrack else { return }
        let p = EqfPreset(name: t.title, preampDB: preamp, bandsDB: eqBands)
        perTrackPresets[t.url.absoluteString] = p
        print("Saved per-track EQ preset for \(t.title)")
        savePerTrackPresets()
    }

    private func applyAutoPreset(for track: Track) {
        guard eqAutoEnabled else { return }
        if let preset = perTrackPresets[track.url.absoluteString] {
            applyPreset(preset)
            appliedAutoPresetTrack = track.title
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.appliedAutoPresetTrack == track.title {
                    self.appliedAutoPresetTrack = nil
                }
            }
            print("Applied per-track EQ preset for \(track.title)")
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
        NSLog("AutoEQ: automatic analysis disabled, no preset generated for \(track.title)")
    }

    // MARK: - Preset persistence
    private func appSupportDirectory() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("MacAmp", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) } catch {
                print("Failed to create app support dir: \(error)")
            }
        }
        return dir
    }

    private func presetsFileURL() -> URL? {
        appSupportDirectory()?.appendingPathComponent(presetsFileName)
    }

    private func loadPerTrackPresets() {
        guard let url = presetsFileURL(), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([String: EqfPreset].self, from: data)
            perTrackPresets = loaded
            print("Loaded \(loaded.count) per-track presets")
        } catch {
            print("Failed to load per-track presets: \(error)")
        }
    }

    private func savePerTrackPresets() {
        guard let url = presetsFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(perTrackPresets)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save per-track presets: \(error)")
        }
    }

    private func loadUserPresets() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: userPresetDefaultsKey) else { return }
        do {
            var decoded = try JSONDecoder().decode([EQPreset].self, from: data)
            decoded.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            userPresets = decoded
            print("AudioPlayer: Loaded \(decoded.count) user EQ presets")
        } catch {
            print("AudioPlayer: Failed to decode user EQ presets: \(error)")
            userPresets = []
        }
    }

    private func persistUserPresets() {
        do {
            let data = try JSONEncoder().encode(userPresets)
            UserDefaults.standard.set(data, forKey: userPresetDefaultsKey)
        } catch {
            print("AudioPlayer: Failed to persist user EQ presets: \(error)")
        }
    }

    private func storeUserPreset(_ preset: EQPreset) {
        if let index = userPresets.firstIndex(where: { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }) {
            userPresets[index] = preset
        } else {
            userPresets.append(preset)
        }
        userPresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistUserPresets()
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
        
        guard let _ = audioFile else { return }
        
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
            #if DEBUG
            NSLog("⚠️ scheduleFrom: No audio file loaded")
            #endif
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
                    DispatchQueue.main.async {
                        self?.onPlaybackEnded(fromSeekID: completionID)
                    }
                }
            )

            // Ensure we have currentDuration for UI (non-critical for seeking)
            if fileDuration.isFinite && fileDuration > 0 {
                DispatchQueue.main.async { self.currentDuration = fileDuration }
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
            do { try audioEngine.start() } catch { print("AudioEngine: start error: \(error)") }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    // Debug: Print spectrum analyzer frequency distribution
    private func printSpectrumFrequencyDistribution(sampleRate: Float, bars: Int) {
        let minimumFrequency: Float = 50
        let maximumFrequency: Float = min(16000, sampleRate * 0.45)

        print("\n==== Spectrum Analyzer Frequency Distribution ====")
        print("Sample Rate: \(sampleRate) Hz")
        print("Bars: \(bars)")
        print("Range: \(minimumFrequency) Hz - \(maximumFrequency) Hz")
        print("\nBar | Center Freq | Equalization | Typical Content")
        print("----+-------------+--------------+------------------------------------------")

        for b in 0..<bars {
            let normalized = Float(b) / Float(max(1, bars - 1))
            let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
            let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
            let centerFrequency = 0.91 * logScale + 0.09 * linScale

            let normalizedFreq = (centerFrequency - minimumFrequency) / (maximumFrequency - minimumFrequency)
            let dbAdjustment = -8.0 + 16.0 * normalizedFreq
            let equalizationGain = pow(10.0, dbAdjustment / 20.0)

            let content: String
            switch centerFrequency {
            case ..<100: content = "Sub-bass, kick drum"
            case 100..<200: content = "Bass, low vocals"
            case 200..<400: content = "Vocal fundamentals, warmth"
            case 400..<800: content = "Vocal body, instrument clarity"
            case 800..<2000: content = "Vocal presence, definition"
            case 2000..<4000: content = "Vocal consonants, attack"
            case 4000..<8000: content = "Brightness, sibilance"
            case 8000...: content = "Air, shimmer, harmonics"
            default: content = "Unknown"
            }

            print(String(format: "%3d | %7.0f Hz  | %+.1f dB (×%.2f) | %@",
                         b, centerFrequency, dbAdjustment, equalizationGain, content))
        }
        print("==================================================\n")
    }

    private static var didPrintFrequencyDistribution = false

    private func installVisualizerTapIfNeeded() {
        guard !visualizerTapInstalled else { return }
        let mixer = audioEngine.mainMixerNode
        mixer.removeTap(onBus: 0)
        visualizerTapInstalled = false
        let scratch = VisualizerScratchBuffers()

        // Pass nil format to adopt the node's format; safer during graph changes.
        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in

            if !Self.didPrintFrequencyDistribution {
                self?.printSpectrumFrequencyDistribution(sampleRate: Float(buffer.format.sampleRate), bars: 20)
                Self.didPrintFrequencyDistribution = true
            }
            // Compute raw levels off-main; avoid touching self here.
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            if frameCount == 0 { return }

            let bars = 20
            scratch.prepare(frameCount: frameCount, bars: bars)

            scratch.withMono { mono in
                let invCount = 1.0 / Float(channelCount)
                for frame in 0..<frameCount {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += ptr[channel][frame]
                    }
                    mono[frame] = sum * invCount
                }
            }

            scratch.withMonoReadOnly { mono in
                scratch.withRms { rms in
                    let bucketSize = max(1, frameCount / bars)
                    var cursor = 0
                    for b in 0..<bars {
                        let start = cursor
                        let end = min(frameCount, start + bucketSize)
                        if end > start {
                            var sumSq: Float = 0
                            var index = start
                            while index < end {
                                let sample = mono[index]
                                sumSq += sample * sample
                                index += 1
                            }
                            var value = sqrt(sumSq / Float(end - start))
                            value = min(1.0, value * 4.0)
                            rms[b] = value
                        } else {
                            rms[b] = 0
                        }
                        cursor = end
                    }
                }

                scratch.withSpectrum { spectrum in
                    let sampleRate = Float(buffer.format.sampleRate)
                    let sampleCount = min(1024, frameCount)
                    if sampleCount > 0 {
                        let minimumFrequency: Float = 50
                        let maximumFrequency: Float = min(16000, sampleRate * 0.45)

                        for b in 0..<bars {
                            let normalized = Float(b) / Float(max(1, bars - 1))

                            // Hybrid frequency mapping: 91% log + 9% linear (Webamp-style)
                            let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
                            let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
                            let centerFrequency = 0.91 * logScale + 0.09 * linScale

                            // Goertzel algorithm for this frequency band
                            let omega = 2 * Float.pi * centerFrequency / sampleRate
                            let coefficient = 2 * cos(omega)
                            var s0: Float = 0
                            var s1: Float = 0
                            var s2: Float = 0
                            var index = 0
                            while index < sampleCount {
                                let sample = mono[index]
                                s0 = sample + coefficient * s1 - s2
                                s2 = s1
                                s1 = s0
                                index += 1
                            }
                            let power = s1 * s1 + s2 * s2 - coefficient * s1 * s2
                            var value = sqrt(max(0, power)) / Float(sampleCount)

                            // Apply frequency-dependent gain compensation (pinking filter)
                            // Compensates for natural 10-20 dB bass dominance in music
                            // Uses dB-based adjustment: -8 dB (bass) to +8 dB (treble)
                            let normalizedFreq = (centerFrequency - minimumFrequency) / (maximumFrequency - minimumFrequency)
                            let dbAdjustment = -8.0 + 16.0 * normalizedFreq  // -8 dB to +8 dB range
                            let equalizationGain = pow(10.0, dbAdjustment / 20.0)  // Convert dB to linear gain

                            // Apply equalization and overall sensitivity boost
                            // - Bass (50 Hz): -8 dB = 0.40x (reduce 60%)
                            // - Mid (1 kHz): 0 dB = 1.0x (no change)
                            // - Treble (16 kHz): +8 dB = 2.5x (boost 250%)
                            value *= equalizationGain
                            value = min(1.0, value * 15.0)  // Overall gain tuned for good visibility at normal volume
                            spectrum[b] = value
                        }
                    } else {
                        for b in 0..<bars {
                            spectrum[b] = 0
                        }
                    }
                }
            }

            let rmsSnapshot = scratch.snapshotRms()
            let spectrumSnapshot = scratch.snapshotSpectrum()
            // Hop to main actor for smoothing and state updates using latest settings
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let used = self.useSpectrumVisualizer ? spectrumSnapshot : rmsSnapshot
                let now = CFAbsoluteTimeGetCurrent()
                let dt = max(0, Float(now - self.lastUpdateTime))
                self.lastUpdateTime = now
                let alpha = max(0, min(1, self.visualizerSmoothing))
                var smoothed = [Float](repeating: 0, count: used.count)
                for b in 0..<used.count {
                    let prev = (b < self.visualizerLevels.count) ? self.visualizerLevels[b] : 0
                    smoothed[b] = alpha * prev + (1 - alpha) * used[b]
                    let fall = self.visualizerPeakFalloff * dt
                    let dropped = max(0, self.visualizerPeaks[b] - fall)
                    self.visualizerPeaks[b] = max(dropped, smoothed[b])
                }
                self.visualizerLevels = smoothed
            }
        }
        visualizerTapInstalled = true
    }

    private func removeVisualizerTapIfNeeded() {
        guard visualizerTapInstalled else { return }
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        visualizerTapInstalled = false
    }

    // MARK: - Seeking / Scrubbing

    /// Seek to a percentage of the track (0.0 to 1.0)
    /// This method calculates time using file.length directly, avoiding race conditions
    func seekToPercent(_ percent: Double, resume: Bool? = nil) {
        guard let file = audioFile else {
            #if DEBUG
            NSLog("⚠️ seekToPercent: No audio file loaded")
            #endif
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
        // Guard: Ensure file is loaded before seeking
        guard let file = audioFile else {
            #if DEBUG
            NSLog("⚠️ seek: Cannot seek - no audio file loaded")
            #endif
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
            playerNode.play()
            startProgressTimer()  // Restart timer with fresh state
            transition(to: .playing)
        } else if !audioScheduled {
            // No audio scheduled - we're at the end of the track
            transition(to: .stopped(.completed))
            // Timer already invalidated above

            // Trigger track completion logic after the seek guard is cleared
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                // Now safe to call onPlaybackEnded once seek guard is relaxed
                self?.onPlaybackEnded()
            }
        } else {
            transition(to: .paused)
            // Timer already invalidated above
        }

        // Clear seek guard after a brief delay to allow old completion handler to fire and be ignored
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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

    private func onPlaybackEnded(fromSeekID: UUID? = nil) {
        DispatchQueue.main.async { [weak self] in
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
            self.nextTrack()
            if !self.isPlaying {
                self.removeVisualizerTapIfNeeded()
            }
            self.seekGuardActive = false

            // Clear re-entrancy guard after nextTrack completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isHandlingCompletion = false
            }
        }
    }

    // MARK: - Playlist navigation
    func nextTrack() {
        guard !playlist.isEmpty else { return }

        if shuffleEnabled {
            // Shuffle: pick random track
            if let randomTrack = playlist.randomElement() {
                playTrack(track: randomTrack)
            }
        } else if let current = currentTrack, let idx = playlist.firstIndex(of: current) {
            // Sequential playback
            let nextIdx = playlist.index(after: idx)
            if nextIdx < playlist.count {
                let next = playlist[nextIdx]
                playTrack(track: next)
            } else if repeatEnabled {
                // Repeat: loop back to first track
                playTrack(track: playlist[0])
            } else {
                // End of playlist reached, no repeat
                trackHasEnded = true
            }
        } else if !playlist.isEmpty {
            // No current track, start from beginning
            playTrack(track: playlist[0])
        }
    }

    func previousTrack() {
        guard let current = currentTrack, let idx = playlist.firstIndex(of: current) else {
            return
        }
        if idx > 0 {
            let prev = playlist[playlist.index(before: idx)]
            playTrack(track: prev)
        } else {
            seek(to: 0, resume: isPlaying)
        }
    }
}
