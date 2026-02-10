# TODO: WindowCoordinator.swift Refactoring

> **Oracle Review Status:** REVISE then proceed (revisions incorporated below)

## Phase 1: Extract Pure Types + Minimal Tests (Zero Risk)

- [x] **1A** Create `MacAmpApp/Windows/WindowDockingTypes.swift` ✓
  - Moved `PlaylistAttachmentSnapshot`, `VideoAttachmentSnapshot`, `PlaylistDockingContext` from WindowCoordinator.swift
  - Changed access from `private` to `internal`
  - Marked all three types as `Sendable` (they are pure value types)
  - Removed moved types from WindowCoordinator.swift
  - Build verified

- [x] **1B** Create `MacAmpApp/Windows/WindowDockingGeometry.swift` ✓
  - Moved ONLY pure geometry methods (no state dependencies):
    - `determineAttachment(anchorFrame:playlistFrame:strict:)`
    - `playlistOrigin(for:anchorFrame:playlistSize:)`
    - `attachmentStillEligible(_:anchorFrame:playlistFrame:)`
    - `anchorFrame(_:mainFrame:eqFrame:playlistFrame:)`
  - Made `nonisolated struct` with static methods (pure math, no @MainActor needed)
  - Correctly kept `makePlaylistDockingContext()`, `makeVideoDockingContext()`, `liveAnchorFrame()` on coordinator
  - Updated 8+ call sites in WindowCoordinator to use `WindowDockingGeometry.method()`
  - Build verified

- [x] **1C** Create `MacAmpApp/Windows/WindowFrameStore.swift` ✓
  - Moved `PersistedWindowFrame`, `WindowFrameStore`, `WindowKind.persistenceKey` extension
  - Changed access from `private` to `internal`
  - Marked `PersistedWindowFrame` as `Sendable` (pure Codable value type)
  - Added injectable `UserDefaults` for testability: `init(defaults: UserDefaults = .standard)`
  - Removed from WindowCoordinator.swift
  - Build verified

- [x] **1D** Add minimal tests (Oracle recommendation) ✓
  - Added `WindowDockingGeometryTests.swift` - 7 test methods covering all 4 static methods
  - Added `WindowFrameStoreTests.swift` - 3 test methods (roundtrip, save/load, nil for unknown)
  - All 10 tests pass

- [x] **1-VERIFY** Phase 1 build + sanitizer + tests ✓
  - Build: `** BUILD SUCCEEDED **`
  - New tests: `** TEST SUCCEEDED **` (10/10 pass)
  - Full test suite: `** TEST SUCCEEDED **` (all existing tests pass)
  - Also fixed pre-existing broken `PlaylistNavigationTests.swift` (was using read-only `playlist` property setter)
  - Stale comments cleaned per depreciated.md (`// NEW:`, `// CRITICAL FIX #3:`, `// NOTE:`)
  - WindowCoordinator.swift: 1,357 → 1,127 lines (-230 lines, -17%)

---

## Phase 2: Extract Controllers (Low-Medium Risk)

- [ ] **2A** Create `MacAmpApp/Windows/WindowRegistry.swift`
  - Move 5 NSWindowController properties + `windowKinds` map
  - Move `mapWindowsToKinds()`, `windowKind(for:)` methods
  - Add `window(for:)` and `forEachWindow()` helpers
  - Add `liveAnchorFrame(_:)` method (moved from coordinator)
  - WindowCoordinator creates registry, registry becomes sole long-term owner of controllers
  - Forward `mainWindow`, `eqWindow`, etc. as computed properties on facade
  - Build verify

- [ ] **2B** Create `MacAmpApp/Windows/WindowFramePersistence.swift`
  - Move persistence suppression logic
  - Move `WindowPersistenceDelegate` class (THIS TYPE IS THE SOLE OWNER)
  - Move `persistAllWindowFrames()`, `schedulePersistenceFlush()`, `handleWindowGeometryChange()`
  - Move `applyPersistedWindowPositions()`, `beginSuppressingPersistence()`, `endSuppressingPersistence()`, `performWithoutPersistence()`
  - Takes `WindowRegistry` as init parameter (dependency direction: Persistence -> Registry)
  - Build verify

- [ ] **2C** Create `MacAmpApp/Windows/WindowVisibilityController.swift`
  - Move `isEQWindowVisible`, `isPlaylistWindowVisible` (observable properties)
  - Move all show/hide/toggle methods for all 5 window types
  - Move `showAllWindows()`, `focusAllWindows()`, `minimizeKeyWindow()`, `closeKeyWindow()`
  - Mark `@Observable` for SwiftUI reactivity
  - Takes `WindowRegistry` as init parameter
  - Forward properties on WindowCoordinator facade (single source of truth in visibility controller)
  - Build verify

