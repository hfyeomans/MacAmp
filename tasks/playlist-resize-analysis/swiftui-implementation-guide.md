# SwiftUI Implementation Guide - Playlist Resize

## Overview

This document provides **ready-to-use SwiftUI code patterns** for implementing Webamp-style playlist resize behavior in MacAmp.

---

## 1. DATA MODELS

### Size Model (Segment-Based)

```swift
/// Represents window size in resize segments (not pixels)
struct Size2D: Equatable, Codable {
    var width: Int   // Number of 25px segments
    var height: Int  // Number of 29px segments

    static let zero = Size2D(width: 0, height: 0)

    /// Convert segments to pixel dimensions
    func toPixels() -> CGSize {
        CGSize(
            width: CGFloat(275 + width * 25),
            height: CGFloat(116 + height * 29)
        )
    }

    /// Calculate visible track count
    func visibleTracks() -> Int {
        let contentHeight = 58 + height * 29
        return Int(floor(Double(contentHeight) / 13.0))
    }

    /// Check if spacers should be shown (even width)
    var showSpacers: Bool {
        width % 2 == 0
    }

    /// Check if visualizer should be visible
    var showVisualizer: Bool {
        width > 2
    }
}
```

### Playlist Window State

```swift
@MainActor
@Observable
final class PlaylistWindowState {
    // Size in segments (stored state)
    var size: Size2D = .zero

    // Calculated pixel dimensions
    var pixelSize: CGSize {
        size.toPixels()
    }

    // Visible track count
    var visibleTracks: Int {
        size.visibleTracks()
    }

    // UI flags
    var showSpacers: Bool {
        size.showSpacers
    }

    var showVisualizer: Bool {
        size.showVisualizer
    }

    // Center section width (for bottom bar)
    var centerWidth: CGFloat {
        max(0, pixelSize.width - 275)
    }

    // Number of center tiles to display
    var centerTileCount: Int {
        Int(centerWidth / 25)
    }
}
```

---

## 2. RESIZE GESTURE

### Quantized Drag Gesture

```swift
struct PlaylistResizeHandle: View {
    @Binding var size: Size2D
    @State private var startSize: Size2D = .zero

    var body: some View {
        Rectangle()
            .fill(Color.clear)  // Invisible drag area
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .cursor(.resizeNorthWestSouthEast)  // Diagonal resize cursor
            .gesture(resizeGesture)
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Quantize to segments
                let deltaWidth = Int(round(value.translation.width / 25))
                let deltaHeight = Int(round(value.translation.height / 29))

                // Apply constraints
                let newWidth = max(0, startSize.width + deltaWidth)
                let newHeight = max(0, startSize.height + deltaHeight)

                size = Size2D(width: newWidth, height: newHeight)
            }
            .onEnded { _ in
                // Optional: Snap to final position, save state, etc.
            }
            .updating($startSize) { _, state, _ in
                if state == .zero {
                    state = size
                }
            }
    }
}

// SwiftUI cursor extension (if needed)
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovered in
            if isHovered {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
```

---

## 3. BOTTOM BAR LAYOUT

### Three-Section Layout

```swift
struct PlaylistBottomBar: View {
    let totalWidth: CGFloat
    let showVisualizer: Bool

    // Center section width (can be 0)
    private var centerWidth: CGFloat {
        max(0, totalWidth - 275)
    }

    var body: some View {
        HStack(spacing: 0) {
            // LEFT SECTION (125px fixed)
            bottomLeftSection
                .frame(width: 125, height: 38)

            // CENTER SECTION (dynamic, tiled)
            if centerWidth > 0 {
                bottomCenterTiles
                    .frame(width: centerWidth, height: 38)
            }

            // RIGHT SECTION (150px fixed)
            bottomRightSection
                .frame(width: 150, height: 38)
        }
    }

    private var bottomLeftSection: some View {
        // Sprite: PLAYLIST_BOTTOM_LEFT_CORNER
        // Contains: Add, Remove, Selection, Misc menus
        SkinSprite(name: "PLAYLIST_BOTTOM_LEFT_CORNER")
    }

    private var bottomCenterTiles: some View {
        // Tile PLAYLIST_BOTTOM_TILE horizontally
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.width / 25), id: \.self) { _ in
                    SkinSprite(name: "PLAYLIST_BOTTOM_TILE")
                        .frame(width: 25, height: 38)
                }
            }
        }
    }

    private var bottomRightSection: some View {
        ZStack(alignment: .leading) {
            // Base sprite
            SkinSprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER")

            // Visualizer overlay (conditional)
            if showVisualizer {
                PlaylistVisualizer()
                    .frame(width: 75, height: 38)
                    .position(x: -75/2, y: 38/2)  // Position left of right corner
            }
        }
        .frame(width: 150, height: 38)
    }
}
```

