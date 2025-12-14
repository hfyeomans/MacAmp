
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

// Scratch buffers are confined to the audio tap queue, so @unchecked Sendable is safe.
private final class VisualizerScratchBuffers: @unchecked Sendable {
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

private struct VisualizerTapContext: @unchecked Sendable {
    let playerPointer: UnsafeMutableRawPointer
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

    /// Returns true if this track is an internet radio stream (HTTP/HTTPS URL)
    /// Streams cannot be played via AudioPlayer (which uses AVAudioFile for local files only)
    /// and must be routed through PlaybackCoordinator → StreamPlayer instead.
    var isStream: Bool {
        !url.isFileURL && (url.scheme == "http" || url.scheme == "https")
    }

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

@Observable
@MainActor
final class AudioPlayer {
    // AVAudioEngine-based playback - NOT observable (engine implementation details)
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let playerNode = AVAudioPlayerNode()
    @ObservationIgnored private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    @ObservationIgnored private var audioFile: AVAudioFile?
    @ObservationIgnored private var progressTimer: Timer?
    @ObservationIgnored private var playheadOffset: Double = 0 // seconds offset for current scheduled segment
    @ObservationIgnored private var visualizerTapInstalled = false
    @ObservationIgnored private var visualizerPeaks: [Float] = Array(repeating: 0.0, count: 20)
    @ObservationIgnored private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    /// Legacy toggle - derives from AppSettings.visualizerMode
    var useSpectrumVisualizer: Bool {
        get { AppSettings.instance().visualizerMode == .spectrum }
        set {
            AppSettings.instance().visualizerMode = newValue ? .spectrum : .none
        }
    }

    var visualizerSmoothing: Float = 0.6 // 0..1 (higher = smoother)
    var visualizerPeakFalloff: Float = 1.2 // units per second

    // Visualizer data storage
    @ObservationIgnored private var latestRMS: [Float] = []
    @ObservationIgnored private var latestSpectrum: [Float] = []
    @ObservationIgnored private var latestWaveform: [Float] = []

    private(set) var playbackState: PlaybackState = .idle
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    @ObservationIgnored private var currentSeekID: UUID = UUID() // Identifies which seek operation scheduled the current audio
    @ObservationIgnored private var isHandlingCompletion = false // Prevents re-entrant onPlaybackEnded calls
    @ObservationIgnored private var trackHasEnded = false // Tracks when playlist has finished
    @ObservationIgnored private var seekGuardActive = false
    @ObservationIgnored private var autoEQTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTrackURLs = Set<URL>()
    var currentTrackURL: URL? // Placeholder for the currently playing track
    var currentTitle: String = "No Track Loaded"
    var currentDuration: Double = 0.0
    var currentTime: Double = 0.0
    var playbackProgress: Double = 0.0 // New: 0.0 to 1.0

    var volume: Float = 1.0 { // 0.0 to 1.0
        didSet {
            playerNode.volume = volume
            if currentMediaType == .video {
                videoPlayer?.volume = volume
            }
        }
    }
    var balance: Float = 0.0 { // -1.0 (left) to 1.0 (right)
        didSet { playerNode.pan = balance }
    }

    var playlist: [Track] = [] // New: List of tracks
    var currentTrack: Track? // New: Currently playing track
    @ObservationIgnored private var currentPlaylistIndex: Int?
    var externalPlaybackHandler: ((Track) -> Void)?
    var shuffleEnabled: Bool = false

    // Video playback support
    var videoPlayer: AVPlayer?
    var currentMediaType: MediaType = .audio
    var videoMetadataString: String = ""
    @ObservationIgnored private var videoEndObserver: NSObjectProtocol?
    @ObservationIgnored private var videoTimeObserver: Any?

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
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]
    @ObservationIgnored private let presetsFileName = "perTrackPresets.json"
    private(set) var userPresets: [EQPreset] = []
    @ObservationIgnored private let userPresetDefaultsKey = "MacAmp.UserEQPresets.v1"
    var visualizerLevels: [Float] = Array(repeating: 0.0, count: 20)
    var appliedAutoPresetTrack: String? = nil
    var channelCount: Int = 2 // 1 = mono, 2 = stereo
    var bitrate: Int = 0 // in kbps
    var sampleRate: Int = 0 // in Hz (will display as kHz)

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

