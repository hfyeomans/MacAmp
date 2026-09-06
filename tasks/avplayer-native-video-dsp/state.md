# State: AVPlayer-Native Video DSP

> **Purpose:** Bring EQ + Balance + Milkdrop/Butterchurn to video playback by applying DSP in-place inside an `MTAudioProcessingTap` on AVPlayer's audio path — instead of routing video audio out of AVPlayer through `AVAudioEngine`. Replaces the engine-routing approach attempted on `feat/video-audio-engine-routing` (now PAUSED-AS-REFERENCE).
> **Created:** 2026-05-01
> **Last revised:** 2026-09-05 (manual runbook started; 8.2/8.12/8.11 dispositioned; push stamp → `5fe8c3c`; LLDB + close-out sequence recorded)
> **Sprint:** S3, Wave S3-2 (architectural pivot)
> **Status:** 🔧 IMPLEMENTING — Phases 1-7 ✅ DONE; **Phase 8 AUTOMATED gates ✅ (2026-06-27), manual/hardware gates ⏳ IN PROGRESS (user, from 2026-09-05).** Automated: 8.3 EQ ≤0.5 dB, 8.4 TSan **116/116**, 8.15 lifecycle (Phase 7), 8.1 CPU **Debug regression guard** (`VideoTapCPUBenchmarkTests` — DSP fits the deadline ~9× over even unoptimized; the production ≤10% figure is 8.1b MANUAL/Release-Instruments, UNVERIFIED). Oracle 7→fixes (benchmark methodology + honesty). Hardware-manual checklist (8.5-8.14 route changes/surround/replacement + 8.5b-e live-EQ/seek/visualizer/telemetry) written to **`verification.md`** — USER runs + records. **Phase 9 (docs + PR) can start in parallel; PR #C should follow manual verification.** Phase 7 (Oracle 9): lifecycle tests. Phase 6 (Oracle 9): telemetry. **Phase 5 ✅ DONE (2026-05-28)**: EQ + balance state fanout (ADR-5, two canonical owners) — `EqualizerController` fans EQ (compute+`installCoefficients` + isEqOn/preamp atomics) and `AudioPlayer` fans balance to registered video-tap Contexts; sample-rate poll via `VisualizerPipeline.onPollTick`. **The audible-EQ-on-video path is now LIVE** (the deferred todo 3.17 — moving an EQ slider / balance changes video audio in real time). Oracle 9→**10/10 APPROVED**. Phase 4 (Oracle 9.6): video-tap visualizer (ADR-6). Phase 3 (Oracle 9.6): P-4 resolved (ADR-4 amendment #2 Mutex hand-off) + BiquadCascade + RBJ compute + tapProcess; ≤0.5 dB vs AVAudioUnitEQ. Steps 1-3 ✅. Plan + research locked at Oracle ≥9.8/10. Open non-blocking finding: P-6 (video→audio no auto-play). **Manual runbook IN PROGRESS (user, from 2026-09-05)** — runbook https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8; 8.2/8.12 dispositioned NOT ABLE, 8.11 NOT ABLE as written (PARTIAL possible); telemetry via xcodebuildmcp LLDB, Release re-signed first / Debug fallback; Xcode MCP: 47 tools reachable via the xcodebuildmcp bridge, debugger tools unconfirmed (bridge timeouts) — user to enumerate.

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
| 4 | Implementation — 9 phases per `plan.md` §6 | 🔧 IN PROGRESS | Phases 1-7 ✅; Phase 8 automated ✅ (2026-06-27), manual/hardware gates IN PROGRESS (user, from 2026-09-05); Phase 9 NEXT |

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
| Phase 2 Oracle revisions 1-6 (Option C structural fix + ADR-4 A1) | Landed in 7d3367c (2026-05-02) | Oracle review (gpt-5.5, 2026-05-02) returned 8/10 REVISE: BLOCKER on ADR-7 (audioMix mutated during playback by post-construction install) + ACTIONABLE on ADR-4 (double-buffer race) + ACTIONABLE on missing race tests. Revisions 1-6 applied: refactored `VideoTap.attach` → `buildAudioMix(audioTrack:context:)` (sync, returns mix); refactored `VideoPlaybackController.loadVideo` to be `async` with `audioMixBuilder` parameter so audioMix is set during AVPlayerItem construction (before AVPlayer adopts the item); refactored `AudioPlayer` to use private `startVideoLoad(track:)` + generation counter + in-flight task handle; removed `installCoefficientSet` per ADR-4 A1 (P-4 placeholder added); added 3 lifecycle tests (`VideoTapLifecycleTests`). |
| Phase 2 Oracle revisions 7-12 (Oracle BLOCKER follow-up: stale-load short-circuit) | Landed in 7d3367c (2026-05-02) | Oracle re-review returned 8/10 REVISE again: BLOCKER on stale `loadVideo` continuation still constructing AVPlayer + observers after stale builder. Revisions 7-12 applied: added `isStillRelevant: () -> Bool` parameter to `loadVideo` short-circuit BEFORE AVPlayerItem/AVPlayer/observer mutation; gated final `play()` on `playbackState == .playing` (pause-during-load no longer auto-plays); added 2 stale-load race tests (`loadVideoBailsWhenStaleAfterAudioMixBuilder` + `loadVideoConstructsPlayerWhenRelevant`); cleaned up stale `installCoefficientSet` references in code + placeholder.md; amended plan.md ADR-4 + ADR-7 + §5.2 + §5.4 + §6 Phase 5 to reflect Option C reality. |