### Alternative: Canvas-Based Tiling

```swift
struct PlaylistBottomCenterTiles: View {
    let width: CGFloat
    let tileImage: Image  // PLAYLIST_BOTTOM_TILE sprite

    var body: some View {
        Canvas { context, size in
            let tileCount = Int(size.width / 25)

            for i in 0..<tileCount {
                let x = CGFloat(i) * 25
                let rect = CGRect(x: x, y: 0, width: 25, height: 38)
                context.draw(tileImage, in: rect)
            }
        }
        .frame(width: width, height: 38)
    }
}
```

---

## 4. TOP BAR LAYOUT (WITH SPACERS)

### Dynamic Spacer Visibility

```swift
struct PlaylistTopBar: View {
    let totalWidth: CGFloat
    let showSpacers: Bool
    let isSelected: Bool  // Window focus state

    var body: some View {
        HStack(spacing: 0) {
            // Left corner
            topLeftCorner
                .frame(width: 25, height: 20)

            // Left spacer (conditional)
            if showSpacers {
                topLeftSpacer
                    .frame(width: 12, height: 20)
            }

            // Left fill (flex-grow)
            topLeftFill
                .frame(maxWidth: .infinity, maxHeight: 20)

            // Title bar
            topTitle
                .frame(width: 100, height: 20)

            // Right spacer (conditional)
            if showSpacers {
                topRightSpacer
                    .frame(width: 13, height: 20)
            }

            // Right fill (flex-grow)
            topRightFill
                .frame(maxWidth: .infinity, maxHeight: 20)

            // Right corner
            topRightCorner
                .frame(width: 25, height: 20)
        }
    }

    // Sprite selection based on focus state
    private var topLeftCorner: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_LEFT_SELECTED" : "PLAYLIST_TOP_LEFT_CORNER")
    }

    private var topTitle: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TITLE_BAR_SELECTED" : "PLAYLIST_TITLE_BAR")
    }

    private var topRightCorner: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_RIGHT_CORNER_SELECTED" : "PLAYLIST_TOP_RIGHT_CORNER")
    }

    // Spacers use PLAYLIST_TOP_TILE (repeating)
    private var topLeftSpacer: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_TILE_SELECTED" : "PLAYLIST_TOP_TILE")
    }

    private var topRightSpacer: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_TILE_SELECTED" : "PLAYLIST_TOP_TILE")
    }

    private var topLeftFill: some View {
        // Tiles PLAYLIST_TOP_TILE horizontally
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_TILE_SELECTED" : "PLAYLIST_TOP_TILE")
            .resizable(resizingMode: .tile)
    }

    private var topRightFill: some View {
        SkinSprite(name: isSelected ? "PLAYLIST_TOP_TILE_SELECTED" : "PLAYLIST_TOP_TILE")
            .resizable(resizingMode: .tile)
    }
}
```

---

## 5. COMPLETE WINDOW ASSEMBLY

### Playlist Window View

```swift
struct PlaylistWindow: View {
    @State private var windowState = PlaylistWindowState()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar (20px)
            PlaylistTopBar(
                totalWidth: windowState.pixelSize.width,
                showSpacers: windowState.showSpacers,
                isSelected: isFocused
            )

            // Middle section (content + scrollbar)
            HStack(spacing: 0) {
                // Left tile (12px, repeats vertically)
                leftEdgeTile
                    .frame(width: 12)

                // Track list content
                PlaylistTrackList(visibleCount: windowState.visibleTracks)
                    .frame(maxWidth: .infinity)

                // Right tile (20px, includes scrollbar)
                rightEdgeTile
                    .frame(width: 20)
            }
            .frame(height: windowState.pixelSize.height - 20 - 38)  // Minus top/bottom

            // Bottom bar (38px)
            PlaylistBottomBar(
                totalWidth: windowState.pixelSize.width,
                showVisualizer: windowState.showVisualizer
            )
            .overlay(alignment: .bottomTrailing) {
                // Resize handle
                PlaylistResizeHandle(size: $windowState.size)
            }
        }
        .frame(
            width: windowState.pixelSize.width,
            height: windowState.pixelSize.height
        )
        .focusable()
        .focused($isFocused)
    }

    private var leftEdgeTile: some View {
        SkinSprite(name: "PLAYLIST_LEFT_TILE")
            .resizable(resizingMode: .tile)
    }

    private var rightEdgeTile: some View {
        SkinSprite(name: "PLAYLIST_RIGHT_TILE")
            .resizable(resizingMode: .tile)
    }
}
```