                    // Notify coordinator that metadata updated
                    self.externalPlaybackHandler?(track)
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
        // Guard against stream URLs - AudioPlayer can only play local files
        guard !track.isStream else {
            print("ERROR: AudioPlayer cannot play internet radio streams.")
            print("       Stream URL: \(track.url)")
            print("       Use PlaybackCoordinator to route streams to StreamPlayer.")
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
        trackHasEnded = false  // Reset playlist end flag

        print("AudioPlayer: Playing track '\(track.title)'")

        // Detect media type and route appropriately
        let mediaType = detectMediaType(url: track.url)

        // CRITICAL: Cleanup old media type BEFORE setting new one
        // This ensures proper cleanup when switching between audio and video
        if currentMediaType != mediaType {
            if currentMediaType == .video {
                // Switching FROM video to audio - cleanup video
                cleanupVideoPlayer()
                videoMetadataString = ""
                print("AudioPlayer: Switching from video to audio - cleanup complete")
            }
            // Note: Audio cleanup happens in loadVideoFile() via playerNode.stop()
        }

        currentMediaType = mediaType

        switch mediaType {
        case .audio:
            loadAudioFile(url: track.url)
        case .video:
            loadVideoFile(url: track.url)
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

    // Load video file for playback
    private func loadVideoFile(url: URL) {
        // Stop any existing audio playback
        playerNode.stop()
        progressTimer?.invalidate()

        // Clean up any existing video player
        cleanupVideoPlayer()

        // Create video player
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.volume = volume  // Sync volume at creation time
        currentMediaType = .video

        // Observe video completion
        if let playerItem = videoPlayer?.currentItem {
            videoEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.onPlaybackEnded()
                }
            }
        }

        // Setup time observer BEFORE play
        setupVideoTimeObserver()

        // Start video playback
        videoPlayer?.play()

        // Update state
        transition(to: .playing)
        isPlaying = true
        isPaused = false

        NSLog("📺 AudioPlayer: Loading video file: \(url.lastPathComponent)")

        // Extract and format video metadata for display
        Task { @MainActor in
            await self.loadVideoMetadata(url: url)
        }
    }

    /// Extract video metadata for display in video window
    /// Format: "filename M4V 1280x720" (simple, matches Winamp classic)
    private func loadVideoMetadata(url: URL) async {
        // Get filename (without extension)
        let filename = url.deletingPathExtension().lastPathComponent

        // Get file extension as video type
        let videoType = url.pathExtension.uppercased()

        do {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.load(.tracks)

            // Get video resolution
            if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                let naturalSize = try await videoTrack.load(.naturalSize)
                let width = Int(naturalSize.width)
                let height = Int(naturalSize.height)

                // Winamp format: "filename (WMV): Video: 1280x720"
                videoMetadataString = "\(filename) (\(videoType)): Video: \(width)x\(height)"
                NSLog("📺 Video metadata: \(videoMetadataString)")
            } else {
                // No video track found
                videoMetadataString = "\(filename) (\(videoType)): Video: Unknown"
                NSLog("📺 Video metadata (no track): \(videoMetadataString)")
            }
        } catch {
            videoMetadataString = "\(filename) (\(videoType)): Video: Unknown"
            NSLog("⚠️ Failed to load video metadata: \(error)")
        }
    }

    // MARK: - Video Time Observer

