# Playlist Window Resize - Implementation Plan

**Task:** Playlist Window Resize + Scroll Slider
**Estimate:** 8-12 hours
**Reference:** Video window resize implementation
**Oracle Grade:** B → A (enhanced with architectural details)

---

## Implementation Strategy

Follow the proven VIDEO window pattern exactly:
1. Create PlaylistWindowSizeState (copy VideoWindowSizeState)
2. Refactor layout to use dynamic pixel dimensions
3. Add resize gesture with AppKit preview overlay
4. Implement scroll slider with proper bridge contract

---

## Architecture Decision: Sprite Resolution

### Decision: Use Legacy Strings for Chrome (Consistent with Video/Milkdrop)

**Rationale:** Video and Milkdrop windows both use legacy string sprite names for chrome tiling. This is acceptable because:
1. Chrome sprites are skin-specific and don't vary by state
2. Semantic sprites are best for stateful elements (buttons, indicators)
3. Consistency with existing window implementations

**When to use each:**
```swift
// LEGACY (chrome tiling): Use for static chrome elements
SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)

// SEMANTIC (stateful): Use for interactive/stateful elements
SimpleSpriteImage(.playButton, width: 23, height: 18)
SimpleSpriteImage(.digit(0), width: 9, height: 13)
```

**Future refinement:** SemanticSprite enum could be extended with playlist chrome sprites if skin variations require fallback logic.

---

## Phase 1: Foundation (1-2 hours)

### 1.1 Fix Sprite Width Bug
**File:** `MacAmpApp/Models/SkinSprites.swift`

```swift
// BEFORE (line ~312):
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 154, height: 38)

// AFTER:
Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 150, height: 38)
```

### 1.2 Add Playlist Presets to Size2D
**File:** `MacAmpApp/Models/Size2D.swift`

Add after line ~22 (video presets):
```swift
// MARK: - Playlist Window Presets

/// Playlist window minimum size: 275×116
static let playlistMinimum = Size2D(width: 0, height: 0)

/// Playlist window default size: 275×232 (current fixed size)
static let playlistDefault = Size2D(width: 0, height: 4)

/// Playlist window 2x width: 550×232
static let playlist2xWidth = Size2D(width: 11, height: 4)
```

Note: `toPlaylistPixels()` already exists at line 36-41 - verify it's correct.

### 1.3 Create PlaylistWindowSizeState
**File:** `MacAmpApp/Models/PlaylistWindowSizeState.swift` (NEW)

Copy VideoWindowSizeState.swift and modify:

```swift
import Foundation
import Observation

/// Observable state for PLAYLIST window sizing using segment-based resize
/// Follows same pattern as VideoWindowSizeState for architectural consistency
@MainActor
@Observable
final class PlaylistWindowSizeState {
    // MARK: - Size State

    var size: Size2D = .playlistDefault {
        didSet { saveSize() }
    }

    // MARK: - Computed Properties

    var pixelSize: CGSize {
        size.toPlaylistPixels()
    }

    /// Center section width in bottom bar (can be 0 at minimum size)
    /// Formula: totalWidth - LEFT(125) - RIGHT(150) = totalWidth - 275
    var centerWidth: CGFloat {
        max(0, pixelSize.width - 275)
    }

    /// Number of center tiles to render in bottom bar
    var centerTileCount: Int {
        Int(centerWidth / 25)
    }

    /// Number of vertical border tiles needed based on height
    var verticalBorderTileCount: Int {
        let contentHeight = pixelSize.height - 20 - 38  // Minus titlebar and bottom bar
        return Int(ceil(contentHeight / 29))
    }

    /// Content area dimensions (for track list)
    var contentSize: CGSize {
        CGSize(
            width: pixelSize.width - 12 - 20,   // Minus left(12)/right(20) borders
            height: pixelSize.height - 20 - 38   // Minus titlebar/bottom bar
        )
    }

    /// Number of visible tracks based on current height
    var visibleTrackCount: Int {
        Int(floor(contentSize.height / 13))  // 13px per track row
    }

    /// Scroll track height (for scroll slider)
    var scrollTrackHeight: CGFloat {
        contentSize.height
    }

    /// Whether to show titlebar spacers (Webamp parity)
    /// Even widths show spacers, odd widths hide them
    var showTitlebarSpacers: Bool {
        size.width % 2 == 0
    }

    // MARK: - Initialization

    init() {
        loadSize()
    }

    // MARK: - Persistence

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

    // MARK: - Convenience

    func resetToDefault() {
        size = .playlistDefault
    }

    func setToMinimum() {
        size = .playlistMinimum
    }

    /// Resize by delta segments (used by drag gesture)
    func resize(byWidthSegments deltaW: Int, heightSegments deltaH: Int) {
        let newSize = Size2D(
            width: size.width + deltaW,
            height: size.height + deltaH
        ).clamped(min: .playlistMinimum)
        size = newSize
    }
}
```

