import Foundation
import Testing
@testable import MacAmp

/// Phase 6 deadline-miss telemetry tests. Exercises `recordProcessingDeadline`
/// directly with synthetic (elapsed, budget) values — the render-thread-safe pure
/// eval seam — so no real render-thread delay injection is needed.
@Suite("VideoTap telemetry", .tags(.audio))
struct VideoTapTelemetryTests {
    static func makeContext() -> VideoTapContext { VideoTapContext(feed: VisualizerFeed()) }

    @Test("under 10% of budget → no overrun, no risk")
    func underBudget() {
        let ctx = Self.makeContext()
        let budget: UInt64 = 10_000_000 // 10 ms
        ctx.recordProcessingDeadline(elapsedNanos: 500_000, budgetNanos: budget, nowHostTime: 1) // 5%
        let snap = ctx.diagnosticSnapshot
        #expect(snap.budgetOverrunCount == 0)
        #expect(snap.deadlineRiskCount == 0)
        #expect(snap.lastDeadlineRiskHostTime == 0)
    }

    @Test("between 10% and 50% → overrun only")
    func overrunOnly() {
        let ctx = Self.makeContext()
        let budget: UInt64 = 10_000_000
        ctx.recordProcessingDeadline(elapsedNanos: 3_000_000, budgetNanos: budget, nowHostTime: 42) // 30%
        let snap = ctx.diagnosticSnapshot
        #expect(snap.budgetOverrunCount == 1)
        #expect(snap.deadlineRiskCount == 0)
        #expect(snap.lastDeadlineRiskHostTime == 0, "no deadline risk → host time gate untouched")
    }

    @Test("over 50% → overrun AND deadline risk, records host time")
    func deadlineRisk() {
        let ctx = Self.makeContext()
        let budget: UInt64 = 10_000_000
        ctx.recordProcessingDeadline(elapsedNanos: 8_000_000, budgetNanos: budget, nowHostTime: 123_456) // 80%
        let snap = ctx.diagnosticSnapshot
        #expect(snap.budgetOverrunCount == 1, "a deadline risk is also a budget overrun")
        #expect(snap.deadlineRiskCount == 1)
        #expect(snap.lastDeadlineRiskHostTime == 123_456)
    }

    @Test("counters accumulate across calls; zero budget is ignored")
    func accumulationAndZeroBudget() {
        let ctx = Self.makeContext()
        let budget: UInt64 = 10_000_000
        ctx.recordProcessingDeadline(elapsedNanos: 6_000_000, budgetNanos: budget, nowHostTime: 1) // risk
        ctx.recordProcessingDeadline(elapsedNanos: 2_000_000, budgetNanos: budget, nowHostTime: 2) // overrun only
        ctx.recordProcessingDeadline(elapsedNanos: 9_000_000, budgetNanos: 0, nowHostTime: 3)       // ignored
        let snap = ctx.diagnosticSnapshot
        #expect(snap.budgetOverrunCount == 2)
        #expect(snap.deadlineRiskCount == 1)
        #expect(snap.lastDeadlineRiskHostTime == 1, "zero-budget call must not overwrite the last risk host time")
    }

    @Test("fresh context has zeroed telemetry")
    func freshIsZero() {
        let snap = Self.makeContext().diagnosticSnapshot
        #expect(snap.processCallCount == 0 && snap.frameCount == 0)
        #expect(snap.budgetOverrunCount == 0 && snap.deadlineRiskCount == 0)
        #expect(snap.isActive == false)
    }
}
