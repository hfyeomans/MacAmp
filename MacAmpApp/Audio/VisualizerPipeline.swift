import AVFoundation
import Accelerate
import Observation

// MARK: - Butterchurn Audio Frame

/// Snapshot of audio data for Butterchurn visualization
/// Produced by VisualizerPipeline tap, consumed by ButterchurnBridge at 30 FPS
struct ButterchurnFrame {
    let spectrum: [Float]       // 1024 frequency bins (from 2048-point FFT)
    let waveform: [Float]       // 1024 mono samples (time-domain)
    let timestamp: TimeInterval // CACurrentMediaTime() when captured
}

// MARK: - Visualizer Data

/// Container for all visualizer datasets produced by the audio tap
struct VisualizerData {
    let rms: [Float]
    let spectrum: [Float]
    let waveform: [Float]
    let butterchurnSpectrum: [Float]
    let butterchurnWaveform: [Float]
}

// MARK: - Scratch Buffers

/// Scratch buffers are confined to the audio tap queue, so @unchecked Sendable is safe.
private final class VisualizerScratchBuffers: @unchecked Sendable {
    private(set) var mono: [Float] = []
    private(set) var rms: [Float] = []
    private(set) var spectrum: [Float] = []

    // Butterchurn FFT buffers
    private static let butterchurnFFTSize: Int = 2048
    private static let butterchurnBins: Int = 1024

    private var butterchurnReal: [Float] = Array(repeating: 0, count: butterchurnFFTSize)
    private var butterchurnImag: [Float] = Array(repeating: 0, count: butterchurnFFTSize)
    private(set) var butterchurnSpectrum: [Float] = Array(repeating: 0, count: butterchurnBins)
    private(set) var butterchurnWaveform: [Float] = Array(repeating: 0, count: butterchurnBins)

    // vDSP FFT setup (log2(2048) = 11)
    private let fftSetup: vDSP_DFT_Setup?

