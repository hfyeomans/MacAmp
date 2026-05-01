# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" sections after each PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each PR merge)

> ⚠️ **S3-2 ARCHITECTURAL PIVOT (2026-05-01)** — `feat/video-audio-engine-routing` is **PAUSED-AS-REFERENCE** (preserved at `5af91eb`, pushed to origin). S3-2 is being re-attempted as **`avplayer-native-video-dsp`** on branch `feat/avplayer-native-video-dsp`. **See `tasks/_context/s3-2-pivot.md` for the strategic decision and three-step plan — that file is authoritative.** The "Last update" line and Active Work Queue below are kept brief during the pivot; rich detail is in the pivot tracker.

**Last update:** 2026-05-01 (S3-2 pivoted — engine-routing approach paused-as-reference; new branch `feat/avplayer-native-video-dsp` cut from main with Phase 1 cherry-picked, scaffold only; Step 2 research NEXT).
**Main HEAD:** `9cca40a` — `docs(_context): close out Phase 2; advance vaer to Phase 3-next`.
**feat/avplayer-native-video-dsp HEAD:** `ffd77c1` — `chore(audio): drop wasVideoBridge field on AVPlayer-native branch` (Step 1 mechanical pivot, post-cherry-pick cleanup; subsequent commit will land the task scaffold).
**feat/video-audio-engine-routing HEAD (paused):** `5af91eb` — `docs(vaer): mark branch paused for S3-2 architectural pivot`. 44 commits ahead of main, pushed to origin.
**Tests:** 72/72 passing on the new branch (TSan ON, Phase-1-only surface). 110/110 on the paused branch (TSan ON, full Phase 7 surface).
**PRs merged total:** 80. No PR opened on either S3-2 branch.

**Most recent docs commits on main:**
- `07a3ee8` HLS video future-work doc (S3-2 vs S3-3 naming clarification + 3 options for hypothetical HLS-video work)
- `9fa0238` `*.m4v` gitignore
- `5dea7d3` Phase 0 status sweep
- `1d4eca1` Phase 0 spike findings — Path NONE selected; plan §9 Phase 4 = no-op; plan §7.5 AudioConverter is load-bearing

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). Atomic silence gate on the `AVAudioSourceNode` render block + producer-quiesce barrier (gate→clearQueue→ring flush in one decode-queue block) + seqlock + CAS in `LockFreeRingBuffer.read()` eliminates the ~0.7 s pause-tail and closes the consumer-side render-vs-flush race. `userPaused` flag suppresses reconnect-during-pause; `resume()` switches on pipeline state for safe live-edge restart with explicit bridge teardown. 9 implementation review iterations (Codex Oracle final 9/10 + parallel code-reviewer agent pass that caught a `deinit` task-leak Oracle missed). All 7 manual scenarios validated on real SomaFM stream. Two Lows deferred (see `_context/state.md` "Post-S3-1B Follow-Ups"): `StreamDecodePipeline.stop()` generation guard and `AudioConverterDecoder.clearQueue()` confinement-doc gap.

