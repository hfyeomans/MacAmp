import AVFoundation
import Accelerate
import Observation
import os

// MARK: - Butterchurn Audio Frame

/// Snapshot of audio data for Butterchurn visualization
/// Produced by VisualizerPipeline tap, consumed by ButterchurnBridge at 30 FPS
/// Sendable for safe cross-actor transfer in Swift 6
struct ButterchurnFrame: Sendable {
    let spectrum: [Float]       // 1024 frequency bins (from 2048-point FFT)
    let waveform: [Float]       // 1024 mono samples (time-domain)
    let timestamp: TimeInterval // CACurrentMediaTime() when captured
}

// MARK: - Visualizer Data

/// Container for all visualizer datasets produced by the audio tap
/// Sendable for safe cross-actor transfer in Swift 6
struct VisualizerData: Sendable {
    let rms: [Float]
    let spectrum: [Float]
    let waveform: [Float]
    let butterchurnSpectrum: [Float]
    let butterchurnWaveform: [Float]
}

// MARK: - Shared Buffer (Lock-Free Audio-to-Main Transfer)

/// Thread-safe shared buffer for transferring visualizer data from the audio tap
/// to the main thread without any allocation on the audio thread.
///
/// Uses os_unfair_lock with trylock on the audio thread (non-blocking, drops frame
/// on contention) and regular lock on the main thread (safe to block briefly).
private final class VisualizerSharedBuffer: @unchecked Sendable {
    private var rms = [Float](repeating: 0, count: 20)
    private var spectrum = [Float](repeating: 0, count: 20)
    private var waveform = [Float](repeating: 0, count: 76)
    private var bcSpectrum = [Float](repeating: 0, count: 1024)
    private var bcWaveform = [Float](repeating: 0, count: 1024)
    private var waveformCount: Int = 0
    private var rmsCount: Int = 0
    private var spectrumCount: Int = 0

    private var lock = os_unfair_lock()
    private var generation: UInt64 = 0
    private var lastConsumed: UInt64 = 0

    /// Audio thread: try to publish data (non-blocking).
    /// Returns false if lock is contended (frame is dropped).
    func tryPublish(from scratch: VisualizerScratchBuffers, oscilloscopeSamples: Int, validFrameCount: Int) -> Bool {
        guard os_unfair_lock_trylock(&lock) else { return false }
        defer { os_unfair_lock_unlock(&lock) }

        let scratchRms = scratch.rms
        let rCount = min(scratchRms.count, rms.count)
        scratchRms.withUnsafeBufferPointer { src in
            rms.withUnsafeMutableBufferPointer { dst in
                if rCount > 0, let s = src.baseAddress, let d = dst.baseAddress {
                    memcpy(d, s, rCount * MemoryLayout<Float>.stride)
                }
            }
        }
        rmsCount = rCount

        let scratchSpec = scratch.spectrum
        let sCount = min(scratchSpec.count, spectrum.count)
        scratchSpec.withUnsafeBufferPointer { src in
            spectrum.withUnsafeMutableBufferPointer { dst in
                if sCount > 0, let s = src.baseAddress, let d = dst.baseAddress {
                    memcpy(d, s, sCount * MemoryLayout<Float>.stride)
                }
            }
        }
        spectrumCount = sCount

        // Downsample waveform using validFrameCount (not mono.count)
        let scratchMono = scratch.mono
        let monoLen = validFrameCount
        let step = max(1, monoLen / oscilloscopeSamples)
        let actualSamples = min(oscilloscopeSamples, waveform.count)
        scratchMono.withUnsafeBufferPointer { src in
            waveform.withUnsafeMutableBufferPointer { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return }
                for i in 0..<actualSamples {
                    let idx = min(i * step, monoLen - 1)
                    d[i] = s[idx]
                }
            }
        }
        waveformCount = actualSamples

        let scratchBcSpec = scratch.butterchurnSpectrum
        scratchBcSpec.withUnsafeBufferPointer { src in
            bcSpectrum.withUnsafeMutableBufferPointer { dst in
                let count = min(src.count, dst.count)
                if count > 0, let s = src.baseAddress, let d = dst.baseAddress {
                    memcpy(d, s, count * MemoryLayout<Float>.stride)
                }
            }
        }