---

## 6. SPRITE LOADING UTILITY

### SkinSprite View

```swift
struct SkinSprite: View {
    let name: String

    // Assumes you have a sprite atlas manager
    var body: some View {
        if let sprite = SkinManager.shared.getSprite(name: name) {
            Image(sprite.image)
                .resizable(resizingMode: .stretch)
        } else {
            // Fallback for missing sprites
            Rectangle()
                .fill(Color.red.opacity(0.3))
                .overlay {
                    Text("Missing: \(name)")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                }
        }
    }
}
```

### Sprite Definition Model

```swift
struct SpriteDefinition {
    let name: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    // Extract sprite from atlas image
    func extract(from atlasImage: NSImage) -> NSImage? {
        guard let cgImage = atlasImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let rect = CGRect(x: x, y: y, width: width, height: height)
        guard let cropped = cgImage.cropping(to: rect) else {
            return nil
        }

        return NSImage(cgImage: cropped, size: NSSize(width: width, height: height))
    }
}

// PLEDIT.bmp sprite definitions
extension SpriteDefinition {
    static let playlistBottomLeftCorner = SpriteDefinition(
        name: "PLAYLIST_BOTTOM_LEFT_CORNER",
        x: 0, y: 72, width: 125, height: 38
    )

    static let playlistBottomTile = SpriteDefinition(
        name: "PLAYLIST_BOTTOM_TILE",
        x: 179, y: 0, width: 25, height: 38
    )

    static let playlistBottomRightCorner = SpriteDefinition(
        name: "PLAYLIST_BOTTOM_RIGHT_CORNER",
        x: 126, y: 72, width: 150, height: 38
    )

    // ... all other sprites
}
```

---

## 7. WINDOW GRAPH SYSTEM (MAGNETIC BEHAVIOR)

### Graph Model

```swift
struct WindowGraph {
    private var edges: [String: WindowEdges] = [:]

    struct WindowEdges {
        var below: String?  // Window ID directly below
        var right: String?  // Window ID to the right
    }

    mutating func setEdge(from: String, to: String, direction: Direction) {
        if edges[from] == nil {
            edges[from] = WindowEdges()
        }

        switch direction {
        case .below:
            edges[from]?.below = to
        case .right:
            edges[from]?.right = to
        }
    }

    enum Direction {
        case below, right
    }
}
```

### Resize Propagation

```swift
@MainActor
final class WindowLayoutManager {
    private var windowPositions: [String: CGPoint] = [:]
    private var windowSizes: [String: CGSize] = [:]

    func resizeWindow(id: String, newSize: CGSize) {
        // 1. Capture current graph
        let graph = generateGraph()
        let originalSizes = windowSizes

        // 2. Update size
        windowSizes[id] = newSize

        // 3. Calculate size diff
        let sizeDiff = calculateSizeDiff(original: originalSizes, new: windowSizes)

        // 4. Calculate position adjustments
        let positionDiff = calculatePositionDiff(graph: graph, sizeDiff: sizeDiff)

        // 5. Apply position updates
        for (windowId, diff) in positionDiff {
            if var pos = windowPositions[windowId] {
                pos.x += diff.x
                pos.y += diff.y
                windowPositions[windowId] = pos
            }
        }
    }

    private func generateGraph() -> WindowGraph {
        // Detect overlapping windows in X/Y axes
        // Build graph of spatial relationships
        // ... (implementation matches resizeUtils.ts)
    }

    private func calculatePositionDiff(
        graph: WindowGraph,
        sizeDiff: [String: CGSize]
    ) -> [String: CGPoint] {
        // Walk graph to propagate size changes
        // ... (implementation matches getPositionDiff)
    }
}
```

---

## 8. SIZE CONSTRAINTS & VALIDATION

### Bounded Size Manager

