# Cluster Left Edge Constraint Investigation

## Problem Statement
Window cluster can reach right edge of monitor but NOT left edge.

**Observations:**
- Individual VIDEO window: Can reach left edge ✅
- Individual other windows: Can reach left/right edges ✅
- Cluster: Can reach RIGHT edge ✅
- Cluster: CANNOT reach LEFT edge ❌ (stops prematurely)

## Test Plan

### Test 1: Pre-Resize Build (Commit d293e95)
**Built:** Pre-resize version with only 2x scaleEffect
**Location:** `/Users/hank/Library/Developer/Xcode/DerivedData/.../MacAmp.app`

**Steps:**
1. Launch pre-resize build
2. Create cluster (Main + EQ + Playlist + VIDEO all docked)
3. Drag cluster to LEFT edge
4. Record: Can it reach x=0? Or does it stop early?

**Result:** ___ (User to test)

### Test 2: Current Build (Commit f165a3b)
**Built:** Current with full resize implementation

**Steps:**
1. Launch current build
2. Create cluster
3. Drag to left edge
4. Record: Can it reach x=0?

**Result:** ___ (Known - CANNOT reach left edge)

## Analysis

### If Pre-Resize ALSO Can't Reach Left Edge:
→ **Pre-existing WindowSnapManager bug**
→ Not caused by our resize work
→ Investigate SnapUtils.swift cluster snapping logic
→ May be related to screen coordinate calculations

### If Pre-Resize CAN Reach Left Edge:
→ **Regression introduced by resize work**
→ Check what changed in WindowSnapManager integration
→ Check if VIDEO window size changes affect cluster bounds
→ Review makeVideoDockingContext() logic

## Suspect Code

### SnapUtils.snapWithinUnion
```swift
static func snapWithinUnion(_ a: Box, union bound: BoundingBox, regions: [Box]) -> Diff {
    var diff = snapWithin(a, bound)
    // ... checks if candidate intersects with regions
    // Might be preventing left edge if VIDEO window size causes intersection
}
```

### WindowSnapManager Cluster Movement
```swift
// Move cluster by user delta
for id in clusterIDs where id != movedID {
    w.setFrameOrigin(NSPoint(x: origin.x + userDelta.x, y: origin.y + userDelta.y))
}

// Then snap the whole cluster
let diffWithin = SnapUtils.snapWithinUnion(groupBox, union: virtualSpace.bounds, regions: virtualSpace.screenBoxes)
```

**Theory:** `screenBoxes` or `snapWithinUnion` may have asymmetric behavior

## Next Steps

1. User tests pre-resize build (d293e95)
2. Report if cluster reaches left edge: YES/NO
3. Based on result, investigate appropriate code area
4. Fix identified issue
5. Verify fix with cluster movement tests

---

**Status:** Awaiting pre-resize test results
**Current Build:** Pre-resize version ready at d293e95
**Return Command:** `git checkout feature/video-milkdrop-windows`
