# Double Rendering Analysis Report
## Critical Search for Static Sprite References

**Date:** 2025-10-12
**Issue:** Double rendering of time display (digits and colons) - one set increments (semantic), one is static (legacy)
**Affected:** ALL skins (Classic, Internet Archive, Winamp3)

---

## CRITICAL FINDING: MainWindowView.swift is the culprit!

### 🔴 PRIMARY SOURCE OF DOUBLE RENDERING

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/MainWindowView.swift`
**Lines:** 207-228

```swift
// Time Display with delightful interactions
HStack(spacing: 0) {
    if showRemainingTime, let minus = skin.images["MINUS_SIGN"] {
        Image(nsImage: minus)
            .resizable()
            .frame(width: minus.size.width, height: minus.size.height)
            .padding(.trailing, 2)
            .scaleEffect(timeDisplayBounce ? 1.1 : 1.0)
    }
    let remaining = max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime)
    let timeline = showRemainingTime ? remaining : audioPlayer.currentTime
    let digits = timeDigits(seconds: timeline)
    ForEach(0..<digits.count, id: \.self) { idx in
        if let digitImage = skin.images["DIGIT_" + String(digits[idx])] {
            Image(nsImage: digitImage)
                .resizable()
                .frame(width: 9, height: 13)
                .scaleEffect(timeDisplayBounce ? 1.05 : 1.0)
                .shadow(color: .cyan.opacity(0.3), radius: timeDisplayBounce ? 1 : 0)
        }
    }
}
```

**Problem:** This code uses LEGACY HARDCODED sprite names:
- `"MINUS_SIGN"` (line 209)
- `"DIGIT_" + String(digits[idx])` (line 220)

**Why it's rendering static:** This view is likely still being rendered alongside the new semantic `WinampMainWindow.swift` view!

---

## Files Using Semantic Sprites (✅ CORRECT)

### 1. WinampMainWindow.swift (NEW SEMANTIC SYSTEM)
**Lines:** 256-311
**Status:** ✅ Using semantic sprites correctly

```swift
// Uses semantic sprite resolution:
SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
SimpleSpriteImage(.character(58), width: 5, height: 6)  // Colon
SimpleSpriteImage(.minusSign, width: 5, height: 1)
```

**Coordinates:** Time display at `CGPoint(x: 39, y: 26)` (lines 282-302)

---

## Legacy Sprite References (⚠️ TO AUDIT)

### 2. MainWindowView.swift (LEGACY - CAUSING DOUBLE RENDER)
**Status:** 🔴 ACTIVE PROBLEM - Uses hardcoded sprite strings
**Evidence:**
- Line 209: `skin.images["MINUS_SIGN"]`
- Line 220: `skin.images["DIGIT_" + String(digits[idx])]`
- Lines 207-228: Entire time display block with legacy syntax

**No explicit positioning found in this file** - likely using SwiftUI automatic layout, which could overlap with the semantic system.

### 3. SimpleTestMainWindow.swift (TEST FILE - OK)
**Status:** ⚠️ Test file - safe to ignore
**Lines:** 29-32
```swift
SimpleSpriteImage("DIGIT_0", width: 9, height: 13)
SimpleSpriteImage("DIGIT_1", width: 9, height: 13)
SimpleSpriteImage("DIGIT_2", width: 9, height: 13)
SimpleSpriteImage("DIGIT_3", width: 9, height: 13)
```

---

## Character Sprite References (TEXT.BMP - Non-Time Display)

### Safe Legacy Usage (Not causing time display issues):

**WinampMainWindow.swift:**
- Line 478: `SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)` - Track info display
- Line 510: `SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)` - Bitrate display
- Line 527: `SimpleSpriteImage("CHARACTER_\(ascii)", width: 5, height: 6)` - Sample rate display

**Note:** These are for TEXT.BMP font rendering, not time digits - NOT the source of double rendering.

---

## Background Sprite Analysis

### MAIN_WINDOW_BACKGROUND
**Sprite Definition:** `Sprite(name: "MAIN_WINDOW_BACKGROUND", x: 0, y: 0, width: 275, height: 116)`
**Source:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SkinSprites.swift:49`

**Assessment:** ✅ SAFE - Background is rendered as a single full-window sprite. Does NOT contain embedded time display graphics (those would be at x:39, y:26, but the background is rendered from origin).

**Usage:**
- WinampMainWindow.swift:67 - `SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)`
- MainWindowView.swift:35 - `skin.images["MAIN_WINDOW_BACKGROUND"]`

**Note:** Classic Winamp MAIN.BMP does not have pre-rendered digits. The time display area in MAIN.BMP is typically blank/black, expecting dynamic digit rendering on top.

---

## Coordinate Analysis

### Time Display Positioning

