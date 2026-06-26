// MARK: - `VideoTapContext` storage contract (ADR-3a Gate 1)
//
// `VideoTapContext` carries state across the C-callback boundary of an
// `MTAudioProcessingTap`. The render thread reads it via
// `MTAudioProcessingTapGetStorage`; the main thread writes to it via the
// public methods on this class. The class envelope is annotated
// `@unchecked Sendable` to silence the Swift 6 concurrency check at the
// FFI boundary; the unsafety must be CONTAINED by the storage shape of
// every stored property.
//
// Permitted storage shapes (each enforced at review time + by the contract
// tests in `VideoTapSendableContractTests`):
//
//   * `Synchronization.Atomic<T>` for `T: AtomicRepresentable`
//   * `Synchronization.Mutex<T>` (only for state changed rarely AND
//     non-trivially; the render thread MUST use `tryLock` and skip on
//     contention — never block on the audio render deadline)
//   * `let` of an immutable primitive value type
//   * `UnsafePointer<T>` / `UnsafeMutablePointer<T>` whose lifetime is
//     managed explicitly by this class's `init` / `deinit`
//   * Any other type that conforms to the `RenderThreadSafe` marker
//     protocol (declared in `RenderThreadSafe.swift`)
//
// Forbidden storage shapes:
//
//   * `@MainActor`-isolated or actor-isolated types
//   * Non-`Sendable` reference types
//   * Swift closures that capture state
//   * `var` of any type that is not `Atomic<...>` or `Mutex<...>`
//
// Adding a new field requires updating this comment AND adding the
// appropriate `RenderThreadSafe` conformance OR proving the field falls
// under a permitted shape.
//
// Current fields (Phase 3-4):
//   * `coefficients: Mutex<BiquadCoefficientSet?>` — main→render coefficient
//     hand-off (render uses `withLockIfAvailable`; ADR-4 amendment #2).
//   * `cascade: BiquadCascade` — render-confined DSP state; `RenderThreadSafe`
//     by render-confinement (main never touches it after `init`).
//   * `feed: VisualizerFeed` — shared (injected) single-slot hand-off;
//     `RenderThreadSafe` (`@unchecked Sendable`, trylock publish).
//   * `scratch: VisualizerScratchBuffers` — per-tap render-confined visualizer
//     DSP scratch; `RenderThreadSafe` by render-confinement.
//   * the `Atomic<…>` parameter/format/telemetry fields below — including the
//     Phase 6 deadline counters (`budgetOverrunCount`, `deadlineRiskCount`,
//     `lastDeadlineRiskHostTime`), all `Atomic<UInt64>`.
//
// See plan.md ADR-3 + ADR-3a + ADR-4 amendment #2 for the design rationale.

import Foundation
import Synchronization

/// Immutable, `Sendable` snapshot of a `VideoTapContext`'s telemetry counters,
/// produced on the main thread via `VideoTapContext.diagnosticSnapshot`. Consumed
/// by the Phase 8 CPU-benchmark gate and production diagnostics.
struct VideoTapDiagnostics: Sendable, Equatable {
    let processCallCount: UInt64
    let frameCount: UInt64
    let budgetOverrunCount: UInt64
    let deadlineRiskCount: UInt64
    /// `mach_absolute_time` ticks of the most recent deadline-risk sample (0 = none).
    let lastDeadlineRiskHostTime: UInt64
    let isActive: Bool
}

/// Tap-side state shared across the C-callback boundary of an
/// `MTAudioProcessingTap` attached to an `AVPlayerItem`'s `audioMix`.
///
/// One Context per `MTAudioProcessingTap` per `AVPlayerItem` (ADR-7
/// "one-tap-per-item invariant"). The Context outlives `init` via
/// `Unmanaged.passRetained` at attach time and is released exactly once in
/// `tapFinalize`.
final class VideoTapContext: @unchecked Sendable {
    // MARK: Coefficient hand-off (ADR-4 amendment #2 — Mutex + withLockIfAvailable)