- [ ] **2D** Create `MacAmpApp/Windows/WindowResizeController.swift`
  - Move `resizeMainAndEQWindows()` + docking-aware resize logic
  - Move `makePlaylistDockingContext()` and `makeVideoDockingContext()` HERE (REVISED: stateful, not pure)
  - Move `lastPlaylistAttachment`, `lastVideoAttachment` state HERE
  - Move `updatePlaylistWindowSize()`, `updateVideoWindowSize()`, `updateMilkdropWindowSize()`
  - Move resize preview methods
  - Move `movePlaylist()`, `moveVideoWindow()`
  - Move debug logging: `logDoubleSizeDebug()`, `logDockingStage()`
  - Compose: `WindowRegistry`, `WindowFramePersistence`, uses `WindowDockingGeometry` static methods
  - NO dependencies on WindowVisibilityController (acyclic)
  - Build verify

- [ ] **2-VERIFY** Phase 2 build + sanitizer + functional test
  - Build with Thread Sanitizer
  - Test EQ/Playlist button toggle states (SwiftUI reactivity)
  - Test Ctrl+D double-size docking (playlist stays attached)
  - Test window position persistence (move windows, restart)
  - Run API parity checklist (all 7 properties + 19 methods forwarded)

---

## Phase 3: Extract Observation & Wiring (Low Risk)

- [ ] **3A** Create `MacAmpApp/Windows/WindowSettingsObserver.swift`
  - Move all 4 observation tasks + setup methods
  - Implement generic observation helper to eliminate boilerplate
  - REVISED: Use explicit `start()`/`stop()` lifecycle, NOT deinit cancellation
    ```swift
    func start(onAlwaysOnTopChanged:, onDoubleSizeChanged:, ...)
    func stop() { tasks.values.forEach { $0.cancel() } }
    // deinit is empty or assert-only
    ```
  - Coordinator calls `settingsObserver.stop()` in teardown
  - Build verify

- [ ] **3B** Create `MacAmpApp/Windows/WindowDelegateWiring.swift`
  - Move delegate multiplexer creation + registration
  - Move focus delegate creation
  - Implement as static factory returning a struct with stored references
  - `WindowFramePersistence` owns `WindowPersistenceDelegate`; wiring only attaches it
  - Build verify

- [ ] **3-VERIFY** Phase 3 build + sanitizer
  - Build with Thread Sanitizer
  - Test always-on-top toggle
  - Test video/milkdrop window show/hide via settings
  - Test window focus (active/inactive titlebar sprites)

---

## Phase 4: Layout Extension (Cosmetic) - APPROVED

- [ ] **4A** Create `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift`
  - Move `setDefaultPositions()`, `resetToDefaultStack()`
  - Move `applyInitialWindowLayout()`, `configureWindows()`
  - Move `presentWindowsWhenReady()`, `presentInitialWindows()`
  - Move `debugLogWindowPositions()`, `LayoutDefaults`
  - Keep as extension (needs internal access to coordinator state)
  - Build verify

- [ ] **4-VERIFY** Final build + full functional test
  - Build with Thread Sanitizer
  - Verify WindowCoordinator.swift is ~200 lines
  - Full regression test: load skins, toggle windows, Ctrl+D, resize, persistence
  - Count total lines: should be ~1,305 across 11 files

---

## Post-Refactoring

- [ ] **5A** Update deprecated.md with any patterns removed
- [ ] **5B** Update state.md to reflect completion
- [ ] **5C** Update `docs/MULTI_WINDOW_ARCHITECTURE.md` to document new file structure
- [ ] **5D** Add dependency matrix diagram to architecture docs
- [ ] **5E** Final Oracle review of completed refactoring

---

## Dependency Matrix (Oracle-Required)

```
WindowCoordinator (facade / composition root)
    ├── WindowRegistry              ← NO dependencies on other extracted types
    ├── WindowVisibilityController  ← depends on: WindowRegistry
    ├── WindowFramePersistence      ← depends on: WindowRegistry, WindowFrameStore
    ├── WindowResizeController      ← depends on: WindowRegistry, WindowFramePersistence, WindowDockingGeometry
    ├── WindowSettingsObserver      ← depends on: AppSettings only
    └── WindowDelegateWiring        ← depends on: WindowRegistry, WindowFramePersistence, WindowFocusState

NO controller-to-controller lateral dependencies.
All cross-cutting coordination goes through WindowCoordinator facade.
```

---

## Summary (Revised)

| Phase | Files Created | Lines Moved | Risk | Oracle Verdict |
|-------|--------------|-------------|------|----------------|
| 1 | 3 new + 2 tests | ~270 lines | Zero | REVISE -> done |
| 2 | 4 new files | ~550 lines | Low-Medium | REVISE -> done |
| 3 | 2 new files | ~180 lines | Low | REVISE -> done |
| 4 | 1 extension | ~100 lines | None | APPROVED |
| **Total** | **10 new + 1 ext + 2 tests** | **~1,100 lines** | |

**WindowCoordinator.swift: 1,357 -> ~200 lines (-85%)**
