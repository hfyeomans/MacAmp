# Playlist Window Resize - Current State

**Date:** 2025-12-14
**Branch:** `feat/playlist-window-resize`
**Status:** Oracle Review Complete, Ready for Implementation
**Oracle Grade:** A (upgraded from B, all issues addressed)

---

## Task Overview

| Field | Value |
|-------|-------|
| Task ID | playlist-resize |
| Priority | P2 (Important feature) |
| Estimate | 8-12 hours |
| Dependencies | None |
| Blocking | None |
| Reference | Video window resize (proven pattern) |

---

## Current MacAmp Status

### What Exists
- [x] Fixed-size playlist window (275×232 hard-coded)
- [x] Two-section bottom bar (LEFT + RIGHT, no CENTER)
- [x] Static scroll handle sprite (not functional)
- [x] PLEDIT.bmp sprites loaded
- [x] Playlist track rendering works
- [x] Window focus state tracking works

### What's Missing
- [ ] Three-section bottom bar layout (LEFT + CENTER + RIGHT)
- [ ] PlaylistWindowSizeState observable class
- [ ] Resize gesture with drag handle
- [ ] AppKit preview overlay during resize
- [ ] Functional scroll slider
- [ ] Dynamic sprite tiling for center section
- [ ] Size persistence to UserDefaults

### Known Bugs
1. **PLAYLIST_BOTTOM_RIGHT_CORNER width wrong**: Currently 154px, should be 150px
2. **Bottom bar offset**: Current HStack has 2px right shift hack
3. **Scroll handle static**: Shows at fixed position, doesn't scroll

---

## Code Locations

### Files to Modify
| File | Changes Needed |
|------|----------------|
| `MacAmpApp/Models/Size2D.swift` | Add `playlistMinimum`, `playlistDefault`, `playlist2xWidth` presets |
| `MacAmpApp/Models/SkinSprites.swift` | Fix PLAYLIST_BOTTOM_RIGHT_CORNER width (154→150) |
| `MacAmpApp/Views/WinampPlaylistWindow.swift` | Major refactor: 3-section layout, resize gesture, scroll slider |
| `MacAmpApp/ViewModels/WindowCoordinator.swift` | Add playlist resize coordinator methods with double-size scaling |

### Files to Create
| File | Purpose |
|------|---------|
| `MacAmpApp/Models/PlaylistWindowSizeState.swift` | Observable size state (copy VideoWindowSizeState) |
| `MacAmpApp/Views/Components/PlaylistScrollSlider.swift` | Scroll slider with bridge contract |

### Reference Files
| File | Why Useful |
|------|------------|
| `MacAmpApp/Models/VideoWindowSizeState.swift` | Pattern to copy |
| `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` | Resize handle pattern |

---

## Sprite Inventory

### Already Defined (SkinSprites.swift)
```swift
// Top bar
PLAYLIST_TOP_LEFT_SELECTED ✅
PLAYLIST_TITLE_BAR_SELECTED ✅
PLAYLIST_TOP_TILE_SELECTED ✅
PLAYLIST_TOP_RIGHT_CORNER_SELECTED ✅
PLAYLIST_TOP_LEFT_CORNER ✅
PLAYLIST_TITLE_BAR ✅
PLAYLIST_TOP_TILE ✅
PLAYLIST_TOP_RIGHT_CORNER ✅

// Side borders
PLAYLIST_LEFT_TILE ✅
PLAYLIST_RIGHT_TILE ✅

// Bottom bar
PLAYLIST_BOTTOM_LEFT_CORNER ✅
PLAYLIST_BOTTOM_RIGHT_CORNER ✅ (width bug: 154→150)
PLAYLIST_BOTTOM_TILE ✅

// Scroll
PLAYLIST_SCROLL_HANDLE ✅
PLAYLIST_SCROLL_HANDLE_SELECTED ✅
```

### Sprite Coordinates Verified
All PLEDIT sprites match webamp/skinSprites.ts coordinates.
Only issue is PLAYLIST_BOTTOM_RIGHT_CORNER width.

