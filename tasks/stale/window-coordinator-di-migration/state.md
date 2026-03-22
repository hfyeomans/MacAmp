# Task State: WindowCoordinator DI Migration

> **Purpose:** Tracks the current state of the WindowCoordinator DI migration task, including phase progress, blocking issues, and decisions. Updated as implementation progresses.

## Current Phase: DEFERRED

## Status: Research and planning complete. Awaiting completion of prerequisite task.

## Branch: TBD (will be created when work begins)

## Context
- **Goal:** Migrate 20 SwiftUI View call sites from `WindowCoordinator.shared?` to `@Environment` via WindowCoordinatorProvider wrapper
- **Prerequisite:** `tasks/window-coordinator-cleanup/` must be complete first
- **Origin:** Deferred from `window-coordinator-cleanup` per Oracle recommendation (scope too large for LOW cleanup)

## Prerequisite Task

| Task | Status | What It Provides |
|------|--------|-----------------|
| `window-coordinator-cleanup` | In Progress | Safe optional singleton (`?` instead of `!`) + DockingController DI |

This task cannot begin until the prerequisite is complete because:
1. The singleton must be safe optional (`?`) before we start removing usages
2. DockingController must already be using property injection (not singleton)

## Approach Decision

**Selected:** WindowCoordinatorProvider wrapper pattern (Oracle-recommended)

| Approach | Verdict | Reason |
|----------|---------|--------|
| Post-init rootView replacement | Rejected | Risky: can reset SwiftUI state, re-trigger onAppear |
| WindowCoordinatorProvider wrapper | **Selected** | Safe, no circular dependency, follows existing patterns |
| Restructure creation flow | Rejected | Too invasive, breaks WindowCoordinator encapsulation |

## Scope

| Component | Count | Status |
|-----------|-------|--------|
| New files (WindowCoordinatorProvider.swift) | 1 | Pending |
| Window controllers to modify | 5 | Pending |
| Views to migrate | 7 | Pending |
| Call sites to convert | 20 | Pending |
| WindowCoordinator.swift changes | 1 | Pending |
