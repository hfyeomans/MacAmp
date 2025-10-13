# Visual Explanation: Double Rendering Issue

## The Problem (What You're Seeing)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Winamp Main Window                                                 │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ TITLEBAR                                         [_] [▫] [×]  │ │
│  ├───────────────────────────────────────────────────────────────┤ │
│  │                                                               │ │
│  │  [►] Time: 0000:0033   ← STATIC (from MAIN.BMP background)   │ │
│  │       Time: 00:45      ← DYNAMIC (from semantic sprites)     │ │
│  │            ^^^ Double rendering!                              │ │
│  │                                                               │ │
│  │  Track: My Song.mp3                                          │ │
│  │                                                               │ │
│  │  [Visualizer]                                                 │ │
│  │                                                               │ │
│  │  [◄◄] [►] [||] [■] [►►] [⏏]                                 │ │
│  │                                                               │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Why It's Happening

### Layer 1: Background (MAIN.BMP)
```
MAIN.BMP (275×116 pixels)
┌─────────────────────────────────────────┐
│                                         │ ← Full window background
│  Position (39, 26):                     │
│  ┌──────────┐                           │
│  │ 00:00    │ ← Static digits baked in  │
│  └──────────┘                           │
│                                         │
│  [buttons and UI elements]              │
└─────────────────────────────────────────┘
```

### Layer 2: Dynamic Sprites (Semantic System)
```
At position (39, 26):
┌──────────────────────────────────┐
│ SimpleSpriteImage(.digit(0), ...) │ ← Updates every second
│ SimpleSpriteImage(.digit(0), ...) │
│ SimpleSpriteImage(.character(58)) │ ← Colon ":"
│ SimpleSpriteImage(.digit(4), ...) │
│ SimpleSpriteImage(.digit(5), ...) │
└──────────────────────────────────┘
Renders as: "00:45" (incrementing)
```

### Combined Result: OVERLAP! 🔴
```
Background digits: "00:00" (static, never changes)
      +
Dynamic digits:    "00:45" (incrementing)
      =
Double digits visible on screen!
```

## The Architecture (What's Actually Running)

```
MacAmpApp.swift
    └─► WindowGroup
         └─► UnifiedDockView
              └─► case .main:
                   └─► WinampMainWindow ✅ ONLY THIS IS ACTIVE
                        └─► body: ZStack {
                             ├─► SimpleSpriteImage("MAIN_WINDOW_BACKGROUND") ← Contains static digits
                             ├─► SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")
                             └─► if !isShadeMode {
                                  └─► buildFullWindow()
                                       └─► buildTimeDisplay() ← Dynamic digits
                                            ├─► SimpleSpriteImage(.digit(0))
                                            ├─► SimpleSpriteImage(.character(58))
                                            └─► SimpleSpriteImage(.digit(5))
                                }
```

**NOT ACTIVE:**
```
❌ MainWindowView.swift (obsolete experimental UI)
```

## Coordinate Analysis

### Time Display Region
```
┌─────────────────────────────────────────────────────────┐
│ MAIN.BMP (275×116)                                      │
│                                                         │
│    0,0                                                  │
│     ┌─────────────────────────────────────────────┐   │
│     │ ▓▓▓▓▓▓▓▓▓▓ [_][▫][×]                        │   │ ← Titlebar
│     │                                              │   │
│     │ [►]  ┌────────────┐  Track Info ───────►   │   │
│     │      │ 00:00      │  ← (39,26) 48×13      │   │ ← Time display
│     │      └────────────┘                        │   │
│     │                                              │   │
│     │ [Visualizer]                                │   │
│     │                                              │   │
│     │ [Position Slider ─────────────]             │   │
│     │                                              │   │
│     │ [◄◄] [►] [||] [■] [►►] [⏏]                │   │
│     │                                              │   │
│     └─────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘

Time Display Coordinates:
- Position: (39, 26) from top-left
- Size: 48×13 pixels
- Contains: 4 digits (9px each) + 1 colon (5px) + gaps (2px each)
```