    /// EQ biquad coefficients handed from the main thread to the render thread.
    /// Main writes via `installCoefficients` (`withLock`); the render thread reads
    /// via `withLockIfAvailable`, copying the value into its own render-confined
    /// cache and never blocking. `nil` until the first install → the render thread
    /// bypasses the cascade. Replaces the withdrawn atomic-pointer A/B double-buffer
    /// (race-unsafe; see plan.md ADR-4 amendment #2).
    let coefficients: Mutex<BiquadCoefficientSet?>

    // MARK: Render-owned DSP state

    /// 10-band biquad cascade with per-(band, channel) filter history. Created
    /// here so it shares the Context's lifetime — no separate `Unmanaged` retain,
    /// so the todo 2.40 `passRetained`↔`tapFinalize` leak balance is unchanged.
    /// Touched ONLY by the render thread (`tapProcess`); its `RenderThreadSafe`
    /// story is render-confinement (conformance in `RenderThreadSafe.swift`).
    let cascade: BiquadCascade

    // MARK: Visualizer (Phase 4 — ADR-6 dual-producer)

    /// Shared single-slot hand-off carrying pre-computed visualizer arrays to the
    /// main thread. INJECTED (owned by `VisualizerPipeline`, shared with the engine
    /// producer); only one producer is active at a time. `RenderThreadSafe`
    /// (`@unchecked Sendable`, `trylock` publish).
    let feed: VisualizerFeed

    /// Per-tap render-confined scratch buffers for the visualizer DSP (mono / RMS /
    /// Goertzel / FFT working set). OWNED by this Context (allocated in `init`, dies
    /// with the Context). `RenderThreadSafe` (render-confined).
    let scratch: VisualizerScratchBuffers

    // MARK: User-controlled DSP parameters

    /// Stereo balance as `Float` packed into the low 32 bits via
    /// `Float.bitPattern`. Range [-1, 1], default 0.0 (center) — matches
    /// `AudioPlayer.balance` / `AVAudioNode.pan` so Phase 5 writes through.
    let balance: Atomic<UInt32>

    /// EQ enabled gate. Render thread short-circuits the biquad cascade
    /// when false. Default false until Phase 5 wires the real EQ state.
    let isEqOn: Atomic<Bool>

    /// Preamp linear gain as `Float` packed into the low 32 bits. Default
    /// 1.0 (no gain).
    let preampLinearGainBits: Atomic<UInt32>

    // MARK: Format gate (ADR-11)

    /// Encoded ASBD-validity tag set by `tapPrepare`. Render thread
    /// pass-throughs when this is anything other than
    /// `formatTagSupportedFloat32LPCM`.
    let processingFormatTag: Atomic<UInt32>

    /// Sample rate observed by the most recent `tapPrepare`, packed as
    /// `Double.bitPattern`. Phase 5 polls this from the main thread to
    /// trigger coefficient recompute on rate changes.
    let pendingSampleRate: Atomic<UInt64>

    // MARK: Telemetry (Phase 6 — deadline-miss instrumentation)

    let processCallCount: Atomic<UInt64>
    let frameCount: Atomic<UInt64>
    let isActive: Atomic<Bool>

    /// Count of sampled `tapProcess` callbacks whose wall-clock exceeded 10% of the
    /// buffer budget. Render thread increments (lock-free); main reads via snapshot.
    let budgetOverrunCount: Atomic<UInt64>
    /// Count of sampled callbacks exceeding 50% of budget (deadline risk).
    let deadlineRiskCount: Atomic<UInt64>
    /// Host time (`mach_absolute_time` ticks) of the most recent deadline-risk
    /// sample. Doubles as the rate-limit gate for any main-thread surfacing.
    let lastDeadlineRiskHostTime: Atomic<UInt64>

    // MARK: Format tag constants

    static let formatTagUnknown: UInt32 = 0
    static let formatTagSupportedFloat32LPCM: UInt32 = 1
    static let formatTagUnsupported: UInt32 = 2