---

## Phase 2: Layout Refactor (2-3 hours)

### 2.1 Inject PlaylistWindowSizeState
**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

Add environment:
```swift
@Environment(PlaylistWindowSizeState.self) var sizeState
```

Replace hard-coded dimensions:
```swift
// BEFORE:
private let windowWidth: CGFloat = 275
private let windowHeight: CGFloat = 232

// AFTER:
private var windowWidth: CGFloat { sizeState.pixelSize.width }
private var windowHeight: CGFloat { sizeState.pixelSize.height }
```

### 2.2 Dynamic Vertical Border Tiling
```swift
// BEFORE (fixed count):
let leftTileCount = Int(ceil(CGFloat(192) / 29))

// AFTER (dynamic):
let leftTileCount = sizeState.verticalBorderTileCount
```

### 2.3 Three-Section Bottom Bar
Replace current bottom HStack:

```swift
@ViewBuilder
private func buildDynamicBottomBar() -> some View {
    let bottomBarY = sizeState.pixelSize.height - 19  // Center of 38px bar

    // LEFT section (125px fixed)
    SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
        .position(x: 62.5, y: bottomBarY)

    // CENTER section (dynamic tiles) - only visible when width > 275
    let centerCount = sizeState.centerTileCount
    ForEach(0..<centerCount, id: \.self) { i in
        SimpleSpriteImage("PLAYLIST_BOTTOM_TILE", width: 25, height: 38)
            .position(x: 125 + 12.5 + CGFloat(i) * 25, y: bottomBarY)
    }

    // RIGHT section (150px fixed)
    SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 150, height: 38)
        .position(x: sizeState.pixelSize.width - 75, y: bottomBarY)
}
```

### 2.4 Dynamic Content Area
```swift
// BEFORE:
.frame(width: 243, height: 174)

// AFTER:
.frame(width: sizeState.contentSize.width, height: sizeState.contentSize.height)
```

### 2.5 Dynamic Top Bar Tiling
Update top bar tile count based on width:
```swift
let topTileCount = Int(ceil((sizeState.pixelSize.width - 50) / 25))  // Minus corners
```

### 2.6 Titlebar Spacer Parity (Webamp Fidelity)

**Implementation:** Show/hide spacers based on even/odd width segments

```swift
@ViewBuilder
private func buildTitlebarSpacers(suffix: String) -> some View {
    // Only show spacers on even width segments (Webamp parity)
    if sizeState.showTitlebarSpacers {
        // Left spacer (12px) - between left corner and title tiles
        SimpleSpriteImage("PLAYLIST_TOP_LEFT_SPACER\(suffix)", width: 12, height: 20)
            .position(x: 31, y: 10)  // After 25px left corner

        // Right spacer (13px) - between title tiles and right corner
        SimpleSpriteImage("PLAYLIST_TOP_RIGHT_SPACER\(suffix)", width: 13, height: 20)
            .position(x: sizeState.pixelSize.width - 31.5, y: 10)  // Before 25px right corner
    }
}
```

