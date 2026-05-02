import Accelerate
import Foundation

// MARK: - Goertzel Coefficients

/// Pre-computed Goertzel coefficients for spectrum analysis.
/// Depends on bar count and sample rate. Recomputed only when sample rate
/// changes (i.e., on track change), not on every tap callback (~21.5 Hz).
/// This eliminates 20x pow() + 20x cos() calls per callback.
struct GoertzelCoefficients {
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

/// Per-tap audio-thread scratch buffers. One instance per render thread / tap.
///
/// Scratch buffers are confined to a single audio render thread, so
/// `@unchecked Sendable` is safe: there are no cross-thread accesses to
/// internal state. The producing thread runs RMS bucketing, Goertzel
/// spectrum analysis, and 2048-pt vDSP FFT into these pre-allocated buffers,
/// then publishes the results via `VisualizerFeed.tryPublish(from:)`.
///
/// **Producers:** the engine-side `mainMixerNode` tap (existing) and the
/// video-side `MTAudioProcessingTap` render path (S3-2 `avplayer-native-video-dsp`).
/// Each tap allocates its own instance at attach time and reuses it for the
/// lifetime of the tap — never shared across taps.
final class VisualizerScratchBuffers: @unchecked Sendable {
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

    func prepare(frameCount: Int, bars: Int, sampleRate: Float) -> Int {
        // CRITICAL: Never allocate on audio thread. Clamp to pre-allocated capacity
        // instead of growing buffers. AVAudioEngine buffer size is 2048, well within
        // our 4096 cap, so this clamp should never activate in normal operation.
        let cappedFrameCount = min(frameCount, mono.count)

        mono.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            vDSP_vclr(baseAddress, 1, vDSP_Length(cappedFrameCount))
        }

        // Recompute Goertzel coefficients only when sample rate changes (once per track)
        _ = goertzel.updateIfNeeded(bars: bars, sampleRate: sampleRate)

        return cappedFrameCount
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