    // MARK: Lifecycle

    /// Max channels the render-side cascade is sized for. 16 comfortably covers
    /// every realistic PCM video layout (mono … 7.1 and beyond); channels past
    /// this bound pass through un-EQ'd (graceful degradation for content that
    /// effectively does not exist in practice).
    static let maxDSPChannels = 16

    init(feed: VisualizerFeed) {
        self.feed = feed
        self.scratch = VisualizerScratchBuffers()
        self.coefficients = Mutex<BiquadCoefficientSet?>(nil)
        self.cascade = BiquadCascade(maxChannels: VideoTapContext.maxDSPChannels)
        self.balance = Atomic<UInt32>(Float(0.0).bitPattern)
        self.isEqOn = Atomic<Bool>(false)
        self.preampLinearGainBits = Atomic<UInt32>(Float(1.0).bitPattern)
        self.processingFormatTag = Atomic<UInt32>(VideoTapContext.formatTagUnknown)
        self.pendingSampleRate = Atomic<UInt64>(0)
        self.processCallCount = Atomic<UInt64>(0)
        self.frameCount = Atomic<UInt64>(0)
        self.isActive = Atomic<Bool>(false)
        self.budgetOverrunCount = Atomic<UInt64>(0)
        self.deadlineRiskCount = Atomic<UInt64>(0)
        self.lastDeadlineRiskHostTime = Atomic<UInt64>(0)
    }

    /// Evaluate one timed `tapProcess` callback against its wall-clock budget and
    /// bump the deadline counters. **Render-thread-safe and allocation-free** — pure
    /// atomic updates, no logging (counters are read on the main thread via
    /// `diagnosticSnapshot`). This is also the unit-test seam: callable directly with
    /// synthetic values, so tests need not inject a real render-thread delay.
    /// Integer-ratio comparisons avoid floating point on the render path.
    func recordProcessingDeadline(elapsedNanos: UInt64, budgetNanos: UInt64, nowHostTime: UInt64) {
        guard budgetNanos > 0 else { return }
        if elapsedNanos * 10 > budgetNanos {          // > 10% of budget → overrun
            _ = budgetOverrunCount.add(1, ordering: .relaxed)
        }
        if elapsedNanos * 2 > budgetNanos {           // > 50% of budget → deadline risk
            _ = deadlineRiskCount.add(1, ordering: .relaxed)
            lastDeadlineRiskHostTime.store(nowHostTime, ordering: .relaxed)
        }
    }

    /// Immutable main-thread snapshot of the telemetry counters (Phase 8 CPU gate +
    /// production observability of "EQ doesn't work on this video" reports).
    var diagnosticSnapshot: VideoTapDiagnostics {
        VideoTapDiagnostics(
            processCallCount: processCallCount.load(ordering: .relaxed),
            frameCount: frameCount.load(ordering: .relaxed),
            budgetOverrunCount: budgetOverrunCount.load(ordering: .relaxed),
            deadlineRiskCount: deadlineRiskCount.load(ordering: .relaxed),
            lastDeadlineRiskHostTime: lastDeadlineRiskHostTime.load(ordering: .relaxed),
            isActive: isActive.load(ordering: .relaxed)
        )
    }

    /// Install a fresh coefficient set from the main thread. Blocking `withLock`
    /// is fine here — main can afford to wait, and the lock is held only for a
    /// flat value-type assignment. The render thread reads the same `Mutex` with
    /// `withLockIfAvailable` (never blocking). See plan.md ADR-4 amendment #2.
    func installCoefficients(_ newSet: BiquadCoefficientSet) {
        coefficients.withLock { $0 = newSet }
    }

    #if DEBUG
    /// DEBUG-only factory for `VideoTapSendableContractTests`. Builds a
    /// Context with no AVPlayer dependency so the contract tests can
    /// reflect the storage shape without spinning up audio infrastructure.
    static func _makeForContractTest() -> VideoTapContext {
        VideoTapContext(feed: VisualizerFeed())
    }
    #endif
}
