import AVFoundation
import Foundation
import Testing
@testable import MacAmp

/// Verifies the video-tap `BiquadCascade` reproduces `AVAudioUnitEQ`'s magnitude
/// response within ≤0.5 dB (ADR-8 acceptance criterion), plus preamp/balance/bypass
/// parity. Magnitude is measured as steady-state RMS gain of a pure sine — which
/// equals |H(f)| regardless of filter phase/latency, so no alignment is needed.
struct BiquadNumericalMatchTests {
    enum RenderError: Error {
        case renderFailed(AVAudioEngineManualRenderingStatus)
        case incomplete(rendered: Int, expected: Int)
    }

    static let sampleRate = 48_000.0
    /// Band gains in dB for five EQ shapes (10 bands each).
    static let presets: [(name: String, gains: [Float])] = [
        ("flat",        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ("v-shape",     [8, 5, 2, 0, -3, -3, 0, 2, 5, 8]),
        ("descending",  [9, 7, 5, 3, 1, -1, -3, -5, -7, -9]),
        ("mid-scoop",   [0, 2, 4, 6, -6, -6, 6, 4, 2, 0]),
        ("alternating", [6, -6, 6, -6, 6, -6, 6, -6, 6, -6]),
    ]

    /// Log-spaced probe frequencies across the audible band.
    static let probeFrequencies: [Double] = {
        let lo = 20.0, hi = 20_000.0, n = 40
        return (0..<n).map { lo * pow(hi / lo, Double($0) / Double(n - 1)) }
    }()

    @Test("Full-EQ magnitude match: BiquadCascade vs AVAudioUnitEQ ≤0.5 dB over 20Hz–20kHz")
    func fullEqMagnitudeMatch() throws {
        var worst = 0.0
        var worstInfo = ""
        for (name, gains) in Self.presets {
            for f in Self.probeFrequencies {
                let eqDB = try Self.eqMagnitudeDB(frequency: f, gains: gains)
                let cascadeDB = Self.cascadeMagnitudeDB(frequency: f, gains: gains)
                let err = abs(eqDB - cascadeDB)
                if err > worst {
                    worst = err
                    worstInfo = "preset=\(name) f=\(Int(f))Hz eq=\(String(format: "%.3f", eqDB))dB cascade=\(String(format: "%.3f", cascadeDB))dB"
                }
            }
        }
        #expect(worst <= 0.5, "Worst-case magnitude error \(String(format: "%.3f", worst)) dB > 0.5 dB at \(worstInfo)")
    }

    @Test("EQ-off bypass: nil and flat coefficients pass audio through unchanged")
    func bypassParity() {
        // Reproducible pseudo-random input.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(truncatingIfNeeded: seed >> 33)) / Float(Int32.max)
        }
        let input = (0..<4_096).map { _ in next() }

        // (a) No coefficients installed → exact pass-through.
        let nilCascade = BiquadCascade(maxChannels: 1)
        var outNil = input
        outNil.withUnsafeMutableBufferPointer {
            nilCascade.process($0.baseAddress!, frameCount: $0.count, channel: 0, stride: 1)
        }
        #expect(outNil == input, "nil-coefficient cascade must be bit-identical pass-through")

        // (b) Flat (all-0 dB) coefficients → every band is .identity → exact pass-through.
        let flatCascade = BiquadCascade(maxChannels: 1)
        flatCascade.currentCoefficients = BiquadCoefficientSet.compute(
            for: EqualizerState(isEqOn: true, preampLinearGain: 1.0,
                                bandGainsDB: Array(repeating: 0, count: 10)),
            sampleRate: Self.sampleRate)
        var outFlat = input
        outFlat.withUnsafeMutableBufferPointer {
            flatCascade.process($0.baseAddress!, frameCount: $0.count, channel: 0, stride: 1)
        }
        #expect(outFlat == input, "flat-EQ cascade must be bit-identical pass-through")
    }

    @Test("Preamp parity: dB→linear conversion and applied gain within 0.1 dB")
    @MainActor
    func preampParity() {
        let controller = EqualizerController()
        for dB in [Float(-12), -6, 0, 6, 12] {
            controller.preamp = dB
            let linear = controller.equalizerState.preampLinearGain
            let expected = Float(pow(10.0, Double(dB) / 20.0))
            #expect(abs(linear - expected) < 1e-4, "preampLinearGain(\(dB)dB)=\(linear) expected \(expected)")
            let appliedDB = 20.0 * log10(Double(linear))
            #expect(abs(appliedDB - Double(dB)) <= 0.1, "applied preamp \(appliedDB)dB vs \(dB)dB")
        }
    }