    init() {
        // Create FFT setup for 2048-point real-to-complex transform
        fftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(Self.butterchurnFFTSize),
            .FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

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

    // MARK: - Butterchurn FFT Processing

    /// Process audio samples for Butterchurn visualization
    /// - Parameter samples: Mono audio samples (at least 2048 for full FFT)
    func processButterchurnFFT(samples: [Float]) {
        guard let setup = fftSetup else { return }

        let sampleCount = min(samples.count, Self.butterchurnFFTSize)

        // Copy input samples and zero-pad if needed
        for i in 0..<sampleCount {
            butterchurnReal[i] = samples[i]
        }
        for i in sampleCount..<Self.butterchurnFFTSize {
            butterchurnReal[i] = 0
        }

        // Apply Hann window to reduce spectral leakage
        var window = [Float](repeating: 0, count: Self.butterchurnFFTSize)
        vDSP_hann_window(&window, vDSP_Length(Self.butterchurnFFTSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(butterchurnReal, 1, window, 1, &butterchurnReal, 1, vDSP_Length(Self.butterchurnFFTSize))

        // Prepare split complex for FFT
        // For real-to-complex DFT, input is interleaved as even/odd
        var inputReal = [Float](repeating: 0, count: Self.butterchurnFFTSize / 2)
        var inputImag = [Float](repeating: 0, count: Self.butterchurnFFTSize / 2)

        for i in 0..<(Self.butterchurnFFTSize / 2) {
            inputReal[i] = butterchurnReal[i * 2]
            inputImag[i] = butterchurnReal[i * 2 + 1]
        }

        var outputReal = [Float](repeating: 0, count: Self.butterchurnFFTSize / 2)
        var outputImag = [Float](repeating: 0, count: Self.butterchurnFFTSize / 2)

        // Execute FFT
        vDSP_DFT_Execute(setup, inputReal, inputImag, &outputReal, &outputImag)

        // Compute magnitude spectrum (first 1024 bins)
        // Magnitude = sqrt(real² + imag²)
        for i in 0..<Self.butterchurnBins {
            let real = outputReal[i % outputReal.count]
            let imag = outputImag[i % outputImag.count]
            var magnitude = sqrt(real * real + imag * imag)

            // Normalize and scale for visualization (0-1 range)
            magnitude /= Float(Self.butterchurnFFTSize)
            magnitude = min(1.0, magnitude * 4.0)  // Boost for visibility

            butterchurnSpectrum[i] = magnitude
        }

        // Capture waveform: downsample to 1024 samples
        let step = max(1, sampleCount / Self.butterchurnBins)
        for i in 0..<Self.butterchurnBins {
            let sampleIndex = min(i * step, sampleCount - 1)
            butterchurnWaveform[i] = samples[sampleIndex]
        }
    }

    func snapshotButterchurnSpectrum() -> [Float] {
        butterchurnSpectrum
    }

    func snapshotButterchurnWaveform() -> [Float] {
        butterchurnWaveform
    }
}

// MARK: - Tap Context

/// Context passed to audio tap for callback to VisualizerPipeline
private struct VisualizerTapContext: @unchecked Sendable {
    let pipelinePointer: UnsafeMutableRawPointer
}

// MARK: - VisualizerPipeline

/// Manages audio visualization tap and data processing.
/// Extracts from AudioPlayer for single responsibility and cleaner separation.
///
/// **Architecture:**
/// - Mechanism layer component, sits alongside AudioPlayer
/// - Owns tap lifecycle and scratch buffer management
/// - Provides callbacks for visualizer data updates
/// - Handles all FFT/spectrum processing on audio thread
@MainActor
@Observable
final class VisualizerPipeline {
    // MARK: - Tap State

    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private weak var mixerNode: AVAudioMixerNode?

    // MARK: - Visualizer Data Storage

    @ObservationIgnored private var peaks: [Float] = Array(repeating: 0.0, count: 20)
    @ObservationIgnored private var lastUpdateTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    @ObservationIgnored private var latestRMS: [Float] = []
    @ObservationIgnored private var latestSpectrum: [Float] = []
    @ObservationIgnored private var latestWaveform: [Float] = []

    // Butterchurn audio data - populated by tap, consumed at 30 FPS
    @ObservationIgnored private var butterchurnSpectrum: [Float] = Array(repeating: 0, count: 1024)
    @ObservationIgnored private var butterchurnWaveform: [Float] = Array(repeating: 0, count: 1024)
    @ObservationIgnored private var lastButterchurnUpdate: TimeInterval = 0

    // MARK: - Configuration

    /// Smoothing factor for visualizer levels (0..1, higher = smoother)
    var smoothing: Float = 0.6

    /// Peak falloff rate (units per second)
    var peakFalloff: Float = 1.2

    // MARK: - Observable State (for UI)

    /// Current smoothed visualizer levels (20 bars)
    private(set) var levels: [Float] = []

    // MARK: - Callbacks

    /// Called when visualizer data is updated (from audio tap)
    var onDataUpdate: ((VisualizerData) -> Void)?

    // MARK: - Initialization

    init() {}

    deinit {
        // Note: Cannot call removeTap from deinit since it's @MainActor
        // Caller must call removeTap() before releasing
    }

    // MARK: - Tap Management

    /// Install visualizer tap on the given mixer node
    /// - Parameter mixer: The AVAudioMixerNode to tap
    func installTap(on mixer: AVAudioMixerNode) {
        guard !tapInstalled else { return }

        // Store weak reference for removal
        mixerNode = mixer

        // Remove any existing tap first
        mixer.removeTap(onBus: 0)

        let scratch = VisualizerScratchBuffers()

        let context = VisualizerTapContext(
            pipelinePointer: Unmanaged.passUnretained(self).toOpaque()
        )

        let handler = Self.makeTapHandler(context: context, scratch: scratch)

        // Buffer size 2048 for Butterchurn FFT - provides 1024 frequency bins
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        tapInstalled = true

        AppLog.debug(.audio, "VisualizerPipeline: Tap installed")
    }

    /// Remove visualizer tap if installed
    func removeTap() {
        guard tapInstalled, let mixer = mixerNode else { return }
        mixer.removeTap(onBus: 0)
        tapInstalled = false
        mixerNode = nil

        AppLog.debug(.audio, "VisualizerPipeline: Tap removed")
    }

    /// Check if tap is currently installed
    var isTapInstalled: Bool {
        tapInstalled
    }

    // MARK: - Butterchurn Data Access

    /// Thread-safe snapshot of current Butterchurn audio data
    /// Called by ButterchurnBridge at 30 FPS to push data to JavaScript
    func snapshotButterchurnFrame() -> ButterchurnFrame {
        ButterchurnFrame(
            spectrum: butterchurnSpectrum,
            waveform: butterchurnWaveform,
            timestamp: lastButterchurnUpdate
        )
    }

    /// Get RMS data mapped to requested number of bands
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

    /// Get waveform samples resampled to requested count
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

    // MARK: - Data Update (called from tap)

    /// Update visualizer levels with new data from audio tap
    /// Called on MainActor from tap handler via Task
    func updateLevels(with data: VisualizerData, useSpectrum: Bool) {
        // Store all visualizer datasets
        latestRMS = data.rms
        latestSpectrum = data.spectrum
        latestWaveform = data.waveform

        // Store Butterchurn data
        butterchurnSpectrum = data.butterchurnSpectrum
        butterchurnWaveform = data.butterchurnWaveform
        lastButterchurnUpdate = CACurrentMediaTime()

        // Apply smoothing to active mode
        let used = useSpectrum ? data.spectrum : data.rms
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(0, Float(now - lastUpdateTime))
        lastUpdateTime = now

        let alpha = max(0, min(1, smoothing))
        var smoothed = [Float](repeating: 0, count: used.count)

        for b in 0..<used.count {
            let prev = (b < levels.count) ? levels[b] : 0
            smoothed[b] = alpha * prev + (1 - alpha) * used[b]
            let fall = peakFalloff * dt
            let dropped = max(0, peaks[b] - fall)
            peaks[b] = max(dropped, smoothed[b])
        }

        levels = smoothed

        // Notify callback
        onDataUpdate?(data)
    }

    // MARK: - Tap Handler (nonisolated)

    /// Build the tap handler in a nonisolated context so AVAudioEngine can call it on its realtime queue.
    private nonisolated static func makeTapHandler(
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

            // Mix channels to mono
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

            // Compute RMS per bar
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

                // Compute spectrum using Goertzel algorithm
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

            // Process Butterchurn FFT (2048-point for 1024 bins)
            scratch.withMonoReadOnly { mono in
                scratch.processButterchurnFFT(samples: mono)
            }
            let butterchurnSpectrumSnapshot = scratch.snapshotButterchurnSpectrum()
            let butterchurnWaveformSnapshot = scratch.snapshotButterchurnWaveform()

            // Create data container
            let data = VisualizerData(
                rms: rmsSnapshot,
                spectrum: spectrumSnapshot,
                waveform: waveformSnapshot,
                butterchurnSpectrum: butterchurnSpectrumSnapshot,
                butterchurnWaveform: butterchurnWaveformSnapshot
            )

            // Dispatch to MainActor to update pipeline state
            Task { @MainActor [context, data] in
                let pipeline = Unmanaged<VisualizerPipeline>.fromOpaque(context.pipelinePointer).takeUnretainedValue()
                // Get useSpectrum from AppSettings on MainActor
                let useSpectrum = AppSettings.instance().visualizerMode == .spectrum
                pipeline.updateLevels(with: data, useSpectrum: useSpectrum)
            }
        }
    }
}
