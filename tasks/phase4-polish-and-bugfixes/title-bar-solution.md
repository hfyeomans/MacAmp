# Title Bar Removal - Solution Documentation

**Date:** 2025-10-13
**Status:** ✅ COMPLETED
**macOS Target:** Sequoia 15+ / Tahoe 26+

---

## 🎯 Objective

Remove the macOS title bar completely while enabling custom window dragging via Winamp skin title bars only.

---

## ⚠️ Initial Problem

**Issue:** When using `.windowStyle(.hiddenTitleBar)` and `window.isMovableByWindowBackground = true`:
1. ❌ Dragging ANY slider moved the entire window instead of the slider
2. ❌ Dragging the title bar caused erratic jumping behavior
3. ❌ Sliders were completely unusable

**Root Cause:** `isMovableByWindowBackground = true` makes the ENTIRE window draggable, not just specific areas.

---

## ✅ Final Solution

### Approach: WindowDragGesture (macOS 15+)

Used SwiftUI's native `WindowDragGesture()` API introduced in macOS Sequoia.

**Key Insight:** `WindowDragGesture()` is attached to specific views, making ONLY those views draggable without affecting other gestures.

### Implementation

#### Step 1: Disable Global Window Dragging

**File:** `MacAmpApp/Views/UnifiedDockView.swift` (Line 85)

```swift
private func configureWindow(_ window: NSWindow) {
    window.styleMask.insert(.borderless)
    window.styleMask.remove(.titled)

    // DO NOT make entire window draggable - causes slider conflicts
    // We'll use custom DragGesture on title bars only
    window.isMovableByWindowBackground = false  // ← Changed from true

    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovable = true
}
```

#### Step 2: Add WindowDragGesture to Title Bars Only

**Main Window:** `MacAmpApp/Views/WinampMainWindow.swift` (Line 86)

```swift
SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                width: 275,
                height: 14)
    .at(CGPoint(x: 0, y: 0))
    .gesture(WindowDragGesture())  // ← Only title bar is draggable
```

**Equalizer Window:** `MacAmpApp/Views/WinampEqualizerWindow.swift` (Line 57)

```swift
SimpleSpriteImage("EQ_TITLE_BAR_SELECTED",
                width: 275,
                height: 14)
    .at(CGPoint(x: 0, y: 0))
    .gesture(WindowDragGesture())  // ← Only title bar is draggable
```

**Playlist Window:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (Line 56)

```swift
SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 100, height: 20)
    .position(x: 137.5, y: 10)
    .gesture(WindowDragGesture())  // ← Only title bar is draggable
```

---

## 🧪 Test Results

### ✅ All Tests Passed (2025-10-13)

**Test 1: Title Bar Dragging**
- ✅ Main window title bar drags the entire app
- ✅ Equalizer title bar drags the entire app
- ✅ Playlist title bar drags the entire app
- **Note:** All 3 "windows" are currently in a unified VStack, so they move together (expected behavior for Phase 4)

**Test 2: Sliders Independent**
- ✅ Volume slider moves slider only, not window
- ✅ Balance slider moves slider only, not window
- ✅ Position slider moves slider only, not window
- ✅ All 11 EQ sliders move independently, not window

**Test 3: No Erratic Behavior**
- ✅ No jumping or stuttering when dragging title bars
- ✅ Smooth window movement
- ✅ No gesture conflicts

---

## 📋 Technical Details

### Why WindowDragGesture Works

1. **View-Specific:** Only the view with `.gesture(WindowDragGesture())` becomes draggable
2. **No Global State:** Doesn't interfere with `isMovableByWindowBackground`
3. **Native SwiftUI:** No AppKit hacks or manual window position calculations
4. **Gesture Priority:** SwiftUI handles gesture priorities automatically

### Compared to Previous Attempts

**❌ Attempt 1: isMovableByWindowBackground = true**
- Problem: Made entire window draggable → sliders unusable

**❌ Attempt 2: Custom DragGesture with setFrameOrigin()**
- Problem: Manual position calculations caused jumping and erratic behavior
- Issue: Delta calculations conflicted with window position updates

**✅ Final: WindowDragGesture()**
- Native API designed specifically for this use case
- Zero configuration needed
- Perfect gesture isolation

---

## 🔮 Future Enhancements

### Phase X: Independent Window Movement

**Goal:** Allow each window (Main, Equalizer, Playlist) to be dragged independently and "dock" together.

**Current State:** All three windows are in a unified VStack (UnifiedDockView), so they move as one unit.

**Future Implementation:**
1. Break UnifiedDockView into separate WindowGroups
2. Implement magnetic docking (windows snap together when near)
3. Add window arrangement persistence
4. Each window independently draggable

**Files to Modify:**
- `MacAmpApp/MacAmpApp.swift` - Create separate WindowGroups
- `MacAmpApp/ViewModels/DockingController.swift` - Add magnetic snapping logic
- Each window view - Maintain independent state

**Research Needed:**
- Multi-window coordination in SwiftUI
- NSWindow positioning and magnetic snapping
- Window arrangement persistence (UserDefaults/AppStorage)
- Reference: Winamp's classic docking behavior

---

## 📚 References

### SwiftUI Documentation
- **WindowDragGesture:** https://developer.apple.com/documentation/swiftui/windowdraggesture
- **Window Styling:** https://developer.apple.com/documentation/swiftui/windowstyle
- **Xcode 26 Documentation:** See `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/`

### Research Articles
- Hacking with Swift: "How to let users drag anywhere to move a window"
- Swift with Majid: "Customizing windows in SwiftUI" (August 2024)
- TrozWare: "SwiftUI for Mac 2024"

### WWDC Sessions
- WWDC 2024: "What's new in SwiftUI" (Session 10144)
- WWDC 2024: "Tailor macOS windows with SwiftUI" (Session 10148)

---

## 🎓 Lessons Learned

1. **Use Native APIs First:** SwiftUI often has purpose-built APIs (like WindowDragGesture) that handle edge cases better than custom implementations

2. **Avoid Global Dragging:** `isMovableByWindowBackground` is too broad - use view-specific gestures instead

3. **Trust the Framework:** Manual window position calculations rarely work better than framework APIs

4. **Modern macOS Development:** Target Sequoia 15+ and Tahoe 26+ allows use of latest SwiftUI features without workarounds

5. **Test Gesture Conflicts:** Always test that new gestures don't interfere with existing interactive elements (sliders, buttons, etc.)

---

## ✅ Success Criteria Met

- ✅ macOS title bar completely removed (borderless window)
- ✅ Custom Winamp title bars visible and styled correctly
- ✅ Title bars draggable to move window
- ✅ Sliders work independently without moving window
- ✅ No erratic jumping or stuttering
- ✅ Clean, maintainable SwiftUI-native code
- ✅ Compatible with macOS Sequoia 15+ and Tahoe 26+

---

**Implementation Status:** ✅ COMPLETE
**Last Updated:** 2025-10-13
**Next Steps:** Continue with Phase 4 remaining tasks (seeking bug fix, debug cleanup)
