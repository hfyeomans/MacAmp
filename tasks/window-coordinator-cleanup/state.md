# Task State: WindowCoordinator Cleanup

> **Purpose:** Tracks the current state of the WindowCoordinator cleanup task, including phase progress, Oracle review results, and blocking issues. Updated as implementation progresses.

## Current Phase: COMPLETE (pending manual testing + commit)

## Status: All 4 phases implemented. Build + tests pass with Thread Sanitizer. Oracle post-implementation review passed (no issues). Awaiting manual testing and commit.

## Branch: `refactor/window-coordinator-cleanup`

## Context
- **Source:** 3 LOW priority issues from WindowCoordinator refactoring Oracle review
- **Parent Task:** `tasks/window-coordinator-refactor/` (completed, PR #45 merged)
- **Goal:** Resolve deferred issues + incremental DI hardening

## Issues to Resolve

| # | Issue | Status | Complexity |
|---|-------|--------|-----------|
| 1 | Remove unused `lastVideoAttachment` | **Done** | Trivial |
| 2 | Replace polling loop with observation | **Done** | Low |
| 3A | Safe optional singleton (`!` -> `?`) | **Done** | Trivial |
| 3B | DockingController property injection | **Done** | Low |

## Scope Change (per Oracle)

**Originally planned but deferred:**
- 3C: @Environment injection in window controllers
- 3D: Convert 20 View usages from singleton to @Environment

**Reason:** Oracle (gpt-5.3-codex, xhigh) recommended splitting the full @Environment migration into a separate task. It's too large for a "LOW cleanup" scope and involves the circular dependency challenge (WindowCoordinator creates controllers that create views that need WindowCoordinator).

**Deferred to:** `tasks/window-coordinator-di-migration/` (task folder created with full research, plan, and todo)

## Oracle Review (Pre-Implementation)

**Model:** gpt-5.3-codex, reasoningEffort: xhigh
**Date:** 2026-02-09

### Findings Applied

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | **HIGH** | Async registration race in `withObservationTracking` | Fixed: synchronous registration + immediate re-check |
| 2 | **MEDIUM** | Scene `.environment()` won't reach AppKit windows | Deferred full @Environment migration |
| 3 | **MEDIUM** | `private(set)` prevents external assignment | Use `static var shared: WindowCoordinator?` |
| 4 | **MEDIUM** | Post-init rootView replacement risky | Deferred: WindowCoordinatorProvider for future |
| 5 | **LOW** | Missing `import Observation` in Layout extension | Added to plan |
| 6 | **LOW** | Missing @Environment is runtime, not build-time | Corrected in research.md |

## Key Decisions

1. **Synchronous observation registration** (not async) to avoid race condition
2. **`@ObservationIgnored`** on DockingController's coordinator reference
3. **No `private(set)`** on singleton - external assignment required from MacAmpApp
4. **Deferred full DI migration** - Oracle-recommended scope reduction
5. **Removed `skinPresentationTask` entirely** - property, deinit cancel, and all references (no longer needed with observation pattern)

## Oracle Review (Post-Implementation)

**Model:** gpt-5.3-codex, reasoningEffort: xhigh
**Date:** 2026-02-09

**Result:** No code-level correctness issues found across all 5 changed files.

**Verified:**
- Thread safety: @MainActor isolation consistent
- No remaining `skinPresentationTask` references in source
- `withObservationTracking` pattern correctly structured (synchronous + immediate re-check)
- `@ObservationIgnored weak var` pattern correct for DockingController
- No force-unwrap on singleton
- All callers use optional chaining
- No retain cycles introduced

**Note:** Stale references to `skinPresentationTask` remain in docs (`MULTI_WINDOW_ARCHITECTURE.md`, `BUILDING_RETRO_MACOS_APPS_SKILL.md`) - documentation-only, no runtime impact.

## Files Changed

| File | Change |
|------|--------|
| `MacAmpApp/Windows/WindowResizeController.swift` | Removed `lastVideoAttachment` property |
| `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift` | Added `import Observation`, replaced polling with `withObservationTracking` + `observeSkinReadiness()` |
| `MacAmpApp/ViewModels/WindowCoordinator.swift` | `shared!` → `shared?`, removed swiftlint disable, removed `skinPresentationTask` property + deinit cancel |
| `MacAmpApp/ViewModels/DockingController.swift` | Added `@ObservationIgnored weak var windowCoordinator`, replaced 2 singleton accesses |
| `MacAmpApp/MacAmpApp.swift` | Extracted coordinator to local `let`, added `dockingController.windowCoordinator = coordinator` |
