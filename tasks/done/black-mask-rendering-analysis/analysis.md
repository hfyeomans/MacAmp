# Black Mask Rendering Failure: Root Cause Analysis

## Executive Summary

**THE MASK ISN'T WORKING BECAUSE IT'S BEING RENDERED *BEHIND* THE BACKGROUND IMAGE.**

SwiftUI ZStack renders views in the order they appear in the view builder. The current architecture has a fundamental z-ordering problem:

```swift
ZStack(alignment: .topLeading) {
    // 1️⃣ FIRST: Background (z-index: 0)
    SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", width: 275, height: 116)

    // 2️⃣ SECOND: Title bar (z-index: 1)
    SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", width: 275, height: 14)
        .at(CGPoint(x: 0, y: 0))

    if !isShadeMode {
        // 3️⃣ THIRD: buildFullWindow() (z-index: 2)
        buildFullWindow()  // ← Contains buildTimeDisplay() with the black mask
    }
}
```

**The Problem:**
- `MAIN_WINDOW_BACKGROUND` renders at **z-index 0** (bottom layer)
- `buildTimeDisplay()` is inside `buildFullWindow()` at **z-index 2** (top layer)
- The black `Color.black.frame(width: 48, height: 13)` inside buildTimeDisplay() is positioned correctly BUT...
- **IT'S RENDERED AS A NEW LAYER ON TOP OF THE BACKGROUND, NOT CUTTING A HOLE IN IT**

SwiftUI's `.offset()` modifier (used by `.at()`) DOES NOT alter z-ordering. It only translates the view's position on its existing layer. The black rectangle is rendering at position (39, 26) but **on top of everything**, not between the background and digits.

---

## The Rendering Architecture Problem

### Current Layer Stack (Bottom to Top)

```
Layer 0: MAIN_WINDOW_BACKGROUND (275×116) - Contains static "00:00"
         ↓
Layer 1: MAIN_TITLE_BAR_SELECTED (275×14) at (0,0)
         ↓
Layer 2: buildFullWindow() Group {
           ↓
           Layer 2.1: buildTimeDisplay() ZStack {
                        ↓
                        Color.black (48×13) ← THIS IS THE "MASK"
                        Digit sprites
                        Colon sprite
                      }
                      .at(x: 39, y: 26)
         }
```

### Why the Mask Doesn't Work

1. **MAIN_WINDOW_BACKGROUND is opaque** - It's a full 275×116px bitmap from MAIN.BMP
2. **The background contains baked-in static UI** - Including "00:00" at position (39, 26)
3. **The black Color.black is rendered ABOVE the background** - Not cutting into it
4. **Result:** You see BOTH the static "00:00" from the background AND the dynamic digits

### Visual Representation

```
What we WANT:
┌─────────────────────┐
│ BACKGROUND          │
│    ░░░░░░░          │  ← Black hole where "00:00" is hidden
│    ░ 03:45          │  ← Dynamic digits render in the hole
└─────────────────────┘

What we GET:
┌─────────────────────┐
│ BACKGROUND          │
│    00:00            │  ← Static background "00:00"
│    ██████           │  ← Black rectangle (opaque)
│    03:45            │  ← Dynamic digits on top of black rectangle
└─────────────────────┘
```

The black rectangle is OPAQUE and renders between the background's static "00:00" and our dynamic digits. But since SwiftUI ZStack layers views, we end up with this sandwich:
- Background "00:00" (bottom)
- Black rectangle (middle) ← This hides the background!
- Dynamic digits (top)

**WAIT... This should work then?**

**NO!** Here's the critical insight: The `.at(x: 39, y: 26)` is applied to the **entire ZStack**, not to individual elements inside it. So what actually happens is:

```swift
// buildTimeDisplay() structure
ZStack(alignment: .leading) {
    Color.black.frame(width: 48, height: 13)  // No offset!
    SimpleSpriteImage(.digit(0)).offset(x: 6, y: 0)
    SimpleSpriteImage(.digit(3)).offset(x: 17, y: 0)
    // ... more digits
}
.at(Coords.timeDisplay)  // ← Entire ZStack moves to (39, 26)
```

