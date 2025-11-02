# Magnetic Window Docking – Actionable TODO (Archive)

Tracking items for `feature/magnetic-window-docking` aligned with the archived implementation plan.

## Phase 0 – Foundations
- [ ] Ensure branch rebased on latest `main`, snapshot current unified window behaviour
- [ ] Review `AppCommands` and `DockingController` visibility flows for compatibility notes

## Phase 1 – Multi-Window Architecture
- [ ] Scaffold `WindowCoordinator` (`@Observable @MainActor`) with weak window storage and visibility flags
- [ ] Create `MainWindowController`, `EqualizerWindowController`, `PlaylistWindowController`
- [ ] Override `windowShouldClose` to hide windows and notify coordinator
- [ ] Update `MacAmpApp.swift` to use coordinator-managed controllers instead of `UnifiedDockView`
- [ ] Remove `UnifiedDockView` references after verifying parity

## Phase 2 – Window Content Wiring
- [ ] Embed SwiftUI window views via `NSHostingController` inside each controller
- [ ] Recreate default stacked positioning on initial launch via coordinator
- [ ] Update menu actions to call coordinator show/hide APIs and reflect state

## Phase 3 – Snap Manager Integration
- [ ] Register each NSWindow with `WindowSnapManager.shared` on `windowDidLoad`
- [ ] Persist registrations across hide/show cycles
- [ ] Update documentation/checklist to flag `SnapUtils.SNAP_DISTANCE == 15` (doc mismatch)

## Phase 4 – Drag Regions & Interaction
- [ ] Add explicit draggable regions that avoid slider/button hit areas
- [ ] Ensure `window.isMovableByWindowBackground` remains false
- [ ] Measure drag performance with Instruments; adjust throttling if required

## Phase 5 – Scaling & Layout Reconciliation
- [ ] Move double-size toggle logic into coordinator to call `setContentSize`
- [ ] Realign cluster positions post-scale before re-enabling snapping
- [ ] Hook playlist shade/resize events to trigger re-layout

## Phase 6 – Persistence & Recovery
- [ ] Persist per-window frame + visibility keyed by monitor signature
- [ ] Clamp restored positions to current virtual screen bounds
- [ ] Guarantee hidden windows remain registered with snap manager

## Phase 7 – Validation & Polish
- [ ] Execute manual QA matrix (docking, undocking, scaling, shading, multi-monitor, close/reopen)
- [ ] Add unit tests for `SnapUtils` diff/cluster semantics
- [ ] Update `docs/MACAMP_ARCHITECTURE_GUIDE.md` and user docs
- [ ] Record demo video for regression reference

## Pre-Merge
- [ ] Run full test suite and SwiftLint (if configured)
- [ ] Capture git diff for review, ensure no lingering references to unified dock
- [ ] Confirm SNAP distance doc alignment resolved