    @Test("Balance law ([-1,1], 0 center): center unity; full pan mutes far channel; half pans halve it")
    func balanceLaw() {
        func approx(_ a: Float, _ b: Float) -> Bool { abs(a - b) < 1e-6 }
        let cases: [(bal: Float, left: Float, right: Float)] = [
            (-1.0, 1.0, 0.0),  // full left → right muted
            (-0.5, 1.0, 0.5),  // half left → right halved
            (0.0, 1.0, 1.0),   // center → both unity
            (0.5, 0.5, 1.0),   // half right → left halved
            (1.0, 0.0, 1.0),   // full right → left muted
        ]
        for c in cases {
            let (l, r) = VideoTap.balanceGains(c.bal)
            #expect(approx(l, c.left) && approx(r, c.right),
                    "balance \(c.bal) → (\(l), \(r)); expected (\(c.left), \(c.right))")
        }
        // Out-of-range input is clamped, not extrapolated (no negative gain).
        #expect(VideoTap.balanceGains(-2.0) == (1.0, 0.0))
        #expect(VideoTap.balanceGains(2.0) == (0.0, 1.0))
    }

    @Test("Stride correctness: interleaved channel matches non-interleaved")
    func strideEquivalence() {
        let frames = 4_096
        let gains: [Float] = [6, 0, -4, 0, 3, 0, -2, 0, 5, 0]
        let coefs = BiquadCoefficientSet.compute(
            for: EqualizerState(isEqOn: true, preampLinearGain: 1.0, bandGainsDB: gains),
            sampleRate: Self.sampleRate)
        let w = 2.0 * Double.pi * 1_000.0 / Self.sampleRate
        let signal = (0..<frames).map { Float(sin(w * Double($0))) }

        // Non-interleaved: contiguous, stride 1.
        let mono = BiquadCascade(maxChannels: 2)
        mono.currentCoefficients = coefs
        var monoBuf = signal
        monoBuf.withUnsafeMutableBufferPointer {
            mono.process($0.baseAddress!, frameCount: frames, channel: 0, stride: 1)
        }

        // Interleaved stereo: same signal in channel 0 (even indices), stride 2.
        let inter = BiquadCascade(maxChannels: 2)
        inter.currentCoefficients = coefs
        var interBuf = [Float](repeating: 0, count: frames * 2)
        for i in 0..<frames { interBuf[i * 2] = signal[i] }
        interBuf.withUnsafeMutableBufferPointer {
            inter.process($0.baseAddress!, frameCount: frames, channel: 0, stride: 2)
        }

        var maxDiff: Float = 0
        for i in 0..<frames { maxDiff = max(maxDiff, abs(monoBuf[i] - interBuf[i * 2])) }
        #expect(maxDiff < 1e-6, "interleaved (stride 2) channel-0 output diverges from non-interleaved by \(maxDiff)")
    }

    @Test("reset() clears all filter state (re-engage starts clean)")
    func resetClearsState() {
        let gains: [Float] = [8, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let coefs = BiquadCoefficientSet.compute(
            for: EqualizerState(isEqOn: true, preampLinearGain: 1.0, bandGainsDB: gains),
            sampleRate: Self.sampleRate)
        let w = 2.0 * Double.pi * 70.0 / Self.sampleRate
        let signal = (0..<2_048).map { Float(sin(w * Double($0))) }

        // Dirty cascade: run signal (builds z1/z2), then reset, then run a probe.
        let dirty = BiquadCascade(maxChannels: 1)
        dirty.currentCoefficients = coefs
        var warm = signal
        warm.withUnsafeMutableBufferPointer { dirty.process($0.baseAddress!, frameCount: $0.count, channel: 0, stride: 1) }
        dirty.reset()
        var dirtyProbe = signal
        dirtyProbe.withUnsafeMutableBufferPointer { dirty.process($0.baseAddress!, frameCount: $0.count, channel: 0, stride: 1) }

        // Fresh cascade: same probe from zero state.
        let fresh = BiquadCascade(maxChannels: 1)
        fresh.currentCoefficients = coefs
        var freshProbe = signal
        freshProbe.withUnsafeMutableBufferPointer { fresh.process($0.baseAddress!, frameCount: $0.count, channel: 0, stride: 1) }

        var maxDiff: Float = 0
        for i in 0..<signal.count { maxDiff = max(maxDiff, abs(dirtyProbe[i] - freshProbe[i])) }
        #expect(maxDiff < 1e-6, "post-reset output differs from fresh cascade by \(maxDiff) — reset left stale state")
    }

    // MARK: - Measurement helpers

    /// Steady-state RMS gain (dB) of a sine at `frequency` through the `BiquadCascade`.
    static func cascadeMagnitudeDB(frequency: Double, gains: [Float]) -> Double {
        let total = 16_384, skip = 8_192
        var input = [Float](repeating: 0, count: total)
        let w = 2.0 * Double.pi * frequency / sampleRate
        for i in 0..<total { input[i] = Float(sin(w * Double(i))) }

        let cascade = BiquadCascade(maxChannels: 1)
        cascade.currentCoefficients = BiquadCoefficientSet.compute(
            for: EqualizerState(isEqOn: true, preampLinearGain: 1.0, bandGainsDB: gains),
            sampleRate: sampleRate)
        var output = input
        output.withUnsafeMutableBufferPointer { buf in
            cascade.process(buf.baseAddress!, frameCount: total, channel: 0, stride: 1)
        }
        return gainDB(input: input, output: output, skip: skip)
    }

    /// Steady-state RMS gain (dB) of a sine at `frequency` through a freshly
    /// configured `AVAudioUnitEQ` (configured identically to `EqualizerController`),
    /// rendered offline via `AVAudioEngine.manualRenderingMode`.
    static func eqMagnitudeDB(frequency: Double, gains: [Float]) throws -> Double {
        let total = 16_384, skip = 8_192
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                   channels: 1, interleaved: false)!

        let engine = AVAudioEngine()
        let eq = AVAudioUnitEQ(numberOfBands: 10)
        configure(eq, gains: gains)
        engine.attach(eq)

        let w = 2.0 * Double.pi * frequency / sampleRate
        var phaseIndex = 0
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, ablPtr in
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            let ptr = abl[0].mData!.assumingMemoryBound(to: Float.self)
            for i in 0..<Int(frameCount) {
                ptr[i] = Float(sin(w * Double(phaseIndex)))
                phaseIndex += 1
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0

        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
        try engine.start()

        let outBuf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                      frameCapacity: engine.manualRenderingMaximumFrameCount)!
        var output = [Float]()
        output.reserveCapacity(total)
        var rendered = 0
        while rendered < total {
            let frames = AVAudioFrameCount(min(Int(outBuf.frameCapacity), total - rendered))
            let status = try engine.renderOffline(frames, to: outBuf)
            guard status == .success else {
                engine.stop()
                throw RenderError.renderFailed(status)
            }
            let ch = outBuf.floatChannelData![0]
            for i in 0..<Int(outBuf.frameLength) { output.append(ch[i]) }
            rendered += Int(outBuf.frameLength)
        }
        engine.stop()
        guard rendered >= total else { throw RenderError.incomplete(rendered: rendered, expected: total) }

        let input = (0..<total).map { Float(sin(w * Double($0))) }
        return gainDB(input: input, output: Array(output.prefix(total)), skip: skip)
    }

    /// Configure an `AVAudioUnitEQ` identically to `EqualizerController.configureEQ`.
    static func configure(_ eq: AVAudioUnitEQ, gains: [Float]) {
        let freqs = BiquadCoefficientSet.frequencies
        for i in 0..<min(eq.bands.count, freqs.count) {
            let band = eq.bands[i]
            if i == 0 { band.filterType = .lowShelf }
            else if i == freqs.count - 1 { band.filterType = .highShelf }
            else { band.filterType = .parametric }
            band.frequency = freqs[i]
            band.bandwidth = 1.0
            band.gain = gains[i]
            band.bypass = false
        }
    }

    /// RMS gain in dB over the steady-state region (skipping `skip` transient samples).
    static func gainDB(input: [Float], output: [Float], skip: Int) -> Double {
        func rms(_ s: ArraySlice<Float>) -> Double {
            let sum = s.reduce(0.0) { $0 + Double($1) * Double($1) }
            return (sum / Double(s.count)).squareRoot()
        }
        let n = min(input.count, output.count)
        guard n > skip else { return 0 }
        let inRMS = rms(input[skip..<n])
        let outRMS = rms(output[skip..<n])
        guard inRMS > 0, outRMS > 0 else { return -.infinity }
        return 20.0 * log10(outRMS / inRMS)
    }
}
