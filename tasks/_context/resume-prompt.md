# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" + "First Action" sections after each phase completion or PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each phase completion or PR merge)

> ✅ **S3-2 CLOSED — `avplayer-native-video-dsp` MERGED 2026-09-25 as [PR #89](https://github.com/hfyeomans/MacAmp/pull/89) (merge commit `ae15f5c`).** The engine-routing attempt `feat/video-audio-engine-routing` stays **PAUSED-AS-REFERENCE** (`5af91eb`, pushed). Task folder: `tasks/done/avplayer-native-video-dsp/`; decision log `tasks/_context/s3-2-pivot.md` (now RESOLVED). **Next: S3-3 `hls-streaming-support`.** The dated S3-2 runbook history below is kept for reference only.

### 2026-09-05 → 2026-09-25 — manual runbook (✅ COMPLETE 2026-09-25)

The user started executing the Phase 8 hardware-manual gates on 2026-09-05.

- **Runbook artifact (per-gate PASS / PARTIAL / FAIL / NOT ABLE + notes, saved in the page):** https://claude.ai/code/artifact/1b5d48d1-5b5c-49ff-bff0-eb23beb8caf8 — `verification.md` remains the record of truth and is transcribed at the end.
- **Sprint ledger artifact (inventory + flow diagram):** https://claude.ai/code/artifact/4556b46a-1863-4be5-8986-3b1702624a60
- **LLDB / telemetry readout decision:** the LLDB path is the xcodebuildmcp CLI debugging workflow (`xcodebuildmcp debugging attach --pid <pid> --make-current`, `lldb-command --command "…"`, `continue`, `detach`). Attach needs `com.apple.security.get-task-allow` — Debug has it, the Developer-ID Release app does not. **RELEASE FIRST:** run 7.9 (signed smoke) + 8.1b (Time Profiler) on the Release build, then re-sign that same app with `get-task-allow` (Apple Development identity `A5V7U473GS`) for the 8.5e read (breakpoint `EqualizerController.swift:106` in `pollVideoTapSampleRates`, `po context.diagnosticSnapshot`; if the optimised frame hides `context`, `po self.registeredVideoTapContexts.compactMap { $0.value }.map { $0.diagnosticSnapshot }`); **DEBUG FALLBACK** if attach or the expression fails. Instruments Allocations (7.10 thorough path) is Debug-only regardless; `xcrun heap` works on any get-task-allow build. Record which build produced the 8.5e numbers.
- **Xcode MCP conclusion (final — the user reconnected it via `/mcp` on 2026-09-05):** it **IS an LLDB path** — `RunProject` (attachDebugger) + `InvokeDebuggerCommand` + `GetConsoleOutput` + `StopProject` (47 tools in all). An Xcode Run injects `get-task-allow` at build time, so the 8.5e read on a Release build needs **no re-sign**: switch the scheme's Run action to Release in Edit Scheme (the generated scheme runs Debug, profiles Release), then Claude drives the run / breakpoint / `po` — **PATH A** in the runbook; leave the scheme at Debug for the fallback. `xcodebuildmcp debugging attach --pid` is **PATH B** (re-sign needed for the Developer-ID app) and xcodebuildmcp remains the build/test tool. Both toolchains are usable from Claude's session.
- **NOT ABLE TO COMPLETE dispositions:** 8.2 Intel CPU benchmark (no Intel Mac; identical scalar DSP, Apple Silicon result is the primary gate); 8.12 mid-playback format re-prepare (no in-app trigger — no audio-track picker, `audioMix` set once per item per ADR-7; optional gate, skip sanctioned); 8.11 BT AAC↔SBC codec switch NOT ABLE AS WRITTEN (no supported renegotiation trigger on macOS 15/27 — device substitution is a PARTIAL at best). 8.5 long-playback drift is CONDITIONAL on a user-supplied ≥10-minute lip-sync video (in-repo clips are 3.000 s; looping resets drift). 8.6-8.9 are hardware-dependent (AirPods 1st gen, AirPods Pro, AirPlay-1, AirPlay-2) — anything unsourceable is recorded NOT ABLE with its reason.
- **Pickup after terminal restart (2026-09-06) — permissions VERIFIED WORKING:** the user granted the terminal app (cmux) **Accessibility** (keystroke synthesis via `osascript`/System Events now succeeds) and **Screen Recording** (`screencapture -x` now produces a real 3840×1600 image), so Claude can click/type in MacAmp (load clips via the ADD panel, open windows, cycle repeat) and take screenshots (visualizer animating / not pinned, video window state). Still missing and optional: `brew install switchaudio-osx` (would let Claude perform the 8.10 output switch) and `blueutil` (BT connect/disconnect). **Execution plan agreed:** Phase A — Claude alone (steps 1, 2, 3, 4 + dry-run of 5–7 mechanics, results prefilled in the runbook page); Phase B — live together ~40 min (step 1 listen; steps 5–7 Claude drives / user listens; steps 8–10 user does the hardware action on cue / Claude measures via telemetry / user confirms by ear; step 11 only with an SBC-only device); Phase C — mostly async (step 12 user supplies the ≥10-min video, Claude runs it, user checks lip-sync at 0:30/2:00/5:00/10:00; step 14 Claude transcribes/commits/pushes; then Phase 9). The runbook artifact carries CLAUDE / YOU labels and a "Who" line per step, plus a "How we run this" section. **Ownership split agreed 2026-09-06:** Claude drives every mechanical step under PATH A (Xcode MCP `RunProject` + `InvokeDebuggerCommand`): at a breakpoint in `AudioPlayer`/`EqualizerController` the app's own API is callable from LLDB — `playTrack(track:)`, `play()`, `pause()`, `stop()`, `seek(to:resume:)`, `balance`, `playlistController.addTrack(_:)`/`clear()`, `equalizer.setEqBand(index:value:)`/`setPreamp(value:)`/`isEqOn`, `AppSettings.visualizerMode`/`repeatMode`/`showVideoWindow`/`showMilkdropWindow` (all confirmed in source; `AudioPlayer.equalizer` is `private let` — LLDB reaches it). Claude-owned outright: step 2 (8.1b `xctrace record` + `xctrace export` → `tapProcess` share), step 3 (8.5e telemetry, two reads), step 4 (7.10 heap census + Allocations export on Debug), step 14 (transcribe + commit). "Claude drives, user judges": steps 5–10 and 12 (Claude runs the stress/replacement/surround/route/drift mechanics and gathers objective proxies — `processCallCount`/`isActive` resuming after a route change, `isEqOn` + coefficients intact — while the user supplies the ears/eyes verdicts and the hardware actions: ADD-loading clips into the Developer-ID app, System Settings output switch, AirPods/AirPlay connect/disconnect, the ≥10-min video, lip-sync). Neither: 8.11 (as written), 8.12, 8.2. **Next action:** user sets Xcode → Edit Scheme → Run → Build Configuration → Release and says "go"; Claude re-runs `XcodeListWindows` (the tab id was `windowtab1` — may change after restart), reconnects Xcode MCP via `/mcp` if it shows CONNECTION_CLOSED, then executes steps 2 → 3 → 4 first while the user prepares hardware. MacAmp has no open-file handler (issue #79), so without Accessibility the user loads clips via the playlist ADD button; with the debugger attached Claude adds them via `playlistController.addTrack`.
- **2026-09-07 — Phase A EXECUTED (Claude solo, via Xcode MCP PATH A on the signed Release build; no re-sign needed):** every objective gate that does not need ears or hardware is now measured and recorded in `verification.md` + the runbook artifact.
  - **7.9 objective ✅:** Developer-ID Release built into `build/ReleaseProfile` (arm64, `-O`); `codesign --verify --strict` exit 0; authority *Developer ID Application (AC3LGVEJJ8)* → Developer ID CA → Apple Root CA; **`get-task-allow` ABSENT** — note the trap: plain `xcodebuild build` injects get-task-allow even for Release, so add `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`; entitlements byte-identical to notarized `dist/`; launches. (EQ-audible-on-video = Phase B ear.)
  - **8.1b proxy PASS (PARTIAL) ✅:** Time Profiler `xctrace` ×3×60 s on the Xcode Release run. The tap runs on its own **`AQProcessingTapManager`** thread (not a MediaToolbox render thread), so report absolute cost: `tapProcess` = **0.40 % (44.1k) / 0.45 % (48k) / 1.04 % (5.1) of one core** ≈ 0.4–1.0 % of the 4096-frame callback budget — far under 10 %. Literal 99p not producible (1 ms sampler); paired with the 8.5e counters.
  - **8.5e PASS ✅:** two LLDB reads 7 min apart — processCallCount 1402→4947→6468, frames→26.5 M, **budgetOverrunCount 0, deadlineRiskCount 0, isActive true throughout**, pendingSampleRate 48000.
  - **7.10 PASS ✅:** `xcrun heap` on the get-task-allow Release run — 1 live `VideoTapContext` while playing after ~7 videos (no accumulation), **0 after `stop()`+`clear()`**. Leak-free.
  - **8.5b/8.5c/8.5d/8.13/8.14 mechanical PARTIAL ✅:** 85 s LLDB stress (band/preamp/balance sweeps, 10 EQ toggles, 60 seeks, visualizer cycle, Milkdrop toggles) + 5 video↔audio replacement cycles — no crash, tap active, counters 0/0, state restored, 0 live context after stop. Audible/eye halves = Phase B.
  - **LLDB technique for the `-O` build (reuse next time):** static accessors (`PlaylistWindowActions.shared`, `AppSettings.instance()`) and the computed `diagnosticSnapshot` getter are stripped → "Couldn't look up symbols". Working seam: `Cmd+O` → breakpoint `AppCommands.presentOpenPanel` (AppCommands.swift:98) → `frame select 1` (the closure frame evaluates; frame 0's `panel` is optimised out) → `unsafeBitCast(<addr>, to: <Type>.self)` on addresses read once via `frame variable self.playbackCoordinator.audioPlayer…` → `thread return` → `continue`. For repeated stops use the 30 Hz **`pollVideoTapSampleRates`** breakpoint (EqualizerController.swift:102) which fires during video playback and lands in a MacAmp frame. Counters via `…registeredVideoTapContexts[0].value!.<counter>.load(ordering:.relaxed)` after `expr -l swift -- import Synchronization`. Generated-project edits needed for PATH A (all gitignored, wiped by `xcodegen generate`): xcscheme LaunchAction Debug→Release; pbxproj Release identity Developer-ID→Apple Development (automatic-signing conflict under an Xcode Run); remove the pbxproj Release `CONFIGURATION_BUILD_DIR=$(PROJECT_DIR)/dist` line (Xcode's own Release run writes into `dist/` then fails on SwiftPM module lookup) — `dist/MacAmp.app` verified still valid + notarized afterwards. Project was regenerated to canonical config at the end.
  - **Observation (not a gate):** `RemoteLayerTreeDisplayLinkClient … stuck for 0.50s` main-thread warnings appeared **only while halted at LLDB breakpoints** (0.5 s cadence = debugger pauses). CoreAnimation main-thread signal, orthogonal to the tap (which stayed 0/0). If seen **without a debugger** in normal playback → real UI-perf hang (Butterchurn/Milkdrop WebView + SwiftUI at 2× showed ~9–11 s main-thread CPU/60 s) → issues-triage candidate, not an S3-2 blocker.
  - **What remains:** Phase B live (audible/eye halves of 8.5b/c/d/8.13/8.14 + 7.9; hardware 8.6–8.10 with Claude driving + measuring on cue) and Phase C (8.5 with the user's ≥10-min lip-sync video), then Phase 9 → PR #C. `brew install switchaudio-osx` would let Claude also perform the 8.10 output switch.
- **2026-09-25 — Phase B route changes + bug fix:** 8.10 ✅, 8.6 ✅ (non-Pro AirPods substitute), 8.7 ✅ live with the user. Found and fixed AVKit's competing remote-command handler (`updatesNowPlayingInfoCenter = false` in `AVPlayerViewRepresentable.swift`) — AirPod/route pauses now go through `PlaybackCoordinator`. **TSan suite is 113/116** (was 116/116; code unchanged since June): `VideoTapLifecycleTests` rapid-cycle release + `VideoTapCPUBenchmarkTests` Debug deadline **block PR #C**; `PlaylistNavigationTests` stream handoff fails on `main` too (pre-existing). **Next:** root-cause the rapid-cycle release test, then the benchmark. Remaining Phase B: audible halves of 8.5b/c/d/8.13/8.14/7.9 and 8.8/8.9 (AirPlay); Phase C: 8.5. Live-debug notes: in this session the Xcode IDE MCP is reached through XcodeBuildMCP `xcode_ide_call_tool` (RunProject / InvokeDebuggerCommand); its captured output is unreliable when a command resumes the process, so the LLDB helper writes results to a file; a breakpoint on `AudioPlayer.isVisualizerRendering.getter` (hit at 30 Hz by the visualizer timer, even when idle) gives a reliable AudioPlayer frame without keystrokes. *(Superseded later the same day — see the next bullet.)*
- **2026-09-25 (later) — Phase 8 COMPLETE.** The two regressed tests were fixed (`55d70c2`; the pre-existing failure filed as #86) — 119 tests under TSan, only #86 fails. Remaining gates PASS: 8.5 (user's 22-min video, lips in sync), 8.5b/c/d, 8.9 after the AirPlay 2 pumping fix (`922d956`, ADR-12 preferred-format tap pinned to stereo Float32 at the source rate), 8.13 (5.1 downmixed to stereo), 8.14, 7.9 (fresh Developer-ID Release of `00d5a03`), 7.10 (re-run on the new tap); 8.8 N/A (AirPlay 1 out of scope). Multichannel output deferred to S4-4 / #88. PR #87 (min macOS 27) merged and merged into the branch (`db3b851`, `00d5a03`). P-6 not observed either way in the 8.14 run. Records committed in `5125bb3`. Runbook artifact updated with all results.
- **When does this branch close? NOT directly after the manual runbook.** Sequence: manual gates recorded in `verification.md` → Phase 9 (9.1-9.3 UI audit; 9.4-9.6 + 9.6b/9.6c mandatory docs incl. `CLAUDE.md` and `.ai-shared/macamp/project.md`; 9.7 smoke; 9.8 TSan; 9.9-9.10 pre-PR Oracle; 9.11 commit) → 9.12 push → 9.13 `gh pr create` PR #C → 9.14 human review → merge → post-merge close-out 10.1-10.8 (move the task folder to `done/`, delete `spike/avplayer-inplace-tap-dsp`, advance `_context` to S3-3). The manual gates are recorded (2026-09-25), so Phase 9 is the next step. *(→ Phase 9 done and PR #89 opened 2026-09-25 — see the next bullet.)*
- **2026-09-25 (latest) — Phase 9 COMPLETE except 9.14; PR #89 opened.** 9.1-9.3 UI audit: no changes needed. 9.4-9.6c docs: video DSP documented (`9d7ef92`), docs pruned 19,340 → 8,811 lines with all links verified (`4ff7364`), `ce914c1`, `d1d89ea`; review-history tags removed from code comments (`d078e57`). Fix `0f556a8`: engine reconfigure no longer resumes the previous music track under a video after an output-format change (found by the docs review, reproduced by forcing 44.1 kHz). 9.7-9.8 checks: 119 tests under TSan, only pre-existing #86 fails. 9.9 `/codex:review --base main` (one pass) → 4 × P2; 9.10 all fixed in `e094e2e` (video preamp bypassed when EQ is off; reconfigure will-handler skips video; `pause()` during the route-change debounce keeps the pause intent; `PreReconfigureSnapshot.wasPaused` keeps stopped tracks stopped). 9.12 pushed; 9.13 [PR #89](https://github.com/hfyeomans/MacAmp/pull/89) opened (`feat/avplayer-native-video-dsp` → `main`, 96 commits ahead of `origin/main`). **Now:** 9.14 — the user reviews/merges PR #89; address review comments; then post-merge close-out 10.1-10.8.
- **2026-09-25 (close-out) — PR #89 MERGED.** The user merged [PR #89](https://github.com/hfyeomans/MacAmp/pull/89) (merge commit `ae15f5c`, 2026-09-26 03:32 UTC, 96 commits) once CI was green (Socket ×2, Snyk, Semgrep); CodeRabbit was still processing and posted no review. A late working-tree Codex P2 was fixed pre-merge in `bebfee5` (gitignore `macamp-save-*.md` / `macamp-converstion-*.md`). Close-out 10.1-10.7 done: task moved to `tasks/done/avplayer-native-video-dsp/`, `_context/` advanced to S3-3, `s3-2-pivot.md` RESOLVED. 10.3: `spike/avplayer-inplace-tap-dsp` (`dd53d64`, not in `main`) preserved on `origin` 2026-09-26; evaluate later.

**Last update:** 2026-09-25 (**post-PR-#89 merge — S3-2 `avplayer-native-video-dsp` shipped (`ae15f5c`); task closed out; S3-3 `hls-streaming-support` is next.** Prior — 2026-09-25: Phase 9 COMPLETE except 9.14 — PR #C opened as PR #89; Codex 4 × P2 fixed in `e094e2e`; reconfigure fix `0f556a8`; docs pruned. Prior — 2026-09-25: **Phase 8 COMPLETE** — Phase B/C gates run with the user; AVKit remote-command fix `e5933ad`, test-gate fixes `55d70c2`, AirPlay 2 pumping fix `922d956`, PR #87 merged in `db3b851`, `00d5a03`, records `5125bb3`; branch pushed at `5125bb3`; Phase 9 next. Prior — 2026-09-07: **Phase A objective gates executed** — 7.9/8.1b/8.5e/7.10 + mechanical axis of 8.5b/c/d/8.13/8.14 measured via Xcode MCP PATH A on the signed Release build, recorded in `verification.md` + the runbook artifact; Phase B/C remain; branch pushed to origin at `3759389`. Prior — 2026-09-05: manual runbook started; S4 ordering confirmed; pushed at `5fe8c3c`. Doc refresh to code HEAD `056c69a`, 2026-06-27 — **Phase 8 AUTOMATED gates ✅ DONE**; hardware-manual gates 🔄 being executed by the user from `verification.md`; **Phase 9 NEXT**. Prior — 2026-06-26: Phase 7 ✅ **DONE** — lifecycle + production tests. `VideoTapLifecycleTests` 6→11: rapid-cycle leak (10 build/attach/drop → all released), injected `MTAudioProcessingTapCreate` failure via the `@MainActor static var VideoTap._testForceTapCreateFailure` seam → Context released not leaked (ADR-10; seam SKIPS the real create else a real tap's `tapFinalize` double-releases), attach+immediate-drop finalize, pause/resume Context-survival, replaceCurrentItem(nil) release. **115/115 tests with TSan, no races**, stable across re-runs. Oracle 8→**9/10 APPROVED** (round 1 flagged overstated coverage → added the 7.5 pause/resume test + honest reframing of the release-vs-UAF and seek→reset claims). Signed-bundle smoke (7.9/7.10) READY FOR USER. Commits `b443369`→`7f50c2c`. **Phase 8 automated gates ✅ DONE 2026-06-27** — commits `2c410a0`→`944795a`→`056c69a`: 8.1 Debug CPU regression guard, 8.3 EQ ≤0.5 dB, 8.4 TSan **116/116**, 8.15 lifecycle, 8.16 `verification.md`; Oracle 7/10 → methodology+honesty fixes, no post-fix re-score. Hardware-manual gates (8.1b Release/Instruments — the real ≤10% CPU gate, UNVERIFIED; 8.2 Intel; 8.5-8.14; 8.5b-8.5e; 7.9/7.10) 🔄 IN PROGRESS WITH THE USER from 2026-09-05. **Phase 9 NEXT** (UI polish + docs + pre-PR Oracle + PR #C). Prior: Phase 6 deadline-miss telemetry (Oracle 9); Xcode 27/Swift 6.4 migration fixes (12 warnings + ZIPFoundation 0.9.20). Open non-blocking: P-6.)
**Main HEAD:** `ae15f5c` — Merge pull request #89 from `feat/avplayer-native-video-dsp` (2026-09-25). Local `main` fast-forwarded to `origin/main`.
**`feat/avplayer-native-video-dsp`:** ✅ merged into `main` via PR #89 (96 commits). Commit arc (Phase 1 `146a8b4` → Phase 9 `d1d89ea`, then `bebfee5`) is recorded in `tasks/done/avplayer-native-video-dsp/state.md` and `s3-2-pivot.md`.
**`spike/avplayer-inplace-tap-dsp` HEAD:** `dd53d64` — Phase 0 spike, **not in `main`**; preserved on `origin` 2026-09-26 at the user's request (`dd53d64`, not in `main`); evaluate later whether it can be deleted.
**`feat/video-audio-engine-routing` HEAD (paused-as-reference):** `5af91eb`. 44 commits ahead of main, pushed to origin.
**Tests:** **119 under TSan on `main` (PR #89 head), only the pre-existing #86 fails** (2026-09-25). At 2026-06-27: 116/116 with TSan ON (72 baseline + 3 `VideoTapSendableContractTests` (Gate 3a/3b/3c) + **11** `VideoTapLifecycleTests` + 5 `VideoSeekStateMatrixTests` + 7 `BiquadNumericalMatchTests` + 5 `VideoTapVisualizerRenderTests` + 5 `VideoTapFanoutTests` + 7 `VideoTapTelemetryTests` + **1 `VideoTapCPUBenchmarkTests`** added by Phase 8).
**PRs merged total:** 81 (highest: #89). No PRs open.

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected (these are OLD-vaer-branch artifacts, kept on main)

**Most recent task closed:** `tasks/done/avplayer-native-video-dsp/` (S3-2 pivot, PR #89, merged 2026-09-25, merge commit `ae15f5c`). In-place `MTAudioProcessingTap` DSP brings EQ + balance + visualizer/Milkdrop to local video without routing it through `AVAudioEngine`. Follow-ups tracked in `tasks/_context/state.md`: #88 → S4-4 `video-multichannel-output`; 16 macOS-27 deprecations → S4-1; P-6 (video→audio no auto-play) → S4-2; `audioplayer-seek-extraction` trigger fired (AudioPlayer 1,101 lines); `StreamDecodePipeline.DecodeContext` concurrency-contract retrofit candidate.

**Previous closeout:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`).

---

## Active Work Queue (ordered — start at the top)

### 1. NEXT — `tasks/hls-streaming-support/` (S3-3)

**Status:** ✅ READY — plan Oracle-approved 9.0/10 (2026-04-27), todo derived. Its S3-2 gate is satisfied (PR #89 merged 2026-09-25); S3-1B also merged. No Phase 0 spike.

**Scope (v1, locked):** audio-only HLS — M3U8 master + media playlists, AAC ADTS segments, live + VOD. No TS / fMP4 / LL-HLS / ABR / DRM / HLS video. New `MacAmpApp/Audio/HLS/` (`M3U8Parser`, `HLSSegmentFeeder`) feeding the existing `DecodeContext.handleIncomingData` through an injected closure; `AudioFileStreamParser.reset()`; two new `StreamTerminationReason` cases.

**Branch:** `feat/hls-streaming-support` → PR #D.
**Predecessors:** S3-1 ✅ + S3-2 ✅ (PR #89) — both merged.
**Successors:** S3-4 `ogg-vorbis-support` (rebases its plan against post-HLS HEAD; HLS plan §17.1 has the checklist).
**Caveat:** the plan predates the S3-2 merge, the macOS 27 deployment target (PR #87) and the Xcode 27 / Swift 6.4 toolchain — pre-flight PF.3-PF.5 (re-read every "Files Affected" source at HEAD) is where that drift gets reconciled. Its todo PF.2 still names the paused `video-audio-engine-routing`; S3-2 shipped as the pivot, so PF.1/PF.2 are satisfied.

**Just closed:** S3-2 `avplayer-native-video-dsp` — see `tasks/done/avplayer-native-video-dsp/` and "Current State" above. `spike/avplayer-inplace-tap-dsp` preserved on `origin` 2026-09-26 at the user's request (`dd53d64`, not in `main`); evaluate later whether it can be deleted.

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

Two roadmap tasks added 2026-09-05, sequenced after the post-S3 Structure Sprint (which itself starts only after S3-4 `ogg-vorbis-support` merges). **S4-1** (`tasks/swift64-macos27-readiness/`) was a research-first readiness pass for Swift 6.4 language mode + macOS 27; **re-scoped 2026-09-25 to adoption** — the deployment target is now macOS 27.0 (D-TARGET27, PR #87 merged), and its first item is the macOS-27 deprecations (16 on `main` since PR #89 — 14 + 2 test-only from S3-2 — deferred there by user decision 2026-09-25). The project still pins `SWIFT_VERSION` 6.2 / swift-tools-version 6.2. **S4-2** (`tasks/github-issues-triage/`) triages and fixes the open user-filed issues (#84, #79, #78, #47) plus internal P-6, one Oracle-gated branch/PR each, landing in the new layout.

**Ordering — confirmed by user 2026-09-05:** the user mandated "issues after the `.swift` rearrangement" and confirmed that **S4-1 runs before S4-2** (its deprecation findings may change how the S4-2 issues get fixed). S4-1's research half touches no code and may still run opportunistically earlier. Both folders are scaffolded (5 canonical files each); no research started. Full entries: `tasks/_context/tasks_index.md` § "Post-Structure-Sprint (S4)" and `tasks/_context/state.md` § "Post-Structure-Sprint (S4) — added 2026-09-05" + decision D-S4. **Added 2026-09-25:** S4-3 `airplay-route-picker` (roadmap row, no folder) and S4-4 `video-multichannel-output` (folder scaffolded, issue #88) — its predecessors (S3-2 PR #89 + PR #87) are now both merged, so it is unblocked; roadmap position unchanged.

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                              ←── PR #82  ✅ MERGED (b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 avplayer-native-video-dsp         ←── PR #89  ✅ MERGED (ae15f5c, 2026-09-25)
     │       │
     │       ▼
     │    S3-3 hls                               ←── PR #D   📋 NEXT (plan 9.0/10; no spike)
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

**Spike policy (default — do NOT deviate without explicit reason):** each Phase 0 spike runs at its parent task's pickup time on a throwaway branch, findings written to that task's `research.md`, branch deleted. The spike branch was pushed to `origin` 2026-09-26 to preserve it; whether to delete it (todo 10.3) is evaluated later.

**Post-S3:** Structure Sprint (file-move consolidation per `_context/state.md` D-STRUCTURE decision 2026-03-15). Don't start it until S3 closes.

**After the Structure Sprint:** S4-1 `swift64-macos27-readiness` (now an adoption task), then S4-2 `github-issues-triage`; S4-3 `airplay-route-picker` (after S4-1) and S4-4 `video-multichannel-output` (#88; predecessors S3-2 PR #89 ✅ + PR #87 ✅ — unblocked) added 2026-09-25 — see `tasks_index.md` "Post-Structure-Sprint (S4)" and Active Work Queue item 4 above.

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

Open `tasks/hls-streaming-support/` (S3-3). S3-2 `avplayer-native-video-dsp` merged 2026-09-25 as PR #89 (`ae15f5c`), which satisfies the HLS gate. Read the 6 canonical files (`research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`).

**S3-2 close-out is complete.** `spike/avplayer-inplace-tap-dsp` is preserved on `origin` 2026-09-26 at the user's request (`dd53d64`, not in `main`); evaluate later whether it can be deleted — not a blocker for S3-3.

Then follow the Standard Pickup Process above:
- Confirm `git status` is clean and `main` is at `origin/main` (most recent merge: PR #89 `avplayer-native-video-dsp`, merge commit `ae15f5c`, 2026-09-25).
- Run pre-flight PF.1-PF.5. PF.1/PF.2 are satisfied (S3-2 shipped as the pivot, not the `video-audio-engine-routing` its todo names). The plan was approved 2026-04-27 — before the S3-2 merge, the macOS 27 deployment target (PR #87) and the Xcode 27 / Swift 6.4 toolchain — so re-read every "Files Affected" source at HEAD (`Audio/Streaming/StreamDecodePipeline.swift` is 825 lines, `AudioFileStreamParser.swift`, `StreamPlayer.swift`) and reconcile line-number and API drift before Phase 1.
- Cut `feat/hls-streaming-support` from `main` and execute phases with TSan-on builds + tests after each.

Stop and report back to me before pushing the PR — I'll review before merge.

### Pickup checklist

1. **Branch from the new main:**
   ```bash
   git checkout main && git pull origin main   # expect ae15f5c or later
   git status   # one untracked local transcript dump may remain (macamp-save-sept-24-1.md; now gitignored by pattern) — ask the user before deleting it
   git checkout -b feat/hls-streaming-support
   ```
2. **Read, in order:** `tasks/hls-streaming-support/state.md` (10 key plan decisions, file inventory) → `plan.md` (1,273 lines, Oracle 9.0/10; §17.1 is the OGG rebase checklist) → `todo.md` (PF.1-PF.5, Phases 1-11, architecture constraints) → `research.md` (the Gemini section notes an optional re-run at plan time if TS/fMP4 prevalence matters).
3. **Architecture constraints from the HLS todo:** all HLS code under `MacAmpApp/Audio/HLS/`; no `private → internal` widening (closure-injection seam); no changes to `AudioPlayer.swift` / `AudioEngineController.swift` / `PlaybackCoordinator.swift`; TSan clean on every commit.
4. **S3-1B barrier API:** HLS pause integrates with `stream-pause-tail`'s `pauseByUser` / `resumeByUser` barrier (plan decision 8) — see `tasks/done/stream-pause-tail/`.
5. **Pre-PR review:** one exhaustive `/codex:review --base main` pass before opening PR #D.

### S3-2 invariants (apply if S3-3 work touches the video path)

- The engine path and the video path are separate: local audio + streams go through `AVAudioEngine`; local video gets in-place DSP inside AVPlayer's `MTAudioProcessingTap` (`Audio/VideoDSP/`). HLS audio joins the engine path; HLS video is out of scope (`MTAudioProcessingTap` does not fire reliably for streaming items).
- `audioMix` is configured during `AVPlayerItem` construction — never assign it to an existing item.
- EQ/balance reach the video tap only via `installCoefficients` + the `isEqOn`/`preamp`/`balance` atomics; never touch the render-confined `.cascade` (a contract test enforces it).
- Contract and topology are documented in `docs/MACAMP_ARCHITECTURE_GUIDE.md` ("Audio Mechanism Concurrency Contract") and `docs/VIDEO_WINDOW.md`.
- Toolchain: Xcode 27 / Swift 6.4; the build carries 16 macOS-27 deprecation warnings deferred to S4-1. ZIPFoundation must stay ≥0.9.20 (0.9.19 crashes TSan at skin load).

### Optional sub-track

`timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