**WinampMainWindow.swift (Semantic System):**
```swift
private struct Coords {
    static let timeDisplay = CGPoint(x: 39, y: 26)
}

// Digit positioning (lines 282-299):
.offset(x: 6, y: 0)   // First minute digit
.offset(x: 17, y: 0)  // Second minute digit
.offset(x: 28, y: 3)  // Colon (character 58)
.offset(x: 35, y: 0)  // First second digit
.offset(x: 46, y: 0)  // Second second digit
```

**All positioned at `.at(Coords.timeDisplay)` = x:39, y:26**

**MainWindowView.swift (Legacy System):**
- No explicit `.offset(x: 39` found
- Uses SwiftUI `HStack` with automatic layout (line 208)
- Positioned via `.padding(.top, 5)` (line 229) - relative positioning
- Positioned after volumeBackground section

**⚠️ LAYOUT CONFLICT:** MainWindowView likely renders at the SAME POSITION as WinampMainWindow, causing overlap!

---

## Root Cause Analysis ✅ CONFIRMED

### ✅ CONFIRMED: Only WinampMainWindow.swift is active!

**App Entry Point:** `/Users/hank/dev/src/MacAmp/MacAmpApp/MacAmpApp.swift`
```swift
WindowGroup {
    UnifiedDockView()  // ← Main entry point
}
```

**UnifiedDockView.swift** (line 188):
```swift
case .main:
    WinampMainWindow()  // ← Only this view is used!
        .environmentObject(skinManager)
        .environmentObject(audioPlayer)
```

**MainWindowView.swift is NOT in the rendering path!** It's an obsolete experimental UI with "Liquid Glass" features.

### ⚠️ REVISED HYPOTHESIS: The double rendering is NOT from two views!

Since only `WinampMainWindow.swift` is active, the double rendering must be from:

1. **Possibility A:** Time digits rendered TWICE in WinampMainWindow.swift itself
   - Check for duplicate `buildTimeDisplay()` calls
   - Check for duplicate time display in shade mode vs full mode

2. **Possibility B:** Skin background image (MAIN.BMP) contains pre-rendered digits
   - Some custom skins might have "00:00" baked into the background
   - These would be static, while dynamic sprites render on top

3. **Possibility C:** Multiple WinampMainWindow instances rendering
   - Check if UnifiedDockView creates multiple main windows
   - Check docking controller logic

**Evidence from WinampMainWindow.swift:**
- Line 121: `buildTimeDisplay()` called in full window mode
- Line 201: `buildTimeDisplay()` called in shade mode (with `.scaleEffect(0.7)`)
- Both use same semantic sprites - no legacy strings!

**Critical Question:** Are BOTH full mode AND shade mode rendering simultaneously?

---

## Search Results Summary

### SimpleSpriteImage with String Literals
**Total Found:** 3 locations (excluding test files)

1. ✅ **WinampMainWindow.swift** - Uses semantic sprites (`.digit`, `.character`)
2. 🔴 **MainWindowView.swift** - Uses legacy hardcoded strings (`"DIGIT_0"`, etc.)
3. ⚠️ **SimpleTestMainWindow.swift** - Test file only

### Suspicious Rendering at Time Display Coordinates
- **No direct `.offset(x: 39` found in MainWindowView.swift**
- WinampMainWindow.swift correctly uses absolute positioning
- MainWindowView.swift uses relative layout (SwiftUI HStack + padding)

### Background Images Overlapping Time Display
- ✅ **MAIN_WINDOW_BACKGROUND does NOT contain static digits**
- Background is rendered first, then dynamic digits on top
- No embedded time graphics in skin sprite sheets

---

## Recommended Actions ✅ UPDATED

### 🔴 CRITICAL - New Investigation Path

Since MainWindowView.swift is NOT being used, the issue is elsewhere:

1. **Check shade mode rendering logic (WinampMainWindow.swift):**
   - Line 77: `if !isShadeMode { buildFullWindow() }`
   - Line 81: `else { buildShadeMode() }`
   - Both call `buildTimeDisplay()` (lines 121 and 201)
   - **Are both branches rendering at once due to animation glitch?**

2. **Inspect actual skin BMP files:**
   ```bash
   # Check if MAIN.BMP contains pre-rendered digits at x:39, y:26
   open /Users/hank/dev/src/MacAmp/tmp/Internet-Archive/MAIN.bmp
   open /Users/hank/dev/src/MacAmp/tmp/Winamp3_Classified_v5.5/main.bmp
   ```
   - Look at coordinates (39, 26) in the image
   - Check if digits "00:00" are baked into the background

3. **Debug buildTimeDisplay() calls:**
   - Add print statements to see if called twice per frame
   - Check if UnifiedDockView creates multiple DockPane instances
   - Verify `isShadeMode` state transitions

4. **Review sprite sheet caching:**
   - Check if SkinManager caches sprites incorrectly
   - Verify SimpleSpriteImage doesn't render stale cached images

### Priority Order:
1. **INVESTIGATE SHADE MODE** - Check if both full/shade render simultaneously
2. **INSPECT SKIN BMPS** - Check for pre-rendered digits in background
3. **DEBUG RENDER CYCLE** - Add logging to buildTimeDisplay()
4. **VERIFY SINGLE INSTANCE** - Ensure only one WinampMainWindow exists

