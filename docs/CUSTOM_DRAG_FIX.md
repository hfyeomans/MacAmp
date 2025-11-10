# Custom Drag Fix: Repelling and Fragile Clustering

## Problem Analysis

Oracle's Phase 2 custom drag implementation had two critical bugs:

1. **Windows repelling each other** - Same post-facto adjustment issue as WindowDragGesture
2. **Fragile clustering** - Fast dragging breaks cluster, only slow dragging maintains group

## Root Causes

### Cause 1: Incremental Delta on Current Positions (Repelling)

**Previous broken implementation**:
```swift
// In updateCustomDrag - WRONG APPROACH
let incrementalDelta = CGPoint(
    x: finalDelta.x - context.lastAppliedTopLeftDelta.x,  // Delta since last tick
    y: finalDelta.y - context.lastAppliedTopLeftDelta.y
)

for id in clusterIDs where id != context.draggedWindowID {
    guard var box = idToBox[id], let window = idToWindow[id] else { continue }
    box.x += incrementalDelta.x  // ← Applied to CURRENT box from buildBoxes()
    box.y += incrementalDelta.y  // ← Not from baseBox at drag start
}
```

**Why this caused repelling**:
- Mouse tick 1: Main window moves 10px, EQ window moves 10px to follow
- Mouse tick 2: Main cumulative=15px, incremental=5px
- BUT: `idToBox[id]` is built from `window.frame` which already has 10px applied
- Applying 5px to position that's already moved 10px creates oscillation/feedback loop
- Windows appear to push each other away

### Cause 2: Dynamic Cluster Recalculation (Fragile)

**Previous broken implementation**:
```swift
// In updateCustomDrag - WRONG APPROACH
let clusterIDs = connectedCluster(start: context.draggedWindowID, boxes: idToBox)
```

**Why this caused fragile clustering**:
- `idToBox` is built from CURRENT window frames after dragged window moved
- Cluster recalculated on EVERY mouse tick
- Fast dragging: Main window snaps to edge, EQ doesn't snap → connection breaks
- Next tick: Cluster recalculation excludes EQ
- EQ stops following
- Only slow dragging keeps windows connected every tick

### Cause 3: Missing Base Boxes for Cluster Windows

**Previous broken DragContext**:
```swift
private struct DragContext {
    let draggedWindowID: ObjectIdentifier
    let baseBox: Box  // ← Only ONE baseBox (dragged window)
    let virtualSpace: VirtualScreenSpace
    var lastInputDelta: CGPoint = .zero
    var lastAppliedTopLeftDelta: CGPoint = .zero  // ← Not needed
}
```

**Why this was wrong**:
- Only dragged window had base position captured
- Cluster windows had no stable reference point
- Each tick applied delta to CURRENT position (from buildBoxes)
- No cumulative tracking for cluster windows

## Webamp's Working Pattern

Webamp's approach (which works perfectly):
```javascript
function handleMouseDown(e) {
  const cluster = findConnectedWindows(draggedWindow);

  // Capture base position for EVERY window in cluster
  for (const window of cluster) {
    window.baseX = window.x;
    window.baseY = window.y;
  }
}

function handleMouseMove(e) {
  const delta = calculateDelta(e);

  // Apply SAME cumulative delta to ALL cluster windows from their base positions
  for (const window of cluster) {
    window.x = window.baseX + delta.x;  // ← Cumulative, not incremental
    window.y = window.baseY + delta.y;
  }

  // THEN check for snaps
  applySnaps(cluster);
}
```

**Key principles**:
1. Cluster membership is STATIC (decided at mousedown, never changes during drag)
2. ALL windows have baseX/baseY captured at drag start
3. SAME cumulative delta applied to ALL windows
4. Cluster doesn't get recalculated during drag

## The Fix

### Fixed DragContext Structure
```swift
private struct DragContext {
    let draggedWindowID: ObjectIdentifier
    let clusterIDs: Set<ObjectIdentifier>          // ← Static cluster membership
    let baseBoxes: [ObjectIdentifier: Box]          // ← ALL cluster base positions
    let virtualSpace: VirtualScreenSpace
    var lastInputDelta: CGPoint = .zero
    // Removed: lastAppliedTopLeftDelta (not needed)
}
```

