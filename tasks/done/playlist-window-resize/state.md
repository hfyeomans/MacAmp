# Playlist Window Resize - Current State

**Date:** 2025-12-16
**Branch:** `feat/playlist-window-resize`
**Status:** Phase 3-5 Complete + Playlist Visualizer Implemented

---

## Session Summary (2025-12-16)

### Completed This Session

1. **Playlist Visualizer Research** (Gemini verified)
   - Documented how playlist mini visualizer differs from main window
   - Key finding: Same `<Vis />` component reused, shows when main window is SHADED
   - Corrected terminology: "closed" → "shaded" (closing main window closes app)

2. **Main Window Shade State Migration**
   - Added `isMainWindowShaded` to `AppSettings` (observable, persisted)
   - Migrated `WinampMainWindow` from local `@State` to AppSettings
   - Enables cross-window observation (playlist knows when main is shaded)

3. **Playlist Mini Visualizer Implementation**
   - Added `VisualizerView` to playlist bottom-right section
   - Only shows when `settings.isMainWindowShaded == true`
   - Renders 76px, clips to 72px (historical accuracy per Gemini)
   - Position: `x=windowWidth-187, y=windowHeight-18`

4. **Bug Fixes**
   - Fixed menu "Shade/Unshade Main" toggling wrong state
   - Fixed shade mode ZStack alignment (buttons were offscreen)

### Commits This Session
```
6d848b1 fix(main-window): Fix shade mode buttons not clickable
5c849f2 fix(main-window): Fix shade/unshade menu command
62c9039 feat(playlist): Add mini visualizer when main window is shaded
2f9771c docs(playlist): Reconcile visualizer research with Gemini verification
2da453c docs(playlist): Add playlist visualizer research section
```

---

## Overall Progress

### ✅ Completed Phases

**Phase 1: Foundation** (commit 15f5a24)
- [x] `PlaylistWindowSizeState` model with size units
- [x] Content dimensions calculation
- [x] Environment injection pattern

**Phase 2: Dynamic Layout** (commit 15f5a24)
- [x] Three-section top bar (LEFT + TILES + TITLE + TILES + RIGHT)
- [x] Three-section bottom bar (LEFT + TILES + VISUALIZER + RIGHT)
- [x] Dynamic center tile rendering

**Phase 3: Resize Gesture** (commit 067d7ac)
- [x] Resize handle in bottom-right corner
- [x] Drag gesture with size constraints
- [x] Preview overlay during resize

**Phase 4: Scroll Slider** (commit 067d7ac)
- [x] `PlaylistScrollSlider` component
- [x] Binding to scroll offset
- [x] Slider scales with content height

**Phase 5: Visualizer Area** (commit 067d7ac)
- [x] Background sprite (`PLAYLIST_VISUALIZER_BACKGROUND`)
- [x] Conditional visibility based on width

**Phase 6: Mini Visualizer** (commit 62c9039) ← NEW
- [x] `VisualizerView` reuse in playlist
- [x] Shade state in AppSettings
- [x] Cross-window observation working
- [x] Correct positioning and clipping

### ⏳ Remaining Work

**Phase 7: Window Shading (Future)**
- [ ] Window shade mode for all windows (not just main)
- [ ] Shade mode dimensions (275×14)
- [ ] Shade-specific UI rendering

**Phase 8: Polish**
- [ ] Test with multiple skins
- [ ] Performance optimization
- [ ] Edge case handling

---

## Key Files Modified

### Core Implementation
- `MacAmpApp/Models/PlaylistWindowSizeState.swift` - Size state model
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - Dynamic layout + visualizer
- `MacAmpApp/Models/AppSettings.swift` - Added `isMainWindowShaded`
- `MacAmpApp/Views/WinampMainWindow.swift` - Shade state migration
- `MacAmpApp/AppCommands.swift` - Fixed menu command

### Research Documentation
- `tasks/playlist-window-resize/research.md` - Comprehensive visualizer research

---

## Technical Architecture

### Playlist Visualizer Visibility Logic
```swift
// Two conditions must be true:
let showVisualizer = sizeState.size.width >= 3   // Playlist wide enough
let activateVisualizer = settings.isMainWindowShaded  // Main window shaded

if showVisualizer && activateVisualizer {
    VisualizerView()
        .frame(width: 76, height: 16)           // Render full size
        .frame(width: 72, alignment: .leading)  // Clip to 72px
        .clipped()
        .position(x: windowWidth - 187, y: windowHeight - 18)
}
```

### Shade State Flow
```
AppSettings.isMainWindowShaded (source of truth, persisted)
    ↓
WinampMainWindow reads → shows full/shade mode
    ↓
WinampPlaylistWindow reads → shows/hides mini visualizer
    ↓
AppCommands reads → updates menu item text
```

---

## Known Issues

### Resolved This Session
1. ✅ Menu "Shade/Unshade Main" wasn't syncing with window state
2. ✅ Shade mode buttons not clickable (ZStack alignment)

### Outstanding
1. ⚠️ Window shading not implemented for EQ/Playlist windows
2. ⚠️ Classic skin visualizer works, modern skins may differ

---

## Resume Instructions

### To Continue Development
```bash
cd /Users/hank/dev/src/MacAmp
git checkout feat/playlist-window-resize
git status  # Check for uncommitted changes
```

### Build & Test
```bash
xcodebuild -scheme MacAmpApp -configuration Debug build
# Or open MacAmp.xcodeproj in Xcode
```

### Test Visualizer
1. Run MacAmp
2. Expand playlist window to ≥350px width
3. Click shade button on main window titlebar
4. Verify: Main window shades (14px bar), playlist visualizer appears

---

## References

- **Research:** `tasks/playlist-window-resize/research.md`
- **Webamp Source:** `webamp_clone/packages/webamp/js/components/PlaylistWindow/`
- **Webamp Docs:** `webamp_clone/packages/webamp-docs/docs/05_features/04_playlist.md`
- **MacAmp Visualizer:** `MacAmpApp/Views/VisualizerView.swift`

---

**Last Updated:** 2025-12-16
**Next Session:** Window shading for all windows, or Phase 8 polish
