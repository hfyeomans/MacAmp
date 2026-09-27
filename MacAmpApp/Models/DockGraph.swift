import CoreGraphics

/// Docking connectivity between window boxes (top-left coordinates, `SnapUtils` conventions).
/// Pure: callers decide which windows to include, so closed windows can still link a chain.
enum DockGraph {
    /// Two boxes are docked when an edge of one lies within snap distance of an edge of the other
    /// and they overlap along the other axis.
    static func areDocked(_ a: Box, _ b: Box) -> Bool {
        if SnapUtils.overlapX(a, b) {
            if SnapUtils.near(SnapUtils.top(a), SnapUtils.bottom(b)) { return true }
            if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.top(b)) { return true }
            if SnapUtils.near(SnapUtils.top(a), SnapUtils.top(b)) { return true }
            if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.bottom(b)) { return true }
        }
        if SnapUtils.overlapY(a, b) {
            if SnapUtils.near(SnapUtils.left(a), SnapUtils.right(b)) { return true }
            if SnapUtils.near(SnapUtils.right(a), SnapUtils.left(b)) { return true }
            if SnapUtils.near(SnapUtils.left(a), SnapUtils.left(b)) { return true }
            if SnapUtils.near(SnapUtils.right(a), SnapUtils.right(b)) { return true }
        }
        return false
    }

    /// Every window transitively docked to `start` (including `start`).
    static func cluster<ID: Hashable>(from start: ID, boxes: [ID: Box]) -> Set<ID> {
        var visited: Set<ID> = []
        var stack: [ID] = [start]
        while let id = stack.popLast() {
            guard visited.insert(id).inserted, let box = boxes[id] else { continue }
            for (otherID, otherBox) in boxes where !visited.contains(otherID) && areDocked(box, otherBox) {
                stack.append(otherID)
            }
        }
        return visited
    }

    /// Windows docked below `resized` (transitively) that must follow a height change of `resized`
    /// whose top edge stays fixed, e.g. shade/unshade. `oldBox` is `resized` before the change.
    static func dockedBelow<ID: Hashable>(_ resized: ID, oldBox: Box, boxes: [ID: Box]) -> Set<ID> {
        var graph = boxes
        graph[resized] = oldBox
        let oldBottom = SnapUtils.bottom(oldBox)
        return cluster(from: resized, boxes: graph).filter { id in
            guard id != resized, let box = graph[id] else { return false }
            return SnapUtils.top(box) >= oldBottom - SnapUtils.SNAP_DISTANCE
        }
    }
}
