import Foundation

/// Render-thread-confined 10-band biquad cascade (Transposed Direct Form II)
/// with per-(band, channel) filter history.
///
/// **Threading.** Created on the main thread (in `VideoTapContext.init`) and
/// thereafter touched ONLY by the render thread inside `tapProcess`. Main never
/// reads or writes it. That render-confinement is its `RenderThreadSafe` story
/// (conformance in `RenderThreadSafe.swift`); it is reached through the Context's
/// `let cascade` reference, which is published before any render callback and
/// never reassigned.
///
/// **Coefficients.** `currentCoefficients` is the render-owned cache the cascade
/// filters with. `tapProcess` refreshes it from the Context's
/// `Mutex<BiquadCoefficientSet?>` via `withLockIfAvailable` (ADR-4 amendment #2);
/// the filter then runs lock-free. `nil` → bypass (pre-install or EQ-off).
///
/// Filter state (`z1`/`z2`) uses manually-allocated buffers (not `Array`) so the
/// per-sample inner loop is free of bounds checks, CoW uniqueness checks, and ARC.
final class BiquadCascade {
    static let bandCount = BiquadCoefficientSet.bandCount

    /// Maximum channels the cascade is sized for (covers up to 7.1 surround).
    let maxChannels: Int

    /// Render-owned coefficient cache. Refreshed by `tapProcess`; read here.
    var currentCoefficients: BiquadCoefficientSet?

    /// Render-owned flag tracking whether EQ was engaged on the previous callback.
    /// `tapProcess` resets the cascade on the false→true edge so a re-enable starts
    /// from clean filter history instead of stale `z1`/`z2` (avoids a click).
    var isEngaged = false

    private let z1: UnsafeMutablePointer<Float>
    private let z2: UnsafeMutablePointer<Float>
    private let stateCount: Int

    init(maxChannels: Int) {
        precondition(maxChannels > 0)
        self.maxChannels = maxChannels
        self.currentCoefficients = nil
        let count = Self.bandCount * maxChannels
        self.stateCount = count
        self.z1 = .allocate(capacity: count)
        self.z2 = .allocate(capacity: count)
        z1.initialize(repeating: 0, count: count)
        z2.initialize(repeating: 0, count: count)
    }

    deinit {
        z1.deinitialize(count: stateCount).deallocate()
        z2.deinitialize(count: stateCount).deallocate()
    }

    /// Zero all filter history. Called on `kMTAudioProcessingTapFlag_StartOfStream`
    /// (seek / new stream) so stale state does not bleed across a discontinuity (ADR-9).
    func reset() {
        z1.update(repeating: 0, count: stateCount)
        z2.update(repeating: 0, count: stateCount)
    }

    /// Filter one channel's samples in place, cascading all 10 bands.
    ///
    /// `base` points at the channel's first sample; successive samples are
    /// `stride` apart (`stride == 1` for non-interleaved, `== channelCount` for
    /// interleaved). No-op when no coefficients are cached or `channel` is out of
    /// range. Flat (`.identity`) bands are skipped and their state zeroed.
    func process(_ base: UnsafeMutablePointer<Float>, frameCount: Int, channel: Int, stride: Int) {
        guard let coefs = currentCoefficients, channel >= 0, channel < maxChannels, frameCount > 0 else { return }
        coefs.withBands { bands in
            for band in 0..<Self.bandCount {
                let c = bands[band]
                let idx = band * maxChannels + channel
                if c == .identity {
                    z1[idx] = 0
                    z2[idx] = 0
                    continue
                }
                let b0 = c.b0, b1 = c.b1, b2 = c.b2, a1 = c.a1, a2 = c.a2
                var s1 = z1[idx]
                var s2 = z2[idx]
                var p = base
                for _ in 0..<frameCount {
                    let x = p.pointee
                    let y = b0 * x + s1
                    s1 = b1 * x - a1 * y + s2
                    s2 = b2 * x - a2 * y
                    p.pointee = y
                    p += stride
                }
                z1[idx] = s1
                z2[idx] = s2
            }
        }
    }
}
