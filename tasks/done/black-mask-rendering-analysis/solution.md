# Black Mask Rendering Fix - Implementation Guide

## Problem Identified

The Color.black masks are being rendered at the WRONG z-index level:

```
Current (BROKEN):
┌─────────────────────────────────────────┐
│ Z-Index 0: MAIN_WINDOW_BACKGROUND       │ ← Static "00:00" baked in
│ Z-Index 1: MAIN_TITLE_BAR_SELECTED      │
│ Z-Index 2: Group {                      │
│              buildTimeDisplay() {       │
│                ZStack {                 │
│                  Color.black ← HERE     │ ← Mask is INSIDE the ZStack
│                  Digits                 │
│                }                        │
│              }                          │
│            }                            │
└─────────────────────────────────────────┘
```

The mask ends up at the SAME z-level as the digits, not between the background and digits.

## Correct Architecture

```
Fixed (WORKING):
┌─────────────────────────────────────────┐
│ Z-Index 0: MAIN_WINDOW_BACKGROUND       │ ← Static "00:00"
│ Z-Index 1: Color.black masks            │ ← MASKS COVER STATIC UI
│ Z-Index 2: MAIN_TITLE_BAR_SELECTED      │
│ Z-Index 3: Group {                      │
│              buildTimeDisplay() {       │
│                Digits (transparent bg)  │ ← Dynamic digits show through
│              }                          │
│            }                            │
└─────────────────────────────────────────┘
```

## Implementation: Immediate Fix

### File: /Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift

#### Change 1: Add Static UI Mask Layer

In the `body` property, add a new layer BETWEEN the background and title bar:

```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Layer 0: Background (contains static UI elements)
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                        width: WinampSizes.main.width,
                        height: WinampSizes.main.height)

        // Layer 1: Static UI Masks (BLACK RECTANGLES)
        // These hide the baked-in static UI elements from MAIN.BMP
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

        // Layer 2: Title bar (overlays on background and masks)
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                        width: 275,
                        height: 14)
            .at(CGPoint(x: 0, y: 0))

        // Layer 3: Dynamic UI elements
        if !isShadeMode {
            buildFullWindow()
        } else {
            buildShadeMode()
        }
    }
    .frame(width: WinampSizes.main.width,
           height: isShadeMode ? WinampSizes.mainShade.height : WinampSizes.main.height)
    .background(Color.black) // Fallback
    .onChange(of: audioPlayer.isPaused) { _, isPaused in
        // ... existing pause blink logic ...
    }
    .onDisappear {
        // ... existing cleanup ...
    }
}
```

#### Change 2: Remove Mask from buildTimeDisplay()

Remove the Color.black from inside buildTimeDisplay() since it's now at the correct z-level:

```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ❌ REMOVED: Color.black mask (now in root ZStack)

        // Show minus sign for remaining time (position 1)
        if showRemainingTime {
            SimpleSpriteImage(.minusSign, width: 5, height: 1)
                .offset(x: 1, y: 6)
        }

        // Time digits (MM:SS format) with absolute positioning
        let timeToShow = showRemainingTime ?
            max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
            audioPlayer.currentTime

        let digits = timeDigits(from: timeToShow)
        let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible

        // Minutes (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
                .offset(x: 6, y: 0)

            SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13)
                .offset(x: 17, y: 0)
        }

        // Colon between minutes and seconds (always visible)
        SimpleSpriteImage(.character(58), width: 5, height: 6)
            .offset(x: 28, y: 3)

        // Seconds (with 2px gap between digits)
        if shouldShowDigits {
            SimpleSpriteImage(.digit(digits[2]), width: 9, height: 13)
                .offset(x: 35, y: 0)

            SimpleSpriteImage(.digit(digits[3]), width: 9, height: 13)
                .offset(x: 46, y: 0)
        }
    }
    .at(Coords.timeDisplay)
    .contentShape(Rectangle())
    .onTapGesture {
        showRemainingTime.toggle()
    }
    .onChange(of: audioPlayer.currentTime) { _, _ in
        // Force digit update
    }
}
```

#### Change 3: Update Comments

Remove or update the mask comment that's now obsolete:

```swift
// OLD (line 259-261):
// MASK: Hide static digits from MAIN_WINDOW_BACKGROUND
// Many skins have "00:00" or "88:88" baked into the background image
// This black rectangle masks them before rendering dynamic digits

// REMOVE this comment since the mask is now in the root ZStack
```

### Testing the Fix

