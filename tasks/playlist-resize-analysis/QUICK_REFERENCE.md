# Playlist Resize - Quick Reference Card

## Constants (Copy-Paste Ready)

```swift
// Resize segments
let SEGMENT_WIDTH = 25          // pixels per width increment
let SEGMENT_HEIGHT = 29         // pixels per height increment

// Base dimensions
let BASE_WIDTH = 275            // minimum playlist width
let BASE_HEIGHT = 116           // minimum playlist total height
let BASE_CONTENT_HEIGHT = 58    // track area height at minimum

// Fixed sections
let BOTTOM_LEFT_WIDTH = 125     // left corner sprite width
let BOTTOM_RIGHT_WIDTH = 150    // right corner sprite width
let TOP_HEIGHT = 20             // top bar height
let BOTTOM_HEIGHT = 38          // bottom bar height
let TRACK_HEIGHT = 13           // pixels per track row

// Spacers
let LEFT_SPACER_WIDTH = 12
let RIGHT_SPACER_WIDTH = 13
let TOTAL_SPACER_WIDTH = 25     // 12 + 13

// Visualizer
let VISUALIZER_WIDTH = 75
let VISUALIZER_HEIGHT = 38
let VISUALIZER_THRESHOLD = 2    // segments (width > 2 to show)

// Resize handle
let RESIZE_HANDLE_SIZE = 20     // 20×20 pixels
```

---

## Formulas (Essential)

```swift
// Segment to pixels
pixelWidth = BASE_WIDTH + (widthSegments * SEGMENT_WIDTH)
pixelHeight = BASE_HEIGHT + (heightSegments * SEGMENT_HEIGHT)

// Pixels to segments (quantization)
widthSegments = max(0, round(pixelWidth / SEGMENT_WIDTH))
heightSegments = max(0, round(pixelHeight / SEGMENT_HEIGHT))

// Visible tracks
contentHeight = BASE_CONTENT_HEIGHT + (heightSegments * SEGMENT_HEIGHT)
visibleTracks = floor(contentHeight / TRACK_HEIGHT)

// Center section width
centerWidth = totalWidth - (BASE_WIDTH)  // Can be 0
tileCount = centerWidth / SEGMENT_WIDTH  // 25px tiles

// Flags
showSpacers = widthSegments % 2 == 0     // Even widths
showVisualizer = widthSegments > 2       // Width > 325px
```

---

## Sprite Quick Lookup

### PLEDIT.bmp Coordinates

| Sprite Name | X | Y | Width | Height | Use |
|-------------|---|---|-------|--------|-----|
| **BOTTOM SECTIONS** |||||
| PLAYLIST_BOTTOM_LEFT_CORNER | 0 | 72 | 125 | 38 | Left section (menus) |
| PLAYLIST_BOTTOM_TILE | 179 | 0 | 25 | 38 | Center repeating tile |
| PLAYLIST_BOTTOM_RIGHT_CORNER | 126 | 72 | 150 | 38 | Right section (actions) |
| **TOP SECTIONS (Unselected)** |||||
| PLAYLIST_TOP_LEFT_CORNER | 0 | 21 | 25 | 20 | Left corner |
| PLAYLIST_TITLE_BAR | 26 | 21 | 100 | 20 | Title text area |
| PLAYLIST_TOP_RIGHT_CORNER | 153 | 21 | 25 | 20 | Right corner |
| PLAYLIST_TOP_TILE | 127 | 21 | 25 | 20 | Repeating fill |
| **TOP SECTIONS (Selected)** |||||
| PLAYLIST_TOP_LEFT_SELECTED | 0 | 0 | 25 | 20 | Left corner (focused) |
| PLAYLIST_TITLE_BAR_SELECTED | 26 | 0 | 100 | 20 | Title (focused) |
| PLAYLIST_TOP_RIGHT_CORNER_SELECTED | 153 | 0 | 25 | 20 | Right corner (focused) |
| PLAYLIST_TOP_TILE_SELECTED | 127 | 0 | 25 | 20 | Fill (focused) |
| **SIDE TILES** |||||
| PLAYLIST_LEFT_TILE | 0 | 42 | 12 | 29 | Left edge (vertical repeat) |
| PLAYLIST_RIGHT_TILE | 31 | 42 | 20 | 29 | Right edge (vertical repeat) |
| **OTHER** |||||
| PLAYLIST_VISUALIZER_BACKGROUND | 205 | 0 | 75 | 38 | Visualizer area |

