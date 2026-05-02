import Foundation

/// 10-band biquad coefficient table.
///
/// Phase 2: empty stub. `VideoTapContext` allocates two blocks against
/// this stride to exercise the alloc/dealloc lifecycle, but no install
/// API exists and `tapProcess` does not read coefficients (see
/// `placeholder.md` P-1 + P-4).
///
/// Phase 3: replace with the real `struct BiquadCoefficientSet { let
/// bands: (BiquadCoefs ×10) }` + `static func compute(for:sampleRate:)`
/// factory using RBJ-cookbook formulas. Phase 3 ALSO chooses the
/// race-safe hand-off scheme (per P-4 — triple-buffer + epoch counter,
/// RCU/epoch reclamation, or `Mutex<BiquadCoefficientSet>` with
/// `withLockIfAvailable`) before any code reads from this type on the
/// render thread. The original ADR-4 atomic-pointer double-buffer was
/// withdrawn during Phase 2 because it was not race-safe.
struct BiquadCoefficientSet {}
