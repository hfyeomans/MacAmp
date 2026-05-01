# VisualizerFeed Extraction — Research Notes

## Current state

### Consumer

**File:** `MacAmpApp/Audio/VisualizerPipeline.swift`

- `VisualizerPipeline` (L325) is a `@MainActor @Observable` class.
- Internal hand-off is a `VisualizerSharedBuffer` (defined L36, held at L330) — a `private final class`
  guarded by `os_unfair_lock` with a `generation` counter. Not a ring buffer; it is a single-slot
  double-buffer (last-write-wins).
- **Consumer thread:** Main thread. A `Timer` fires at 30 Hz (L440, `.common` run-loop mode).
  Each tick calls `sharedBuffer.consume()` (L451), which takes the lock normally (blocking is safe on
  main thread), reads out the latest data if `generation != lastConsumed`, then calls `updateLevels`.
- **Consumer data format:** The shared buffer holds pre-processed results:
  - 20-element RMS bar array
  - 20-element Goertzel spectrum array
  - 76-element oscilloscope waveform (downsampled from mono)
  - 1024-element Butterchurn FFT magnitude spectrum
  - 1024-element Butterchurn waveform snapshot
- The consumer never sees raw PCM frames; all DSP runs on the producer side before hand-off.

### Producer (engine-side tap)

**Tap installed:** `AudioEngineController.installVisualizerTapIfNeeded()` (L278–281),
called via `AudioPlayer` at multiple play/resume sites (AudioPlayer.swift L473, L640, L739).

**Tap node/bus:** `audioEngine.mainMixerNode`, bus 0, bufferSize 2048 (VisualizerPipeline.swift L393).

**Format:** `nil` passed for format → engine delivers buffers in the mixer's native format
(interleaved stereo or non-interleaved Float32, whichever the engine uses; typically
non-interleaved Float32 at the hardware sample rate, commonly 44.1 kHz or 48 kHz).

**Producer thread:** AVAudioEngine's internal realtime render thread (not main, not a DispatchQueue).
The tap closure is `nonisolated static` (L565) — deliberately detached from any actor.

**Tap closure work** (L570–658 inside `makeTapHandler`):
1. Mix N channels → mono (manual loop, no allocation).
2. Compute 20-bar RMS in mono buckets.
3. Run Goertzel for 20-bar spectrum on first 1024 mono frames.
4. Run 2048-pt Hann-windowed vDSP FFT for Butterchurn spectrum + waveform.
5. `sharedBuffer.tryPublish(...)` — `os_unfair_lock_trylock`, drops frame on contention.

All DSP is done in pre-allocated `VisualizerScratchBuffers` (one instance per tap, allocated at
`installTap` time, then reused). No heap allocation occurs in the tap closure.

### Threading model summary

| Stage | Thread | Mechanism |
|---|---|---|
| Tap closure | AVAudioEngine render thread | `nonisolated static` closure |
| Hand-off | `os_unfair_lock` trylock / lock | `VisualizerSharedBuffer` (single-slot) |
| Poll / update | Main thread, 30 Hz | `Timer` in `.common` mode |
| UI read | Main thread | `@Observable` property access |

---

## Proposed VisualizerFeed surface

The existing `VisualizerSharedBuffer` already is effectively a single-slot SPSC feed (one producer,
one consumer, generation counter). The minimal extraction wraps it in a named, injectable type so
both the engine tap and the future MTAudioProcessingTap can write into the same slot.

```swift
// MacAmpApp/Audio/VisualizerFeed.swift  (~50 LOC)

/// Single-slot SPSC transfer buffer: one producer (render thread),
/// one consumer (main thread 30 Hz poll). Last-write-wins; frame
/// is dropped on lock contention rather than blocking the render thread.
final class VisualizerFeed: @unchecked Sendable {

    /// Write pre-processed visualizer data. Non-blocking; drops frame on contention.
    /// Safe to call from any realtime thread (uses trylock).
    func tryPublish(from scratch: VisualizerScratchBuffers,
                    oscilloscopeSamples: Int,
                    validFrameCount: Int) -> Bool

    /// Read latest data. Blocking lock (safe for main thread).
    /// Returns nil when no new generation is available.
    func consume() -> VisualizerData?
}
```

