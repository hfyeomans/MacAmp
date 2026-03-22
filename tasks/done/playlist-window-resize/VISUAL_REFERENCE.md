# Visual Reference - Playlist Window Resize

This document provides ASCII art diagrams to understand the three-section layout.

---

## Current MacAmp Layout (Two-Section Workaround)

```
┌──────────────────────────────────────────────────────────────┐
│ PLAYLIST WINDOW (Fixed Size: 275×300)                       │
├──────────────────────────────────────────────────────────────┤
│ ╔══════════════════════════════════════════════════════════╗ │
│ ║ TOP BAR (Title, Shade, Close buttons)                   ║ │
│ ╚══════════════════════════════════════════════════════════╝ │
├──────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐   │
│ │                                                        │   │
│ │    TRACK LIST (Scrollable)                            │   │
│ │    1. Song Name - Artist                              │   │
│ │    2. Another Song - Band                             │   │
│ │    3. Track Three - Group                             │   │
│ │                                                        │   │
│ └────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│ ╔═══════════════════╦═════════════════════════════════════╗ │
│ ║ BOTTOM LEFT       ║  BOTTOM RIGHT                       ║ │
│ ║ 125px             ║  154px                              ║ │
│ ║                   ║                                     ║ │
│ ║ [Add] [Rem]       ║  [▶][⏸][⏹][⏮][⏭]  [List] [Resize]║ │
│ ║ [Sel] [Misc]      ║  Time: 3:45 / 12:30                 ║ │
│ ╚═══════════════════╩═════════════════════════════════════╝ │
│                                                              │
│ ↑ NO CENTER SECTION - LEFT AND RIGHT DIRECTLY ADJACENT      │
│ ↑ CANNOT RESIZE - NO SPACE TO EXPAND                        │
└──────────────────────────────────────────────────────────────┘
```

---

## Proper Winamp Layout (Three-Section with Resize)

### Minimum Width (275px - Center Hidden)

```
┌──────────────────────────────────────────────────────────────┐
│ PLAYLIST WINDOW (Resizable: Min 275px)                      │
├──────────────────────────────────────────────────────────────┤
│ ╔══════════════════════════════════════════════════════════╗ │
│ ║ TOP BAR (Title, Shade, Close buttons)                   ║ │
│ ╚══════════════════════════════════════════════════════════╝ │
├──────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────┐   │
│ │                                                        │   │
│ │    TRACK LIST (Scrollable)                            │   │
│ │    1. Song Name - Artist                              │   │
│ │    2. Another Song - Band                             │   │
│ │                                                        │   │
│ └────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│ ╔═══════════════════╦╦═════════════════════════════════════╗ │
│ ║ BOTTOM LEFT       ║║  BOTTOM RIGHT                       ║ │
│ ║ 125px             ║║  150px                              ║ │
│ ║                   ║║                                     ║ │
│ ║ [Add] [Rem]       ║║  [▶][⏸][⏹][⏮][⏭]  [List] [Resize]║ │
│ ║ [Sel] [Misc]      ║║  Time: 3:45 / 12:30                 ║ │
│ ╚═══════════════════╩╩═════════════════════════════════════╝ │
│                      ↑                                       │
│                      CENTER (0px - collapsed)                │
│                      Tiled background sprite                 │
└──────────────────────────────────────────────────────────────┘
```

