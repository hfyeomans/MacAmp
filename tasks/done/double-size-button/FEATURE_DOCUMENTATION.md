# Double-Size Mode Feature

**Version:** v0.2.1
**Date:** 2025-10-30
**Status:** ✅ Shipped

---

## Overview

Double-Size Mode allows you to scale the MacAmp window to 200% of its original size, making the classic Winamp interface more visible on modern high-resolution displays.

## Usage

### Button
Click the **"D" button** in the clutter bar (left side of the main window, 4th button from top)

### Visual Feedback
- **Normal (100%):** D button appears unpressed
- **Doubled (200%):** D button appears pressed/highlighted

### Button Location
The clutter bar is a vertical strip of 5 small buttons on the left side:
- **O** - Options (not yet implemented)
- **A** - Always On Top (not yet implemented)
- **I** - Info (not yet implemented)
- **D** - Double Size ⭐ (FUNCTIONAL)
- **V** - Visualizer (not yet implemented)

---

## Behavior

### What Happens
- **Click D once:** All windows smoothly animate to 200% size (550×232 for main/EQ)
- **Click D again:** All windows animate back to 100% size (275×116)
- **Transition:** Smooth 0.2-second animation
- **Persistence:** Last size remembered across app restarts

### What Scales
All 3 Winamp windows scale together:
- Main window: 275×116 → 550×232
- Equalizer: 275×116 → 550×232
- Playlist: 275×height → 550×(height×2)

### Anchor Point
Windows scale from **top-left corner** (classic Winamp behavior)

---

## Technical Details

### State Management
- Property: `AppSettings.isDoubleSizeMode: Bool`
- Default: `false` (100% size)
- Persistence: UserDefaults (`isDoubleSizeMode` key)
- Concurrency: `@MainActor` safe

### Scaling Implementation
- Method: CSS-like `.scaleEffect(2.0, anchor: .topLeading)`
- Frame calculation: `baseSize × scale`
- Animation: SwiftUI `.animation(.easeInOut(duration: 0.2))`
- Unified window: All 3 windows in single macOS window

### Sprite Definitions
Button sprites from TITLEBAR.BMP:
- `MAIN_CLUTTER_BAR_BUTTON_D` (normal, 8×8px)
- `MAIN_CLUTTER_BAR_BUTTON_D_SELECTED` (active, 8×8px)

---

## Known Limitations

### Playlist Menu Buttons
**Issue:** Playlist menu buttons (ADD, REM, SEL, MISC, LIST OPTS) don't scale with double-size mode

**Status:** ⏸️ Deferred to `magnetic-window-docking` task

**Reason:**
- Playlist window is independently resizable (variable height)
- Menu buttons use absolute positioning
- Will be fixed when windows are separated

**Workaround:** Menu buttons remain functional at current size

---

## Compatibility

### System Requirements
- macOS 15+ (Sequoia/Tahoe)
- Swift 6
- Xcode 16.0+

### Works With
- ✅ All skins
- ✅ Shade mode (14px → 28px when doubled)
- ✅ Multiple displays
- ✅ Window dragging
- ✅ Minimize/restore

### Keyboard Shortcut
**Not yet implemented** - Future enhancement

Potential shortcuts:
- Ctrl+D (matches help text)
- ⌘⌃1 (Command+Control+1)

---

## Architecture Notes

### Current Implementation
- **Unified Window:** Single macOS window contains all 3 Winamp windows
- **Scaling Level:** UnifiedDockView applies scaling to entire unified window
- **State:** Shared AppSettings.isDoubleSizeMode affects all windows

### Future (Magnetic Docking)
When windows are separated (future task):
- Each NSWindow will handle its own scaling
- Main/EQ: Fixed dimensions, only double-size mode
- Playlist: Independent resize + double-size mode
- Scaling logic moves from UnifiedDockView to individual windows

See `tasks/magnetic-window-docking/research.md` for migration guide.

---

## Testing Checklist

### Completed Tests ✅
- [x] App starts at 100% (normal size)
- [x] D button click toggles to 200%
- [x] D button click toggles back to 100%
- [x] Button visual state matches mode
- [x] Smooth animation (0.2s)
- [x] All 3 windows scale together
- [x] Works with different skins
- [x] State persists across app restarts
- [x] Top-left anchor maintained

### Known Issues
- [ ] ⏸️ Playlist menu buttons don't scale (deferred)

### Future Testing (Magnetic Docking)
- [ ] Per-window scaling
- [ ] Docking at 2x scale
- [ ] Playlist resize + double-size interaction
- [ ] Snap threshold scaling

---

## Implementation Files

### Modified (5 files)
1. `MacAmpApp/Models/AppSettings.swift` - State management
2. `MacAmpApp/Models/SkinSprites.swift` - Button sprites
3. `MacAmpApp/Views/Components/SkinToggleStyle.swift` - Toggle style (created but simplified)
4. `MacAmpApp/Views/WinampMainWindow.swift` - Clutter bar buttons
5. `MacAmpApp/Views/UnifiedDockView.swift` - Window scaling

### Lines Changed
- ~210 lines added
- ~50 lines removed/refactored
- Net: +160 lines

### Git Branch
- Branch: `double-sized-button`
- Commits: 5 (bcc4582, dc48d29, 6e7cf10, a4d2d2d, 538098f, + reactivity fix)

---

## Release Notes Entry

### v0.2.1 - Double-Size Mode

**New Feature:**
- Added "D" button to toggle window size between 100% and 200%
- All windows (main, EQ, playlist) scale together
- Smooth animations with classic Winamp behavior
- Size preference persists across app restarts

**Clutter Bar:**
- Added O, A, I, D, V button strip (classic Winamp)
- D button functional
- O, A, I, V scaffolded for future features

**Known Issue:**
- Playlist menu buttons don't scale in double-size mode (will fix when implementing magnetic window docking)

---

## Developer Notes

### Reactivity Fix Required

**Critical Issue Discovered:** `@AppStorage` with `@ObservationIgnored` blocks reactivity

**Solution:** Use `didSet` pattern:
```swift
// WRONG (blocks @Observable):
@ObservationIgnored
@AppStorage("key") var value: Bool = false

// CORRECT (maintains @Observable):
var value: Bool = false {
    didSet {
        UserDefaults.standard.set(value, forKey: "key")
    }
}
```

### Why UnifiedDockView Controls Scaling

MacAmp uses a single macOS window containing all 3 Winamp windows (unified architecture). UnifiedDockView manages the unified window size by:

1. Calculating individual window sizes via `naturalSize(for:)`
2. Applying scale factor (1.0 or 2.0) to each window
3. Using `.scaleEffect()` for visual content scaling
4. Computing total frame via `calculateTotalWidth/Height()`

Individual windows (WinampMainWindow, etc.) don't know about scaling - they use 1x coordinates.

---

## References

- Task documentation: `tasks/double-size-button/`
- Migration guide: `tasks/magnetic-window-docking/research.md`
- Webamp reference: `webamp_clone/js/components/MainWindow/ClutterBar.tsx`
- Sprite coordinates: webamp skinSprites.ts line 638-670

---

**Documentation Status:** Complete
**Feature Status:** Shipped ✅
**Future Work:** Playlist menu scaling, keyboard shortcut, magnetic docking integration