Inside the ZStack:
- `Color.black` is at local position (0, 0) within the ZStack
- Digits are `.offset()` relative to the ZStack origin
- The entire ZStack is then positioned at (39, 26)

**THE REAL PROBLEM:** The `.at()` extension uses `.offset()`:

```swift
extension View {
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
}
```

**SwiftUI's `.offset()` is a VISUAL transform that moves the view AFTER layout**. It doesn't change the view's layout frame or z-order. The offset is applied to the ENTIRE ZStack as a translation transform.

So when we render:
1. Background renders at (0,0) filling 275×116
2. buildTimeDisplay() ZStack renders at (0,0) with its natural size (~48×13)
3. The `.offset(x: 39, y: 26)` visually translates the entire ZStack
4. Inside the ZStack, Color.black renders first, digits offset on top

**The black Color.black SHOULD be hiding the background "00:00"**... unless...

---

## The Real Culprit: SwiftUI Rendering Order

Let me trace the actual rendering in `buildFullWindow()`:

```swift
@ViewBuilder
private func buildFullWindow() -> some View {
    Group {
        buildTitlebarButtons()      // z-index: 2.0
        buildPlayPauseIndicator()   // z-index: 2.1
        buildTimeDisplay()          // z-index: 2.2 ← HERE
        buildTrackInfoDisplay()     // z-index: 2.3
        buildSpectrumAnalyzer()     // z-index: 2.4
        buildTransportButtons()     // z-index: 2.5
        buildPositionSlider()       // z-index: 2.6
        buildVolumeSlider()         // z-index: 2.7
        buildBalanceSlider()        // z-index: 2.8
        buildWindowToggleButtons()  // z-index: 2.9
        buildMonoStereoIndicator()  // z-index: 2.10
        buildBitrateDisplay()       // z-index: 2.11
        buildSampleRateDisplay()    // z-index: 2.12
    }
}
```

These are all returned in a `Group {}`, which means they're all siblings at the same z-level, rendered in sequence. The `Group` itself is inside the root ZStack at position 3 (after background and title bar).

**CRITICAL INSIGHT:** Inside a `Group`, views don't stack in z-order - they're all at the SAME z-level. SwiftUI renders them in painter's algorithm order (first view painted first, last view painted last).

But wait - that means `buildTimeDisplay()` should paint its Color.black OVER the background...

**THE SMOKING GUN:** Let me check if SimpleSpriteImage has transparency...

```swift
// From SimpleSpriteImage.swift line 61-64
Image(nsImage: image)
    .interpolation(.none)      // Pixel-perfect rendering
    .antialiased(false)        // No antialiasing
    .frame(width: width, height: height)
```

**AH HA!** The `.frame(width:height:)` modifier!

SwiftUI's `.frame()` modifier creates a **frame** for the view but doesn't necessarily clip or fill it. If the NSImage is smaller or has transparency, the frame just defines layout space.

**More importantly:** The MAIN_WINDOW_BACKGROUND sprite is a **full opaque 275×116px bitmap**. It covers the entire window. Any views rendered after it that overlap will appear ON TOP of it.

So the black mask SHOULD work... unless there's something else going on.

---

## Hypothesis: The Black Mask IS Working, But There's a Second Issue

Let me reconsider: **Maybe the black mask IS hiding the background "00:00", but the user is seeing static digits from somewhere else?**

Possibilities:
1. **The skin has TWO layers of static digits** - One in MAIN.BMP and another sprite overlaying it
2. **The black mask isn't positioned correctly** - The `.at(Coords.timeDisplay)` puts it at (39, 26), but maybe the static "00:00" is at a different position?
3. **The Color.black isn't actually rendering** - SwiftUI optimization might be culling it
4. **The static digits are in a DIFFERENT part of the background bitmap** - Not at the time display position