### Medium Width (400px - Center Visible)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ PLAYLIST WINDOW (Resizable: 400px)                                      │
├──────────────────────────────────────────────────────────────────────────┤
│ ╔════════════════════════════════════════════════════════════════════╗   │
│ ║ TOP BAR (Title, Shade, Close buttons)                             ║   │
│ ╚════════════════════════════════════════════════════════════════════╝   │
├──────────────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────────────────┐     │
│ │                                                                  │     │
│ │    TRACK LIST (Scrollable) - Wider view                         │     │
│ │    1. Song Name - Artist - Album - 3:45                         │     │
│ │    2. Another Song - Band - Collection - 4:20                   │     │
│ │                                                                  │     │
│ └──────────────────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────────┤
│ ╔═══════════════════╦═══════════════════════╦══════════════════════════╗│
│ ║ BOTTOM LEFT       ║  BOTTOM CENTER        ║  BOTTOM RIGHT            ║│
│ ║ 125px             ║  125px (EXPANDABLE)   ║  150px                   ║│
│ ║                   ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║                          ║│
│ ║ [Add] [Rem]       ║  ▓ Tiled Background ▓ ║  [▶][⏸][⏹][⏮][⏭] [List]║│
│ ║ [Sel] [Misc]      ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  Time: 3:45 / 12:30     ║│
│ ╚═══════════════════╩═══════════════════════╩══════════════════════════╝│
│                      ↑                                                   │
│                      CENTER (125px - expanded)                           │
│                      Background sprite tiles horizontally                │
└──────────────────────────────────────────────────────────────────────────┘
```

### Maximum Width (600px - Center Fully Expanded)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│ PLAYLIST WINDOW (Resizable: 600px)                                                            │
├────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ╔══════════════════════════════════════════════════════════════════════════════════════════╗   │
│ ║ TOP BAR (Title, Shade, Close buttons)                                                   ║   │
│ ╚══════════════════════════════════════════════════════════════════════════════════════════╝   │
├────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────────────────────────────────────┐     │
│ │                                                                                        │     │
│ │    TRACK LIST (Scrollable) - Maximum width view                                       │     │
│ │    1. Song Name - Artist - Album - Duration - Genre - Year - 3:45                    │     │
│ │    2. Another Song - Band - Collection - Length - Category - 2001 - 4:20             │     │
│ │                                                                                        │     │
│ └────────────────────────────────────────────────────────────────────────────────────────┘     │
├────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ╔═══════════════════╦═══════════════════════════════════════════╦══════════════════════════╗  │
│ ║ BOTTOM LEFT       ║  BOTTOM CENTER                            ║  BOTTOM RIGHT            ║  │
│ ║ 125px             ║  325px (FULLY EXPANDED)                   ║  150px                   ║  │
│ ║                   ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║                          ║  │
│ ║ [Add] [Rem]       ║  ▓ Tiled Background (Repeating Pattern) ▓ ║  [▶][⏸][⏹][⏮][⏭] [List]║  │
│ ║ [Sel] [Misc]      ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  Time: 3:45 / 12:30     ║  │
│ ╚═══════════════════╩═══════════════════════════════════════════╩══════════════════════════╝  │
│                      ↑                                                                         │
│                      CENTER (325px - maximum expansion)                                        │
│                      Background sprite tiles seamlessly across entire width                    │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Layout Math

### Minimum Width (275px)
```
125px (left) + 0px (center) + 150px (right) = 275px total
```

### Medium Width (400px)
```
125px (left) + 125px (center) + 150px (right) = 400px total
```

### Maximum Width (600px)
```
125px (left) + 325px (center) + 150px (right) = 600px total
```

### Formula
```
Total Width = 125 + centerWidth + 150
centerWidth = Total Width - 275
```

---

## Top Section Layout (Also Three-Part)

```
╔════════════════════════════════════════════════════════════════╗
║ ┌──┬─┬────────────────────────────────────┬─┬────────────┬──┐ ║
║ │LC│S│   LEFT FILL (expandable)           │T│ RIGHT FILL │RC│ ║
║ └──┴─┴────────────────────────────────────┴─┴────────────┴──┘ ║
╚════════════════════════════════════════════════════════════════╝

LC = Left Corner (25px)
S  = Spacer (12px) - only if even width
LF = Left Fill (expandable) - tiles background
T  = Title (100px)
RF = Right Fill (expandable) - tiles background
S  = Spacer (13px) - only if even width
RC = Right Corner (25px) - Shade/Close buttons
```

**Key Difference:**
- **Top section:** Uses **flexbox** with `flex-grow: 1` for fills
- **Bottom section:** Uses **absolute positioning** with implicit center gap

---

## Middle Section Layout (Tracklist)

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──┬──────────────────────────────────────────────────┬────┐ │
│ │LB│  TRACK LIST (scrollable)                        │ SB │ │
│ │  │  1. Song Name - Artist                          │    │ │
│ │  │  2. Another Song - Band                         │    │ │
│ │  │  3. Track Three - Group                         │    │ │
│ │  │  [... more tracks ...]                          │ ▲  │ │
│ │  │                                                  │ │  │ │
│ │  │                                                  │ ▓  │ │
│ │  │                                                  │ │  │ │
│ │  │                                                  │ ▼  │ │
│ └──┴──────────────────────────────────────────────────┴────┘ │
└──────────────────────────────────────────────────────────────┘

LB = Left Border (12px) - repeating vertical pattern
TL = Track List (expandable) - grows to fill
SB = Scroll Bar (20px) - right border + scrollbar
```

