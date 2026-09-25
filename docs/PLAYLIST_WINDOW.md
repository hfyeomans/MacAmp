# MacAmp Playlist Window Documentation

**Version:** 1.3.0
**Last Updated:** 2026-09-25
**Status:** Production

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
10. [Testing Guidelines](#testing-guidelines)
11. [Appendix: Sprite Definitions](#appendix-sprite-definitions)

---

## Introduction

The Playlist Window provides track management with PLEDIT.bmp skinning and Winamp's quantized **segment-based resizing** (25×29px increments).

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

1. **PL Button:** Click the "PL" button on the main window (`WindowCoordinator.togglePlaylistWindowVisibility()`)
2. **Menu / Keyboard:** Options → Show/Hide Playlist (`⌘⇧2`, `DockingController.togglePlaylist()`)

---

## Window Specifications

### Dimensions

Layout constants are `static let`s on `PlaylistWindowSizeState` (`MacAmpApp/Models/PlaylistWindowSizeState.swift`):

| Constant | Value |
|----------|-------|
| `segmentWidth` / `segmentHeight` | 25 / 29 |
| `baseWidth` / `baseHeight` | 275 / 116 (size [0,0]) |
| `topBarHeight` / `bottomBarHeight` | 20 / 38 |
| `leftBorderWidth` / `rightBorderWidth` | 12 / 20 (right includes the scroll track) |
| `bottomLeftWidth` / `bottomRightWidth` | 125 / 150 |
| `trackRowHeight` | 13 |

Default size is `Size2D.playlistDefault` = [0,4] = 275×232.

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

- Pixels: `Size2D.toPixels()` = `275 + width*25`, `116 + height*29`
- Content: `contentSize` = (window width − 12 − 20, window height − 20 − 38)
- Visible tracks: `visibleTrackCount = floor(contentHeight / 13)`
- Scroll range: `scrollTrackHeight = max(0, contentHeight − 20)`

---

## Architecture Overview

### File Structure

`WinampPlaylistWindow.swift` (220 lines) is the root composer: background chrome, content overlay and shade switch. Child views live in `MacAmpApp/Views/PlaylistWindow/`:

```
MacAmpApp/Views/PlaylistWindow/
  PlaylistWindowInteractionState.swift  (61 lines, @Observable state)
  PlaylistMenuPresenter.swift           (195 lines, AppKit NSMenu bridge)
  PlaylistTrackListView.swift           (78 lines, track list + selection)
  PlaylistBottomControlsView.swift      (113 lines, transport + time)
  PlaylistShadeView.swift               (42 lines, shade mode)
  PlaylistResizeHandle.swift            (65 lines, resize drag gesture)
  PlaylistTitleBarButtons.swift         (33 lines, titlebar buttons)

MacAmpApp/Views/
  PlaylistWindowActions.swift           (318 lines, playlist operations: NEW/LOAD/SAVE LIST, sort, remove, crop)
  Components/PlaylistScrollSlider.swift (105 lines)
```

### Three-Layer Pattern

Following the [three-layer architecture](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive):

- **Presentation:** `WinampPlaylistWindow` + the `PlaylistWindow/` child views (chrome sprites, resize gesture, track list)
- **Bridge:** `PlaylistWindowSizeState` (`@MainActor @Observable`: segment→pixel math, persistence, layout properties); `WindowCoordinator` (`updatePlaylistWindowSize(to:)`, `showPlaylistResizePreview(_:previewSize:)`, `hidePlaylistResizePreview(_:)`, forwarding to `WindowResizeController`)
- **Mechanism:** `AudioPlayer` (`playlist`, current track), `WindowSnapManager` (docking)

### Window Controller Pattern

`WinampPlaylistWindowController` creates a 275×232 `BorderlessWindow` with `styleMask: [.borderless, .resizable]`, `minSize` = (`baseWidth`, `baseHeight`) and `maxSize` = 2000×900, applies `WinampWindowConfigurator`, and hosts `WinampPlaylistWindow` with `SkinManager`, `AudioPlayer`, `DockingController`, `AppSettings`, `RadioStationLibrary`, `PlaybackCoordinator` and `WindowFocusState` injected. It is one of the five windows owned by `WindowCoordinator`; see [Five-Window NSWindowController Stack](MACAMP_ARCHITECTURE_GUIDE.md#five-window-nswindowcontroller-stack).

---

## Chrome Components

All chrome is drawn by `WinampPlaylistWindow.buildCompleteBackground()` with absolute `.position()`; `suffix` is `_SELECTED` when focused.

### Top Bar (Titlebar)

| Piece | Sprite | Placement |
|-------|--------|-----------|
| Left corner | `PLAYLIST_TOP_LEFT_SELECTED` (active) / `PLAYLIST_TOP_LEFT_CORNER` (inactive), 25×20 | x = 12.5 |
| Background tiles | `PLAYLIST_TOP_TILE<suffix>`, 25×20 × `topBarTileCount` = `ceil((width − 25) / 25)` | from x = 37.5, under the title |
| Title | `PLAYLIST_TITLE_BAR<suffix>`, 100×20, wrapped in `WinampTitlebarDragHandle(windowKind: .playlist, …)` | centred at width / 2 |
| Right corner | `PLAYLIST_TOP_RIGHT_CORNER<suffix>`, 25×20 | x = width − 12.5 |

`showTitlebarSpacers` (even width segment count, Webamp parity) is exposed by the size state.

### Side Borders

`PLAYLIST_LEFT_TILE` (12×29) at x = 6 and `PLAYLIST_RIGHT_TILE` (20×29, includes the scroll track) at x = width − 10, tiled from y = 34.5 in 29px steps; count = `verticalBorderTileCount` = `ceil(sideHeight / 29)`.

### Bottom Bar (Three Sections)

```
┌───────────────────────────────────────────────────────────────┐
│ LEFT (125px) │ CENTER (dynamic) │ VIS (75px) │ RIGHT (150px) │
│   Menu btns  │   Tile sprites   │ Spectrum   │ Transport+Time│
└───────────────────────────────────────────────────────────────┘
```

All at y = height − 19:

- `PLAYLIST_BOTTOM_LEFT_CORNER` (125×38) at x = 62.5
- `PLAYLIST_BOTTOM_TILE` (25×38) tiles from x = 125 up to `centerEndX` = width − 225 with the visualizer, else width − 150
- `PLAYLIST_VISUALIZER_BACKGROUND` (75×38) at x = width − 187.5, only when `sizeState.size.width >= 3` (350px+)
- `PLAYLIST_BOTTOM_RIGHT_CORNER` (150×38) at x = width − 75

Controls are overlaid by `PlaylistBottomControlsView`, `PlaylistTitleBarButtons` and menus from `PlaylistMenuPresenter`.

### List Operations (NEW LIST / LOAD LIST / SAVE LIST)

The bottom bar's LEFT section contains buttons for playlist list operations, implemented in `PlaylistWindowActions.swift`:

- **NEW LIST**: Clears the playlist immediately with no confirmation dialog (matches Winamp behavior). Calls `audioPlayer.clearPlaylist()`.

- **LOAD LIST**: Opens `NSOpenPanel` filtered to `.m3u`/`.m3u8` files and parses off the main actor. A `loadListGeneration` token rejects the result if another load started meanwhile. On success it clears the current playlist, adds the parsed entries (replaces, not appends) and auto-plays the first track. `AudioPlayer`'s `playlistGeneration` token guards against stale metadata tasks from the previous playlist.

- **SAVE LIST**: Opens `NSSavePanel` with `.m3u` default extension. Writes `#EXTM3U` format via `M3UWriter.write()` off the main actor.

Sort List, File Info, Misc Options and Remove Misc currently show a "Not supported yet" alert.

### Track Position Display

`PlaybackCoordinator.trackPositionString` provides a `"3/15"` format playlist position string shown in the main window title area, indicating the current track's position within the playlist.

---

## Segment-Based Resize System

### Overview

```
Example Sizes:
[0,0] = 275×116  (minimum)
[0,4] = 275×232  (default - matches Winamp)
[4,4] = 375×232  (wider)
[11,4] = 550×232 (2x width, Size2D.playlist2xWidth)
```

### PlaylistWindowSizeState

`@MainActor @Observable`, owned as `@State` by `WinampPlaylistWindow`. `size: Size2D` (default `.playlistDefault`) persists in `didSet`; everything else is computed from it: `pixelSize`, `windowWidth`/`windowHeight`, `centerWidth` (width − 275) and `centerTileCount`, `topBarTileCount`, `showTitlebarSpacers`, `sideHeight`, `verticalBorderTileCount`, `contentSize`/`contentWidth`/`contentHeight`, `visibleTrackCount`, `scrollTrackHeight`.

### Resize Handle Implementation

`PlaylistResizeHandle` is a 20×20 clear area at (width − 10, height − 10) with `DragGesture(minimumDistance: 0)`:

- **First tick:** store `dragStartSize`, set `isDragging`, `WindowSnapManager.shared.beginProgrammaticAdjustment()` (no magnetic snapping during resize).
- **onChanged:** candidate = start + `round(dx/25)`, `round(dy/29)` segments (clamped at 0); only the AppKit preview is updated via `coordinator.showPlaylistResizePreview(resizePreview, previewSize:)`.
- **onEnded:** recompute the final size from the total translation, commit `sizeState.size`, `updatePlaylistWindowSize(to:)`, `hidePlaylistResizePreview`, clear drag state, `endProgrammaticAdjustment()`.

### WindowCoordinator Bridge Methods

`WindowResizeController.updatePlaylistWindowSize(to:)` returns early if the size is unchanged, otherwise sets a top-left-anchored frame (`topLeftAnchoredFrame(from:newSize:)`). The playlist is not scaled by double-size mode. `showPlaylistResizePreview` shows the shared `WindowResizePreviewOverlay` over the playlist window; `hidePlaylistResizePreview` hides it.

### NSWindow Synchronization

`WinampPlaylistWindow` calls `updatePlaylistWindowSize(to: sizeState.pixelSize)` in `onAppear` (applies the persisted size at launch) and in `onChange(of: sizeState.size)` (programmatic size changes).

---

## Scroll Slider

### PlaylistScrollSlider Component

`PlaylistScrollSlider` (`MacAmpApp/Views/Components/PlaylistScrollSlider.swift`) takes `@Binding scrollOffset: Int` (first visible track index, owned by `PlaylistWindowInteractionState`), `totalTracks` and `visibleTracks`. It is placed at x = width − 15, with height `contentHeight − 4`.

- `maxScrollOffset = max(0, totalTracks − visibleTracks)`; thumb offset = `scrollOffset / maxScrollOffset × (height − 18)`.
- The track is transparent (drawn by `PLAYLIST_RIGHT_TILE`); the 8×18 thumb is `PLAYLIST_SCROLL_HANDLE`, or `PLAYLIST_SCROLL_HANDLE_SELECTED` while dragging.
- A `DragGesture(minimumDistance: 0)` maps `location.y / height` (clamped 0…1) to `scrollOffset = round(position × maxScrollOffset)`.
- Disabled at 50% opacity when all tracks fit.

### ScrollView Integration

`PlaylistTrackListView` renders rows in a `ScrollViewReader` + `ScrollView(.vertical, showsIndicators: false)`, each row `.id(index)`. `onChange(of: scrollOffset)` calls `proxy.scrollTo(newOffset, anchor: .top)` with a 0.1 s ease-out. `WinampPlaylistWindow` clamps the offset (`ui.clampScrollOffset(maxOffset:)`) when the playlist count or `visibleTrackCount` changes. Double-click a row plays it; single click selects.

---

## Mini Visualizer

### Overview

The playlist window displays a mini visualizer in the bottom bar when:
1. Window is wide enough (`sizeState.size.width >= 3`, i.e., 350px+)
2. Main window is in shade mode (`settings.isMainWindowShaded`)

This matches Winamp 5.x behavior where the visualizer appears in the playlist when the main window's visualizer is hidden.

It is the same `VisualizerView` as the main window, gated on `audioPlayer.isVisualizerRendering`, so it animates for video playback as well as audio (see [AVPlayer-Native Video DSP](MACAMP_ARCHITECTURE_GUIDE.md#avplayer-native-video-dsp)).

### Implementation

```swift
// WinampPlaylistWindow.swift
if showVisualizer {
    SimpleSpriteImage("PLAYLIST_VISUALIZER_BACKGROUND", width: 75, height: 38)
        .position(x: windowWidth - 187.5, y: windowHeight - 19)

    if settings.isMainWindowShaded {
        // Render at 76px native width, clip to 72px to match Winamp's visualizer inset
        VisualizerView()
            .frame(width: 76, height: 16)
            .frame(width: 72, alignment: .leading)
            .clipped()
            .position(x: windowWidth - 187, y: windowHeight - 18)
    }
}
```

---

## Window Focus Integration

`WinampPlaylistWindow` reads `windowFocusState.isPlaylistKey` (set by `WindowFocusDelegate`) as `isWindowActive`. Focused, the titlebar uses the `_SELECTED` sprites (left corner `PLAYLIST_TOP_LEFT_SELECTED`); unfocused, the plain sprites (left corner `PLAYLIST_TOP_LEFT_CORNER`). Shade mode (`PlaylistShadeView`) receives the same flag.

---

## Persistence & Window Docking

### Size Persistence

`PlaylistWindowSizeState` saves `["width": Int, "height": Int]` under UserDefaults key `playlistWindowSize` in `size.didSet`; `init` → `loadSize()` restores it clamped to `playlistMinimum`, defaulting to `playlistDefault`.

### Window Position Restoration

`WindowFramePersistence.restorePlaylistWindow()` reads the stored frame (`WindowFrameStore`, key `WindowFrame.playlist`), keeps the stored width (at least `baseWidth`), clamps height to `baseHeight`…`LayoutDefaults.playlistMaxHeight` (900), and applies it. Frames are saved by the shared debounced persistence path.

### Magnetic Docking During Resize

The resize gesture brackets the drag with `WindowSnapManager.shared.beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` so the window does not snap mid-resize. In double-size mode the playlist keeps its size and moves to stay docked to the EQ (`WindowResizeController`). See [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager).

---

## Testing Guidelines

Build and test with Thread Sanitizer (see the project `CLAUDE.md`).

### Size Testing Matrix

| Size Segments | Pixels | Expected Behavior |
|---------------|--------|-------------------|
| [0,0] | 275×116 | Minimum, no center tiles, ~4 tracks visible |
| [0,4] | 275×232 | Default, ~13 tracks visible |
| [3,4] | 350×232 | Visualizer appears |
| [4,4] | 375×232 | Center tiles visible |
| [11,4] | 550×232 | 2x width |

### Checklist

- [ ] Drag handle at bottom-right; resize quantizes to 25×29px with the preview overlay; NSWindow frame updates on drag end
- [ ] Size persists across app restart; center tiles and the visualizer (350px+) appear correctly
- [ ] Scroll thumb proportional to visible/total; dragging scrolls the list; disabled (opacity 0.5) when all tracks visible; offset clamps when the playlist shrinks
- [ ] Titlebar active (bright) when focused, inactive (dim) when not; all `*_SELECTED` sprites render

---

## Appendix: Sprite Definitions

Defined in `MacAmpApp/Models/SkinSprites.swift` (PLEDIT sheet).

### Titlebar Sprites (20px height)

| Sprite Name | Size | Description |
|-------------|------|-------------|
| `PLAYLIST_TOP_LEFT_CORNER` | 25×20 | Left corner (inactive) |
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
| 1.3.0 | 2026-09-25 | Pruned; snippets replaced with current code; activation and sprite names corrected |
| 1.2.0 | 2026-03-25 | List operations (NEW/LOAD/SAVE), PlaylistWindowActions.swift, track position display |
| 1.1.0 | February 2026 | Decomposition into child view structs |
| 1.0.0 | December 2025 | Initial release with full resize system |