        let scratchBcWave = scratch.butterchurnWaveform
        scratchBcWave.withUnsafeBufferPointer { src in
            bcWaveform.withUnsafeMutableBufferPointer { dst in
                let count = min(src.count, dst.count)
                if count > 0, let s = src.baseAddress, let d = dst.baseAddress {
                    memcpy(d, s, count * MemoryLayout<Float>.stride)
                }
            }
        }

        generation &+= 1
        return true
    }

    /// Main thread: consume latest data (blocking lock, safe for main thread).
    func consume() -> VisualizerData? {
        os_unfair_lock_lock(&lock)

        guard generation != lastConsumed else {
            os_unfair_lock_unlock(&lock)
            return nil
        }
        lastConsumed = generation

        // Copy raw data under lock (memcpy only, no construction)
        let localRms = Array(rms.prefix(rmsCount))
        let localSpec = Array(spectrum.prefix(spectrumCount))
        let localWave = Array(waveform.prefix(waveformCount))
        let localBcSpec = Array(bcSpectrum)
        let localBcWave = Array(bcWaveform)

        os_unfair_lock_unlock(&lock)

        // Construct VisualizerData after releasing lock
        return VisualizerData(
            rms: localRms,
            spectrum: localSpec,
            waveform: localWave,
            butterchurnSpectrum: localBcSpec,
            butterchurnWaveform: localBcWave
        )
    }
}

// MARK: - Goertzel Coefficients

/// Pre-computed Goertzel coefficients for spectrum analysis.
/// Depends on bar count and sample rate. Recomputed only when sample rate
/// changes (i.e., on track change), not on every tap callback (~21.5 Hz).
/// This eliminates 20x pow() + 20x cos() calls per callback.
private struct GoertzelCoefficients {
    var coefficients: [Float]
    var equalizationGains: [Float]
    private(set) var sampleRate: Float = 0

    init(bars: Int) {
        coefficients = [Float](repeating: 0, count: bars)
        equalizationGains = [Float](repeating: 0, count: bars)
    }

    mutating func updateIfNeeded(bars: Int, sampleRate: Float) -> Bool {
        guard sampleRate != self.sampleRate else { return false }
        self.sampleRate = sampleRate
        let minimumFrequency: Float = 50
        let maximumFrequency: Float = min(16000, sampleRate * 0.45)
        for b in 0..<bars {
            let normalized = Float(b) / Float(max(1, bars - 1))
            let logScale = minimumFrequency * pow(maximumFrequency / minimumFrequency, normalized)
            let linScale = minimumFrequency + normalized * (maximumFrequency - minimumFrequency)
            let centerFrequency = 0.91 * logScale + 0.09 * linScale
            let omega = 2 * Float.pi * centerFrequency / sampleRate
            coefficients[b] = 2 * cos(omega)
            let normalizedFreq = (centerFrequency - minimumFrequency) / (maximumFrequency - minimumFrequency)
            let dbAdjustment = -8.0 + 16.0 * normalizedFreq
            equalizationGains[b] = pow(10.0, dbAdjustment / 20.0)
        }
        return true
    }
}

// MARK: - Scratch Buffers

/// Scratch buffers are confined to the audio tap queue, so @unchecked Sendable is safe.
private final class VisualizerScratchBuffers: @unchecked Sendable {
    private(set) var mono: [Float] = []
    private(set) var rms: [Float] = []
    private(set) var spectrum: [Float] = []

    // Pre-computed Goertzel coefficients (recomputed only when sample rate changes)
    var goertzel: GoertzelCoefficients

    // Butterchurn FFT buffers
    private static let butterchurnFFTSize: Int = 2048
    private static let butterchurnBins: Int = 1024

    private var butterchurnReal: [Float] = Array(repeating: 0, count: butterchurnFFTSize)
    private var butterchurnImag: [Float] = Array(repeating: 0, count: butterchurnFFTSize)
    private(set) var butterchurnSpectrum: [Float] = Array(repeating: 0, count: butterchurnBins)
    private(set) var butterchurnWaveform: [Float] = Array(repeating: 0, count: butterchurnBins)

    // Pre-allocated FFT working buffers (avoid per-buffer allocations on audio thread)
    private var hannWindow: [Float] = Array(repeating: 0, count: butterchurnFFTSize)
    private var fftInputReal: [Float] = Array(repeating: 0, count: butterchurnFFTSize / 2)
    private var fftInputImag: [Float] = Array(repeating: 0, count: butterchurnFFTSize / 2)
    private var fftOutputReal: [Float] = Array(repeating: 0, count: butterchurnFFTSize / 2)
    private var fftOutputImag: [Float] = Array(repeating: 0, count: butterchurnFFTSize / 2)

