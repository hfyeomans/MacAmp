# Plan - Magnetic Window Cluster Regression

1. **Normalize playlist titlebar drag placement**
   - Update `WinampPlaylistWindow` to follow the main/EQ pattern: wrap the sprite in `WinampTitlebarDragHandle`, keep the sprite at the origin inside the closure, and use `.position` (or `.at`) on the handle itself so the capture view sits over the playlist titlebar.
   - Confirm the coordinates match the prior visual (center at x=137.5, y=10) so the art does not shift while ensuring the hit area now overlaps the sprite.

2. **Extend drag context with virtual space + deltas**
   - Introduce a `VirtualScreenSpace` helper storing `top`, `left`, and `BoundingBox` so we can rebuild boxes in a stable coordinate system during the drag.
   - Update `DragContext` to hold that space plus both the last processed cursor delta (to drop repeats) and the last snapped delta applied to the dragged window.
   - Adjust `beginCustomDrag` to populate the new fields using the latest window snapshot.

3. **Rebuild boxes + translate clusters inside `updateCustomDrag`**
   - Recompute window boxes (and maintain an `id -> NSWindow` map) every time using the stored virtual space.
   - After computing the snapped position for the dragged window, derive the incremental delta vs. the previous snapped delta and update the dragged window immediately via `apply`.
   - Run `connectedCluster` with the hypothetical boxes (including the moved dragged window) to find the currently attached cluster and translate every other member by the same incremental delta before updating `context.lastAppliedTopLeftDelta`.
   - Keep snapping calculations identical (snap to other windows + screen bounds) using the freshly rebuilt boxes so that dynamically-joining windows still participate in snapping.

4. **Verification**
   - Ensure playlist titlebar still renders at the same coordinates but is now draggable across the entire sprite.
   - Manually review `WindowSnapManager` logic to confirm there is no more dependency on `windowDidMove` during custom drags and that `windowDidMove` still handles non-custom drags.
   - Run Swift formatting / lint (not required now) and prepare reasoning for QA (manual test instructions) since we cannot run GUI tests here.
