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

- [x] **2A** Create `MacAmpApp/Windows/WindowRegistry.swift` ✓
  - Moved 5 NSWindowController properties + `windowKinds` map
  - Moved `mapWindowsToKinds()`, `windowKind(for:)` methods
  - Added `window(for:)`, `forEachWindow()`, `liveAnchorFrame(_:)` helpers
  - WindowCoordinator creates registry, forwards window accessors as computed properties
  - Build verified

- [x] **2B** Create `MacAmpApp/Windows/WindowFramePersistence.swift` ✓
  - Moved persistence suppression logic, `WindowPersistenceDelegate` class
  - Moved `persistAllWindowFrames()`, `schedulePersistenceFlush()`, `handleWindowGeometryChange()`
  - Moved `applyPersistedWindowPositions()` with clamping logic
  - Coordinator methods forward to `framePersistence`
  - Removed `windowFrameStore` property from coordinator (now owned by persistence)
  - Removed old nested `WindowPersistenceDelegate` from coordinator (replaced by top-level class)
  - Removed duplicate `LayoutDefaults.playlistMaxHeight` from coordinator
  - Build verified

- [x] **2C** Create `MacAmpApp/Windows/WindowVisibilityController.swift` ✓
  - Moved `isEQWindowVisible`, `isPlaylistWindowVisible` (observable properties)
  - Moved all show/hide/toggle methods for all 5 window types
  - Moved `showAllWindows()`, `focusAllWindows()`, `minimizeKeyWindow()`, `closeKeyWindow()`
  - Marked `@Observable @MainActor` for SwiftUI reactivity
  - Takes `WindowRegistry` and `AppSettings` as init parameters
  - Coordinator forwards properties via computed get/set (observation chaining verified)
  - Build verified

- [x] **2D** Create `MacAmpApp/Windows/WindowResizeController.swift` ✓
  - Moved `resizeMainAndEQWindows()` + docking-aware resize logic
  - Moved `makePlaylistDockingContext()` and `makeVideoDockingContext()` (stateful, not pure)
  - Moved `lastPlaylistAttachment`, `lastVideoAttachment` state
  - Moved `updatePlaylistWindowSize()`, `updateVideoWindowSize()`, `updateMilkdropWindowSize()`
  - Moved resize preview methods (show/hide for video and playlist)
  - Moved `movePlaylist()`, `moveVideoWindow()`
  - Moved debug logging: `logDoubleSizeDebug()`, `logDockingStage()`
  - Composes: `WindowRegistry`, `WindowFramePersistence`, uses `WindowDockingGeometry` static methods
  - NO dependencies on WindowVisibilityController (acyclic graph maintained)
  - Build verified

- [x] **2-VERIFY** Phase 2 build + sanitizer + functional test ✓
  - Build: **SUCCEEDED**
  - Full test suite: **TEST SUCCEEDED**
  - Oracle review (gpt-5.3-codex, xhigh reasoning): **No concrete defects found**
  - WindowCoordinator.swift: 1,357 → 583 lines (-57%)

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
