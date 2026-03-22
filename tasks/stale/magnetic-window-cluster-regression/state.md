# State - Magnetic Window Cluster Regression

- Playlist window now positions the `WinampTitlebarDragHandle` itself at `(x: 137.5, y: 10)` while keeping the sprite un-offset inside the closure. This aligns the invisible drag capture frame with the rendered titlebar so dragging works again without shifting the art.
- `WindowSnapManager` records the virtual screen space (top + left origin plus bounds) when a drag begins and keeps it with the drag context so all subsequent calculations reuse the same coordinate system.
- `DragContext` tracks both the last cursor delta fed into `updateCustomDrag` and the last snapped delta actually applied. The difference between the two lets us compute the incremental movement we need to apply to any connected windows each tick.
- `updateCustomDrag` now rebuilds window boxes on every call, snaps the dragged window as before, replaces its box in the working set, recomputes the currently-connected cluster, and shifts every non-dragged member by the incremental delta. Cluster membership updates dynamically as windows approach or separate during the drag.
- Helper functions (`makeVirtualSpace`, `boxes(in:)`, `box(for:in:)`) centralize box construction while keeping `windowDidMove` logic untouched for standard AppKit drags.
- Manual verification still needed in-app: grab the playlist titlebar to ensure it drags, then snap EQ to main, drag main, and confirm EQ moves with it while detaching correctly when pulled past the snap threshold.