**Previous closeout:** `tasks/done/timer-runloop-mode-audit/` (Post-S3-1A follow-up, PR #81, 2026-04-29). Pattern A normalization across the codebase. Deferred sub-follow-up `timer-scheduled-on-common-extension` pre-tracked.

---

## Active Work Queue (ordered — start at the top)

### 1. SCAFFOLDED — `tasks/avplayer-native-video-dsp/` (S3-2 PIVOT)

**Status:** Step 1 (mechanical pivot) ✅ DONE 2026-05-01. **Step 2 (research phase) is NEXT** — see `tasks/_context/s3-2-pivot.md` for the canonical three-step tracker.

**Why pivoted:** The original S3-2 (`feat/video-audio-engine-routing`) reached Phase 7 testing and revealed structural issues with the engine-routing approach: `AVAudioEngineConfigurationChange` unreliable for AirPlay/AirPods routes (proven by missing log line), master-clock-coupled video stalls, dual-clock-domain drift, and tinning artifacts from a second SRC stage. The contrarian solve: don't drag video audio out of AVPlayer — apply DSP in-place inside the same `MTAudioProcessingTap` so AVPlayer's native pipeline plays the modified buffer. No ring, no engine clock for video, no master-clock coupling. Full strategic decision in `tasks/_context/s3-2-pivot.md`.

**Step 1 deliverables (all ✅ done):**
- Saved branch `feat/video-audio-engine-routing` pushed to origin (44 commits, last `5af91eb`)
- New branch `feat/avplayer-native-video-dsp` cut from main (`9cca40a`)
- Phase 1 cherry-picked (13 commits — engine config observer for stream-side resilience)
- `wasVideoBridge` field cleanly removed from `PreReconfigureSnapshot` (commit `ffd77c1`)
- 72/72 tests with TSan
- Task folder `tasks/avplayer-native-video-dsp/` scaffolded with 6 canonical files (skeletons)
- `tasks/_context/s3-2-pivot.md` created
- Cross-refs in `_context/state.md`, `tasks_index.md`, this file

**Step 2 (research phase) NEXT — kill-switches:**
- **Phase 0 spike** — `MTAudioProcessingTap` in-place buffer modification feasibility (throwaway branch, ~1–2 days). If AVPlayer doesn't actually play modified buffers, the architecture pivots and we replan.
- Apple docs review — TN2249, `AVMutableAudioMix`, `MTAudioProcessingTap` SDK header, `AVAudioUnitEQ` reference
- Reference-branch retrospective — read `feat/video-audio-engine-routing` end-to-end, catalog reusable patterns
- `AVAudioUnitEQ` numerical-match research
- Render-thread CPU budget measurement (Apple Silicon + Intel)
- Channel-count / sample-rate handling investigation
- `VisualizerFeed` extraction approach

Findings written to `tasks/avplayer-native-video-dsp/research.md`; Oracle research-pass review.

**Step 3 (plan phase) — AFTER Step 2:** write `plan.md`, iterate with Oracle to ≥9/10, get user sign-off, derive `todo.md` phases, begin implementation.

### 2. PAUSED-AS-REFERENCE — `tasks/video-audio-engine-routing/`

Original S3-2 attempt. Branch `feat/video-audio-engine-routing` preserved at `5af91eb` (44 commits ahead of main, pushed to origin). NOT being merged. Useful as research reference for: channel-mapping/surround-downmix logic, C-side `MTAudioProcessingTap` callback patterns, atomics-driven cross-thread state, TSan test patterns, Oracle review history (9 implementation phases, all ≥9/10), Phase 7 quality investigation findings (which informed the pivot).

The task's `state.md` carries a PAUSED-AS-REFERENCE banner pointing here.

### 3. DEFERRED — `timer-scheduled-on-common-extension`

Sub-follow-up of `timer-runloop-mode-audit` (now merged). Extract a `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift` and migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` to use it. With 7 Pattern-A callsites now in the codebase, AHA Rule-of-Three is exceeded by 4× — the helper is the natural next step.

**Predecessor:** `timer-runloop-mode-audit` PR #81 ✅ merged 2026-04-29.
**Task folder:** not yet created (centrally tracked in `tasks/_context/state.md` "Post-S3-1A `timer-runloop-mode-audit` Follow-Ups" section).
**Risk:** `@Sendable` closure migration may surface concurrency-checker edge cases at callsites using `[weak self]` + `MainActor.assumeIsolated` — warrants per-site review.
**When to start:** any time; not blocking any S3 wave.

### 2. DEFERRED — `timer-scheduled-on-common-extension`

Sub-follow-up of `timer-runloop-mode-audit` (now merged). Extract a `Timer.scheduledOnMainCommon(every:repeats:_:)` helper into `MacAmpApp/Utilities/Timer+CommonMode.swift` and migrate all 7 timer-on-RunLoop callsites in `MacAmpApp/` to use it. With 7 Pattern-A callsites now in the codebase, AHA Rule-of-Three is exceeded by 4× — the helper is the natural next step.

**Predecessor:** `timer-runloop-mode-audit` PR #81 ✅ merged 2026-04-29.
**Task folder:** not yet created (centrally tracked in `tasks/_context/state.md` "Post-S3-1A `timer-runloop-mode-audit` Follow-Ups" section).
**Risk:** `@Sendable` closure migration may surface concurrency-checker edge cases at callsites using `[weak self]` + `MainActor.assumeIsolated` — warrants per-site review.
**When to start:** any time after S3-1B; not blocking any S3 wave.

---

## S3 work map (current state — refresh on each merge)

```
S3-1A mwvi  ✅ MERGED (PR #80, merge commit 7f3d76f, 2026-04-28)
     │
     ├──► S3-1B spt                       ←── PR #82  ✅ MERGED (merge commit b60fd57, 2026-04-30)
     │       │
     │       ▼
     │    S3-2 vaer                       ←── PR #C   🔧 IN PROGRESS (Phase 0/1/2 ✅; Phase 3 engine source node + wiring next)
     │       │
     │       ▼
     │    S3-3 hls                        ←── PR #D
     │       │
     │       ▼
     │    S3-4 ogg                        ←── PR #E
     │           └── runs spike/ogg-build-wiring (0a) + spike/ogg-local-playback (0b) FIRST
     │
     └──► timer-runloop-mode-audit         ←── PR #81  ✅ MERGED (merge commit ac09dd4, 2026-04-29)
              │
              ▼
          timer-scheduled-on-common-extension   ←── PR #H   ⏸ DEFERRED (predecessor merged ✅; ready when scheduled)
```

**Spike policy (default — do NOT deviate without explicit reason):** each Phase 0 spike runs at its parent task's pickup time on a throwaway branch, findings written to that task's `research.md`, branch deleted. Do NOT run `spike/vaer-av-drift-measurement`, `spike/ogg-build-wiring`, or `spike/ogg-local-playback` early. The vaer drift spike is the kill-switch on whether vaer is feasible at all (>100 ms drift → cancel task), but its strategic value of running early is not worth the workflow break.

**Post-S3:** Structure Sprint (file-move consolidation per `_context/state.md` D-STRUCTURE decision 2026-03-15). Don't start it until S3 closes.

---

## Standard Pickup Process (apply per task)

Every S3 task — main task or spike — follows this sequence:

1. **Read `tasks/_context/state.md`** for cross-task coordination state, file-conflict matrix, and current sprint status.
2. **Read `tasks/_context/principles.md`** — the 7 decomposition principles (Problem-First, Cohesion>LOC, State Ownership, AHA Rule of Three, API Surface, No Pass-Through, ADR + Kill Switch).
3. **Read all 6 canonical files** in the task folder: `research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`.
4. **Re-read every "Files Affected" source at HEAD** to reconcile line-number drift since the plan was written. Verify the plan/todo references still match the code.
5. **Confirm `git status` is clean.** If pending changes exist, commit them as a `chore:` before cutting the new branch.
6. **Cut branch from `main`:** `git checkout main && git pull && git checkout -b <branch-name>`.
7. **Execute `todo.md` phases in order.** TSan-on builds + tests after each phase (per `feedback_xcodebuildmcp_workflow.md` memory):
   ```bash
   xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
   ```
   Note: TSan is per-invocation only — no session-default works (see `feedback_tsan_xcodebuildmcp_cli.md`).
8. **Use `ast-grep` (`sg --lang swift -p '<pattern>'`)** before editing setter chains, call graphs, or member-access patterns. `rg` text search alone misses duplicates and dead writes (see `feedback_ast_grep_structural_search.md`).
9. **For diagnostic work on pipelines** (producer → transport → consumer): instrument at least two stages, not just the symptom site (see `feedback_pipeline_end_to_end_diagnosis.md`).
10. **Run Codex Oracle pre-PR code-review gate** (`mcp__codex-cli__codex`, model `gpt-5.3-codex`, `reasoningEffort: xhigh`). Apply ACTIONABLE feedback. Consider NITs case-by-case.
11. **Push + `gh pr create`.** Wait for human review before merging.
12. **Post-merge close-out** (model after the mwvi close-out commit `0358a25`):
    - Update task `state.md` to MERGED with PR link + merge commit.
    - `git mv tasks/<task>/ tasks/done/<task>/` (preserves history).
    - Update `tasks/_context/state.md` (Quick Reference, sprint table, follow-up section if any).
    - Update `tasks/_context/tasks_index.md`.
    - **Update this file** (`tasks/_context/resume-prompt.md`) — bump "Current State" section, advance "Active Work Queue" by removing the merged task and promoting the next task in line.
    - Single `chore: close out <task> (PR #X)` commit.

---

## Persistent Project Memories (auto-loaded by session start hook)

Index lives at `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/MEMORY.md`. Notable memories that apply directly to S3 work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — Symptoms manifest at the consumer; root causes often live at the producer. Instrument both ends of any data pipeline before diagnosing. Five operational rules; cross-references the same meta-principle as ast-grep.
- **`feedback_ast_grep_structural_search.md`** — Use `sg --lang swift -p` for structural enumeration before edits; `rg` text search misses duplicates / dead writes / pass-through middlemen.
- **`feedback_xcodebuildmcp_workflow.md`** — Always xcodegen + XcodeBuildMCP build AND test (not just `swift build`/`test`) after adding/moving files. TSan must be passed per-invocation.
- **`feedback_sprint_workflow.md`** — Every sprint task gets Oracle review + PR for user review before merge, regardless of size.
- **`feedback_architecture_principles.md`** — The 7 decomposition principles (project-canonical at `tasks/_context/principles.md` and `.ai-shared/principles.md`).

---

## Project-Specific Lessons Reference

`BUILDING_RETRO_MACOS_APPS_SKILL.md` is the canonical lessons-learned doc. Most relevant for current work:

- **`feedback_pipeline_end_to_end_diagnosis.md`** — directly applicable to `stream-pause-tail`: the pause-tail bug is a producer-vs-consumer pipeline issue (silence-gate at consumer + producer-quiesce). Instrument both ends before diagnosing.
- **Part 23 — Lesson: RunLoop Mode Discipline in Feeding Pipelines (April 2026)** — historical context for the merged `timer-runloop-mode-audit` (PR #81) and direct guidance for the deferred follow-up `timer-scheduled-on-common-extension`. Includes the audit-habit shell snippet to enumerate all `Timer.scheduledTimer` callsites and verify each is followed by `RunLoop.main.add(timer, forMode: .common)`.
- **Part 21 — Video/Milkdrop Window Patterns** (Pattern 3: `Task { @MainActor in }` for Timer/Observer Closures) — relevant whenever modifying timer closures.

---

## First Action for the Resuming Agent

**Read `tasks/_context/s3-2-pivot.md` first.** It is authoritative for current S3-2 status — three-step plan, decision log, file index. The "Active Work Queue" above gives a one-paragraph summary; the pivot tracker has the full context.

Then open `tasks/avplayer-native-video-dsp/` and read the 6 canonical files (currently scaffolded, not yet researched):
- `state.md` — Step 1 done, Step 2 next; saved-branch context, dual-architecture topology table
- `research.md` — research questions for Step 2 (Phase 0 spike kill-switch, Apple docs, retrospective, numerical-match research, render-thread CPU, channel/SRC handling, `VisualizerFeed` extraction)
- `plan.md` — explicitly a skeleton; do NOT implement from it (research must land first per workflow)
- `todo.md` — Step 1 items checked, Step 2/3 items pending
- `placeholder.md` / `depreciated.md` — empty until implementation phase

**Step 1 is done.** Skip it. **Step 2 (research phase) is the active work.**

**Branch already exists:** `feat/avplayer-native-video-dsp` is on main commit `9cca40a` + 13 cherry-picked Phase 1 commits + 1 cleanup commit (`ffd77c1`) + scaffolding commit (the next one to land). Switch to it (`git checkout feat/avplayer-native-video-dsp`). 72/72 tests with TSan.

Saved reference branch (paused, not for work): `feat/video-audio-engine-routing` at `5af91eb`, pushed to origin. Read end-to-end during Step 2 retrospective (research question Q5 in `research.md`).

Step 2 starts with the **Phase 0 spike** (research question Q1) on a throwaway branch — the kill switch on the entire architecture. If `MTAudioProcessingTap` doesn't actually let AVPlayer play in-place modified buffers, replan from there. The spike is documented in `research.md`; stand it up, run it, write findings back to `research.md`. Other research items (Apple docs, retrospective, numerical match, CPU budget, channel handling) can run in parallel or after the spike.

Stop and report back to me before writing `plan.md` (Step 3) — I'll review research findings before plan iteration with Oracle begins.

> **Optional sub-track:** `timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
