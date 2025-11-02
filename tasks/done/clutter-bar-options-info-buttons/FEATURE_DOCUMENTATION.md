# O & I Buttons - Feature Documentation

**Feature:** Clutter Bar Options and Track Info Buttons
**Version:** v0.7.8
**Date:** 2025-11-02
**Status:** ✅ Production Ready

---

## 📖 User Guide

### O Button (Options Menu)

The O button opens a context menu with quick access to player settings.

**Location:** Left side of main window, first button in clutter bar

**How to Use:**
1. Click the O button, OR
2. Press Ctrl+O

**Menu Items:**
- **Time: Elapsed** - Show time elapsed since track start (default)
- **Time: Remaining** - Show time remaining until track end (shows minus sign)
- **Double Size** - Toggle window size between 100% and 200% (Ctrl+D)
- **Repeat** - Enable/disable repeat mode (Ctrl+R)
- **Shuffle** - Enable/disable shuffle mode (Ctrl+S)

**Visual Feedback:**
- Active menu items show checkmarks (✓)
- Menu positioned directly below O button

**Keyboard Shortcuts:**
- **Ctrl+O** - Open options menu
- **Ctrl+T** - Toggle time display mode

---

### I Button (Track Information)

The I button opens a dialog showing detailed metadata for the currently playing track or stream.

**Location:** Left side of main window, third button in clutter bar

**How to Use:**
1. Click the I button, OR
2. Press Ctrl+I

**Displayed Information:**

**For Local Tracks:**
- Title and artist (if available)
- Duration (MM:SS format)
- Bitrate (when reported)
- Sample rate (when reported)
- Channel configuration (Mono/Stereo)

**For Radio Streams:**
- Stream title/station name
- Technical details (when available)
- Note indicating limited metadata

**For No Playback:**
- "No track or stream loaded" message

**Visual Feedback:**
- I button shows selected state (highlighted) while dialog is open
- Dialog centered on screen

**Keyboard Shortcuts:**
- **Ctrl+I** - Open track information dialog

**Dismissal:**
- Click "Close" button, OR
- Press Esc key, OR
- Click outside dialog (if macOS allows)

---

### Time Display Toggle

Click the time display or use keyboard shortcuts to toggle between elapsed and remaining time.

**Modes:**
1. **Elapsed Time** (default)
   - Shows: 00:00 to track duration
   - No minus sign

2. **Remaining Time**
   - Shows: -duration to -00:00
   - Minus sign displayed (centered vertically)

**How to Toggle:**
1. Click directly on the time display (39, 26 on main window), OR
2. Press Ctrl+T, OR
3. Open O button menu and select desired mode

**Persistence:**
- Selected mode persists across app restarts
- Synchronized across all controls (time display, O menu, shortcuts)

---

## 🎹 Keyboard Shortcuts Reference

| Shortcut | Action | Notes |
|----------|--------|-------|
| Ctrl+O | Open Options Menu | Menu appears at O button position |
| Ctrl+T | Toggle Time Display | Cycles elapsed ⇄ remaining |
| Ctrl+I | Open Track Info | Shows metadata dialog |
| Ctrl+D | Toggle Double Size | Existing, accessible via O menu |
| Ctrl+A | Toggle Always On Top | Existing |
| Ctrl+R | Toggle Repeat | Existing, accessible via O menu |
| Ctrl+S | Toggle Shuffle | Existing, accessible via O menu |

**No Conflicts:** All shortcuts tested and verified non-conflicting

---

## 🔧 Technical Details

### Architecture

**State Management:**
- Uses `@Observable` AppSettings as single source of truth
- TimeDisplayMode persisted with `didSet` + UserDefaults pattern
- Dialog state is transient (not persisted across restarts)

**Menu Implementation:**
- NSMenu via AppKit bridge (better control than SwiftUI Menu)
- MenuItemTarget class bridges closures to NSMenuItem actions
- Strong reference via @State prevents premature deallocation
- Window detection filters by size characteristics

**Dialog Implementation:**
- SwiftUI sheet with proper binding to AppSettings
- Reads AudioPlayer for technical details
- Falls back to PlaybackCoordinator for stream metadata
- Dismissible via button, Esc key, or click-outside

### Sprite Coordinates

**O Button:**
- Normal: (x: 304, y: 3, width: 8, height: 8)
- Selected: (x: 304, y: 47, width: 8, height: 8)

**I Button:**
- Normal: (x: 304, y: 18, width: 8, height: 7)
- Selected: (x: 304, y: 62, width: 8, height: 7)

**Minus Sign:**
- Sprite: (x: 20, y: 6, width: 5, height: 1)
- Container: 9x13 frame with y:6 offset for centering

