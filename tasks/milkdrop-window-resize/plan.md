# MILKDROP Window Resize - Implementation Plan

## Overview

Implement resizable window support for MILKDROP HD window using the **exact same pattern** as VIDEO and Playlist windows:
- Size2D segment model (25×29 px quantization)
- MilkdropWindowSizeState (copy of VideoWindowSizeState)
- Dynamic sprite tiling for titlebar, borders, and bottom bar
- DragGesture resize handle with AppKit preview overlay
- Butterchurn canvas resize notification

## Reference Implementations

Following these existing patterns exactly:
- `MacAmpApp/Models/Size2D.swift` - Segment model
- `MacAmpApp/Models/VideoWindowSizeState.swift` - Observable state
- `MacAmpApp/Views/Windows/VideoWindowChromeView.swift` - Dynamic chrome + resize gesture
- `MacAmpApp/Views/WinampVideoWindow.swift` - Size state wiring + initial sync

---

## Phase 1: Foundation (MilkdropWindowSizeState)

### 1.1 Add MILKDROP Presets to Size2D.swift

```swift
// MARK: - MILKDROP Window Presets

/// MILKDROP window minimum size: 275×116 (matches Main/EQ/Video/Playlist)
static let milkdropMinimum = Size2D(width: 0, height: 0)  // 275×116

/// MILKDROP window default size: 275×232 (current standard)
static let milkdropDefault = Size2D(width: 0, height: 4)  // 275×232

/// Convert segments to pixel dimensions for MILKDROP window
/// Same formula as VIDEO - base 275×116, segments 25×29
func toMilkdropPixels() -> CGSize {
    CGSize(
        width: 275 + width * 25,
        height: 116 + height * 29
    )
}
```

### 1.2 Create MilkdropWindowSizeState.swift

Copy `VideoWindowSizeState.swift` pattern with MILKDROP-specific values:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class MilkdropWindowSizeState {
    var size: Size2D = .milkdropDefault {
        didSet { saveSize() }
    }

    // MARK: - Computed Properties

    var pixelSize: CGSize { size.toMilkdropPixels() }

    /// Width available for center tiles: window - LEFT(125) - RIGHT(125)
    var centerWidth: CGFloat { max(0, pixelSize.width - 250) }

    /// Number of 25px center tiles in bottom bar
    var centerTileCount: Int { Int(centerWidth / 25) }

    /// Content height: window - titlebar(20) - bottomBar(14)
    var contentHeight: CGFloat { pixelSize.height - 34 }

    /// Content width: window - leftBorder(11) - rightBorder(8)
    var contentWidth: CGFloat { pixelSize.width - 19 }

    /// Number of 29px vertical border tiles
    var verticalBorderTileCount: Int { Int(ceil(contentHeight / 29)) }

    /// Content size for WKWebView/Butterchurn
    var contentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    // MARK: - MILKDROP Titlebar Layout
    // Structure: LEFT_CAP(25) + LEFT_GOLD(n×25) + LEFT_END(25) + CENTER(m×25) + RIGHT_END(25) + RIGHT_GOLD(n×25) + RIGHT_CAP(25)
    // Fixed: LEFT_CAP + LEFT_END + RIGHT_END + RIGHT_CAP = 100px
    // Variable: LEFT_GOLD + CENTER + RIGHT_GOLD = window width - 100

    /// Gold filler tiles per side (symmetric)
    /// At 275px: (275 - 100 - 75) / 2 / 25 = 2 tiles per side (matches current)
    var goldFillerTilesPerSide: Int {
        // Total variable space minus 3 center grey tiles (75px)
        let goldSpace = pixelSize.width - 100 - 75  // Fixed caps/ends + center grey
        let perSide = goldSpace / 2
        return max(0, Int(perSide / 25))
    }

    /// Center grey tiles (fixed at 3 - expand gold fillers instead)
    var centerGreyTileCount: Int { 3 }

    /// X position for center section start (after left gold + left end)
    var centerSectionStartX: CGFloat {
        25 + CGFloat(goldFillerTilesPerSide) * 25 + 25  // LEFT_CAP + LEFT_GOLD + LEFT_END
    }

    /// X position for MILKDROP HD letters (centered in center section)
    var milkdropLettersCenterX: CGFloat {
        centerSectionStartX + 37.5  // Center of 75px center section
    }

    // MARK: - Persistence

    private static let sizeKey = "milkdropWindowSize"

    private func saveSize() {
        let data = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(data, forKey: Self.sizeKey)
    }

    func loadSize() {
        guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
              let width = data["width"] as? Int,
              let height = data["height"] as? Int else {
            size = .milkdropDefault
            return
        }
        size = Size2D(width: width, height: height).clamped(min: .milkdropMinimum)
    }

    // MARK: - Convenience Methods (parity with VIDEO)

    func resetToDefault() {
        size = .milkdropDefault
    }

    func setToMinimum() {
        size = .milkdropMinimum
    }

    init() { loadSize() }
}
```

---

## Phase 2: Size State Wiring (WinampMilkdropWindow)

**CRITICAL**: Wire up sizeState in WinampMilkdropWindow (same pattern as WinampVideoWindow)

### 2.1 Add State Property

```swift
struct WinampMilkdropWindow: View {
    // ... existing @Environment properties ...

