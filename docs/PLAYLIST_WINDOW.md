# MacAmp Playlist Window Documentation

**Version:** 1.1.0
**Last Updated:** February 2026
**Status:** Production Ready
**Author:** MacAmp Development Team
**Oracle Grade:** A- (Architecture Aligned)

> **Note (Wave 1 Decomposition, Feb 2026):** Line references such as `WinampPlaylistWindow.swift:390-417`
> throughout this document predate the playlist window decomposition and may be stale. Verify against
> current source files in `MacAmpApp/Views/PlaylistWindow/`. See [Architecture Overview](#architecture-overview)
> for the updated file structure.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Window Specifications](#window-specifications)
3. [Architecture Overview](#architecture-overview)
4. [Chrome Components](#chrome-components)
5. [Segment-Based Resize System](#segment-based-resize-system)
6. [Scroll Slider](#scroll-slider)
7. [Mini Visualizer](#mini-visualizer)
8. [Window Focus Integration](#window-focus-integration)
9. [Persistence & Window Docking](#persistence--window-docking)
10. [Implementation Patterns](#implementation-patterns)
11. [Testing Guidelines](#testing-guidelines)
12. [Appendix: Sprite Definitions](#appendix-sprite-definitions)

---

## Introduction

The Playlist Window is a core component of MacAmp's multi-window system, providing track management with authentic Winamp skinning. It features a **segment-based resize system** matching Winamp's quantized resizing behavior (25×29px increments).

### Purpose

- **Track Management:** Display and control playlist tracks
- **Dynamic Resizing:** Resize in 25×29px segments (Winamp parity)
- **Skinned Chrome:** Pixel-perfect PLEDIT.bmp sprite rendering
- **Seamless Integration:** Works with MacAmp's 5-window system

### Key Features

| Feature | Description |
|---------|-------------|
| **Segment Resize** | 25px width × 29px height grid quantization |
| **Dynamic Tiling** | Chrome tiles expand/contract with window size |
| **Scroll Slider** | Functional track navigation with proportional thumb |
| **Mini Visualizer** | 72×16px spectrum display when main window shaded |
| **Size Persistence** | UserDefaults storage across app restarts |

### Activation Methods

1. **PL Button:** Click the "PL" button on main window
2. **Keyboard:** Press `Ctrl+P` to toggle visibility
3. **Menu:** Windows → Show/Hide Playlist

---

## Window Specifications

### Dimensions

```swift
// Layout Constants (PlaylistWindowSizeState.swift:19-37)
static let segmentWidth: CGFloat = 25    // Horizontal resize unit
static let segmentHeight: CGFloat = 29   // Vertical resize unit
static let baseWidth: CGFloat = 275      // Minimum width (0 width segments)
static let baseHeight: CGFloat = 116     // Minimum height (0 height segments)

// Chrome dimensions
static let topBarHeight: CGFloat = 20    // Titlebar
static let bottomBarHeight: CGFloat = 38 // Control bar
static let leftBorderWidth: CGFloat = 12 // Left chrome
static let rightBorderWidth: CGFloat = 20 // Right chrome (includes scroll)

// Default size: 275×232 (0 width segments, 4 height segments)
static let playlistDefault = Size2D(width: 0, height: 4)
```

### Coordinate System

```
Window Layout (Minimum 275×116):
┌─────────────────────────────────────────┐
│ Titlebar (0,0,275,20)                   │ ← Draggable
├───┬─────────────────────────────────┬───┤
│ L │                                 │ R │
│ 12│     Content Area                │ 20│ ← Track List
│   │     (12,20,243,58)              │   │
├───┴─────────────────────────────────┴───┤
│ Bottom Bar (0,78,275,38)                │ ← Controls
│ [LEFT 125px] [CENTER 0px] [RIGHT 150px] │
└─────────────────────────────────────────┘

Window Layout (Default 275×232):
┌─────────────────────────────────────────┐
│ Titlebar (20px)                         │
├───┬─────────────────────────────────┬───┤
│   │                                 │   │
│ 12│     Content Area                │ 20│
│   │     (243×174)                   │   │
│   │     ~13 visible tracks          │   │
├───┴─────────────────────────────────┴───┤
│ Bottom Bar (38px)                       │
│ [LEFT] [CENTER] [VIS 75px] [RIGHT]      │ ← Visualizer at 350px+
└─────────────────────────────────────────┘
```

### Size Calculation Formulas

```swift
// Pixel dimensions from segment counts
func toPlaylistPixels() -> CGSize {
    CGSize(
        width: 275 + CGFloat(width) * 25,   // Base + segments
        height: 116 + CGFloat(height) * 29  // Base + segments
    )
}

// Content area (track list)
var contentSize: CGSize {
    CGSize(
        width: windowWidth - 12 - 20,      // Minus borders
        height: windowHeight - 20 - 38     // Minus bars
    )
}

// Visible tracks
var visibleTrackCount: Int {
    Int(floor(contentSize.height / 13))    // 13px per track row
}
```

---

## Architecture Overview

### File Structure (Post-Decomposition)

The playlist window was decomposed from a monolithic view + extension into focused child view structs (Wave 1, Feb 2026). `WinampPlaylistWindow.swift` is now ~230 lines (root composer only), down from ~530 lines. The menu extension `WinampPlaylistWindow+Menus.swift` was **deleted** -- its code moved to child views and `PlaylistMenuPresenter`.

```
MacAmpApp/Views/PlaylistWindow/
  PlaylistWindowInteractionState.swift  (47 lines, @Observable state)
  PlaylistMenuPresenter.swift           (197 lines, AppKit NSMenu bridge)
  PlaylistTrackListView.swift           (84 lines, track list + selection)
  PlaylistBottomControlsView.swift      (120 lines, transport + time)
  PlaylistShadeView.swift               (42 lines, shade mode)
  PlaylistResizeHandle.swift            (65 lines, resize drag gesture)
  PlaylistTitleBarButtons.swift         (33 lines, titlebar buttons)
```

### Three-Layer Pattern

Following MacAmp's documented architecture (MACAMP_ARCHITECTURE_GUIDE.md §3):

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  WinampPlaylistWindow.swift (~230 lines, root composer)     │
│  + PlaylistWindow/ child views (7 files, see above)         │
│  - Renders chrome sprites                                    │
│  - Handles resize gesture (PlaylistResizeHandle)             │
│  - Displays track list (PlaylistTrackListView)               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      BRIDGE LAYER                            │
│  PlaylistWindowSizeState.swift (@Observable)                │
│  - Segment-to-pixel calculations                            │
│  - UserDefaults persistence                                  │
│  - Computed layout properties                                │
│                                                              │
│  WindowCoordinator.swift (AppKit Bridge)                    │
│  - updatePlaylistWindowSize(to:)                            │
│  - showPlaylistResizePreview(_:previewSize:)                │
│  - hidePlaylistResizePreview(_:)                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    MECHANISM LAYER                           │
│  AudioPlayer.swift                                          │
│  - playlist: [Track]                                         │
│  - currentTrackIndex: Int                                    │
│                                                              │
│  WindowSnapManager.swift                                     │
│  - Magnetic docking during resize                            │
└─────────────────────────────────────────────────────────────┘
```

### Window Controller Pattern

```swift
// WinampPlaylistWindowController.swift
class WinampPlaylistWindowController: NSWindowController {
    convenience init(...) {
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.borderless, .resizable],  // Resizable!
            backing: .buffered,
            defer: false
        )

        // CRITICAL: Segment-based constraints
        window.minSize = NSSize(
            width: PlaylistWindowSizeState.baseWidth,   // 275
            height: PlaylistWindowSizeState.baseHeight  // 116
        )
        window.maxSize = NSSize(width: 2000, height: 900)

        WinampWindowConfigurator.apply(to: window)

        let rootView = WinampPlaylistWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            // ... inject all dependencies

        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController

        self.init(window: window)
    }
}
```

### Five-Window System Integration

```
WindowCoordinator
├── Main Window (always visible)
├── Equalizer Window
├── Playlist Window    ← Our focus (resizable)
├── Video Window       (resizable - 25×29 segments)
└── Milkdrop Window
```

---

## Chrome Components

### Top Bar (Titlebar)

The titlebar consists of dynamic sprite sections based on window width:

```swift
// WinampPlaylistWindow.swift:390-417
let suffix = isWindowActive ? "_SELECTED" : ""

// Left corner (25×20)
SimpleSpriteImage("PLAYLIST_TOP_LEFT\(suffix)", width: 25, height: 20)
    .position(x: 12.5, y: 10)

// Background tiles (fill width)
ForEach(0..<sizeState.topBarTileCount, id: \.self) { i in
    SimpleSpriteImage("PLAYLIST_TOP_TILE\(suffix)", width: 25, height: 20)
        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
}

// Title bar overlay (centered, 100×20)
WinampTitlebarDragHandle(windowKind: .playlist, size: CGSize(width: 100, height: 20)) {
    SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", width: 100, height: 20)
}
.position(x: windowWidth / 2, y: 10)

// Right corner (25×20)
SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER\(suffix)", width: 25, height: 20)
    .position(x: windowWidth - 12.5, y: 10)
```

### Side Borders

Dynamic vertical tiling based on content height:

```swift
// Left border tiles (12×29 each)
let borderTileCount = sizeState.verticalBorderTileCount
ForEach(0..<borderTileCount, id: \.self) { i in
    SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)
        .position(x: 6, y: 20 + 14.5 + CGFloat(i) * 29)
}

// Right border tiles (20×29 each) - includes scroll track
ForEach(0..<borderTileCount, id: \.self) { i in
    SimpleSpriteImage("PLAYLIST_RIGHT_TILE", width: 20, height: 29)
        .position(x: windowWidth - 10, y: 20 + 14.5 + CGFloat(i) * 29)
}
```

### Bottom Bar (Three Sections)

```
┌───────────────────────────────────────────────────────────────┐
│ LEFT (125px) │ CENTER (dynamic) │ VIS (75px) │ RIGHT (150px) │
│   Menu btns  │   Tile sprites   │ Spectrum   │ Transport+Time│
└───────────────────────────────────────────────────────────────┘
```

**Visualizer Visibility:** Appears when `sizeState.size.width >= 3` (350px+ width)

```swift
// WinampPlaylistWindow.swift:437-478
let showVisualizer = sizeState.size.width >= 3  // 275 + 75 = 350px minimum

// LEFT section (fixed 125px)
SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
    .position(x: 62.5, y: windowHeight - 19)

// CENTER tiles (dynamic)
let centerEndX: CGFloat = showVisualizer ? (windowWidth - 225) : (windowWidth - 150)
let centerAvailableWidth = max(0, centerEndX - 125)
let centerTileCount = Int(centerAvailableWidth / 25)

if centerTileCount > 0 {
    ForEach(0..<centerTileCount, id: \.self) { i in
        SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
            .position(x: 125 + 12.5 + CGFloat(i) * 25, y: windowHeight - 19)
    }
}

// VISUALIZER section (75px, only when wide enough)
if showVisualizer {
    SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
        .position(x: windowWidth - 187.5, y: windowHeight - 19)

    // Mini visualizer when main window shaded
    if settings.isMainWindowShaded {
        VisualizerView()
            .frame(width: 76, height: 16)
            .frame(width: 72, alignment: .leading)
            .clipped()
            .position(x: windowWidth - 187, y: windowHeight - 18)
    }
}

// RIGHT section (fixed 150px)
SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
    .position(x: windowWidth - 75, y: windowHeight - 19)
```

---

## Segment-Based Resize System

### Overview

The playlist window uses **quantized segment-based resizing** matching Winamp's behavior:

```
Segment Grid:
┌─────┬─────┬─────┬─────┬─────┐
│ 25  │ 25  │ 25  │ 25  │ 25  │  ← Width segments (25px each)
├─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │     │  29px
├─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │     │  29px  ← Height segments
├─────┼─────┼─────┼─────┼─────┤
│     │     │     │     │     │  29px
└─────┴─────┴─────┴─────┴─────┘

Example Sizes:
[0,0] = 275×116  (minimum)
[0,4] = 275×232  (default - matches Winamp)
[4,4] = 375×232  (wider)
[11,4] = 550×232 (2x width)
```

### PlaylistWindowSizeState

```swift
// MacAmpApp/Models/PlaylistWindowSizeState.swift
@MainActor
@Observable
final class PlaylistWindowSizeState {
    // MARK: - Constants
    static let segmentWidth: CGFloat = 25
    static let segmentHeight: CGFloat = 29
    static let baseWidth: CGFloat = 275
    static let baseHeight: CGFloat = 116

    // MARK: - Size State (persisted)
    var size: Size2D = .playlistDefault {
        didSet { saveSize() }
    }

    // MARK: - Computed Properties
    var pixelSize: CGSize { size.toPlaylistPixels() }
    var windowWidth: CGFloat { pixelSize.width }
    var windowHeight: CGFloat { pixelSize.height }

    var centerWidth: CGFloat {
        max(0, windowWidth - Self.bottomLeftWidth - Self.bottomRightWidth)
    }

    var centerTileCount: Int { Int(centerWidth / Self.segmentWidth) }
    var verticalBorderTileCount: Int { Int(ceil(sideHeight / Self.segmentHeight)) }
    var visibleTrackCount: Int { Int(floor(contentHeight / Self.trackRowHeight)) }

    // MARK: - Persistence
    private func saveSize() {
        let data = ["width": size.width, "height": size.height]
        UserDefaults.standard.set(data, forKey: "playlistWindowSize")
    }
}
```

### Resize Handle Implementation

```swift
// WinampPlaylistWindow.swift:756-822
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
                        // CRITICAL: Prevent magnetic snapping during resize
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    guard let baseSize = dragStartSize else { return }

                    // Quantize to 25×29px segments
                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Show AppKit preview overlay
                    if let coordinator = WindowCoordinator.shared {
                        let previewPixels = candidate.toPlaylistPixels()
                        coordinator.showPlaylistResizePreview(resizePreview, previewSize: previewPixels)
                    }
                }
                .onEnded { value in
                    // Commit final size
                    sizeState.size = finalSize

                    // Update NSWindow frame
                    WindowCoordinator.shared?.updatePlaylistWindowSize(to: sizeState.pixelSize)
                    WindowCoordinator.shared?.hidePlaylistResizePreview(resizePreview)

                    // Re-enable magnetic snapping
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: windowWidth - 10, y: windowHeight - 10)
}
```

### WindowCoordinator Bridge Methods

```swift
// WindowCoordinator.swift:820-838
func updatePlaylistWindowSize(to pixelSize: CGSize) {
    guard let window = playlistWindow else { return }
    var frame = window.frame
    let oldHeight = frame.height

    // Note: Playlist window does NOT use double-size mode
    frame.size = pixelSize
    frame.origin.y += oldHeight - pixelSize.height  // Anchor top-left
    window.setFrame(frame, display: true)
}

func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
    guard let window = playlistWindow else { return }
    overlay.show(in: window, previewSize: previewSize)
}

func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
    overlay.hide()
}
```

### NSWindow Synchronization

Critical for ensuring SwiftUI state and AppKit window stay in sync:

```swift
// WinampPlaylistWindow.swift:358-375
.onAppear {
    // Sync NSWindow size from persisted PlaylistWindowSizeState on launch
    WindowCoordinator.shared?.updatePlaylistWindowSize(to: sizeState.pixelSize)
}
.onChange(of: sizeState.size) { _, newSize in
    // Sync NSWindow when sizeState.size changes programmatically
    let pixelSize = newSize.toPlaylistPixels()
    WindowCoordinator.shared?.updatePlaylistWindowSize(to: pixelSize)
}
```

---

## Scroll Slider

### Overview

The scroll slider provides track navigation with a proportional thumb:

```
Scroll Slider Layout:
┌───┐
│ ▲ │ ← Track scroll position
│   │
│ █ │ ← Thumb (proportional to visible/total)
│   │
│   │
│ ▼ │
└───┘
```

### PlaylistScrollSlider Component

```swift
// MacAmpApp/Views/Components/PlaylistScrollSlider.swift
struct PlaylistScrollSlider: View {
    @Binding var scrollOffset: Int  // First visible track index
    let totalTracks: Int
    let visibleTracks: Int

    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 18

    @State private var isDragging = false

    private var maxScrollOffset: Int {
        max(0, totalTracks - visibleTracks)
    }

    private var scrollPosition: CGFloat {
        guard maxScrollOffset > 0 else { return 0 }
        return CGFloat(scrollOffset) / CGFloat(maxScrollOffset)
    }

    private var isDisabled: Bool {
        totalTracks <= visibleTracks
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height - handleHeight
            let handleOffset = scrollPosition * availableHeight

            ZStack(alignment: .top) {
                Color.clear  // Track (transparent)

                SimpleSpriteImage(
                    isDragging ? "PLAYLIST_SCROLL_HANDLE_SELECTED" : "PLAYLIST_SCROLL_HANDLE",
                    width: handleWidth,
                    height: handleHeight
                )
                .offset(y: handleOffset)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        guard !isDisabled else { return }

                        let newPosition = value.location.y / geometry.size.height
                        let clampedPosition = min(1, max(0, newPosition))
                        scrollOffset = Int(round(clampedPosition * CGFloat(maxScrollOffset)))
                    }
                    .onEnded { _ in isDragging = false }
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .frame(width: handleWidth)
    }
}
```

### ScrollView Integration

```swift
// WinampPlaylistWindow.swift:536-573
ScrollViewReader { proxy in
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
            ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                trackRow(track: track, index: index)
                    .id(index)  // Enable scroll-to by index
            }
        }
    }
    .onChange(of: scrollOffset) { _, newOffset in
        // Sync: scroll slider → scroll view
        withAnimation(.easeOut(duration: 0.1)) {
            proxy.scrollTo(newOffset, anchor: .top)
        }
    }
}

// Clamp scrollOffset when playlist size changes
.onChange(of: audioPlayer.playlist.count) { _, _ in
    if scrollOffset > maxScrollOffset {
        scrollOffset = maxScrollOffset
    }
}
```

---

## Mini Visualizer

### Overview

The playlist window displays a mini visualizer in the bottom bar when:
1. Window is wide enough (`sizeState.size.width >= 3`, i.e., 350px+)
2. Main window is in shade mode (`settings.isMainWindowShaded`)

This matches Winamp 5.x behavior where the visualizer appears in the playlist when the main window's visualizer is hidden.

### Implementation

```swift
// WinampPlaylistWindow.swift:459-478
if showVisualizer {
    SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
        .position(x: windowWidth - 187.5, y: windowHeight - 19)

    // Mini visualizer: Only active when main window is SHADED
    if settings.isMainWindowShaded {
        VisualizerView()
            .frame(width: 76, height: 16)           // Render at full size
            .frame(width: 72, alignment: .leading)  // Clip to 72px (4px hidden)
            .clipped()
            // Position within the 75×38 visualizer container
            .position(x: windowWidth - 187, y: windowHeight - 18)
    }
}
```

### Dimensions

```
Visualizer Container: 75×38px
┌───────────────────────────────────┐
│                                   │ 12px padding top
│  ┌─────────────────────────────┐  │
│  │ 72×16px spectrum display    │  │ ← VisualizerView clipped
│  └─────────────────────────────┘  │
│                                   │
└───────────────────────────────────┘
```

---

## Window Focus Integration

### WindowFocusState Integration

```swift
// WinampPlaylistWindow.swift:285-288
@Environment(WindowFocusState.self) var windowFocusState

private var isWindowActive: Bool {
    windowFocusState.isPlaylistKey
}
```

### Active/Inactive Titlebar

```swift
// Chrome suffix based on focus state
let suffix = isWindowActive ? "_SELECTED" : ""

// Top bar sprites change based on focus
SimpleSpriteImage("PLAYLIST_TOP_LEFT\(suffix)", ...)
SimpleSpriteImage("PLAYLIST_TOP_TILE\(suffix)", ...)
SimpleSpriteImage("PLAYLIST_TITLE_BAR\(suffix)", ...)
SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER\(suffix)", ...)
```

---

## Persistence & Window Docking

### Size Persistence

```swift
// PlaylistWindowSizeState.swift:155-172
private static let sizeKey = "playlistWindowSize"

private func saveSize() {
    let data = ["width": size.width, "height": size.height]
    UserDefaults.standard.set(data, forKey: Self.sizeKey)
}

private func loadSize() {
    guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
          let width = data["width"] as? Int,
          let height = data["height"] as? Int else {
        size = .playlistDefault
        return
    }
    size = Size2D(width: width, height: height).clamped(min: .playlistMinimum)
}
```

### Window Position Restoration

```swift
// WindowCoordinator.swift:1072-1088
if let playlist = playlistWindow,
   var storedPlaylist = windowFrameStore.frame(for: .playlist) {
    // Preserve stored width (segment-based sizing allows expansion)
    let clampedWidth = max(PlaylistWindowSizeState.baseWidth, storedPlaylist.size.width)
    let clampedHeight = max(
        PlaylistWindowSizeState.baseHeight,
        min(LayoutDefaults.playlistMaxHeight, storedPlaylist.size.height)
    )
    storedPlaylist.size = CGSize(width: clampedWidth, height: clampedHeight)
    playlist.setFrame(storedPlaylist, display: true)
}
```

### Magnetic Docking During Resize

```swift
// During drag: Disable snapping
WindowSnapManager.shared.beginProgrammaticAdjustment()

// After drag: Re-enable snapping
WindowSnapManager.shared.endProgrammaticAdjustment()
```

---

## Implementation Patterns

### @Observable State Pattern

```swift
@MainActor
@Observable
final class PlaylistWindowSizeState {
    var size: Size2D = .playlistDefault {
        didSet { saveSize() }  // Persist on change
    }

    // Computed properties derive from size
    var pixelSize: CGSize { size.toPlaylistPixels() }
    var visibleTrackCount: Int { ... }
}
```

### Environment Injection

```swift
// Window controller injects dependencies
WinampPlaylistWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(windowFocusState)
    .environment(playbackCoordinator)
```

### Sprite String Pattern

Legacy string sprite names are used for chrome (consistent with Video/Milkdrop):

```swift
// Chrome tiling: Legacy strings (no state variation)
SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)

