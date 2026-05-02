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
// See plan.md ADR-3 + ADR-3a for the design rationale.

import Foundation
import Synchronization

/// Tap-side state shared across the C-callback boundary of an
/// `MTAudioProcessingTap` attached to an `AVPlayerItem`'s `audioMix`.
///
/// One Context per `MTAudioProcessingTap` per `AVPlayerItem` (ADR-7
/// "one-tap-per-item invariant"). The Context outlives `init` via
/// `Unmanaged.passRetained` at attach time and is released exactly once in
/// `tapFinalize`.
final class VideoTapContext: @unchecked Sendable {
    // MARK: Coefficient hand-off (Phase 2 placeholder; Phase 3 redesigns per P-4)

    /// Active coefficient block for the render thread. **Permanently
    /// `nil` in Phase 2** — no install API exists, and `tapProcess`
    /// does not read this pointer. Phase 3 will introduce an install
    /// path under a race-safe scheme (per `placeholder.md` P-4); the
    /// field is declared now so the surrounding lifecycle (alloc /
    /// dealloc / nil-default) is exercised end-to-end.
    let coefficientSetPointer: Atomic<UnsafePointer<BiquadCoefficientSet>?>

    /// The two pre-allocated coefficient blocks. Phase 2 only exercises
    /// their alloc/dealloc lifecycle (init / deinit below). Phase 3's
    /// install path will repurpose them per the chosen P-4 scheme — or
    /// replace them with a different storage layout if the scheme
    /// requires (e.g. RCU allocates fresh per install).
    private let coefficientBlockA: UnsafeMutablePointer<BiquadCoefficientSet>
    private let coefficientBlockB: UnsafeMutablePointer<BiquadCoefficientSet>

    // MARK: User-controlled DSP parameters

    /// Stereo balance as `Float` packed into the low 32 bits via
    /// `Float.bitPattern`. Default 0.5 (center).
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

    // MARK: Telemetry (Phase 6 expands)

    let processCallCount: Atomic<UInt64>
    let frameCount: Atomic<UInt64>
    let isActive: Atomic<Bool>

    // MARK: Format tag constants

    static let formatTagUnknown: UInt32 = 0
    static let formatTagSupportedFloat32LPCM: UInt32 = 1
    static let formatTagUnsupported: UInt32 = 2

    // MARK: Lifecycle

    init() {
        let blockA = UnsafeMutablePointer<BiquadCoefficientSet>.allocate(capacity: 1)
        blockA.initialize(to: BiquadCoefficientSet())
        let blockB = UnsafeMutablePointer<BiquadCoefficientSet>.allocate(capacity: 1)
        blockB.initialize(to: BiquadCoefficientSet())
        self.coefficientBlockA = blockA
        self.coefficientBlockB = blockB

        self.coefficientSetPointer = Atomic<UnsafePointer<BiquadCoefficientSet>?>(nil)
        self.balance = Atomic<UInt32>(Float(0.5).bitPattern)
        self.isEqOn = Atomic<Bool>(false)
        self.preampLinearGainBits = Atomic<UInt32>(Float(1.0).bitPattern)
        self.processingFormatTag = Atomic<UInt32>(VideoTapContext.formatTagUnknown)
        self.pendingSampleRate = Atomic<UInt64>(0)
        self.processCallCount = Atomic<UInt64>(0)
        self.frameCount = Atomic<UInt64>(0)
        self.isActive = Atomic<Bool>(false)
    }

    deinit {
        coefficientBlockA.deinitialize(count: 1).deallocate()
        coefficientBlockB.deinitialize(count: 1).deallocate()
    }

    // NOTE: NO coefficient-install API is exposed in Phase 2.
    //
    // ADR-4's original design (atomic-pointer A/B swap) was withdrawn
    // because it is not race-safe in the multi-install case: a render
    // thread holding a pointer to slot A from a prior load can have
    // slot A overwritten by a subsequent main-thread swap A→B→A. No
    // acquire/release ordering closes that pointee-lifetime window.
    //
    // Phase 2 leaves `coefficientSetPointer` as a permanently-nil
    // `Atomic<UnsafePointer<BiquadCoefficientSet>?>` and `tapProcess`
    // never reads it. The two pre-allocated coefficient blocks
    // (`coefficientBlockA` / `coefficientBlockB` declared above)
    // remain so the alloc/dealloc lifecycle is exercised end-to-end.
    //
    // Phase 3 GATING work (see `tasks/avplayer-native-video-dsp/placeholder.md`
    // P-4): pick a race-safe hand-off scheme before exposing any
    // install API or before `tapProcess` reads coefficients. Candidates:
    // triple-buffer + atomic in-use counter, RCU/epoch reclamation,
    // or `Mutex<BiquadCoefficientSet>` with `withLockIfAvailable`.

    #if DEBUG
    /// DEBUG-only factory for `VideoTapSendableContractTests`. Builds a
    /// Context with no AVPlayer dependency so the contract tests can
    /// reflect the storage shape without spinning up audio infrastructure.
    static func _makeForContractTest() -> VideoTapContext {
        VideoTapContext()
    }
    #endif
}
