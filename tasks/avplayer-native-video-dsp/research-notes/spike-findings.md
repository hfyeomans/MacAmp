# Phase 0 Spike Findings: `MTAudioProcessingTap` In-Place Modification

**Date:** 2026-05-01
**Branch:** `spike/avplayer-inplace-tap-dsp` (throwaway, cut from `feat/avplayer-native-video-dsp`)
**Spike code:** `spikes/avplayer-inplace-tap-dsp/` (~170 LOC, single Swift file)
**Verdict:** ✅ **Q1 kill-switch empirically resolved.**

---

## Goal

Validate empirically that:

1. `MTAudioProcessingTap` with `kMTAudioProcessingTapCreationFlag_PreEffects` supports in-place buffer modification on macOS 15+.
2. AVPlayer plays the modified buffer (not the original source).
3. The Swift 6.2 toolchain produces working code with `Synchronization.Atomic`, `@unchecked Sendable` Context, and `Unmanaged<Context>` lifetime through C callbacks.

Apple's SDK header documents (1) and (2) verbatim (`research-notes/apple-docs.md` Q1); the spike's role is empirical confirmation on the actual macOS 15+ runtime + our Swift 6.2 toolchain.

---

## Method

Minimal Swift 6.2 CLI tool loads a 3-second 44.1 kHz stereo MP4 clip from `clapperboard-videos/`, attaches an `MTAudioProcessingTap` with `_PreEffects`, applies `sample *= gain` in `tapProcess`, plays through default audio output. Two back-to-back runs:

1. Control: `gain=1.0` (no modification, normal volume)
2. Test: `gain=0.1` (-20 dB attenuation)

User compares auditorily; spike prints diagnostics for programmatic confirmation.

---

## Programmatic results

Both runs:

| Metric | Control (gain=1.0) | Test (gain=0.1) |
|---|---|---|
| `tapPrepare` sample rate | 44 100 Hz | 44 100 Hz |
| `tapPrepare` channels | 2 (non-interleaved Float32) | 2 (non-interleaved Float32) |
| `tapPrepare` `formatID` | `0x6C70636D` ('lpcm') | `0x6C70636D` ('lpcm') |
| `tapPrepare` `maxFrames` | 4 096 | 4 096 |
| `tapProcess` invocations | 38 | 39 |
| Frames processed | 155 648 | 159 744 |
| In-place buffer confirmed | ✅ `mData = 0x10a570000` (non-NULL) | ✅ `mData = 0x10a3ec000` (non-NULL) |
| Write verified | ✅ pre=-0.0695 → post=-0.0695 (× 1.0) | ✅ pre=-0.0695 → post=-0.00695 (× 0.1) |

The "Write verified" line proves the memory write went where expected: read sample S0 before the multiply, multiply, read S0 again, compare to `S0 × gain`. Match confirms no copy-on-write or re-read of the source buffer.

---

## Auditory result

User (2026-05-01) confirmed: two clips played sequentially, second was clearly quieter. The audible difference between control and test runs proves AVPlayer's downstream pipeline played the buffer as we wrote it — the kill-switch closes empirically.

---

## Toolchain notes (Swift 6.2 deltas observed during spike)

- **`Synchronization.Atomic<T>` requires `T: AtomicRepresentable`.** Float and Double are NOT supported. Pack Float as `UInt32` via `Float.bitPattern` / `Float(bitPattern:)`:
  ```swift
  let gainBits: Atomic<UInt32>
  var gain: Float { Float(bitPattern: gainBits.load(ordering: .relaxed)) }
  ```
  Use this pattern for the production `BiquadCascade` coefficient hand-off (10 bands × 5 coefficients × 2 channels = 100 atomic floats — or a single mutex-protected snapshot, TBD in plan.md).

- **`MTAudioProcessingTapCallbacks.init` parameter:** label is `init:` (no backticks needed). Compiler warns if escaped.

- **`MTAudioProcessingTapCreate` last parameter:** Swift bridges as `MTAudioProcessingTap?` directly, not `Unmanaged<MTAudioProcessingTap>?`. Pattern: `var tapOut: MTAudioProcessingTap?; &tapOut`.

- **`@unchecked Sendable` envelope on the Context class** is sufficient at the FFI boundary; individual atomic fields don't need `nonisolated(unsafe)` because `Atomic<T>` is `Sendable` by design. The saved branch's blanket `@unchecked Sendable` was correct in spirit; modernization on the new branch is the `Synchronization.Atomic` swap, not the Sendable carve-out.

- **`Unmanaged.passRetained` / `MTAudioProcessingTapGetStorage` / `Unmanaged.fromOpaque(...).release()` lifecycle:** identical to the saved branch's pattern, works cleanly in Swift 6.2 strict-concurrency mode.

---

## Out-of-scope items NOT validated by this spike

- **Numerical EQ equivalence** (Q2): deferred to implementation phase verification.
- **5.1 surround handling** (Q4): surround clip enumerated but spike tested stereo only. Defer to implementation.
- **CPU budget under full `BiquadCascade` load** (Q3): spike's `*= gain` cost is trivial; full 10-band biquad + balance + visualizer DSP cost is deferred.
- **Long-playback drift / clock stability:** 3-second clip; long-playback (>10 min) drift is implicit from the architecture (single AVPlayer master clock, no second clock domain) but not measured.

These were explicitly excluded from the spike scope per "reduced-scope" decision (option A in research.md "Spike scope decision"). They land in the implementation phase's verification work.

---

## Spike branch disposition

`spike/avplayer-inplace-tap-dsp` retained locally as reference for the implementation phase. To be deleted at S3-2 close. `spikes/` directory exists only on this branch — not merged to `feat/avplayer-native-video-dsp` or `main`.

---

## Reproduction

```bash
git checkout spike/avplayer-inplace-tap-dsp
cd spikes/avplayer-inplace-tap-dsp
swift build
./.build/debug/InPlaceTapSpike ../../clapperboard-videos/1_mp4_441_stereo.mp4 1.0   # control
./.build/debug/InPlaceTapSpike ../../clapperboard-videos/1_mp4_441_stereo.mp4 0.1   # -20 dB
```
