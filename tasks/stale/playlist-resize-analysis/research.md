# Webamp Playlist Window Resize - Complete Technical Specification

**Task Context**: This research supports playlist resize implementation
**Status**: Complete specification, ready for implementation
**Priority**: Deferred (complex 3-section layout)

## Executive Summary

This document provides a **complete technical specification** for implementing playlist window resize in MacAmp based on the Webamp implementation. All measurements, sprites, behaviors, and constraints have been extracted from source code analysis.

### Cross-Task Context

**TASK 1** (magnetic-docking-foundation): ✅ COMPLETE
- Created foundation: 3 windows + magnetic snapping + persistence
- Deferred playlist resize (too complex for foundation scope)

**TASK 2** (milk-drop-video-support): Next
- Will add Video + Milkdrop windows
- **CRITICAL**: Video and Milkdrop are ALSO resizable windows
- Resize solution from this research applies to ALL 3 windows (Playlist, Video, Milkdrop)
- Could implement resize in Task 2 for all windows together

**TASK 3** (possible): If resize not done in Task 2
- Dedicated task: Implement resize for Playlist/Video/Milkdrop
- Use this complete specification
- ~8-12 hours per window (first is hardest, others follow pattern)

### Why Playlist/Video/Milkdrop Share Resize Pattern

All 3 windows use same Webamp pattern:
- Bottom section: LEFT (125px) + CENTER (expandable) + RIGHT (150px)
- Quantized segments: 25px width, 29px height
- BOTTOM_TILE sprite for center tiling
- 20×20 transparent drag handle at bottom-right
- Spacer visibility based on even/odd width
- Visualizer threshold at width > 2 segments

**Implementation Strategy**: Solve once, apply to all 3 windows!

---

## 1. RESIZE CONSTANTS

### Resize Segment Dimensions
```javascript
WINDOW_RESIZE_SEGMENT_WIDTH = 25    // pixels per width increment
WINDOW_RESIZE_SEGMENT_HEIGHT = 29   // pixels per height increment
```

### Base Window Dimensions
```javascript
WINDOW_WIDTH = 275                  // base playlist width (pixels)
WINDOW_HEIGHT = 116                 // used for main/equalizer windows
BASE_WINDOW_HEIGHT = 58            // base playlist content area height (pixels)
TRACK_HEIGHT = 13                  // pixels per track row
```

### Size Calculation Formula
```javascript
// Playlist window uses size array: [widthSegments, heightSegments]
pixelWidth = WINDOW_WIDTH + (widthSegments * WINDOW_RESIZE_SEGMENT_WIDTH)
pixelHeight = WINDOW_HEIGHT + (heightSegments * WINDOW_RESIZE_SEGMENT_HEIGHT)

// Number of visible tracks
visibleTracks = Math.floor((BASE_WINDOW_HEIGHT + WINDOW_RESIZE_SEGMENT_HEIGHT * heightSegments) / TRACK_HEIGHT)
```

### Default Size
- Initial size: `[0, 0]` segments (minimum size)
- Initial pixel dimensions: `275×116` pixels
- Initial visible tracks: `Math.floor(58 / 13) = 4` tracks

---

## 2. RESIZE CONSTRAINTS

### Size Bounds
**NO EXPLICIT MIN/MAX CONSTRAINTS IN CODE**

The implementation uses:
```typescript
const newWidth = Math.max(0, width + Math.round(x / WINDOW_RESIZE_SEGMENT_WIDTH));
const newHeight = Math.max(0, height + Math.round(y / WINDOW_RESIZE_SEGMENT_HEIGHT));
```