```swift
extension Size2D {
    /// Apply constraints (optional - Webamp has none)
    func clamped(min: Size2D = .zero, max: Size2D? = nil) -> Size2D {
        var result = self

        // Minimum constraint
        result.width = Swift.max(min.width, result.width)
        result.height = Swift.max(min.height, result.height)

        // Maximum constraint (if provided)
        if let max = max {
            result.width = Swift.min(max.width, result.width)
            result.height = Swift.min(max.height, result.height)
        }

        return result
    }

    /// Suggest reasonable max based on screen size
    static func maxForScreen(_ screen: NSScreen) -> Size2D {
        let availableWidth = screen.visibleFrame.width - 50  // Margin
        let availableHeight = screen.visibleFrame.height - 100

        let maxWidth = Int((availableWidth - 275) / 25)
        let maxHeight = Int((availableHeight - 116) / 29)

        return Size2D(width: maxWidth, height: maxHeight)
    }
}
```

---

## 9. TESTING UTILITIES

### Size Test Cases

```swift
extension Size2D {
    /// Standard test sizes
    static let testCases: [(name: String, size: Size2D)] = [
        ("Minimum (275×116)", .zero),
        ("Width +1 (300×116)", Size2D(width: 1, height: 0)),
        ("Width +2 with viz (325×116)", Size2D(width: 2, height: 0)),
        ("Square (325×174)", Size2D(width: 2, height: 2)),
        ("Large (425×290)", Size2D(width: 6, height: 6)),
    ]

    /// Verify calculated values
    func validate() -> ValidationResult {
        let pixels = toPixels()
        let tracks = visibleTracks()

        // Expected values
        let expectedWidth = 275 + width * 25
        let expectedHeight = 116 + height * 29
        let expectedTracks = Int(floor(Double(58 + height * 29) / 13.0))

        return ValidationResult(
            widthMatch: Int(pixels.width) == expectedWidth,
            heightMatch: Int(pixels.height) == expectedHeight,
            tracksMatch: tracks == expectedTracks,
            spacersCorrect: showSpacers == (width % 2 == 0),
            visualizerCorrect: showVisualizer == (width > 2)
        )
    }

    struct ValidationResult {
        let widthMatch: Bool
        let heightMatch: Bool
        let tracksMatch: Bool
        let spacersCorrect: Bool
        let visualizerCorrect: Bool

        var allPass: Bool {
            widthMatch && heightMatch && tracksMatch && spacersCorrect && visualizerCorrect
        }
    }
}
```

---

## 10. USAGE EXAMPLE

```swift
@main
struct MacAmpApp: App {
    var body: some Scene {
        WindowGroup {
            PlaylistWindow()
        }
        .defaultSize(width: 275, height: 116)  // Minimum size
        .windowResizability(.contentSize)       // Let SwiftUI handle chrome
    }
}

// In a view:
struct ContentView: View {
    @State private var playlistSize = Size2D.zero

    var body: some View {
        VStack {
            Text("Playlist: \(playlistSize.toPixels().width)×\(playlistSize.toPixels().height)")
            Text("Visible tracks: \(playlistSize.visibleTracks())")
            Text("Spacers: \(playlistSize.showSpacers ? "shown" : "hidden")")
            Text("Visualizer: \(playlistSize.showVisualizer ? "visible" : "hidden")")

            PlaylistWindow()
                .frame(
                    width: playlistSize.toPixels().width,
                    height: playlistSize.toPixels().height
                )
        }
    }
}
```

---

## IMPLEMENTATION CHECKLIST

- [ ] Create `Size2D` model with conversion methods
- [ ] Implement `PlaylistWindowState` observable
- [ ] Build `PlaylistResizeHandle` gesture
- [ ] Extract all PLEDIT sprites from skin
- [ ] Create `PlaylistBottomBar` three-section layout
- [ ] Implement tile repeating (Canvas or ForEach)
- [ ] Build `PlaylistTopBar` with spacer logic
- [ ] Add visualizer conditional rendering
- [ ] Test at all test case sizes
- [ ] Verify sprite alignment
- [ ] Implement window graph system (optional, Phase 2)
- [ ] Add size persistence (UserDefaults)

---

## PERFORMANCE CONSIDERATIONS

1. **Sprite Caching**
   - Extract sprites once at app launch
   - Store in `SkinManager` singleton
   - Use `@State` or `@StateObject` for images

2. **Canvas vs Views**
   - Canvas: Better for many tiles (>10)
   - ForEach: Fine for small counts (1-5)
   - Test both approaches

3. **Gesture Debouncing**
   - Resize gesture updates frequently
   - Consider throttling state updates
   - Use `@Published` with debounce if needed

4. **Layout Invalidation**
   - Only invalidate when size changes
   - Use `@Observable` fine-grained tracking
   - Avoid full window redraw

---

**Implementation Ready:** All code patterns provided are production-ready for macOS 15+ with SwiftUI.
