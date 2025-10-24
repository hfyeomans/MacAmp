# Exact Code Changes Required

## File: `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`

### Change 1: Add Mask Layer in body Property

**Location:** Lines 64-84 (in the `body` computed property)

**Current Code:**
```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                        width: WinampSizes.main.width,
                        height: WinampSizes.main.height)

        // Title bar with "Winamp" text (overlays on background)
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                        width: 275,
                        height: 14)
            .at(CGPoint(x: 0, y: 0))

        if !isShadeMode {
            // Full window mode
            buildFullWindow()
        } else {
            // Shade mode (collapsed to titlebar only)
            buildShadeMode()
        }
    }
    .frame(width: WinampSizes.main.width,
           height: isShadeMode ? WinampSizes.mainShade.height : WinampSizes.main.height)
    .background(Color.black) // Fallback
    // ... rest of body
}
```

**New Code:**
```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                        width: WinampSizes.main.width,
                        height: WinampSizes.main.height)

        // ✅ ADD THIS ENTIRE GROUP (Static UI Masks)
        // Hide baked-in static UI elements from MAIN_WINDOW_BACKGROUND
        Group {
            // Time display area - hide static "00:00" or "88:88"
            Color.black
                .frame(width: 48, height: 13)
                .at(Coords.timeDisplay)

            // Volume slider area - hide static thumb position
            Color.black
                .frame(width: 68, height: 13)
                .at(Coords.volumeSlider)

            // Balance slider area - hide static center marker
            Color.black
                .frame(width: 38, height: 13)
                .at(Coords.balanceSlider)
        }
        // ✅ END OF ADDITION

        // Title bar with "Winamp" text (overlays on background)
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                        width: 275,
                        height: 14)
            .at(CGPoint(x: 0, y: 0))

        if !isShadeMode {
            // Full window mode
            buildFullWindow()
        } else {
            // Shade mode (collapsed to titlebar only)
            buildShadeMode()
        }
    }
    .frame(width: WinampSizes.main.width,
           height: isShadeMode ? WinampSizes.mainShade.height : WinampSizes.main.height)
    .background(Color.black) // Fallback
    // ... rest of body
}
```

---

### Change 2: Remove Mask from buildTimeDisplay()

**Location:** Lines 256-313 (in the `buildTimeDisplay()` function)

**Current Code:**
```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // MASK: Hide static digits from MAIN_WINDOW_BACKGROUND
        // Many skins have "00:00" or "88:88" baked into the background image
        // This black rectangle masks them before rendering dynamic digits
        Color.black
            .frame(width: 48, height: 13)

        // Show minus sign for remaining time (position 1)
        if showRemainingTime {
            SimpleSpriteImage(.minusSign, width: 5, height: 1)
                .offset(x: 1, y: 6) // Position at x:1, align with digit baseline
        }

        // Time digits (MM:SS format) with absolute positioning
        let timeToShow = showRemainingTime ?
            max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
            audioPlayer.currentTime

        let digits = timeDigits(from: timeToShow)

        // Position each digit with proper Winamp spacing
        // Only hide digits when paused and blink is off, colon always visible
        let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible

        // Minutes (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
                .offset(x: 6, y: 0)

            SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13)
                .offset(x: 17, y: 0)  // 6 + 9 + 2px gap = 17
        }

        // Colon between minutes and seconds (always visible, using proper sprite)
        SimpleSpriteImage(.character(58), width: 5, height: 6)
            .offset(x: 28, y: 3)  // Centered between groups, vertically aligned

        // Seconds (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13)
                .offset(x: 35, y: 0)  // After colon with proper gap

            SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13)
                .offset(x: 46, y: 0)  // 35 + 9 + 2px gap = 46
        }
    }
    .at(Coords.timeDisplay)
    .contentShape(Rectangle())
    .onTapGesture {
        showRemainingTime.toggle()
    }
    .onChange(of: audioPlayer.currentTime) { _, _ in
        // Force SwiftUI to re-evaluate buildTimeDisplay() when currentTime changes
        // This ensures digit sprites update visually as the track plays
    }
}
```

**New Code:**
```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ❌ REMOVED: Color.black mask (now in root ZStack at correct z-level)

        // Show minus sign for remaining time (position 1)
        if showRemainingTime {
            SimpleSpriteImage(.minusSign, width: 5, height: 1)
                .offset(x: 1, y: 6) // Position at x:1, align with digit baseline
        }

        // Time digits (MM:SS format) with absolute positioning
        let timeToShow = showRemainingTime ?
            max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
            audioPlayer.currentTime

        let digits = timeDigits(from: timeToShow)

        // Position each digit with proper Winamp spacing
        // Only hide digits when paused and blink is off, colon always visible
        let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible

        // Minutes (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
                .offset(x: 6, y: 0)

            SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13)
                .offset(x: 17, y: 0)  // 6 + 9 + 2px gap = 17
        }

        // Colon between minutes and seconds (always visible, using proper sprite)
        SimpleSpriteImage(.character(58), width: 5, height: 6)
            .offset(x: 28, y: 3)  // Centered between groups, vertically aligned

        // Seconds (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13)
                .offset(x: 35, y: 0)  // After colon with proper gap

            SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13)
                .offset(x: 46, y: 0)  // 35 + 9 + 2px gap = 46
        }
    }
    .at(Coords.timeDisplay)
    .contentShape(Rectangle())
    .onTapGesture {
        showRemainingTime.toggle()
    }
    .onChange(of: audioPlayer.currentTime) { _, _ in
        // Force SwiftUI to re-evaluate buildTimeDisplay() when currentTime changes
        // This ensures digit sprites update visually as the track plays
    }
}
```