This means:
- **Minimum:** `[0, 0]` segments → `275×116` pixels
- **Maximum:** Unlimited (constrained only by user's browser window)

### Implicit Constraints
1. **Visualizer visibility threshold:** `playlistSize[0] > 2` (width must exceed 2 segments = 325px)
2. **Spacer tiles shown when:** `playlistSize[0] % 2 === 0` (even width values)

---

## 3. RESIZE HANDLE IMPLEMENTATION

### Component Structure
```tsx
<PlaylistResizeTarget />
  → wraps <ResizeTarget />
```

### CSS Positioning
```css
#playlist-window #playlist-resize-target {
  position: absolute;
  right: 0;
  bottom: 0;
  height: 20px;
  width: 20px;
}
```

### Drag Behavior (ResizeTarget.tsx)

**Event Flow:**
1. **mousedown/touchstart** on resize target
   - Captures starting mouse position `(x, y)`
   - Sets `mouseDown = true`

2. **mousemove/touchmove** (global listener)
   - Calculates delta from start: `deltaX = currentX - startX`
   - Quantizes to segments: `Math.round(deltaX / WINDOW_RESIZE_SEGMENT_WIDTH)`
   - Updates window size: `[width + segments, height + segments]`

3. **mouseup/touchend** (global listener)
   - Sets `mouseDown = false`
   - Removes global listeners

**Key Implementation Details:**
- Uses **quantized/snapped resizing** (not continuous)
- Resizes in discrete 25×29 pixel increments
- Event listeners attached to `window` object (allows drag outside element)
- State closed over from mousedown (prevents stale state issues)

### Skin Sprite
```javascript
PSIZE: ["#playlist-window #playlist-resize-target"]
```
Maps to skin cursor region (not a visual sprite, just a drag area).

---

## 4. BOTTOM BAR LAYOUT (THREE-SECTION DESIGN)

### Section Breakdown

**LEFT Section:**
```css
.playlist-bottom-left {
  width: 125px;
  height: 100%;
  position: absolute;
}
```
Contains:
- Add Menu (4 buttons)
- Remove Menu (4 buttons)
- Selection Menu (3 buttons)
- Misc Menu (3 buttons)

**Sprite:**
```javascript
PLAYLIST_BOTTOM_LEFT_CORNER: { x: 0, y: 72, width: 125, height: 38 }
```

**CENTER Section:**
```jsx
<div className="playlist-bottom-center draggable" />
```
**NO CSS WIDTH DEFINED** → Automatically fills available space between left (125px) and right (150px)

**Sprite:**
```javascript
PLAYLIST_BOTTOM_TILE: { x: 179, y: 0, width: 25, height: 38 }
```
This 25×38px tile **repeats horizontally** via CSS background-repeat.

**RIGHT Section:**
```css
.playlist-bottom-right {
  width: 150px;
  height: 100%;
  position: absolute;
  right: 0;
}
```
Contains:
- Visualizer area (75px wide, shows when `width > 2`)
- Action buttons (sort, file info, etc.)
- List menu
- Scroll up/down buttons
- Resize target (20×20px)

**Sprite:**
```javascript
PLAYLIST_BOTTOM_RIGHT_CORNER: { x: 126, y: 72, width: 150, height: 38 }
```

### Center Sprite Visibility Logic

**ALWAYS VISIBLE** - The center section exists as an empty div:
```jsx
<div className="playlist-bottom-center draggable" />
```

There is **NO conditional rendering** based on width. The PLAYLIST_BOTTOM_TILE sprite tiles continuously between left and right sections.

**At minimum width (275px):**
- Left: 125px
- Center: 275 - 125 - 150 = **0px** (collapsed, invisible)
- Right: 150px

**At width = 1 segment (300px):**
- Center: 300 - 125 - 150 = **25px** (exactly 1 tile visible)

**At width = 2 segments (325px):**
- Center: 325 - 125 - 150 = **50px** (2 tiles)

**Formula:**
```
centerWidth = totalWidth - 275
centerTiles = centerWidth / 25
```

---

## 5. TOP BAR LAYOUT (SPACER BEHAVIOR)

### Spacer Visibility Logic
```tsx
const showSpacers = playlistSize[0] % 2 === 0;
```

**Even widths (0, 2, 4, ...):** Spacers shown
**Odd widths (1, 3, 5, ...):** Spacers hidden

### Top Layout Structure
```jsx
<div className="playlist-top draggable">
  <div className="playlist-top-left" />                    {/* 25px */}
  {showSpacers && <div className="playlist-top-left-spacer" />}   {/* 12px */}
  <div className="playlist-top-left-fill" />              {/* flex-grow: 1 */}
  <div className="playlist-top-title" />                  {/* 100px */}
  {showSpacers && <div className="playlist-top-right-spacer" />}  {/* 13px */}
  <div className="playlist-top-right-fill" />             {/* flex-grow: 1 */}
  <div className="playlist-top-right" />                  {/* 25px */}
</div>
```

**Spacer widths:**
- Left spacer: `12px`
- Right spacer: `13px`
- Total added when shown: `25px`

This creates perfect alignment between odd/even widths by adding exactly one segment width (25px) of spacer tiles.

---

## 6. SPRITE ATLAS (PLEDIT.bmp)

### Key Sprites for Resize

```javascript
PLEDIT: [
  // Top sections
  { name: "PLAYLIST_TOP_TILE", x: 127, y: 21, width: 25, height: 20 },
  { name: "PLAYLIST_TOP_LEFT_CORNER", x: 0, y: 21, width: 25, height: 20 },
  { name: "PLAYLIST_TITLE_BAR", x: 26, y: 21, width: 100, height: 20 },
  { name: "PLAYLIST_TOP_RIGHT_CORNER", x: 153, y: 21, width: 25, height: 20 },

  // Top sections (selected state)
  { name: "PLAYLIST_TOP_TILE_SELECTED", x: 127, y: 0, width: 25, height: 20 },
  { name: "PLAYLIST_TOP_LEFT_SELECTED", x: 0, y: 0, width: 25, height: 20 },
  { name: "PLAYLIST_TITLE_BAR_SELECTED", x: 26, y: 0, width: 100, height: 20 },
  { name: "PLAYLIST_TOP_RIGHT_CORNER_SELECTED", x: 153, y: 0, width: 25, height: 20 },

  // Middle sections (vertical tiles)
  { name: "PLAYLIST_LEFT_TILE", x: 0, y: 42, width: 12, height: 29 },
  { name: "PLAYLIST_RIGHT_TILE", x: 31, y: 42, width: 20, height: 29 },

  // Bottom sections
  { name: "PLAYLIST_BOTTOM_TILE", x: 179, y: 0, width: 25, height: 38 },
  { name: "PLAYLIST_BOTTOM_LEFT_CORNER", x: 0, y: 72, width: 125, height: 38 },
  { name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 150, height: 38 },

  // Visualizer area (within bottom-right)
  { name: "PLAYLIST_VISUALIZER_BACKGROUND", x: 205, y: 0, width: 75, height: 38 },
]
```

### Tiling Patterns

**Horizontal tiling (top/bottom):**
- PLAYLIST_TOP_TILE (25×20) repeats horizontally in top-fill areas
- PLAYLIST_BOTTOM_TILE (25×38) repeats horizontally in center bottom

**Vertical tiling (sides):**
- PLAYLIST_LEFT_TILE (12×29) repeats vertically on left edge
- PLAYLIST_RIGHT_TILE (20×29) repeats vertically on right edge (includes scrollbar track)

---

## 7. VISUALIZER BEHAVIOR

### Visibility Logic
```tsx
const showVisualizer = playlistSize[0] > 2;
const activateVisualizer = !getWindowOpen(WINDOWS.MAIN);
```

**Conditions:**
1. **Shown when:** Width exceeds 2 segments (325px total width)
2. **Active when:** Main window is closed
3. **Positioned:** Absolute within bottom-right section
4. **Dimensions:** 75×38 pixels

### CSS Positioning
```css
#playlist-window .playlist-visualizer {
  width: 75px;
  height: 100%;
  position: absolute;
  right: 150px;  /* Positioned left of bottom-right corner */
}

#playlist-window .visualizer-wrapper {
  position: absolute;
  top: 12px;
  left: 2px;
  width: 72px;
  overflow: hidden;
}
```

---

## 8. WINDOW RELATIONSHIPS (MAGNETIC BEHAVIOR)

### Graph-Based Layout System

Webamp maintains a **spatial graph** of window relationships:
```typescript
interface Graph {
  [windowId: string]: {
    below?: string;    // Window ID directly below
    right?: string;    // Window ID directly to the right
  }
}
```

### Resize Propagation Algorithm

When a window resizes:
1. **Capture existing graph** (edge relationships between windows)
2. **Dispatch resize action** (update window size)
3. **Calculate position diff** required to maintain edges
4. **Update all affected window positions**

**Implementation (actionCreators/windows.ts):**
```typescript
function withWindowGraphIntegrity(action: Action): Thunk {
  return (dispatch, getState) => {
    const graph = Selectors.getWindowGraph(getState());
    const originalSizes = Selectors.getWindowSizes(getState());

    dispatch(action);  // Resize window

    const newSizes = Selectors.getWindowSizes(getState());
    const sizeDiff = calculateSizeDiff(originalSizes, newSizes);
    const positionDiff = getPositionDiff(graph, sizeDiff);

    dispatch(updateWindowPositions(positionDiff));
  };
}
```

### Overlap Detection

Windows determine edges by checking for overlap in perpendicular axis:
```typescript
// For vertical relationship (below)
const overlapsInX = !(isToTheLeft || isToTheRight);

// For horizontal relationship (right)
const overlapsInY = !(isAbove || isBelow);
```

**Example:**
- Playlist resizes wider → windows to the right shift right
- Playlist resizes taller → windows below shift down

---

## 9. SWIFTUI IMPLEMENTATION REQUIREMENTS

### State Model
```swift
// Segment-based size (matches Webamp)
@Published var playlistSize: Size2D = Size2D(width: 0, height: 0)

// Calculated pixel dimensions
var playlistPixelSize: CGSize {
    CGSize(
        width: 275 + (playlistSize.width * 25),
        height: 116 + (playlistSize.height * 29)
    )
}

// Visible track count
var visibleTracks: Int {
    Int(floor((58 + Double(playlistSize.height * 29)) / 13.0))
}
```

### Resize Gesture
```swift
.gesture(
    DragGesture()
        .onChanged { value in
            let deltaX = value.translation.width
            let deltaY = value.translation.height

            // Quantize to segments
            let newWidth = max(0, startSize.width + Int(round(deltaX / 25)))
            let newHeight = max(0, startSize.height + Int(round(deltaY / 29)))

            playlistSize = Size2D(width: newWidth, height: newHeight)
        }
)
```

### Bottom Bar Layout
```swift
HStack(spacing: 0) {
    // Left section (125px fixed)
    bottomLeftCorner
        .frame(width: 125, height: 38)

    // Center section (dynamic, tiles PLAYLIST_BOTTOM_TILE)
    if playlistPixelSize.width > 275 {
        bottomCenterTile
            .frame(width: playlistPixelSize.width - 275, height: 38)
    }

    // Right section (150px fixed)
    bottomRightCorner
        .frame(width: 150, height: 38)
}
```

### Spacer Visibility
```swift
let showSpacers = playlistSize.width % 2 == 0
```

### Visualizer Visibility
```swift
let showVisualizer = playlistSize.width > 2
```

---

## 10. KEY FINDINGS SUMMARY

| Aspect | Value/Behavior |
|--------|---------------|
| **Resize Increment** | Width: 25px, Height: 29px |
| **Minimum Size** | 275×116 pixels ([0,0] segments) |
| **Maximum Size** | Unbounded (browser constrained) |
| **Default Size** | 275×116 pixels |
| **Visible Tracks Formula** | `floor((58 + heightSegments*29) / 13)` |
| **Center Sprite Visibility** | Always present, width = totalWidth - 275 |
| **Center Sprite Tile** | PLAYLIST_BOTTOM_TILE (25×38px) |
| **Resize Handle Size** | 20×20 pixels (bottom-right) |
| **Resize Quantization** | YES (snaps to 25×29 increments) |
| **Spacer Behavior** | Shown when width is even |
| **Visualizer Threshold** | Width > 2 segments (325px) |
| **Window Graph System** | Maintains spatial relationships during resize |

---

## 11. IMPLEMENTATION CHECKLIST

- [ ] Create Size2D model (width/height in segments)
- [ ] Implement segment-to-pixel conversion formulas
- [ ] Build resize gesture with 25×29 quantization
- [ ] Extract all PLEDIT sprites (27 total for playlist)
- [ ] Implement three-section bottom layout (left/center/right)
- [ ] Add center tile horizontal repeat logic
- [ ] Implement spacer visibility (even/odd width)
- [ ] Add visualizer show/hide logic (width > 2)
- [ ] Calculate visible track count dynamically
- [ ] Build window graph relationship system
- [ ] Implement resize propagation algorithm
- [ ] Test at sizes: [0,0], [1,0], [2,0], [2,2], [4,4]
- [ ] Verify sprite alignment at all sizes

---

## 12. CRITICAL IMPLEMENTATION NOTES

1. **Size is stored in SEGMENTS, not pixels**
   - State: `[0, 0]` to `[n, m]` segments
   - Display: Convert to pixels for rendering

2. **Resize must be quantized**
   - Continuous drag → round to nearest segment
   - Use `Math.round(delta / segmentSize)`

3. **Center tile ALWAYS exists**
   - Not conditionally rendered
   - Width can be 0 (collapsed)
   - Tiles repeat via background-image CSS

4. **Spacers are width-parity dependent**
   - Even widths: show spacers (12px + 13px)
   - Odd widths: hide spacers
   - Maintains visual alignment

5. **Window graph must be maintained**
   - Calculate before resize
   - Restore spatial relationships after
   - Prevents windows from detaching

---

## 13. OPEN QUESTIONS FOR SWIFTUI

1. **How to implement CSS background-repeat tiling in SwiftUI?**
   - Option A: Use `Image().resizable().tile()` modifier
   - Option B: Generate repeated sprite manually
   - Option C: Use geometry reader to calculate tile count

2. **Should we enforce maximum size constraints?**
   - Webamp has none (browser-limited)
   - macOS could limit to screen size
   - Suggest: `maxWidth = screenWidth - margin`

3. **Window graph system in SwiftUI?**
   - NSWindow frame manipulation for magnetic behavior?
   - Or implement drag constraints in SwiftUI positioning?
   - Needs research on WindowGroup capabilities

4. **Cursor regions for resize handle?**
   - Webamp uses skin cursor definitions
   - macOS could use native resize cursor
   - Or custom cursor from skin

---

## FILES ANALYZED

1. `/packages/webamp/js/components/PlaylistWindow/index.tsx` - Main window structure
2. `/packages/webamp/js/components/ResizeTarget.tsx` - Drag gesture logic
3. `/packages/webamp/js/components/PlaylistWindow/PlaylistResizeTarget.tsx` - Playlist-specific wrapper
4. `/packages/webamp/css/playlist-window.css` - Layout and positioning
5. `/packages/webamp/js/constants.ts` - Size constants
6. `/packages/webamp/js/selectors.ts` - Size calculation formulas
7. `/packages/webamp/js/reducers/windows.ts` - State management
8. `/packages/webamp/js/actionCreators/windows.ts` - Window graph system
9. `/packages/webamp/js/resizeUtils.ts` - Position diff calculation
10. `/packages/webamp/js/skinSprites.ts` - Sprite definitions

---

**Analysis Complete:** All technical details extracted and documented for MacAmp implementation.