    /// Setup periodic time observer for video playback
    /// Updates currentTime, currentDuration, AND playbackProgress (all three required)
    private func setupVideoTimeObserver() {
        tearDownVideoTimeObserver()  // Clean first
        guard let player = videoPlayer else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        videoTimeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in  // Explicit main actor hop
                guard let self else { return }
                let seconds = time.seconds
                self.currentTime = seconds

                if let item = player.currentItem {
                    let duration = item.duration.seconds
                    if duration.isFinite {
                        self.currentDuration = duration
                        // CRITICAL: playbackProgress is STORED, must assign explicitly
                        self.playbackProgress = duration > 0 ? seconds / duration : 0
                    }
                }
            }
        }
        NSLog("📺 Video time observer setup")
    }

    /// Teardown video time observer to prevent memory leaks
    private func tearDownVideoTimeObserver() {
        if let observer = videoTimeObserver, let player = videoPlayer {
            player.removeTimeObserver(observer)
        }
        videoTimeObserver = nil
    }

    /// Shared cleanup for all video resources
    private func cleanupVideoPlayer() {
        tearDownVideoTimeObserver()
        if let observer = videoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            videoEndObserver = nil
        }
        videoPlayer?.pause()
        videoPlayer = nil
        NSLog("📺 Video player cleanup complete")
    }

    /// Private: Load audio file for playback (does NOT modify playlist)
    private func loadAudioFile(url: URL) {
        // Video cleanup now happens in playTrack() BEFORE calling this
        // currentMediaType is already set to .audio by playTrack()

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


    func play() {
        // If playlist has ended, restart from the beginning
        if trackHasEnded && !playlist.isEmpty {
            playTrack(track: playlist[0])
            return
        }

        // Handle video playback
        if currentMediaType == .video {
            guard let player = videoPlayer else {
                print("AudioPlayer: No video loaded to play.")
                return
            }
            player.play()
            transition(to: .playing)
            isPlaying = true
            isPaused = false
            print("AudioPlayer: Play (Video)")
            return
        }

        // Audio playback
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
        // Handle video playback
        if currentMediaType == .video {
            videoPlayer?.pause()
            transition(to: .paused)
            isPlaying = false
            isPaused = true
            print("AudioPlayer: Pause (Video)")
            return
        }

        // Audio playback
        guard playerNode.isPlaying else { return }
        playerNode.pause()
        transition(to: .paused)
        seekGuardActive = false
        print("AudioPlayer: Pause")
    }

    func stop() {
        transition(to: .stopped(.manual))

        // Handle video playback cleanup
        if currentMediaType == .video {
            cleanupVideoPlayer()
            videoMetadataString = ""
            currentMediaType = .audio
            print("AudioPlayer: Stop (Video) - cleaned up AVPlayer")
        }

        // Audio playback cleanup
        playerNode.stop()
        currentSeekID = UUID()
        let _ = scheduleFrom(time: 0, seekID: currentSeekID)  // Ignore return - reset to beginning

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
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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


    @MainActor
    private func updateVisualizerLevels(rms: [Float], spectrum: [Float], waveform: [Float]) {
        // Store all visualizer datasets
        self.latestRMS = rms
        self.latestSpectrum = spectrum
        self.latestWaveform = waveform

        // Apply smoothing to active mode
        let used = self.useSpectrumVisualizer ? spectrum : rms
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

    /// Build the tap handler in a nonisolated context so AVAudioEngine can call it on its realtime queue.
    private nonisolated static func makeVisualizerTapHandler(
        context: VisualizerTapContext,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        { buffer, _ in
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
                            let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
                            let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
                            let centerFrequency = 0.91 * logScale + 0.09 * linScale

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

                            let normalizedFreq = (centerFrequency - minimumFrequency) / (maximumFrequency - minimumFrequency)
                            let dbAdjustment = -8.0 + 16.0 * normalizedFreq
                            let equalizationGain = pow(10.0, dbAdjustment / 20.0)

                            value *= equalizationGain
                            value = min(1.0, value * 15.0)
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

            // Capture waveform samples for oscilloscope
            let oscilloscopeSamples = 76  // Match VisualizerLayout.oscilloscopeSampleCount
            var waveformSnapshot: [Float] = []
            scratch.withMonoReadOnly { mono in
                let step = max(1, mono.count / oscilloscopeSamples)
                waveformSnapshot = stride(from: 0, to: mono.count, by: step)
                    .prefix(oscilloscopeSamples)
                    .map { mono[$0] }
            }

            Task { @MainActor [context, rmsSnapshot, spectrumSnapshot, waveformSnapshot] in
                let player = Unmanaged<AudioPlayer>.fromOpaque(context.playerPointer).takeUnretainedValue()
                player.updateVisualizerLevels(rms: rmsSnapshot, spectrum: spectrumSnapshot, waveform: waveformSnapshot)
            }
        }
    }

    private func installVisualizerTapIfNeeded() {
        guard !visualizerTapInstalled else { return }
        let mixer = audioEngine.mainMixerNode
        mixer.removeTap(onBus: 0)
        visualizerTapInstalled = false
        let scratch = VisualizerScratchBuffers()

        let context = VisualizerTapContext(
            playerPointer: Unmanaged.passUnretained(self).toOpaque()
        )
        let handler = AudioPlayer.makeVisualizerTapHandler(
            context: context,
            scratch: scratch
        )

        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil, block: handler)
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
        // VIDEO SEEKING (Part 21)
        if currentMediaType == .video {
            guard let player = videoPlayer,
                  let duration = player.currentItem?.duration.seconds,
                  duration.isFinite else {
                NSLog("⚠️ seekToPercent: No video player or invalid duration")
                return
            }
            let targetTime = percent * duration
            seek(to: targetTime, resume: resume)
            return
        }

        // AUDIO SEEKING
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
        // VIDEO SEEKING
        if currentMediaType == .video {
            guard let player = videoPlayer else {
                NSLog("⚠️ seek: Cannot seek - no video player loaded")
                return
            }
            let shouldPlay = resume ?? isPlaying

            let timescale = player.currentItem?.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
            let targetTime = CMTime(seconds: max(0, time), preferredTimescale: timescale)

            // Use default tolerance (not .zero) to allow seeking to nearest keyframe
            // This is MUCH faster and avoids -12860 errors from trying to decode exact frames
            // AVPlayer will seek to the nearest keyframe, which is typically within 0.5s
            player.seek(to: targetTime) { [weak self] finished in
                Task { @MainActor in
                    guard let self, finished else { return }

                    // Update to actual seek position (may differ slightly from requested)
                    let actualTime = player.currentTime().seconds
                    self.currentTime = actualTime

                    if let duration = player.currentItem?.duration.seconds, duration.isFinite {
                        self.currentDuration = duration
                        self.playbackProgress = duration > 0 ? actualTime / duration : 0
                    }

                    if shouldPlay {
                        player.play()
                        self.transition(to: .playing)
                    } else {
                        player.pause()
                        self.transition(to: .paused)
                    }
                }
            }
            NSLog("📺 Video seek to \(time)s")
            return  // Exit early for video
        }

        // AUDIO SEEKING
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

    func getRMSData(bands: Int) -> [Float] {
        guard bands > 0 else { return [] }

        // Return raw RMS data (already has correct band count)
        if latestRMS.count == bands {
            return latestRMS
        }

        // Or map if different band count requested
        var result = [Float](repeating: 0, count: bands)
        if !latestRMS.isEmpty {
            for i in 0..<bands {
                let sourceIndex = (i * latestRMS.count) / bands
                result[i] = latestRMS[min(sourceIndex, latestRMS.count - 1)]
            }
        }

        return result
    }

    func getWaveformSamples(count: Int) -> [Float] {
        guard count > 0 else { return [] }

        // Return waveform samples captured from mono buffer
        if latestWaveform.count == count {
            return latestWaveform
        }

        // Resample if different count requested
        var result = [Float](repeating: 0, count: count)
        if !latestWaveform.isEmpty {
            for i in 0..<count {
                let sourceIndex = (i * latestWaveform.count) / count
                result[i] = latestWaveform[min(sourceIndex, latestWaveform.count - 1)]
            }
        }

        return result
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
    enum PlaylistAdvanceAction {
        case none
        case restartCurrent
        case playLocally(Track)
        case requestCoordinatorPlayback(Track)
    }

    func updatePlaylistPosition(with track: Track?) {
        guard let track else {
            currentPlaylistIndex = nil
            return
        }

        if let index = playlist.firstIndex(of: track) {
            currentPlaylistIndex = index
            trackHasEnded = false
        } else {
            currentPlaylistIndex = nil
        }
    }

    @discardableResult
    func nextTrack(isManualSkip: Bool = false) -> PlaylistAdvanceAction {
        guard !playlist.isEmpty else { return .none }

        trackHasEnded = false

        // ──────────────────────────────────────
        // WINAMP 5 REPEAT MODE LOGIC
        // ──────────────────────────────────────
        // Repeat-one: Only auto-restart on track end, allow manual skips
        if repeatMode == .one && !isManualSkip {
            // Auto-advance (track ended naturally): restart current track
            guard let current = currentTrack else { return .none }

            if current.isStream {
                // Internet radio: reload via coordinator
                return .requestCoordinatorPlayback(current)
            } else {
                // Local file: seek to beginning and resume
                seek(to: 0, resume: true)
                return .playLocally(current)
            }
        }
        // Manual skip OR modes .off/.all: continue with normal advancement logic below

        if shuffleEnabled {
            guard let randomTrack = playlist.randomElement(),
                  let randomIndex = playlist.firstIndex(of: randomTrack) else {
                return .none
            }

            currentPlaylistIndex = randomIndex
            trackHasEnded = false
            if randomTrack.isStream {
                return .requestCoordinatorPlayback(randomTrack)
            }

            playTrack(track: randomTrack)
            return .playLocally(randomTrack)
        }

        let activeIndex: Int
        if let index = currentPlaylistIndex {
            activeIndex = index
        } else if let current = currentTrack, let index = playlist.firstIndex(of: current) {
            activeIndex = index
            currentPlaylistIndex = index
        } else {
            activeIndex = -1
        }

        let nextIndex = activeIndex + 1
        if nextIndex < playlist.count {
            let track = playlist[nextIndex]
            currentPlaylistIndex = nextIndex
            trackHasEnded = false
            if track.isStream {
                return .requestCoordinatorPlayback(track)
            }

            playTrack(track: track)
            return .playLocally(track)
        }

        // End of playlist reached - handle based on repeat mode
        if repeatMode == .all {
            // Winamp 5 repeat-all: wrap to first track
            let track = playlist[0]
            currentPlaylistIndex = 0
            trackHasEnded = false
            if track.isStream {
                return .requestCoordinatorPlayback(track)
            }

            playTrack(track: track)
            return .playLocally(track)
        }

        // Repeat mode .off: stop at playlist end
        trackHasEnded = true
        currentPlaylistIndex = nil
        return .none
    }

    @discardableResult
    func previousTrack() -> PlaylistAdvanceAction {
        guard !playlist.isEmpty else { return .none }

        if shuffleEnabled {
            guard let track = playlist.randomElement(),
                  let index = playlist.firstIndex(of: track) else {
                return .none
            }

            currentPlaylistIndex = index
            trackHasEnded = false
            if track.isStream {
                return .requestCoordinatorPlayback(track)
            }

            playTrack(track: track)
            return .playLocally(track)
        }

        let activeIndex: Int
        if let index = currentPlaylistIndex {
            activeIndex = index
        } else if let current = currentTrack, let index = playlist.firstIndex(of: current) {
            activeIndex = index
            currentPlaylistIndex = index
        } else {
            return .none
        }

        if activeIndex > 0 {
            let previousIndex = playlist.index(before: activeIndex)
            let track = playlist[previousIndex]
            currentPlaylistIndex = previousIndex
            trackHasEnded = false
            if track.isStream {
                return .requestCoordinatorPlayback(track)
            }

            playTrack(track: track)
            return .playLocally(track)
        }

        seek(to: 0, resume: isPlaying)
        return .restartCurrent
    }
}
