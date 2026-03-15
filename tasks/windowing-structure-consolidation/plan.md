# Plan: Windowing Structure Consolidation

> **Description:** Implementation plan for moving generic window-management code into a coherent `Windowing/` subsystem.
> **Purpose:** Bound the consolidation so it improves ownership and navigation without turning into a broad UI refactor.

---

## Objective

Move generic window-management infrastructure into a dedicated `Windowing/` source area while preserving behavior.

## Proposed Target Layout

```text
MacAmpApp/Windowing/
  Controllers/
  Coordination/
  Geometry/
  Persistence/
```

## Candidate Migrations

- `Windows/WindowRegistry.swift`
- `Windows/WindowVisibilityController.swift`
- `Windows/WindowResizeController.swift`
- `Windows/WindowFrameStore.swift`
- `Windows/WindowFramePersistence.swift`
- `Windows/WindowDockingGeometry.swift`
- `Windows/WindowDockingTypes.swift`
- `Windows/WindowSettingsObserver.swift`
- `Utilities/WindowSnapManager.swift`
- `Utilities/WindowAccessor.swift` if still truly generic after review
- `Utilities/WindowDelegateMultiplexer.swift`
- `Utilities/WindowFocusDelegate.swift`
- `ViewModels/WindowCoordinator.swift`
- `ViewModels/WindowCoordinator+Layout.swift`

## Constraints

- Do not mix this task with feature-specific window redesign.
- Do not mix this task with active S1 implementation branches.
- Avoid introducing behavior changes except where required by the move.

## Open Questions

- `WindowCoordinator` and `WindowRegistry` may still carry feature-specific knowledge that prevents a clean move into a generic `Windowing/` subsystem.
- The implementation pass must classify each candidate as:
  - generic and safe to move
  - generic after extracting a small abstraction
  - feature-coupled and better left in place until a later refactor
- Dependency analysis must happen before any file move so this task does not create circular imports or force broad API reshaping during a structure cleanup.

## Verification

- Project builds after moves and XcodeGen regeneration if needed
- Main, EQ, playlist, video, and Milkdrop windows still open and coordinate correctly
- Docking, visibility, persistence, and resize behaviors remain unchanged
