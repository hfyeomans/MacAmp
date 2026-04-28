# State: Timer.scheduledTimer Run-Loop Mode Audit

> **Purpose:** Bring the 3 remaining buggy `Timer.scheduledTimer` callsites in `MacAmpApp/` onto `.common` run-loop mode so they keep firing during user gestures. Mirrors the mwvi `VisualizerPipeline` fix.
> **Created:** 2026-04-28
> **Status:** PLANNED — ready to implement after mwvi PR #A merges.

---

## Branch + Wave

- **Branch:** `fix/timer-runloop-mode-audit`
- **Wave:** Post-S3-1A follow-up (independent of S3-2 / S3-3 / S3-4)
- **PR target:** PR #G (numbering tentative; not blocking S3 sequence)
- **Predecessors:** mwvi PR #A merged (so we re-audit against post-mwvi `main`)
- **Successors:** None

---

## Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete (audit findings 2026-04-28) |
| `plan.md` | ✅ Complete |
| `todo.md` | ✅ Complete (5 phases, derived from plan) |
| `depreciated.md` | Empty |
| `placeholder.md` | Empty |

---

## Audit Summary

7 `Timer.scheduledTimer` callsites total in `MacAmpApp/` (post-mwvi):

- ✅ 4 already correct (`AudioEngineController.progressTimer`, `StreamPlayer.elapsedTimer`, `VideoWindowChromeView.metadataScrollTimer`, `VisualizerPipeline.pollTimer` after mwvi commit `6a6bbf2`).
- ❌ 3 need fixing:
  - **HIGH:** `WinampMainWindowInteractionState.scrollTimer` — Winamp marquee title scroll freezes during gestures.
  - **LOW:** `ButterchurnPresetManager.cycleTimer` — Butterchurn preset auto-cycle pauses.
  - **LOW:** `ButterchurnPresetManager.trackTitleTimer` — Butterchurn track-title overlay refresh pauses.

---

## Why this is its own task (not folded into mwvi PR)

mwvi's scope is the spectrum analyzer freeze. Adding 3 unrelated file changes there would be scope creep — the fixes are structurally similar but each callsite has its own semantic context (marquee scroll, preset cycle, title overlay) that warrants independent review. Per project Principle 1 (Problem-First), one task = one problem statement. This task's problem statement is "audit and fix the codebase-wide pattern"; mwvi's was "fix the visualizer freeze."

---

## Next Steps

1. Wait for mwvi PR #A to merge (so this task's audit re-runs against post-mwvi `main`).
2. Cut branch `fix/timer-runloop-mode-audit`.
3. Execute Phases 1-2 (fixes) and Phase 3 (verification) per todo.md.
4. Run Oracle code-review gate.
5. Open PR #G.
6. Merge.