### Fixed beginCustomDrag
```swift
func beginCustomDrag(kind: WindowKind, startPointInScreen _: NSPoint) {
    guard let window = windows[kind]?.window else { return }
    guard let (virtualSpace, idToBox) = buildBoxes() else { return }
    let draggedID = ObjectIdentifier(window)
    guard idToBox[draggedID] != nil else { return }

    // ✅ Compute cluster ONCE at drag start
    let clusterIDs = connectedCluster(start: draggedID, boxes: idToBox)

    // ✅ Capture base boxes for ALL cluster members
    var baseBoxes: [ObjectIdentifier: Box] = [:]
    for id in clusterIDs {
        if let box = idToBox[id] {
            baseBoxes[id] = box
        }
    }

    dragContexts[kind] = DragContext(
        draggedWindowID: draggedID,
        clusterIDs: clusterIDs,      // ← Static for entire drag
        baseBoxes: baseBoxes,         // ← All bases captured
        virtualSpace: virtualSpace
    )
}
```

### Fixed updateCustomDrag
```swift
func updateCustomDrag(kind: WindowKind, cumulativeDelta delta: CGPoint) {
    guard var context = dragContexts[kind] else { return }
    guard delta != context.lastInputDelta else { return }

    var idToWindow: [ObjectIdentifier: NSWindow] = [:]
    for (_, tracked) in windows {
        if let window = tracked.window {
            idToWindow[ObjectIdentifier(window)] = window
        }
    }

    // ✅ Use STATIC cluster IDs to filter non-cluster windows
    let liveBoxes = boxes(in: context.virtualSpace)
    let otherBoxes = liveBoxes.compactMap { entry -> Box? in
        context.clusterIDs.contains(entry.key) ? nil : entry.value
    }

    // Calculate snap delta for dragged window
    let topLeftDelta = CGPoint(x: delta.x, y: -delta.y)
    var translatedDraggedBox = draggedBaseBox
    translatedDraggedBox.x += topLeftDelta.x
    translatedDraggedBox.y += topLeftDelta.y

    let diffToOthers = SnapUtils.snapToMany(translatedDraggedBox, otherBoxes)
    let diffWithin = SnapUtils.snapWithin(translatedDraggedBox, context.virtualSpace.bounds)
    let snappedPoint = SnapUtils.applySnap(...)

    let snapDelta = CGPoint(
        x: snappedPoint.x - translatedDraggedBox.x,
        y: snappedPoint.y - translatedDraggedBox.y
    )
    let finalDelta = CGPoint(
        x: topLeftDelta.x + snapDelta.x,
        y: topLeftDelta.y + snapDelta.y
    )

    // ✅ Apply SAME cumulative delta to ALL cluster windows from their base positions
    for (id, baseBox) in context.baseBoxes {
        guard let window = idToWindow[id] else { continue }
        var movedBox = baseBox  // ← Start from base position
        movedBox.x += finalDelta.x  // ← Cumulative delta
        movedBox.y += finalDelta.y

        isAdjusting = true
        apply(box: movedBox, to: window, ...)
        isAdjusting = false
    }

    context.lastInputDelta = delta
    dragContexts[kind] = context
}
```

## Key Changes Summary

1. **Static cluster membership** - Computed once at `beginCustomDrag`, never recalculated
2. **All cluster base boxes captured** - Every window has a stable reference point
3. **Cumulative deltas for all** - Same delta applied to all windows from their bases
4. **No incremental calculation** - Removed `lastAppliedTopLeftDelta` and incremental logic
5. **No dynamic cluster** - Removed `connectedCluster` call from `updateCustomDrag`

## Verification

Build successful with thread sanitizer enabled:
```bash
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Debug \
  -destination 'platform=macOS' -enableThreadSanitizer YES clean build
```

**Expected behavior**:
- ✅ No window repelling during drag
- ✅ Cluster remains stable during fast dragging
- ✅ All windows move together smoothly
- ✅ Snapping works correctly for entire cluster

## Testing Instructions

1. **Launch MacAmp**
2. **Position windows in a cluster** (snapped together)
3. **Fast drag test**:
   - Drag main window quickly across screen
   - Verify all cluster windows follow smoothly
   - No separation should occur
4. **Snap test**:
   - Drag cluster near screen edge
   - Verify all windows snap together as a unit
   - No individual windows should lag or repel
5. **Multi-screen test**:
   - Drag cluster across screen boundaries
   - Verify coordinates remain correct
   - No jumping or oscillation

## Files Changed

- `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowSnapManager.swift`
  - Fixed `DragContext` structure
  - Fixed `beginCustomDrag` to capture all cluster base boxes
  - Fixed `updateCustomDrag` to use cumulative deltas
  - Added helper methods: `buildBoxes()`, `makeVirtualSpace()`, `boxes(in:)`, `box(for:in:)`
  - Moved `apply(box:to:virtualTop:virtualLeft:)` out of `windowDidMove` to shared helper

## Related Documentation

- Original Phase 2 implementation: See commit 718df4d
- Webamp reference: https://github.com/captbaritone/webamp (window management)
- Previous coordinate fix: See docs/Phase2_coordinate_fix.md
