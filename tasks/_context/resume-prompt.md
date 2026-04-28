# S3 Resume Prompt

> **Purpose:** One-stop pickup file for resuming MacAmp Sprint S3 work in a fresh Claude Code session. Update this file's "Current State" + "Active Work Queue" sections after each PR merge so it always reflects HEAD.
>
> **How to use:** In a new session, paste:
> *"Read `tasks/_context/resume-prompt.md` and follow it. Start with the next active task."*

---

## Current State (update after each PR merge)

**Last update:** 2026-04-28 (post-PR-#80 merge).
**Main HEAD:** `7f3d76f` — Merge pull request #80 from `feat/mainwindow-visualizer-isolation`.
**Tests:** 59 passing (TSan ON).
**PRs merged total:** 78.

**Most recent task closed:** `tasks/done/mainwindow-visualizer-isolation/` (S3-1A, PR #80, 2026-04-28). The visualizer-freeze fix landed: producer-side `VisualizerPipeline.pollTimer` switched from `Timer.scheduledTimer` (default `.default` mode) to `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)`. See the task folder's `state.md` for full close-out.

---

## Active Work Queue (ordered — start at the top)

### 1. NEXT — `tasks/timer-runloop-mode-audit/`

**Why first:** Quick win, same run-loop-mode pattern that just shipped. Completes the "no UI element freezes during a drag" story. Estimated 1-2 hours including Oracle gate + PR.

**Scope:** 3 buggy `Timer.scheduledTimer` callsites still using `.default`-mode scheduling:

| File | Line | Severity | Symptom during gesture |
|---|---:|---|---|
| `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift` | 34 | **HIGH** | Winamp marquee title scroll freezes during any slider drag |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 208 | LOW | Butterchurn auto-preset-cycle pauses |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | 239 | LOW | Butterchurn track-title overlay refresh pauses |

**Branch:** `fix/timer-runloop-mode-audit` → target PR #G.
**Phase 0 spike:** none required (structural fix mirroring mwvi commit `6a6bbf2`).
**Plan + todo already in task folder, Oracle-ready.**

### 2. THEN — `tasks/stream-pause-tail/` (S3-1B)

**Status:** Plan Oracle-approved 9.1/10 over 5 iterations. Ready to implement.

**Scope:** Two bugs in one task:
- ~0.7 s of audio plays after pausing an internet-radio stream (silence-gate + producer-quiesce).
- Latent reconnect-during-pause bug (reconnect can resume playback while user has stream paused).

**Branch:** `fix/stream-pause-tail` → target PR #B.
**Phase 0 spike:** none required.
**8 phases / 8 ADRs (SPT-1 through SPT-8) / ~8 files touched** — see `tasks/stream-pause-tail/{plan,todo}.md`.

---

## After S3-1B merges (S3 ladder, locked)

```
S3-1A mwvi ✅ MERGED (PR #80)
     │
     ├──► S3-1B spt           ←── PR #B (next after timer-runloop-mode-audit)
     │       │
     └───────┴──► S3-2 vaer    ←── PR #C
                    │   └── runs spike/vaer-av-drift-measurement FIRST (kill-switch)
                    ▼
                 S3-3 hls       ←── PR #D
                    │
                    ▼
                 S3-4 ogg       ←── PR #E
                     └── runs spike/ogg-build-wiring (0a) + spike/ogg-local-playback (0b) FIRST
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

- **Part 23 — Lesson: RunLoop Mode Discipline in Feeding Pipelines (April 2026)** — direct guidance for `timer-runloop-mode-audit`. Includes the audit-habit shell snippet to enumerate all `Timer.scheduledTimer` callsites and verify each is followed by `RunLoop.main.add(timer, forMode: .common)`.
- **Part 21 — Video/Milkdrop Window Patterns** (Pattern 3: `Task { @MainActor in }` for Timer/Observer Closures) — relevant when modifying timer closures during the audit.

---

## First Action for the Resuming Agent

Open `tasks/timer-runloop-mode-audit/`, read all 6 canonical files, and run the pre-flight verification: re-read `WinampMainWindowInteractionState.swift:25-50` and `ButterchurnPresetManager.swift:200-260` at HEAD to confirm the line numbers in the task's `research.md` haven't drifted. Then proceed with the standard pickup process from step 5 onward (cut branch, execute phases, Oracle gate, PR).

Stop and report back to me before pushing the PR — I'll review before merge.
