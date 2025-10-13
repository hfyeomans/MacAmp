
import Foundation
import Combine
import AVFoundation
import Accelerate

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
    private var wasStopped = false // Track if playback was stopped manually
    @Published var useSpectrumVisualizer: Bool = true
    @Published var visualizerSmoothing: Float = 0.6 // 0..1 (higher = smoother)
    @Published var visualizerPeakFalloff: Float = 1.2 // units per second

    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
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

    // Equalizer properties
    @Published var preamp: Float = 0.0 // -12.0 to 12.0 dB (typical range)
    @Published var eqBands: [Float] = Array(repeating: 0.0, count: 10) // 10 bands, -12.0 to 12.0 dB
    @Published var isEqOn: Bool = false // New: EQ On/Off state
    @Published var eqAutoEnabled: Bool = false
    @Published var useLogScaleBands: Bool = true
    var perTrackPresets: [String: EqfPreset] = [:]
    private let presetsFileName = "perTrackPresets.json"
    @Published var visualizerLevels: [Float] = Array(repeating: 0.0, count: 20)
    @Published var appliedAutoPresetTrack: String? = nil
    @Published var channelCount: Int = 2 // 1 = mono, 2 = stereo
    @Published var bitrate: Int = 0 // in kbps
    @Published var sampleRate: Int = 0 // in Hz (will display as kHz)

    init() {
        setupEngine()
        configureEQ()
        loadPerTrackPresets()
    }

    deinit {}

    func loadTrack(url: URL) {
        stop()
        currentTrackURL = url
        isPaused = false
        print("AudioPlayer: Loaded track from \(url.lastPathComponent)")

        // Load metadata and duration via modern async APIs
        let asset = AVURLAsset(url: url)
        Task { @MainActor in
            do {
                let metadata = try await asset.load(.commonMetadata)
                let durationCM = try await asset.load(.duration)
                let audioTracks = try await asset.load(.tracks)
                
                // Detect channel count, sample rate, and bitrate from the first audio track
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
                
                let titleItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle).first
                let artistItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtist).first
                let title = (try? await titleItem?.load(.stringValue)) ?? url.lastPathComponent
                let artist = (try? await artistItem?.load(.stringValue)) ?? "Unknown Artist"
                let duration = durationCM.seconds

                self.currentTitle = "\(title) - \(artist)"
                self.currentDuration = duration
                let newTrack = Track(url: url, title: title, artist: artist, duration: duration)
                self.playlist.append(newTrack)
                if self.currentTrack == nil { self.currentTrack = newTrack }
                if self.eqAutoEnabled { self.applyAutoPreset(for: newTrack) }
            } catch {
                self.currentTitle = url.lastPathComponent
                self.currentDuration = 0.0
                let newTrack = Track(url: url, title: url.lastPathComponent, artist: "Unknown", duration: 0.0)
                self.playlist.append(newTrack)
                if self.currentTrack == nil { self.currentTrack = newTrack }
                if self.eqAutoEnabled { self.applyAutoPreset(for: newTrack) }
            }
        }

        // Prepare audio file and schedule from start
        do {
            audioFile = try AVAudioFile(forReading: url)
            rewireForCurrentFile()
            scheduleFrom(time: 0)
            // Ensure volume/pan applied
            playerNode.volume = volume
            playerNode.pan = balance
        } catch {
            print("AudioEngine: Failed to open file: \(error)")
        }
    }

    func playTrack(track: Track) {
        loadTrack(url: track.url)
        currentTrack = track
        play()
    }

    func play() {
        guard audioFile != nil else {
            print("AudioPlayer: No track loaded to play.")
            return
        }
        startEngineIfNeeded()
        if !playerNode.isPlaying {
            playerNode.play()
        }
        startProgressTimer()
        isPlaying = true
        isPaused = false
        wasStopped = false
        print("AudioPlayer: Play")
    }

    func pause() {
        guard playerNode.isPlaying else { return }
        playerNode.pause()
        isPlaying = false
        isPaused = true
        wasStopped = false // Allow normal completion handling after pause
        print("AudioPlayer: Pause")
    }

    func stop() {
        wasStopped = true
        playerNode.stop()
        scheduleFrom(time: 0)
        currentTime = 0
        playbackProgress = 0
        progressTimer?.invalidate()
        isPlaying = false
        isPaused = false
        // Reset audio properties when stopping
        if currentTrack == nil {
            bitrate = 0
            sampleRate = 0
            channelCount = 2
        }
        print("AudioPlayer: Stop")
    }

    

    func eject() {
        print("AudioPlayer: Eject (Not yet implemented)")
        // TODO: Implement eject logic (e.g., clear playlist)
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

    func savePresetForCurrentTrack() {
        guard let t = currentTrack else { return }
        let p = EqfPreset(name: t.title, preampDB: preamp, bandsDB: eqBands)
        perTrackPresets[t.url.absoluteString] = p
        print("Saved per-track EQ preset for \(t.title)")
        savePerTrackPresets()
    }

    private func applyAutoPreset(for track: Track) {
        if let p = perTrackPresets[track.url.absoluteString] {
            applyPreset(p)
            appliedAutoPresetTrack = track.title
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // Clear only if unchanged
                if self.appliedAutoPresetTrack == track.title {
                    self.appliedAutoPresetTrack = nil
                }
            }
            print("Applied per-track EQ preset for \(track.title)")
        }
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

    private func scheduleFrom(time: Double) {
        guard let file = audioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, min(time, currentDuration)) * sampleRate)
        let totalFrames = file.length
        let framesRemaining = max(0, totalFrames - startFrame)
        playheadOffset = Double(startFrame) / sampleRate
        playerNode.stop()
        if framesRemaining > 0 {
            playerNode.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(framesRemaining),
                at: nil,
                completionHandler: { [weak self] in DispatchQueue.main.async { self?.onPlaybackEnded() } }
            )
        } else {
            onPlaybackEnded()
        }
        // Ensure we have currentDuration
        let duration = Double(file.length) / file.processingFormat.sampleRate
        if duration.isFinite && duration > 0 {
            DispatchQueue.main.async { self.currentDuration = duration }
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
                        self.playbackProgress = current / self.currentDuration
                    } else {
                        self.playbackProgress = 0
                    }
                }
            }
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    private func installVisualizerTapIfNeeded() {
        guard !visualizerTapInstalled else { return }
        let mixer = audioEngine.mainMixerNode
        mixer.removeTap(onBus: 0)
        // Pass nil format to adopt the node's format; safer during graph changes.
        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            // Compute raw levels off-main; avoid touching self here.
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            if frameCount == 0 { return }

            // Mix down to mono
            var mono: [Float] = Array(repeating: 0, count: frameCount)
            let invCount = 1.0 / Float(channelCount)
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += ptr[ch][i]
                }
                mono[i] = sum * invCount
            }
            let bars = 20
            // Compute RMS bars raw
            var rms = Array(repeating: Float(0), count: bars)
            do {
                let bucketSize = max(1, frameCount / bars)
                var idx = 0
                for b in 0..<bars {
                    let start = idx
                    let end = min(frameCount, start + bucketSize)
                    if end > start {
                        var sumSq: Float = 0
                        let len = end - start
                        var j = start
                        while j < end {
                            let s = mono[j]
                            sumSq += s * s
                            j += 1
                        }
                        var v = sqrt(sumSq / Float(len))
                        v = min(1.0, v * 4.0)
                        rms[b] = v
                    }
                    idx = end
                }
            }
            // Compute spectrum bars (log scale) raw
            var spec = Array(repeating: Float(0), count: bars)
            do {
                let fs = Float(buffer.format.sampleRate)
                let n = min(1024, frameCount)
                if n > 0 {
                    let fMin: Float = 50
                    let fMax: Float = min(16000, fs * 0.45)
                    for b in 0..<bars {
                        let t = Float(b) / Float(max(1, bars - 1))
                        let fc = fMin * pow(fMax / fMin, t)
                        let w = 2 * Float.pi * fc / fs
                        let coeff = 2 * cos(w)
                        var s0: Float = 0, s1: Float = 0, s2: Float = 0
                        var j = 0
                        while j < n {
                            s0 = mono[j] + coeff * s1 - s2
                            s2 = s1
                            s1 = s0
                            j += 1
                        }
                        let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
                        var val = sqrt(max(0, power)) / Float(n)
                        val = min(1.0, val * 4.0)
                        spec[b] = val
                    }
                }
            }
            // Hop to main actor for smoothing and state updates using latest settings
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let used = self.useSpectrumVisualizer ? spec : rms
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

    // MARK: - Seeking / Scrubbing
    func seek(to time: Double, resume: Bool? = nil) {
        let shouldPlay = resume ?? isPlaying
        wasStopped = false // Allow normal completion after seeking
        scheduleFrom(time: time)
        currentTime = time
        playbackProgress = currentDuration > 0 ? time / currentDuration : 0
        if shouldPlay {
            startEngineIfNeeded()
            playerNode.play()
            startProgressTimer()
            isPlaying = true
            isPaused = false
        } else {
            isPlaying = false
            progressTimer?.invalidate()
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

    private func onPlaybackEnded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Don't update progress if we stopped manually
            guard !self.wasStopped else {
                self.wasStopped = false
                return
            }
            self.isPlaying = false
            self.progressTimer?.invalidate()
            self.playbackProgress = 1
            self.currentTime = self.currentDuration
            self.nextTrack()
        }
    }

    // MARK: - Playlist navigation
    func nextTrack() {
        guard let current = currentTrack, let idx = playlist.firstIndex(of: current) else {
            return
        }
        let nextIdx = playlist.index(after: idx)
        if nextIdx < playlist.count {
            let next = playlist[nextIdx]
            playTrack(track: next)
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
