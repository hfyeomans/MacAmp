# State: AVPlayer-Native Video DSP

> **Purpose:** Bring EQ + Balance + Milkdrop/Butterchurn to video playback by applying DSP in-place inside an `MTAudioProcessingTap` on AVPlayer's audio path — instead of routing video audio out of AVPlayer through `AVAudioEngine`. Replaces the engine-routing approach attempted on `feat/video-audio-engine-routing` (now PAUSED-AS-REFERENCE).
> **Created:** 2026-05-01
> **Last revised:** 2026-05-02
> **Sprint:** S3, Wave S3-2 (architectural pivot)
> **Status:** 🔧 IMPLEMENTING — Phase 2 ✅ landed (production tap scaffold + ADR-3a containment, 74/74 TSan green); Phase 3 NEXT (`BiquadCascade` + balance + numerical match). Steps 1 + 2 + 3 ✅; Phases 1 + 2 ✅. Plan + research locked at Oracle ≥9.8/10.

---

## Pivot context

This task replaces `tasks/video-audio-engine-routing/` (preserved as reference, branch `feat/video-audio-engine-routing` paused at commit `5af91eb`). The engine-routing approach reached Phase 7 testing and revealed structural issues with the macOS platform:

1. **`AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes** — Apple's notification only fires when the engine's effective configuration actually changes, not on every system default-output change. AirPods on macOS route through the AirPlay subsystem and don't always trigger it. Proven by missing log line in user traces during Phase 7.
2. **Master-clock-coupled video stalls** — AVPlayer's audio queue is the master clock for video on macOS. Any ring under-run on the engine consumer side stalls the master clock, which stalls the video frame.
3. **Dual-clock-domain drift** — engine output clock vs AVPlayer master clock are unsynchronized. Drift accumulates on long playback (>5–10 min).
4. **Tinning artifacts from second SRC stage** — AudioConverter's quality tier had to be raised to Mastering / Max to match what AVPlayer's native pipeline does internally.

The contrarian framing: **don't drag video audio out of AVPlayer. Apply processing in-place where the audio already lives.** AVPlayer + `AVMutableAudioMix` + `MTAudioProcessingTap` modifies the source buffer that Core Audio plays. Phase 0 spike (2026-05-01) empirically confirmed this works on macOS 15+ with Swift 6.2.

---

## Three-step plan tracker

| Step | Description | Status | Closed |
|------|-------------|--------|--------|
| 1 | Mechanical pivot — branch + cherry-pick Phase 1 + scaffold task + `_context/` cross-refs | ✅ DONE | 2026-05-01 |
| 2 | Research phase — Phase 0 spike (empirical kill-switch ✅), Apple docs (verbatim contract from SDK header), saved-branch retrospective, EQ numerical-match research, VisualizerFeed extraction analysis | ✅ DONE | 2026-05-01 (Oracle 10/10 final after 5 rounds) |
| 3 | Plan phase — write `plan.md`, iterate with Oracle, ADR-3a containment cycle (user-requested), user sign-off | ✅ DONE | 2026-05-02 (Oracle 9.8/10 final after 5 rounds) |
| 4 | Implementation — 9 phases per `plan.md` §6 | 🔧 IN PROGRESS | Phase 1 + 2 done; Phase 3 NEXT |

See `tasks/_context/s3-2-pivot.md` for the strategic decision log.

---

## What's on this branch right now

| Component | Source | Notes |
|-----------|--------|-------|
| Phase 1 (engine config observer) | Cherry-picked from `feat/video-audio-engine-routing` (13 commits) | Stream-side route-change resilience. Same code, no `wasVideoBridge` field (cleanly dropped per Oracle). |
| `wasVideoBridge` cleanup | Commit `ffd77c1` | Forward-looking field from Phase 1's `PreReconfigureSnapshot` removed. |
| Step 2 research | Commits `4a80bf9` → `46bb6af` (5 commits) | research.md + 5 research-notes/* files. Oracle 10/10. |
| Step 3 plan | Commits `1ae8e80` → `fdce0ed` (5 commits) | plan.md (15 sections, ~900 LOC, 11+1 ADRs incl. ADR-3a). Oracle 9.8/10. |
| Spike artifact | `spike/avplayer-inplace-tap-dsp` (throwaway, retained locally) | ~210 LOC Swift 6.2 CLI tool. Phase 0 kill-switch empirical confirmation. |
| Phase 1 (`VisualizerFeed` + `VisualizerScratchBuffers` extraction) | Commit `146a8b4` | 2 nested types promoted to module-internal across new files. Engine path byte-for-byte identical. |
| Phase 2 (production tap scaffold + ADR-3a containment) | Pending commit | New `RenderThreadSafe.swift` (Gate 2 marker protocol, `~Copyable`) + `VideoDSP/VideoTapContext.swift` (Gate 1 header contract, all 9 atomic fields, double-buffer alloc/dealloc, install method, `_makeForContractTest` factory) + `VideoDSP/VideoTap.swift` (5 C-callbacks, ADR-10 release-on-fail, `@MainActor` attach/detach) + `VideoDSP/BiquadCoefficientSet.swift` (empty struct stub, Phase 3 fills) + `Tests/VideoTapSendableContractTests.swift` (Gate 3a Mirror + 3b regex). `AudioPlayer.swift` modified: `videoTapContext` field + `attachVideoTap`/`detachVideoTap` facades wired into `playTrack`/`stop`/media-switch. Pass-through DSP only (no biquad math). |

**Tests:** 74/74 with TSan (72 baseline + 2 new contract tests). Engine path unchanged.

## Phase 2 implementation findings (2026-05-02)

Three architectural deviations forced by Swift 6 reality, documented for Oracle pre-PR review:

1. **`RenderThreadSafe: ~Copyable`** — `Synchronization.Atomic<T>` and `Mutex<T>` are `~Copyable` in Swift 6, so the marker protocol must allow non-Copyable conformers. Plan ADR-3a Gate 2's snippet (`extension Atomic: RenderThreadSafe {}`) compiles only with this adjustment.
2. **Mirror reflection coverage gap** — `Mirror.Child.value: Any` requires `Copyable`, so `~Copyable` Atomic/Mutex fields reflect as `Void` and are invisible to Test 3a. The test now skips `Void`-typed children with an inline comment. Atomic/Mutex are safe by construction (the stdlib wrappers carry the contract); the residual gap (a `let foo: SomeNonCopyableType` that is not actually atomic) is gated by the file header contract + code review only. Test 3b (source-level regex) remains the load-bearing enforcement for the `var` mutability rule.
3. **`@preconcurrency import AVFoundation` + `@MainActor` on attach/detach** — `AVAsset` is not yet `Sendable`-annotated under Swift 6, so the `await playerItem.asset.loadTracks(...)` boundary inside `VideoTap.attach` requires `@preconcurrency` (matching the existing `AudioEngineConfigurationObserver.swift` pattern). `attach`/`detach` are `@MainActor` because they mutate `playerItem.audioMix` (MainActor-isolated).

`placeholder.md` items P-1 (BiquadCoefficientSet stub), P-2 (Mirror gap), P-3 (`@preconcurrency`) are the persistent records.

---

## Branch + Wave

- **Branch:** `feat/avplayer-native-video-dsp` (cut from `main` 2026-05-01)
- **Reference (paused):** `feat/video-audio-engine-routing` (44 commits, last `5af91eb`, pushed to origin)
- **Wave:** S3-2 (architectural pivot)
- **PR target:** PR #C
- **Predecessors:** S3-1A ✅, S3-1B ✅, Phase 1 (engine config observer) ✅ as cherry-pick base
- **Successors:** S3-3 (`hls-streaming-support`), S3-4 (`ogg-vorbis-support`)

---

## Artifacts (current)

| File | Status |
|------|--------|
| `research.md` | ✅ COMPLETE — Oracle 10/10 final |
| `research-notes/apple-docs.md` | ✅ COMPLETE |
| `research-notes/saved-branch-retrospective.md` | ✅ COMPLETE |
| `research-notes/eq-numerical-match.md` | ✅ COMPLETE |
| `research-notes/visualizer-feed.md` | ✅ COMPLETE |
| `research-notes/spike-findings.md` | ✅ COMPLETE (incl. production-translation hazards checklist) |
| `plan.md` | ✅ APPROVED — Oracle 9.8/10 final, user signed off |
| `todo.md` | ✅ ACTIVE — derived from plan.md §6 phases (2026-05-02) |
| `state.md` | ✅ This file |
| `placeholder.md` | Empty (populated during implementation) |
| `depreciated.md` | Empty (populated during implementation) |

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
| Future HLS video | Out of scope (`MTAudioProcessingTap` doesn't fire reliably for streaming `AVPlayerItem`s per QA1716) | — |

Split tracks who owns the clock — engine-managed transports get engine processing, AVPlayer-managed transports get tap-side processing. EQ math lives twice (in `AVAudioUnitEQ` and `BiquadCascade`); per Principle 4 (AHA Rule of Three) this is the right kind of WET — engine-AU EQ and tap-side biquad have different threading, different parameter-update paths, different ownership models.

---

## Next steps (Phase 3 — `BiquadCascade` + balance + numerical match)

Per `todo.md` and `plan.md` §6 Phase 3 + ADR-4, ADR-5, ADR-8, ADR-9:

1. Replace the `BiquadCoefficientSet.swift` empty-struct stub with the real `struct BiquadCoefficientSet { let bands: (BiquadCoefs ×10) }` + `static func compute(for:sampleRate:)` factory using RBJ-cookbook formulas.
2. Add private nested `struct EqualizerState: Sendable, Equatable` to `EqualizerController.swift`.
3. Create `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift` — direct-form-II biquad with per-channel filter history; `process(buffer:channels:frames:coefficients:)` + `reset()`.
4. Add `extension BiquadCascade: RenderThreadSafe` to `RenderThreadSafe.swift`.
5. Update `VideoTapContext.swift` init/deinit to allocate `BiquadCoefficientSet` blocks against the real (non-empty) struct stride.
6. Implement `tapProcess` render-path steps 2-6 from ADR-5 (filter reset on StartOfStream, preamp, EQ on/off gate, BiquadCascade.process, balance L/R multiplies).
7. Create `Tests/MacAmpTests/BiquadNumericalMatchTests.swift` — 4 tests: full-EQ-active sweep ≤0.5 dB vs `AVAudioUnitEQ`; EQ-toggle bypass parity; preamp parity; balance parity.
8. TSan-on build + test green.
9. Manual smoke: video plays with EQ presets producing audible differences.
10. Commit: `chore(s3-2): Phase 3 — BiquadCascade + balance + numerical match`.
