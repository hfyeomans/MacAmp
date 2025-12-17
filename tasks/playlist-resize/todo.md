# Playlist Window Resize - Task List

**Branch:** `feat/playlist-window-resize`
**Status:** ✅ COMPLETE
**Oracle Review:** Grade A- (Architecture Aligned)
**Completed:** 2025-12-16

---

## Phase 1: Foundation ✅ COMPLETE

- [x] **1.1** Fix PLAYLIST_BOTTOM_RIGHT_CORNER sprite width
  - File: `MacAmpApp/Models/SkinSprites.swift` line ~312
  - Change: width 154 → 150

- [x] **1.2** Add playlist presets to Size2D
  - File: `MacAmpApp/Models/Size2D.swift`
  - Added: `playlistMinimum`, `playlistDefault`, `playlist2xWidth`

- [x] **1.3** Create PlaylistWindowSizeState.swift
  - File: `MacAmpApp/Models/PlaylistWindowSizeState.swift`
  - Pattern: @MainActor @Observable final class with didSet persistence

- [x] **1.4** Add to Xcode project

---

## Phase 2: Layout Refactor ✅ COMPLETE

- [x] **2.1** Inject PlaylistWindowSizeState environment
- [x] **2.2** Replace hard-coded dimensions
- [x] **2.3** Dynamic vertical border tiling
- [x] **2.4** Implement three-section bottom bar
- [x] **2.5** Dynamic content area
- [x] **2.6** Dynamic top bar tiling
- [x] **2.7** Implement titlebar spacer parity
- [x] **2.8** Test layout at fixed default size

---

## Phase 3: Resize Gesture ✅ COMPLETE

- [x] **3.1** Add resize state variables
- [x] **3.2** Implement buildResizeHandle()
- [x] **3.3** Add WindowCoordinator methods
- [x] **3.4** Integrate WindowSnapManager
- [x] **3.5** Test resize gesture

---

## Phase 4: Scroll Slider ✅ COMPLETE

- [x] **4.1** Define scroll slider bridge contract
- [x] **4.2** Create PlaylistScrollSlider component
- [x] **4.3** Add scroll offset state
- [x] **4.4** Replace static scroll handle
- [x] **4.5** Connect to ScrollView
- [x] **4.6** Test scroll slider

---

## Phase 5: Integration & Polish ✅ COMPLETE

- [x] **5.1** Wire up environment in app
- [x] **5.2** Update button positions
- [x] **5.3** Test size persistence
- [x] **5.4** Test multiple sizes
- [x] **5.5** Test with multiple skins
- [x] **5.6** Thread Sanitizer check
- [x] **5.7** Test double-size mode interaction
- [x] **5.8** Test magnetic docking during resize

---

## Phase 6: Code Review & Documentation ✅ COMPLETE

- [x] **6.1** Oracle (Codex) code review - Grade A-
- [x] **6.2** Update state.md
- [x] **6.3** Create PLAYLIST_WINDOW.md documentation
- [x] **6.4** Update docs/README.md

---

## Phase 7: Bug Fixes (Oracle Review) ✅ COMPLETE

- [x] **7.1** Fix NSWindow constraints in WinampPlaylistWindowController
  - Old: minSize=275×232, maxSize=275×900 (blocked horizontal resize)
  - New: minSize=275×116, maxSize=2000×900

- [x] **7.2** Fix WindowCoordinator.applyPersistedWindowPositions
  - Preserve stored width (don't force to 275px)
  - Use correct base height (116px, not 232px)

- [x] **7.3** Add onAppear/onChange hooks for NSWindow sync
  - Sync NSWindow from PlaylistWindowSizeState on launch
  - Sync on programmatic size changes

---

## Oracle Review Summary

### Initial Grade: B → Final Grade: A-

### Architecture Alignment: ✅ ALIGNED

| Pattern | Status |
|---------|--------|
| Three-Layer (Mechanism→Bridge→Presentation) | ✅ |
| @Observable + @MainActor | ✅ |
| UserDefaults via didSet | ✅ |
| Environment Injection | ✅ |
| Window Controller Pattern | ✅ |
| Focus State Integration | ✅ |
| Video Window Pattern Parity | ✅ |

### Minor Recommendation (Non-blocking)
Consider migrating `WindowCoordinator.shared` to environment injection for better testability.

---

## Files Created
1. `MacAmpApp/Models/PlaylistWindowSizeState.swift`
2. `MacAmpApp/Views/Components/PlaylistScrollSlider.swift`
3. `docs/PLAYLIST_WINDOW.md`

## Files Modified
1. `MacAmpApp/Models/Size2D.swift`
2. `MacAmpApp/Models/SkinSprites.swift`
3. `MacAmpApp/Views/WinampPlaylistWindow.swift`
4. `MacAmpApp/ViewModels/WindowCoordinator.swift`
5. `MacAmpApp/Windows/WinampPlaylistWindowController.swift`
6. `docs/README.md`

---

**Task Complete.** All phases implemented, Oracle validated (Grade A-), documentation created.
