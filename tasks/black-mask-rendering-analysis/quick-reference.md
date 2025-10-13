# Quick Reference: Black Mask Fix

## TL;DR - The Problem

Color.black masks inside `buildTimeDisplay()` are at the WRONG z-index level:
- Background with static "00:00" is at **z-index 0**
- Masks inside `buildTimeDisplay()` are at **z-index 2** (same as digits)
- **Result:** Masks render AFTER background, but don't hide static elements

## The Fix (3 Steps)

### 1. Add Mask Layer in Root ZStack

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`

**Location:** In `body` property, AFTER background, BEFORE title bar:

```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                        width: WinampSizes.main.width,
                        height: WinampSizes.main.height)

        // ✅ ADD THIS GROUP HERE (between background and title bar)
        Group {
            // Time display mask
            Color.black
                .frame(width: 48, height: 13)
                .at(Coords.timeDisplay)

            // Volume slider mask
            Color.black
                .frame(width: 68, height: 13)
                .at(Coords.volumeSlider)

            // Balance slider mask
            Color.black
                .frame(width: 38, height: 13)
                .at(Coords.balanceSlider)
        }

        // Title bar (existing)
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", ...)
            .at(CGPoint(x: 0, y: 0))

        // Rest of UI (existing)
        if !isShadeMode {
            buildFullWindow()
        } else {
            buildShadeMode()
        }
    }
    // ... rest of body
}
```

### 2. Remove Mask from buildTimeDisplay()

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`

**Location:** In `buildTimeDisplay()` function:

```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ❌ DELETE THESE LINES (lines 259-263):
        // // MASK: Hide static digits from MAIN_WINDOW_BACKGROUND
        // // Many skins have "00:00" or "88:88" baked into the background image
        // // This black rectangle masks them before rendering dynamic digits
        // Color.black
        //     .frame(width: 48, height: 13)

        // ✅ KEEP EVERYTHING ELSE (minus sign, digits, colon)
        if showRemainingTime {
            SimpleSpriteImage(.minusSign, width: 5, height: 1)
                .offset(x: 1, y: 6)
        }

        let timeToShow = showRemainingTime ?
            max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime) :
            audioPlayer.currentTime

        let digits = timeDigits(from: timeToShow)
        let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible

        // ... rest of digit rendering (KEEP THIS)
    }
    .at(Coords.timeDisplay)
    // ... rest of function (KEEP THIS)
}
```

### 3. Test

Build and run:
1. Load a track
2. Check time display - should show ONLY dynamic digits
3. Adjust volume - should not show ghost thumb
4. Adjust balance - should not show ghost center

---

## Why This Works

### Before (Broken)

```
Z-Stack Layers:
0: MAIN_WINDOW_BACKGROUND ← Static "00:00" at (39,26)
1: MAIN_TITLE_BAR_SELECTED
2: buildFullWindow() Group {
     buildTimeDisplay() ZStack {
       Color.black ← At z:2, same level as digits
       Digits
     }
   }

Result: All at same z-level, background "00:00" still visible
```

### After (Fixed)

```
Z-Stack Layers:
0: MAIN_WINDOW_BACKGROUND ← Static "00:00" at (39,26)
1: Color.black masks ← HIDES static "00:00"
2: MAIN_TITLE_BAR_SELECTED
3: buildFullWindow() Group {
     buildTimeDisplay() {
       Digits ← Render on top of black mask
     }
   }

Result: Black mask covers background, digits show on top
```

---

## If Static Elements Still Appear

### Debug Steps

1. **Verify mask is rendering:**
   ```swift
   Color.black
       .frame(width: 48, height: 13)
       .border(Color.red, width: 2)  // ← Add red border
       .at(Coords.timeDisplay)
   ```
   If you see red border but still see static "00:00", the position is wrong.

2. **Check background sprite:**
   ```swift
   // Temporarily replace background to verify static element source
   // SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)
   Color.purple.frame(width: 275, height: 116)
   ```
   If static "00:00" disappears, it's from MAIN_WINDOW_BACKGROUND.
   If it's still there, it's from a different sprite.

3. **Verify coordinates:**
   ```swift
   // Print mask position
   Color.black
       .frame(width: 48, height: 13)
       .at(Coords.timeDisplay)
       .onAppear {
           print("Time display position: \(Coords.timeDisplay)")
       }
   ```

### Add More Masks

If you find other static elements (EQ sliders, preamp, etc.):

```swift
Group {
    // Existing masks...

    // Add new mask for discovered element
    Color.black
        .frame(width: <width>, height: <height>)
        .at(x: <x>, y: <y>)
}
```

---

## Affected Coordinates

Based on Winamp spec and user report:

| Element | Coords | Size | Sprite |
|---------|--------|------|--------|
| Time Display | (39, 26) | 48×13 | MAIN_WINDOW_BACKGROUND |
| Volume Slider | (107, 57) | 68×13 | MAIN_WINDOW_BACKGROUND |
| Balance Slider | (177, 57) | 38×13 | MAIN_WINDOW_BACKGROUND |
| EQ Sliders | TBD | TBD | EQ_WINDOW_BACKGROUND |
| Preamp Slider | TBD | TBD | EQ_WINDOW_BACKGROUND |

---

## Alternative: Preprocess Background (Long-term)

Instead of runtime masks, modify the background sprite during skin loading:

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SkinManager.swift`

```swift
private func preprocessMainBackground(_ image: NSImage) -> NSImage {
    let processed = NSImage(size: image.size)
    processed.lockFocus()

    // Draw original
    image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1.0)

    // Paint black over static UI areas
    NSColor.black.setFill()
    NSRect(x: 39, y: 26, width: 48, height: 13).fill()   // Time
    NSRect(x: 107, y: 57, width: 68, height: 13).fill()  // Volume
    NSRect(x: 177, y: 57, width: 38, height: 13).fill()  // Balance

    processed.unlockFocus()
    return processed
}
```

Call during skin load:
```swift
if let mainBg = skin.images["MAIN_WINDOW_BACKGROUND"] {
    skin.images["MAIN_WINDOW_BACKGROUND"] = preprocessMainBackground(mainBg)
}
```

**Pros:**
- Cleaner UI code
- No runtime overhead
- Guaranteed to work

**Cons:**
- Modifies skin assets
- Need to track all static UI regions
- Can't dynamically change which areas are masked
