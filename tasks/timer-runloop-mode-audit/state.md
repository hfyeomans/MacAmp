# State: Timer.scheduledTimer Run-Loop Mode Audit

> **Purpose:** Normalize all timer-on-RunLoop callsites in `MacAmpApp/` onto Pattern A (mwvi-canonical: `Timer(timeInterval:...)` + `RunLoop.main.add(timer, forMode: .common)`). Fixes 2 buggy Butterchurn callsites and converts 4 Pattern-B callsites for consistency.
> **Created:** 2026-04-28
> **Revised:** 2026-04-29 (audit corrected at HEAD `883d085`; scope expanded from 3 → 6 callsites for full normalization)
> **Status:** IMPLEMENTED — branch cut, doc updates done, code edits done, TSan build + 59/59 tests passing, Oracle review 9/10 ACTIONABLE items applied. Awaiting user review before PR push.

---

## Branch + Wave

- **Branch:** `fix/timer-runloop-mode-audit` (cut from `main` at `883d085`)
- **Wave:** Post-S3-1A follow-up (independent of S3-2 / S3-3 / S3-4)
- **PR target:** PR #81 (opened 2026-04-29; not blocking S3 sequence)
- **Predecessors:** mwvi PR #80 merged ✅
- **Successors:** None for this task. Optional follow-up task `timer-scheduled-on-common-extension` (helper extraction) tracked in `plan.md` §8.

---

## Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Revised 2026-04-29 (audit re-done at HEAD; corrected the original textual-only audit) |
| `plan.md` | ✅ Revised 2026-04-29 (scope expanded to 6 callsites for full normalization) |
| `todo.md` | ✅ Revised 2026-04-29 (5 phases, derived from revised plan) |
| `depreciated.md` | Empty |
| `placeholder.md` | Empty |

---

## Audit Summary (corrected 2026-04-29)

7 `Timer.scheduledTimer` / `Timer(...)` callsites total in `MacAmpApp/` at HEAD `883d085`:

- ✅ **1 Pattern A** (mwvi-canonical): `VisualizerPipeline.pollTimer` (fixed in commit `6a6bbf2`).
- ⚠️ **4 Pattern B** (functionally correct but stylistically inconsistent — `Timer.scheduledTimer` + later `.common` add): `AudioEngineController.progressTimer`, `StreamPlayer.elapsedTimer`, `VideoWindowChromeView.metadataScrollTimer`, `WinampMainWindowInteractionState.scrollTimer`.
- ❌ **2 buggy** (no `.common` add): `ButterchurnPresetManager.cycleTimer`, `.trackTitleTimer`.

This task normalizes all 6 non-A callsites to Pattern A.

The original audit (2026-04-28) was textual and inconsistent — see the "Audit correction" section in `research.md`. The HIGH-severity user-visible defect it claimed (Winamp marquee freeze during slider drag) does not exist on `main`; the marquee scrolls correctly during gestures (manually verified by user 2026-04-29). The two LOW-severity Butterchurn defects are real and get fixed as a side-effect of the consistency pass.

---

## Why this is its own task (not folded into mwvi PR)

mwvi's scope was the spectrum analyzer freeze. Adding 6 unrelated file changes there would be scope creep — the fixes are structurally similar but each callsite has its own semantic context that warrants independent review. Per project Principle 1 (Problem-First), one task = one problem statement. This task's problem statement is "audit and normalize the codebase-wide pattern"; mwvi's was "fix the visualizer freeze."

---

## Next Steps

1. ✅ Read all 6 canonical files at HEAD; verify line numbers; confirm audit; `git status` clean.
2. ✅ Cut branch `fix/timer-runloop-mode-audit` from `main`.
3. ✅ Update task docs to reflect revised scope.
4. ✅ Execute Phase 1 (4 Pattern B → A conversions) and Phase 2 (2 Buggy → A conversions).
5. ✅ Phase 3 verification: TSan build clean, 59/59 tests passing, audit re-run shows zero `Timer.scheduledTimer` matches in production code.
6. ✅ Phase 4 — Codex Oracle code-review gate (9/10, ACTIONABLE doc-accuracy items applied).
7. ⏳ Phase 5 — commit changes; **stop and report to user before pushing PR**.
8. ⏳ User-go-ahead → push + open PR #81.
9. ⏳ Post-merge close-out (move to `tasks/done/`, update `_context/state.md` + `tasks_index.md` + `resume-prompt.md`).

> **Update 2026-04-29:** Steps 7-8 complete — feature commit `726d847` pushed to `origin/fix/timer-runloop-mode-audit`; PR #81 opened. CodeRabbit feedback (placeholder + MD040) addressed in a follow-up commit on the same branch.