---

## Previous Research Reconciliation

### tasks/playlist-resize-analysis/ (older)
- Complete technical specification
- Sprite atlas diagrams
- SwiftUI implementation guide
- **Status:** Comprehensive but theoretical

### tasks/playlist-window-resize/ (older)
- Webamp analysis
- Three-section layout documented
- Connection to playlist-state-sync
- **Status:** Good research, incomplete state

### This Task (tasks/playlist-resize/)
- Consolidated research from both
- Video window as proven reference
- Ready for implementation
- **Status:** ACTIVE

---

## Implementation Dependencies

### Must Complete First
1. None - can start immediately

### Nice to Have Before
1. Thread Sanitizer clean build (verify no races)
2. Test with multiple skins to verify sprite loading

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AppKit/SwiftUI frame sync issues | Medium | High | Follow video window pattern exactly |
| Sprite alignment bugs | Medium | Medium | Test at multiple sizes: [0,0], [1,0], [2,2], [4,4] |
| Scroll slider complexity | Medium | Medium | Implement resize first, scroll second |
| Skin compatibility | Low | Medium | Test with classic Winamp skin + 2 others |

---

## Test Plan

### Manual Testing Checklist
- [ ] Build with Thread Sanitizer enabled
- [ ] Resize from minimum [0,0] to various sizes
- [ ] Verify center tiles appear/disappear correctly
- [ ] Verify scroll slider moves with playlist scroll
- [ ] Test 1x/2x preset buttons (if added)
- [ ] Test with Classic Winamp skin
- [ ] Test with Internet Archive skin
- [ ] Verify size persists across app restart

### Size Test Matrix
| Size | Pixels | Center Width | Tiles | Tracks |
|------|--------|--------------|-------|--------|
| [0,0] | 275×116 | 0px | 0 | 4 |
| [1,0] | 300×116 | 25px | 1 | 4 |
| [2,0] | 325×116 | 50px | 2 | 4 |
| [0,4] | 275×232 | 0px | 0 | 13 |
| [2,4] | 325×232 | 50px | 2 | 13 |
| [4,8] | 375×348 | 100px | 4 | 21 |

---

## Progress Tracking

### Phase 1: Foundation (1-2 hours) ✅ COMPLETE
- [x] 1.1 Fix PLAYLIST_BOTTOM_RIGHT_CORNER sprite width (154→150)
- [x] 1.2 Add playlist presets to Size2D.swift
- [x] 1.3 Create PlaylistWindowSizeState.swift
- [x] 1.4 Add to Xcode project

### Phase 2: Layout Refactor (2-3 hours) ✅ COMPLETE
- [x] 2.1 Inject PlaylistWindowSizeState environment
- [x] 2.2 Replace hard-coded dimensions
- [x] 2.3 Dynamic vertical border tiling
- [x] 2.4 Implement three-section bottom bar
- [x] 2.5 Dynamic content area
- [x] 2.6 Dynamic top bar tiling
- [x] 2.7 Titlebar spacer parity (even/odd width) - in PlaylistWindowSizeState
- [x] 2.8 Test layout at fixed default size - BUILD SUCCEEDED

### Phase 3: Resize Gesture (2-3 hours)
- [ ] 3.1 Add resize state variables
- [ ] 3.2 Implement buildResizeHandle()
- [ ] 3.3 Add WindowCoordinator methods
- [ ] 3.4 Integrate WindowSnapManager
- [ ] 3.5 Test resize gesture

### Phase 4: Scroll Slider (2-3 hours)
- [ ] 4.1 Define scroll slider bridge contract
- [ ] 4.2 Create PlaylistScrollSlider component
- [ ] 4.3 Add scroll offset state
- [ ] 4.4 Replace static scroll handle
- [ ] 4.5 Connect to ScrollView
- [ ] 4.6 Test scroll slider

