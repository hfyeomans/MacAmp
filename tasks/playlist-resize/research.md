# Playlist Window Resize - Consolidated Research

**Task:** Playlist Window Resize + Scroll
**Status:** Research Complete → Plan Grade A Validated
**Estimated:** 8-12 hours implementation
**Reference:** Video window resize implementation (proven pattern)
**Oracle Grade:** A (architectural alignment confirmed)

---

## Executive Summary

The playlist window needs two major enhancements:
1. **Resize functionality**: 3-section bottom bar layout (LEFT + CENTER + RIGHT) where CENTER expands
2. **Scroll slider**: Add the gold thumb scroll button for playlist navigation

The VIDEO window resize implementation is the proven reference pattern to follow (Size2D model, 25x29px quantized segments, AppKit preview overlay).

---

## 1. Resize Constants (Matching Video Window)

### Segment Dimensions
```swift
SEGMENT_WIDTH = 25   // pixels per width increment
SEGMENT_HEIGHT = 29  // pixels per height increment
```

### Base Dimensions
```swift
BASE_WIDTH = 275     // minimum playlist width
BASE_HEIGHT = 116    // minimum playlist height (Main/EQ height)
```

### Size Calculation
```swift
pixelWidth = BASE_WIDTH + (widthSegments * SEGMENT_WIDTH)
pixelHeight = BASE_HEIGHT + (heightSegments * SEGMENT_HEIGHT)

// At [0,0]: 275×116
// At [1,0]: 300×116
// At [2,2]: 325×174
// At [4,4]: 375×232 (current fixed size ≈ this)
```

### Track Count Formula
```swift
BASE_CONTENT_HEIGHT = 58  // base playlist content area
TRACK_HEIGHT = 13         // pixels per track row

visibleTracks = floor((BASE_CONTENT_HEIGHT + heightSegments * SEGMENT_HEIGHT) / TRACK_HEIGHT)
// At [0,0]: floor(58/13) = 4 tracks
// At [0,4]: floor((58 + 116)/13) = 13 tracks
```

---

## 2. Three-Section Bottom Bar Layout

### Critical Finding: Current MacAmp is MISSING the CENTER section

**Current MacAmp (BROKEN):**
```swift
HStack(spacing: 0) {
    LEFT  (125px)  // PLAYLIST_BOTTOM_LEFT_CORNER
    RIGHT (154px)  // PLAYLIST_BOTTOM_RIGHT_CORNER  ← WRONG width
}
// Total: 279px (not 275px!)
// No center section = cannot resize
```

**Correct Webamp Layout:**
```
Total Width: W pixels
┌──────────────┬──────────────────────┬───────────────┐
│   LEFT       │      CENTER          │     RIGHT     │
│   125px      │   (W - 275)px        │    150px      │
│   FIXED      │   DYNAMIC TILES      │    FIXED      │
│              │                      │               │
│  [4 Menus]   │  PLAYLIST_BOTTOM_TILE│ [Transport]   │
│              │  (25×38) repeating   │ [Scroll btns] │
│              │                      │ [Resize]      │
└──────────────┴──────────────────────┴───────────────┘
                38px total height
```

### Section Breakdown

| Section | Width | Sprite | Contents |
|---------|-------|--------|----------|
| LEFT | 125px fixed | PLAYLIST_BOTTOM_LEFT_CORNER (125×38) | Add/Rem/Sel/Misc menu buttons |
| CENTER | W-275px dynamic | PLAYLIST_BOTTOM_TILE (25×38) tiles | Empty, tiles horizontally |
| RIGHT | 150px fixed | PLAYLIST_BOTTOM_RIGHT_CORNER (150×38) | Visualizer, transport, scroll, resize |

### Center Section Behavior

- **At minimum (275px):** Center width = 0px (collapsed, invisible)
- **At +1 segment (300px):** Center width = 25px (1 tile visible)
- **At +2 segments (325px):** Center width = 50px (2 tiles visible)
- **Formula:** `centerWidth = totalWidth - 275`
- **Tile count:** `centerTileCount = centerWidth / 25`

---

## 3. Video Window Resize Pattern (Reference Implementation)

The video window has a working resize implementation to copy from.

### Size2D Model (MacAmpApp/Models/Size2D.swift)
```swift
struct Size2D: Equatable, Codable, Hashable {
    var width: Int   // segments, not pixels
    var height: Int  // segments, not pixels

    static let zero = Size2D(width: 0, height: 0)

    // Playlist-specific presets (to add)
    static let playlistMinimum = Size2D(width: 0, height: 0)  // 275×116
    static let playlistDefault = Size2D(width: 0, height: 4)  // 275×232 (current fixed)

    func toPlaylistPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }
}
```

### VideoWindowSizeState Pattern (to replicate for Playlist)
```swift
@MainActor
@Observable
final class VideoWindowSizeState {
    var size: Size2D = .videoDefault {
        didSet { saveSize() }  // Persist to UserDefaults
    }

    var pixelSize: CGSize { size.toVideoPixels() }
    var centerWidth: CGFloat { max(0, pixelSize.width - 250) }
    var centerTileCount: Int { Int(centerWidth / 25) }
    var contentSize: CGSize { /* minus borders */ }
}
```