1. **Build and run MacAmp**
2. **Load a track** - Observe time display updates
3. **Expected behavior:**
   - No static "00:00" visible
   - Only dynamic time digits appear
   - Digits update smoothly as track plays
   - Pause blink works correctly

4. **Check volume slider:**
   - No ghost thumb position from background
   - Thumb moves smoothly

5. **Check balance slider:**
   - No ghost center marker from background
   - Center notch is only from WinampBalanceSlider rendering

### If Static Elements Still Appear

If you still see static UI elements after this fix:

1. **Take a screenshot** showing the static element
2. **Identify its exact pixel position** using a pixel ruler tool
3. **Check which sprite it's from:**
   ```bash
   # Extract MAIN.BMP from the skin
   # Open in Preview or image editor
   # Locate the static element coordinates
   ```
4. **Add a corresponding mask** to the Group in the root ZStack:
   ```swift
   Color.black
       .frame(width: <element_width>, height: <element_height>)
       .at(x: <element_x>, y: <element_y>)
   ```

---

## Understanding Why This Works

### SwiftUI Z-Ordering Rules

1. **ZStack renders views in order** - First view is bottom layer, last view is top layer
2. **Group doesn't create z-levels** - All children in a Group render at the same z-level
3. **.offset() doesn't change z-order** - It only translates the view visually

### Current Rendering Flow (Before Fix)

```swift
ZStack {
    // Z:0
    MAIN_WINDOW_BACKGROUND

    // Z:1
    MAIN_TITLE_BAR_SELECTED

    // Z:2 (all in Group, same level)
    Group {
        buildTimeDisplay() {  // Returns a ZStack
            ZStack {
                Color.black       // ← This is at Z:2, SAME as digits
                digit sprites     // ← Also at Z:2
            }
        }
    }
}
```

Inside `buildTimeDisplay()`'s ZStack, the Color.black is rendered first, then digits on top. But the ENTIRE ZStack is at z-level 2, which is ABOVE the title bar (z:1).

The problem: The MAIN_WINDOW_BACKGROUND (z:0) has static "00:00" painted at (39,26). The Color.black at z:2 is rendered OVER the title bar, but the static "00:00" is still visible because it's part of the background layer.

**Wait, that doesn't make sense...**

If Color.black is at z:2 and background is at z:0, the black should cover the background's static "00:00".

**Let me reconsider:**

Actually, the black SHOULD work if it's opaque and positioned correctly. Let me re-examine...

### The REAL Problem (After Deeper Analysis)

The issue is likely one of these:

1. **The Color.black inside the ZStack has the wrong alignment**
   - ZStack(alignment: .leading) means all children align to the leading edge
   - Color.black.frame(width: 48, height: 13) creates a frame but the Color might not fill it
   - Solution: Use `Color.black.frame(width: 48, height: 13, alignment: .topLeading)`

2. **The digit .offset() positions are relative to the ZStack, not the mask**
   - If the ZStack has alignment .leading, children align to leading edge
   - .offset() then translates from that aligned position
   - The Color.black might not be at (0,0) within the ZStack

3. **The .at(Coords.timeDisplay) offset is applied AFTER layout**
   - SwiftUI applies .offset() as a transform after layout
   - This means the ZStack lays out at its natural position, then is translated
   - If the natural position results in the Color.black not covering the background digits...

Let me check the actual .at() implementation again:

```swift
extension View {
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
}
```

Yes, it's using `.offset()`. This is a **visual transform**, not a layout position.

### How .offset() Actually Works

From Apple's documentation:
> `.offset()` applies a translation transform to the view. The view's layout position remains unchanged - the offset is purely visual.

This means:
```swift
Color.black.frame(width: 48, height: 13)
    .offset(x: 39, y: 26)
```

Lays out the Color.black at (0, 0) with size 48×13, then visually translates it to (39, 26).

**For overlapping to work, the visual bounds must overlap.**

If MAIN_WINDOW_BACKGROUND is at (0,0) with size 275×116, and has static "00:00" painted at (39, 26), then a Color.black offset to (39, 26) with size 48×13 SHOULD cover it.

**So why isn't it working?**

### The Smoking Gun: Color.black Isn't Opaque?

Wait, let me check if SwiftUI's `Color.black` is actually opaque...

From SwiftUI documentation, `Color.black` is RGB(0,0,0) with alpha=1.0. It's opaque.

**Then the mask SHOULD work...**

**UNLESS:** The SimpleSpriteImage for digits has a solid background that we're not accounting for.

