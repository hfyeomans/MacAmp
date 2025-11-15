# Ready for Next Session

## Current State: v0.8.9 Released

**Branch:** main @ 744d5ec
**Tag:** v0.8.9
**Release Date:** 2025-11-15

## Completed Since Last Session

### Video & Milkdrop Windows (Part 21)
- [x] VIDEO window with full Winamp chrome (Ctrl+V)
- [x] Milkdrop window foundation with GEN.bmp sprites (Ctrl+K)
- [x] 5-window architecture (Main, EQ, Playlist, VIDEO, Milkdrop)
- [x] Size2D quantized resize model (25x29px segments)
- [x] Cyan preview box pattern (solved jitter during resize)
- [x] 1x/2x size presets with keyboard shortcuts (Ctrl+1, Ctrl+2)
- [x] Unified video controls (volume sync, time display, seek bar)
- [x] Active/inactive titlebar states for all windows
- [x] WindowFocusState for focus tracking across 5 windows
- [x] Oracle Grade A architecture compliance (3 reviews)
- [x] Comprehensive documentation (864 lines added)
- [x] 9 new patterns in BUILDING_RETRO_MACOS_APPS_SKILL.md
- [x] Focus ring removal (WinampButtonStyle)

### Documentation Updates
- [x] README.md: v0.8.9 release notes, video features, usage sections
- [x] docs/VIDEO_WINDOW.md: Bumped to v2.0.0 with Part 21 patterns
- [x] docs/README.md: 12 new search terms, 6 common questions
- [x] BUILDING_RETRO_MACOS_APPS_SKILL.md: Jitter solution, sprite extraction patterns

## Next Priority: Playlist Window Resizing

### Overview
The Playlist window currently has fixed dimensions. Next task is implementing Winamp-style resizing similar to VIDEO window.

### Proposed Approach
1. **Research Winamp behavior** - How does classic Winamp resize the playlist?
   - Horizontal and vertical resize handles
   - Minimum/maximum constraints
   - Track list scaling behavior

2. **Adapt Size2D model** - Reuse VIDEO window pattern
   - Quantized segments (different grid than VIDEO)
   - Playlist-specific constraints
   - Persistence via UserDefaults

3. **Chrome scaling** - Dynamic titlebar and borders
   - Similar to VIDEO window chrome
   - Reuse existing sprite patterns

4. **Content scaling** - Track list grows/shrinks
   - SwiftUI List view adaptation
   - Font scaling or more tracks visible

### Key Files to Modify
- `MacAmpApp/Views/WinampPlaylistWindow.swift`
- `MacAmpApp/Windows/WinampPlaylistWindowController.swift`
- `MacAmpApp/Models/AppSettings.swift` (add playlistSize: Size2D)
- `MacAmpApp/ViewModels/WindowCoordinator.swift`
- Possibly new `PlaylistWindowSizeState.swift`

### Success Criteria
- Drag-to-resize with preview overlay (reuse cyan box pattern)
- Quantized sizing with Winamp feel
- Minimum size constraints (readable track list)
- Persistence across app restarts
- Magnetic docking still works with resized playlist

## Other Potential Next Steps

### High Priority
- [ ] Playlist window resizing (see above)
- [ ] Butterchurn visualization integration (deferred from Part 21)
- [ ] Metadata display in Milkdrop window titlebar

### Medium Priority
- [ ] Main window shade mode (collapse to titlebar only)
- [ ] Mini browser / media library window
- [ ] Skin color scheme parsing for playlist

### Lower Priority
- [ ] macOS 26 Tahoe features (when available)
- [ ] App Store submission preparation
- [ ] Performance profiling and optimization

## Quick Start Commands

```bash
# Build with Thread Sanitizer
xcodebuild -scheme MacAmp -configuration Debug -enableThreadSanitizer YES

# Run app
open build/Debug/MacAmp.app

# Check current version
git describe --tags  # v0.8.9
```

## Oracle Consultation Template

For playlist resize planning:
```bash
codex "@MacAmpApp/Views/WinampPlaylistWindow.swift @MacAmpApp/Views/WinampVideoWindow.swift
Research playlist window resizing requirements:
- Compare VIDEO resize implementation
- Identify reusable patterns (Size2D, preview overlay)
- Playlist-specific constraints (min rows, column widths)
- Oracle recommendation for grid size"
```

## Session Notes

- Oracle Grade A maintained throughout Part 21
- Preview overlay pattern proven effective (zero jitter)
- WindowCoordinator bridge pattern solid for AppKit/SwiftUI separation
- 5-window clustering working correctly
- Thread Sanitizer clean (no races)

**Ready for playlist resize implementation!**