**Tests:** 116/116 with TSan at HEAD (85/85 at the Phase 2 close — 72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix). Engine path unchanged. *(74/74 vs 85/85 discrepancy — `todo.md` 2.37 records 74/74 for the same Phase 2 close; open item for Phase 9 pre-PR Oracle.)*

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

`placeholder.md` items P-1 through P-4 are the persistent tracking records. P-1 + P-4 were required in Phase 3 and both closed there (2026-05-28 / commit `24f8a12`); P-2 + P-3 remain open until external conditions change (Apple SDK Sendable, stricter language reflection). P-5 (closed, `c040e76`) and P-6 (open, non-blocking) were added later.

---

## Toolchain migration (Xcode 27 / Swift 6.4) — 2026-06-26

Mid-branch the dev machine upgraded Xcode 26→27 (Swift 6.2→6.4). This surfaced pre-existing issues NOT caused by S3-2; fixed on this branch as hygiene:
- **12 new compiler warnings** (`786b3c2`): 6 Combine implicit-import (`Timer.publish().autoconnect()` needs explicit `import Combine`) + 6 `#ImplicitStrongCapture` (`[weak self]` hoisted to the outer closure in `WindowSettingsObserver`/`WindowCoordinator+Layout`/`PlaylistWindowActions`). Codex-verified SAFE. Build now warning-clean.
- **TSan crash at app launch** (`1561621`): Swift 6.4's stricter `load(as:)` alignment precondition trapped on ZIPFoundation 0.9.19's misaligned ZIP-struct read (`Data.scanValue`) when loading the default `.wsz` skin. Fixed by upgrading ZIPFoundation 0.9.19→0.9.20 (`scanValue` now uses `loadUnaligned`). TSan gate restored: 103/103 green at that point (116/116 at HEAD). App was always fine in normal Debug (manual smokes passed) — TSan-only.
- Note: `project.yml` `xcodeVersion: 26.0` left as-is (cosmetic; not blocking). Deployment target stays macOS 15.0.

## Branch + Wave

