# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" + "First Action" sections after each phase completion or PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each phase completion or PR merge)

> ⚠️ **S3-2 ARCHITECTURAL PIVOT — IMPLEMENTATION IN PROGRESS (pivot decided 2026-05-01; current status per "Last update" below).** `feat/video-audio-engine-routing` is **PAUSED-AS-REFERENCE** (preserved at `5af91eb`, pushed to origin). S3-2 re-attempted as **`avplayer-native-video-dsp`** on branch `feat/avplayer-native-video-dsp`. **Steps 1+2+3 ✅ + Phases 1-7 ✅ + Phase 8 AUTOMATED gates ✅ done (2026-06-27). Phase 8's hardware-manual gates 🔄 IN PROGRESS WITH THE USER from 2026-09-05 (`tasks/avplayer-native-video-dsp/verification.md`); Phase 9 (UI polish + docs + PR #C) NEXT.** See `tasks/_context/s3-2-pivot.md` for the strategic decision log + step-by-step status — that file is authoritative.

### 2026-09-05 — manual runbook IN PROGRESS (user)

The user started executing the Phase 8 hardware-manual gates on 2026-09-05.

- **Runbook artifact (per-gate PASS / PARTIAL / FAIL / NOT ABLE + notes, saved in the page):** https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8 — `verification.md` remains the record of truth and is transcribed at the end.
- **Sprint ledger artifact (inventory + flow diagram):** https://claude.ai/code/artifact/4556b46a-1863-4be5-8986-3b1702624a60
- **LLDB / telemetry readout decision:** the LLDB path is the xcodebuildmcp CLI debugging workflow (`xcodebuildmcp debugging attach --pid <pid> --make-current`, `lldb-command --command "…"`, `continue`, `detach`). Attach needs `com.apple.security.get-task-allow` — Debug has it, the Developer-ID Release app does not. **RELEASE FIRST:** run 7.9 (signed smoke) + 8.1b (Time Profiler) on the Release build, then re-sign that same app with `get-task-allow` (Apple Development identity `A5V7U473GS`) for the 8.5e read (breakpoint `EqualizerController.swift:106` in `pollVideoTapSampleRates`, `po context.diagnosticSnapshot`; if the optimised frame hides `context`, `po self.registeredVideoTapContexts.compactMap { $0.value }.map { $0.diagnosticSnapshot }`); **DEBUG FALLBACK** if attach or the expression fails. Instruments Allocations (7.10 thorough path) is Debug-only regardless; `xcrun heap` works on any get-task-allow build. Record which build produced the 8.5e numbers.
- **Xcode MCP conclusion (final — the user reconnected it via `/mcp` on 2026-09-05):** it **IS an LLDB path** — `RunProject` (attachDebugger) + `InvokeDebuggerCommand` + `GetConsoleOutput` + `StopProject` (47 tools in all). An Xcode Run injects `get-task-allow` at build time, so the 8.5e read on a Release build needs **no re-sign**: switch the scheme's Run action to Release in Edit Scheme (the generated scheme runs Debug, profiles Release), then Claude drives the run / breakpoint / `po` — **PATH A** in the runbook; leave the scheme at Debug for the fallback. `xcodebuildmcp debugging attach --pid` is **PATH B** (re-sign needed for the Developer-ID app) and xcodebuildmcp remains the build/test tool. Both toolchains are usable from Claude's session.
- **NOT ABLE TO COMPLETE dispositions:** 8.2 Intel CPU benchmark (no Intel Mac; identical scalar DSP, Apple Silicon result is the primary gate); 8.12 mid-playback format re-prepare (no in-app trigger — no audio-track picker, `audioMix` set once per item per ADR-7; optional gate, skip sanctioned); 8.11 BT AAC↔SBC codec switch NOT ABLE AS WRITTEN (no supported renegotiation trigger on macOS 15/27 — device substitution is a PARTIAL at best). 8.5 long-playback drift is CONDITIONAL on a user-supplied ≥10-minute lip-sync video (in-repo clips are 3.000 s; looping resets drift). 8.6-8.9 are hardware-dependent (AirPods 1st gen, AirPods Pro, AirPlay-1, AirPlay-2) — anything unsourceable is recorded NOT ABLE with its reason.
- **Pickup after terminal restart (2026-09-06) — permissions VERIFIED WORKING:** the user granted the terminal app (cmux) **Accessibility** (keystroke synthesis via `osascript`/System Events now succeeds) and **Screen Recording** (`screencapture -x` now produces a real 3840×1600 image), so Claude can click/type in MacAmp (load clips via the ADD panel, open windows, cycle repeat) and take screenshots (visualizer animating / not pinned, video window state). Still missing and optional: `brew install switchaudio-osx` (would let Claude perform the 8.10 output switch) and `blueutil` (BT connect/disconnect). **Execution plan agreed:** Phase A — Claude alone (steps 1, 2, 3, 4 + dry-run of 5–7 mechanics, results prefilled in the runbook page); Phase B — live together ~40 min (step 1 listen; steps 5–7 Claude drives / user listens; steps 8–10 user does the hardware action on cue / Claude measures via telemetry / user confirms by ear; step 11 only with an SBC-only device); Phase C — mostly async (step 12 user supplies the ≥10-min video, Claude runs it, user checks lip-sync at 0:30/2:00/5:00/10:00; step 14 Claude transcribes/commits/pushes; then Phase 9). The runbook artifact carries CLAUDE / YOU labels and a "Who" line per step, plus a "How we run this" section. **Ownership split agreed 2026-09-06:** Claude drives every mechanical step under PATH A (Xcode MCP `RunProject` + `InvokeDebuggerCommand`): at a breakpoint in `AudioPlayer`/`EqualizerController` the app's own API is callable from LLDB — `playTrack(track:)`, `play()`, `pause()`, `stop()`, `seek(to:resume:)`, `balance`, `playlistController.addTrack(_:)`/`clear()`, `equalizer.setEqBand(index:value:)`/`setPreamp(value:)`/`isEqOn`, `AppSettings.visualizerMode`/`repeatMode`/`showVideoWindow`/`showMilkdropWindow` (all confirmed in source; `AudioPlayer.equalizer` is `private let` — LLDB reaches it). Claude-owned outright: step 2 (8.1b `xctrace record` + `xctrace export` → `tapProcess` share), step 3 (8.5e telemetry, two reads), step 4 (7.10 heap census + Allocations export on Debug), step 14 (transcribe + commit). "Claude drives, user judges": steps 5–10 and 12 (Claude runs the stress/replacement/surround/route/drift mechanics and gathers objective proxies — `processCallCount`/`isActive` resuming after a route change, `isEqOn` + coefficients intact — while the user supplies the ears/eyes verdicts and the hardware actions: ADD-loading clips into the Developer-ID app, System Settings output switch, AirPods/AirPlay connect/disconnect, the ≥10-min video, lip-sync). Neither: 8.11 (as written), 8.12, 8.2. **Next action:** user sets Xcode → Edit Scheme → Run → Build Configuration → Release and says "go"; Claude re-runs `XcodeListWindows` (the tab id was `windowtab1` — may change after restart), reconnects Xcode MCP via `/mcp` if it shows CONNECTION_CLOSED, then executes steps 2 → 3 → 4 first while the user prepares hardware. MacAmp has no open-file handler (issue #79), so without Accessibility the user loads clips via the playlist ADD button; with the debugger attached Claude adds them via `playlistController.addTrack`.
- **When does this branch close? NOT directly after the manual runbook.** Sequence: manual gates recorded in `verification.md` → Phase 9 (9.1-9.3 UI audit; 9.4-9.6 + 9.6b/9.6c mandatory docs incl. `CLAUDE.md` and `.ai-shared/macamp/project.md`; 9.7 smoke; 9.8 TSan; 9.9-9.10 pre-PR Oracle; 9.11 commit) → 9.12 push → 9.13 `gh pr create` PR #C → 9.14 human review → merge → post-merge close-out 10.1-10.8 (move the task folder to `done/`, delete `spike/avplayer-inplace-tap-dsp`, advance `_context` to S3-3). Phase 9's non-PR items (9.1-9.11) may run in parallel with the user's manual gates; PR #C waits for the manual results.

