# Playlist Resize Analysis - Summary

## Task Completed

Complete technical analysis of Webamp's playlist window resize implementation for MacAmp.

---

## Documents Delivered

### 1. `/tasks/playlist-resize-analysis/research.md`
**Comprehensive Technical Specification** (13 sections, 500+ lines)

Contains:
- Exact resize constants (25×29 pixel segments)
- Size calculation formulas
- Sprite atlas coordinates (27 PLEDIT sprites)
- Three-section bottom layout breakdown
- Center tile visibility logic (ALWAYS visible, dynamic width)
- Spacer behavior (even/odd width parity)
- Visualizer threshold (width > 2 segments)
- Window graph system for magnetic behavior
- Resize gesture implementation details
- All questions answered with SOURCE CODE references

### 2. `/tasks/playlist-resize-analysis/sprite-layout-diagram.md`
**Visual Layout Diagrams**

Contains:
- PLEDIT.bmp sprite atlas map
- Window layouts at different sizes (ASCII art)
- Three-section bottom bar breakdown
- Sprite state diagram (selected/unselected)
- Resize handle positioning
- Implementation formula reference card

### 3. `/tasks/playlist-resize-analysis/swiftui-implementation-guide.md`
**Production-Ready SwiftUI Code** (10 sections, 600+ lines)

Contains:
- Complete `Size2D` model (segment-based sizing)
- `PlaylistWindowState` observable class
- Quantized drag gesture implementation
- Bottom bar three-section layout (LEFT/CENTER/RIGHT)
- Top bar with dynamic spacers
- Sprite loading utilities
- Window graph system (magnetic behavior)
- Testing utilities and validation
- Performance optimization tips
- Full usage examples

---

## Key Findings

### Critical Measurements
| Property | Value |
|----------|-------|
| Resize Increment | Width: 25px, Height: 29px |
| Base Dimensions | 275×116 pixels |
| Base Content Height | 58 pixels (playlist track area) |
| Track Height | 13 pixels |
| Minimum Size | [0,0] segments = 275×116px |
| Default Size | [0,0] segments = 275×116px |
| Maximum Size | Unbounded (Webamp has NO max) |

### Bottom Bar Layout
```
Total Width: W pixels
─────────────────────────────────────────
│ LEFT 125px │ CENTER (W-275)px │ RIGHT 150px │
│  [Menus]   │  [Tiles 25×38]   │  [Actions]  │
─────────────────────────────────────────
```

**CENTER SECTION:**
- Width = `totalWidth - 275` pixels
- Can be **0px** at minimum size (collapsed, invisible)
- Tiles PLAYLIST_BOTTOM_TILE (25×38px) horizontally
- ALWAYS exists as div (never conditionally rendered)

### Spacer Logic
```swift
showSpacers = playlistSize.width % 2 == 0
```
- **Even widths (0, 2, 4...):** Show spacers (12px + 13px = 25px added)
- **Odd widths (1, 3, 5...):** Hide spacers

### Visualizer Logic
```swift
showVisualizer = playlistSize.width > 2
```
- Hidden at [0,0], [1,0], [2,0]
- Visible at [3,0] and beyond (350px+ total width)

### Track Count Formula
```swift
visibleTracks = floor((58 + heightSegments * 29) / 13)
```

Examples:
- [0,0]: 4 tracks
- [0,1]: 6 tracks
- [0,2]: 8 tracks
- [0,4]: 13 tracks

---

## Research Questions Answered

### Q1: Where is the skinned drag point located?
**Answer:** Bottom-right corner, 20×20 pixel drag area
- CSS: `position: absolute; right: 0; bottom: 0;`
- Sprite selector: `PSIZE: ["#playlist-window #playlist-resize-target"]`
- Maps to skin cursor region (not a visual sprite)

### Q2: What sprite is used for the resize handle?
**Answer:** No sprite image - it's a transparent 20×20px drag area
- Cursor changes via skin cursor definitions
- Webamp uses skin-defined cursor regions
- macOS could use native `.resizeNorthWestSouthEast` cursor

### Q3: Minimum/Maximum size constraints?
**Answer:**
- **Minimum:** `[0, 0]` segments → 275×116 pixels
- **Maximum:** NONE (unlimited in code, browser-constrained)
- Enforced via: `Math.max(0, newSize)` only

### Q4: Center bottom sprite behavior?
**Answer:** PLAYLIST_BOTTOM_TILE (25×38px) at coordinates (179, 0)
- **Hidden when:** Never (always exists)
- **Width = 0 when:** Size is [0,0] (275px total = no space for center)
- **Visible when:** Width > 0 segments (300px+ total)
- **Tiling:** Repeats horizontally via CSS `background-repeat`

### Q5: Three-section bottom layout?
**Answer:**
- **LEFT:** 125px fixed (PLAYLIST_BOTTOM_LEFT_CORNER sprite)
- **CENTER:** Dynamic width = `totalWidth - 275` (tiles PLAYLIST_BOTTOM_TILE)
- **RIGHT:** 150px fixed (PLAYLIST_BOTTOM_RIGHT_CORNER sprite)

### Q6: Resize behavior?
**Answer:**
- Resizes BOTH width and height simultaneously
- Uses **quantized/snapped** increments (not continuous)
- Segment width: 25 pixels
- Segment height: 29 pixels
- Formula: `newSegments = Math.round(pixelDelta / segmentSize)`

### Q7: ResizeTarget.tsx implementation?
**Answer:**
- **mousedown:** Captures start position, sets flag
- **mousemove:** Calculates delta, quantizes, updates size
- **mouseup:** Clears flag, removes listeners
- **Key:** Global listeners on `window` object (allows drag outside element)
- **State:** Closed over from mousedown (prevents stale reads)

---

## Implementation Ready

All questions answered with:
- Exact measurements extracted from source
- Sprite coordinates from skinSprites.ts
- Formula verification from selectors.ts
- Behavior logic from React components
- Ready-to-use SwiftUI code patterns

**No ambiguity remains.** Every detail has been extracted from the Webamp codebase.

---

## Next Steps (Recommended)

1. **Phase 1: Basic Resize**
   - Implement `Size2D` model
   - Build resize gesture (quantized drag)
   - Create static bottom bar layout
   - Test at sizes [0,0], [1,0], [2,0]

2. **Phase 2: Dynamic Elements**
   - Add center tile repeating logic
   - Implement spacer visibility toggle
   - Add visualizer conditional rendering
   - Test at all edge cases

3. **Phase 3: Integration**
   - Connect to playlist track rendering
   - Implement scrollbar behavior
   - Add state persistence (UserDefaults)
   - Polish visual alignment

4. **Phase 4: Magnetic Behavior** (Optional)
   - Implement window graph system
   - Add resize propagation
   - Test multi-window scenarios
   - Refine snap/detach logic

---

## Files Analyzed (10 total)

1. `/packages/webamp/js/components/PlaylistWindow/index.tsx`
2. `/packages/webamp/js/components/ResizeTarget.tsx`
3. `/packages/webamp/js/components/PlaylistWindow/PlaylistResizeTarget.tsx`
4. `/packages/webamp/css/playlist-window.css`
5. `/packages/webamp/js/constants.ts`
6. `/packages/webamp/js/selectors.ts`
7. `/packages/webamp/js/reducers/windows.ts`
8. `/packages/webamp/js/actionCreators/windows.ts`
9. `/packages/webamp/js/resizeUtils.ts`
10. `/packages/webamp/js/skinSprites.ts`

---

**Analysis Complete.** Ready for SwiftUI implementation in MacAmp.