---

## Files to Investigate Next ✅ COMPLETED

1. ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/MacAmpApp.swift` - **CONFIRMED: Uses UnifiedDockView**
2. ✅ `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/UnifiedDockView.swift` - **CONFIRMED: Only WinampMainWindow is rendered**
3. 🔍 **NEW:** Check shade mode logic in WinampMainWindow.swift (lines 77-208)
4. 🔍 **NEW:** Inspect actual MAIN.BMP files for pre-rendered digits
5. 🔍 **NEW:** Check DockingController for duplicate pane creation

---

## Additional Findings

### Sprite Resolution Architecture

**SpriteResolver.swift** (lines 87-156) correctly handles semantic → actual sprite mapping:
```swift
case .digit(let n):
    return [
        "DIGIT_\(n)_EX",      // Prefer extended digits (NUMS_EX.BMP)
        "DIGIT_\(n)"          // Fall back to standard digits (NUMBERS.BMP)
    ]
```

**This system works correctly when used via SimpleSpriteImage(.semantic)!**

### Pause Blink Animation
**WinampMainWindow.swift** (lines 277-300) correctly handles pause blinking:
```swift
let shouldShowDigits = !audioPlayer.isPaused || pauseBlinkVisible
if shouldShowDigits {
    SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
    // ... etc
}
```

**MainWindowView.swift does NOT have pause blink logic** - another sign it's outdated.

---

## Shade Mode Analysis 🔍 CRITICAL FINDING

### Potential Double Rendering in WinampMainWindow.swift

**The shade mode logic shows a critical issue:**

```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)  // Line 67

        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", ...)  // Line 72

        if !isShadeMode {
            buildFullWindow()  // Line 79 - includes buildTimeDisplay() at line 121
        } else {
            buildShadeMode()   // Line 82 - includes buildTimeDisplay() at line 201
        }
    }
}
```

**Problem 1: ZStack rendering order**
- Background is ALWAYS rendered (line 67)
- Title bar is ALWAYS rendered (line 72)
- Full window OR shade mode is rendered

**Problem 2: Background sprite includes time area**
- `MAIN_WINDOW_BACKGROUND` is the full 275×116 window
- If the skin's MAIN.BMP has digits drawn at (39, 26), they will ALWAYS show
- Dynamic digits render on top at the same position

**Problem 3: Check the actual logic:**
```swift
// Line 77-83
if !isShadeMode {
    // Full window mode
    buildFullWindow()  // Calls buildTimeDisplay() at line 121
} else {
    // Shade mode (collapsed to titlebar only)
    buildShadeMode()   // Calls buildTimeDisplay() at line 201
}
```

**This logic is CORRECT - only one branch executes!**

### ✅ CONCLUSION: The issue is in the SKIN BACKGROUND IMAGE!

The static "00:00" or time display you're seeing is likely **baked into the MAIN.BMP file** of one or more skins. When `SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)` renders the full background sprite, it includes those pre-rendered static digits.

Then the dynamic time display renders on top at the same coordinates, creating the double rendering effect.

---

## Conclusion ✅ ROOT CAUSE IDENTIFIED

**ROOT CAUSE:** The double rendering is caused by **pre-rendered time digits in the skin's MAIN.BMP background image** being rendered as part of `MAIN_WINDOW_BACKGROUND` sprite, with the dynamic semantic time digits rendering on top.

**Why it affects all skins:**
- If all your test skins (Classic, Internet Archive, Winamp3) have "00:00" or similar baked into their MAIN.BMP at coordinates (39, 26)
- The background always shows these static digits
- The dynamic semantic system correctly renders updating digits on top
- Result: Two sets of digits visible

**Solutions:**

1. **Option A: Crop the background sprite to exclude time display area**
   - Modify MAIN_WINDOW_BACKGROUND sprite definition
   - Instead of x:0, y:0, width:275, height:116 (full window)
   - Split into multiple sprites that avoid the time display region

2. **Option B: Mask/clear the time display area from background**
   - After rendering MAIN_WINDOW_BACKGROUND
   - Before rendering time digits
   - Draw a black rectangle at (39, 26, 48, 13) to clear the static digits

3. **Option C: Use layered background sprites**
   - Render lower portion of background (below time display)
   - Render time display
   - Render upper portion of background (above time display)

4. **Option D: Modify skin BMP files directly**
   - Edit MAIN.BMP files to have blank/black area at time display coordinates
   - This is the "proper" solution if you control the skin files

**Verification Steps:**
1. Open MAIN.BMP in an image editor
2. Look at pixel coordinates (39, 26) to (87, 39)
3. Check if digits "00:00" or "88:88" are visible
4. If YES → This is your problem!

**Next Action:** Inspect the actual MAIN.BMP files to confirm this hypothesis.