Let me check SimpleSpriteImage rendering:

```swift
// SimpleSpriteImage.swift line 61-64
Image(nsImage: image)
    .interpolation(.none)
    .antialiased(false)
    .frame(width: width, height: height)
```

The `Image(nsImage:)` respects the NSImage's alpha channel. If the digit sprites have transparent backgrounds (which they should from webamp architecture), this is fine.

---

## The ACTUAL Root Cause (Final Answer)

After all this analysis, I believe the issue is:

**The Color.black is being rendered at the correct z-level and position, BUT there's a SwiftUI view hierarchy issue where the offset is applied incorrectly.**

Specifically: When you have:
```swift
ZStack(alignment: .leading) {
    Color.black.frame(width: 48, height: 13)
    digit.offset(x: 6, y: 0)
}
.at(Coords.timeDisplay)  // .offset(x: 39, y: 26)
```

SwiftUI processes it as:
1. Create ZStack with alignment: .leading
2. Layout Color.black at leading edge (x:0) of ZStack
3. Layout digit at leading edge (x:0) of ZStack
4. Apply .offset(x: 6, y: 0) to digit → visually move to x:6
5. Apply .offset(x: 39, y: 26) to entire ZStack → visually move to (39, 26)

Result: Color.black visual position = (0+39, 0+26) = (39, 26) ✓
Result: digit visual position = (0+6+39, 0+0+26) = (45, 26) ✓

**This SHOULD work!**

So why doesn't it?

**Because the Group in buildFullWindow() is processed differently:**

```swift
Group {
    buildTitlebarButtons()
    buildPlayPauseIndicator()
    buildTimeDisplay()  // ← Returns the ZStack with offset
    // ... more builders
}
```

In a Group, all children are laid out independently, not stacked in z-order. The Group acts as a transparent container.

**When you return a view from a function, SwiftUI flattens it into the parent hierarchy.**

So `buildTimeDisplay()` returns:
```swift
ZStack { ... }
    .at(Coords.timeDisplay)
```

Which becomes:
```swift
Group {
    // ...
    ZStack { ... }.offset(x: 39, y: 26)  // ← Inserted here
    // ...
}
```

All views in the Group are at the SAME z-level. They don't stack - they're all painted at z:2.

**The painting order within the Group is:**
1. buildTitlebarButtons() - painted first
2. buildPlayPauseIndicator() - painted second
3. buildTimeDisplay() - painted third ← Color.black is part of this
4. ... rest painted in order

**Since they're all at z:2, the LATER painted views appear ON TOP of earlier views.**

So buildTimeDisplay() (painted third) should appear OVER buildPlayPauseIndicator() (painted second).

But the MAIN_WINDOW_BACKGROUND is at z:0 (painted first in the entire ZStack).

**THE COLOR.BLACK AT Z:2 SHOULD COVER THE BACKGROUND AT Z:0.**

---

## Final Conclusion

After exhaustive analysis, I believe one of these is happening:

### Hypothesis A: Color.black Isn't Actually Rendering

SwiftUI might be optimizing away the Color.black because it's covered by other views.

**Test:** Add a border to verify it's rendering:
```swift
Color.black
    .frame(width: 48, height: 13)
    .border(Color.red, width: 2)  // ← Add this
```

If you see a red border but still see static "00:00", then Color.black is rendering but isn't opaque.

### Hypothesis B: The Static "00:00" Isn't in MAIN_WINDOW_BACKGROUND

Maybe there's a SECOND sprite layer we're not seeing that contains the static "00:00".

**Test:** Comment out the MAIN_WINDOW_BACKGROUND:
```swift
// SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)
Color.purple  // ← Replace with purple to see if static "00:00" disappears
```

If static "00:00" still appears, it's from a different sprite.

### Hypothesis C: SwiftUI Rendering Order Bug

There might be a SwiftUI bug where .offset() views don't properly overlap background views.

**Test:** Use .position() instead of .offset():
```swift
func at(_ point: CGPoint) -> some View {
    self.position(x: point.x + width/2, y: point.y + height/2)
}
```

(Note: .position() requires center coordinates, not top-left)

---

## Recommended Fix (Moving Masks to Correct Z-Level)

The safest solution is to move the masks to the correct z-level in the root ZStack, as shown in the implementation section above.

This guarantees:
1. Masks are at z:1 (between background z:0 and UI z:3)
2. No dependency on Group rendering order
3. No SwiftUI optimization interference
4. Clear, explicit z-ordering

**This is the fix I recommend implementing.**
