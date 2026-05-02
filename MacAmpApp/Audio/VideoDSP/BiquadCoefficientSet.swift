import Foundation

/// 10-band biquad coefficient table consumed by `BiquadCascade.process` on
/// the render thread and produced by `EqualizerController` (Phase 5)
/// whenever EQ state or sample rate changes.
///
/// Phase 2 declares this as an empty stub so that `VideoTapContext` can
/// allocate two pre-sized blocks for the ADR-4 atomic-pointer
/// double-buffer. Phase 3 fills in the per-band RBJ-cookbook coefficients
/// (`bands: (BiquadCoefs × 10)`) and the `compute(for:sampleRate:)`
/// factory.
struct BiquadCoefficientSet {}
