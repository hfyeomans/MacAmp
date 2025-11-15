# Focus Ring & EQ/PL Button Fixes - Current State

## Date: 2025-11-15

## Branch: feature/video-milkdrop-windows

## Latest Commit: c167b4f

## Completed Work

1. **Commit 78c9b3a** - Remove blue focus ring from all window titlebar buttons
2. **Commit bfb6305** - Add missing .focusable(false) to EQ window titlebar buttons
3. **Commit 4fb68aa** - Remove focus rings from clutter bar and Playlist minimize button
4. **Commit 5f39cd5** - EQ/PL buttons light when windows visible + remove focus rings
5. **Commit 32227a1** - Use WindowCoordinator for EQ/PL button state
6. **Commit c167b4f** - Previous button focus ring + EQ/PL buttons actually toggle windows

## Current Issues

### Issue 1: EQ/PL Button Lights Don't Update Reactively

**Problem:** Clicking EQ/PL buttons toggles window visibility (orderOut/orderFront works), but the button sprite doesn't change from SELECTED to normal because SwiftUI view body doesn't re-evaluate.

**Root Cause:** The sprite selection happens at view render time:
```swift
let eqSprite = WindowCoordinator.shared?.eqWindow?.isVisible == true
    ? "MAIN_EQ_BUTTON_SELECTED"
    : "MAIN_EQ_BUTTON"
```

This only runs when SwiftUI re-renders the view. Changing NSWindow.isVisible doesn't trigger a SwiftUI update because there's no @Observable/@State property being observed.

**Why Shuffle/Repeat Work:** They're bound to `@Observable AppSettings` properties which trigger view updates automatically via Swift's observation system.

**Solution Options:**
1. Add @State properties to track window visibility, update after toggle
2. Use NotificationCenter to observe NSWindow visibility changes
3. Force view refresh by toggling a dummy @State property
4. Make WindowCoordinator @Observable and track visibility there

### Issue 2: Focus Rings on ALL Main Window Buttons

**Problem:** As each focus ring is fixed, another appears on the next button in tab order. This indicates ALL buttons in main window need `.focusable(false)`.

**Buttons Needing Fix:**
- Transport: Previous, Play, Pause, Stop, Next (some may already be fixed)
- Volume slider (if interactive)
- Balance slider (if interactive)
- Seek slider (if interactive)
- Any other interactive buttons

## Files to Modify

- `MacAmpApp/Views/WinampMainWindow.swift` - Main file with all buttons
- Possibly `MacAmpApp/ViewModels/WindowCoordinator.swift` - If making @Observable

## Next Steps

1. Search for ALL Button instances in WinampMainWindow.swift
2. Add .focusable(false) to every single one
3. Implement reactive EQ/PL button state using @State or observation
4. Build and test
5. Commit with comprehensive message

## Technical Notes

- SwiftUI view updates only when @Observable/@State properties change
- NSWindow.isVisible is not observed by SwiftUI
- Need to bridge AppKit window state to SwiftUI reactive system
- Best pattern: @State with manual update after orderOut/orderFront
