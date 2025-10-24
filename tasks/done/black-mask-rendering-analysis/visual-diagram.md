# Visual Explanation: Z-Index Rendering Problem

## Current Architecture (BROKEN)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SwiftUI ZStack Rendering                         │
└─────────────────────────────────────────────────────────────────────┘

Layer 0 (Bottom):
╔═══════════════════════════════════════════════════════════════════╗
║ SimpleSpriteImage("MAIN_WINDOW_BACKGROUND")                       ║
║ Size: 275×116px                                                    ║
║                                                                    ║
║    ┌───────────┐                                                  ║
║    │ 00:00     │ ← Static digits baked into background bitmap    ║
║    └───────────┘   at position (39, 26)                          ║
║    Position: (39, 26)                                             ║
╚═══════════════════════════════════════════════════════════════════╝

Layer 1:
╔═══════════════════════════════════════════════════════════════════╗
║ SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")                      ║
║ Size: 275×14px                                                     ║
║ Position: (0, 0)                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

Layer 2 (Top):
╔═══════════════════════════════════════════════════════════════════╗
║ buildFullWindow() → Group {                                       ║
║                                                                    ║
║   buildTimeDisplay() → ZStack {                                   ║
║                                                                    ║
║     ┌─────────────────────┐                                       ║
║     │ ████████████████    │ ← Color.black (48×13)                ║
║     │ 03:45               │ ← Dynamic digits rendered on top     ║
║     └─────────────────────┘                                       ║
║     Position: (39, 26) via .at(Coords.timeDisplay)               ║
║                                                                    ║
║     Problem: Black rectangle and digits are BOTH at Layer 2      ║
║              Background "00:00" is at Layer 0                     ║
║              ALL THREE ARE VISIBLE!                               ║
║   }                                                                ║
║                                                                    ║
║   Other UI elements...                                            ║
║ }                                                                  ║
╚═══════════════════════════════════════════════════════════════════╝

COMPOSITE RESULT (What User Sees):
┌───────────────┐
│ 00:00         │ ← Background static digits (Layer 0)
│ ████████████  │ ← Black mask (Layer 2) - doesn't cover background!
│ 03:45         │ ← Dynamic digits (Layer 2)
└───────────────┘

Why doesn't the black mask cover the background?
→ Because they're at DIFFERENT z-levels and SwiftUI's rendering
  doesn't properly overlap views in nested Groups/ZStacks
```

---

## Fixed Architecture (WORKING)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SwiftUI ZStack Rendering                         │
└─────────────────────────────────────────────────────────────────────┘

Layer 0 (Bottom):
╔═══════════════════════════════════════════════════════════════════╗
║ SimpleSpriteImage("MAIN_WINDOW_BACKGROUND")                       ║
║ Size: 275×116px                                                    ║
║                                                                    ║
║    ┌───────────┐                                                  ║
║    │ 00:00     │ ← Static digits baked into background bitmap    ║
║    └───────────┘   at position (39, 26)                          ║
║    Position: (39, 26)                                             ║
╚═══════════════════════════════════════════════════════════════════╝

Layer 1 (NEW - MASKS):
╔═══════════════════════════════════════════════════════════════════╗
║ Group {                                                            ║
║                                                                    ║
║   ┌─────────────────────┐                                         ║
║   │ ████████████████    │ ← Color.black (48×13)                  ║
║   └─────────────────────┘   COVERS background "00:00"            ║
║   Position: (39, 26) via .at(Coords.timeDisplay)                 ║
║                                                                    ║
║   ┌──────────────────────────────┐                                ║
║   │ ████████████████████████████ │ ← Volume slider mask (68×13) ║
║   └──────────────────────────────┘                                ║
║   Position: (107, 57) via .at(Coords.volumeSlider)               ║
║                                                                    ║
║   ┌───────────────────┐                                           ║
║   │ ████████████████  │ ← Balance slider mask (38×13)           ║
║   └───────────────────┘                                           ║
║   Position: (177, 57) via .at(Coords.balanceSlider)              ║
║ }                                                                  ║
╚═══════════════════════════════════════════════════════════════════╝

Layer 2:
╔═══════════════════════════════════════════════════════════════════╗
║ SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")                      ║
║ Size: 275×14px                                                     ║
║ Position: (0, 0)                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

Layer 3 (Top):
╔═══════════════════════════════════════════════════════════════════╗
║ buildFullWindow() → Group {                                       ║
║                                                                    ║
║   buildTimeDisplay() → ZStack {                                   ║
║                                                                    ║
║     ┌─────────────────────┐                                       ║
║     │ 03:45               │ ← Dynamic digits (TRANSPARENT bg)    ║
║     └─────────────────────┘                                       ║
║     Position: (39, 26) via .at(Coords.timeDisplay)               ║
║                                                                    ║
║     Renders on top of black mask (Layer 1)                        ║
║     Black mask hides background "00:00"                           ║
║   }                                                                ║
║                                                                    ║
║   Other UI elements...                                            ║
║ }                                                                  ║
╚═══════════════════════════════════════════════════════════════════╝

COMPOSITE RESULT (What User Sees):
┌───────────────┐
│ [HIDDEN]      │ ← Background "00:00" covered by black mask (Layer 1)
│ ████████████  │ ← Black mask (Layer 1) covers background
│ 03:45         │ ← Dynamic digits (Layer 3) render on top of mask
└───────────────┘

Result: ONLY dynamic "03:45" is visible!
```