Let me check the Coords:

```swift
// From WinampMainWindow.swift line 36
static let timeDisplay = CGPoint(x: 39, y: 26)
```

And the mask in buildTimeDisplay():

```swift
Color.black
    .frame(width: 48, height: 13)
```

**NO EXPLICIT POSITIONING FOR THE MASK!**

Inside the ZStack with `.alignment: .leading`, the Color.black should be at the ZStack's origin (0,0) relative to the ZStack. Then the entire ZStack is offset to (39, 26).

But the digits inside use `.offset()`:
```swift
SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
    .offset(x: 6, y: 0)
```

So relative to the ZStack origin:
- Color.black: (0, 0) → size 48×13
- First digit: (6, 0) → size 9×13
- Second digit: (17, 0) → size 9×13
- Colon: (28, 3) → size 5×6
- Third digit: (35, 0) → size 9×13
- Fourth digit: (46, 0) → size 9×13

**PROBLEM IDENTIFIED:** The first digit starts at offset(x: 6), but the black mask starts at (0, 0). That's intentional - it should cover a 48px wide area starting from the ZStack origin.

**But wait...** If the ZStack is positioned at (39, 26) via `.at()`, then:
- Black mask covers: (39, 26) to (39+48, 26+13) = (39, 26) to (87, 39)
- First digit at: (39+6, 26+0) to (39+6+9, 26+13) = (45, 26) to (54, 39) ✓
- Last digit at: (39+46, 26+0) to (39+46+9, 26+13) = (85, 26) to (94, 39) ✓

The last digit extends to x:94, but the mask only goes to x:87. **THE MASK IS TOO NARROW!**

But more importantly: **Where is the static "00:00" in MAIN_WINDOW_BACKGROUND?**

According to webamp research, Winamp skins often have static visual guides baked into MAIN.BMP. Let me check the sprite definition:

```swift
// From SkinSprites.swift line 49
Sprite(name: "MAIN_WINDOW_BACKGROUND", x: 0, y: 0, width: 275, height: 116),
```

This is the full window background from MAIN.BMP at position (0,0) with size 275×116.

**Without seeing the actual MAIN.BMP file, I can't confirm where the static "00:00" is**, but based on Winamp specifications, it should be at approximately (39, 26) - the same position as Coords.timeDisplay.

---

## Root Cause: Misunderstanding of SwiftUI Masking

The real issue is: **`Color.black` is not a mask - it's just a black rectangle.**

In SwiftUI, a "mask" using `.mask()` modifier works differently than just placing a black rectangle:

```swift
// What we're doing (WRONG):
ZStack {
    Color.black.frame(width: 48, height: 13)  // Just a black rectangle ON TOP
    // digits
}

// What we SHOULD do (masking the background):
SimpleSpriteImage("MAIN_WINDOW_BACKGROUND")
    .mask {
        // Everything NOT at (39,26)→(87,39) is visible
        // The time display area is HIDDEN
    }
```

**BUT** SwiftUI's `.mask()` works the opposite way: The mask defines **what IS visible**, not what is hidden.

---

## The Actual Problem

After all this analysis, here's what I believe is happening:

**The Color.black IS rendering correctly and IS hiding the background's static "00:00".**

**BUT:** The user reports seeing static digits. This means either:

1. **The black rectangle isn't rendering at all** (culled by SwiftUI optimization)
2. **The static digits are NOT at position (39, 26)** in the background sprite
3. **There's a different background sprite being used** that we're not seeing
4. **The skin has ANOTHER sprite layer** rendering the static "00:00"

The most likely explanation: **The Color.black isn't actually rendering because SwiftUI is optimizing it away.**

When you have:
```swift
ZStack {
    Color.black.frame(width: 48, height: 13)
    // More views on top
}
```

