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

- [x] **3A** Create `MacAmpApp/Windows/WindowSettingsObserver.swift` ✓
  - Moved all 4 observation tasks (alwaysOnTop, doubleSize, showVideo, showMilkdrop)
  - Used explicit `start()`/`stop()` lifecycle with `Handlers` struct for `@MainActor` closures
  - 4 concrete observe methods with recursive `withObservationTracking` pattern
  - Coordinator creates `settingsObserver` and calls `.start()` with callback closures
  - `deinit` does NOT call `stop()` (nonisolated deinit can't call @MainActor); tasks use `[weak self]`
  - Build verified

- [x] **3B** Create `MacAmpApp/Windows/WindowDelegateWiring.swift` ✓
  - Moved snap manager registration, delegate multiplexer creation, focus delegate creation
  - Static `wire()` factory returns struct holding strong refs to multiplexers + focus delegates
  - Iterates all 5 window kinds, sets up snap + persistence + focus delegates per window
  - Coordinator stores returned `WindowDelegateWiring?` (optional due to init order)
  - Removed 10 properties from coordinator (5 multiplexers + 5 focus delegates)
  - Build verified

- [x] **3-VERIFY** Phase 3 build + sanitizer ✓
  - Build: **SUCCEEDED**
  - Full test suite: **TEST SUCCEEDED** (with Thread Sanitizer)
  - Oracle review (gpt-5.3-codex, xhigh reasoning): **No concrete functional regressions found**
  - WindowCoordinator.swift: 583 → 408 lines (-30%, cumulative: 1,357 → 408, -70%)

---

## Phase 4: Layout Extension (Cosmetic) - APPROVED

- [x] **4A** Create `MacAmpApp/ViewModels/WindowCoordinator+Layout.swift` ✓
  - Moved `setDefaultPositions()`, `resetToDefaultStack()`, `applyInitialWindowLayout()`
  - Moved `configureWindows()`, `presentWindowsWhenReady()`, `presentInitialWindows()`
  - Moved `debugLogWindowPositions()`, `canPresentImmediately`, `LayoutDefaults`
  - Removed unused `windowKind(for:)` and persistence forwarding wrappers
  - Widened access: `skinManager`, `hasPresentedInitialWindows`, `skinPresentationTask` (private → internal)
  - Build verified (with Thread Sanitizer)

- [x] **4-VERIFY** Final build + full functional test ✓
  - Build with Thread Sanitizer: **SUCCEEDED**
  - Full test suite with TSan: **TEST SUCCEEDED**
  - WindowCoordinator.swift: 408 → 223 lines (cumulative: 1,357 → 223, -84%)
  - Extension: 153 lines
  - Oracle review (gpt-5.3-codex, xhigh reasoning): **No functional or blocking issues**

---

## Post-Refactoring

- [x] **5A** Update deprecated.md with patterns removed ✓
  - Documented all deprecated patterns replaced by refactoring
  - Compared old vs new patterns with code examples
  - Marked force-unwrapped singleton as deferred

- [x] **5B** Swift 6.2 compliance research ✓
  - swift-concurrency-expert skill review: Grade A+ (95/100)
  - Verified @MainActor isolation, Task lifecycle, withObservationTracking pattern
  - Confirmed alignment with 2025/2026 Swift best practices

- [x] **5C** Update `docs/MULTI_WINDOW_ARCHITECTURE.md` ✓
  - Added 290-line WindowCoordinator Refactoring section
  - Documented 11-file structure with dependency matrix
  - Explained Facade + Composition pattern, Swift 6.2 patterns
  - Updated docking pipeline to reference new files

- [x] **5D** Add dependency matrix diagram ✓
  - Included in MULTI_WINDOW_ARCHITECTURE.md §10
  - ASCII tree showing acyclic dependencies
  - Documented "no lateral dependencies" principle

- [x] **5E** Final comprehensive Oracle review ✓
  - gpt-5.3-codex comprehensive review of all 11 files
  - Found 2 HIGH/MEDIUM issues, fixed immediately:
    - Debounce cancellation guard in WindowFramePersistence
    - Handler nil-check in WindowSettingsObserver
  - Build + tests verified with Thread Sanitizer: **PASSED**
  - Final grade: A (92/100)

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
