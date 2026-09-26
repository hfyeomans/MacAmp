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

## Production-translation hazards (informs plan.md hardening checklist)

The spike intentionally cuts corners that would not be acceptable in production. Items captured here for the implementation phase, raised by Oracle review (2026-05-01):

1. **`Unmanaged.passRetained` leak on tap-create failure** — `spikes/avplayer-inplace-tap-dsp/Sources/InPlaceTapSpike/main.swift` lines 131-149. The spike calls `passRetained(context)` to populate `clientInfo`, then `MTAudioProcessingTapCreate`. If `Create` fails, `tapInit` never fires and the +1 retain leaks. Production must release the `Unmanaged` on the create-failure path:
   ```swift
   let retained = Unmanaged.passRetained(context)
   var callbacks = MTAudioProcessingTapCallbacks(...)
   callbacks.clientInfo = UnsafeMutableRawPointer(retained.toOpaque())

   var tapOut: MTAudioProcessingTap?
   let status = MTAudioProcessingTapCreate(..., &tapOut)
   guard status == noErr, let tap = tapOut else {
       retained.release()  // production-required cleanup
       throw TapError.createFailed(status)
   }
   ```

2. **Float sample-format assumption** — `main.swift` lines 84-87 assume `bufferList.mBuffers.mData` is `Float`-typed. Production must guard via `tapPrepare`'s `AudioStreamBasicDescription` inspection: only enable the DSP path when `mFormatID == kAudioFormatLinearPCM && (mFormatFlags & kAudioFormatFlagIsFloat) != 0 && mBitsPerChannel == 32`. Bypass DSP (pass-through) on any other format.

3. **No deadline-miss instrumentation.** Spike does not measure tap-callback wall-clock time. Production must add periodic sample-and-alarm logging (`mach_absolute_time` delta on `tapProcess` entry/exit, alarm if >10 % of buffer budget) — necessary for the Q3 CPU benchmark gate and for production observability.

4. **No tear-down sequencing.** Spike runs to clip-end and exits (process tear-down handles cleanup). Production must handle pause / seek / stop with the EQ-active flag, ensure `tapFinalize` fires after all in-flight `tapProcess` calls, and verify no `Unmanaged` access after release.

5. **Channel-count assumption.** Spike accepts whatever ASBD `tapPrepare` reports (44.1 kHz stereo Float32 in this case). Production must handle 1 / 2 / 5.1 / 7.1 channel counts: stereo is a no-op for the audible path, mono duplicates to L+R, surround applies the `inferredSurroundChannelLayoutTag` downmix table (see Q5 allowlist) **for the visualizer feed only** — the audible path leaves the layout untouched.

6. **No long-playback / route-change validation.** Spike is 3 s; the architecture's claim that AVPlayer handles route changes natively (vs the failed engine-routing path) is not yet empirically validated for the in-place tap topology. plan.md verification matrix must include AirPods connect/disconnect mid-playback, AirPlay handoff, and >10-minute continuous playback to validate drift behavior under the new clock topology.

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