**Layout Strategy:**
- HStack with fixed-width borders
- Center section uses `flex-grow: 1`
- No three-part tiling (just borders + content)

---

## Sprite Tiling Visualization

### PLAYLIST_BOTTOM_CENTER_TILE (Hypothetical)

Assuming the tile is 2px wide for seamless repetition:

```
┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐
│░│▓│░│▓│░│▓│░│▓│░│▓│░│▓│░│▓│░│
└─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘
 ↑   ↑
 2px tile repeats horizontally

Each tile: 2×38 pixels
Repeats: (centerWidth / 2) times
Result: Seamless horizontal pattern
```

**Alternative:** Tile could be 1px wide for solid color/gradient

```
┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐
││││││││││││││││
└┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┘
 ↑
 1px tile repeats

Each tile: 1×38 pixels
Repeats: centerWidth times
Result: Smooth gradient or solid color
```

---

## Resize Handle Position

```
╔═══════════════════╦═════════════════╦══════════════════════════╗
║ BOTTOM LEFT       ║  BOTTOM CENTER  ║  BOTTOM RIGHT            ║
║                   ║                 ║                          ║
║ [Add] [Rem]       ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  [▶][⏸][⏹][⏮][⏭]      ║
║ [Sel] [Misc]      ║  ▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  Time: 3:45 / 12:30 ┌──┐║
╚═══════════════════╩═════════════════╩═══════════════════════│▒▒│╝
                                                               │▒▒│
                                                               └──┘
                                                                 ↑
                                                    Resize Handle (20×20px)
                                                    Bottom-right corner
                                                    Drag to resize window
```

**Implementation Options:**
1. **Custom drag gesture** on 20×20px area
2. **Built-in macOS resize** (standard window behavior)
3. **Hybrid:** Custom visual + system functionality

---

## SwiftUI Layout Structure (Conceptual)

```swift
VStack(spacing: 0) {
    // TOP SECTION (20px height)
    topBar()
        .frame(height: 20)

    // MIDDLE SECTION (expandable height)
    middleSection()
        .frame(minHeight: 100)

    // BOTTOM SECTION (38px height)
    ZStack {
        // Background layer (center tiling)
        GeometryReader { geo in
            centerTileBackground()
                .frame(width: geo.size.width)
        }

        // Foreground layer (left/right positioned)
        HStack(spacing: 0) {
            bottomLeft()
                .frame(width: 125, height: 38)

            Spacer()  // EXPANDABLE CENTER GAP

            bottomRight()
                .frame(width: 150, height: 38)
        }
    }
    .frame(height: 38)
}
.frame(minWidth: 275, minHeight: 200)
.frame(idealWidth: 275, idealHeight: 300)
```

**Key Points:**
- `Spacer()` creates the expandable gap
- `ZStack` allows background tiling under foreground elements
- Left/right sections fixed width, center grows/shrinks

---

## Visual Comparison: Before vs After

### Before (Current MacAmp)
```
┌─────────┬──────────┐
│  LEFT   │  RIGHT   │  ← Directly adjacent
│ 125px   │  154px   │  ← Cannot expand
└─────────┴──────────┘
    ↑
    No space for expansion
    Window cannot resize
```

### After (Proper Implementation)
```
┌─────────┬─────────┬──────────┐
│  LEFT   │ CENTER  │  RIGHT   │  ← Three sections
│ 125px   │ 0-500px │  150px   │  ← Center expands
└─────────┴─────────┴──────────┘
            ↑
            Expandable gap
            Tiled background
            Window can resize
```

---

## Implementation Checklist

- [ ] Add `PLAYLIST_BOTTOM_CENTER_TILE` sprite definition
- [ ] Refactor bottom section to use ZStack + HStack + Spacer
- [ ] Position left/right sections with fixed widths
- [ ] Implement center background tiling
- [ ] Add window resize support (min: 275px, max: ~1000px)
- [ ] Add resize handle (bottom-right corner)
- [ ] Track window size in state
- [ ] Persist size between launches
- [ ] Test with multiple skins
- [ ] Verify sprite tiling works correctly
- [ ] Add smooth resize animation
- [ ] Update documentation

---

**Created:** 2025-10-23
**Purpose:** Visual understanding of three-section layout
**Status:** Reference material for implementation