### Digit Layout (Dynamic Rendering)
```
Position (39, 26) + offsets:

┌───┬─┬───┬─┬─┬─┬───┬─┬───┐
│ M │2│ M │2│:│2│ S │2│ S │  M = Minute digit (9px)
│ I │p│ I │p│5│p│ E │p│ E │  S = Second digit (9px)
│ N │x│ N │p│p│p│ C │p│ C │  : = Colon (5px)
│ 1 │ │ 2 │ │x│ │ 1 │ │ 2 │  2px = Gap
└───┴─┴───┴─┴─┴─┴───┴─┴───┘
  6   2  17  2  28 2  35  2  46  ← x-offsets
```

## The Solution: Mask Static Digits

### Before Fix (Current State)
```
┌────────────────────────────────────┐
│ Background Layer                   │
│ ┌────────┐                         │
│ │ 00:00  │ ← Static digits visible │
│ └────────┘                         │
└────────────────────────────────────┘
             ↑
         Overlays
             ↓
┌────────────────────────────────────┐
│ Dynamic Layer                      │
│ ┌────────┐                         │
│ │ 00:45  │ ← Dynamic digits        │
│ └────────┘                         │
└────────────────────────────────────┘
         =
    DOUBLE DIGITS!
```

### After Fix (Proposed Solution)
```
┌────────────────────────────────────┐
│ Background Layer                   │
│ ┌────────┐                         │
│ │ 00:00  │ ← Static digits         │
│ └────────┘                         │
└────────────────────────────────────┘
             ↓
         Add Mask
             ↓
┌────────────────────────────────────┐
│ Masking Layer                      │
│ ┌────────┐                         │
│ │████████│ ← Black rectangle       │
│ └────────┘   (48×13 at 39,26)     │
└────────────────────────────────────┘
             ↓
       Render Digits
             ↓
┌────────────────────────────────────┐
│ Dynamic Layer                      │
│ ┌────────┐                         │
│ │ 00:45  │ ← Only these visible!   │
│ └────────┘                         │
└────────────────────────────────────┘
         =
    SINGLE DIGITS! ✅
```

## Code Comparison

### Current Code (Double Rendering)
```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ❌ Background with static digits shows through!

        // Dynamic digits render on top
        SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
            .offset(x: 6, y: 0)
        // ... more digits
    }
    .at(Coords.timeDisplay) // Position at (39, 26)
}
```

### Fixed Code (Single Rendering)
```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ✅ Mask the static digits from background
        Color.black
            .frame(width: 48, height: 13)

        // Dynamic digits render on top of mask
        SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13)
            .offset(x: 6, y: 0)
        // ... more digits
    }
    .at(Coords.timeDisplay) // Position at (39, 26)
}
```

## Testing Verification

### How to Confirm the Hypothesis

1. **Open MAIN.BMP in image editor:**
   ```bash
   open -a Preview /Users/hank/dev/src/MacAmp/tmp/Internet-Archive/MAIN.bmp
   ```

2. **Use ruler/coordinates to check pixel (39, 26):**
   - If you see "00:00" or "88:88" → CONFIRMED!
   - If you see black/blank area → Not the issue

3. **Check all test skins:**
   - Classic Winamp
   - Internet Archive
   - Winamp3 Classified

### Expected Results After Fix

- **Before:** Two sets of digits (one static, one moving)
- **After:** One set of digits (incrementing correctly)
- **Pause blink:** Digits blink on/off, colon stays visible
- **Remaining time:** Minus sign appears, digits count down

## Why Classic Winamp Didn't Have This Problem

Original Winamp rendered the entire UI manually:
1. Clear the time display region
2. Draw background (excluding time area)
3. Draw digits on top

Modern approach with sprite sheets:
1. Draw entire background as one image
2. Draw digits on top
3. ❌ Static digits in background show through!

**Solution:** Mimic the original approach by masking the time display region.