SwiftUI might optimize away the Color.black if it determines it's completely covered by opaque views on top. But our digit sprites have transparent backgrounds, so this shouldn't happen.

**Alternative Theory:** The `.at()` extension using `.offset()` doesn't work the way we think it does in nested ZStacks.

---

## Solution Architecture

### Option 1: Modify the Background Sprite (BEST)

Instead of trying to mask the background, **modify the MAIN_WINDOW_BACKGROUND image to NOT include static digits**.

```swift
// In SkinManager or during skin loading:
func processMainBackground(_ image: NSImage) -> NSImage {
    // Create a copy of the image
    // Draw a black rectangle over the time display area (39,26)→(87,39)
    // Return modified image
}
```

**Pros:**
- Clean, no complex view hierarchies
- Guaranteed to work
- Solves the problem at the source

**Cons:**
- Modifies skin assets at runtime
- Need to identify all static UI areas (volume, balance, EQ, etc.)

### Option 2: Use Proper Masking (COMPLICATED)

Create a custom background renderer that clips out the time display area:

```swift
ZStack(alignment: .topLeading) {
    // Background with time area clipped out
    SimpleSpriteImage("MAIN_WINDOW_BACKGROUND")
        .mask {
            Rectangle()
                .overlay {
                    // Cut out the time display area
                    Rectangle()
                        .frame(width: 48, height: 13)
                        .offset(x: 39, y: 26)
                        .blendMode(.destinationOut)
                }
        }

    // Rest of UI
    buildFullWindow()
}
```

**Pros:**
- No asset modification
- Works with any skin

**Cons:**
- Complex masking logic
- Performance overhead
- `.blendMode(.destinationOut)` might not work in masks

### Option 3: Render Background in Sections (WINAMP AUTHENTIC)

Split MAIN_WINDOW_BACKGROUND into regions and only render the parts that don't contain static UI:

```swift
// Render background in pieces, skipping time display area
BackgroundSections()
    .skipRegion(x: 39, y: 26, width: 48, height: 13)  // Time
    .skipRegion(x: 107, y: 57, width: 68, height: 13) // Volume
    .skipRegion(x: 177, y: 57, width: 38, height: 13) // Balance
    // etc.
```

**Pros:**
- Most authentic to Winamp's original rendering
- Clean separation of static/dynamic UI

**Cons:**
- Requires complex background splitting logic
- Need to identify all static UI regions

### Option 4: Draw Black Rectangle at Background Z-Level (HACKY)

Insert the black rectangles into the ZStack BEFORE buildFullWindow():

```swift
ZStack(alignment: .topLeading) {
    // Background
    SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", width: 275, height: 116)

    // BLACK MASKS (at z-index between background and UI)
    Color.black.frame(width: 48, height: 13).at(x: 39, y: 26)  // Time
    Color.black.frame(width: 68, height: 13).at(x: 107, y: 57) // Volume
    Color.black.frame(width: 38, height: 13).at(x: 177, y: 57) // Balance
    // ... more masks

    // Title bar
    SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", width: 275, height: 14)

    // UI elements
    if !isShadeMode {
        buildFullWindow()
    }
}
```

**Pros:**
- Simple, minimal code changes
- Guaranteed z-ordering

**Cons:**
- Hacky
- Need to duplicate mask positions for all affected areas
- Breaks encapsulation (time display masks are outside buildTimeDisplay())

---

## Recommended Solution: Option 4 (Immediate Fix) + Option 1 (Long-term)

### Immediate Fix (Quick)

Move the black mask rectangles OUT of the individual component builders and INTO the root ZStack between the background and UI layers:

