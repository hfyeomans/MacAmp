# Task State: WindowCoordinator.swift Refactoring

## Current Phase: Phase 3 Complete

## Status: Ready for Phase 4 (Layout Extension)

## Branch: `refactor/window-coordinator-decomposition`

## Context
- **File:** `MacAmpApp/ViewModels/WindowCoordinator.swift`
- **Original Size:** 1,357 lines
- **Current Size:** 583 lines (after Phase 2 extractions, -57%)
- **Issue:** God object with 10 orthogonal responsibilities, exceeds linting threshold
- **Goal:** Decompose into focused types using Facade + Composition pattern
- **Target:** ~200 lines in WindowCoordinator.swift (-85%)

## Phase 1 Results (Committed: `89c9150`)

### Files Created
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowDockingTypes.swift` | 50 | Value types: PlaylistAttachmentSnapshot, VideoAttachmentSnapshot, PlaylistDockingContext |
| `MacAmpApp/Windows/WindowDockingGeometry.swift` | 109 | Pure geometry: 4 static methods, nonisolated struct |
| `MacAmpApp/Windows/WindowFrameStore.swift` | 65 | Persistence: PersistedWindowFrame, WindowFrameStore, WindowKind.persistenceKey |
| `Tests/MacAmpTests/WindowDockingGeometryTests.swift` | 101 | 7 test methods covering all geometry functions |
| `Tests/MacAmpTests/WindowFrameStoreTests.swift` | 51 | 3 test methods (roundtrip, save/load, nil) |

## Phase 2 Results (Complete)

### 2A: WindowRegistry.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowRegistry.swift` | 83 | Owns 5 NSWindowController instances, window lookup by kind |

- Coordinator forwards `mainWindow`, `eqWindow`, etc. as computed properties
- `liveAnchorFrame()` and `windowKind(for:)` forward to registry
- Build: **SUCCEEDED**

### 2B: WindowFramePersistence.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowFramePersistence.swift` | 145 | Frame persistence, suppression, WindowPersistenceDelegate |

- Coordinator forwards: `persistAllWindowFrames()`, `schedulePersistenceFlush()`, `applyPersistedWindowPositions()`
- Coordinator forwards: `beginSuppressingPersistence()`, `endSuppressingPersistence()`, `performWithoutPersistence()`
- Removed: `windowFrameStore` property, old nested `WindowPersistenceDelegate`, `LayoutDefaults.playlistMaxHeight`
- Build: **SUCCEEDED**

### 2C: WindowVisibilityController.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowVisibilityController.swift` | 161 | Show/hide/toggle for all windows, @Observable visibility state |

- Moved `isEQWindowVisible`, `isPlaylistWindowVisible` observable properties
- Moved all show/hide/toggle methods for EQ, Playlist, Video, Milkdrop, Main
- Moved `showAllWindows()`, `focusAllWindows()`, `minimizeKeyWindow()`, `closeKeyWindow()`
- Coordinator forwards via computed get/set properties (observation chaining verified)
- Build: **SUCCEEDED**

### 2D: WindowResizeController.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowResizeController.swift` | 313 | Resize, docking-aware layout, resize preview overlays |

- Moved `resizeMainAndEQWindows()` + docking context builders
- Moved `lastPlaylistAttachment`, `lastVideoAttachment` state
- Moved all update*WindowSize() methods, move methods, resize preview methods
- Moved debug logging helpers
- Build: **SUCCEEDED**

### 2-VERIFY: PASSED
- Build: **SUCCEEDED**
- Full test suite: **TEST SUCCEEDED**
- Oracle review (gpt-5.3-codex, xhigh reasoning): **No concrete defects found**

## Oracle Reviews
- **Pre-implementation:** gpt-5.3-codex, reasoningEffort: xhigh -> REVISE then proceed (revisions applied)
- **Post-Phase 1:** gpt-5.3-codex, reasoningEffort: xhigh -> 1 finding (P2: test build phase), fixed
- **Post-Phase 2:** gpt-5.3-codex, reasoningEffort: xhigh -> No concrete defects found
- **Post-Phase 3:** gpt-5.3-codex, reasoningEffort: xhigh -> No concrete functional regressions found

## Phase 3 Results (In Progress)

### 3A: WindowSettingsObserver.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowSettingsObserver.swift` | 114 | Settings observation with start/stop lifecycle |

- Moved 4 observation tasks from coordinator (alwaysOnTop, doubleSize, showVideo, showMilkdrop)
- Stores `@MainActor` closures in `Handlers` struct
- Uses recursive `withObservationTracking` pattern with `[weak self]` captures
- Coordinator calls `.start()` with callback closures in init
- Build: **SUCCEEDED**

### 3B: WindowDelegateWiring.swift - COMPLETE
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowDelegateWiring.swift` | 56 | Static factory for delegate multiplexer + focus delegate wiring |

- Static `wire()` factory returns struct with strong refs to multiplexers + focus delegates
- Iterates all 5 window kinds, registers snap manager + persistence + focus delegates
- Coordinator stores as `WindowDelegateWiring?` (optional due to init ordering)
- Removed 10 properties from coordinator (5 multiplexers + 5 focus delegates)
- Build: **SUCCEEDED**

### 3-VERIFY: PASSED
- Build: **SUCCEEDED**
- Full test suite: **TEST SUCCEEDED** (with Thread Sanitizer)
- Oracle review (gpt-5.3-codex, xhigh reasoning): **No concrete functional regressions found**

## Line Count Summary
| File | Lines |
|------|-------|
| WindowCoordinator.swift | 408 |
| WindowRegistry.swift | 83 |
| WindowFramePersistence.swift | 146 |
| WindowVisibilityController.swift | 161 |
| WindowResizeController.swift | 312 |
| WindowSettingsObserver.swift | 114 |
| WindowDelegateWiring.swift | 56 |
| WindowDockingTypes.swift | 50 |
| WindowDockingGeometry.swift | 109 |
| WindowFrameStore.swift | 65 |
| **Total** | **1,504** |

## Next Steps
1. Commit Phase 3 changes
2. Implement Phase 4: Extract WindowCoordinator+Layout.swift extension
3. Post-refactoring: update docs, final Oracle review