---

## Size Examples

| Segments | Pixels | Visible Tracks | Center Width | Spacers | Visualizer |
|----------|--------|----------------|--------------|---------|------------|
| [0, 0] | 275×116 | 4 | 0px | YES | NO |
| [1, 0] | 300×116 | 4 | 25px (1 tile) | NO | NO |
| [2, 0] | 325×116 | 4 | 50px (2 tiles) | YES | NO |
| [3, 0] | 350×116 | 4 | 75px (3 tiles) | NO | YES ✓ |
| [0, 1] | 275×145 | 6 | 0px | YES | NO |
| [0, 2] | 275×174 | 8 | 0px | YES | NO |
| [2, 2] | 325×174 | 8 | 50px (2 tiles) | YES | NO |
| [4, 4] | 375×232 | 13 | 100px (4 tiles) | YES | YES ✓ |

---

## Layout Breakpoints

### Bottom Bar Sections
```
At [0,0] (275px):
├─ LEFT: 125px
├─ CENTER: 0px (collapsed)
└─ RIGHT: 150px

At [1,0] (300px):
├─ LEFT: 125px
├─ CENTER: 25px (1 tile)
└─ RIGHT: 150px

At [2,0] (325px):
├─ LEFT: 125px
├─ CENTER: 50px (2 tiles)
└─ RIGHT: 150px
    └─ VISUALIZER: NOT YET (need width > 2)

At [3,0] (350px):
├─ LEFT: 125px
├─ CENTER: 75px (3 tiles)
└─ RIGHT: 150px
    └─ VISUALIZER: VISIBLE ✓
```

---

## SwiftUI Snippets

### Size Model
```swift
struct Size2D: Equatable {
    var width: Int   // segments
    var height: Int  // segments

    func toPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }

    func visibleTracks() -> Int {
        Int(floor(Double(58 + height * 29) / 13))
    }

    var showSpacers: Bool { width % 2 == 0 }
    var showVisualizer: Bool { width > 2 }
}
```

### Resize Gesture
```swift
DragGesture()
    .onChanged { value in
        let deltaW = Int(round(value.translation.width / 25))
        let deltaH = Int(round(value.translation.height / 29))
        size = Size2D(
            width: max(0, startSize.width + deltaW),
            height: max(0, startSize.height + deltaH)
        )
    }
```

### Bottom Bar Layout
```swift
HStack(spacing: 0) {
    // Left (125px)
    BottomLeftCorner().frame(width: 125, height: 38)

    // Center (dynamic)
    if centerWidth > 0 {
        BottomCenterTiles().frame(width: centerWidth, height: 38)
    }

    // Right (150px)
    BottomRightCorner().frame(width: 150, height: 38)
}
```

---

## Common Pitfalls

1. **DON'T store size in pixels** → Use segments
2. **DON'T use continuous drag** → Quantize to segments
3. **DON'T conditionally render center section** → Always present, width can be 0
4. **DON'T check `width >= 2` for visualizer** → Use `width > 2` (strict)
5. **DON'T forget spacer parity** → Even widths only

---

## Testing Checklist

- [ ] [0,0] → 275×116, 4 tracks, 0px center, spacers YES, viz NO
- [ ] [1,0] → 300×116, 4 tracks, 25px center, spacers NO, viz NO
- [ ] [2,0] → 325×116, 4 tracks, 50px center, spacers YES, viz NO
- [ ] [3,0] → 350×116, 4 tracks, 75px center, spacers NO, viz YES
- [ ] [0,1] → 275×145, 6 tracks
- [ ] [0,2] → 275×174, 8 tracks
- [ ] [2,2] → 325×174, 8 tracks, spacers YES, viz NO
- [ ] [4,4] → 375×232, 13 tracks, spacers YES, viz YES
- [ ] Drag resize quantizes to 25×29 increments
- [ ] Spacers toggle correctly on width changes
- [ ] Visualizer appears at width > 2
- [ ] Center tiles align perfectly
- [ ] No gaps in layout at any size

---

**Print this page for quick reference during implementation!**
