# State: WinampMainWindow Layer Decomposition

> **Purpose:** Current status, decisions made, and blockers for this task.
> Updated as implementation progresses.

## Current Status

**Phase:** COMPLETE — MERGED
**Branch:** `refactor/mainwindow-decomposition` (merged, deleted)
**PR:** #54 (merged 2026-02-22)
**Last Updated:** 2026-02-22

## Implementation Summary

| Phase | Status | Commit |
|-------|--------|--------|
| Phase 1: Scaffolding | COMPLETE | 997e4d6 |
| Phase 2: Child Views | COMPLETE | 3b1543b |
| Phase 3: Root Wiring | COMPLETE | 223f594 |
| Phase 4: Verification | IN PROGRESS | — |

### Files Created (10 total in MainWindow/)
- `WinampMainWindow.swift` — root composition (~100 lines)
- `WinampMainWindowLayout.swift` — Coords constants enum (~50 lines)
- `WinampMainWindowInteractionState.swift` — @Observable state class (~120 lines)
- `MainWindowOptionsMenuPresenter.swift` — NSMenu bridge (~130 lines)
- `MainWindowFullLayer.swift` — full-mode composition (~250 lines)
- `MainWindowShadeLayer.swift` — shade-mode composition (~140 lines)
- `MainWindowTransportLayer.swift` — transport buttons (~60 lines)
- `MainWindowTrackInfoLayer.swift` — scrolling text (~50 lines)
- `MainWindowIndicatorsLayer.swift` — indicators (~85 lines)
- `MainWindowSlidersLayer.swift` — sliders (~75 lines)

### Files Deleted
- `MacAmpApp/Views/WinampMainWindow.swift` (339 lines)
- `MacAmpApp/Views/WinampMainWindow+Helpers.swift` (518 lines)
- `MacAmpApp/Views/VideoWindowChromeView.swift` (125 lines, stale duplicate)

### Net Change: -857 lines old → +1,060 lines new (10 focused files vs 2 monolithic)

## Oracle Reviews

### Review 1: Phase 1 Scaffolding (gpt-5.3-codex, xhigh)
- **Finding 1 (High):** Build fails — xcodeproj missing entries → FALSE POSITIVE (SwiftPM project)
- **Finding 2 (Medium):** Interaction state is unused scaffolding → EXPECTED (Phase 1 scaffolding)
- **Finding 3 (Medium):** Stale title capture in scroll timer → FIXED (displayTitleProvider closure)
- **Finding 4 (Low):** DispatchQueue.main.asyncAfter → FIXED (modernized to Task.sleep)

### Review 2: Phase 3 Root Wiring (gpt-5.3-codex, xhigh)
- **Finding 1 (High):** xcodeproj missing entries → FALSE POSITIVE (SwiftPM project)
- **Finding 2 (Medium):** Shade time display double-offset regression → FIXED
- **Finding 3 (Low):** displayTitleProvider stale if coordinator swapped → ACKNOWLEDGED (singleton, no risk)

## Decisions Made

### D1-D6: (unchanged from research phase — see below)

### D7: Task.sleep Modernization
**Decision:** Replace DispatchQueue.main.asyncAfter with Task.sleep in interaction state.
**Rationale:** Structured cancellation, explicit @MainActor isolation, no GCD dependency.
**Status:** Implemented

### D8: displayTitleProvider Pattern
**Decision:** Use closure that reads live title instead of captured string parameter.
**Rationale:** Oracle identified stale title bug — timer would use captured title for its lifetime.
**Status:** Implemented

## Decisions D1-D6 (from research phase)

### D1: Architecture Pattern -- @Observable + Child View Structs
**Decision:** Use `@Observable` interaction state class + separate `View` structs (not extensions).
**Status:** Confirmed

### D2: Coords Extraction Strategy
**Decision:** Extract `Coords` to a top-level `WinampMainWindowLayout` enum.
**Status:** Confirmed

### D3: Timer Ownership
**Decision:** `scrollTimer` in interaction state, `pauseBlinkTimer` on root view.
**Status:** Confirmed

### D4: Options Menu Isolation
**Decision:** Dedicated `MainWindowOptionsMenuPresenter` class.
**Status:** Confirmed

### D5: @Environment Passthrough
**Decision:** Child views declare their own `@Environment` properties.
**Status:** Confirmed

### D6: File Location
**Decision:** `MacAmpApp/Views/MainWindow/` subdirectory.
**Status:** Confirmed

## Blockers

None. Awaiting manual visual/functional verification.

## Artifact Inventory

| Artifact | Status |
|----------|--------|
| research.md | Complete |
| plan.md | Complete |
| todo.md | Active (Phase 4 manual items pending) |
| state.md | Active (this file) |
| depreciated.md | Complete |
| placeholder.md | Needs update (Coords typealias resolved) |