**Last update:** 2026-09-05 (manual runbook in progress; S4 ordering confirmed; branch pushed to origin at `5fe8c3c`. Doc refresh to code HEAD `056c69a`, 2026-06-27 — **Phase 8 AUTOMATED gates ✅ DONE**; hardware-manual gates 🔄 being executed by the user from `verification.md`; **Phase 9 NEXT**. Prior — 2026-06-26: Phase 7 ✅ **DONE** — lifecycle + production tests. `VideoTapLifecycleTests` 6→11: rapid-cycle leak (10 build/attach/drop → all released), injected `MTAudioProcessingTapCreate` failure via the `@MainActor static var VideoTap._testForceTapCreateFailure` seam → Context released not leaked (ADR-10; seam SKIPS the real create else a real tap's `tapFinalize` double-releases), attach+immediate-drop finalize, pause/resume Context-survival, replaceCurrentItem(nil) release. **115/115 tests with TSan, no races**, stable across re-runs. Oracle 8→**9/10 APPROVED** (round 1 flagged overstated coverage → added the 7.5 pause/resume test + honest reframing of the release-vs-UAF and seek→reset claims). Signed-bundle smoke (7.9/7.10) READY FOR USER. Commits `b443369`→`7f50c2c`. **Phase 8 automated gates ✅ DONE 2026-06-27** — commits `2c410a0`→`944795a`→`056c69a`: 8.1 Debug CPU regression guard, 8.3 EQ ≤0.5 dB, 8.4 TSan **116/116**, 8.15 lifecycle, 8.16 `verification.md`; Oracle 7/10 → methodology+honesty fixes, no post-fix re-score. Hardware-manual gates (8.1b Release/Instruments — the real ≤10% CPU gate, UNVERIFIED; 8.2 Intel; 8.5-8.14; 8.5b-8.5e; 7.9/7.10) 🔄 IN PROGRESS WITH THE USER from 2026-09-05. **Phase 9 NEXT** (UI polish + docs + pre-PR Oracle + PR #C). Prior: Phase 6 deadline-miss telemetry (Oracle 9); Xcode 27/Swift 6.4 migration fixes (12 warnings + ZIPFoundation 0.9.20). Open non-blocking: P-6.)
**Main HEAD:** `9cca40a` (main has not advanced during S3-2 work).
**`feat/avplayer-native-video-dsp` HEAD:** `5fe8c3c` — "docs(_context): sync tracking docs to HEAD 056c69a; queue S4 roadmap …" (2026-09-05, docs-only; run `git log -1 --oneline` to confirm). **Code HEAD is unchanged since `944795a` (2026-06-27)** — `056c69a` and `5fe8c3c` are both docs-only commits. **74 commits ahead of main** (run `git rev-list --count main..HEAD` for the live number). Commit arc: Phase 1 `146a8b4` → Phase 2 `ac7e0d5`→`7d3367c` (Oracle 9.0) → Phase 3 `37f9edc`→`ddd0431` (Oracle 7→9.6) → Phase 4 `92d0079`→`ea95f10` (Oracle 6→9.6) → Phase 5 `e1f8a4e`→`252d3bc` (Oracle 9→10) → Xcode-27 toolchain fixes `786b3c2`/`1561621` → Phase 6 `82365c7`→`3fd157c` (telemetry, Oracle 8→9) → Phase 7 `b443369`→`7f50c2c` (lifecycle tests, Oracle 8→9) → **Phase 8 `2c410a0`→`944795a`→`056c69a` (automated verification gates + `verification.md`, Oracle 7 → methodology/honesty fixes).**
**`spike/avplayer-inplace-tap-dsp` HEAD (throwaway, retained locally):** `dd53d64` — Phase 0 spike. In-place tap DSP works on macOS 15+ / Swift 6.2.
**`feat/video-audio-engine-routing` HEAD (paused-as-reference):** `5af91eb`. 44 commits ahead of main, pushed to origin.
**Tests:** 116/116 with TSan ON (72 baseline + 3 `VideoTapSendableContractTests` (Gate 3a/3b/3c) + **11** `VideoTapLifecycleTests` + 5 `VideoSeekStateMatrixTests` + 7 `BiquadNumericalMatchTests` + 5 `VideoTapVisualizerRenderTests` + 5 `VideoTapFanoutTests` + 7 `VideoTapTelemetryTests` + **1 `VideoTapCPUBenchmarkTests`** added by Phase 8).
**PRs merged total:** 80. `feat/avplayer-native-video-dsp` is **pushed to origin at `5fe8c3c` (2026-09-05 docs sync; code unchanged since `944795a`)** (0 ahead / 0 behind, upstream tracking set — todo 9.12 is effectively already done; its unchecked box is stale), but the branch is **unmerged and PR #C is not yet opened** (single PR at S3-2 close).

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected (these are OLD-vaer-branch artifacts, kept on main)

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). See `tasks/_context/state.md` for the full S3-1B closeout summary.

---

## Active Work Queue (ordered — start at the top)

### 1. IMPLEMENTING — `tasks/avplayer-native-video-dsp/` (S3-2 PIVOT)

**Status:** Steps 1+2+3 ✅ + Phases 1-7 ✅ + Phase 8 automated gates ✅ done (2026-06-27, commits `2c410a0`→`056c69a`). **Phase 8's hardware-manual gates 🔄 IN PROGRESS WITH THE USER from 2026-09-05** — checklist + pass criteria in `tasks/avplayer-native-video-dsp/verification.md`, driven from the runbook artifact linked in "Current State". **Phase 9 (UI polish + mandatory docs + pre-PR Oracle + PR #C) is NEXT for Claude** and may run in parallel with the user's gates — see `tasks/avplayer-native-video-dsp/todo.md` for the per-phase work breakdown.

**Why pivoted:** The original S3-2 (`feat/video-audio-engine-routing`) reached Phase 7 testing and revealed structural issues with the engine-routing approach: `AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes (proven by missing log line), master-clock-coupled video stalls, dual-clock-domain drift, tinning artifacts from a second SRC stage. Contrarian solve: don't drag video audio out of AVPlayer — apply DSP in-place inside the same `MTAudioProcessingTap` so AVPlayer's native pipeline plays the modified buffer. No ring, no engine clock for video, no master-clock coupling. Full strategic decision in `tasks/_context/s3-2-pivot.md`.

**Step 1 — Mechanical pivot ✅ DONE 2026-05-01.** Branch + cherry-pick + scaffold. 72/72 tests with TSan.

**Step 2 — Research ✅ DONE 2026-05-01 (Oracle 10/10 after 5 rounds).** Commits `4a80bf9` → `46bb6af`. Phase 0 spike empirically confirmed in-place tap DSP works (audible -20 dB attenuation A/B vs control on macOS 15+ Swift 6.2). Apple SDK header documents the contract verbatim. Full research package: `research.md` + 5 `research-notes/*.md` + 17-row Evidence Ledger + Tap Lifecycle Contract + Concurrency Decision Record + Tooling Constraints.

**Step 3 — Plan ✅ DONE 2026-05-02 (Oracle 9.8/10 after 5 rounds).** Commits `1ae8e80` → `fdce0ed`. The 0.2 below 10 reflects added scope from ADR-3a (Containment of `@unchecked Sendable` drift) added at user request 2026-05-02 with three durable gates: header contract block + `RenderThreadSafe` marker protocol + DEBUG Mirror+source-level reflection tests. User signed off 2026-05-02. 11+1 ADRs, 9 implementation phases, 15-gate verification matrix.

**Phase 1 — `VisualizerFeed` + `VisualizerScratchBuffers` extraction ✅ DONE 2026-05-02.** Commit `146a8b4`. Two private nested types in `VisualizerPipeline.swift` promoted to module-internal across new files (`VisualizerFeed.swift` ~110 LOC + `VisualizerScratchBuffers.swift` ~195 LOC, latter includes `GoertzelCoefficients` as cohesive unit). 5 type renames + 5 field renames in `VisualizerPipeline.swift` (661 → 378 lines). Engine path byte-for-byte identical. 72/72 tests TSan green.

**Phase 2 — production tap scaffold + ADR-3a containment + Oracle-driven Option C revision ✅ DONE 2026-05-02.** Initial commit `ac7e0d5` then 18 revisions across 7 Oracle review rounds (final 9.0/10 APPROVED). Final architecture: `audioMix` is configured during `AVPlayerItem` CONSTRUCTION (before `AVPlayer` adopts the item) via `VideoTap.buildAudioMix(audioTrack:context:)` (sync) + `VideoPlaybackController.loadVideo` (async, takes `audioMixBuilder` + `isStillRelevant` parameters + identity-guarded observers + seek state matrix) + `AudioPlayer.startVideoLoad(track:)` (private orchestrator with generation counter that short-circuits superseded loads BEFORE any AVPlayer/observer mutation; gates auto-play on `playbackState == .playing` so user pause-during-load is honoured). New files: `RenderThreadSafe.swift`, `VideoDSP/VideoTapContext.swift`, `VideoDSP/VideoTap.swift`, `VideoDSP/BiquadCoefficientSet.swift` (empty stub), `Tests/VideoTapSendableContractTests.swift` (Gate 3a Mirror + Gate 3b regex), `Tests/VideoTapLifecycleTests.swift` (6 lifecycle + race tests), `Tests/VideoSeekStateMatrixTests.swift` (5 seek state matrix tests). `AudioPlayer.swift` + `VideoPlaybackController.swift` modified. Pass-through DSP only. **85/85 TSan green** (72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix). **Four plan deviations** documented in task `placeholder.md` P-1/P-2/P-3/P-4 + `state.md` "Phase 2 implementation findings": (1) `RenderThreadSafe: ~Copyable`; (2) Mirror reflection gap on `~Copyable`; (3) `@preconcurrency import AVFoundation`; (4) ADR-4 install method withdrawn at Phase 2 close — **RESOLVED in Phase 3** (ADR-4 amendment #2: `Mutex<BiquadCoefficientSet?>` + `withLockIfAvailable`). *(This Phase-2 snapshot is historical; current state is Phases 1-7 ✅ + Phase 8 automated gates ✅ / **Phase 9 NEXT**, with Phase 8's hardware-manual gates being run by the user from 2026-09-05 — see Active Work Queue + First Action. The Phase 2 close count above is recorded as 85/85 here and in `_context/s3-2-pivot.md` but as 74/74 in the task todo — 74/74 vs 85/85 discrepancy, open item for Phase 9 pre-PR Oracle.)*

**Phase 3 (`BiquadCascade` + balance + numerical match) ✅ DONE 2026-05-28.** P-4 resolved (ADR-4 amendment #2: `Mutex<BiquadCoefficientSet?>` + render `withLockIfAvailable`, Oracle 9.0 APPROVED). Real `BiquadCoefficientSet`+RBJ `compute`, `BiquadCascade` (DF2II, render-confined `let` field on Context, denormal flush), Context Mutex refactor, `tapProcess` steps 2-6, `EqualizerState` + `VideoTap.balanceGains` ([-1,1]/0.0). 93/93 TSan, no races; `BiquadNumericalMatchTests` ≤0.5 dB vs `AVAudioUnitEQ`. Code Oracle-reviewed across 4 rounds: 7 → 8.5 → 9.1 → **9.6/10 APPROVED** (balance convention aligned, EQ-off reset, fail-closed compute for Nyquist/non-finite, maxChannels 16, shared freq constant, render-confinement test). Commits `37f9edc`→`24f8a12`→`4feec43`→`84b9964`→`e2eba05`→`ddd0431`.

**Phase 4 (visualizer DSP, ADR-6 dual-producer) ✅ DONE 2026-05-28.** `videoTapVisualizerRender` (AudioBufferList → shared `VisualizerFeed`; RMS/Goertzel duplicated per ADR-6, FFT shared); `VideoTapContext` gained `feed`(injected)/`scratch`(owned); `tapProcess` step 7. Consumer wired for video — `VisualizerPipeline.start/stopVideoVisualization` poll timer + `AudioPlayer.isVisualizerRendering` ungating across spectrum/Butterchurn/oscilloscope (incl. the bar-height floor); lifecycle across video start/switch/stop/completion/repeat-one. **The playlist-window mini-visualizer (shown when the main window is shaded) reuses the SAME `VisualizerView()` + shared `AudioPlayer` as the main window — no separate path, so all gating flows to both windows.** 98/98 TSan; Oracle 6→8→9.0→**9.6 APPROVED**. Commits `92d0079`→`2884033`→`d475374`→`1634dbd`→`1db11cb` (docs)→`ea95f10` (bar-floor + dual-window verification).

**Phase 5 (EQ + balance state fanout, ADR-5) ✅ DONE 2026-05-28.** Two canonical owners: `EqualizerController` fans EQ (didSet → compute+`installCoefficients` + isEqOn/preamp atomics), `AudioPlayer` fans balance ([-1,1] bit-pattern) to registered video-tap Contexts (shared `WeakBox` registries; register in `startVideoLoad`, unregister in `pauseAndDetachVideoTapIfNeeded`); sample-rate poll via `VisualizerPipeline.onPollTick` → `pollVideoTapSampleRates`. **Audible EQ-on-video now LIVE** (deferred todo 3.17 → 5.16). Writes ONLY Mutex/atomics — never the render-confined cascade (guarded by `cascadeIsRenderConfined`). `VideoTapFanoutTests` (5). 103/103 TSan; Oracle 9→**10/10 APPROVED**. Commits `e1f8a4e`→`252d3bc`.

**Phase 6 (deadline-miss telemetry) ✅ DONE 2026-06-26.** RT-safe `Atomic<UInt64>` counters sampled every 64th `tapProcess` callback (cached Mach timebase, prewarmed off render thread); `VideoTapDiagnostics` snapshot; pure `recordProcessingDeadline` eval seam; NO render-thread logging. Fixed a real `tapPrepare` store-ordering bug (sample rate publishes before the format-tag release-store). `VideoTapTelemetryTests` (7). 110/110 TSan; Oracle 8→**9/10 APPROVED**. Commits `82365c7`→`3fd157c`.

**Phase 7 (lifecycle + production tests) ✅ DONE 2026-06-26.** `VideoTapLifecycleTests` 6→11: rapid-cycle leak, injected create-failure (`_testForceTapCreateFailure` seam, ADR-10), attach+drop finalize, pause/resume Context-survival, replaceCurrentItem(nil) release. 115/115 TSan; Oracle 8→**9/10 APPROVED**. Signed-bundle smoke (7.9/7.10) READY FOR USER. Commits `b443369`→`7f50c2c`.

**Phase 8 (verification matrix) — AUTOMATED GATES ✅ DONE 2026-06-27; hardware-manual gates 🔄 IN PROGRESS WITH THE USER from 2026-09-05.** Automated: 8.1 CPU **Debug (`-Onone`) regression guard** (`VideoTapCPUBenchmarkTests` — dense per-iteration with pristine-input refresh; worst-case DSP core p99 ≈11% / max ≈13% of the 21,333 µs deadline, i.e. it fits the audio deadline with margin even unoptimized) — a regression net, **NOT** the production figure; 8.3 numerical EQ ≤0.5 dB re-run (`BiquadNumericalMatchTests` ×7); 8.4 TSan **116/116**, no races; 8.15 lifecycle (covered by Phase 7's 11 tests); 8.16 `verification.md` created. Oracle 7/10 → benchmark-methodology + honesty fixes applied (`944795a`); **no post-fix re-score recorded, so Phase 8 has no APPROVED Oracle number.** **The real production CPU gate is 8.1b (Release build + Instruments Time Profiler, `tapProcess` 99p ≤10%) and is UNVERIFIED.** Remaining hardware-manual gates — 8.1b, 8.2 (Intel), 8.5-8.14, 8.5b-8.5e, plus Phase 7's 7.9/7.10 signed-bundle smoke — are written up with pass criteria in `tasks/avplayer-native-video-dsp/verification.md` for the user to run and record. Commits `2c410a0`→`944795a`→`056c69a`.

**Remaining work (per plan.md §6):**
- Phase 8 (IN THE USER'S HANDS, execution started 2026-09-05): only the hardware-manual gates remain — 8.1b Release/Instruments `tapProcess` 99p ≤10% (the REAL CPU gate, still UNVERIFIED), 8.2 Intel, 8.5-8.14 (long-playback drift, AirPods/AirPlay/system-output/BT-codec route changes, surround, item replacement), 8.5b-8.5e (live EQ/balance stress, seek, visualizer-mode switch, telemetry readout), plus Phase 7's 7.9/7.10 signed-bundle smoke. All are written up with pass criteria in `tasks/avplayer-native-video-dsp/verification.md`; the user runs them and records results there.
- Phase 9 (NEXT for Claude — may run in parallel with the manual gates): UI integration polish + final smoke + mandatory docs (execute `docs-update-backlog.md`, incl. the mandated `docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection) + pre-PR Oracle → PR #C, opened after manual verification reports clean

See `tasks/avplayer-native-video-dsp/todo.md` for the full work-item checklist.

### 2. PAUSED-AS-REFERENCE — `tasks/video-audio-engine-routing/`

Original S3-2 attempt. Branch `feat/video-audio-engine-routing` preserved at `5af91eb` (44 commits ahead of main, pushed to origin). NOT being merged. Useful as research reference for: channel-mapping/surround-downmix logic, C-side `MTAudioProcessingTap` callback patterns, atomics-driven cross-thread state, TSan test patterns, Oracle review history (9 implementation phases, all ≥9/10), Phase 7 quality investigation findings (which informed the pivot).

The task's `state.md` carries a PAUSED-AS-REFERENCE banner pointing here.

### 3. DEFERRED — `timer-scheduled-on-common-extension`

Sub-follow-up of `timer-runloop-mode-audit` (now merged). Extract a `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift` and migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` to use it.

**Predecessor:** `timer-runloop-mode-audit` PR #81 ✅ merged 2026-04-29.
**Task folder:** not yet created (centrally tracked in `tasks/_context/state.md` "Post-S3-1A `timer-runloop-mode-audit` Follow-Ups" section).
**Risk:** `@Sendable` closure migration may surface concurrency-checker edge cases at callsites using `[weak self]` + `MainActor.assumeIsolated` — warrants per-site review.
**When to start:** any time; not blocking any S3 wave.

### 4. QUEUED (post-Structure-Sprint) — S4-1 `swift64-macos27-readiness`, then S4-2 `github-issues-triage`

Two roadmap tasks added 2026-09-05, sequenced after the post-S3 Structure Sprint (which itself starts only after S3-4 `ogg-vorbis-support` merges). **S4-1** (`tasks/swift64-macos27-readiness/`) is a research-first readiness pass for Swift 6.4 language mode + macOS 27: the machine is on Xcode 27.0 / Swift 6.4 / macOS 27.0 while the project still pins `SWIFT_VERSION` 6.2, swift-tools-version 6.2 and a macOS 15.0 deployment target — the key deliverable is a deployment-target ADR. **S4-2** (`tasks/github-issues-triage/`) triages and fixes the open user-filed issues (#84, #79, #78, #47) plus internal P-6, one Oracle-gated branch/PR each, landing in the new layout.

**Ordering — confirmed by user 2026-09-05:** the user mandated "issues after the `.swift` rearrangement" and confirmed that **S4-1 runs before S4-2** (its deprecation findings may change how the S4-2 issues get fixed). S4-1's research half touches no code and may still run opportunistically earlier. Both folders are scaffolded (5 canonical files each); no research started. Full entries: `tasks/_context/tasks_index.md` § "Post-Structure-Sprint (S4)" and `tasks/_context/state.md` § "Post-Structure-Sprint (S4) — added 2026-09-05" + decision D-S4.

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                              ←── PR #82  ✅ MERGED (b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 avplayer-native-video-dsp         ←── PR #C   🔧 IMPLEMENTING
     │       │                                                  Step 1+2+3 ✅; Phases 1-7 ✅
     │       │                                                  (P3 EQ ≤0.5dB; P4 visualizer; P5 fanout —
     │       │                                                  audible EQ live; P6 telemetry; P7 lifecycle
     │       │                                                  tests; 116/116 TSan)
     │       │                                                  Phase 8 automated ✅; manual gates 🔄 user (from 2026-09-05); Phase 9 NEXT (UI+docs+PR #C)
     │       │
     │       ▼
     │    S3-3 hls                               ←── PR #D
     │       │
     │       ▼
     │    S3-4 ogg                               ←── PR #E
     │           └── runs spike/ogg-build-wiring (0a) + spike/ogg-local-playback (0b) FIRST
     │
     └──► timer-runloop-mode-audit                ←── PR #81  ✅ MERGED (ac09dd4, 2026-04-29)
              │
              ▼
          timer-scheduled-on-common-extension    ←── PR #H   ⏸ DEFERRED
```

**Spike policy (default — do NOT deviate without explicit reason):** each Phase 0 spike runs at its parent task's pickup time on a throwaway branch, findings written to that task's `research.md`, branch deleted. S3-2's spike (`spike/avplayer-inplace-tap-dsp`) ran 2026-05-01 and is **retained locally** until S3-2 close as implementation reference.

**Post-S3:** Structure Sprint (file-move consolidation per `_context/state.md` D-STRUCTURE decision 2026-03-15). Don't start it until S3 closes.

**After the Structure Sprint:** S4-1 `swift64-macos27-readiness` (research-first), then S4-2 `github-issues-triage` — see `tasks_index.md` "Post-Structure-Sprint (S4)" and Active Work Queue item 4 above.

---

## Standard Pickup Process (apply per task)

Every S3 task — main task or spike — follows this sequence:

1. **Read `tasks/_context/state.md`** for cross-task coordination state, file-conflict matrix, and current sprint status.
2. **Read `tasks/_context/principles.md`** — the 7 decomposition principles (Problem-First, Cohesion>LOC, State Ownership, AHA Rule of Three, API Surface, No Pass-Through, ADR + Kill Switch).
3. **Read all 6 canonical files** in the task folder: `research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`.
4. **Re-read every "Files Affected" source at HEAD** to reconcile line-number drift since the plan was written. Verify the plan/todo references still match the code.
5. **Confirm `git status` is clean.** If pending changes exist, commit them as a `chore:` before continuing.
6. **Execute `todo.md` phases in order.** TSan-on builds + tests after each phase (per `feedback_xcodebuildmcp_workflow.md` memory):
   ```bash
   xcodegen generate
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   Note: TSan is per-invocation only — no session-default works (see `feedback_tsan_xcodebuildmcp_cli.md`).
7. **Use `ast-grep` (`sg --lang swift -p '<pattern>'`)** before editing setter chains, call graphs, or member-access patterns. `rg` text search alone misses duplicates and dead writes (see `feedback_ast_grep_structural_search.md`).
8. **For diagnostic work on pipelines** (producer → transport → consumer): instrument at least two stages, not just the symptom site (see `feedback_pipeline_end_to_end_diagnosis.md`).
9. **Run Codex Oracle pre-PR code-review gate** (`mcp__codex-cli__codex`, model `gpt-5.5`, `reasoningEffort: xhigh`). Apply ACTIONABLE feedback. Consider NITs case-by-case.
10. **Push + `gh pr create`.** Wait for human review before merging.
11. **Post-merge close-out** (model after the mwvi close-out commit `0358a25`):
    - Update task `state.md` to MERGED with PR link + merge commit.
    - `git mv tasks/<task>/ tasks/done/<task>/` (preserves history).
    - Update `tasks/_context/state.md` (Quick Reference, sprint table, follow-up section if any).
    - Update `tasks/_context/tasks_index.md`.
    - **Update this file** (`tasks/_context/resume-prompt.md`) — bump "Current State" section, advance "Active Work Queue" by removing the merged task and promoting the next task in line, update "First Action".
    - Single `chore: close out <task> (PR #X)` commit.

---

## Persistent Project Memories (auto-loaded by session start hook)

Index lives at `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/MEMORY.md`. Notable memories that apply directly to S3 work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — Symptoms manifest at the consumer; root causes often live at the producer. Instrument both ends of any data pipeline before diagnosing.
- **`feedback_ast_grep_structural_search.md`** — Use `sg --lang swift -p` for structural enumeration before edits; `rg` text search misses duplicates / dead writes / pass-through middlemen.
- **`feedback_xcodebuildmcp_workflow.md`** — Always xcodegen + XcodeBuildMCP build AND test (not just `swift build`/`test`) after adding/moving files. TSan must be passed per-invocation.
- **`feedback_sprint_workflow.md`** — Every sprint task gets Oracle review + PR for user review before merge, regardless of size.
- **`feedback_architecture_principles.md`** — The 7 decomposition principles (project-canonical at `tasks/_context/principles.md` and `.ai-shared/principles.md`).
- **`feedback_no_review_trail_in_comments.md`** — Production source comments must describe the invariant, not cite Oracle iters / ADR-IDs / PR numbers.
- **`feedback_oracle_exhaustive_pass.md`** — Run Oracle exhaustively in one pass over full files instead of iter-by-iter rounds.
- **`feedback_comment_verbosity.md`** — Default to zero comments; when needed, one short line max.

---

## Project-Specific Lessons Reference

`BUILDING_RETRO_MACOS_APPS_SKILL.md` is the canonical lessons-learned doc. Most relevant for current work:

- **Part 21 — Video/Milkdrop Window Patterns** (Pattern 3: `Task { @MainActor in }` for Timer/Observer Closures) — relevant whenever modifying timer closures.
- **Part 23 — Lesson: RunLoop Mode Discipline in Feeding Pipelines (April 2026)** — historical context for the merged `timer-runloop-mode-audit` (PR #81) and direct guidance for the deferred follow-up `timer-scheduled-on-common-extension`.

---

## First Action for the Resuming Agent

You are picking up `avplayer-native-video-dsp` after Phase 8's automated gates. Steps 1+2+3 ✅ + Phases 1-7 ✅ + **Phase 8 automated gates ✅** (8.1 Debug CPU regression guard, 8.3 EQ ≤0.5 dB, 8.4 TSan 116/116, 8.15 lifecycle, 8.16 `verification.md` — commits `2c410a0`→`056c69a`, 2026-06-27). There are two live work streams. **(a) The USER is already running the hardware-manual runbook** (started 2026-09-05, from the runbook artifact linked in "Current State"; pass criteria in `tasks/avplayer-native-video-dsp/verification.md`) — 8.1b Release/Instruments (the REAL `tapProcess` 99p ≤10% gate, still UNVERIFIED and expected to land PARTIAL at best), 8.2 Intel (NOT ABLE — no Intel Mac), 8.5-8.14 (drift, AirPods/AirPlay/system-output/BT-codec route changes, surround, item replacement — 8.11 NOT ABLE AS WRITTEN, 8.12 NOT ABLE, 8.5 conditional on a user-supplied ≥10-min clip), 8.5b-8.5e (live EQ stress, seek, visualizer switch, telemetry), 7.9/7.10 signed-bundle smoke — the user runs them and records results in that file; do not tick those boxes yourself. **(b) YOU execute Phase 9's non-PR items now, in parallel** — `todo.md` items 9.1-9.11 (video-window UI audit + the `docs-update-backlog.md` doc pass incl. the mandated "Audio Mechanism Concurrency Contract" subsection, plus 9.6b/9.6c `CLAUDE.md` and `.ai-shared/macamp/project.md`), then 9.12-9.14 (push Phase 9 commits — the branch is already on origin at `5fe8c3c` — then `gh pr create` → PR #C → human review) **only after (a) reports clean**. **The branch does not close at the end of the manual runbook:** manual gates recorded → Phase 9 (9.1-9.11) → 9.12 push → 9.13 PR #C → 9.14 human review → merge → post-merge close-out 10.1-10.8. **Never claim the CPU gate passed:** 8.1 is a synthetic Debug (`-Onone`) DSP-core regression guard, not the production figure (per todo.md 8.1 and verification.md 8.1/8.1b).

> **Phases 3-7 ✅ DONE; Phase 8's automated gates ✅ DONE.** Phase 3 (Oracle 9.6): BiquadCascade ≤0.5 dB. Phase 4 (Oracle 9.6): video-tap visualizer (ADR-6). Phase 5 (Oracle 10): EQ + balance fanout; audible EQ-on-video LIVE. Phase 6 (Oracle 9): deadline-miss telemetry. Phase 7 (Oracle 9): lifecycle tests (`VideoTapLifecycleTests` ×11). Phase 8 (Oracle 7 → fixes applied, no post-fix re-score): automated gates 8.1/8.3/8.4/8.15 + `verification.md`. 116/116 TSan.

### Pickup checklist

1. **Switch to the work branch:**
   ```bash
   git checkout feat/avplayer-native-video-dsp
   git status   # expect one untracked file: macamp-converstion-1.md (674 KB historical terminal transcript, not referenced by any task file — ask the user before committing or deleting it). Otherwise clean; run `git log -1 --oneline` for the actual HEAD
   ```

2. **Read these files in order** (they describe the architecture, the contract, and the work):
   - `tasks/_context/s3-2-pivot.md` — strategic decision log (3 steps + phase ownership)
   - `tasks/avplayer-native-video-dsp/state.md` — current status + dual-architecture topology + Phase 2 implementation findings (the 4 deviations forced by Swift 6 / Oracle review). Its stale tails ("Phase 6 NEXT", the tracker table's "Phase 1 + 2 done; Phase 3 NEXT", "placeholder.md — Empty") were cleared in the 2026-09-05 sweep — banner, tracker table and placeholder row all read current. The "103/103" (line 80) and "85/85" (line 51) that remain are DATED snapshots, each annotated with the HEAD figure (116/116); the 85/85 also carries the 74/74-vs-85/85 discrepancy left open for the Phase 9 pre-PR Oracle.
   - `tasks/avplayer-native-video-dsp/verification.md` — the Phase 8 gate matrix: automated results (8.1/8.3/8.4/8.15) plus the hardware-manual checklist the USER fills in.
   - `tasks/avplayer-native-video-dsp/phase2-walkthrough.md` — Phase 2 closure summary (code paths overview, new files, EQ rationale, test count, architecture extraction status, why Oracle scored 9.0 not 10.0). **Read this first if you skipped the Phase 2 conversation.**
   - `tasks/avplayer-native-video-dsp/placeholder.md` — open: **P-2** (Mirror `~Copyable` gap), **P-3** (`@preconcurrency import AVFoundation`), **P-6** (video→audio no auto-play, non-blocking). CLOSED: P-1, **P-4 (coefficient hand-off resolved — Mutex)**, P-5.
   - `tasks/avplayer-native-video-dsp/research.md` — full Step 2 synthesis (Oracle 10/10), Evidence Ledger, Architecture diagram, Reuse policy, Tap Lifecycle Contract, Concurrency Decision Record, Tooling Constraints
   - `tasks/avplayer-native-video-dsp/research-notes/spike-findings.md` — Phase 0 empirical confirmation + 6-item production-translation hazards checklist
   - `tasks/avplayer-native-video-dsp/plan.md` — full 9-phase plan, 11+1 ADRs, especially **ADR-3 + ADR-3a** (concurrency contract + `@unchecked Sendable` containment), **ADR-4 + amendments #1/#2** (A/B-swap withdrawn → `Mutex<BiquadCoefficientSet?>` + render `withLockIfAvailable`, RESOLVED + Oracle-approved), **ADR-6** (visualizer dual-producer — the Phase 4 contract), **ADR-7 + amendment** (audioMix-on-construction), ADR-8 (RBJ formulas), ADR-9 (filter reset on seek), ADR-10 (release-on-fail), ADR-11 (ASBD format guard)
   - `tasks/avplayer-native-video-dsp/todo.md` — **Phase 9 work-item checklist (9.1-9.14) is the active work.** Phases 1-7 plus Phase 8's automated items (8.1, 8.3, 8.4, 8.15, 8.16, 8.18) are `[x]`; 8.2, 8.5-8.14 and the standing rule 8.17 stay `[ ]` because they are user-owned hardware gates, and 9.12 (push) is a stale unchecked box — the branch is already pushed to origin at `5fe8c3c` (2026-09-05 docs sync; code unchanged since `944795a`). Also `verification.md` (the user's checklist), `docs-update-backlog.md` (the Phase 9 doc work) + `placeholder.md` (P-2/P-3/P-6 open). Its header banner reads current since the 2026-09-05 sweep (Phases 1-7 ✅; Phase 8 automated ✅, manual 🔄 in progress with the user; Phase 9 NEXT).
   - `tasks/avplayer-native-video-dsp/research-notes/saved-branch-retrospective.md` — ALLOWLIST/DENYLIST scoping for what to study from the saved engine-routing branch (file:line citations)

3. **Re-read at HEAD** the files/areas Phase 9 (UI polish + mandatory docs) touches:
   - `MacAmpApp/Windows/WinampVideoWindowController.swift`, `MacAmpApp/Views/WinampVideoWindow.swift`, `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` — the 9.1-9.3 UI audit. Expected minimal: the video window already shares EQ + balance through `AppSettings` / `EqualizerController` / `AudioPlayer`.
   - `docs/MACAMP_ARCHITECTURE_GUIDE.md`, `docs/IMPLEMENTATION_PATTERNS.md`, `docs/VIDEO_WINDOW.md`, `docs/MILKDROP_WINDOW.md`, `docs/README.md` — the 9.4-9.6 doc pass. Three claims in them are flatly FALSE at HEAD and are the top-priority fixes: ARCHITECTURE_GUIDE ~2662 (Butterchurn "returns nil during video playback"), ~3892 (video "shares audio session with main playback engine"), VIDEO_WINDOW ~319-323 ("EQ not available for video playback"). `docs-update-backlog.md` line numbers were captured at `9bce090` and have drifted — re-verify every one at edit time.
   - `docs/RELEASE_BUILD_GUIDE.md` — for the user's signed-bundle / Instruments runs (7.9/7.10 + 8.1b).
   - `tasks/avplayer-native-video-dsp/verification.md` — the user's hardware-manual checklist; read it, don't fill it in. Engine path stays UNTOUCHED.

4. **Spike code reference** (kept locally, throwaway branch — Phase 2 production tap is the spike's pattern HARDENED; do not regress to the spike's shortcuts):
   ```bash
   git show spike/avplayer-inplace-tap-dsp:spikes/avplayer-inplace-tap-dsp/Sources/InPlaceTapSpike/main.swift
   ```

5. **Saved-branch reference** (paused-as-reference, NOT for cherry-picking):
   ```bash
   git show feat/video-audio-engine-routing:MacAmpApp/Audio/VideoAudioTap.swift
   ```
   Read with the ALLOWLIST/DENYLIST in `research-notes/saved-branch-retrospective.md` open. C-callback shape, `Unmanaged` lifetime, ASBD inspection, surround-channel layout knowledge are reusable as patterns. Ring buffer, AudioConverter, watchdog, HAL listener, fallback flag, `swift-atomics` are explicitly NOT carried forward.

6. **Then execute Phase 9** (UI integration polish + mandatory docs) per `todo.md` items 9.1-9.11 + plan.md §6 Phase 9. Essentials:
   - 9.1-9.3: audit the video-window UI surfaces for EQ / balance / visualizer-mode wiring; add menu items only where a real gap shows (those controls are already shared with the main window).
   - 9.4-9.6: execute `docs-update-backlog.md` — the per-doc, line-referenced backlog from the 5-agent full-file audit — including the MANDATED `docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection and the removal of the three false "video has no EQ / no PCM tap" claims. Re-verify every cited line number at HEAD first.
   - 9.7-9.8: end-to-end smoke (video + EQ drag + balance + visualizer-mode switch) and a full TSan-on suite run (expect 116/116).
   - 9.9-9.11: pre-PR Codex Oracle review over the UI + doc diffs, apply ACTIONABLE feedback, commit `chore(s3-2): Phase 9 — UI polish + docs`.
   - Do NOT run or tick the `verification.md` hardware gates (8.1b, 8.2, 8.5-8.14, 8.5b-8.5e, 7.9/7.10) — those belong to the user.

7. **Then 9.12-9.14, once the user's manual gates report clean:** the branch is already pushed to origin at `5fe8c3c`, so 9.12 is just `git push` for the new Phase 9 commits → `gh pr create` (PR #C, describing the 5-round research + 5-round plan + 9-phase implementation) → wait for human review. Mark Phase 9 todos `[x]`; update this file's "Current State" + "Active Work Queue" to Phase 9 done / PR #C open.

### Critical reminders

- **Engine path must remain byte-for-byte identical.** Phase 1 verified this for the visualizer extraction. Do NOT modify the engine audio path or the engine-side `makeTapHandler`; Phase 4 ADDED a parallel video-tap visualizer producer (ADR-6); it did not change the engine one.
- **Coefficient hand-off is settled (P-4 resolved, ADR-4 amendment #2).** `VideoTapContext.coefficients: Mutex<BiquadCoefficientSet?>`; main writes via `installCoefficients` (`withLock`), render reads via `withLockIfAvailable` (three-case double-optional) into the render-owned `BiquadCascade` cache. **EQ state is pushed via `installCoefficients` + the `isEqOn`/`preamp`/`balance` atomics (landed in Phase 5) — NEVER touch `.cascade`** (render-confined; a contract test, `cascadeIsRenderConfined`, fails the build if `.cascade` is referenced outside `VideoTapContext.swift`/`VideoTap.swift`).
- **`audioMix` is configured during AVPlayerItem CONSTRUCTION** (per ADR-7 amendment). Never assign `audioMix` to an existing `AVPlayerItem` in production code paths. See `VideoPlaybackController.loadVideo` (audioMixBuilder + isStillRelevant) + `AudioPlayer.startVideoLoad` (generation counter + in-flight Task handle).
- **No `swift-atomics` `ManagedAtomic`.** Use `Synchronization.Atomic<T>` (Swift 6 stdlib, macOS 15+) per ADR-3.
- **`@unchecked Sendable` on Context is contained by the Gate-1 header contract.** Every stored field is `Atomic<T>`, `Mutex<T>`, or a `RenderThreadSafe` conformer (`cascade: BiquadCascade`, render-confined). Adding a field requires extending the header contract + adding a `RenderThreadSafe` conformance in `RenderThreadSafe.swift`. Gate 3a (Mirror) + 3b (var-regex) + 3c (`.cascade` confinement) tests enforce it.
- **Float not `AtomicRepresentable`.** Use `Atomic<UInt32>` storing `Float.bitPattern`.
- **Balance is `[-1, 1]`, center `0.0`** — same convention as `AudioPlayer.balance` / `AVAudioNode.pan` (Phase 5 writes through it). `VideoTap.balanceGains` clamps.
- **One tap per `AVPlayerItem`.** Per ADR-7. AVPlayerItem replacement → new tap; never reuse.
- **`MTAudioProcessingTapCallbacks.init` parameter:** label is `init:` (no backticks).
- **`MTAudioProcessingTapCreate` last parameter:** Swift bridges as `MTAudioProcessingTap?` (NOT `Unmanaged<MTAudioProcessingTap>?`). **`MTAudioProcessingTapFlags` is a `UInt32` typealias, not an OptionSet** — use bitwise `&` with `kMTAudioProcessingTapFlag_StartOfStream`.
- **TSan after every phase boundary.** Per project convention.
- **No `// TODO` in production code.** Stubs go in `placeholder.md`. Current open: **P-2** (Mirror `~Copyable` gap), **P-3** (`@preconcurrency import AVFoundation`), **P-6** (video→audio no auto-play, non-blocking). P-1/P-4/P-5 are CLOSED.
- **Manual smoke (todo 2.39) ✅ DONE 2026-05-02** — 5 clapperboard clips; fixed P-5 display regression (`c040e76`).
- **Leak check (todo 2.40) ✅ DONE 2026-05-28** — via Xcode Memory Graph Debugger (NOT Allocations — pure-Swift classes don't show by name there; MGD does). `VideoTapContext` + coefficient buffers 1→0 across clip load→teardown; no leak. Workflow: `tasks/_context/instruments-allocations-workflow.md`.
- **Audible EQ-on-video smoke ✅ DELIVERED + USER-VERIFIED in Phase 5** (was the deferred todo 3.17; todo 5.16/5.17 user-verified 2026-05-28) — moving an EQ slider / balance during video changes the audio in real time; EQ on a music file is unchanged (engine regression clean).
- **Toolchain (Xcode 27 / Swift 6.4):** the dev machine is on Xcode 27. The branch is warning-clean and TSan-green under it (ZIPFoundation must stay ≥0.9.20 — 0.9.19 crashes TSan at skin load).

### Phase 9 — the active Claude work (Phase 8's manual gates run in parallel, user-owned)

Phase 9 (the LAST phase) is UI integration polish + final smoke + mandatory docs (execute `tasks/avplayer-native-video-dsp/docs-update-backlog.md` — the detailed per-doc, line-referenced backlog from the 5-agent full-file audit, incl. the mandated `docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection) + pre-PR Oracle review → **`gh pr create` → PR #C → human review → merge to main.** Then S3-3 (hls) branches fresh from the new main.

### Optional sub-track

`timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
