# Plan: WinampPlaylistWindow Layer Decomposition

> **Purpose:** Phased implementation plan for decomposing WinampPlaylistWindow from cross-file extension pattern to proper layer subview decomposition with @Observable interaction state. Follows the same architectural principles as mainwindow-layer-decomposition.

---

## Status: PLANNED — Awaiting implementation approval

## Overview

| Metric | Current | Target |
|--------|---------|--------|
| WinampPlaylistWindow.swift | ~516 lines | ~120 lines (root composer) |
| WinampPlaylistWindow+Menus.swift | ~200 lines | DELETED (replaced by child views) |
| PlaylistWindowActions.swift | ~240 lines | Kept (proper class extraction) |
| New files | 0 | 5-6 child view structs + 1 state object |
| Widened properties | 6 | 0 (all restored to private or eliminated) |

---

## Phase 1: Scaffolding — Create State Object + Layout

### 1.1 Create PlaylistWindowInteractionState

**New file:** `MacAmpApp/Views/PlaylistWindow/PlaylistWindowInteractionState.swift`

Consolidate scattered @State vars into a single @Observable object:

```swift
@MainActor
@Observable
final class PlaylistWindowInteractionState {
    var selectedIndices: Set<Int> = []
    var isShadeMode: Bool = false
    var scrollOffset: Int = 0
    var dragStartSize: Size2D?
    var isDragging: Bool = false
    var resizePreview = WindowResizePreviewOverlay()
    var keyboardMonitor: Any?

    func handleTrackTap(index: Int) { ... }
    func handleKeyPress(event: NSEvent, playlistCount: Int) -> NSEvent? { ... }
}
```

### 1.2 Create PlaylistMenuPresenter

**New file:** `MacAmpApp/Views/PlaylistWindow/PlaylistMenuPresenter.swift`

Extract all 4 sprite menu builders + alert + positioning helpers from the extension:

```swift
@MainActor
struct PlaylistMenuPresenter {
    let skinManager: SkinManager
    let audioPlayer: AudioPlayer
    let menuDelegate: PlaylistMenuDelegate
    let windowHeight: CGFloat
    let windowWidth: CGFloat
    let selectedIndices: Set<Int>

    func showAddMenu(in view: NSView?) { ... }
    func showRemMenu(in view: NSView?) { ... }
    func showMiscMenu(in view: NSView?) { ... }
    func showListMenu(in view: NSView?) { ... }
}
```

---

## Phase 2: Extract Child View Structs

### 2.1 PlaylistTrackListView

Extract `buildTrackList()`, `trackRow()`, track tap handling. Receives playlist data and selection binding.

### 2.2 PlaylistBottomControlsView

Extract `buildBottomControls()`, `buildPlaylistTransportButtons()`, `buildTimeDisplays()`. Receives transport actions and time display data.

### 2.3 PlaylistShadeView

Extract `buildShadeMode()`. Receives window dimensions, active state, current track.

### 2.4 PlaylistResizeHandle

Extract `buildResizeHandle()` drag gesture. Receives size state binding.

### 2.5 PlaylistTitleBarButtons

Extract `buildTitleBarButtons()`. Receives shade toggle and window actions.

---

## Phase 3: Wire Root Composer

### 3.1 Rewrite WinampPlaylistWindow.body

Replace extension method calls with child view composition:

```swift
struct WinampPlaylistWindow: View {
    @State private var ui = PlaylistWindowInteractionState()
    // ... @Environment deps

    var body: some View {
        ZStack {
            if !ui.isShadeMode {
                buildCompleteBackground()
                PlaylistTrackListView(...)
                PlaylistBottomControlsView(...)
                PlaylistTitleBarButtons(...)
                PlaylistResizeHandle(...)
            } else {
                PlaylistShadeView(...)
            }
        }
    }
}
```

### 3.2 Restore Private Access

All @State vars move into `PlaylistWindowInteractionState` (private to root view). Computed properties (`windowWidth`, `windowHeight`, `playlistStyle`, `isWindowActive`) become private again or move to child views that need them.

### 3.3 Delete Extension File

Remove `WinampPlaylistWindow+Menus.swift` entirely. All its code lives in child views or the menu presenter.

---

## Phase 4: Verification

- Build with Thread Sanitizer
- Visual comparison: playlist window renders identically
- Functional tests: track selection, double-click play, menu operations, shade mode, resize, scroll
- Lint: zero violations without suppressions
- No regressions in playlist menus (Add, Rem, Sel, Misc, List)

---

## Dependencies

- **Upstream:** None — can be done independently
- **Sibling task:** `mainwindow-layer-decomposition` — same architectural pattern, can share learnings
- **PlaylistWindowActions.swift:** Kept as-is (already proper class extraction). Singleton + shared selectedIndices debt can be addressed separately.

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Sprite menu positioning breaks | LOW | Menu positioning is coordinate-based, extract exact values |
| Selection state desync | LOW | Consolidate into @Observable, single source of truth |
| Resize gesture breaks | LOW | Self-contained, extract as-is |
| Keyboard monitor lifecycle | MEDIUM | Move setup/teardown to state object, verify cleanup |
