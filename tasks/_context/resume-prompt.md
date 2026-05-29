# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" + "First Action" sections after each phase completion or PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each phase completion or PR merge)

> ⚠️ **S3-2 ARCHITECTURAL PIVOT — IMPLEMENTATION IN PROGRESS (2026-05-02).** `feat/video-audio-engine-routing` is **PAUSED-AS-REFERENCE** (preserved at `5af91eb`, pushed to origin). S3-2 re-attempted as **`avplayer-native-video-dsp`** on branch `feat/avplayer-native-video-dsp`. **Steps 1+2+3 ✅ + Phases 1 + 2 + 3 + 4 + 5 ✅ done. Phase 6 (production telemetry — deadline-miss instrumentation) NEXT.** See `tasks/_context/s3-2-pivot.md` for the strategic decision log + step-by-step status — that file is authoritative.

**Last update:** 2026-05-28 (Phase 5 ✅ **DONE** — EQ + balance state fanout, ADR-5, two canonical owners. `EqualizerController` fans EQ (didSet → compute+`installCoefficients` Mutex hand-off + isEqOn/preamp atomics) and `AudioPlayer` fans balance ([-1,1] bit-pattern) to registered video-tap Contexts via shared `WeakBox` registries; register in `startVideoLoad`, unregister in `pauseAndDetachVideoTapIfNeeded`; sample-rate poll via `VisualizerPipeline.onPollTick` → `pollVideoTapSampleRates`. **Audible EQ-on-video is now LIVE** (deferred todo 3.17 delivered as todo 5.16 — moving an EQ slider / balance changes video audio in real time). **103/103 tests with TSan, no races.** Oracle 9→**10/10 APPROVED** (round-2 duplicate-path sweep clean). Commits `e1f8a4e`→`252d3bc`. Phase 4 (Oracle 9.6): video-tap visualizer (ADR-6). Phase 3 (Oracle 9.6): P-4 resolved (ADR-4 amendment #2) + BiquadCascade + RBJ compute + tapProcess, ≤0.5 dB vs AVAudioUnitEQ. **Phase 6 NEXT** (deadline-miss telemetry). Open non-blocking: P-6.)
**Main HEAD:** `9cca40a` (main has not advanced during S3-2 work).
**`feat/avplayer-native-video-dsp` HEAD:** `252d3bc` (run `git log -1 --oneline` to confirm — doc commits may have advanced it). **~62 commits ahead of main** (run `git rev-list --count main..HEAD` for the live number). Commit arc: 13 cherry-picked Phase-1 commits (ending `2aa2f18`) + pivot cleanup + scaffold → Step-2 research `4a80bf9`→`46bb6af` (Oracle 10/10) → Step-3 plan `1ae8e80`→`fdce0ed` (Oracle 9.8/10) → Phase 1 `146a8b4` → Phase 2 `ac7e0d5`→`7d3367c` (Option C, Oracle 9.0) → Phase 2 close (todo 2.40 leak check + P-6 + instruments doc) → Phase 3 `37f9edc`→`ddd0431` (P-4 resolution + BiquadCascade + tapProcess + Oracle 7→9.6) → Phase 4 `92d0079`→`ea95f10` (video-tap visualizer + consumer wiring + Oracle 6→9.6) → **Phase 5 `e1f8a4e`→`252d3bc` (EQ + balance fanout + Oracle 9→10).**
**`spike/avplayer-inplace-tap-dsp` HEAD (throwaway, retained locally):** `dd53d64` — Phase 0 spike. In-place tap DSP works on macOS 15+ / Swift 6.2.
**`feat/video-audio-engine-routing` HEAD (paused-as-reference):** `5af91eb`. 44 commits ahead of main, pushed to origin.
**Tests:** 103/103 with TSan ON (72 baseline + 3 `VideoTapSendableContractTests` (Gate 3a/3b/3c) + 6 `VideoTapLifecycleTests` + 5 `VideoSeekStateMatrixTests` + 7 `BiquadNumericalMatchTests` + 5 `VideoTapVisualizerRenderTests` + 5 `VideoTapFanoutTests`). Target by S3-2 close: ~110+ (Phase 7 additional lifecycle ~6 tests).
**PRs merged total:** 80. No PR opened on the S3-2 branch yet (single PR at S3-2 close).

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected (these are OLD-vaer-branch artifacts, kept on main)

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). See `tasks/_context/state.md` for the full S3-1B closeout summary.

---

## Active Work Queue (ordered — start at the top)

### 1. IMPLEMENTING — `tasks/avplayer-native-video-dsp/` (S3-2 PIVOT)

**Status:** Steps 1+2+3 ✅ + Phases 1 + 2 + 3 + 4 + 5 ✅ done. **Phase 6 (production telemetry — deadline-miss instrumentation) NEXT** — see `tasks/avplayer-native-video-dsp/todo.md` for the per-phase work breakdown.

**Why pivoted:** The original S3-2 (`feat/video-audio-engine-routing`) reached Phase 7 testing and revealed structural issues with the engine-routing approach: `AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes (proven by missing log line), master-clock-coupled video stalls, dual-clock-domain drift, tinning artifacts from a second SRC stage. Contrarian solve: don't drag video audio out of AVPlayer — apply DSP in-place inside the same `MTAudioProcessingTap` so AVPlayer's native pipeline plays the modified buffer. No ring, no engine clock for video, no master-clock coupling. Full strategic decision in `tasks/_context/s3-2-pivot.md`.

**Step 1 — Mechanical pivot ✅ DONE 2026-05-01.** Branch + cherry-pick + scaffold. 72/72 tests with TSan.

**Step 2 — Research ✅ DONE 2026-05-01 (Oracle 10/10 after 5 rounds).** Commits `4a80bf9` → `46bb6af`. Phase 0 spike empirically confirmed in-place tap DSP works (audible -20 dB attenuation A/B vs control on macOS 15+ Swift 6.2). Apple SDK header documents the contract verbatim. Full research package: `research.md` + 5 `research-notes/*.md` + 17-row Evidence Ledger + Tap Lifecycle Contract + Concurrency Decision Record + Tooling Constraints.

**Step 3 — Plan ✅ DONE 2026-05-02 (Oracle 9.8/10 after 5 rounds).** Commits `1ae8e80` → `fdce0ed`. The 0.2 below 10 reflects added scope from ADR-3a (Containment of `@unchecked Sendable` drift) added at user request 2026-05-02 with three durable gates: header contract block + `RenderThreadSafe` marker protocol + DEBUG Mirror+source-level reflection tests. User signed off 2026-05-02. 11+1 ADRs, 9 implementation phases, 15-gate verification matrix.

**Phase 1 — `VisualizerFeed` + `VisualizerScratchBuffers` extraction ✅ DONE 2026-05-02.** Commit `146a8b4`. Two private nested types in `VisualizerPipeline.swift` promoted to module-internal across new files (`VisualizerFeed.swift` ~110 LOC + `VisualizerScratchBuffers.swift` ~195 LOC, latter includes `GoertzelCoefficients` as cohesive unit). 5 type renames + 5 field renames in `VisualizerPipeline.swift` (661 → 378 lines). Engine path byte-for-byte identical. 72/72 tests TSan green.

**Phase 2 — production tap scaffold + ADR-3a containment + Oracle-driven Option C revision ✅ DONE 2026-05-02.** Initial commit `ac7e0d5` then 18 revisions across 7 Oracle review rounds (final 9.0/10 APPROVED). Final architecture: `audioMix` is configured during `AVPlayerItem` CONSTRUCTION (before `AVPlayer` adopts the item) via `VideoTap.buildAudioMix(audioTrack:context:)` (sync) + `VideoPlaybackController.loadVideo` (async, takes `audioMixBuilder` + `isStillRelevant` parameters + identity-guarded observers + seek state matrix) + `AudioPlayer.startVideoLoad(track:)` (private orchestrator with generation counter that short-circuits superseded loads BEFORE any AVPlayer/observer mutation; gates auto-play on `playbackState == .playing` so user pause-during-load is honoured). New files: `RenderThreadSafe.swift`, `VideoDSP/VideoTapContext.swift`, `VideoDSP/VideoTap.swift`, `VideoDSP/BiquadCoefficientSet.swift` (empty stub), `Tests/VideoTapSendableContractTests.swift` (Gate 3a Mirror + Gate 3b regex), `Tests/VideoTapLifecycleTests.swift` (6 lifecycle + race tests), `Tests/VideoSeekStateMatrixTests.swift` (5 seek state matrix tests). `AudioPlayer.swift` + `VideoPlaybackController.swift` modified. Pass-through DSP only. **85/85 TSan green** (72 baseline + 2 contract + 6 lifecycle + 5 seek-state-matrix). **Four plan deviations** documented in task `placeholder.md` P-1/P-2/P-3/P-4 + `state.md` "Phase 2 implementation findings": (1) `RenderThreadSafe: ~Copyable`; (2) Mirror reflection gap on `~Copyable`; (3) `@preconcurrency import AVFoundation`; (4) ADR-4 install method withdrawn at Phase 2 close — **RESOLVED in Phase 3** (ADR-4 amendment #2: `Mutex<BiquadCoefficientSet?>` + `withLockIfAvailable`). *(This Phase-2 snapshot is historical; current state is Phases 1-5 ✅ / Phase 6 NEXT — see Active Work Queue + First Action.)*

**Phase 3 (`BiquadCascade` + balance + numerical match) ✅ DONE 2026-05-28.** P-4 resolved (ADR-4 amendment #2: `Mutex<BiquadCoefficientSet?>` + render `withLockIfAvailable`, Oracle 9.0 APPROVED). Real `BiquadCoefficientSet`+RBJ `compute`, `BiquadCascade` (DF2II, render-confined `let` field on Context, denormal flush), Context Mutex refactor, `tapProcess` steps 2-6, `EqualizerState` + `VideoTap.balanceGains` ([-1,1]/0.0). 93/93 TSan, no races; `BiquadNumericalMatchTests` ≤0.5 dB vs `AVAudioUnitEQ`. Code Oracle-reviewed across 4 rounds: 7 → 8.5 → 9.1 → **9.6/10 APPROVED** (balance convention aligned, EQ-off reset, fail-closed compute for Nyquist/non-finite, maxChannels 16, shared freq constant, render-confinement test). Commits `37f9edc`→`24f8a12`→`4feec43`→`84b9964`→`e2eba05`→`ddd0431`.

**Phase 4 (visualizer DSP, ADR-6 dual-producer) ✅ DONE 2026-05-28.** `videoTapVisualizerRender` (AudioBufferList → shared `VisualizerFeed`; RMS/Goertzel duplicated per ADR-6, FFT shared); `VideoTapContext` gained `feed`(injected)/`scratch`(owned); `tapProcess` step 7. Consumer wired for video — `VisualizerPipeline.start/stopVideoVisualization` poll timer + `AudioPlayer.isVisualizerRendering` ungating across spectrum/Butterchurn/oscilloscope (incl. the bar-height floor); lifecycle across video start/switch/stop/completion/repeat-one. **The playlist-window mini-visualizer (shown when the main window is shaded) reuses the SAME `VisualizerView()` + shared `AudioPlayer` as the main window — no separate path, so all gating flows to both windows.** 98/98 TSan; Oracle 6→8→9.0→**9.6 APPROVED**. Commits `92d0079`→`2884033`→`d475374`→`1634dbd`→`1db11cb` (docs)→`ea95f10` (bar-floor + dual-window verification).

**Phase 5 (EQ + balance state fanout, ADR-5) ✅ DONE 2026-05-28.** Two canonical owners: `EqualizerController` fans EQ (didSet → compute+`installCoefficients` + isEqOn/preamp atomics), `AudioPlayer` fans balance ([-1,1] bit-pattern) to registered video-tap Contexts (shared `WeakBox` registries; register in `startVideoLoad`, unregister in `pauseAndDetachVideoTapIfNeeded`); sample-rate poll via `VisualizerPipeline.onPollTick` → `pollVideoTapSampleRates`. **Audible EQ-on-video now LIVE** (deferred todo 3.17 → 5.16). Writes ONLY Mutex/atomics — never the render-confined cascade (guarded by `cascadeIsRenderConfined`). `VideoTapFanoutTests` (5). 103/103 TSan; Oracle 9→**10/10 APPROVED**. Commits `e1f8a4e`→`252d3bc`.

**Remaining phases (per plan.md §6):**
- Phase 6 (NEXT): production telemetry (deadline-miss instrumentation) — tap-callback wall-clock sampling + budget-overrun/deadline-risk Atomic counters on `VideoTapContext`, for the Phase 8 CPU-benchmark gate
- Phase 7: lifecycle + production tests (TSan, signed-bundle smoke)
- Phase 8: verification matrix execution (15 gates: Static / Dynamic / Lifecycle)
- Phase 9: UI integration polish + final smoke + mandatory docs (`docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection)

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

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                              ←── PR #82  ✅ MERGED (b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 avplayer-native-video-dsp         ←── PR #C   🔧 IMPLEMENTING
     │       │                                                  Step 1+2+3 ✅; Phases 1-5 ✅
     │       │                                                  (P3: EQ DSP ≤0.5dB; P4: video visualizer;
     │       │                                                  P5: EQ/balance fanout — audible EQ live;
     │       │                                                  103/103 TSan; P5 Oracle 10/10)
     │       │                                                  Phase 6 NEXT (telemetry); 4 phases remain
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
9. **Run Codex Oracle pre-PR code-review gate** (`mcp__codex-cli__codex`, model `gpt-5.3-codex`, `reasoningEffort: xhigh`). Apply ACTIONABLE feedback. Consider NITs case-by-case.
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

You are picking up `avplayer-native-video-dsp` mid-implementation. Steps 1+2+3 ✅ + Phases 1 + 2 + 3 + 4 + 5 ✅ are done. **Phase 6 (production telemetry — deadline-miss instrumentation, per plan.md §6 Phase 6 + spike-findings hardening item 3) is the active work** — see `tasks/avplayer-native-video-dsp/todo.md` Phase 6 items. Add tap-callback wall-clock sampling + budget-overrun / deadline-risk Atomic counters on `VideoTapContext`, surfaced for the Phase 8 CPU-benchmark gate. Keep the render path allocation/lock-free; counters are `Atomic` increments.

> **Phases 3 + 4 + 5 ✅ DONE (2026-05-28).** Phase 3 (Oracle 9.6): P-4 resolved (ADR-4 amendment #2 Mutex hand-off) + `BiquadCascade` + RBJ `compute` + `tapProcess` steps 2-6; ≤0.5 dB vs `AVAudioUnitEQ`. Phase 4 (Oracle 9.6): video-tap visualizer (ADR-6). Phase 5 (Oracle 10/10): EQ + balance fanout (`EqualizerController` + `AudioPlayer` → registered Contexts via Mutex/atomics); audible EQ-on-video LIVE. 103/103 TSan. The Phase 3 detail below is retained as historical reference.

### Pickup checklist

1. **Switch to the work branch:**
   ```bash
   git checkout feat/avplayer-native-video-dsp
   git status   # should be clean; run `git log -1 --oneline` for the actual HEAD
   ```

2. **Read these files in order** (they describe the architecture, the contract, and the work):
   - `tasks/_context/s3-2-pivot.md` — strategic decision log (3 steps + phase ownership)
   - `tasks/avplayer-native-video-dsp/state.md` — current status + dual-architecture topology + Phase 2 implementation findings (the 4 deviations forced by Swift 6 / Oracle review)
   - `tasks/avplayer-native-video-dsp/phase2-walkthrough.md` — Phase 2 closure summary (code paths overview, new files, EQ rationale, test count, architecture extraction status, why Oracle scored 9.0 not 10.0). **Read this first if you skipped the Phase 2 conversation.**
   - `tasks/avplayer-native-video-dsp/placeholder.md` — open: **P-2** (Mirror `~Copyable` gap), **P-3** (`@preconcurrency import AVFoundation`), **P-6** (video→audio no auto-play, non-blocking). CLOSED: P-1, **P-4 (coefficient hand-off resolved — Mutex)**, P-5.
   - `tasks/avplayer-native-video-dsp/research.md` — full Step 2 synthesis (Oracle 10/10), Evidence Ledger, Architecture diagram, Reuse policy, Tap Lifecycle Contract, Concurrency Decision Record, Tooling Constraints
   - `tasks/avplayer-native-video-dsp/research-notes/spike-findings.md` — Phase 0 empirical confirmation + 6-item production-translation hazards checklist
   - `tasks/avplayer-native-video-dsp/plan.md` — full 9-phase plan, 11+1 ADRs, especially **ADR-3 + ADR-3a** (concurrency contract + `@unchecked Sendable` containment), **ADR-4 + amendments #1/#2** (A/B-swap withdrawn → `Mutex<BiquadCoefficientSet?>` + render `withLockIfAvailable`, RESOLVED + Oracle-approved), **ADR-6** (visualizer dual-producer — the Phase 4 contract), **ADR-7 + amendment** (audioMix-on-construction), ADR-8 (RBJ formulas), ADR-9 (filter reset on seek), ADR-10 (release-on-fail), ADR-11 (ASBD format guard)
   - `tasks/avplayer-native-video-dsp/todo.md` — **Phase 4 work-item checklist is the active work.** Phases 1-3 items are all `[x]` (3.17 audible smoke deferred to Phase 5).
   - `tasks/avplayer-native-video-dsp/research-notes/saved-branch-retrospective.md` — ALLOWLIST/DENYLIST scoping for what to study from the saved engine-routing branch (file:line citations)

3. **Re-read at HEAD** the files Phase 6 (deadline-miss telemetry) will touch (line numbers drift):
   - `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` — add Atomic counters (`budgetOverrunCount`, `deadlineRiskCount`, `lastLoggedHostTime` per todo 6.1) following the existing Gate-1 contract (Atomic-only; update the header field list). All `RenderThreadSafe` by being `Atomic`.
   - `MacAmpApp/Audio/VideoDSP/VideoTap.swift` — `tapProcess` samples `mach_absolute_time()` around the DSP, compares against the render deadline budget, increments the counters (lock-free, no allocation). See `tasks/avplayer-native-video-dsp/research-notes/spike-findings.md` hardening item 3.
   - Phase 8 reads these counters as the CPU-benchmark gate. Engine path stays UNTOUCHED.

4. **Spike code reference** (kept locally, throwaway branch — Phase 2 production tap is the spike's pattern HARDENED; do not regress to the spike's shortcuts):
   ```bash
   git show spike/avplayer-inplace-tap-dsp:spikes/avplayer-inplace-tap-dsp/Sources/InPlaceTapSpike/main.swift
   ```

5. **Saved-branch reference** (paused-as-reference, NOT for cherry-picking):
   ```bash
   git show feat/video-audio-engine-routing:MacAmpApp/Audio/VideoAudioTap.swift
   ```
   Read with the ALLOWLIST/DENYLIST in `research-notes/saved-branch-retrospective.md` open. C-callback shape, `Unmanaged` lifetime, ASBD inspection, surround-channel layout knowledge are reusable as patterns. Ring buffer, AudioConverter, watchdog, HAL listener, fallback flag, `swift-atomics` are explicitly NOT carried forward.

6. **Then execute Phase 4** (visualizer DSP on the video-tap render path) per `todo.md` Phase 4 items + plan.md §6 Phase 4 + **ADR-6** (dual-producer pattern). Essentials:
   - Add a `videoTapVisualizerRender` path that consumes the tap's `AudioBufferList`. The engine-side producer (`makeTapHandler` in `VisualizerPipeline.swift`) stays UNTOUCHED — ADR-6 is explicit: two parallel render functions, NOT a flag-driven generalization.
   - Both producers feed the same `VisualizerFeed` + `VisualizerScratchBuffers` (extracted in Phase 1). Multichannel/surround downmixes to mono in the new render function; the audible path leaves channel layout untouched.
   - Drive it from `tapProcess` reading the post-DSP buffer (so the visualizer reflects the EQ'd signal, matching the engine side). Confirm exact ordering against ADR-6 + plan §6.
   - TSan-on build + test green. Manual smoke: spectrum analyzer + Butterchurn animate from video audio (this is the first phase where the visualizer lights up for video).

7. **Commit at end of Phase 4:** `chore(s3-2): Phase 4 — visualizer DSP on video-tap render path`. Mark Phase 4 todos `[x]`; update this file's "Current State" + "Active Work Queue" to Phase 4 done / Phase 5 next.

### Critical reminders

- **Engine path must remain byte-for-byte identical.** Phase 1 verified this for the visualizer extraction. Do NOT modify the engine audio path or the engine-side `makeTapHandler`; Phase 4 ADDS a parallel video-tap visualizer producer (ADR-6), it does not change the engine one.
- **Coefficient hand-off is settled (P-4 resolved, ADR-4 amendment #2).** `VideoTapContext.coefficients: Mutex<BiquadCoefficientSet?>`; main writes via `installCoefficients` (`withLock`), render reads via `withLockIfAvailable` (three-case double-optional) into the render-owned `BiquadCascade` cache. **Phase 5 must push EQ state via `installCoefficients` + the `isEqOn`/`preamp`/`balance` atomics — NEVER touch `.cascade`** (render-confined; a contract test, `cascadeIsRenderConfined`, fails the build if `.cascade` is referenced outside `VideoTapContext.swift`/`VideoTap.swift`).
- **`audioMix` is configured during AVPlayerItem CONSTRUCTION** (per ADR-7 amendment). Never assign `audioMix` to an existing `AVPlayerItem` in production code paths. See `VideoPlaybackController.loadVideo` (audioMixBuilder + isStillRelevant) + `AudioPlayer.startVideoLoad` (generation counter + in-flight Task handle).
- **No `swift-atomics` `ManagedAtomic`.** Use `Synchronization.Atomic<T>` (Swift 6 stdlib, macOS 15+) per ADR-3.
- **`@unchecked Sendable` on Context is contained by the Gate-1 header contract.** Every stored field is `Atomic<T>`, `Mutex<T>`, or a `RenderThreadSafe` conformer (`cascade: BiquadCascade`, render-confined). Adding a field requires extending the header contract + adding a `RenderThreadSafe` conformance in `RenderThreadSafe.swift`. Gate 3a (Mirror) + 3b (var-regex) + 3c (`.cascade` confinement) tests enforce it.
- **Float not `AtomicRepresentable`.** Use `Atomic<UInt32>` storing `Float.bitPattern`.
- **Balance is `[-1, 1]`, center `0.0`** — same convention as `AudioPlayer.balance` / `AVAudioNode.pan` (so Phase 5 writes through). `VideoTap.balanceGains` clamps.
- **One tap per `AVPlayerItem`.** Per ADR-7. AVPlayerItem replacement → new tap; never reuse.
- **`MTAudioProcessingTapCallbacks.init` parameter:** label is `init:` (no backticks).
- **`MTAudioProcessingTapCreate` last parameter:** Swift bridges as `MTAudioProcessingTap?` (NOT `Unmanaged<MTAudioProcessingTap>?`). **`MTAudioProcessingTapFlags` is a `UInt32` typealias, not an OptionSet** — use bitwise `&` with `kMTAudioProcessingTapFlag_StartOfStream`.
- **TSan after every phase boundary.** Per project convention.
- **No `// TODO` in production code.** Stubs go in `placeholder.md`. Current open: **P-2** (Mirror `~Copyable` gap), **P-3** (`@preconcurrency import AVFoundation`), **P-6** (video→audio no auto-play, non-blocking). P-1/P-4/P-5 are CLOSED.
- **Manual smoke (todo 2.39) ✅ DONE 2026-05-02** — 5 clapperboard clips; fixed P-5 display regression (`c040e76`).
- **Leak check (todo 2.40) ✅ DONE 2026-05-28** — via Xcode Memory Graph Debugger (NOT Allocations — pure-Swift classes don't show by name there; MGD does). `VideoTapContext` + coefficient buffers 1→0 across clip load→teardown; no leak. Workflow: `tasks/_context/instruments-allocations-workflow.md`.
- **Audible EQ-on-video smoke ✅ DELIVERED in Phase 5** (was the deferred todo 3.17; now todo 5.16, READY FOR USER) — the EQ/balance fanout populates the tap's coefficients/atomics, so moving an EQ slider or balance during video changes the audio in real time.

### After Phase 6

Phase 7 is the lifecycle test suite + signed-bundle smoke. Phase 8 executes the 15-gate verification matrix (reads the Phase 6 deadline-miss counters as the CPU gate). Phase 9 is UI integration polish + mandatory docs (`docs/MACAMP_ARCHITECTURE_GUIDE.md` "Audio Mechanism Concurrency Contract" subsection — the Phase 2-5 architecture deltas to fold in are catalogued in `tasks/avplayer-native-video-dsp/state.md` "Architecture / flow changes for a later docs/ update") + pre-PR Oracle review + `gh pr create`.

### Optional sub-track

`timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
