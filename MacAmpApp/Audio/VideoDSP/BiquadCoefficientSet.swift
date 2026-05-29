import Foundation

/// One biquad section's normalized coefficients (direct form, `a0` == 1).
///
/// Trivially-copyable value type — no heap, no CoW, no ARC traffic — so a
/// `BiquadCoefficientSet` can be copied on the render thread under a
/// `withLockIfAvailable` trylock without allocator or reference-counting work
/// (ADR-4 amendment #2).
struct BiquadCoefs: Sendable, Equatable {
    var b0: Float
    var b1: Float
    var b2: Float
    var a1: Float
    var a2: Float

    /// Unity pass-through section.
    static let identity = BiquadCoefs(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)
}

/// 10-band biquad coefficient table for the video-tap EQ cascade.
///
/// The 10 sections are stored as a fixed-size homogeneous tuple (not an
/// `Array`) so the whole set is a flat value type — see `BiquadCoefs` for why
/// that matters on the render thread. Read the bands with `withBands`.
///
/// `compute(for:sampleRate:)` mirrors the engine-side `AVAudioUnitEQ`
/// configuration in `EqualizerController.configureEQ` using the RBJ Audio EQ
/// Cookbook formulas (ADR-8): octave-bandwidth peaking for bands 1-8, low/high
/// shelf for bands 0/9. The band center `frequencies` below are the single source
/// of truth — `EqualizerController.configureEQ` reads them too — and
/// `BiquadNumericalMatchTests` guards the engine↔tap numerical match.
struct BiquadCoefficientSet: Sendable, Equatable {
    var bands: (BiquadCoefs, BiquadCoefs, BiquadCoefs, BiquadCoefs, BiquadCoefs,
                BiquadCoefs, BiquadCoefs, BiquadCoefs, BiquadCoefs, BiquadCoefs)

    static let bandCount = 10

    /// Winamp internal processing frequencies (Hz). **Single source of truth** —
    /// `EqualizerController.configureEQ` reads this too, so the engine `AVAudioUnitEQ`
    /// and the tap cascade can never drift apart.
    static let frequencies: [Float] = [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000]

    /// Octave bandwidth for the 8 parametric bands (matches `AVAudioUnitEQ.bandwidth = 1.0`).
    static let bandwidthOctaves: Double = 1.0

    /// All-identity (flat) table — render bypasses to this before the first install.
    static let flat = BiquadCoefficientSet(bands: (.identity, .identity, .identity, .identity, .identity,
                                                   .identity, .identity, .identity, .identity, .identity))

    /// Contiguous read access to the 10 bands. The homogeneous tuple is laid out
    /// contiguously, so binding its bytes to `BiquadCoefs` is well-defined.
    func withBands<R>(_ body: (UnsafeBufferPointer<BiquadCoefs>) -> R) -> R {
        // Homogeneous tuples are contiguous in practice; assert no padding surprise.
        assert(MemoryLayout.size(ofValue: bands) == Self.bandCount * MemoryLayout<BiquadCoefs>.stride,
               "BiquadCoefficientSet.bands layout is not a contiguous \(Self.bandCount)-element array")
        return withUnsafeBytes(of: bands) { raw in
            body(raw.bindMemory(to: BiquadCoefs.self))
        }
    }

    // Manual `Equatable` — a 10-tuple field blocks synthesized conformance.
    static func == (lhs: BiquadCoefficientSet, rhs: BiquadCoefficientSet) -> Bool {
        lhs.withBands { l in
            rhs.withBands { r in
                for i in 0..<bandCount where l[i] != r[i] { return false }
                return true
            }
        }
    }

