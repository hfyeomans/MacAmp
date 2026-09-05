# S3-2 Architectural Pivot Tracker

> **Date:** 2026-05-01 (created), 2026-09-05 (last update — Phase 8 automated gates logged; header, Step-3 row, file index and decision log advanced to HEAD `056c69a`)
> **Status:** Steps 1-3 ✅. Implementation: **Phases 1 + 2 + 3 + 4 + 5 + 6 + 7 ✅ DONE.** Phase 7 (2026-06-26): lifecycle + production tests (`VideoTapLifecycleTests` 6→11 — rapid-cycle leak, injected create-failure via `_testForceTapCreateFailure` seam, attach+drop finalize, pause/resume survival, replaceCurrentItem(nil) release); **115/115 TSan**; Oracle 8→9/10 APPROVED. Phase 6 (Oracle 9): deadline-miss telemetry. Phase 5 (Oracle 10): EQ + balance fanout, audible EQ-on-video LIVE. Phases 3/4 (Oracle 9.6): BiquadCascade ≤0.5 dB + video visualizer. **Phase 8 (2026-06-27): automated gates ✅** — 8.3 EQ ≤0.5 dB, 8.4 TSan **116/116**, 8.15 lifecycle, 8.1 CPU *Debug (-Onone) regression guard* (p99 ≈11% / max ≈13% of the 21,333 µs deadline — the production ≤10% figure is gate 8.1b, Release + Instruments, **UNVERIFIED**); Oracle 7/10 → benchmark-methodology + honesty fixes. **Manual/hardware gates ⏳ READY FOR USER** (`verification.md`: 8.1b, 8.2, 8.5-8.14, 8.5b-8.5e, 7.9/7.10). **Phase 9 NEXT** (UI audit + mandatory docs + pre-PR Oracle + PR #C) — may run in parallel with the manual gates; PR #C follows them. Mid-branch: Xcode 27/Swift 6.4 migration fixes (12 warnings + ZIPFoundation 0.9.20).
> **Purpose:** Track the architectural pivot of S3-2 from engine-routing to AVPlayer-native DSP. Authoritative source for the S3-2 strategic decision log — the `_context/state.md` / `tasks_index.md` / `resume-prompt.md` files carry pivot banners pointing here, and all three were advanced to HEAD `056c69a` in the same 2026-09-05 sweep, so their status text now agrees with this file (Phases 1-7 ✅; Phase 8 automated gates ✅, manual/hardware gates pending user; Phase 9 next).

---

## Strategic decision

S3-2 (`video-audio-engine-routing`) reached Phase 7 testing and revealed the engine-routing approach for video audio fights the macOS platform too hard. The architecture extracts video audio from AVPlayer via `MTAudioProcessingTap`, writes it to a `LockFreeRingBuffer`, has `AVAudioSourceNode` consume from the ring on the engine side, and applies engine processing (EQ, balance, visualizer tap). Three structural problems emerged:

1. **`AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods route changes.** Apple's notification only fires when the engine's effective configuration actually changes (sample rate, channel count, etc.). AirPods on macOS route through the AirPlay subsystem and don't always trigger it. Proven by missing `Engine will reconfigure` log line in user traces during Phase 7 testing — the watchdog gate never armed for the bug case. Apple SDK header evidence (AVAudioEngine.h, AudioHardware.h; macOS has no route-change notification) is recorded in `tasks/airpods-route-gate-validation/state.md` (unindexed review-scratch folder, 2026-05-01).

2. **Master-clock-coupled video stalls.** AVPlayer's audio queue is the master clock for video on macOS. Any ring under-run on the engine consumer side stalls the master clock, which stalls the video frame. Mitigated but not eliminated by larger ring (16 K frames vs original 4 K).

3. **Dual-clock-domain drift.** Engine output clock vs AVPlayer master clock are unsynchronized. Drift accumulates on long playback (>5–10 min) and resets on pause/resume. Phase 7 fixes (Mastering SRC + 16 K ring) reduced perceived drift but the topology guarantees some residue.

**Plus tinning artifacts** from the second SRC stage that AudioConverter introduces — required raising AudioConverter's quality tier to Mastering / Max to match what AVPlayer's native pipeline does internally. Net fidelity tax remained.

**The contrarian solve:** don't drag video audio out of AVPlayer. Apply DSP in-place inside the same `MTAudioProcessingTap`, modifying the source buffer that AVPlayer's native pipeline plays. No ring, no engine clock for video, no second SRC stage, no master-clock coupling. AVPlayer keeps full ownership of its clock and route handling; tap-side DSP brings EQ + balance + Milkdrop to where the audio already is.

The cost is a small WET duplication: EQ math lives twice (engine path uses `AVAudioUnitEQ`; tap path uses new `BiquadCascade`). Per Principle 4 (AHA Rule of Three) this is the right kind of WET — different threading, different parameter-update paths, different ownership models. Sharing would create a flag-driven abstraction that conflates two genuinely different scenarios.

---

## Saved reference branch

The engine-routing branch is preserved as a reference (NOT being merged):

- **Branch:** `feat/video-audio-engine-routing`
- **Last commit:** `5af91eb` (`docs(vaer): mark branch paused for S3-2 architectural pivot`)
- **Push status:** ✅ Pushed to origin (off-machine backup)
- **Total commits ahead of `main`:** 44 (43 implementation + 1 pause-doc commit)
- **Phases shipped:** Phase 0 ✅ + Phase 1 ✅ + Phase 2 ✅ + Phase 3 ✅ + Phase 5 ✅ + Phase 6 ✅ + Phase 7 partial (gate v2 + HAL listener + 3 s threshold + edge cases — Oracle 9.2/10 final pass, but real-hardware testing showed the gate v2 still failed because the engine notification didn't fire for the bug case)
- **Tests on saved branch:** 110/110 with TSan
- **Task folder:** `tasks/video-audio-engine-routing/` — the PAUSED-AS-REFERENCE banner lives on the **saved branch's** copy of `state.md`; the copy in this branch's working tree is a pre-Phase-2 snapshot (this branch was cut before that task's later doc commits), so the saved branch is the accurate record

The saved branch is the canonical record of the engine-routing approach's most-developed state. Useful as research reference for: channel-mapping / surround-downmix logic, C-side `MTAudioProcessingTap` callback patterns, atomics-driven cross-thread state, TSan test patterns, Oracle review history, the Phase 7 quality investigation findings.

---

## Three-step plan

### Step 1 — Mechanical pivot ✅ DONE (2026-05-01)

| Task | Status | Notes |
|------|--------|-------|
| Push `feat/video-audio-engine-routing` to origin (backup) | ✅ | Tracking set up |
| Cut `feat/avplayer-native-video-dsp` from `main` | ✅ | Branched at main commit `9cca40a` |
| Cherry-pick 13 Phase 1 commits (`3ed4356` → `2aa2f18`) | ✅ | Engine config observer (stream-side resilience). Clean cherry-pick, no conflicts. |
| Drop `wasVideoBridge` field from `PreReconfigureSnapshot` | ✅ | Phase 1 had the field as forward-looking; this branch has no engine video bridge so it's removed. Commit `ffd77c1`. |
| Build + TSan green | ✅ | 72/72 with TSan |
| Scaffold `tasks/avplayer-native-video-dsp/` with 6 canonical files | ✅ | All skeletons created |
| Create this tracker | ✅ | This file |
| Cross-reference from `_context/state.md`, `tasks_index.md`, `resume-prompt.md` | ✅ | All three updated |
| Mark old branch + old task PAUSED | ✅ | `5af91eb` on saved branch |

### Step 2 — Research phase ✅ DONE (2026-05-01)

Oracle 10/10 final after 5 rounds (7.8 → 8.9 → 9.1 → 9.5 → 10). Commits `4a80bf9` → `46bb6af`. See `tasks/avplayer-native-video-dsp/research.md` for the full synthesis + Evidence Ledger. Summary:

| Activity | Status | Kill switch outcome |
|----------|--------|---------------------|
| Phase 0 spike — `MTAudioProcessingTap` in-place buffer modification feasibility | ✅ | ✅ EMPIRICALLY CONFIRMED — audible -20 dB attenuation A/B vs control on macOS 15+ Swift 6.2; programmatic write-verify (pre × gain == post). Architecture green. |
| Apple docs review — TN2249, `AVMutableAudioMix`, AU reference, WWDC archive | ✅ | SDK header documents in-place modification verbatim. `_PreEffects` flag selected. |
| Reference-branch retrospective — read `feat/video-audio-engine-routing` end-to-end | ✅ | 5-item ALLOWLIST + 11-item DENYLIST with file:line citations. 1 modernization gap (`ManagedAtomic` → `Synchronization.Atomic`). |
| `AVAudioUnitEQ` numerical-match research | ✅ | HIGH confidence — Apple uses RBJ cookbook (Butterworth/octave-BW per `AudioUnitParameters.h`). Tolerance ≤0.5 dB / hard reject ≤1 dB. |
| Render-thread CPU budget measurement | Estimated, NOT validated | Empirical benchmark gate landed in plan.md Phase 8 (AS + Intel × 44.1/48 × stereo/5.1). |
| Channel-count / sample-rate handling | ✅ | Audible path leaves layout untouched; visualizer-feed downmixes surround → mono. |
| `VisualizerFeed` extraction approach | ✅ | Rename + visibility-promotion of `VisualizerSharedBuffer` + `VisualizerScratchBuffers`; ~100-150 LOC; engine-path byte-for-byte identical. |
| Findings written to `research.md`; Oracle research-pass review | ✅ | 17-row Evidence Ledger; 11-gate verification matrix; Concurrency Decision Record; Tap Lifecycle Contract; Tooling Constraints. |

### Step 3 — Plan phase ✅ DONE (2026-05-02)

Oracle 9.8/10 final after 5 rounds (8.3 → 8.9 → 10 → 9.2 → 9.8). Commits `1ae8e80` → `fdce0ed`. The 0.2 below 10 reflects added scope from ADR-3a (Containment of `@unchecked Sendable` drift), added at user request 2026-05-02 with 3 durable gates (header contract / `RenderThreadSafe` marker / DEBUG Mirror+source tests).

| Activity | Status |
|----------|--------|
| Write `plan.md` from research | ✅ |
| Iterate with Oracle until ≥9/10 APPROVED | ✅ (final 9.8/10 — exceeds bar) |
| Get user sign-off | ✅ 2026-05-02 |
| Derive concrete `todo.md` phases from plan | ✅ 2026-05-02 |
| Begin implementation phases (9 phases per plan §6) | 🔧 Phases 1-7 ✅ DONE (Oracle-approved from Phase 2 on; Phase 1 had no Oracle round); Phase 8 automated gates ✅ 2026-06-27, manual/hardware gates ⏳ pending user per `verification.md`; **Phase 9 NEXT** |

---

## File index

- **`tasks/avplayer-native-video-dsp/`** — new task folder
  - `state.md` — task-internal status (Phases 1-7 done; Phase 8 automated done, manual pending user; Phase 9 next)
  - `research.md` — research questions + Phase 0 spike kill-switch criteria
  - `plan.md` — ✅ complete (Oracle 9.8/10) — 15 sections, 11+1 ADRs, 9 implementation phases
  - `todo.md` — ✅ populated 2026-05-02, maintained through Phase 8 — Phases 1-8 all checked/dated; Phase 9 (9.1-9.14) and post-merge close-out (10.1-10.8) present but still unchecked
  - `placeholder.md` — 6 entries (P-1…P-6), statuses reconciled 2026-09-05. Genuinely open: P-2 (Mirror `~Copyable` gap), P-3 (`@preconcurrency import AVFoundation`), P-6 (video→audio no auto-play — non-blocking, surfaced again in gate 8.14). Resolved: P-1 (`24f8a12`), P-4 (closed in Phase 3), P-5 (`c040e76`)
  - `depreciated.md` — ✅ populated 2026-09-05: withdrawn `installCoefficientSet` + `coefficientBlockA`/`B` double-buffer, removed `attachVideoTap`/`detachVideoTap` facades, dropped `wasVideoBridge` field (`ffd77c1`)
  - `verification.md` — Phase 8 gate matrix; hardware-manual checklist awaiting the user
  - `docs-update-backlog.md` — per-file docs plan feeding Phase 9 items 9.4-9.6
  - `phase2-walkthrough.md` — Phase 2 implementation walkthrough (21 KB)
  - `research-notes/` — 5 Step-2 research note files
- **`tasks/video-audio-engine-routing/`** — saved task folder; the PAUSED banner is on the saved branch's `state.md` (the working-tree copy here is a pre-Phase-2 snapshot)
- **`tasks/_context/s3-2-pivot.md`** — this file
- **`tasks/_context/state.md`** — top-of-file pivot banner; sprint table reflects pivot
- **`tasks/_context/tasks_index.md`** — `video-audio-engine-routing` row marked PAUSED-AS-REFERENCE; new task added
- **`tasks/_context/resume-prompt.md`** — Active Work Queue updated; First Action points at this file
- **`tasks/_context/instruments-allocations-workflow.md`** — reusable leak-check workflow produced by this task (Memory Graph Debugger, not Allocations, for pure-Swift classes)

---

## Decision log (key moments)

- **2026-04-30** — Phase 7 quality investigation on `feat/video-audio-engine-routing`: SRC artifacts, ring under-runs causing video stalls, drift over long playback. Several iterations fixed each symptom but the topology kept producing new edge cases.
- **2026-05-01** — Phase 7 watchdog gate v2 + HAL listener (Oracle 9.2/10). Real-hardware testing reproduced the route-change bug because `AVAudioEngineConfigurationChange` doesn't fire for AirPlay route changes — proven by missing log line.
- **2026-05-01** — User raised the contrarian framing: instead of dragging video audio out of AVPlayer, apply processing in-place via the same tap. Architecture sketch laid out in conversation. User chose to pivot.
- **2026-05-01** — Step 1 mechanical pivot executed.
- **2026-05-02** — Phase 1 (VisualizerFeed extraction) ✅ + Phase 2 (production tap scaffold, Option C audioMix-on-construction, ADR-3a containment) ✅ landed; 7 Oracle rounds → 9.0/10 APPROVED; 85/85 TSan (74/74 vs 85/85 discrepancy — open item for Phase 9 pre-PR Oracle). ADR-4 A/B-swap install withdrawn as race-unsafe → P-4 gates Phase 3.
- **2026-05-28** — Phase 2 fully closed: todo 2.40 leak check ✅ via Memory Graph Debugger on the real playback path (`VideoTapContext` + both coefficient blocks 1→0 across clip load→teardown, no leak). Found that Allocations Instruments can't show pure-Swift classes by name (→ `_context/instruments-allocations-workflow.md`). Non-blocking finding P-6 logged (video→audio no auto-play).
- **2026-05-28** — P-4 resolved + Phase 3 implemented in one session. Chose ADR-4 amendment #2 (`Mutex<BiquadCoefficientSet?>` + render `withLockIfAvailable`, copy-out into a render-owned `BiquadCascade` cache); Oracle gpt-5.5 xhigh → **9.0/10 APPROVED**, 4 actionable items folded in. Implemented `BiquadCoefficientSet`+RBJ `compute`, `BiquadCascade` (DF2II, render-confined `let` field on Context — no new Unmanaged, 2.40 leak balance preserved), Context Mutex refactor, `tapProcess` steps 2-6. **89/89 TSan, no races**; `BiquadNumericalMatchTests` ≤0.5 dB vs `AVAudioUnitEQ` (no tuning needed). Commits `37f9edc` (ADR) → `24f8a12` (core) → `4feec43` (tests).
- **2026-05-28** — Phase 3 code Oracle review (gpt-5.5 xhigh). Round 1: 7/10 REVISE — no concurrency/RT blocker, but 1 latent balance-convention bug + 5 robustness items. Fixed: tap balance → app's [-1,1]/0.0 convention (prevents Phase 5 center→hard-left); EQ-off→on cascade reset; `compute` fail-closed for sampleRate≤0 / mis-sized gains; `maxDSPChannels` 8→16; `configureEQ` reads the shared `BiquadCoefficientSet.frequencies`; `withBands` layout assertion. Declined full >16ch all-or-none as over-engineering. Round 2: 8.5/10 — caught band-at/above-Nyquist NaN (fixed: fail-closed). Round 3: 9.1/10 — caught non-finite (`.infinity`/NaN sampleRate, NaN/Inf gains) → added `isFinite` guards + all-coefficients-finite safety net + denormal flush + render-confinement source test (`cascadeIsRenderConfined`). Round 4: **9.6/10 APPROVED, no remaining BLOCKER/ACTIONABLE** — remaining 0.4 is diminishing-returns polish (EQ-reenable-under-contention edge, low-rate fail-closed trade-off, perf-benchmark gold-plating, audit-vs-compiler enforcement) — deliberate trade-offs, not defects. 93/93 TSan. Commits `84b9964`→`e2eba05`→`ddd0431`. Phase 4 next.
- **2026-05-28** — Phase 4 (visualizer DSP, ADR-6 dual-producer) implemented + reviewed. `videoTapVisualizerRender` (AudioBufferList → shared `VisualizerFeed`, RMS/Goertzel duplicated per ADR-6, FFT shared); `VideoTapContext` gained `feed`(injected)/`scratch`(owned); tapProcess step 7. Oracle arc: round 1 6/10 (2 BLOCKERs — video frames published but NOT consumed: poll timer bound to engine tap + UI gated on isEngineRendering) → fixed via `VisualizerPipeline.start/stopVideoVisualization` + `AudioPlayer.isVisualizerRendering` ungating + VisualizerView/oscilloscope; round 2 8/10 (timer leak on natural completion → fixed); round 3 9.0 (repeat-one `.restartCurrent` bypasses playTrack → re-arm timer there); round 4 **9.6/10 APPROVED**. 98/98 TSan. Commits `92d0079`→`2884033`→`d475374`→`1634dbd`. Post-close (user-reported): verified the playlist-window mini-visualizer (shaded main) reuses the same shared `VisualizerView`/`AudioPlayer` as the main window — no separate path; fixed one stray `isEngineRendering` (bar-height floor) → `ea95f10`. User smoke tests 1-6 pass.
- **2026-05-28** — Phase 5 (EQ + balance state fanout, ADR-5) implemented + reviewed. Two canonical owners: `EqualizerController` (EQ → didSet fanout: compute+`installCoefficients` + isEqOn/preamp atomics) + `AudioPlayer` (balance → didSet → balance atomic); shared `WeakBox` registries; register in `startVideoLoad`, unregister in `pauseAndDetachVideoTapIfNeeded`; sample-rate poll via `VisualizerPipeline.onPollTick`. Audible EQ-on-video now live (todo 3.17 delivered as 5.16). `VideoTapFanoutTests` (5). Oracle round 1 9/10 (ACTIONABLE balance test + 3 NITs) → fixed → round 2 **10/10 APPROVED, no findings** (duplicate-path sweep clean). 103/103 TSan. Commits `e1f8a4e`→`252d3bc`. Phase 6 next.
- **2026-06-26** — Xcode 26→27 (Swift 6.2→6.4) toolchain migration (mid-branch, surfaced pre-existing issues, NOT S3-2): fixed 12 new compiler warnings (`786b3c2`) + a TSan launch crash from ZIPFoundation 0.9.19's misaligned ZIP read → upgraded to 0.9.20 (`1561621`). TSan gate restored 103/103.
- **2026-06-26** — Phase 6 (deadline-miss telemetry, ADR/plan §6) implemented + reviewed. RT-safe atomic counters (`budgetOverrunCount`/`deadlineRiskCount`/`lastDeadlineRiskHostTime`) sampled every 64th `tapProcess` callback (cached Mach timebase, prewarmed off render thread); `VideoTapDiagnostics` main-thread snapshot; pure `recordProcessingDeadline` eval as the test seam. Deliberate: NO render-thread logging (RT-safety). Oracle round 1 8/10 → fixed (A2 real `tapPrepare` store-ordering bug: sample rate must publish before format-tag release-store; A1 timebase prewarm; A3 advisory-sampling doc + NITs) → round 2 **9/10 APPROVED**. `VideoTapTelemetryTests` (7). 110/110 TSan. Commits `82365c7`→`3fd157c`. Phase 7 next.
- **2026-06-26** — Phase 7 (lifecycle + production tests, plan §6 Phase 7 / ADR-7/10) implemented + reviewed. `VideoTapLifecycleTests` 6→11: rapid-cycle leak, injected `MTAudioProcessingTapCreate` failure (`@MainActor static var _testForceTapCreateFailure` seam — skips the real create so no double-release), attach+immediate-drop finalize, pause/resume Context-survival, replaceCurrentItem(nil) release. Oracle round 1 8/10 (overstated coverage) → fixed (added the 7.5 pause/resume test, reframed the replaceCurrentItem release-vs-UAF claim, tightened flag scoping, honest 7.6 deferral) → round 2 **9/10 APPROVED**. 115/115 TSan, stable across re-runs. Signed-bundle smoke READY FOR USER. Commits `b443369`→`7f50c2c`. Phase 8 next.
- **2026-06-27** — Phase 8 (verification matrix) — **automated gates executed**. Added `VideoTapCPUBenchmarkTests`: dense per-iteration timing of the worst-case DSP core (preamp + all 10 bands + balance + visualizer, 1024 frames stereo @ 48 kHz, 2,000 iterations). PASS: **8.1** CPU as an explicitly-scoped **Debug (`-Onone`) regression guard** — p99 ≈11% / max ≈13% of the 21,333 µs deadline (fits ~9× over even unoptimized); **8.3** EQ ≤0.5 dB vs `AVAudioUnitEQ`; **8.4** TSan **116/116**; **8.15** lifecycle (Phase 7 tests). Oracle round 1 **7/10** → fixes (refresh working buffers from a pristine source outside the timed region — the old loop fed EQ output back into input 2000× and distorted the cost; include preamp in the measured chain; relax `max` to ≤budget; stop overstating 8.1 as the production gate); no post-fix re-score was recorded. **8.1b (Release + Instruments `tapProcess` 99p ≤10%) remains UNVERIFIED** — the Debug guard is a regression net, not the production figure. `verification.md` created (8.16) with the full hardware-manual checklist. Commits `2c410a0`→`944795a`→`056c69a`. Manual/hardware gates (8.1b, 8.2 Intel, 8.5-8.14, 8.5b-8.5e, 7.9/7.10 signed-bundle) **READY FOR USER**. Phase 9 next.
- **2026-09-05** — Documentation reconciliation sweep. No code has changed since `944795a` (2026-06-27); HEAD `056c69a` is docs-only and the branch has been idle since. **73 commits ahead of `main`** (`9cca40a`). Branch state: **pushed to origin at `056c69a`; unmerged; PR #C not yet opened** (`origin/feat/avplayer-native-video-dsp` is in sync at `056c69a` — todo 9.12 being unchecked is a stale checkbox, not a push gap; 9.13/9.14 unchecked is the real PR gap). Tracker header, Step-3 row, file index and decision log advanced to HEAD; in the same sweep `_context/state.md`, `tasks_index.md`, `resume-prompt.md` and the task's own `state.md` / `todo.md` / `placeholder.md` / `depreciated.md` were advanced too, so the set is now internally consistent. No code was re-verified.