    // MILKDROP window size state (segment-based resizing)
    @State private var sizeState = MilkdropWindowSizeState()

    // ... rest of view ...
}
```

### 2.2 Pass to Chrome View

```swift
var body: some View {
    MilkdropWindowChromeView(sizeState: sizeState) {
        // ... existing content ...
    }
    .frame(
        width: sizeState.pixelSize.width,
        height: sizeState.pixelSize.height,
        alignment: .topLeading
    )
    .fixedSize()
    .background(Color.black)
    .onAppear {
        // Configure bridge with audioPlayer for audio visualization
        bridge.configure(audioPlayer: audioPlayer)

        // Initial NSWindow frame sync with integral coordinates
        if let coordinator = WindowCoordinator.shared {
            let clampedSize = CGSize(
                width: round(sizeState.pixelSize.width),
                height: round(sizeState.pixelSize.height)
            )
            coordinator.updateMilkdropWindowSize(to: clampedSize)
        }
    }
}
```

---

## Phase 3: Dynamic Chrome Layout (MilkdropWindowChromeView)

### 3.1 Update View Signature

```swift
struct MilkdropWindowChromeView<Content: View>: View {
    @ViewBuilder let content: Content
    let sizeState: MilkdropWindowSizeState  // ADD parameter

    // Access bridge from environment for resize notification
    @Environment(ButterchurnBridge.self) private var bridge

    // ... existing @Environment properties ...