`VisualizerFeed` is the renamed, extracted shell of `VisualizerSharedBuffer`. Its body is identical
to `VisualizerSharedBuffer`; only visibility and ownership change: it becomes a non-private type
owned and injected by `VisualizerPipeline` instead of being a private nested class.

No ring sizing decision is required: the existing single-slot semantics are correct for both
producers. The tap produces one buffer every ~46 ms (2048 frames at 44.1 kHz) or ~43 ms (at 48 kHz);
the consumer polls at 30 Hz (~33 ms). Drop-on-contention is the right policy; a ring would only
accumulate stale frames. If a ring is preferred for smoothness, 4 slots (≈4 × 2048 frames) is
sufficient for 1 full consumer interval of jitter headroom — but this is not required.

---

## Engine-side delta

Only `VisualizerPipeline.swift` changes. Two edits:

1. **Extract `VisualizerSharedBuffer` → `VisualizerFeed`** (rename + remove `private`, move to its
   own file or promote to `internal`). Body is unchanged. ~0 net new LOC; ~5 lines of visibility
   change.

2. **`VisualizerPipeline` holds `VisualizerFeed` instead of `VisualizerSharedBuffer`** (type
   rename at L330). The `installTap` method (L380–398) continues to pass `sharedBuffer` (now a
   `VisualizerFeed`) into `makeTapHandler` exactly as today. The tap closure calls
   `feed.tryPublish(...)` — same call, same arguments, same drop-on-contention semantics.

Files touched:
- `MacAmpApp/Audio/VisualizerPipeline.swift` — rename `sharedBuffer: VisualizerSharedBuffer` to
  `feed: VisualizerFeed` (L330), update type reference in `makeTapHandler` signature (L566).
- `MacAmpApp/Audio/VisualizerFeed.swift` — new file containing the extracted type (body moved from
  `VisualizerPipeline.swift`).

No changes to `AudioEngineController.swift`, `AudioPlayer.swift`, or any consumer call-site.
Net LOC delta: ~0 (move, not add). `xcodegen generate` required to register the new file.

---

## Tap-side write call

Inside the `tapProcess` C callback, after the MTAudioProcessingTap produces and downmixes a stereo
mono buffer into `scratch`, the call shape is:

```swift
// After step 4 in tapProcess (downmix surround→stereo into scratch already done):
_ = visualizerFeed.tryPublish(
    from: scratch,
    oscilloscopeSamples: 76,
    validFrameCount: Int(framesOut.pointee)
)
```

`visualizerFeed` is captured in the tap's `Context` struct (alongside the EQ + balance state),
passed via `Unmanaged<Context>` through `MTAudioProcessingTapGetStorage`. The `VisualizerFeed`
must be `@unchecked Sendable` (already the case) so it is safe to reference from the C callback.

---

## Risk + LOC estimate

- **Engine-path behavior change:** Zero. The tap closure body, the `tryPublish` call, and the 30 Hz
  poll-consume cycle are byte-for-byte identical. Only the type name at the declaration site changes.
- **New file:** `VisualizerFeed.swift`, ~55 LOC (moved body, visibility tweak, doc comment).
- **`VisualizerPipeline.swift` edits:** 2 lines changed (type annotation + `makeTapHandler` param).
- **`xcodegen generate`:** Required once to register the new file. No `project.yml` schema change.
- **Test surface:** Existing TSan tests continue to cover the engine path without modification.
  No new test surface is introduced by this extraction alone.
- **Regression risk:** Negligible — the lock, generation counter, trylock drop, and consumer nil
  return on no-new-generation are all identical. The only risk is a typo during the rename, which
  is caught at compile time.
- **Scope:** ~60 LOC touched across 2 files, 1 new file. Half-day task maximum.

---

## TL;DR

The existing `VisualizerSharedBuffer` is already a single-slot SPSC hand-off with exactly the right
semantics (trylock drop on the render thread, blocking consume on main). Extracting it as
`VisualizerFeed` requires renaming the type, promoting its visibility, and moving it to its own
file — no algorithmic change. The engine tap continues to call `tryPublish` with identical
arguments; the new video tap adds a second callsite with the same signature; `VisualizerPipeline`
consumes from `VisualizerFeed.consume()` as before, unchanged.
