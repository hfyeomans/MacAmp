# Research - Magnetic Window Cluster Regression

## Initial questions
1. Does `WinampTitlebarDragHandle` still allow inner `.position(...)` calls to reposition sprites after we locked its frame with `.frame(width:height:)`?
2. Where is the playlist title bar currently positioned relative to the new drag capture frame, and is the hit area misaligned?
3. Why does `WindowSnapManager.updateCustomDrag` assume `windowDidMove` will propagate cluster drags, and what short-circuit prevents that observer from running?
4. Which data structures do we already have for connected-cluster detection, and can they be reused during a custom drag without recomputing state from scratch each gesture update?

## Findings

### Winamp titlebar drag handle alignment
- `WinampTitlebarDragHandle` (`MacAmpApp/Views/Shared/WinampTitlebarDragHandle.swift:8-37`) now wraps its content in a top-leading `ZStack` with an explicit `frame(width:height:)` for both the capture view and provided content. The outer frame is fixed, so positioning the sprite **inside** the closure no longer moves the capture view.
- `WinampMainWindow` and `WinampEqualizerWindow` place their drag handles with `.at(CGPoint(x: 0, y: 0))` **outside** the handle (`MacAmpApp/Views/WinampMainWindow.swift:93-107`, `MacAmpApp/Views/WinampEqualizerWindow.swift:64-78`). This keeps the capture frame aligned with the titlebar art.
- `WinampPlaylistWindow` still does the old pattern: it inserts the handle without any offset and then applies `.position(x: 137.5, y: 10)` to the sprite **inside** the closure (`MacAmpApp/Views/WinampPlaylistWindow.swift:368-386`). Because the handle's frame stays at the ZStack's origin (center of the GeometryReader), the invisible drag capture never reaches the playlist titlebar; only the sprite is repositioned.
- Result: the playlist titlebar looks correct visually, but dragging fails or registers at the wrong coordinates because the capture view is not sitting over the sprite. The fix is to let the handle itself participate in layout (use `.position`/`.at` on the handle) and keep the sprite un-offset inside the closure.

### Cluster snapping during custom drags
- `updateCustomDrag` (`MacAmpApp/Utilities/WindowSnapManager.swift:210-268`) moves **only** the dragged window. A comment explicitly states "windowDidMove observer will handle cluster snapping automatically".
- The `TitlebarDragCaptureNSView` drives the drag via `WindowSnapManager.updateCustomDrag`. All moves triggered there set `isAdjusting = true` before calling `apply(...)`, suppressing `windowDidMove` callbacks. As a result, the observer never fires until the drag ends, so the rest of the cluster never receives movement deltas mid-drag.
- `windowDidMove` (`WindowSnapManager.swift:24-109`) *does* contain robust cluster logic: it recomputes connected components via `connectedCluster` and translates the entire cluster together, but it only runs for user-driven AppKit drags, not custom drags where `isAdjusting` stays true.
- The previous attempt to translate the cluster inside `updateCustomDrag` used a snapshot of the cluster taken at drag-start, so cluster membership never refreshed mid-drag. That made it impossible for windows to join or leave the cluster as they approached each other.

### Existing utilities we can reuse
- We already have `boxesAreConnected` and `connectedCluster` helpers within `WindowSnapManager` (lines 113-162) and `SnapUtils` describing the geometry thresholds (`MacAmpApp/Models/SnapUtils.swift`). These work with an AppKit-top-left coordinate system.
- `buildBoxes()` (lines 271-305) currently returns `(BoundingBox, idToBox)` but does not expose the virtual screen origin (`virtualTop`, `virtualLeft`) required to convert back to AppKit coordinates. We'll need to record that origin in the drag context so we can rebuild predicted boxes in the same coordinate space while dragging.

### Requirements distilled
1. Playlist drag handle must follow the same pattern as main/EQ windows: apply positional offsets to the handle itself and keep the sprite un-offset inside so the capture frame and art stay aligned.
2. `updateCustomDrag` must:
   - Rebuild window boxes in the stored virtual coordinate space each time.
   - Recompute the connected cluster **after** the dragged window's snapped position is known.
   - Move every window in that cluster by the incremental delta applied during the current drag update, enabling windows to join/leave dynamically.
   - Continue to honor snapping against other windows and screen bounds after the cluster shift.
3. We likely need to extend `DragContext` to track both the last raw cursor delta (to prevent redundant work) and the last snapped delta actually applied, so we can derive the incremental move for the cluster on each update.
