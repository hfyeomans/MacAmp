# State: Codebase-Wide Simplification

> **Description:** Systematic sweep of all 112 .swift files for DRY violations, dead code, and simplification opportunities across file boundaries.
> **Purpose:** Phase 2.5 — cross-file cleanup before the 5 structural decomposition tasks.

---

## Status

COMPLETE. PR #72 merged to main 2026-03-24.

**Sprint:** Post-Task 0 / Pre-Task 1
**Created:** 2026-03-24
**Last Updated:** 2026-03-24

## Result

- -732 lines of source code (207 added, 939 removed)
- 6 dead files deleted (393 lines)
- ~270 lines dead functions removed across 19 files
- 8 dead imports removed
- 6 DRY consolidations (96 lines) + 3 moderate DRY consolidations (50 lines)
- 4 new utility files: QueueConfined, TimeFormatting, MenuActionTarget, WinampAlertHelper
- 110 .swift files remain (was 112)
- Oracle gpt-5.4 xhigh: zero findings on both review passes

## Context

Task 0 (intra-file dedup) cleaned up within-file duplications. This task extends that to cross-file patterns:
- Duplicate alert/dialog code across multiple files
- `Result(catching:)` opportunities (flagged by Gemini)
- Dead code that's only visible when checking callers across files
- Common helper extraction candidates
- DRY violations spanning file boundaries

Also addresses Oracle P3 follow-up: investigate whether the custom-skin pledit.txt fallback (white vs green) is intentional or a latent bug to fix.

## Agent Team Structure

5 parallel Explore agents (one per directory area) + 1 Plan agent synthesizer:

| Agent | Scope | Files |
|-------|-------|-------|
| audio-agent | `Audio/` (including `Audio/Streaming/`) | ~15 files |
| views-agent | `Views/` (including all subfolders) | ~44 files |
| models-agent | `Models/` | ~22 files |
| viewmodels-agent | `ViewModels/` | ~6 files |
| infra-agent | `Windows/`, `Utilities/`, root files | ~25 files |

After agents report → Plan agent synthesizes → Implementation in batches with build+test gates.

## Key Decision

- Run BEFORE decomposition tasks (Tasks 1-5) since simplification may reduce code volume
- Each agent reads full files using ast-grep for structural matching
- Findings prioritized: ACTIONABLE (fix now) vs DEFERRED (after decomposition)
- Oracle review on all changes before PR
