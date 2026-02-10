# Task State: WindowCoordinator.swift Refactoring

## Current Phase: Phase 1 Complete (Oracle Verified)

## Status: Phase 1 Verified - Ready for Commit & Phase 2

## Branch: `refactor/window-coordinator-decomposition`

## Context
- **File:** `MacAmpApp/ViewModels/WindowCoordinator.swift`
- **Original Size:** 1,357 lines
- **Current Size:** 1,127 lines (-230 lines, -17%)
- **Issue:** God object with 10 orthogonal responsibilities, exceeds linting threshold
- **Goal:** Decompose into focused types using Facade + Composition pattern
- **Target:** ~200 lines in WindowCoordinator.swift (-85%)

## Phase 1 Results

### Files Created
| File | Lines | Purpose |
|------|-------|---------|
| `MacAmpApp/Windows/WindowDockingTypes.swift` | 50 | Value types: PlaylistAttachmentSnapshot, VideoAttachmentSnapshot, PlaylistDockingContext |
| `MacAmpApp/Windows/WindowDockingGeometry.swift` | 109 | Pure geometry: 4 static methods, nonisolated struct |
| `MacAmpApp/Windows/WindowFrameStore.swift` | 65 | Persistence: PersistedWindowFrame, WindowFrameStore, WindowKind.persistenceKey |
| `Tests/MacAmpTests/WindowDockingGeometryTests.swift` | 101 | 7 test methods covering all geometry functions |
| `Tests/MacAmpTests/WindowFrameStoreTests.swift` | 51 | 3 test methods (roundtrip, save/load, nil) |

### Build & Test Status
- Build: **SUCCEEDED**
- Phase 1 tests (10 tests): **ALL PASS**
- Full test suite: **ALL PASS**

### Additional Fixes
- Fixed pre-existing broken `PlaylistNavigationTests.swift` (`player.playlist` is read-only; changed to `player.playlistController.addTrack()`)
- Cleaned all stale comments per depreciated.md (`// NEW:`, `// CRITICAL FIX #3:`, `// NOTE:`)

### Pre-Existing Broken Tests Found
- `PlaylistNavigationTests.swift` had compilation error: `Cannot assign to property: 'playlist' is a get-only property` (fixed — used `playlistController.addTrack()` instead)

## Oracle Review (Post-Phase 1)
- **Model:** gpt-5.3-codex, reasoningEffort: xhigh
- **Finding:** [P2] Test files were in PBXBuildFile but NOT in MacAmpTests PBXSourcesBuildPhase
- **Impact:** Tests were discovered by Xcode via group membership but not formally in build phase — could cause CI gaps
- **Fix Applied:** Added `095F23474597A1E26C0CDDFD` and `2E7AF1F816A6079309895544` to MacAmpTests PBXSourcesBuildPhase
- **Secondary fix:** `WindowFrameStoreTests.swift` had `CGFloat?` to `Double` type mismatch in `XCTAssertEqual` accuracy overload — fixed with `XCTUnwrap`
- **Post-fix status:** All tests pass (`** TEST SUCCEEDED **`)

## Research Completed
- [x] Read all related docs (Architecture Guide, Multi-Window, Window Focus, etc.)
- [x] Analyzed full dependency graph (13 files reference WindowCoordinator)
- [x] Researched Swift 6.2+ concurrency patterns
- [x] Researched macOS window management patterns
- [x] Swift concurrency skill audit (5 findings, all addressed in plan)

## Oracle Reviews
- **Pre-implementation:** gpt-5.3-codex, reasoningEffort: xhigh → REVISE then proceed (revisions applied)
- **Post-Phase 1:** gpt-5.3-codex, reasoningEffort: xhigh → 1 finding (P2: test build phase), fixed

## Next Steps
1. Commit Phase 1 changes on feature branch
2. Begin Phase 2 implementation (extract controllers: WindowRegistry, WindowFramePersistence, WindowVisibilityController, WindowResizeController)
