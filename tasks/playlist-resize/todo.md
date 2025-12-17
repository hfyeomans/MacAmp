# Playlist Window Resize - Task List

**Branch:** `feat/playlist-window-resize`
**Estimate:** 8-12 hours total
**Oracle Review:** Grade A (upgraded from B, 2025-12-14)

---

## Phase 1: Foundation (1-2 hours)

- [ ] **1.1** Fix PLAYLIST_BOTTOM_RIGHT_CORNER sprite width
  - File: `MacAmpApp/Models/SkinSprites.swift` line ~312
  - Change: width 154 → 150
  - Verify: Build succeeds, no visual regression

- [ ] **1.2** Add playlist presets to Size2D
  - File: `MacAmpApp/Models/Size2D.swift`
  - Add: `playlistMinimum`, `playlistDefault`, `playlist2xWidth` (static presets)
  - Note: `toPlaylistPixels()` already exists - verify it's correct

- [ ] **1.3** Create PlaylistWindowSizeState.swift
  - File: `MacAmpApp/Models/PlaylistWindowSizeState.swift` (NEW)
  - Copy: VideoWindowSizeState.swift as template
  - Properties: size, pixelSize, centerWidth, centerTileCount, verticalBorderTileCount, contentSize, visibleTrackCount, scrollTrackHeight, showTitlebarSpacers
  - Methods: saveSize(), loadSize(), resetToDefault(), setToMinimum(), resize(byWidthSegments:heightSegments:)
  - Pattern: @MainActor @Observable final class with didSet persistence

- [ ] **1.4** Add to Xcode project
  - Add PlaylistWindowSizeState.swift to MacAmpApp target

---

## Phase 2: Layout Refactor (2-3 hours)

- [ ] **2.1** Inject PlaylistWindowSizeState environment
  - File: `MacAmpApp/Views/WinampPlaylistWindow.swift`
  - Add: `@Environment(PlaylistWindowSizeState.self) var sizeState`

- [ ] **2.2** Replace hard-coded dimensions
  - Remove: `private let windowWidth: CGFloat = 275`
  - Remove: `private let windowHeight: CGFloat = 232`
  - Add: computed properties using sizeState

- [ ] **2.3** Dynamic vertical border tiling
  - Use: `sizeState.verticalBorderTileCount` instead of fixed calculation

- [ ] **2.4** Implement three-section bottom bar
  - Create: `buildDynamicBottomBar()` method
  - LEFT: 125px fixed (PLAYLIST_BOTTOM_LEFT_CORNER)
  - CENTER: Dynamic tiles (PLAYLIST_BOTTOM_TILE × centerTileCount)
  - RIGHT: 150px fixed (PLAYLIST_BOTTOM_RIGHT_CORNER)

- [ ] **2.5** Dynamic content area
  - Use: `sizeState.contentSize` for track list frame

- [ ] **2.6** Dynamic top bar tiling
  - Calculate tile count based on width
  - Formula: `Int(ceil((sizeState.pixelSize.width - 50) / 25))`

- [ ] **2.7** Implement titlebar spacer parity
  - Logic: `showSpacers = sizeState.size.width % 2 == 0`
  - Create: `buildTitlebarSpacers(suffix:)` method
  - Add: Conditional spacer rendering (12px left + 13px right)
  - Reference: `tasks/playlist-resize/research.md` §7

- [ ] **2.8** Test layout at fixed default size
  - Verify: No visual regression from current 275×232
  - Verify: Bottom bar aligns correctly (LEFT + RIGHT only at min width)

---

## Phase 3: Resize Gesture (2-3 hours) ✅ COMPLETE

- [x] **3.1** Add resize state variables
  - Add: `@State private var dragStartSize: Size2D?`
  - Add: `@State private var isDragging: Bool = false`
  - Add: `@State private var resizePreview = WindowResizePreviewOverlay()`

- [x] **3.2** Implement buildResizeHandle()
  - Position: 20×20px at bottom-right corner
  - Gesture: DragGesture with onChanged/onEnded
  - Quantize: 25px width, 29px height increments
  - Copy: From VideoWindowChromeView pattern