    /// Build the coefficient table for a given EQ state at a given sample rate.
    /// Computed on the main thread (off the render path); arithmetic in `Double`
    /// for precision, stored as `Float`.
    static func compute(for state: EqualizerState, sampleRate: Double) -> BiquadCoefficientSet {
        // Defensive: a non-positive sample rate (e.g. queried before `tapPrepare`)
        // would produce NaN coefficients; a mis-sized gain array would trap. Fall
        // back to flat (pass-through) rather than corrupt the render thread.
        guard sampleRate > 0, state.bandGainsDB.count == bandCount else { return .flat }
        var sections = [BiquadCoefs](repeating: .identity, count: bandCount)
        for i in 0..<bandCount {
            let f0 = Double(frequencies[i])
            let gainDB = Double(state.bandGainsDB[i])
            if gainDB == 0 { continue } // flat band → exact identity (already set); render skips it
            switch i {
            case 0:
                sections[i] = lowShelf(f0: f0, gainDB: gainDB, sampleRate: sampleRate)
            case bandCount - 1:
                sections[i] = highShelf(f0: f0, gainDB: gainDB, sampleRate: sampleRate)
            default:
                sections[i] = peaking(f0: f0, gainDB: gainDB, bandwidthOctaves: bandwidthOctaves, sampleRate: sampleRate)
            }
        }
        return BiquadCoefficientSet(bands: (sections[0], sections[1], sections[2], sections[3], sections[4],
                                            sections[5], sections[6], sections[7], sections[8], sections[9]))
    }

    // MARK: - RBJ Audio EQ Cookbook coefficient derivations

    private static func normalized(b0: Double, b1: Double, b2: Double,
                                   a0: Double, a1: Double, a2: Double) -> BiquadCoefs {
        BiquadCoefs(b0: Float(b0 / a0), b1: Float(b1 / a0), b2: Float(b2 / a0),
                    a1: Float(a1 / a0), a2: Float(a2 / a0))
    }

    /// Peaking (parametric) EQ, octave-bandwidth parameterization.
    private static func peaking(f0: Double, gainDB: Double, bandwidthOctaves: Double, sampleRate: Double) -> BiquadCoefs {
        let A = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = sinw0 * sinh((log(2.0) / 2.0) * bandwidthOctaves * w0 / sinw0)
        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cosw0
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cosw0
        let a2 = 1.0 - alpha / A
        return normalized(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)
    }

    /// Low-shelf, RBJ slope `S = 1` (the canonical no-resonance default that matches
    /// `AVAudioUnitEQ`'s shelf, which exposes no bandwidth/Q parameter).
    private static func lowShelf(f0: Double, gainDB: Double, sampleRate: Double) -> BiquadCoefs {
        let A = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = (sinw0 / 2.0) * sqrt(2.0) // S = 1
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
        let b0 = A * ((A + 1.0) - (A - 1.0) * cosw0 + twoSqrtAAlpha)
        let b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosw0)
        let b2 = A * ((A + 1.0) - (A - 1.0) * cosw0 - twoSqrtAAlpha)
        let a0 = (A + 1.0) + (A - 1.0) * cosw0 + twoSqrtAAlpha
        let a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosw0)
        let a2 = (A + 1.0) + (A - 1.0) * cosw0 - twoSqrtAAlpha
        return normalized(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)
    }

    /// High-shelf, RBJ slope `S = 1`.
    private static func highShelf(f0: Double, gainDB: Double, sampleRate: Double) -> BiquadCoefs {
        let A = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * f0 / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = (sinw0 / 2.0) * sqrt(2.0) // S = 1
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
        let b0 = A * ((A + 1.0) + (A - 1.0) * cosw0 + twoSqrtAAlpha)
        let b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosw0)
        let b2 = A * ((A + 1.0) + (A - 1.0) * cosw0 - twoSqrtAAlpha)
        let a0 = (A + 1.0) - (A - 1.0) * cosw0 + twoSqrtAAlpha
        let a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosw0)
        let a2 = (A + 1.0) - (A - 1.0) * cosw0 - twoSqrtAAlpha
        return normalized(b0: b0, b1: b1, b2: b2, a0: a0, a1: a1, a2: a2)
    }
}
