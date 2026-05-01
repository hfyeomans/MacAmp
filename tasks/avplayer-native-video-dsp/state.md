# State: AVPlayer-Native Video DSP

> **Purpose:** Bring EQ + Balance + Milkdrop/Butterchurn to video playback by applying DSP in-place inside an `MTAudioProcessingTap` on AVPlayer's audio path — instead of routing video audio out of AVPlayer through `AVAudioEngine`. Replaces the engine-routing approach attempted on `feat/video-audio-engine-routing` (now PAUSED-AS-REFERENCE).
> **Created:** 2026-05-01
> **Sprint:** S3, Wave S3-2 (architectural pivot)
> **Status:** SCAFFOLDED — Step 1 (mechanical pivot) ✅ done. Step 2 (research) NEXT. See `tasks/_context/s3-2-pivot.md` for the three-step plan.

---

## Pivot context

This task replaces `tasks/video-audio-engine-routing/` (preserved as reference, branch `feat/video-audio-engine-routing` paused at commit `5af91eb`). The engine-routing approach reached Phase 7 testing and revealed structural issues with the macOS platform:

1. **`AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes** — Apple's notification only fires when the engine's effective configuration actually changes, not on every system default-output change. AirPods on macOS route through the AirPlay subsystem and don't always trigger it. Proven by missing log line in user traces during Phase 7.
2. **Master-clock-coupled video stalls** — AVPlayer's audio queue is the master clock for video on macOS. Any ring under-run on the engine consumer side stalls the master clock, which stalls the video frame. Mitigated but not eliminated by larger ring (16k frames).
3. **Dual-clock-domain drift** — engine output clock vs AVPlayer master clock are unsynchronized. Drift accumulates on long playback (>5–10 min) and resets on pause/resume.
4. **Tinning artifacts from second SRC stage** — AudioConverter's quality tier had to be raised to Mastering / Max to match what AVPlayer's native pipeline does internally. Net fidelity tax remains.

The contrarian framing: **don't drag video audio out of AVPlayer. Apply processing in-place where the audio already lives.** AVPlayer + `AVMutableAudioMix` already supports this via `MTAudioProcessingTap` modifying the source buffer that Core Audio plays. No ring buffer, no engine clock, no second SRC stage, no master-clock coupling.

---

## Three-step plan tracker

See `tasks/_context/s3-2-pivot.md` for the canonical tracker. Status here:

| Step | Description | Status |
|------|-------------|--------|
| 1 | Mechanical pivot — branch + cherry-pick Phase 1 + scaffold task + `_context/` cross-refs | ✅ DONE (this commit) |
| 2 | Research phase — Phase 0 spike (in-place tap DSP feasibility), Apple docs, retrospective from saved branch | ⏭ NEXT |
| 3 | Plan phase — write `plan.md`, iterate with Oracle to ≥9/10, get user sign-off before any implementation phase begins | ⏭ AFTER STEP 2 |

---

## What's on this branch right now

| Component | Source | Notes |
|-----------|--------|-------|
| Phase 1 (engine config observer) | Cherry-picked from `feat/video-audio-engine-routing` (13 commits) | Stream-side route-change resilience. Same code, no `wasVideoBridge` field (cleanly dropped per Oracle). |
| `wasVideoBridge` cleanup | New on this branch (commit `ffd77c1`) | The forward-looking field from Phase 1's `PreReconfigureSnapshot` is removed since this branch doesn't have an engine video bridge. |
| Pivot scaffolding | New on this branch | Task folder + `_context/s3-2-pivot.md` + cross-refs. |

**Tests:** 72/72 with TSan (matches `main`'s engine-config-observer surface).

---

## Branch + Wave

- **Branch:** `feat/avplayer-native-video-dsp` (cut from `main` 2026-05-01)
- **Reference (paused):** `feat/video-audio-engine-routing` (43 + 1 commits, last `5af91eb`, pushed to origin)
- **Wave:** S3-2 (architectural pivot)
- **PR target:** PR #C (replaces the previous S3-2 PR target)
- **Predecessors:** S3-1A ✅, S3-1B ✅, Phase 1 (engine config observer) ✅ as cherry-pick base
- **Successors:** S3-3 (`hls-streaming-support`), S3-4 (`ogg-vorbis-support`)

---

## Artifacts (current)

| File | Status |
|------|--------|
| `research.md` | 📋 SKELETON — research questions + Phase 0 spike kill-switch criteria; awaiting Step 2 |
| `plan.md` | 📋 SKELETON — placeholder until research lands |
| `todo.md` | 📋 SKELETON — placeholder until plan lands |
| `state.md` | ✅ This file |
| `placeholder.md` | Empty (no in-flight stubs yet) |
| `depreciated.md` | Empty (Step 3 will document what gets removed/replaced once plan exists) |

---

## What this task is NOT

This is not a redesign of audio-side processing. Local audio files and streams continue to route through `AVAudioEngine` exactly as today — `AVAudioPlayerNode` and `AVAudioSourceNode`, the existing `AVAudioUnitEQ`, the existing balance node, the existing engine tap visualizer. **Only the video path changes.**

The dual-architecture topology that emerges:

| Path | Audio routing | Processing |
|---|---|---|
| Local audio files | `AVAudioPlayerNode` → engine graph | Engine `AVAudioUnitEQ` + balance node + engine tap visualizer (today) |
| Streams (Icecast/SHOUTcast) | Custom decode → ring → `AVAudioSourceNode` → engine graph | Same engine processing |
| Local video files | AVPlayer (native, in-place tap DSP) | Tap-side `BiquadCascade` + tap-side balance + visualizer feed |
| Future HLS audio | Custom decode → ring → engine graph (S3-3 plan) | Same engine processing |
| Future HLS video | AVPlayer (native, in-place tap DSP) | Same as local video |

Split tracks who owns the clock — engine-managed transports get engine processing, AVPlayer-managed transports get tap-side processing. EQ math lives twice (in `AVAudioUnitEQ` and a new `BiquadCascade`); per Principle 4 (AHA Rule of Three) this is the right kind of WET — engine-AU EQ and tap-side biquad have different threading, different parameter-update paths, different ownership models.

---

## Next steps (Step 2 — research)

Before writing `plan.md`, validate the architecture's load-bearing assumptions on a throwaway branch:

1. **Phase 0 spike:** Confirm `MTAudioProcessingTap` in-place buffer modification works — write modified frames back into `bufferList` in `tapProcess`, verify AVPlayer plays them with EQ effect audible. Throwaway branch, ~1–2 days. Kill switch: if in-place modification doesn't work the way I sketched, the architecture pivots and we replan from there.
2. **Apple docs review:** TN2249, current `AVMutableAudioMix` / `MTAudioProcessingTap` docs, WWDC archive for relevant sessions.
3. **Reference-branch retrospective:** Read `feat/video-audio-engine-routing` end-to-end. Catalog what's reusable as patterns (channel-mapping logic, surround downmix, tap callback structure with `Unmanaged` context, atomics-driven cross-thread state, TSan test patterns) and what's not (engine bridge activation, ring-buffer transport, watchdog/fallback, HAL listener — all moot in the new architecture).
4. **Numerical-equivalence research for `AVAudioUnitEQ`:** Pull AU's frequency response curves, Q values, gain shape. Tolerance target for `BiquadCascade` matching.
5. **Render-thread CPU budget:** measure during spike — 10 biquads × 2 channels at 48 kHz on Apple Silicon AND Intel build targets.

Findings get written to `research.md`. Once research is solid, write `plan.md` and gate with Oracle ≥9/10 before any implementation begins.