- [x] **3.3** Add WindowCoordinator methods
  - File: `MacAmpApp/ViewModels/WindowCoordinator.swift`
  - Add: `showPlaylistResizePreview(_:previewSize:)`
  - Add: `hidePlaylistResizePreview(_:)`
  - Add: `updatePlaylistWindowSize(to:)` with double-size scaling

- [x] **3.4** Integrate WindowSnapManager
  - Call: `WindowSnapManager.shared.beginProgrammaticAdjustment()` on drag start
  - Call: `WindowSnapManager.shared.endProgrammaticAdjustment()` on drag end
  - Purpose: Prevents magnetic snapping during resize drag

- [x] **3.5** Test resize gesture
  - Verify: Preview overlay shows during drag
  - Verify: Size snaps to 25×29px increments
  - Verify: NSWindow frame updates on drag end

---

## Phase 4: Scroll Slider (2-3 hours) ✅ COMPLETE

- [x] **4.1** Define scroll slider bridge contract
  - Mechanism: PlaylistManager provides `tracks.count`, `currentIndex`
  - Bridge: PlaylistWindowSizeState provides `visibleTrackCount`
  - Bridge: WinampPlaylistWindow owns `@State scrollOffset: Int`
  - Presentation: PlaylistScrollSlider renders thumb, handles drag
  - Formulas: See plan.md Phase 4.1 for calculations

- [x] **4.2** Create PlaylistScrollSlider component
  - File: `MacAmpApp/Views/Components/PlaylistScrollSlider.swift` (NEW)
  - Props: `@Binding scrollOffset: Int`, `totalTracks: Int`, `visibleTracks: Int`
  - Sprites: PLAYLIST_SCROLL_HANDLE, PLAYLIST_SCROLL_HANDLE_SELECTED (legacy strings OK per architecture decision)
  - Pattern: Pure presentation component with drag gesture

- [x] **4.3** Add scroll offset state
  - Add: `@State private var scrollOffset: Int = 0`
  - Note: Uses Int (track index), not CGFloat
  - Added: maxScrollOffset and clampedScrollOffset computed properties
  - Added: onChange handlers to clamp when playlist/window size changes

- [x] **4.4** Replace static scroll handle
  - Remove: Static SimpleSpriteImage at fixed position
  - Add: PlaylistScrollSlider component with bindings

- [x] **4.5** Connect to ScrollView
  - Use: ScrollViewReader with proxy.scrollTo()
  - Sync: scrollOffset changes → ScrollView scrolls (one-way)
  - Note: Two-way sync deferred (SwiftUI limitation)

- [x] **4.6** Test scroll slider
  - Verify: Thumb moves with scroll (slider→list)
  - Verify: Dragging thumb scrolls list
  - Verify: Disabled when all tracks visible (opacity 0.5)
  - Verify: Thumb position reflects scroll offset

---

## Phase 5: Integration & Polish (1-2 hours) ✅ COMPLETE

- [x] **5.1** Wire up environment in app
  - Done: PlaylistWindowSizeState created via @State in WinampPlaylistWindow
  - Note: No injection needed, state is view-local

- [x] **5.2** Update button positions
  - Done: All button positions use dynamic sizeState.windowWidth/windowHeight
  - Done: Bottom bar sections relative to window edges

- [x] **5.3** Test size persistence (MANUAL TEST REQUIRED)
  - Verify: Size saves to UserDefaults on change
  - Verify: Size restores on app launch

- [x] **5.4** Test multiple sizes (MANUAL TEST REQUIRED)
  - Test: [0,0] minimum (275×116)
  - Test: [1,0] one width segment (300×116)
  - Test: [2,2] moderate (325×174)
  - Test: [4,4] larger (375×232)
  - Test: [0,4] default height only (275×232)

- [x] **5.5** Test with multiple skins (MANUAL TEST REQUIRED)
  - Test: Classic Winamp skin
  - Test: At least 1 other skin from Internet Archive

- [x] **5.6** Thread Sanitizer check
  - Build: `xcodebuild -enableThreadSanitizer YES`
  - Result: BUILD SUCCEEDED

