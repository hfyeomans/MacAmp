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

## Engine-side delta (revised after Oracle review — original "rename only" understated)

The actual changes touch THREE nested types, not just `VisualizerSharedBuffer`. See research.md Q6
for the canonical scope statement; this note retains the file-by-file detail.

1. **Extract `VisualizerSharedBuffer` → `VisualizerFeed`** (file: `VisualizerPipeline.swift:36`).
   `private final class` → module-internal, move to its own file. Body unchanged.

2. **Promote `VisualizerScratchBuffers` visibility** (file: `VisualizerPipeline.swift:169`). Currently
   `private final class`. Video tap path needs its own instance (render-thread isolation per producer),
   so the type must be visible to the new tap module — at minimum module-internal. Either keep nested-
   but-not-private or extract to `VisualizerScratchBuffers.swift`.

3. **Add a parallel video-tap render path** to consume `AudioBufferList` (vs the engine path's
   `AVAudioPCMBuffer`) and produce the same `VisualizerFeed` arrays. The current
   `makeTapHandler` (`VisualizerPipeline.swift:565`) is engine-tap-specific. Preferred (per AHA Rule
   of Three): keep `makeTapHandler` engine-only and add `videoTapRender` that uses the same
   `VisualizerFeed` + `VisualizerScratchBuffers` types. Rejected alternative: generalize
   `makeTapHandler` over `AVAudioPCMBuffer` | `AudioBufferList` — would require flag-driven divergence
   inside the closure (the wrong abstraction).

Files touched:
- `MacAmpApp/Audio/VisualizerPipeline.swift` — type renames + visibility-promote (`L36`, `L169`,
  `L565`, plus the `sharedBuffer` field reference at `L330`).
- New: `MacAmpApp/Audio/VisualizerFeed.swift` — extracted type.
- New (optional): `MacAmpApp/Audio/VisualizerScratchBuffers.swift` if extracting rather than
  keeping nested-but-non-private.
- New: video-tap render function (file lives in the new tap module, not in `VisualizerPipeline.swift`).

No changes to `AudioEngineController.swift`, `AudioPlayer.swift`, or any visualizer consumer call-site.
**Engine path: byte-for-byte identical behavior.** `xcodegen generate` required once. Net LOC
estimate: ~100–150 across `VisualizerPipeline.swift` + 1–2 new files. plan.md Phase-1 work item.

---

## Tap-side write call

Inside the `tapProcess` C callback, after the visualizer DSP produces mono into `scratch` (mono mix
+ 20-bar RMS + 20-bar Goertzel + 2048-pt FFT — the same DSP the engine tap runs today), the call
shape is:

```swift
// After step 4 in tapProcess (visualizer DSP into scratch — mono pre-computed arrays):
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
  poll-consume cycle are byte-for-byte identical.
- **New file(s):** `VisualizerFeed.swift` (extracted body), optionally `VisualizerScratchBuffers.swift`
  if extracting rather than keeping nested-non-private.
- **`VisualizerPipeline.swift` edits:** type renames + visibility-promote at L36, L169, L330, L565
  (per "Engine-side delta" above).
- **Plus:** new video-tap render function (lives in the new tap module, not in
  `VisualizerPipeline.swift`) — consumes `AudioBufferList` and reuses `VisualizerFeed` +
  `VisualizerScratchBuffers`.
- **`xcodegen generate`:** Required once to register the new file(s). No `project.yml` schema change.
- **Test surface:** Existing TSan tests continue to cover the engine path without modification.
  New tests cover the video-tap render path + lifecycle (per research.md verification matrix).
- **Regression risk for the engine path:** Negligible — the lock, generation counter, trylock drop,
  and consumer nil-return semantics are byte-for-byte unchanged.
- **Scope (canonical — matches research.md Q6):** ~100–150 LOC across `VisualizerPipeline.swift` +
  1–2 new files + new video-tap render function. plan.md Phase-1 work item.

---

## TL;DR

The existing `VisualizerSharedBuffer` is already a single-slot SPSC hand-off with exactly the right
semantics (trylock drop on the render thread, blocking consume on main). The minimum viable
extraction for the engine path alone would be a rename + visibility promotion; the **dual-producer
extraction (engine + video tap) requires three nested types to become module-internal**:
`VisualizerSharedBuffer` → `VisualizerFeed`, `VisualizerScratchBuffers` (visibility-only), plus a
parallel video-tap render function (engine `makeTapHandler` stays untouched). Engine path remains
byte-for-byte identical; video tap reuses the same DSP and publishes mono pre-computed arrays.
~100–150 LOC across 2 files + 1–2 new files.
