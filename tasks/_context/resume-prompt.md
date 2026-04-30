# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" sections after each PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each PR merge)

**Last update:** 2026-04-30 (post-PR-#82 merge — `stream-pause-tail` shipped; Wave S3-1 complete).
**Main HEAD:** `b60fd57` — Merge pull request #82 from `fix/stream-pause-tail`.
**Tests:** 68 passing (TSan ON).
**PRs merged total:** 80.

**Most recent task closed:** `tasks/done/stream-pause-tail/` (S3-1B, PR #82, merged 2026-04-30, merge commit `b60fd57`). Atomic silence gate on the `AVAudioSourceNode` render block + producer-quiesce barrier (gate→clearQueue→ring flush in one decode-queue block) + seqlock + CAS in `LockFreeRingBuffer.read()` eliminates the ~0.7 s pause-tail and closes the consumer-side render-vs-flush race. `userPaused` flag suppresses reconnect-during-pause; `resume()` switches on pipeline state for safe live-edge restart with explicit bridge teardown. 9 implementation review iterations (Codex Oracle final 9/10 + parallel code-reviewer agent pass that caught a `deinit` task-leak Oracle missed). All 7 manual scenarios validated on real SomaFM stream. Two Lows deferred (see `_context/state.md` "Post-S3-1B Follow-Ups"): `StreamDecodePipeline.stop()` generation guard and `AudioConverterDecoder.clearQueue()` confinement-doc gap.

**Previous closeout:** `tasks/done/timer-runloop-mode-audit/` (Post-S3-1A follow-up, PR #81, 2026-04-29). Pattern A normalization across the codebase. Deferred sub-follow-up `timer-scheduled-on-common-extension` pre-tracked.

---

## Active Work Queue (ordered — start at the top)

### 1. NEXT — `tasks/video-audio-engine-routing/` (S3-2)

**Status:** Plan Oracle-approved 9.4/10. S3-1B merge precondition is satisfied. Ready to implement.

**Phase 0 spike:** `spike/vaer-av-drift-measurement` — **kill-switch**. Run on a throwaway branch FIRST. If measured A/V drift exceeds 100 ms, **cancel the task entirely**.

**Branch:** `feat/video-audio-engine-routing` → PR target #C.
**Predecessors:** S3-1A ✅ + S3-1B ✅ both merged.
**Successors:** S3-3 (`hls-streaming-support`) gated on this merge.

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
     │    S3-2 vaer                       ←── PR #C   📋 NEXT (plan 9.4/10; spike/vaer-av-drift-measurement FIRST as kill-switch)
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

Open `tasks/video-audio-engine-routing/` (S3-2). Read all 6 canonical files (`research.md`, `plan.md`, `todo.md`, `state.md`, `placeholder.md`, `depreciated.md`).

**Phase 0 first — kill-switch.** Cut a throwaway branch and run `spike/vaer-av-drift-measurement` to measure A/V drift on the candidate routing path. If measured drift exceeds 100 ms, **cancel the task entirely** — record findings in `research.md`, archive task to `tasks/depreciated/` or annotate as NO-GO, and skip ahead to S3-3 (`hls-streaming-support`).

If drift is acceptable, proceed with the standard pickup process from step 6 onward:
- Confirm `git status` is clean and `git pull origin main` is up to date (most recent merge: PR #82 `stream-pause-tail`, merge commit `b60fd57`, 2026-04-30).
- Re-read every "Files Affected" source listed in `plan.md` at HEAD to reconcile line-number drift since the plan was Oracle-approved (9.4/10).
- Cut branch `feat/video-audio-engine-routing` from `main` and execute phases with TSan-on builds + tests after each.

Stop and report back to me before pushing the PR — I'll review before merge.

> **Optional sub-track:** `timer-scheduled-on-common-extension` — extract a `Timer.scheduledOnMainCommon` helper, migrate all 7 Pattern-A timer callsites. Predecessor `timer-runloop-mode-audit` (PR #81) is merged ✅; this task does not block any S3 wave. Task folder doesn't exist yet — create it on pickup using the same 6-file canonical layout.