### Phase 5: Integration & Polish (1-2 hours)
- [ ] 5.1 Wire up environment in app
- [ ] 5.2 Update button positions
- [ ] 5.3 Test size persistence
- [ ] 5.4 Test multiple sizes
- [ ] 5.5 Test with multiple skins
- [ ] 5.6 Thread Sanitizer check
- [ ] 5.7 Test double-size mode interaction
- [ ] 5.8 Test magnetic docking during resize

### Phase 6: Code Review & Documentation
- [ ] 6.1 Oracle (Codex) code review
- [ ] 6.2 Update state.md
- [ ] 6.3 Create PR

---

## Session Log

### 2025-12-14 (Grade A Upgrade)
- Enhanced plan.md with all missing architectural details
- Added "Architecture Decision: Sprite Resolution" section documenting legacy string choice
- Added Phase 2.6: Titlebar spacer parity with concrete Swift implementation
- Added Phase 4.1: Complete scroll slider bridge contract with layer responsibilities
- Added Phase 5.1: Double-size mode behavior specification with code
- Added Phase 5.2: Magnetic docking expected behavior and testing
- Oracle re-validation: **Grade A** confirmed
- Only implementation note: Apply thumb sizing formula during coding

### 2025-12-14 (Oracle Review - Initial)
- Conducted comprehensive Oracle (Codex) review with gpt-5.1-codex-max, xhigh reasoning
- **Grade: B** - Architectural alignment validated
- Strengths confirmed:
  - Three-layer pattern correctly followed
  - Video window pattern fidelity maintained
  - @MainActor/@Observable patterns correct
  - Size2D API usage matches codebase (width/height fields)
- Issues identified and todo.md updated:
  - 2.7: Titlebar spacer parity (even/odd width)
  - 2.8: Semantic sprite resolution (not hard-coded strings)
  - 4.4: Scroll slider bridge contract specification
  - 5.7: Double-size mode interaction testing
  - 5.8: Magnetic docking during resize testing
- Size2D.swift verified: `toPlaylistPixels()` already exists
- Sprite width bug confirmed: 154→150 still needed

### 2025-12-14 (Initial)
- Created branch `feat/playlist-window-resize`
- Consolidated research from 2 previous task folders
- Created fresh task folder with 4 files
- Documented video window reference pattern
- Ready for implementation

---

**Next Action:** Begin Phase 3 implementation (Resize Gesture)

### Session Log - 2025-12-16 (Phase 1 & 2 Complete)
- Fixed sprite width bug (SkinSprites.swift): 154→150px
- Added playlist presets to Size2D.swift: playlistMinimum, playlistDefault, playlist2xWidth
- Created PlaylistWindowSizeState.swift (~200 lines) with all computed properties
- Added file to Xcode project (PBXBuildFile, PBXFileReference, Models group, Sources phase)
- Injected PlaylistWindowSizeState via @State in WinampPlaylistWindow
- Replaced all hard-coded dimensions with dynamic computed values
- Implemented three-section bottom bar (LEFT 125px + CENTER tiles + RIGHT 150px)
- Dynamic vertical border tiling based on window height
- Dynamic top bar tiling based on window width
- Dynamic content area sizing
- All button positions now relative to window edges
- Build verified: **SUCCEEDED**
- **Commit:** 15f5a24 - feat(playlist): Phase 1 & 2 - Foundation and Dynamic Layout

### Resume Instructions
To resume Phase 3 implementation:
1. Read this state.md file
2. Read VideoWindowChromeView.swift for resize handle pattern
3. Implement buildResizeHandle() with DragGesture
4. Add WindowCoordinator methods for playlist resize
5. Integrate WindowSnapManager to prevent snapping during resize

### Files Modified in Phase 1 & 2
- MacAmpApp/Models/SkinSprites.swift (sprite width fix)
- MacAmpApp/Models/Size2D.swift (playlist presets)
- MacAmpApp/Models/PlaylistWindowSizeState.swift (NEW)
- MacAmpApp/Views/WinampPlaylistWindow.swift (major refactor)
- MacAmpApp.xcodeproj/project.pbxproj (new file reference)