    // vDSP FFT setup (log2(2048) = 11)
    private let fftSetup: vDSP_DFT_Setup?

    // Pre-allocated capacity to avoid reallocation on frame-size changes
    private static let maxFrameCount = 4096
    private static let maxBars = 20

    init() {
        goertzel = GoertzelCoefficients(bars: Self.maxBars)

        // Create FFT setup for 2048-point real-to-complex transform
        fftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(Self.butterchurnFFTSize),
            .FORWARD
        )

        // Pre-compute Hann window (never changes)
        vDSP_hann_window(&hannWindow, vDSP_Length(Self.butterchurnFFTSize), Int32(vDSP_HANN_NORM))

        // Pre-allocate buffers at max capacity to avoid reallocation
        mono = Array(repeating: 0, count: Self.maxFrameCount)
        rms = Array(repeating: 0, count: Self.maxBars)
        spectrum = Array(repeating: 0, count: Self.maxBars)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    func prepare(frameCount: Int, bars: Int, sampleRate: Float) {
        // Grow buffers only if needed (pre-allocated at maxFrameCount/maxBars,
        // so this branch should never execute in normal operation)
        if mono.count < frameCount {
            mono = Array(repeating: 0, count: frameCount)
        } else {
            mono.withUnsafeMutableBufferPointer { pointer in
                guard let baseAddress = pointer.baseAddress else { return }
                vDSP_vclr(baseAddress, 1, vDSP_Length(frameCount))
            }
        }

        if rms.count < bars {
            rms = Array(repeating: 0, count: bars)
        }

        if spectrum.count < bars {
            spectrum = Array(repeating: 0, count: bars)
        }

        // Recompute Goertzel coefficients only when sample rate changes (once per track)
        _ = goertzel.updateIfNeeded(bars: bars, sampleRate: sampleRate)
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

    // MARK: - Butterchurn FFT Processing

    /// Process audio samples for Butterchurn visualization
    /// - Parameter samples: Mono audio samples (at least 2048 for full FFT)
    /// - Note: Uses pre-allocated buffers to avoid audio-thread allocations
    func processButterchurnFFT(samples: [Float], validCount: Int? = nil) {
        guard let setup = fftSetup else { return }

        let sampleCount = min(validCount ?? samples.count, Self.butterchurnFFTSize)

        // Copy input samples and zero-pad if needed
        for i in 0..<sampleCount {
            butterchurnReal[i] = samples[i]
        }
        for i in sampleCount..<Self.butterchurnFFTSize {
            butterchurnReal[i] = 0
        }

        // Apply pre-computed Hann window to reduce spectral leakage
        vDSP_vmul(butterchurnReal, 1, hannWindow, 1, &butterchurnReal, 1, vDSP_Length(Self.butterchurnFFTSize))

        // Prepare split complex for FFT using pre-allocated buffers
        // For real-to-complex DFT, input is interleaved as even/odd
        for i in 0..<(Self.butterchurnFFTSize / 2) {
            fftInputReal[i] = butterchurnReal[i * 2]
            fftInputImag[i] = butterchurnReal[i * 2 + 1]
        }

        // Execute FFT into pre-allocated output buffers
        vDSP_DFT_Execute(setup, fftInputReal, fftInputImag, &fftOutputReal, &fftOutputImag)

        // Compute magnitude spectrum (first 1024 bins)
        // Magnitude = sqrt(real² + imag²)
        for i in 0..<Self.butterchurnBins {
            let real = fftOutputReal[i % fftOutputReal.count]
            let imag = fftOutputImag[i % fftOutputImag.count]
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
}

// MARK: - VisualizerPipeline

/// Manages audio visualization tap and data processing.
/// Extracted from AudioPlayer for single responsibility and cleaner separation.
///
/// **Layer:** Mechanism (audio processing)
/// **Responsibilities:**
/// - Owns tap lifecycle and scratch buffer management
/// - Provides callbacks for visualizer data updates
/// - Handles all FFT/spectrum processing on audio thread
/// - Manages Butterchurn frame generation at 30 FPS
@MainActor
@Observable
final class VisualizerPipeline {
    // MARK: - Tap State
    // Note: nonisolated(unsafe) allows removeTap() to be called from deinit
    // Safe because AVAudioMixerNode.removeTap is thread-safe and at deinit
    // there are no concurrent references

    @ObservationIgnored nonisolated(unsafe) private var tapInstalled = false
    @ObservationIgnored nonisolated(unsafe) private weak var mixerNode: AVAudioMixerNode?
    @ObservationIgnored private let sharedBuffer = VisualizerSharedBuffer()
    @ObservationIgnored nonisolated(unsafe) private var pollTimer: Timer?

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

    /// Cached spectrum/RMS mode to avoid per-frame AppSettings lookup
    /// AudioPlayer sets this when visualizerMode changes in AppSettings
    var useSpectrum: Bool = true

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
        let handler = Self.makeTapHandler(sharedBuffer: sharedBuffer, scratch: scratch)

        // Buffer size 2048 for Butterchurn FFT - provides 1024 frequency bins
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil, block: handler)
        tapInstalled = true
        startPollTimer()

        AppLog.debug(.audio, "VisualizerPipeline: Tap installed")
    }

    /// Remove visualizer tap if installed
    /// Nonisolated to allow calling from deinit (AVAudioMixerNode.removeTap is thread-safe)
    nonisolated func removeTap() {
        guard tapInstalled, let mixer = mixerNode else { return }
        // pollTimer was scheduled on main run loop — must invalidate from main thread
        dispatchPrecondition(condition: .onQueue(.main))
        pollTimer?.invalidate()
        pollTimer = nil
        mixer.removeTap(onBus: 0)
        tapInstalled = false
        mixerNode = nil

        AppLog.debug(.audio, "VisualizerPipeline: Tap removed")
    }

    /// Clear cached visualizer data so UI shows empty bars instead of stale data.
    /// Call after removeTap() when transitioning away from audio playback.
    func clearData() {
        levels = []
        latestRMS = []
        latestSpectrum = []
        latestWaveform = []
        butterchurnSpectrum = Array(repeating: 0, count: 1024)
        butterchurnWaveform = Array(repeating: 0, count: 1024)
    }

    /// Check if tap is currently installed
    nonisolated var isTapInstalled: Bool {
        tapInstalled
    }

    // MARK: - Poll Timer

    private func startPollTimer() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                self?.pollVisualizerData()
            }
        }
    }

    private func pollVisualizerData() {
        guard let data = sharedBuffer.consume() else { return }
        updateLevels(with: data, useSpectrum: useSpectrum)
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

    // MARK: - Data Update (called from poll timer)

    /// Update visualizer levels with new data from shared buffer
    /// Called on MainActor from 30 Hz poll timer
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

    // swiftlint:disable function_body_length
    /// Build the tap handler in a nonisolated context so AVAudioEngine can call it on its realtime queue.
    /// Uses SPSC shared buffer instead of Task { @MainActor } to avoid allocations on the audio thread.
    private nonisolated static func makeTapHandler(
        sharedBuffer: VisualizerSharedBuffer,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
        // swiftlint:disable:next closure_body_length
        { buffer, _ in
            let channelCount = Int(buffer.format.channelCount)
            guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            if frameCount == 0 { return }

            let bars = 20
            scratch.prepare(frameCount: frameCount, bars: bars, sampleRate: Float(buffer.format.sampleRate))

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
            scratch.withMonoReadOnly { mono in // swiftlint:disable:this closure_body_length
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

                // Compute spectrum using Goertzel algorithm with precomputed coefficients
                scratch.withSpectrum { spectrum in
                    let sampleCount = min(1024, frameCount)
                    if sampleCount > 0 {
                        let coefficients = scratch.goertzel.coefficients
                        let gains = scratch.goertzel.equalizationGains

                        for b in 0..<bars {
                            let coefficient = coefficients[b]
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
                            value *= gains[b]
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

            // Process Butterchurn FFT (2048-point for 1024 bins)
            scratch.withMonoReadOnly { mono in
                scratch.processButterchurnFFT(samples: mono, validCount: frameCount)
            }

            // Publish to shared buffer (non-blocking: drops frame on contention)
            _ = sharedBuffer.tryPublish(from: scratch, oscilloscopeSamples: 76, validFrameCount: frameCount)
        }
    }
    // swiftlint:enable function_body_length
}