**Note:** Verify PLAYLIST_TOP_LEFT_SPACER and PLAYLIST_TOP_RIGHT_SPACER exist in SkinSprites.swift. If missing, add them or use transparent rectangles with appropriate background color.

---

## Phase 3: Resize Gesture (2-3 hours)

### 3.1 Add State Variables
```swift
@State private var dragStartSize: Size2D?
@State private var isDragging: Bool = false
@State private var resizePreview = WindowResizePreviewOverlay()
```

### 3.2 Implement Resize Handle
Add to body ZStack:
```swift
buildResizeHandle()
```

Create method (copy from VideoWindowChromeView):
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

                    // Show AppKit preview overlay (solves SwiftUI clipping)
                    if let coordinator = WindowCoordinator.shared {
                        let previewPixels = candidate.toPlaylistPixels()
                        coordinator.showPlaylistResizePreview(resizePreview, previewSize: previewPixels)
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

                    // Commit final size to state (triggers persistence)
                    sizeState.size = finalSize

                    // Update NSWindow frame via coordinator bridge
                    if let coordinator = WindowCoordinator.shared {
                        coordinator.updatePlaylistWindowSize(to: sizeState.pixelSize)
                        coordinator.hidePlaylistResizePreview(resizePreview)
                    }

                    // Cleanup
                    isDragging = false
                    dragStartSize = nil
                    // CRITICAL: Re-enable magnetic snapping
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: sizeState.pixelSize.width - 10, y: sizeState.pixelSize.height - 10)
}
```

### 3.3 Add WindowCoordinator Methods
**File:** `MacAmpApp/ViewModels/WindowCoordinator.swift`

Add methods matching video pattern:
```swift
// MARK: - Playlist Resize Coordination

func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
    guard let window = playlistWindow else { return }
    overlay.show(in: window, previewSize: previewSize)
}

func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
    overlay.hide()
}

func updatePlaylistWindowSize(to size: CGSize) {
    guard let window = playlistWindow else { return }
    var frame = window.frame
    let oldHeight = frame.height

    // Account for double-size mode
    let scale = settings.isDoubleSize ? 2.0 : 1.0
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)

    frame.size = scaledSize
    frame.origin.y += oldHeight - scaledSize.height  // Anchor top-left
    window.setFrame(frame, display: true)
}
```

---

## Phase 4: Scroll Slider (2-3 hours)

### 4.1 Scroll Slider Bridge Contract

**Architecture Decision:** Scroll state lives in the BRIDGE layer (view-local @State) with binding to mechanism layer (PlaylistManager).

**Layer Responsibilities:**

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| Mechanism | PlaylistManager | `tracks.count`, `currentIndex` |
| Bridge | PlaylistWindowSizeState | `visibleTrackCount` |
| Bridge | WinampPlaylistWindow | `@State scrollOffset: Int` (first visible track index) |
| Presentation | PlaylistScrollSlider | Renders thumb, handles drag |

**Calculations:**

```swift
// Thumb sizing (proportional to visible/total)
let totalTracks = playlistManager.tracks.count
let visibleTracks = sizeState.visibleTrackCount
let thumbRatio = totalTracks > 0 ? min(1.0, CGFloat(visibleTracks) / CGFloat(totalTracks)) : 1.0
let thumbHeight = max(18, trackHeight * thumbRatio)  // Minimum 18px (sprite height)

// Scroll position (0.0 to 1.0)
let maxScrollOffset = max(0, totalTracks - visibleTracks)
let scrollPosition = maxScrollOffset > 0 ? CGFloat(scrollOffset) / CGFloat(maxScrollOffset) : 0