### Dependencies

**O Button:**
- AppSettings.timeDisplayMode (new)
- AppSettings.isDoubleSizeMode (existing)
- AudioPlayer.repeatEnabled (existing)
- AudioPlayer.shuffleEnabled (existing)

**I Button:**
- AudioPlayer.currentTrack (existing)
- AudioPlayer.bitrate, sampleRate, channelCount (existing)
- PlaybackCoordinator.currentTitle (fallback for streams)

---

## 🎨 UI/UX Design

### Menu Design
- Standard macOS context menu appearance
- Checkmarks for active states
- Keyboard equivalents shown
- Separator between sections

### Dialog Design
- Clean, minimal layout
- Label-value pairs with right-aligned labels
- Graceful handling of missing metadata
- Clear messaging for edge cases

### Visual Feedback
- I button highlights when dialog is open
- O button tooltip shows available shortcuts
- Checkmarks update in real-time

---

## ⚠️ Known Limitations

### Current Behavior

1. **O Button Menu Position**
   - Menu always appears below button
   - No edge detection (could go off-screen on small displays)
   - Acceptable: macOS handles menu repositioning automatically

2. **Track Info Read-Only**
   - Metadata is displayed but not editable
   - ID3 tag writing deferred to future version
   - Acceptable: Viewing is primary use case

3. **Limited Stream Metadata**
   - Some streams don't provide bitrate/sample rate
   - Dialog shows "Limited metadata available"
   - Acceptable: Limitation of streaming protocols

### Future Enhancements (P3)

1. Album artwork display in track info dialog
2. ID3 tag editing capability
3. EQ presets in options menu
4. Skins submenu in options menu
5. O button selected state while menu open

**None are blockers for current release.**

---

## 📝 Maintenance Notes

### For Future Developers

**Adding Menu Items to O Button:**
1. Add item in `showOptionsMenu(from:)` method
2. Create @objc action method or MenuItemTarget closure
3. Add keyboard shortcut in AppCommands.swift if desired

**Adding Fields to I Button Dialog:**
1. Edit TrackInfoView.swift
2. Add InfoRow for new field
3. Add conditional check if field might be missing
4. Test with tracks that lack the field

**Modifying Time Display:**
- Time display logic is in `buildTimeDisplay()` method
- Mode controlled by `AppSettings.timeDisplayMode`
- Persistence automatic via didSet pattern

### Code Locations

| Component | File | Line(s) |
|-----------|------|---------|
| O Button | WinampMainWindow.swift | 522-529 |
| Options Menu | WinampMainWindow.swift | 803-912 |
| I Button | WinampMainWindow.swift | 541-553 |
| Track Info Dialog | TrackInfoView.swift | 1-120 |
| Time Display | WinampMainWindow.swift | 291-352 |
| TimeDisplayMode | AppSettings.swift | 165-182 |
| Keyboard Shortcuts | AppCommands.swift | 42-55 |

---

## 🧪 Testing Guide

### Manual Testing

**Test O Button:**
```
1. Click O button
2. Verify menu appears below button
3. Click "Time: Remaining"
4. Verify checkmark moves
5. Restart app
6. Open O menu
7. Verify "Time: Remaining" still checked
```

**Test I Button:**
```
1. Load and play a track
2. Click I button
3. Verify metadata displays correctly
4. Close dialog
5. Play a radio stream
6. Click I button
7. Verify stream info displays
```

**Test Keyboard Shortcuts:**
```
1. Press Ctrl+O → menu appears
2. Press Ctrl+T → time toggles
3. Press Ctrl+I → dialog opens
4. Focus playlist window
5. Press Ctrl+O → menu still appears at main window
```

### Automated Testing

Currently manual testing only. Future: Add UI tests for menu/dialog interaction.

---

## 🔗 Related Features

- **D Button (Double Size):** tasks/done/double-size-button/
- **A Button (Always On Top):** Implemented alongside D button
- **V Button (Visualizer):** Scaffolded, pending implementation
- **Time Display:** Now managed by AppSettings.timeDisplayMode
- **PlaybackCoordinator:** Provides stream metadata fallback

---

## 📚 References

- **Webamp Source:** webamp_clone/packages/webamp/
- **Pattern:** tasks/done/double-size-button/
- **Sprite Definitions:** MacAmpApp/Models/SkinSprites.swift
- **Oracle Reviews:** tasks/done/clutter-bar-options-info-buttons/bugfix-nsmenu-lifecycle.md

---

**Documentation Status:** ✅ COMPLETE
**Last Updated:** 2025-11-02
**Maintainer:** MacAmp Development Team