// Stateful elements: Semantic sprites (if applicable)
SimpleSpriteImage(.playButton, width: 23, height: 18)
```

---

## Testing Guidelines

### Build Verification

```bash
# Build with Thread Sanitizer
xcodebuild -scheme MacAmpApp -configuration Debug -enableThreadSanitizer YES build
```

### Size Testing Matrix

| Size Segments | Pixels | Expected Behavior |
|---------------|--------|-------------------|
| [0,0] | 275×116 | Minimum, no center tiles, ~4 tracks visible |
| [0,4] | 275×232 | Default, ~13 tracks visible |
| [3,4] | 350×232 | Visualizer appears |
| [4,4] | 375×232 | Center tiles visible |
| [11,4] | 550×232 | 2x width |

### Resize Behavior Checklist

- [ ] Drag handle appears at bottom-right corner
- [ ] Resize quantizes to 25×29px segments
- [ ] Preview overlay shows during drag
- [ ] NSWindow frame updates on drag end
- [ ] Size persists across app restart
- [ ] Center tiles appear/disappear correctly
- [ ] Visualizer appears at 350px+ width

### Scroll Slider Checklist

- [ ] Thumb proportional to visible/total tracks
- [ ] Dragging thumb scrolls track list
- [ ] Disabled (opacity 0.5) when all tracks visible
- [ ] Offset clamps when playlist shrinks

### Focus State Checklist

- [ ] Titlebar shows active (bright) when focused
- [ ] Titlebar shows inactive (dim) when unfocused
- [ ] All `*_SELECTED` sprites render correctly

---

## Appendix: Sprite Definitions

### Titlebar Sprites (20px height)

| Sprite Name | Size | Description |
|-------------|------|-------------|
| `PLAYLIST_TOP_LEFT` | 25×20 | Left corner (inactive) |
| `PLAYLIST_TOP_LEFT_SELECTED` | 25×20 | Left corner (active) |
| `PLAYLIST_TOP_TILE` | 25×20 | Background tile (inactive) |
| `PLAYLIST_TOP_TILE_SELECTED` | 25×20 | Background tile (active) |
| `PLAYLIST_TITLE_BAR` | 100×20 | Title text (inactive) |
| `PLAYLIST_TITLE_BAR_SELECTED` | 100×20 | Title text (active) |
| `PLAYLIST_TOP_RIGHT_CORNER` | 25×20 | Right corner (inactive) |
| `PLAYLIST_TOP_RIGHT_CORNER_SELECTED` | 25×20 | Right corner (active) |

### Side Border Sprites (29px height)

| Sprite Name | Size | Description |
|-------------|------|-------------|
| `PLAYLIST_LEFT_TILE` | 12×29 | Left border tile |
| `PLAYLIST_RIGHT_TILE` | 20×29 | Right border tile (includes scroll track) |

### Bottom Bar Sprites (38px height)

| Sprite Name | Size | Description |
|-------------|------|-------------|
| `PLAYLIST_BOTTOM_LEFT_CORNER` | 125×38 | Left section (menu buttons) |
| `PLAYLIST_BOTTOM_TILE` | 25×38 | Center tile (dynamic) |
| `PLAYLIST_VISUALIZER_BACKGROUND` | 75×38 | Visualizer container |
| `PLAYLIST_BOTTOM_RIGHT_CORNER` | 150×38 | Right section (transport, time) |

### Scroll Slider Sprites

| Sprite Name | Size | Description |
|-------------|------|-------------|
| `PLAYLIST_SCROLL_HANDLE` | 8×18 | Scroll thumb (normal) |
| `PLAYLIST_SCROLL_HANDLE_SELECTED` | 8×18 | Scroll thumb (dragging) |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | February 2026 | Wave 1 decomposition: child view structs, deleted Menus extension, staleness note |
| 1.0.0 | December 2025 | Initial release with full resize system |

---

**MacAmp Playlist Window Documentation v1.0.0 | Status: Production Ready | Oracle Grade: A-**
