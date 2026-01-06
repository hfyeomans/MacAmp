# MILKDROP Window Resize - Research

## Overview

This task implements resizable window support for the MILKDROP HD window, following the same quantized segment-based resize pattern used by VIDEO and Playlist windows.

## Current Implementation Analysis

### MilkdropWindowChromeView.swift

Current state: **Fixed size at 275×232 pixels**

```swift
private enum MilkdropWindowLayout {
    static let windowSize = CGSize(width: 275, height: 232)  // FIXED - needs dynamic
    static let titlebarHeight: CGFloat = 20
    static let bottomBarHeight: CGFloat = 14
    static let leftBorderWidth: CGFloat = 11
    static let rightBorderWidth: CGFloat = 8
}
```

Key characteristics:
- Uses **GEN.bmp** sprites (different from VIDEO.bmp)
- 6-section titlebar: LEFT (25px) + FILLER + TITLE (100px) + FILLER + WINDOWSHADE + RIGHT (25px)
- Two-piece bottom fill sprites: TOP (13px) + BOTTOM (1px)
- Left border: 11px, Right border: 8px
- Bottom bar: 14px height (much smaller than VIDEO's 38px)
- Content area hosts WKWebView for Butterchurn visualization

### GEN.bmp Sprite Layout

From SpriteID.swift:
```swift
// Titlebar (6 sections)
case genTitlebarLeftActive, genTitlebarLeftInactive      // 25×20
case genTitlebarFillerActive, genTitlebarFillerInactive  // 25×20 (tiles)
case genTitlebarTitleActive, genTitlebarTitleInactive    // 100×20
case genTitlebarWsNormal, genTitlebarWsPressed           // 9×9
case genTitlebarRightActive, genTitlebarRightInactive    // 25×20

// Borders (left and right vertical strips)
case genLeftBorderActive, genLeftBorderInactive          // 11×29 (tiles vertically)
case genRightBorderActive, genRightBorderInactive        // 8×29 (tiles vertically)

// Bottom bar (three sections)
case genBottomLeftActive, genBottomLeftInactive          // 125×14
case genBottomFillTopActive, genBottomFillTopInactive    // 25×13 (tiles - TOP piece)
case genBottomFillBottomActive, genBottomFillBottomInactive  // 25×1 (tiles - BOTTOM piece)
case genBottomRightActive, genBottomRightInactive        // 125×14

// Close button
case genCloseNormal, genClosePressed                     // 9×9

// Corner for resize
case genCorner                                           // 20×14 (resize handle area)
```

### Two-Piece Sprite Pattern

MILKDROP uses a unique two-piece pattern for bottom fill:
- **TOP piece**: 25×13px (tiles horizontally)
- **BOTTOM piece**: 25×1px (tiles horizontally, sits below TOP)

This differs from VIDEO which uses single-piece fills.

---

## Reference Implementations

### Size2D Model (Size2D.swift)

The quantized segment model for all resizable windows:

```swift
struct Size2D: Equatable, Codable, Hashable {
    var width: Int   // Number of 25px segments beyond base width (275px)
    var height: Int  // Number of 29px segments beyond base height (116px)

    // Minimum = Size2D(0, 0) = 275×116 pixels
    // Default = Size2D(0, 4) = 275×232 pixels (matches current fixed size)

    static let videoMinimum = Size2D(width: 0, height: 0)
    static let videoDefault = Size2D(width: 0, height: 4)

    func toVideoPixels() -> CGSize {
        CGSize(width: 275 + width * 25, height: 116 + height * 29)
    }
}
```

**Key insight**: MILKDROP can reuse the same `toVideoPixels()` method since it shares the same base dimensions and segment sizes.

### VideoWindowSizeState Pattern (VideoWindowSizeState.swift)

The Observable state class pattern to replicate:

```swift
@MainActor
@Observable
final class VideoWindowSizeState {
    var size: Size2D = .videoDefault {
        didSet { saveSize() }
    }

    // Computed properties for layout
    var pixelSize: CGSize { size.toVideoPixels() }
    var centerWidth: CGFloat { pixelSize.width - 250 }  // 125+125 fixed sides
    var centerTileCount: Int { Int(centerWidth / 25) }
    var contentHeight: CGFloat { pixelSize.height - 58 }  // titlebar + bottom
    var verticalBorderTileCount: Int { Int(ceil(contentHeight / 29)) }

    // Persistence
    private func saveSize() {
        UserDefaults.standard.set(size.width, forKey: "videoWindowWidth")
        UserDefaults.standard.set(size.height, forKey: "videoWindowHeight")
    }

    func loadSize() {
        let w = UserDefaults.standard.integer(forKey: "videoWindowWidth")
        let h = UserDefaults.standard.integer(forKey: "videoWindowHeight")
        if w >= 0 && h >= 0 {
            size = Size2D(width: w, height: h)
        }
    }
}
```

### Three-Section Bottom Bar Layout

Pattern from Playlist/Video windows:
- **LEFT section**: Fixed width (125px for VIDEO/MILKDROP)
- **CENTER section**: Dynamic tiles (25px each)
- **RIGHT section**: Fixed width (125px for VIDEO/MILKDROP)

For MILKDROP:
```
LEFT (125px) + CENTER (tiles × 25px) + RIGHT (125px) = window width
At minimum width 275px: 125 + 25 + 125 = 275 (1 center tile)
```

### Resize Handle Implementation (VideoWindowChromeView.swift)

The DragGesture pattern with AppKit preview:

```swift
@ViewBuilder
private func buildResizeHandle() -> some View {
    Rectangle().fill(Color.clear).frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartSize == nil {
                        dragStartSize = sizeState.size
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))
                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Show AppKit preview overlay
                    coordinator.showVideoResizePreview(resizePreview, previewSize: candidate.toVideoPixels())
                }
                .onEnded { _ in
                    sizeState.size = finalSize
                    coordinator.updateVideoWindowSize(to: sizeState.pixelSize)
                    coordinator.hideVideoResizePreview(resizePreview)
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                    dragStartSize = nil
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

### WindowCoordinator Integration

VIDEO resize uses WindowCoordinator for NSWindow frame sync:
```swift
func updateVideoWindowSize(to size: CGSize) {
    guard let window = videoWindow else { return }
    var frame = window.frame
    let heightDelta = size.height - frame.height
    frame.size = size
    frame.origin.y -= heightDelta  // Keep top-left anchor
    window.setFrame(frame, display: true)
}
```

MILKDROP will need similar methods:
- `updateMilkdropWindowSize(to:)`
- `showMilkdropResizePreview(_:previewSize:)`
- `hideMilkdropResizePreview(_:)`

---

## Butterchurn Integration Considerations

### WKWebView Canvas Resize

From bridge.js, the setSize function handles canvas resize:
```javascript
setSize: function(width, height) {
    if (!visualizer) return;
    canvas.width = width;
    canvas.height = height;
    visualizer.setRendererSize(width, height);
}
```

Called from Swift via ButterchurnBridge:
```swift
func setSize(width: CGFloat, height: CGFloat) {
    guard isReady, let webView = webView else { return }
    let js = "window.macampButterchurn?.setSize(\(Int(width)), \(Int(height)));"
    webView.evaluateJavaScript(js, completionHandler: nil)
}
```

### Content Size Calculation

MILKDROP content area (where WKWebView lives):
```
contentWidth = windowWidth - leftBorder(11) - rightBorder(8) = windowWidth - 19
contentHeight = windowHeight - titlebar(20) - bottomBar(14) = windowHeight - 34

At minimum (275×116): content = 256×82
At default (275×232): content = 256×198
```

---

## Key Differences from VIDEO Window

| Aspect | VIDEO | MILKDROP |
|--------|-------|----------|
| Sprite source | VIDEO.bmp | GEN.bmp |
| Bottom bar height | 38px | 14px |
| Left border | 11px | 11px |
| Right border | 8px | 8px |
| Titlebar height | 20px | 20px |
| Bottom fill sprite | Single piece | Two pieces (13px + 1px) |
| Content | AVPlayerLayer | WKWebView (Butterchurn) |
| Resize notification | None | Must call setSize() on Butterchurn |

---

## Size Calculations Summary

### MILKDROP Window Dimensions

```
Base dimensions: 275×116 (at Size2D[0,0])
Default dimensions: 275×232 (at Size2D[0,4])

Window width = 275 + (size.width × 25)
Window height = 116 + (size.height × 29)

Content width = window width - 19 (11 left + 8 right borders)
Content height = window height - 34 (20 titlebar + 14 bottom bar)

Center tile count = (window width - 250) / 25
Vertical border tile count = ceil(content height / 29)
```

### Minimum Size Rationale

275×116 matches:
- Main window height (116px)
- EQ window (275×116)
- Playlist minimum (275×116)
- Video minimum (275×116)

This ensures visual consistency across all MacAmp windows at minimum size.

---

## Files to Modify

1. **Size2D.swift** - Add MILKDROP presets (or reuse VIDEO presets)
2. **MilkdropWindowSizeState.swift** - NEW: Observable state class
3. **MilkdropWindowChromeView.swift** - Dynamic layout + resize handle
4. **WindowCoordinator.swift** - Add MILKDROP resize methods
5. **ButterchurnBridge.swift** - Add setSize() wrapper (may already exist)
6. **MilkdropWindowManager.swift** - Initialize with size state

---

## References

- tasks/playlist-resize/research.md - Playlist resize patterns
- tasks/playlist-resize/plan.md - Implementation phases
- tasks/video-window-focus/research.md - WindowFocusState patterns
- docs/MILKDROP_WINDOW.md - Current MILKDROP documentation
- docs/VIDEO_WINDOW.md - Video window architecture
