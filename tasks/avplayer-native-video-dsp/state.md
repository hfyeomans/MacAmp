# State: AVPlayer-Native Video DSP

> **Purpose:** Bring EQ + Balance + Milkdrop/Butterchurn to video playback by applying DSP in-place inside an `MTAudioProcessingTap` on AVPlayer's audio path — instead of routing video audio out of AVPlayer through `AVAudioEngine`. Replaces the engine-routing approach attempted on `feat/video-audio-engine-routing` (now PAUSED-AS-REFERENCE).
> **Created:** 2026-05-01
> **Last revised:** 2026-05-28
> **Sprint:** S3, Wave S3-2 (architectural pivot)
> **Status:** 🔧 IMPLEMENTING — Phases 1+2+3+4 ✅ **DONE**. **Phase 4 ✅ DONE (2026-05-28)**: video-tap visualizer (ADR-6 dual-producer) — `videoTapVisualizerRender` feeds the shared `VisualizerFeed`; consumer wired for video (poll timer + `isVisualizerRendering` ungating across spectrum/Butterchurn/oscilloscope). **98/98 tests with TSan, no races.** Oracle arc 6→8→9.0→**9.6 APPROVED** (2 blockers fixed: producer-published-but-not-consumed; lifecycle holes: completion + repeat-one). **Phase 5 NEXT** (EQ + balance state fanout — also delivers the deferred audible-EQ-on-video smoke, todo 3.17). Phase 3 (Oracle 9.6): P-4 resolved (ADR-4 amendment #2 Mutex hand-off), BiquadCascade + RBJ compute + tapProcess steps 2-6, ≤0.5 dB vs AVAudioUnitEQ. Steps 1-3 ✅. Plan + research locked at Oracle ≥9.8/10. Open non-blocking finding: P-6 (video→audio no auto-play).

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
| Phase 2 initial scaffold (commit `ac7e0d5`) | Landed | New `RenderThreadSafe.swift` (Gate 2 marker protocol, `~Copyable`) + `VideoDSP/VideoTapContext.swift` (Gate 1 header contract, all 9 atomic fields, double-buffer alloc/dealloc, **initial** install method) + `VideoDSP/VideoTap.swift` (5 C-callbacks, ADR-10 release-on-fail, `@MainActor` `attach`/`detach`) + `VideoDSP/BiquadCoefficientSet.swift` (empty struct stub) + `Tests/VideoTapSendableContractTests.swift` (Gate 3a Mirror + 3b regex). `AudioPlayer.swift` modified: `videoTapContext` field + initial `attachVideoTap`/`detachVideoTap` facades wired into `playTrack`/`stop`/media-switch. |
| Phase 2 Oracle revisions 1-6 (Option C structural fix + ADR-4 A1) | Pending commit (amend or new) | Oracle review (gpt-5.5, 2026-05-02) returned 8/10 REVISE: BLOCKER on ADR-7 (audioMix mutated during playback by post-construction install) + ACTIONABLE on ADR-4 (double-buffer race) + ACTIONABLE on missing race tests. Revisions 1-6 applied: refactored `VideoTap.attach` → `buildAudioMix(audioTrack:context:)` (sync, returns mix); refactored `VideoPlaybackController.loadVideo` to be `async` with `audioMixBuilder` parameter so audioMix is set during AVPlayerItem construction (before AVPlayer adopts the item); refactored `AudioPlayer` to use private `startVideoLoad(track:)` + generation counter + in-flight task handle; removed `installCoefficientSet` per ADR-4 A1 (P-4 placeholder added); added 3 lifecycle tests (`VideoTapLifecycleTests`). |
| Phase 2 Oracle revisions 7-12 (Oracle BLOCKER follow-up: stale-load short-circuit) | Pending commit | Oracle re-review returned 8/10 REVISE again: BLOCKER on stale `loadVideo` continuation still constructing AVPlayer + observers after stale builder. Revisions 7-12 applied: added `isStillRelevant: () -> Bool` parameter to `loadVideo` short-circuit BEFORE AVPlayerItem/AVPlayer/observer mutation; gated final `play()` on `playbackState == .playing` (pause-during-load no longer auto-plays); added 2 stale-load race tests (`loadVideoBailsWhenStaleAfterAudioMixBuilder` + `loadVideoConstructsPlayerWhenRelevant`); cleaned up stale `installCoefficientSet` references in code + placeholder.md; amended plan.md ADR-4 + ADR-7 + §5.2 + §5.4 + §6 Phase 5 to reflect Option C reality. |

**Tests:** 85/85 with TSan (72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix). Engine path unchanged.

**Leak check (todo 2.40) ✅ 2026-05-28** — verified on the real playback path via Xcode Memory Graph Debugger (Allocations Instruments can't show pure-Swift classes by name; MGD can). Clip loaded+paused → `VideoTapContext` + `coefficientBlockA` + `coefficientBlockB` all = 1; switch to an audio track (`.video→.audio` cleanup → `tapFinalize`) → all = 0. `Unmanaged.passRetained`↔`tapFinalize` balanced, no leak, Phase-2-attributable. Redundant with the 6 automated `VideoTapLifecycleTests`. Reusable workflow: `tasks/_context/instruments-allocations-workflow.md`.

## Phase 2 implementation findings (2026-05-02)

Documented for Oracle pre-PR review and for Phase 3+ context:

### Plan deviations forced by Swift 6 reality

1. **`RenderThreadSafe: ~Copyable`** — `Synchronization.Atomic<T>` and `Mutex<T>` are `~Copyable` in Swift 6, so the marker protocol must allow non-Copyable conformers. Plan ADR-3a Gate 2's snippet (`extension Atomic: RenderThreadSafe {}`) compiles only with this adjustment.
2. **Mirror reflection coverage gap (placeholder P-2)** — `Mirror.Child.value: Any` requires `Copyable`, so `~Copyable` Atomic/Mutex fields reflect as `Void` and are invisible to Test 3a. The test now skips `Void`-typed children with an inline comment. Atomic/Mutex are safe by construction (the stdlib wrappers carry the contract); the residual gap (a `let foo: SomeNonCopyableType` that is not actually atomic) is gated by the file header contract + code review only. Test 3b (source-level regex) remains the load-bearing enforcement for the `var` mutability rule.
3. **`@preconcurrency import AVFoundation` + `@MainActor` on `buildAudioMix`/`detach` (placeholder P-3)** — `AVAsset` is not yet `Sendable`-annotated under Swift 6; the `await asset.loadTracks(...)` boundary inside the audioMixBuilder closure requires `@preconcurrency`. `buildAudioMix`/`detach` are `@MainActor` because they touch MainActor-isolated AVPlayerItem properties.

### Architectural amendments forced by Oracle review

4. **ADR-4 install method withdrawn (placeholder P-4)** — Oracle flagged that the naive A/B-swap encoded in ADR-4 is not race-safe (main can swap A→B→A while render still holds A's pointer). Phase 2 closed without `installCoefficientSet`; the two pre-allocated coefficient blocks remain so the alloc/dealloc lifecycle is exercised end-to-end. Phase 3 MUST design a race-safe hand-off scheme (triple-buffer + epoch counter, RCU-style allocate-fresh-each-install, or `Mutex<BiquadCoefficientSet>` with `withLockIfAvailable`) BEFORE `tapProcess` reads coefficients.
5. **ADR-7 audioMix-on-construction pattern (replaces post-construction install)** — Original ADR-7 said "audioMix set once before play()". Phase 2 implementation tightened to "audioMix set during AVPlayerItem CONSTRUCTION, before the AVPlayer exists." `VideoTap.attach(to:context:) async throws` was replaced by sync `buildAudioMix(audioTrack:context:) throws -> AVMutableAudioMix`; `VideoPlaybackController.loadVideo` is now `async` with `audioMixBuilder` + `isStillRelevant` parameters; `AudioPlayer` orchestrates via private `startVideoLoad(track:)` with a generation counter that short-circuits superseded loads BEFORE any AVPlayer/observer mutation. The `attachVideoTap`/`detachVideoTap` public facades from the original Phase 2 plan were removed (now redundant — orchestration lives entirely in `startVideoLoad`).
6. **`pauseAndDetachVideoTapIfNeeded` enforces pause-before-detach** — `audioMix = nil` is a mutation that ADR-7 forbids during playback. Detach paths (`stop`, video→audio media switch) now call `pauseAndDetachVideoTapIfNeeded()` which pauses the player first if it is currently playing.
7. **Final `play()` gated on `playbackState`** — User pause/stop while a video load is in flight no longer triggers an unwanted auto-play after the load completes. `startVideoLoad`'s Task checks `playbackState == .playing` before calling `videoPlaybackController.play()`.

`placeholder.md` items P-1 through P-4 are the persistent tracking records. P-1 + P-4 MUST be addressed in Phase 3; P-2 + P-3 are open until external conditions change (Apple SDK Sendable, stricter language reflection).

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

## Next steps (Phase 5 — EQ + balance state fanout)

Phases 1-4 ✅ DONE (see status banner). **Phase 5 NEXT** per `todo.md` Phase 5 + `plan.md` §6 Phase 5 + ADR-5: fan out `EqualizerController`/`AudioPlayer` state to the registered video-tap Context(s) — write coefficients via `Context.installCoefficients` (the Mutex, ADR-4 amendment #2) and the `isEqOn`/`preamp`/`balance` atomics, on each EQ/preamp/balance/preset change + sample-rate change. **NEVER touch `.cascade`** (render-confined; guarded by the `cascadeIsRenderConfined` test). `EqualizerController.equalizerState` projection is ready. **Phase 5 also delivers the deferred audible-EQ-on-video smoke (todo 3.17)** — the first phase where moving an EQ slider changes video audio. Then Phase 6 (telemetry), 7 (lifecycle tests), 8 (15-gate matrix), 9 (UI polish + mandatory docs).

---

## Architecture / flow changes for a later docs/ update (Phase 9 mandatory-docs backlog)

> Phase 9 mandates a `docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection. The following Phase 2-3 deltas should be folded into `docs/` then (and likely `docs/VIDEO_WINDOW.md`). Captured here so they aren't lost.

1. **Video-tap in-place DSP path (NEW signal flow).** `AVPlayer` → `AVMutableAudioMix` → `MTAudioProcessingTap` → `tapProcess` modifies the buffer **in place** (steps: StartOfStream filter reset → preamp → `isEqOn` gate → `BiquadCascade` → balance) → AVPlayer's native pipeline plays the modified buffer. No ring buffer, no engine clock for video, no master-clock coupling. *Needs a flow diagram in docs/* contrasting this with the engine path.
2. **Dual-architecture topology** (already tabled above in this file): engine-managed transports (local audio, streams) use `AVAudioUnitEQ` + engine balance + engine tap visualizer; AVPlayer-managed transports (local video) use tap-side `BiquadCascade` + tap balance + (Phase 4) tap visualizer feed. EQ math lives twice by design (AHA — different threading/ownership).
3. **Coefficient hand-off concurrency contract (ADR-4 amendment #2).** `VideoTapContext.coefficients: Mutex<BiquadCoefficientSet?>`; main writes via `installCoefficients` (`withLock`), render reads via `withLockIfAvailable` (non-blocking, three-case double-optional) into a render-owned `BiquadCascade` cache; skip-on-contention reuses the last cache. Replaces the withdrawn race-unsafe atomic-pointer A/B double-buffer.
4. **`@unchecked Sendable` containment (ADR-3a) — final field set.** Gate-1 header contract; every field `Atomic`/`Mutex`/`RenderThreadSafe`. `cascade: BiquadCascade` is render-confined (RenderThreadSafe-by-confinement), enforced by Gate-3c source-scan test. Document the contract + the three gate tests.
5. **RBJ coefficient model.** Octave-BW peaking (bands 1-8) + S=1 low/high shelf (bands 0/9) matches `AVAudioUnitEQ` ≤0.5 dB; `BiquadCoefficientSet.frequencies` is the single source of truth shared with `EqualizerController.configureEQ`. Fail-closed to `.flat` for non-finite/Nyquist inputs; denormal state flush in the cascade.
6. **Balance convention.** Video tap uses `[-1, 1]`/0.0-center (matches `AudioPlayer.balance`/`AVAudioNode.pan`).
7. **Visualizer dual-producer (Phase 4, ADR-6).** Two parallel producers feed ONE shared `VisualizerFeed` (single-slot SPSC, trylock): the engine `makeTapHandler` (AVAudioPCMBuffer) and the video `videoTapVisualizerRender` (AudioBufferList, in `tapProcess` step 7, post-DSP). Only one is active at a time (audio vs video). Consumer side: `AudioPlayer.isVisualizerRendering` (engine OR video) gates `getFrequencyData`/`snapshotButterchurnFrame`/`VisualizerView` (spectrum + oscilloscope + bar-height floor); the 30 Hz poll timer is driven for video via `VisualizerPipeline.start/stopVideoVisualization` (hooked into video start / video→audio / stop / completion / repeat-one). **The visualizer renders in TWO windows from one shared path:** `VisualizerView()` is instantiated in both `MainWindowFullLayer` (main window) and `WinampPlaylistWindow` (the mini-visualizer shown when the main window is shaded), both reading the same `@Environment(AudioPlayer.self)` — so the same gating drives both; there is no playlist-specific visualizer code. RMS+Goertzel duplicated per ADR-6 (FFT shared); a flow diagram should show both producers → feed → consumer → both windows.
8. **Open follow-ups to mention:** P-6 (video→audio no auto-play), P-2/P-3 (Swift-6/SDK-evolution gaps).