---

## Layer Stack Comparison

### Before (BROKEN)

```
Z-Index | Content                        | Visibility
--------|--------------------------------|---------------------------
   0    | MAIN_WINDOW_BACKGROUND         | ✓ Static "00:00" visible
   1    | MAIN_TITLE_BAR_SELECTED        | ✓ Title bar visible
   2    | Group {                        |
        |   buildTimeDisplay() ZStack {  |
        |     Color.black                | ✓ Black rect visible
        |     Digits                     | ✓ Dynamic digits visible
        |   }                            |
        | }                              |

Problem: User sees ALL THREE: background "00:00" + black rect + digits
```

### After (FIXED)

```
Z-Index | Content                        | Visibility
--------|--------------------------------|---------------------------
   0    | MAIN_WINDOW_BACKGROUND         | ✗ Static "00:00" HIDDEN by Layer 1
   1    | Group {                        |
        |   Color.black masks            | ✓ Black rects visible
        | }                              |
   2    | MAIN_TITLE_BAR_SELECTED        | ✓ Title bar visible
   3    | Group {                        |
        |   buildTimeDisplay() ZStack {  |
        |     Digits                     | ✓ Dynamic digits visible
        |   }                            |
        | }                              |

Result: User sees ONLY: black background + dynamic digits
        Background "00:00" is completely covered by Layer 1 black mask
```

---

## Detailed Rendering Flow

### Current (BROKEN) - Frame by Frame

```
Frame 1: Render Background (z:0)
┌─────────────────────────────────┐
│                                 │
│    00:00 ← Static from bitmap  │
│                                 │
└─────────────────────────────────┘

Frame 2: Render Title Bar (z:1)
┌─────────────────────────────────┐
│ WINAMP ────────────── O □ X    │
│    00:00                        │
│                                 │
└─────────────────────────────────┘

Frame 3: Render buildFullWindow Group (z:2)
  → buildTimeDisplay() called
    → Returns ZStack with Color.black + digits
      → ZStack lays out internally:
         - Color.black at ZStack origin (0,0) local coords
         - Digits .offset() from origin
      → Entire ZStack .offset(x:39, y:26) applied

┌─────────────────────────────────┐
│ WINAMP ────────────── O □ X    │
│    00:00 ← STILL VISIBLE!      │
│    ████████████                 │
│    03:45                        │
└─────────────────────────────────┘

Why is "00:00" still visible?
→ The Color.black is inside a nested ZStack at z:2
→ Background "00:00" is part of the Layer 0 bitmap
→ SwiftUI's rendering doesn't properly detect overlap
→ Both are rendered, creating visual conflict
```

### Fixed (WORKING) - Frame by Frame

