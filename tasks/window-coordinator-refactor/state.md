# Task State: WindowCoordinator.swift Refactoring

## Current Phase: Phase 2 Complete

## Status: Ready for Phase 3 (Extract Observation & Wiring)

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

## Line Count Summary
| File | Lines |
|------|-------|
| WindowCoordinator.swift | 583 |
| WindowRegistry.swift | 83 |
| WindowFramePersistence.swift | 145 |
| WindowVisibilityController.swift | 161 |
| WindowResizeController.swift | 313 |
| **Total** | **1,285** |

## Next Steps
1. Commit Phase 2 changes
2. Implement Phase 3A: Extract WindowSettingsObserver.swift
3. Implement Phase 3B: Extract WindowDelegateWiring.swift
4. Run 3-VERIFY: Full build + tests + Oracle review