// Reverse calculation (thumb drag → scroll offset)
func scrollOffsetFromPosition(_ position: CGFloat) -> Int {
    let maxScrollOffset = max(0, playlistManager.tracks.count - sizeState.visibleTrackCount)
    return Int(round(position * CGFloat(maxScrollOffset)))
}
```

### 4.2 Create PlaylistScrollSlider Component
**File:** `MacAmpApp/Views/Components/PlaylistScrollSlider.swift` (NEW)

```swift
import SwiftUI

/// Winamp-style playlist scroll slider with gold thumb
/// Follows bridge layer pattern: receives bindings, handles presentation only
struct PlaylistScrollSlider: View {
    @Binding var scrollOffset: Int  // First visible track index
    let totalTracks: Int
    let visibleTracks: Int
    let trackHeight: CGFloat

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
                // Track (transparent, scroll track is part of PLAYLIST_RIGHT_TILE)
                Color.clear

                // Handle (gold thumb)
                SimpleSpriteImage(
                    isDragging ? "PLAYLIST_SCROLL_HANDLE_SELECTED" : "PLAYLIST_SCROLL_HANDLE",
                    width: handleWidth,
                    height: handleHeight
                )
                .offset(y: handleOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        guard !isDisabled else { return }

                        let newPosition = value.location.y / geometry.size.height
                        let clampedPosition = min(1, max(0, newPosition))
                        scrollOffset = Int(round(clampedPosition * CGFloat(maxScrollOffset)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .frame(width: handleWidth)
    }
}
```

### 4.3 Integrate Scroll Slider
**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

Add state:
```swift
@State private var scrollOffset: Int = 0
```

Replace static scroll handle:
```swift
// BEFORE:
SimpleSpriteImage("PLAYLIST_SCROLL_HANDLE", width: 8, height: 18)
    .position(x: 260, y: 30)

// AFTER:
PlaylistScrollSlider(
    scrollOffset: $scrollOffset,
    totalTracks: audioPlayer.playlist.count,
    visibleTracks: sizeState.visibleTrackCount,
    trackHeight: sizeState.scrollTrackHeight
)
.frame(height: sizeState.scrollTrackHeight)
.position(x: sizeState.pixelSize.width - 10, y: 20 + sizeState.contentSize.height / 2)
```

### 4.4 Connect to ScrollView
Use ScrollViewReader or programmatic offset to sync scroll position:

```swift
// In track list view
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(Array(audioPlayer.playlist.enumerated()), id: \.offset) { index, track in
                TrackRowView(track: track, index: index)
                    .id(index)
            }
        }
    }
    .onChange(of: scrollOffset) { _, newOffset in
        // Sync: slider → scroll view
        proxy.scrollTo(newOffset, anchor: .top)
    }
}
```

---

## Phase 5: Double-Size Mode & Docking Integration

### 5.1 Double-Size Mode Behavior

**Expected Behavior:**
- Size2D segments store **1x values** (not scaled)
- Scaling happens at **NSWindow frame level** (in WindowCoordinator)
- Chrome sprites render at 2x via SwiftUI's existing double-size scaling

**Implementation:**
```swift
// In WindowCoordinator.updatePlaylistWindowSize(to:)
func updatePlaylistWindowSize(to size: CGSize) {
    guard let window = playlistWindow else { return }

    // Apply double-size scaling at the window frame level
    let scale = settings.isDoubleSize ? 2.0 : 1.0
    let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)

    var frame = window.frame
    let oldHeight = frame.height
    frame.size = scaledSize
    frame.origin.y += oldHeight - scaledSize.height  // Anchor top-left
    window.setFrame(frame, display: true)
}
```

**Testing Checklist:**
- [ ] Resize at 1x, toggle to 2x → window doubles correctly
- [ ] Resize at 2x → quantization still works (25×29 × 2 = 50×58px visual)
- [ ] Toggle 2x during resize drag → no jitter

### 5.2 Magnetic Docking Behavior

**Expected Behavior:**
- Resize does NOT break existing clusters
- After resize completes, cluster detection updates
- Docked windows maintain relative positions

**Implementation Notes:**
- `WindowSnapManager.beginProgrammaticAdjustment()` is called in resize handle
- This prevents magnetic snapping DURING drag
- On drag end, `endProgrammaticAdjustment()` re-enables snapping
- Cluster detection runs on next window move

**Testing Checklist:**
- [ ] Dock playlist to main window (right edge)
- [ ] Resize playlist wider → main window doesn't move
- [ ] After resize, drag main → cluster still works
- [ ] Resize in cluster → relative positions preserved

---

## Phase 6: Polish & Testing (1-2 hours)

### 6.1 Wire Up Environment
**File:** `MacAmpApp/MacAmpApp.swift` or window controller

Inject PlaylistWindowSizeState:
```swift
let playlistSizeState = PlaylistWindowSizeState()