- **Branch:** `feat/avplayer-native-video-dsp` (cut from `main` 2026-05-01; pushed to origin at `5fe8c3c` (docs sync; code unchanged since `944795a`) — 74 commits ahead of `main` `9cca40a`, unmerged, PR #C not yet opened)
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
| `placeholder.md` | P-1..P-6 recorded; P-2/P-3/P-6 open, P-1/P-4/P-5 resolved |
| `depreciated.md` | ✅ POPULATED — code removed during Phases 1-8 (withdrawn ADR-4 A/B swap, Phase-2 attach/detach facades, `wasVideoBridge`) |
| `verification.md` | ✅ ACTIVE — Phase 8 gate matrix + hardware-manual checklist (2026-06-27); manual run IN PROGRESS from 2026-09-05 (runbook artifact transcribed here at the end) |
| `phase2-walkthrough.md` | ✅ COMPLETE — Phase 2 manual walkthrough (2026-05-02) |

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

## Next steps (Phase 8 manual gates ⏳ user · Phase 9 NEXT)

Phases 1-7 ✅ DONE (see status banner). **Phase 8 AUTOMATED gates executed 2026-06-27** (commits `2c410a0` → `944795a` → `056c69a`): the dense-sampling CPU benchmark landed as `VideoTapCPUBenchmarkTests` — a **Debug `-Onone` DSP-core regression guard only** (p99 ≈11% / max ≈13% of the 21,333 µs deadline), plus 8.3 numerical EQ ≤0.5 dB, 8.4 TSan 116/116, and 8.15 lifecycle. **8.1b — the production CPU gate (`tapProcess` 99p ≤10% on a Release build under Instruments) — remains UNVERIFIED**, and cannot literally yield a 99p on this machine (Time Profiler reports an aggregate share; `VideoTap.swift:112` samples 1-in-64 into two bucket counters), so expect a PARTIAL result. Phase 8 Oracle round 1 scored 7/10; the benchmark-methodology + honesty fixes landed in `944795a` with no post-fix re-score recorded.

The remaining **manual/hardware checklist is in `verification.md`** and is ⏳ IN PROGRESS with the user from 2026-09-05 (live results in the runbook artifact https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8, transcribed back into `verification.md` at the end; sprint ledger — inventory + flow diagram — at https://claude.ai/code/artifact/4556b46a-1863-4be5-8986-3b1702624a60): 8.5-8.10/8.13/8.14 (long-playback drift, AirPods/AirPlay/system-output route changes, surround, item replacement), 8.5b-8.5e (live EQ / seek / visualizer / telemetry), and 7.9/7.10 (signed-bundle smoke). Dispositioned: **8.2 ⛔ NOT ABLE** (no Intel Mac), **8.12 ⛔ NOT ABLE** (no in-app trigger; optional), **8.11 ⛔ NOT ABLE AS WRITTEN** (no supported AAC↔SBC forcing path; optional device-substitution → PARTIAL), **8.5 conditional** on a user-supplied ≥10-min lip-sync video, **8.6-8.9 hardware-dependent**.

**Phase 9 is NEXT** and may run in parallel with the user's manual gates: UI audit (9.1-9.3), the mandatory docs pass per `docs-update-backlog.md` (9.4-9.6), final smoke + TSan + pre-PR Oracle (9.7-9.10), then commit/re-push/PR #C (9.11-9.14) — **PR #C must follow manual verification.** The branch **cannot be closed out directly after the manual runbook**: the sequence is manual gates recorded in `verification.md` → Phase 9 (9.1-9.3 UI audit; 9.4-9.6 + 9.6b/9.6c mandatory docs incl. `CLAUDE.md` and `.ai-shared/macamp/project.md`; 9.7 smoke; 9.8 TSan; 9.9-9.10 pre-PR Oracle; 9.11 commit) → 9.12 push → 9.13 `gh pr create` PR #C → 9.14 human review → merge → post-merge close-out 10.1-10.8 (move the task to `tasks/done/`, delete `spike/avplayer-inplace-tap-dsp`, advance `_context` to S3-3), with 9.1-9.11 free to run in parallel while PR #C waits on the manual results.

Phase 9 docs scope must ALSO cover `CLAUDE.md` (lines ~61, 81, 82) and `.ai-shared/macamp/project.md` (lines ~18, 38, 39), which repeat the "all audio through one unified AVAudioEngine" framing and omit `VideoDSP/` — these are agent instructions and outrank `docs/` for correction priority.

> **todo 3.17 (audible EQ-on-video smoke) is no longer "deferred"** — Phase 5 delivered the fanout, now todo **5.16 ✅ USER-VERIFIED 2026-05-28**: all 4 video scenarios pass (EQ slider, EQ toggle, balance, EQ-on-before-video). Engine regression **5.17 ✅ USER-VERIFIED** (EQ on a music file unchanged). **Phase 5 is fully verified.**

---

## Architecture / flow changes for a later docs/ update (Phase 9 mandatory-docs backlog)

> Phase 9 mandates a `docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection. The following Phase 2-5 deltas should be folded into `docs/` then. **→ The DETAILED, per-doc, line-referenced backlog is in `tasks/avplayer-native-video-dsp/docs-update-backlog.md`** (produced 2026-05-28 by a 5-agent team that read each `docs/` file in full). The list below is the high-level summary; the dedicated file is authoritative for the Phase 9 doc pass.

1. **Video-tap in-place DSP path (NEW signal flow).** `AVPlayer` → `AVMutableAudioMix` → `MTAudioProcessingTap` → `tapProcess` modifies the buffer **in place** (steps: StartOfStream filter reset → preamp → `isEqOn` gate → `BiquadCascade` → balance) → AVPlayer's native pipeline plays the modified buffer. No ring buffer, no engine clock for video, no master-clock coupling. *Needs a flow diagram in docs/* contrasting this with the engine path.
2. **Dual-architecture topology** (already tabled above in this file): engine-managed transports (local audio, streams) use `AVAudioUnitEQ` + engine balance + engine tap visualizer; AVPlayer-managed transports (local video) use tap-side `BiquadCascade` + tap balance + (Phase 4) tap visualizer feed. EQ math lives twice by design (AHA — different threading/ownership).
3. **Coefficient hand-off concurrency contract (ADR-4 amendment #2).** `VideoTapContext.coefficients: Mutex<BiquadCoefficientSet?>`; main writes via `installCoefficients` (`withLock`), render reads via `withLockIfAvailable` (non-blocking, three-case double-optional) into a render-owned `BiquadCascade` cache; skip-on-contention reuses the last cache. Replaces the withdrawn race-unsafe atomic-pointer A/B double-buffer.
4. **`@unchecked Sendable` containment (ADR-3a) — final field set.** Gate-1 header contract; every field `Atomic`/`Mutex`/`RenderThreadSafe`. `cascade: BiquadCascade` is render-confined (RenderThreadSafe-by-confinement), enforced by Gate-3c source-scan test. Document the contract + the three gate tests.
5. **RBJ coefficient model.** Octave-BW peaking (bands 1-8) + S=1 low/high shelf (bands 0/9) matches `AVAudioUnitEQ` ≤0.5 dB; `BiquadCoefficientSet.frequencies` is the single source of truth shared with `EqualizerController.configureEQ`. Fail-closed to `.flat` for non-finite/Nyquist inputs; denormal state flush in the cascade.
6. **Balance convention.** Video tap uses `[-1, 1]`/0.0-center (matches `AudioPlayer.balance`/`AVAudioNode.pan`).
7. **Visualizer dual-producer (Phase 4, ADR-6).** Two parallel producers feed ONE shared `VisualizerFeed` (single-slot SPSC, trylock): the engine `makeTapHandler` (AVAudioPCMBuffer) and the video `videoTapVisualizerRender` (AudioBufferList, in `tapProcess` step 7, post-DSP). Only one is active at a time (audio vs video). Consumer side: `AudioPlayer.isVisualizerRendering` (engine OR video) gates `getFrequencyData`/`snapshotButterchurnFrame`/`VisualizerView` (spectrum + oscilloscope + bar-height floor); the 30 Hz poll timer is driven for video via `VisualizerPipeline.start/stopVideoVisualization` (hooked into video start / video→audio / stop / completion / repeat-one). **The visualizer renders in TWO windows from one shared path:** `VisualizerView()` is instantiated in both `MainWindowFullLayer` (main window) and `WinampPlaylistWindow` (the mini-visualizer shown when the main window is shaded), both reading the same `@Environment(AudioPlayer.self)` — so the same gating drives both; there is no playlist-specific visualizer code. RMS+Goertzel duplicated per ADR-6 (FFT shared); a flow diagram should show both producers → feed → consumer → both windows.
8. **EQ + balance state fanout (Phase 5, ADR-5).** Two canonical owners, parallel fanout: `EqualizerController` owns EQ → on change (`preamp`/`eqBands`/`isEqOn` didSets) fans out to the engine `AVAudioUnitEQ` AND to registered video-tap Contexts (`installCoefficients` Mutex hand-off + `isEqOn`/`preamp` atomics); `AudioPlayer` owns balance → `balance.didSet` fans to the engine balance node AND each Context's `balance` atomic. Each owner keeps a separate `WeakBox` registry; Contexts register in `startVideoLoad` and unregister in `pauseAndDetachVideoTapIfNeeded`. Sample-rate-dependent coefficient recompute is a main-thread poll (`VisualizerPipeline.onPollTick` → `EqualizerController.pollVideoTapSampleRates`) keyed on the render-published `pendingSampleRate`. Diagram: owner → (engine consumer ∥ tap-Context consumer).
9. **Open follow-ups to mention:** P-6 (video→audio no auto-play), P-2/P-3 (Swift-6/SDK-evolution gaps).