```
Frame 1: Render Background (z:0)
┌─────────────────────────────────┐
│                                 │
│    00:00 ← Static from bitmap  │
│                                 │
└─────────────────────────────────┘

Frame 2: Render Mask Group (z:1)
┌─────────────────────────────────┐
│                                 │
│    ████████████ ← BLACK MASK   │
│                                 │
└─────────────────────────────────┘
       ↓ COVERS background "00:00"

Frame 3: Render Title Bar (z:2)
┌─────────────────────────────────┐
│ WINAMP ────────────── O □ X    │
│    ████████████                 │
│                                 │
└─────────────────────────────────┘

Frame 4: Render buildFullWindow Group (z:3)
  → buildTimeDisplay() called
    → Returns ZStack with digits only (no Color.black)
      → Digits .offset() from ZStack origin
      → Entire ZStack .offset(x:39, y:26) applied

┌─────────────────────────────────┐
│ WINAMP ────────────── O □ X    │
│    ████████████                 │
│    03:45 ← DYNAMIC ONLY!       │
└─────────────────────────────────┘

Result: "00:00" is hidden by Layer 1 black mask
        Only "03:45" dynamic digits are visible
        Perfect rendering!
```

---

## Why .offset() Doesn't Fix Z-Order

### Common Misconception

```swift
// ❌ WRONG: Thinking offset changes z-order
ZStack {
    Background  // z:0
    View.offset(x: 100, y: 100)  // Still z:1, just moved visually
}
```

### How .offset() Actually Works

```swift
// .offset() is a VISUAL TRANSFORM, not a layout position
Color.black
    .frame(width: 48, height: 13)
    .offset(x: 39, y: 26)

// Equivalent to:
// 1. Layout Color.black at (0, 0) with size 48×13
// 2. Apply transform: translate(39, 26)
// 3. Visual position: (39, 26), layout position: (0, 0)
```

### Why This Matters for Z-Ordering

```swift
ZStack {
    Background at (0,0) size 275×116  // z:0, covers entire window

    Group {  // z:1
        buildTimeDisplay() {  // Returns ZStack
            ZStack {
                Color.black.frame(48×13)  // Layout at (0,0)
                Digits.offset(...)
            }
            .offset(x: 39, y: 26)  // Visual transform
        }
    }
}

// The offset makes Color.black APPEAR at (39,26)
// But it's still part of the z:1 Group
// Background at z:0 has "00:00" painted at pixel (39,26)
// SwiftUI renders:
//   1. Background bitmap (includes "00:00" at 39,26)
//   2. Color.black transformed to (39,26)
//   3. Digits transformed to (45,26), (56,26), etc.

// Problem: Background is a BITMAP with "00:00" baked in
//          The Color.black transform doesn't "cut out" that part
//          Both are rendered, creating double image
```

---

## Coordinate System Explanation

### SwiftUI Coordinate System

```
(0,0) ────────────────► X-axis
  │
  │    ┌─────────────────────────┐
  │    │ ZStack                  │
  │    │                         │
  │    │  ┌─────┐               │
  ▼    │  │View │ ← .offset(x,y)│
       │  └─────┘               │
Y-axis │                         │
       └─────────────────────────┘

Origin: Top-left (0,0)
X increases: Right →
Y increases: Down ↓
```

### Time Display Positioning

```
Main Window: 275×116px

    0────────────────────────────275
    ┌────────────────────────────┐  0
    │ WINAMP            [_][^][X]│
    │                            │ 14
    │┌──────────────────────────┐│
    ││                          ││
    ││ [►]  00:00               ││
    ││      ↑                   ││
    ││      └─ Position (39,26) ││
    ││         Size: 48×13      ││
    │└──────────────────────────┘│
    │                            │
    └────────────────────────────┘ 116
```

### Mask Coverage Area

```
Time Display Mask:
  Position: (39, 26)
  Size: 48×13
  Coverage: x∈[39,87], y∈[26,39]

Background "00:00":
  Painted at: ~(39, 26) in MAIN.BMP
  Size: ~48×13 (varies by skin font)

Perfect overlap IF z-ordering correct!
```

---

## Summary

**Problem:** Black masks at wrong z-level (z:2 instead of z:1)

**Cause:** Masks inside nested ZStack within Group, not in root ZStack

**Solution:** Move masks to root ZStack at explicit z:1 layer

**Visual Result:** Background static UI covered by masks, dynamic UI renders on top

**Implementation:** Simple view hierarchy restructuring (15 min)

**Testing:** Load track, verify no static "00:00" visible (5 min)