    private var pixelSize: CGSize { sizeState.pixelSize }
    private var contentSize: CGSize { sizeState.contentSize }
}
```

### 3.2 Remove Fixed Layout Enum

```swift
// DELETE this entire enum
private enum MilkdropWindowLayout { ... }
```

### 3.3 Dynamic Titlebar

MILKDROP titlebar has 7 sections. Expansion strategy: **Expand gold fillers, keep center at 3 tiles**

```swift
@ViewBuilder
private func buildDynamicTitlebar() -> some View {
    let suffix = isWindowActive ? "_SELECTED" : ""
    let goldTiles = sizeState.goldFillerTilesPerSide
    let centerStart = sizeState.centerSectionStartX

    WinampTitlebarDragHandle(windowKind: .milkdrop, size: CGSize(width: pixelSize.width, height: 20)) {
        ZStack(alignment: .topLeading) {
            // Section 1: Left cap (25px)
            SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
                .position(x: 12.5, y: 10)

            // Section 2: Left gold bar tiles (dynamic)
            ForEach(0..<goldTiles, id: \.self) { i in
                SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                    .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
            }

            // Section 3: Left end (25px)
            SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: 20)
                .position(x: centerStart - 12.5, y: 10)

            // Section 4: Center grey tiles (fixed 3 tiles = 75px)
            ForEach(0..<3, id: \.self) { i in
                SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
                    .position(x: centerStart + 12.5 + CGFloat(i) * 25, y: 10)
            }

            // Section 5: Right end (25px)
            SimpleSpriteImage("GEN_TOP_RIGHT_END\(suffix)", width: 25, height: 20)
                .position(x: centerStart + 75 + 12.5, y: 10)

            // Section 6: Right gold bar tiles (symmetric with left)
            ForEach(0..<goldTiles, id: \.self) { i in
                SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                    .position(x: centerStart + 75 + 25 + 12.5 + CGFloat(i) * 25, y: 10)
            }

            // Section 7: Right cap (25px)
            SimpleSpriteImage("GEN_TOP_RIGHT\(suffix)", width: 25, height: 20)
                .position(x: pixelSize.width - 12.5, y: 10)

            // MILKDROP HD letters - centered in 75px center section
            milkdropLetters
                .position(x: sizeState.milkdropLettersCenterX, y: 8)
        }
    }
    .position(x: pixelSize.width / 2, y: 10)
}
```

### 3.4 Dynamic Vertical Borders

```swift
@ViewBuilder
private func buildDynamicBorders() -> some View {
    let tileCount = sizeState.verticalBorderTileCount

    ForEach(0..<tileCount, id: \.self) { i in
        // Left border (11px wide)
        SimpleSpriteImage("GEN_MIDDLE_LEFT", width: 11, height: 29)
            .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

        // Right border (8px wide)
        SimpleSpriteImage("GEN_MIDDLE_RIGHT", width: 8, height: 29)
            .position(x: pixelSize.width - 4, y: 20 + 14.5 + CGFloat(i) * 29)
    }
}
```

### 3.5 Dynamic Bottom Bar

```swift
@ViewBuilder
private func buildDynamicBottomBar() -> some View {
    let bottomBarY = pixelSize.height - 7  // 14px bar, center at 7

    // LEFT section (125px fixed)
    SimpleSpriteImage("GEN_BOTTOM_LEFT", width: 125, height: 14)
        .position(x: 62.5, y: bottomBarY)

    // CENTER section (dynamic tiles) - TWO-PIECE sprites (13px + 1px = 14px)
    let centerCount = sizeState.centerTileCount
    ForEach(0..<centerCount, id: \.self) { i in
        VStack(spacing: 0) {
            SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)
            SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)
        }
        .position(x: 125 + 12.5 + CGFloat(i) * 25, y: bottomBarY)
    }

    // RIGHT section (125px fixed) - contains resize corner
    SimpleSpriteImage("GEN_BOTTOM_RIGHT", width: 125, height: 14)
        .position(x: pixelSize.width - 62.5, y: bottomBarY)
}
```

### 3.6 Dynamic Content Area

```swift
// Content area
content
    .frame(width: contentSize.width, height: contentSize.height)
    .position(x: pixelSize.width / 2, y: 20 + contentSize.height / 2)
```

### 3.7 Outer Frame

```swift
.frame(width: pixelSize.width, height: pixelSize.height, alignment: .topLeading)
.fixedSize()
.background(Color.black)
```

---

## Phase 4: Resize Gesture

### 4.1 Add Drag State

```swift
@State private var dragStartSize: Size2D?
@State private var isDragging: Bool = false
@State private var resizePreview = WindowResizePreviewOverlay()
```

### 4.2 Resize Handle (copy from VIDEO, fix API)

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
                    if dragStartSize == nil {
                        dragStartSize = sizeState.size
                        isDragging = true
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    guard let baseSize = dragStartSize else { return }

                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // AppKit preview overlay - CORRECT API: show(in:previewSize:)
                    if let coordinator = WindowCoordinator.shared,
                       let window = coordinator.milkdropWindow {
                        resizePreview.show(in: window, previewSize: candidate.toMilkdropPixels())
                    }
                }
                .onEnded { value in
                    guard let baseSize = dragStartSize else { return }

                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let finalSize = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Commit size
                    sizeState.size = finalSize

                    // Sync NSWindow with top-left anchoring
                    if let coordinator = WindowCoordinator.shared {
                        coordinator.updateMilkdropWindowSize(to: sizeState.pixelSize)
                    }

                    // Hide preview
                    resizePreview.hide()

                    // Notify Butterchurn of canvas resize
                    bridge.setSize(width: contentSize.width, height: contentSize.height)

                    // Cleanup
                    isDragging = false
                    dragStartSize = nil
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

---

## Phase 5: WindowCoordinator Integration

Add to `WindowCoordinator.swift` (mirror VIDEO pattern with proper top-left anchoring):

```swift
// MARK: - MILKDROP Window Resize

