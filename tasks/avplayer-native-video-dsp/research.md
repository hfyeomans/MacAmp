# Research: AVPlayer-Native Video DSP

> **Task:** `tasks/avplayer-native-video-dsp/`
> **Status:** 📋 SKELETON — Step 2 of the three-step pivot. Awaiting Phase 0 spike + Apple docs review + reference-branch retrospective.
> **Reference:** `tasks/video-audio-engine-routing/research.md` (saved branch's research, kept as historical context — much of it remains relevant for surround-downmix and channel-mapping patterns).

---

## Goal

Validate the architecture's load-bearing assumptions before writing `plan.md`. Per project workflow: research informs plan, plan goes through Oracle ≥9/10 gate, only then does implementation begin.

---

## Research questions (to be answered in Step 2)

### Q1 — Does `MTAudioProcessingTap` actually support in-place buffer modification?

**Why it matters:** This is the *load-bearing* assumption of the entire architecture. If the answer is no, the approach pivots.

**What "yes" looks like:** A tap created with `kMTAudioProcessingTapCreationFlag_PreEffects` (or `_PostEffects`?) can modify the source buffer in `tapProcess`, and AVPlayer plays the modified buffer. EQ-effected audio is audible. AVPlayer's master clock is unaffected (no ring under-runs, no master-clock stalls).

**What "no" looks like:** AVPlayer treats the modified buffer specially / re-reads source / ignores modifications. Modifications are read-only by design. Tap mode forces drain semantics regardless of flag.

**Validation method:** Phase 0 spike on throwaway branch. Pseudocode:
```swift
// In tapProcess:
let getStatus = MTAudioProcessingTapGetSourceAudio(tap, framesToProcess, bufferList, ...)
guard getStatus == noErr else { return }
// Modify in place — apply gain reduction (simplest possible DSP, easy to hear)
let frames = Int(framesOut.pointee)
let dataPtr = bufferList.pointee.mBuffers.mData!.bindMemory(to: Float.self, capacity: frames * 2)
for i in 0..<(frames * 2) { dataPtr[i] *= 0.1 }
// Don't write to a ring. Don't mute AVPlayer. AVPlayer should play the modified buffer.
```

If the audio is audibly attenuated, in-place modification works. If volume is unchanged, AVPlayer is reading source elsewhere.

**Apple docs to consult:** TN2249, `AVMutableAudioMix` reference, `MTAudioProcessingTap` SDK header (read flag semantics carefully — `_PreEffects` vs `_PostEffects` may differ in modify-vs-read contract).

**Kill switch:** If in-place modification doesn't work, abandon this architecture. Possible fallbacks (much more complex): apply DSP via `AVAudioMixInputParameters.setVolumeRamp` (only volume, no EQ); intercept via `AVPlayerItem.audioMix` with custom audio processing tap that drains+rewrites (back to ring-buffer territory); accept that video gets no EQ/balance/Milkdrop and remove the UI surface.

---

### Q2 — Numerical equivalence target for `AVAudioUnitEQ` matching

**Why it matters:** EQ math lives twice in the dual architecture (engine path uses `AVAudioUnitEQ`; tap path uses new `BiquadCascade`). Both must produce subjectively identical EQ effects across the 10 bands. If `BiquadCascade` is significantly different, users will hear inconsistency.

**What needs answering:**
- What biquad design does `AVAudioUnitEQ` use internally? (constant-Q vs constant-bandwidth, Robert Bristow-Johnson cookbook formulas vs Apple's own derivation)
- What gain shape (asymmetric vs symmetric)?
- What Q values per band?
- Frequency response curves at typical settings (flat, bass boost, treble boost, mid scoop)?

**Validation method:** Render a known input (white noise, sine sweep, music sample) through `AVAudioUnitEQ` at various preset settings. Capture output. Compare against `BiquadCascade` output during spike. Tolerance: TBD — start with -40 dBFS or better magnitude error per frequency bin, refine empirically.

**Apple docs to consult:** `AVAudioUnitEQ` reference (likely scant on internals), Audio Unit framework docs, possibly WWDC sessions on AU.

---

### Q3 — Render-thread CPU budget for tap-side DSP

**Why it matters:** All DSP runs on the AVPlayer audio render thread. Too much work → render thread misses its deadline → audio glitches → AVPlayer master clock stalls → video stalls. Worse than the ring-buffer architecture's failure mode (which at least had the watchdog).

**Budget components:**
- 10-band biquad cascade: ~5 mults + 4 adds per sample per band per channel = ~180 ops/sample stereo
- Balance: 2 mults per sample stereo
- Visualizer feed write: 1 ring write per buffer (low frequency)

**Total at 48 kHz stereo:** ~9 M ops/sec. Apple Silicon can do this several times over per core. Intel is the constraint — particularly older Intel Macs in MacAmp's support matrix.

**Validation method:** Phase 0 spike includes CPU measurement on Apple Silicon AND Intel build targets. Target: <2% of one core for the full DSP chain at 48 kHz stereo.

---

### Q4 — Channel-count / sample-rate handling

**Source variety:** Real video files have 1/2/5.1/7.1 channel counts, 44.1/48/96 kHz sample rates. The tap callback receives whatever the asset's audio track is decoded to.

**Approach (informed by reference-branch lessons):**
- For visualizer feed: always downmix to stereo (Butterchurn / spectrum analyzer want stereo Float32)
- For audible path: leave channel layout untouched if AVPlayer's downstream pipeline handles it; reverse-engineer from Phase 0 spike whether buffer in `tapProcess` is pre- or post-engine-mix (the `_PreEffects` / `_PostEffects` flag determines this)
- Sample rate: tap delivers audio at the asset's native rate. AVPlayer handles SRC to hardware. We don't need a converter at all — DSP applies in-place at native rate.

**Compare to reference branch:** The engine-routing approach REQUIRED an `AudioConverter` because the engine consumer ran at a different rate (48 kHz fixed) than the tap source (varies). New architecture DROPS the converter entirely — DSP runs at whatever rate AVPlayer is decoding. This is one of the architecture's key fidelity wins.

---

### Q5 — Reference-branch patterns reusable as code

**From `feat/video-audio-engine-routing` (saved):**

Reusable patterns (informed re-implementation, not cherry-pick):
- C-side tap callback structure (`Unmanaged<Context>` handoff in `tapInit` / `tapFinalize`, `MTAudioProcessingTapGetStorage`)
- Channel-map / surround-downmix recipes (`configureChannelMapping`, `inferredSurroundChannelLayoutTag`) — useful for visualizer-feed downmix even though we don't use AudioConverter for the audible path
- Atomics-driven cross-thread state (`ManagedAtomic<UInt64>` for host-time, `ManagedAtomic<Bool>` for flags)
- TSan-on test patterns (driving real bridge in tests, sleeping past tick windows for assertion timing)
- `_test*` seam pattern for production-API exposure to tests

Not reusable (engine-routing-specific):
- `LockFreeRingBuffer` instantiation for video — DSP is in-place, no transport ring
- `AVAudioSourceNode` + engine graph for video — there is no engine bridge for video
- Watchdog + fallback machinery — nothing to fall back from
- HAL property listener + reconfigure gate — AVPlayer handles its own routes
- `videoTapFallbackActive` capability flag branch — capability flag for video becomes simply `true`

---

### Q6 — Existing visualizer-feed extraction

**Today's code:** `VisualizerPipeline` reads from `AVAudioEngine.installTap(onBus:)` on the main mixer node. That feeds the spectrum analyzer + Butterchurn snapshot.

**New architecture:** Both engine path and tap path need to feed the visualizer. Cleanest approach: extract a generic `VisualizerFeed` (small SPSC ring of stereo Float32 frames at fixed cadence). Engine path's mixer-node tap writes into it; new video tap also writes into it. `VisualizerPipeline` consumes from `VisualizerFeed`.

**Question for research:** Where exactly does the engine-tap currently write its data? What's the consumer side? How disruptive is the refactor to extract the feed without changing engine-path behavior? Read existing code in Step 2.

---

## Reference materials

- **`tasks/video-audio-engine-routing/`** (saved task folder) — Phase 0 spike findings, Phase 1 engine-config-observer plan, Phase 2 `MTAudioProcessingTap` plan (the *spec* is reusable; the implementation choice differs), Phase 7 quality-investigation findings (the route-change + clock-domain learnings that prompted the pivot)
- **`feat/video-audio-engine-routing`** branch (paused, pushed to origin) — full implementation of the engine-routing approach. Read end-to-end during Step 2 retrospective.
- **`tasks/_context/s3-2-pivot.md`** — three-step pivot tracker
- **Apple docs:** TN2249 ("Using `MTAudioProcessingTap` to process audio data tapped from `AVPlayer`"), `AVMutableAudioMix`, `AVAudioUnitEQ`, `MTAudioProcessingTap` framework reference

---

## Out of scope

- Audio-path changes (local files, streams) — engine path stays intact
- HLS audio (S3-3) — that's a separate task
- HLS video — different platform constraint (`MTAudioProcessingTap` doesn't fire reliably for streaming AVPlayerItems per QA1716; documented in `_context/state.md`)
- Visualizer mode changes (spectrum vs Butterchurn selection) — UI/preference work, not part of pipeline