### Resize Handle Implementation (VideoWindowChromeView.swift:285-350)
```swift
@ViewBuilder
private func buildResizeHandle() -> some View {
    Rectangle()
        .fill(Color.clear)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Capture start size on first tick
                    if dragStartSize == nil {
                        dragStartSize = sizeState.size
                        isDragging = true
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    guard let baseSize = dragStartSize else { return }

                    // Quantize to segments
                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Show AppKit preview overlay
                    coordinator.showResizePreview(previewSize: candidate.toPixels())
                }
                .onEnded { value in
                    // Commit final size
                    sizeState.size = finalSize
                    coordinator.updateWindowSize(to: sizeState.pixelSize)
                    coordinator.hideResizePreview()

                    // Cleanup
                    dragStartSize = nil
                    isDragging = false
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

### Key Pitfalls (Lessons from Video Window)

1. **AppKit Preview Overlay Required**
   - SwiftUI clips content during drag resize
   - Use WindowResizePreviewOverlay (AppKit NSPanel) to show dashed preview rect
   - Preview can extend beyond current window bounds

2. **WindowSnapManager Coordination**
   - Call `beginProgrammaticAdjustment()` before resize starts
   - Call `endProgrammaticAdjustment()` after resize ends
   - Prevents magnetic snapping during resize drag

3. **NSWindow Frame Sync**
   - SwiftUI size state is independent of NSWindow frame
   - Must call `coordinator.updateWindowSize(to:)` on drag end
   - Coordinator bridges SwiftUI state to AppKit window frame

4. **Quantization Timing**
   - Quantize on every onChanged (show snapped preview)
   - Only commit state on onEnded (prevents jitter)

---

## 4. Scroll Bar Implementation

### Sprite Details (PLEDIT.bmp)
```swift
// Gold scroll thumb (tiny button)
PLAYLIST_SCROLL_HANDLE: { x: 52, y: 53, width: 8, height: 18 }
PLAYLIST_SCROLL_HANDLE_SELECTED: { x: 61, y: 53, width: 8, height: 18 }

// Scroll track is part of PLAYLIST_RIGHT_TILE
PLAYLIST_RIGHT_TILE: { x: 31, y: 42, width: 20, height: 29 }
```

### Webamp ScrollBar Component
```tsx
const HANDLE_HEIGHT = 18;

function PlaylistScrollBar() {
    const playlistHeight = getWindowPixelSize(WINDOWS.PLAYLIST).height;

    return (
        <VerticalSlider
            height={playlistHeight - 58}  // Dynamic based on window
            handleHeight={HANDLE_HEIGHT}   // 18px gold thumb
            width={8}                      // Slider track width
            value={scrollPosition / 100}
            onChange={(val) => setScrollPosition(val * 100)}
        />
    );
}
```

### ScrollBar Positioning
- **Track:** Inside PLAYLIST_RIGHT_TILE (right border)
- **Thumb:** 8×18px gold button
- **Margin:** 5px from right edge
- **Height:** `windowHeight - 58` (content area - bottom bar)

### Current MacAmp Status
```swift
// Currently shows static scroll handle (NOT functional)
SimpleSpriteImage("PLAYLIST_SCROLL_HANDLE", width: 8, height: 18)
    .position(x: 260, y: 30)  // Fixed position, doesn't scroll!
```

**Needed:** Implement draggable vertical slider that:
- Moves thumb position based on playlist scroll offset
- Updates playlist view scroll position on drag
- Scales thumb position based on total tracks vs visible tracks

---

## 5. PLEDIT.bmp Sprite Atlas

### Key Sprites for Resize
```swift
// Top bar (y=0-40)
PLAYLIST_TOP_LEFT_SELECTED: { x: 0, y: 0, w: 25, h: 20 }
PLAYLIST_TITLE_BAR_SELECTED: { x: 26, y: 0, w: 100, h: 20 }
PLAYLIST_TOP_TILE_SELECTED: { x: 127, y: 0, w: 25, h: 20 }
PLAYLIST_TOP_RIGHT_CORNER_SELECTED: { x: 153, y: 0, w: 25, h: 20 }

PLAYLIST_TOP_LEFT_CORNER: { x: 0, y: 21, w: 25, h: 20 }
PLAYLIST_TITLE_BAR: { x: 26, y: 21, w: 100, h: 20 }
PLAYLIST_TOP_TILE: { x: 127, y: 21, w: 25, h: 20 }
PLAYLIST_TOP_RIGHT_CORNER: { x: 153, y: 21, w: 25, h: 20 }

// Side borders (y=42-71)
PLAYLIST_LEFT_TILE: { x: 0, y: 42, w: 12, h: 29 }
PLAYLIST_RIGHT_TILE: { x: 31, y: 42, w: 20, h: 29 }  // Contains scroll track

// Scroll thumb (y=53)
PLAYLIST_SCROLL_HANDLE: { x: 52, y: 53, w: 8, h: 18 }
PLAYLIST_SCROLL_HANDLE_SELECTED: { x: 61, y: 53, w: 8, h: 18 }