WinampPlaylistWindow()
    .environment(playlistSizeState)
```

### 6.2 Testing Checklist
- [ ] Build with `-enableThreadSanitizer YES`
- [ ] Test resize at [0,0], [1,0], [2,2], [4,4]
- [ ] Verify center tiles appear/disappear
- [ ] Test scroll slider drag
- [ ] Test with Classic Winamp skin
- [ ] Verify persistence across restart
- [ ] Test double-size mode interaction
- [ ] Test magnetic docking during/after resize
- [ ] Verify spacer parity (even/odd width)

### 6.3 Code Review
Request Oracle (Codex) review:
```bash
codex "@MacAmpApp/Models/PlaylistWindowSizeState.swift @MacAmpApp/Views/WinampPlaylistWindow.swift @MacAmpApp/Views/Components/PlaylistScrollSlider.swift Review playlist resize implementation for Grade A architectural compliance"
```

---

## File Change Summary

| File | Action | Changes |
|------|--------|---------|
| Size2D.swift | MODIFY | Add playlist presets (minimal changes, toPlaylistPixels exists) |
| SkinSprites.swift | MODIFY | Fix BOTTOM_RIGHT width 154→150 |
| PlaylistWindowSizeState.swift | CREATE | New file (based on VideoWindowSizeState) |
| PlaylistScrollSlider.swift | CREATE | New component with bridge contract |
| WinampPlaylistWindow.swift | MODIFY | Major refactor: 3-section layout, resize gesture, scroll slider |
| WindowCoordinator.swift | MODIFY | Add playlist resize methods with double-size scaling |

---

## Rollback Plan

If implementation fails:
1. Git stash/reset to clean state
2. Keep fixed-size playlist (current behavior)
3. Document blockers in state.md

---

## Success Criteria (Grade A)

- [ ] Playlist window resizes in 25×29px increments
- [ ] Center tiles appear/disappear correctly
- [ ] Resize handle works (20×20px bottom-right)
- [ ] AppKit preview shows during drag
- [ ] Scroll slider is functional with proper bridge contract
- [ ] Size persists to UserDefaults
- [ ] Thread Sanitizer clean
- [ ] Works with Classic Winamp skin
- [ ] Double-size mode integration verified
- [ ] Magnetic docking behavior verified
- [ ] Titlebar spacer parity implemented (even/odd width)
- [ ] Sprite resolution decision documented

---

## Oracle Review Addressed (B → A)

| Issue | Resolution |
|-------|------------|
| Semantic sprites | Documented as architectural decision: legacy strings for chrome (consistent with Video/Milkdrop) |
| Spacer parity | Added 2.6 with concrete implementation |
| Size2D API | Verified: uses `width/height` fields, matches codebase |
| Double-size mode | Added 5.1 with behavior spec and code |
| Docking interaction | Added 5.2 with expected behavior and testing |
| Scroll bridge contract | Added 4.1 with full layer specification |

---

**Plan Complete. Grade A Ready.** See todo.md for actionable task list.