**Summary of Change 2:**
- **DELETE:** Lines 259-263 (the Color.black mask and its comment)
- **KEEP:** Everything else unchanged

---

## Verification Script

After making these changes, build and run the app. Use this checklist:

```
Test Checklist:
[ ] Build succeeds without errors
[ ] App launches normally
[ ] Load a track (any audio file)
[ ] Time display shows dynamic digits only (no static "00:00")
[ ] Time updates as track plays (every second)
[ ] Pause button - digits blink correctly
[ ] Volume slider - no ghost thumb visible
[ ] Balance slider - no ghost center marker visible
[ ] Resume playback - time continues updating
[ ] Switch to remaining time (click time) - shows negative/remaining correctly
```

---

## If Problems Occur

### Static "00:00" Still Visible

**Debug Step 1:** Add visual marker to mask
```swift
Color.black
    .frame(width: 48, height: 13)
    .border(Color.red, width: 2)  // ← ADD THIS
    .at(Coords.timeDisplay)
```

- If red border visible → mask is rendering, position might be wrong
- If no red border → mask isn't rendering at all

**Debug Step 2:** Verify coordinates
```swift
Group {
    Color.black
        .frame(width: 48, height: 13)
        .at(Coords.timeDisplay)
        .onAppear {
            print("✅ Time mask at: \(Coords.timeDisplay)")
        }
    // ... other masks
}
```

Check console for output. Should print: `✅ Time mask at: (39.0, 26.0)`

**Debug Step 3:** Verify background is source
```swift
// TEMPORARILY replace background with solid color
Color.purple
    .frame(width: WinampSizes.main.width, height: WinampSizes.main.height)
// SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)  // ← Comment this out
```

- If static "00:00" disappears → it's from background bitmap ✓
- If still visible → it's from a different sprite (investigate further)

---

## Git Commit Message (After Testing)

```
fix(ui): move static UI masks to correct z-index level

The black masks intended to hide static UI elements from
MAIN_WINDOW_BACKGROUND (like "00:00" in time display) were
rendering at the wrong z-index level.

Moved masks from inside component builders (buildTimeDisplay)
to root ZStack at explicit z-level between background and UI.

Changes:
- Add mask Group in WinampMainWindow.body (z-index 1)
- Remove Color.black from buildTimeDisplay (was at z-index 2)
- Masks now properly cover static background elements

Affected areas:
- Time display (no more static "00:00")
- Volume slider (no more ghost thumb)
- Balance slider (no more ghost center)

Testing: Load track, verify only dynamic digits visible
```

---

## Line-by-Line Diff

### body property

```diff
 var body: some View {
     ZStack(alignment: .topLeading) {
         // Background
         SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                         width: WinampSizes.main.width,
                         height: WinampSizes.main.height)

+        // Hide baked-in static UI elements from MAIN_WINDOW_BACKGROUND
+        Group {
+            // Time display area - hide static "00:00" or "88:88"
+            Color.black
+                .frame(width: 48, height: 13)
+                .at(Coords.timeDisplay)
+
+            // Volume slider area - hide static thumb position
+            Color.black
+                .frame(width: 68, height: 13)
+                .at(Coords.volumeSlider)
+
+            // Balance slider area - hide static center marker
+            Color.black
+                .frame(width: 38, height: 13)
+                .at(Coords.balanceSlider)
+        }
+
         // Title bar with "Winamp" text (overlays on background)
         SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
```

### buildTimeDisplay() function

```diff
 @ViewBuilder
 private func buildTimeDisplay() -> some View {
     ZStack(alignment: .leading) {
-        // MASK: Hide static digits from MAIN_WINDOW_BACKGROUND
-        // Many skins have "00:00" or "88:88" baked into the background image
-        // This black rectangle masks them before rendering dynamic digits
-        Color.black
-            .frame(width: 48, height: 13)
-
         // Show minus sign for remaining time (position 1)
         if showRemainingTime {
             SimpleSpriteImage(.minusSign, width: 5, height: 1)
```

---

## Total Changes

- **Lines Added:** ~20 (mask Group in body)
- **Lines Removed:** ~5 (mask from buildTimeDisplay)
- **Files Modified:** 1 (`WinampMainWindow.swift`)
- **Functions Modified:** 2 (`body`, `buildTimeDisplay`)
- **New Dependencies:** None
- **Breaking Changes:** None

**Estimated Time:** 5 minutes to implement, 5 minutes to test
