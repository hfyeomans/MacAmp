# Magnetic Window Docking – Implementation Plan (Archive)

**Feature:** Split MacAmp into three magnetically docking NSWindows (main, equalizer, playlist) for macOS 15+ using SwiftUI + Swift 6  
**Source Context:** `docs/MACAMP_ARCHITECTURE_GUIDE.md`, `MacAmpApp/Utilities/WindowSnapManager.swift`, `tasks/magnetic-window-docking/research.md`, CODEX/Gemini/Claude analyses  
**Assumptions:** Work happens on branch `feature/magnetic-window-docking`, Xcode 16 toolchain, `WindowSnapManager` stays authoritative snap engine

---

## Phase 0 – Foundations (0.5 h)
- Confirm clean working tree and latest main merge.
- Snapshot current single-window behaviour for regression reference.
- Audit existing menu bindings (`AppCommands`, `DockingController`) to understand visibility flows.

## Phase 1 – Multi-Window Architecture (2.5 h)
1. Introduce `WindowCoordinator` (`@Observable @MainActor`) storing weak references to each NSWindow, visibility flags, and shared layout metadata.
2. Create minimal `NSWindowController` subclasses (or a shared factory) for Main/Equalizer/Playlist so we can enforce singleton lifetimes, override `windowShouldClose` to hide, and forward delegate callbacks to the coordinator.
3. Update `MacAmpApp.swift` to instantiate controllers via the coordinator. SwiftUI scenes should request existing controllers rather than create new windows automatically.
4. Remove `UnifiedDockView` from the app entry point after parity verification.

## Phase 2 – Window Content Wiring (1.5 h)
1. Embed existing SwiftUI views (`WinampMainWindow`, etc.) inside the new controllers using `NSHostingController`.
2. Re-create the default stacked layout by positioning windows relative to each other from `WindowCoordinator` on first launch.
3. Ensure AppCommands visibility toggles call through the coordinator to show/hide specific windows (no more `DockingController`-only state).

## Phase 3 – Snap Manager Integration (1 h)
1. On first `windowDidLoad`, call `WindowSnapManager.shared.register(window:kind:)` for each controller.  
2. Add coordinator hooks so registrations occur once even after hide/show cycles.  
3. Update documentation to note the actual `SnapUtils.SNAP_DISTANCE` of 15 px (FLAG).

## Phase 4 – Drag Regions & Interaction (2 h)
1. Replace native title bars with custom drag handles in each window (maintain existing drag gestures on controls).  
2. Implement hit-testing to prevent slider/button interference.  
3. Verify drag performance with Instruments; adjust throttling if needed.

## Phase 5 – Scaling & Layout Reconciliation (2.5 h)
1. Refactor double-size toggle: coordinator computes scaled sizes, calls `window.setContentSize`, and repositions docked neighbours before re-enabling snapping.  
2. Handle playlist shade/resize by notifying the coordinator to recompute cluster frames and push updates via `WindowSnapManager`.

## Phase 6 – Persistence & Recovery (1.5 h)
1. Store per-window frames and visibility in `AppSettings` (or dedicated persistence helper) keyed by resolution + monitor signature.  
2. On launch or monitor change, normalize saved positions to the current virtual screen bounds.  
3. Ensure hidden windows remain registered so they can snap upon re-show.

## Phase 7 – Validation & Polish (2 h)
1. Manual test matrix: independent movement, docking/undocking, double-size transitions (docked & undocked), shading, multi-monitor hot-plug, close/reopen flows.  
2. Add unit tests for `SnapUtils` cluster and diff behaviour with representative cases.  
3. Update `docs/MACAMP_ARCHITECTURE_GUIDE.md` and user-facing docs with the new multi-window architecture.  
4. Capture short screen recording for QA reference.

**Estimated Total:** ~11.5 h (buffer +2.5 h for integration unknowns → 14 h)

**Dependencies & Risks:**  
- Delegate collisions (WindowSnapManager owns delegate) → use delegate multiplexer.  
- Drag responsiveness → profile early.  
- Double-size misalignment → treat as blocking acceptance criterion.  
- **Snap distance doc mismatch (15 vs 10) must be resolved before merge.**

---

This archived plan supersedes previous drafts and should be treated as the authoritative roadmap for the magnetic docking refactor.

