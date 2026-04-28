# State: MainWindow Visualizer Isolation

> **Purpose:** SwiftUI recomposition boundary for the visualizer during volume slider drag, plus conditional UserDefaults persistence debounce.
> **Created:** 2026-03-14
> **Sprint:** S3, Wave S3-1 Worktree A (parallel with `stream-pause-tail` Worktree B)
> **Status:** PLAN APPROVED — ready for implementation

---

## Current Status

**Phase:** Plan complete, Oracle gate cleared.
**Last Updated:** 2026-04-27.

### Artifacts

| File | Status |
|------|--------|
| `research.md` | ✅ Complete (Oracle 9/9 actionable items applied, 2026-04-27) |
| `plan.md` | ✅ Complete — Oracle iter 4: **9.4/10 APPROVED** |
| `todo.md` | ✅ Complete (7 phases, ~145 lines, derived from plan) |
| `depreciated.md` | Empty (no deprecated code yet) |
| `placeholder.md` | Empty (none yet) |

### Oracle Iterations (plan + todo)

| # | Score | Verdict |
|---|------:|---------|
| 1 | 8.4/10 | CONDITIONAL |
| 2 | 9.0/10 | CONDITIONAL (regression cycle on Phase 1B redesign) |
| 3 | 8.8/10 | CONDITIONAL |
| 4 | **9.4/10** | **APPROVED** |

---

## Branch + Wave

- **Branch:** `feat/mainwindow-visualizer-isolation`
- **Spike branch:** `spike/mwvi-volume-drag-profile` (throwaway)
- **Wave:** S3-1 Worktree A (parallel start with spt Worktree B; sequential merge: A first)
- **PR target:** PR #A
- **Predecessors:** none
- **Successors:** S3-1B (`stream-pause-tail`) merges after A; subsequent waves S3-2 → S3-4

---

## Key Plan Decisions

| # | Decision |
|---|----------|
| 1 | Phase 0 mandatory Instruments spike: 4-trace protocol (T1 vol-control, T2 vol-drag, T3 bal-control, T4 bal-drag) with explicit ratio thresholds (≥3× / ≥1.5× / ±20%) to disambiguate Mechanism A / B / A+B / C / Heisenbug. |
| 2 | Phase 1A — extraction of `MainWindowVisualizerLayer` wrapping `VisualizerView()` (2-file diff). |
| 3 | Phase 1B (conditional, only if Mechanism B confirmed) — redesigned during Oracle iter-1 to call-site-driven persistence (`AudioPlayer.commitVolumeToDefaults()` + `PlaybackCoordinator.commitVolume()` + `WinampVolumeSlider.onDragEnded` closure). Satisfies Principle 3 (state ownership). |
| 4 | Phase 1C (timer promotion) documented as fallback only. |
| 5 | Stop-criteria split: pre-merge §11.1 (Path A default-preserve / Path B-cherry-pick discard) and post-merge §11.2 → §13 Rollback Plan. |

---

## Next Steps (implementation)

1. Create worktree on branch `feat/mainwindow-visualizer-isolation`.
2. Cut throwaway spike branch `spike/mwvi-volume-drag-profile`.
3. Execute Phase 0 todo items (T0.1 – T0.7) — Instruments capture + decision rule.
4. Write findings to `research.md` "Phase 0 — Spike Results" section.
5. Delete spike branch.
6. Execute Phase 1A (always) and conditionally Phase 1B / 1C per spike outcome.
7. Run TSan-enabled build + tests via xcodebuildmcp.
8. Run Oracle code-review gate against `main` after implementation.
9. Open PR #A.
