# Research: Custom drag repelling & fragile clustering

## Files reviewed
- `MacAmpApp/Utilities/WindowSnapManager.swift`
- `MacAmpApp/Views/Shared/TitlebarDragCaptureView.swift`

## Key observations
1. **Cumulative drag input** (`TitlebarDragCaptureNSView.mouseDragged`)
   - Sends cumulative delta (`current - initial`) to `WindowSnapManager.updateCustomDrag`.
   - No throttling / smoothing: events can arrive rapidly while mouse moves fast.

2. **DragContext only captures dragged window** (`WindowSnapManager.swift:198-209`)
   - `DragContext` stores only `baseBox` for the dragged window plus virtual-space snapshot.
   - No per-cluster base boxes, so companion windows have no stable origin reference for the drag.

3. **Cluster movement uses incremental delta + current boxes** (`updateCustomDrag`, lines ~248-305)
   - After snapping adjustments, `incrementalDelta = finalDelta - context.lastAppliedTopLeftDelta`.
   - For each connected window (computed using current frames), the incremental delta is added to boxes rebuilt from *current* window frames (already moved during previous ticks).
   - Applying incremental delta to already-shifted coordinates recreates the feedback loop we saw with the original `WindowDragGesture` (causes repelling/oscillation).

4. **Cluster membership recalculated every tick**
   - `connectedCluster(start:, boxes:)` is rerun using `idToBox` built from live window frames.
   - If two windows temporarily lose exact adjacency (common during fast drags or when hitting screen snaps), they immediately drop out of the cluster and stop being dragged.

5. **Only dragged window is snapped before cluster move**
   - Snap deltas (`snapToMany`, `snapWithin`) are computed for `translatedBox` of the dragged window only.
   - Companion windows simply inherit whatever incremental delta remained, so they can fall out of snap alignment.

6. **Coordinate flip**
   - `topLeftDelta = CGPoint(x: delta.x, y: -delta.y)` because internal boxes use top-left origin. Matches earlier non-custom drag path.

## Hypothesis alignment
- **Repelling**: matches Hypothesis 1 (incremental delta applied to already-updated boxes) + missing base boxes for companions.
- **Fragile clustering**: combination of dynamic cluster recalculation and lack of locked base boxes causes slow-only dragging.
- **Webamp parity**: Their approach captures base boxes for all cluster members, applies same cumulative delta, and keeps membership static during drag.
