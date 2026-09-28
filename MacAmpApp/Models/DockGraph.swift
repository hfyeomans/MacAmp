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

    /// AppKit rect for a box from `box(for:)`.
    static func frame(for box: Box) -> CGRect {
        CGRect(x: box.x, y: -(box.y + box.height), width: box.width, height: box.height)
    }

    /// Boxes after `newSizes` resize windows in place (top-left fixed); attached windows follow, see MULTI_WINDOW_ARCHITECTURE.md §Docking.
    static func followResize<ID: Hashable>(boxes: [ID: Box], newSizes: [ID: CGSize], order: [ID]) -> [ID: Box] {
        let ids = order.filter { boxes[$0] != nil } + boxes.keys.filter { !order.contains($0) }
        var result = boxes
        for (id, size) in newSizes {
            result[id]?.width = size.width
            result[id]?.height = size.height
        }
        func growth(_ id: ID) -> CGSize {
            guard let old = boxes[id], let new = newSizes[id] else { return .zero }
            return CGSize(width: new.width - old.width, height: new.height - old.height)
        }
        // Parents a window is attached to: below one first, then beside one (top-aligned first).
        func parents(of id: ID) -> [(id: ID, below: Bool)] {
            guard let box = boxes[id] else { return [] }
            let above = ids.filter { $0 != id && (boxes[$0].map { hangs(box, from: $0) } ?? false) }
            let left = ids.compactMap { other -> (ID, CGFloat)? in
                guard other != id, let o = boxes[other], besideRight(box, of: o) else { return nil }
                return (other, abs(SnapUtils.top(box) - SnapUtils.top(o)))
            }.sorted { $0.1 < $1.1 }.map(\.0)
            return above.map { ($0, true) } + left.map { ($0, false) }
        }
        func overlapsOthers(_ id: ID, at box: Box) -> Bool {
            ids.contains { other in
                guard other != id, let o = result[other] else { return false }
                return SnapUtils.left(box) < SnapUtils.right(o) - 0.5 && SnapUtils.left(o) < SnapUtils.right(box) - 0.5
                    && SnapUtils.top(box) < SnapUtils.bottom(o) - 0.5 && SnapUtils.top(o) < SnapUtils.bottom(box) - 0.5
            }
        }
        var offsets: [ID: CGPoint] = [:]
        var pending = ids
        while !pending.isEmpty {
            var progressed = false
            for id in pending {
                let attached = parents(of: id)
                guard attached.allSatisfy({ offsets[$0.id] != nil }), let old = boxes[id], let sized = result[id] else { continue }
                let candidates = attached.map { parent -> CGPoint in
                    let o = offsets[parent.id] ?? .zero, g = growth(parent.id)
                    return parent.below ? CGPoint(x: o.x, y: o.y + g.height) : CGPoint(x: o.x + g.width, y: o.y)
                }
                func placed(_ o: CGPoint) -> Box { Box(x: old.x + o.x, y: old.y + o.y, width: sized.width, height: sized.height) }
                let stays = candidates.isEmpty || candidates.contains { abs($0.x) < 0.5 && abs($0.y) < 0.5 }
                let offset = stays ? .zero
                    : candidates.first { !overlapsOthers(id, at: placed($0)) }
                    ?? (overlapsOthers(id, at: placed(.zero)) ? candidates[0] : .zero)
                offsets[id] = offset
                result[id] = placed(offset)
                progressed = true
            }
            pending.removeAll { offsets[$0] != nil }
            if !progressed { break }
        }
        return result
    }

    /// `box`'s top edge is on `other`'s bottom edge and they share some horizontal span.
    static func hangs(_ box: Box, from other: Box) -> Bool {
        SnapUtils.left(box) < SnapUtils.right(other) && SnapUtils.left(other) < SnapUtils.right(box)
            && SnapUtils.near(SnapUtils.top(box), SnapUtils.bottom(other))
    }

    /// `box`'s left edge is on `other`'s right edge and they share some vertical span.
    static func besideRight(_ box: Box, of other: Box) -> Bool {
        SnapUtils.top(box) < SnapUtils.bottom(other) && SnapUtils.top(other) < SnapUtils.bottom(box)
            && SnapUtils.near(SnapUtils.left(box), SnapUtils.right(other))
    }
}