func updateMilkdropWindowSize(to size: CGSize) {
    guard let window = milkdropWindow else { return }

    // Use integer coordinates to prevent blurry rendering
    let roundedSize = CGSize(
        width: round(size.width),
        height: round(size.height)
    )

    var frame = window.frame

    // Top-left anchoring: preserve top-left corner position
    let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height)
    frame.size = roundedSize
    frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - roundedSize.height)

    window.setFrame(frame, display: true)
}
```

---

## Phase 6: Butterchurn Canvas Sync

### 6.1 Add setSize to ButterchurnBridge (if missing)

Check if exists, add if not:

```swift
/// Resize the Butterchurn canvas
func setSize(width: CGFloat, height: CGFloat) {
    guard isReady, let webView = webView else { return }
    let js = "window.macampButterchurn?.setSize(\(Int(width)), \(Int(height)));"
    webView.evaluateJavaScript(js, completionHandler: nil)
}
```

### 6.2 Call on Resize End + Initial Sync

In resize gesture `.onEnded`:
```swift
bridge.setSize(width: contentSize.width, height: contentSize.height)
```

Also call in WinampMilkdropWindow `.onAppear` after initial NSWindow sync to ensure canvas matches restored size.

---

## Phase 7: Testing & Polish

### Checklist
- [ ] Build with Thread Sanitizer
- [ ] Test minimum size (275×116)
- [ ] Test default size (275×232)
- [ ] Test large sizes (500×400, 800×600)
- [ ] **Visual check: titlebar tiles correctly at wider widths**
- [ ] **Visual check: MILKDROP HD letters stay centered**
- [ ] Verify Butterchurn scales correctly at all sizes
- [ ] Test persistence (quit/relaunch)
- [ ] Test magnetic docking during resize
- [ ] Oracle code review

---

## File Changes Summary

| File | Change | Description |
|------|--------|-------------|
| `Size2D.swift` | MODIFY | Add milkdropMinimum, milkdropDefault, toMilkdropPixels() |
| `MilkdropWindowSizeState.swift` | CREATE | Observable state class with titlebar computed properties |
| `WinampMilkdropWindow.swift` | MODIFY | Add sizeState, pass to chrome, initial NSWindow sync |
| `MilkdropWindowChromeView.swift` | MODIFY | Dynamic layout + resize handle + bridge access |
| `WindowCoordinator.swift` | MODIFY | Add updateMilkdropWindowSize() with top-left anchoring |
| `ButterchurnBridge.swift` | MODIFY | Add setSize() if missing |

---

## Key Differences from VIDEO

| Aspect | VIDEO | MILKDROP |
|--------|-------|----------|
| Bottom bar height | 38px | 14px |
| Bottom bar content | 1X/2X buttons, metadata | Just chrome tiles |
| Bottom fill sprite | Single piece (38px) | Two pieces (13px + 1px) |
| Titlebar structure | Simple stretchy | 7 sections with gold fillers |
| Titlebar expansion | Expand stretchy tiles | Expand gold fillers, keep center at 3 |
| Content | AVPlayerLayer | WKWebView + Butterchurn |
| Resize notification | None | Must call setSize() on canvas |
| Sprite source | VIDEO.bmp | GEN.bmp |

---

## Oracle Review Status

**Initial Review**: Needs Changes (2026-01-05)

**Issues Addressed**:
1. ✅ Size-state wiring added (Phase 2)
2. ✅ Initial NSWindow sync added (Phase 2.2)
3. ✅ Titlebar math updated with MILKDROP-specific formula (Phase 1.2, 3.3)
4. ✅ Overlay API corrected to `show(in:previewSize:)` (Phase 4.2)
5. ✅ Bridge access via @Environment added (Phase 3.1)
6. ✅ WindowCoordinator uses top-left anchoring (Phase 5)
7. ✅ Convenience methods added (Phase 1.2)

**Titlebar Strategy**: Expand gold fillers symmetrically, keep center grey at 3 tiles (75px fixed).
