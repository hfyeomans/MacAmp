# Magnetic Window Docking – Task State (Archive)

**Branch:** `feature/magnetic-window-docking`  
**Baseline Commit:** `1235fc06af6daa6fca89d47ab1142514ce3bf5a0`  
**Date:** 2025-11-03  
**Status:** *Pre-implementation – plan approved*

## Snapshot
- Research from Claude, Gemini, and Codex consolidated (see `tasks/magnetic-window-docking/archive/research.md`).
- Authoritative implementation plan and todo list published in this archive.
- `WindowSnapManager` and `SnapUtils` confirmed production-ready; integration pending.
- Unified window (`UnifiedDockView`) still active in app entry point; no multi-window code committed yet.

## Key Decisions Locked
1. Use coordinator + window controllers rather than bare `WindowGroup`s to avoid duplicate windows and command drift.
2. Reuse existing `WindowSnapManager` (no reimplementation).
3. Treat double-size alignment as a gating acceptance criterion.

## Outstanding Risks
1. **Lifecycle Drift:** Need delegate multiplexer to coexist with `WindowSnapManager` delegate ownership.
2. **Snap Threshold Documentation:** Current docs claim 10 px; code uses 15 px (`MacAmpApp/Models/SnapUtils.swift:27`). Must reconcile before release.
3. **Drag UX:** Removing system title bars could degrade performance; requires profiling.
4. **Persistence Integrity:** Restoring off-screen windows across monitor changes is unimplemented.

## Next Actions
- Implement Phase 0/1 tasks (coordinator + controllers).
- Update architecture guide to reflect approved approach (draft changes in docs once implementation begins).
- Schedule verification resources for manual QA matrix once window splitting lands.