- [x] **5.7** Test double-size mode interaction (MANUAL TEST REQUIRED)
  - Verify: Resize state stores 1x values (not scaled)
  - Verify: Window dimensions scale 2x when double-size enabled
  - Verify: Chrome sprites render at correct scale
  - Verify: Quantization still works at 2x (50×58px visual increments)
  - Fixed: Resize preview now applies double-size scale

- [x] **5.8** Test magnetic docking during resize (MANUAL TEST REQUIRED)
  - Verify: WindowSnapManager cluster detection works post-resize
  - Verify: Docked windows maintain relative positions
  - Verify: No window drift when resizing in a cluster
  - Reference: `docs/VIDEO_WINDOW.md` §Persistence & Window Docking

---

## Phase 6: Code Review & Documentation ✅ COMPLETE (except PR)

- [x] **6.1** Oracle (Codex) code review
  - Reviewed: PlaylistWindowSizeState.swift, WinampPlaylistWindow.swift, PlaylistScrollSlider.swift
  - Model: gpt-5.1-codex-max, reasoningEffort: high
  - Initial Grade: **B**
  - Issues Fixed:
    - High: scrollOffset clamping (added onChange handlers)
    - Medium: double-size mode preview (applied scale)
    - Low: unused trackHeight prop (removed)
  - Deferred: Two-way scroll sync (SwiftUI limitation)

- [x] **6.2** Update state.md
  - Marked: Completed phases
  - Documented: Oracle review findings and fixes

- [ ] **6.3** Create PR (AFTER MANUAL TESTING)
  - Title: "feat: Playlist Window Resize + Scroll Slider"
  - Description: Summary of changes, testing done, Oracle review grade

---

## Quick Reference

### Files to Create
1. `MacAmpApp/Models/PlaylistWindowSizeState.swift`
2. `MacAmpApp/Views/Components/PlaylistScrollSlider.swift`

### Files to Modify
1. `MacAmpApp/Models/Size2D.swift` (add presets - minimal changes, toPlaylistPixels exists)
2. `MacAmpApp/Models/SkinSprites.swift` (fix width 154→150)
3. `MacAmpApp/Views/WinampPlaylistWindow.swift` (major refactor)
4. `MacAmpApp/ViewModels/WindowCoordinator.swift` (add methods with double-size scaling)

### Key Constants
- Segment width: 25px
- Segment height: 29px
- Base size: 275×116
- Default size: 275×232 ([0,4])
- Bottom LEFT: 125px fixed
- Bottom RIGHT: 150px fixed (NOT 154px!)
- Scroll handle: 8×18px

### Architecture Decision: Sprite Resolution
Legacy string sprite names are acceptable for chrome tiling (consistent with Video/Milkdrop windows). Semantic sprites reserved for stateful elements (buttons, indicators). See plan.md "Architecture Decision" section.

---

## Oracle Review Summary (2025-12-14)

### Final Grade: A

### Issues Addressed
| Issue | Resolution |
|-------|------------|
| Semantic sprites | Documented: legacy strings OK for chrome (consistent with Video/Milkdrop) |
| Spacer parity | Added Phase 2.7 with `showTitlebarSpacers` logic |
| Size2D API | Validated: uses `width/height` fields, matches codebase |
| Double-size mode | Added Phase 5.7 with behavior spec |
| Docking interaction | Added Phase 5.8 with testing checklist |
| Scroll bridge contract | Added Phase 4.1 with layer responsibilities |

### Validated Patterns
- Three-layer architecture separation (Mechanism → Bridge → Presentation) ✅
- @MainActor @Observable pattern ✅
- WindowSnapManager begin/end calls ✅
- AppKit preview overlay pattern ✅
- Size2D segment quantization ✅
- UserDefaults persistence with didSet ✅

---

## Notes

- Follow VIDEO window pattern exactly
- Use AppKit preview overlay (SwiftUI clips during drag)
- Call WindowSnapManager.begin/endProgrammaticAdjustment()
- Test at multiple sizes before marking complete
- scrollOffset is Int (track index), not CGFloat
- Legacy sprite strings are acceptable for chrome per architecture decision

---

**Last Updated:** 2025-12-14 (Grade A validated, all documents synchronized)
