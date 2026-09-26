import Foundation
import Testing
@testable import MacAmp

/// Phase 5 EQ-fanout tests: `EqualizerController` pushes its state to registered
/// video-tap `VideoTapContext`s (coefficients via the Mutex hand-off + isEqOn/preamp
/// atomics), recomputes on sample-rate change, and stops on unregister (ADR-5).
///
/// Balance fanout (`AudioPlayer.balance` → Context `balance` atomic) is a trivial
/// atomic write through a private registry; it's exercised end-to-end by the manual
/// smoke (todo 5.16) and the balance law is unit-tested in `BiquadNumericalMatchTests`.
@MainActor
@Suite("VideoTap EQ fanout", .tags(.audio))
struct VideoTapFanoutTests {
    static func makeContext(sampleRate: Double) -> VideoTapContext {
        let ctx = VideoTapContext(feed: VisualizerFeed())
        ctx.pendingSampleRate.store(sampleRate.bitPattern, ordering: .relaxed)
        return ctx
    }

    static func installedCoefficients(_ ctx: VideoTapContext) -> BiquadCoefficientSet? {
        ctx.coefficients.withLock { $0 }
    }

    @Test("register pushes current EQ state (coefficients + atomics) to the Context")
    func registerPushesState() {
        let eq = EqualizerController()
        eq.isEqOn = true
        eq.preamp = 6
        eq.eqBands = [8, 4, 0, -4, -8, -4, 0, 4, 8, 0]

        let ctx = Self.makeContext(sampleRate: 44_100)
        eq.registerVideoTapContext(ctx)

        let expected = BiquadCoefficientSet.compute(for: eq.equalizerState, sampleRate: 44_100)
        #expect(Self.installedCoefficients(ctx) == expected)
        #expect(ctx.isEqOn.load(ordering: .relaxed) == true)
        #expect(Float(bitPattern: ctx.preampLinearGainBits.load(ordering: .relaxed)) == eq.equalizerState.preampLinearGain)
    }

    @Test("EQ change after register fans out new coefficients")
    func eqChangeFansOut() {
        let eq = EqualizerController()
        eq.isEqOn = true
        let ctx = Self.makeContext(sampleRate: 48_000)
        eq.registerVideoTapContext(ctx)

        eq.setEqBand(index: 0, value: 10) // low shelf boost
        let expected = BiquadCoefficientSet.compute(for: eq.equalizerState, sampleRate: 48_000)
        #expect(Self.installedCoefficients(ctx) == expected)
        #expect(expected != .flat, "a non-zero band must produce non-flat coefficients")
    }

    @Test("sample-rate poll recomputes when pendingSampleRate becomes known")
    func sampleRatePollRecomputes() {
        let eq = EqualizerController()
        eq.isEqOn = true
        eq.eqBands = [9, 0, 0, 0, 0, 0, 0, 0, 0, 0]

        // Register before the rate is known (mirrors startVideoLoad → register at 0).
        let ctx = Self.makeContext(sampleRate: 0)
        eq.registerVideoTapContext(ctx)
        #expect(Self.installedCoefficients(ctx) == .flat, "rate 0 → fail-closed flat at register")

        // tapPrepare publishes the real rate; the poll should recompute.
        ctx.pendingSampleRate.store(Double(44_100).bitPattern, ordering: .relaxed)
        eq.pollVideoTapSampleRates()

        let expected = BiquadCoefficientSet.compute(for: eq.equalizerState, sampleRate: 44_100)
        #expect(expected != .flat)
        #expect(Self.installedCoefficients(ctx) == expected, "poll must recompute at the now-known rate")
    }

    @Test("balance fanout: AudioPlayer.balance updates a registered Context's atomic")
    func balanceFanout() {
        let player = AudioPlayer()
        let ctx = VideoTapContext(feed: VisualizerFeed())
        func ctxBalance() -> Float { Float(bitPattern: ctx.balance.load(ordering: .relaxed)) }

        player.registerVideoTapContextForBalance(ctx)
        for value in [Float(0.5), -1.0, 0.0, 1.0, -0.25] {
            player.balance = value
            #expect(ctxBalance() == value, "Context balance atomic should track AudioPlayer.balance \(value)")
        }

        player.unregisterVideoTapContextForBalance(ctx)
        player.balance = 0.9
        #expect(ctxBalance() == -0.25, "unregistered Context must not receive balance fanout")
    }

    @Test("unregister stops further fanout")
    func unregisterStopsFanout() {
        let eq = EqualizerController()
        eq.isEqOn = true
        eq.eqBands = [6, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let ctx = Self.makeContext(sampleRate: 48_000)
        eq.registerVideoTapContext(ctx)
        let afterRegister = Self.installedCoefficients(ctx)

        eq.unregisterVideoTapContext(ctx)
        eq.setEqBand(index: 9, value: 12) // change EQ after unregister

        #expect(Self.installedCoefficients(ctx) == afterRegister, "unregistered Context must not receive further fanout")
    }
}
