# Custom Drag: Repelling and Fragile Clustering

Titlebar drags go through `TitlebarDragCaptureView` → `WindowSnapManager.beginCustomDrag` / `updateCustomDrag` / `endCustomDrag` (in `MacAmpApp/Utilities/WindowSnapManager.swift`), replacing SwiftUI's `WindowDragGesture`.

## Problem Analysis

A naive custom drag shows two symptoms:

1. **Windows repelling each other** - the same post-facto adjustment issue as `WindowDragGesture`
2. **Fragile clustering** - fast drags break the cluster; only slow drags keep the group together

### Cause 1: Incremental Delta on Current Positions (Repelling)

Applying the per-tick delta (`finalDelta - lastAppliedDelta`) to boxes rebuilt from the *current* `window.frame` double-counts movement: on tick 2 the follower has already moved 10px, and adding the 5px increment to that position creates a feedback loop, so windows appear to push each other away.

### Cause 2: Dynamic Cluster Recalculation (Fragile)

Calling `connectedCluster(start:boxes:)` on every tick, using current frames, lets the cluster change mid-drag. On a fast drag the main window snaps to an edge, the EQ doesn't, the connection breaks, and the next recalculation drops the EQ, which stops following.

### Cause 3: Missing Base Boxes for Cluster Windows

Capturing a base box only for the dragged window leaves the other cluster windows with no stable reference point, so each tick moves them from wherever they currently are.

## Webamp's Working Pattern

```javascript
function handleMouseDown(e) {
  const cluster = findConnectedWindows(draggedWindow);
  for (const window of cluster) {   // capture base position for EVERY window
    window.baseX = window.x;
    window.baseY = window.y;
  }
}

function handleMouseMove(e) {
  const delta = calculateDelta(e);
  for (const window of cluster) {   // same cumulative delta from each base
    window.x = window.baseX + delta.x;
    window.y = window.baseY + delta.y;
  }
  applySnaps(cluster);
}
```

1. Cluster membership is decided at mousedown and never changes during the drag
2. Every window has its base position captured at drag start
3. The same cumulative delta is applied to every window

## Solution

```swift
private struct DragContext {
    let draggedWindowID: ObjectIdentifier
    let clusterIDs: Set<ObjectIdentifier>      // static for the whole drag
    let baseBoxes: [ObjectIdentifier: Box]     // base box for every cluster member
    let virtualSpace: VirtualScreenSpace
    var lastInputDelta: CGPoint = .zero
}
```

**`beginCustomDrag(kind:startPointInScreen:)`**
- Builds boxes once (`buildBoxes()`).
- Cluster membership follows Webamp: dragging the **main** window captures the full connected cluster (`connectedCluster`); dragging **EQ/Playlist** (or any other window) moves only that window, separating it from the cluster so it can re-snap.
- Stores a base box for every member in `dragContexts[kind]`.

**`updateCustomDrag(kind:cumulativeDelta:)`**
- Ignores a repeated delta (`delta == lastInputDelta`).
- Treats live boxes outside `clusterIDs` as snap targets.
- Translates the cluster's **bounding box** (`SnapUtils.boundingBox` of the base boxes) by the cumulative delta (y flipped to top-left space), then snaps it with `SnapUtils.snapToMany` (other windows) and `SnapUtils.snapWithinUnion` (screen union and per-screen regions). Snapping the group box rather than just the dragged window prevents off-screen drift.
- Applies `cumulative delta + snap delta` to every member from its base box, via `apply(box:to:virtualTop:virtualLeft:)` with `isAdjusting = true`.

**`endCustomDrag(kind:)`** clears the context and records every window's origin in `lastOrigins`.

Helpers: `buildBoxes()`, `makeVirtualSpace()`, `boxes(in:)`, `box(for:in:)`, `apply(box:to:virtualTop:virtualLeft:)`.

## Verification

```bash
xcodebuild -scheme MacAmpApp -configuration Debug \
  -destination 'platform=macOS' -enableThreadSanitizer YES build
```

Expected behavior: no repelling; the cluster stays together on fast drags; the whole cluster snaps as a unit.

Manual test:
1. Snap windows into a cluster.
2. Drag the main window quickly across the screen: all cluster windows follow with no separation.
3. Drag the cluster near a screen edge: it snaps as a unit, with no lagging or repelling window.
4. Drag the cluster across screen boundaries: coordinates stay correct, with no jumping or oscillation.
5. Drag EQ or Playlist: it detaches from the cluster and can re-snap.

## Related

- [MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md)
- Webamp window management: https://github.com/captbaritone/webamp
