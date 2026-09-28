import CoreGraphics

/// Pure docking connectivity over top-left boxes; callers pick the windows, so closed ones can link a chain.
enum DockGraph {
    /// Docked: an edge within snap distance of the other's edge, overlapping along the other axis.
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

    /// All windows split into docked groups (a lone window is its own group).
    static func clusters<ID: Hashable>(boxes: [ID: Box]) -> [Set<ID>] {
        var remaining = Set(boxes.keys)
        var groups: [Set<ID>] = []
        while let start = remaining.first {
            let group = cluster(from: start, boxes: boxes)
            groups.append(group)
            remaining.subtract(group)
        }
        return groups
    }

    /// Top-left box for an AppKit rect; docking is translation-invariant, so flipping y is enough.
    static func box(for rect: CGRect) -> Box {
        Box(x: rect.minX, y: -rect.maxY, width: rect.width, height: rect.height)
    }

    /// Windows below `resized` that follow its top-anchored height change; ones hanging from a window that stays, stay.
    static func dockedBelow<ID: Hashable>(_ resized: ID, oldBox: Box, boxes: [ID: Box]) -> Set<ID> {
        var graph = boxes
        graph[resized] = oldBox
        let oldBottom = SnapUtils.bottom(oldBox)
        let group = cluster(from: resized, boxes: graph)
        var below = group.filter { id in
            guard id != resized, let box = graph[id] else { return false }
            return SnapUtils.top(box) >= oldBottom - SnapUtils.SNAP_DISTANCE
        }
        var staying = group.subtracting(below).subtracting([resized])
        var changed = true
        while changed {
            changed = false
            for id in below {
                guard let box = graph[id],
                      staying.contains(where: { graph[$0].map { hangs(box, from: $0) } ?? false }) else { continue }
                below.remove(id)
                staying.insert(id)
                changed = true
            }
        }
        return below
    }

    /// `box`'s top edge is on `other`'s bottom edge and they share some horizontal span.
    private static func hangs(_ box: Box, from other: Box) -> Bool {
        SnapUtils.left(box) < SnapUtils.right(other) && SnapUtils.left(other) < SnapUtils.right(box)
            && SnapUtils.near(SnapUtils.top(box), SnapUtils.bottom(other))
    }
}