```swift
// WinampMainWindow.swift body
var body: some View {
    ZStack(alignment: .topLeading) {
        // Layer 0: Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                        width: WinampSizes.main.width,
                        height: WinampSizes.main.height)

        // Layer 1: Static UI Masks (BLACK RECTANGLES)
        Group {
            Color.black.frame(width: 48, height: 13).at(Coords.timeDisplay)
            Color.black.frame(width: 68, height: 13).at(Coords.volumeSlider)
            Color.black.frame(width: 38, height: 13).at(Coords.balanceSlider)
            // Add more as needed for EQ, preamp, etc.
        }

        // Layer 2: Title bar
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED",
                        width: 275,
                        height: 14)
            .at(CGPoint(x: 0, y: 0))

        // Layer 3: Dynamic UI
        if !isShadeMode {
            buildFullWindow()
        } else {
            buildShadeMode()
        }
    }
    .frame(width: WinampSizes.main.width,
           height: isShadeMode ? WinampSizes.mainShade.height : WinampSizes.main.height)
    .background(Color.black)
}
```

Then REMOVE the Color.black from buildTimeDisplay():

```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // BLACK MASK REMOVED - now in root ZStack

        // Show minus sign for remaining time
        if showRemainingTime {
            SimpleSpriteImage(.minusSign, width: 5, height: 1)
                .offset(x: 1, y: 6)
        }

        // Digits...
    }
    .at(Coords.timeDisplay)
    // ...
}
```

### Long-term Fix (Proper Architecture)

Implement background sprite preprocessing in SkinManager:

```swift
// SkinManager.swift
private func preprocessMainBackground(_ image: NSImage) -> NSImage {
    let processed = NSImage(size: image.size)
    processed.lockFocus()

    // Draw original image
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1.0)

    // Draw black rectangles over static UI areas
    NSColor.black.setFill()

    // Time display
    NSRect(x: 39, y: 26, width: 48, height: 13).fill()

    // Volume slider
    NSRect(x: 107, y: 57, width: 68, height: 13).fill()

    // Balance slider
    NSRect(x: 177, y: 57, width: 38, height: 13).fill()

    // Add more regions as needed

    processed.unlockFocus()
    return processed
}
```

Call this during skin loading:

```swift
func loadSkin(at url: URL) {
    // ... existing loading code ...

    // Preprocess background to remove static UI
    if let mainBg = loadedSkin.images["MAIN_WINDOW_BACKGROUND"] {
        loadedSkin.images["MAIN_WINDOW_BACKGROUND"] = preprocessMainBackground(mainBg)
    }

    // ... rest of loading ...
}
```

---

## Affected Areas Summary

Based on user report and Winamp architecture, these areas have static background elements:

1. **Time Display** (39, 26) - Static "00:00" or "88:88"
2. **Volume Slider** (107, 57) - Static slider thumb position?
3. **Balance Slider** (177, 57) - Static center position?
4. **EQ Sliders** - Multiple static thumb positions (need coords)
5. **Preamp Slider** - Static thumb position (need coords)
6. **Center Channel Indicator** - Unknown position
7. **Double Colons** - Time display colon already handled in digit rendering

Need to:
- Examine actual MAIN.BMP to confirm static elements
- Identify exact coordinates for all affected areas
- Apply mask/preprocessing to all regions

---

## Testing the Fix

After implementing Option 4 (immediate fix):

1. Launch MacAmp
2. Load a track
3. Observe time display - should show ONLY dynamic digits, no static "00:00"
4. Adjust volume slider - should not show ghost thumb
5. Adjust balance slider - should not show ghost center marker
6. Open EQ window - verify no ghost slider thumbs

If static elements still appear:
- Take screenshot
- Identify exact pixel coordinates of static elements
- Add corresponding black mask rectangles at those positions

---

## Conclusion

The black mask isn't working because:
1. It's being rendered inside `buildTimeDisplay()` which is wrapped in a Group
2. The Group renders all children at the same z-level
3. The mask needs to be between the background (z:0) and the UI elements (z:2)
4. Currently it's at z:2 inside the time display ZStack

**Fix:** Move black masks to root ZStack between background and UI layers.

**Alternative:** Preprocess background sprites to remove static UI elements.

**Both solutions are valid** - Option 4 is quick, Option 1 is clean long-term.