// Bottom bar (y=72-110)
PLAYLIST_BOTTOM_LEFT_CORNER: { x: 0, y: 72, w: 125, h: 38 }
PLAYLIST_BOTTOM_RIGHT_CORNER: { x: 126, y: 72, w: 150, h: 38 }  // NOTE: 150px not 154px!
PLAYLIST_BOTTOM_TILE: { x: 179, y: 0, w: 25, h: 38 }  // Center tiling
```

### Sprite Width Discrepancy (BUG in current MacAmp)
```swift
// CURRENT (WRONG):
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 154, height: 38)

// CORRECT (per Webamp):
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 150, height: 38)
```

The 4px difference (154 vs 150) is why the current layout is off!

---

## 6. Window Layout Diagrams

### Minimum Size: [0,0] = 275×116
```
┌─────────────────────────────────────────────┐ 20px
│  TOP BAR (275px)                            │
├─────────────────────────────────────────────┤
│L│                                          │R│
│12│     Content (243×58)                    │20│ 58px
│ │         4 tracks                         │ │
├─┴──────────────────────────────────────────┴─┤
│ ┌─────────────┬─────────────────────────────┐│
│ │ LEFT 125px  │ RIGHT 150px                ││ 38px
│ └─────────────┴─────────────────────────────┘│
└─────────────────────────────────────────────┘
  275px total
  CENTER width = 0px (collapsed)
```

### Expanded: [2,4] = 325×232
```
┌──────────────────────────────────────────────────┐ 20px
│  TOP BAR (325px, spacers visible)                │
├──────────────────────────────────────────────────┤
│L│                                               │R│
│12│     Content (293×174)                        │20│ 174px
│ │         13 tracks                             │ │
│ │                                               │ │
│ │                                               │ │
├─┴───────────────────────────────────────────────┴─┤
│ ┌─────────────┬──────┬──────┬────────────────────┐│
│ │ LEFT 125px  │TILE  │TILE  │ RIGHT 150px        ││ 38px
│ └─────────────┴──────┴──────┴────────────────────┘│
└──────────────────────────────────────────────────┘
  325px total
  CENTER width = 50px (2 tiles)
```

---

## 7. Spacer Visibility (Top Bar)

### Webamp Logic
```typescript
const showSpacers = playlistSize[0] % 2 === 0;
```

- **Even widths (0, 2, 4):** Show spacers (12px left + 13px right = 25px)
- **Odd widths (1, 3, 5):** Hide spacers

This maintains visual alignment across different sizes.

---

## 8. Files to Modify

### Files to Create (NEW)
1. **MacAmpApp/Models/PlaylistWindowSizeState.swift** - Observable size state (copy VideoWindowSizeState pattern)
2. **MacAmpApp/Views/Components/PlaylistScrollSlider.swift** - Scroll slider component with bridge contract

### Files to Modify
3. **MacAmpApp/Models/Size2D.swift** - Add playlist presets (minimal, toPlaylistPixels exists)
4. **MacAmpApp/Models/SkinSprites.swift** - Fix PLAYLIST_BOTTOM_RIGHT_CORNER width (154→150)
5. **MacAmpApp/Views/WinampPlaylistWindow.swift** - Major refactor: 3-section layout, resize gesture, scroll slider
6. **MacAmpApp/ViewModels/WindowCoordinator.swift** - Add playlist resize coordinator methods with double-size scaling

---

## 9. Open Questions Resolved

| Question | Answer |
|----------|--------|
| Is resize continuous or quantized? | **Quantized** (25×29px segments) |
| Where is resize handle? | **20×20px** bottom-right corner |
| Min/max size constraints? | **Min [0,0]**, no explicit max |
| When does center appear? | **Always exists**, width can be 0 at minimum |
| Scroll bar position? | **Inside PLAYLIST_RIGHT_TILE**, 5px margin |
| Bottom right width? | **150px** (not 154px as currently defined) |

---

## 10. Reference Files Analyzed

### Webamp Source
- `webamp_clone/packages/webamp/js/components/PlaylistWindow/index.tsx`
- `webamp_clone/packages/webamp/js/components/PlaylistWindow/PlaylistScrollBar.tsx`
- `webamp_clone/packages/webamp/js/components/VerticalSlider.tsx`
- `webamp_clone/packages/webamp/css/playlist-window.css`
- `webamp_clone/packages/webamp/js/skinSprites.ts`
- `webamp_clone/packages/webamp/js/constants.ts`

### MacAmp Source
- `MacAmpApp/Models/Size2D.swift`
- `MacAmpApp/Models/VideoWindowSizeState.swift`
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
- `MacAmpApp/Views/WinampPlaylistWindow.swift`
- `MacAmpApp/Models/SkinSprites.swift`

### Documentation
- `docs/VIDEO_WINDOW.md` (Section: Window Resizing)
- `tasks/playlist-resize-analysis/research.md` (previous analysis)
- `tasks/playlist-window-resize/research.md` (previous analysis)

---

**Research Complete.** Ready for implementation planning.
