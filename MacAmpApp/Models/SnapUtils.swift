import Foundation
import CoreGraphics

struct Point: Hashable {
    var x: CGFloat
    var y: CGFloat
}

struct Diff {
    var x: CGFloat?
    var y: CGFloat?
}

struct Box: Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
}

struct BoundingBox {
    var width: CGFloat
    var height: CGFloat
}

enum SnapUtils {
    static let SNAP_DISTANCE: CGFloat = 15

    static func top(_ b: Box) -> CGFloat { b.y }
    static func bottom(_ b: Box) -> CGFloat { b.y + b.height }
    static func left(_ b: Box) -> CGFloat { b.x }
    static func right(_ b: Box) -> CGFloat { b.x + b.width }

    static func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < SNAP_DISTANCE }

    static func overlapX(_ a: Box, _ b: Box) -> Bool {
        left(a) <= right(b) + SNAP_DISTANCE && left(b) <= right(a) + SNAP_DISTANCE
    }
    static func overlapY(_ a: Box, _ b: Box) -> Bool {
        top(a) <= bottom(b) + SNAP_DISTANCE && top(b) <= bottom(a) + SNAP_DISTANCE
    }

    static func intersects(_ a: Box, _ b: Box) -> Bool {
        return left(a) < right(b) && left(b) < right(a) && top(a) < bottom(b) && top(b) < bottom(a)
    }

    // Return new position for `boxA` that snaps to `boxB` if needed
    static func snap(_ boxA: Box, _ boxB: Box) -> Diff {
        var x: CGFloat?
        var y: CGFloat?

        if overlapY(boxA, boxB) {
            if near(left(boxA), right(boxB)) {
                x = right(boxB)
            } else if near(right(boxA), left(boxB)) {
                x = left(boxB) - boxA.width
            } else if near(left(boxA), left(boxB)) {
                x = left(boxB)
            } else if near(right(boxA), right(boxB)) {
                x = right(boxB) - boxA.width
            }
        }

        if overlapX(boxA, boxB) {
            if near(top(boxA), bottom(boxB)) {
                y = bottom(boxB)
            } else if near(bottom(boxA), top(boxB)) {
                y = top(boxB) - boxA.height
            } else if near(top(boxA), top(boxB)) {
                y = top(boxB)
            } else if near(bottom(boxA), bottom(boxB)) {
                y = bottom(boxB) - boxA.height
            }
        }
        return Diff(x: x, y: y)
    }

    static func snapDiff(_ a: Box, _ b: Box) -> Point {
        let newPos = snap(a, b)
        return Point(
            x: newPos.x.map { $0 - a.x } ?? 0,
            y: newPos.y.map { $0 - a.y } ?? 0
        )
    }

    static func snapDiffManyToMany(_ boxesA: [Box], _ boxesB: [Box]) -> Point {
        var x: CGFloat? = 0
        var y: CGFloat? = 0
        for a in boxesA {
            for b in boxesB {
                let diff = snapDiff(a, b)
                x = x ?? diff.x
                y = y ?? diff.y
                if let xx = x, let yy = y, xx > 0 && yy > 0 { break }
            }
        }
        return Point(x: x ?? 0, y: y ?? 0)
    }

    static func snapToMany(_ a: Box, _ others: [Box]) -> Diff {
        var x: CGFloat?
        var y: CGFloat?
        for b in others {
            let newPos = snap(a, b)
            if x == nil { x = newPos.x }
            if y == nil { y = newPos.y }
        }
        return Diff(x: x, y: y)
    }

    static func snapWithin(_ a: Box, _ bound: BoundingBox) -> Diff {
        var x: CGFloat?
        var y: CGFloat?
        if a.x - SNAP_DISTANCE < 0 {
            x = 0
        } else if a.x + a.width + SNAP_DISTANCE > bound.width {
            x = bound.width - a.width
        }
        if a.y - SNAP_DISTANCE < 0 {
            y = 0
        } else if a.y + a.height + SNAP_DISTANCE > bound.height {
            y = bound.height - a.height
        }
        return Diff(x: x, y: y)
    }

    static func snapWithinUnion(_ a: Box, union bound: BoundingBox, regions: [Box]) -> Diff {
        var diff = snapWithin(a, bound)
        guard !regions.isEmpty else { return diff }

        let candidate = Box(
            x: diff.x ?? a.x,
            y: diff.y ?? a.y,
            width: a.width,
            height: a.height
        )

        if regions.contains(where: { intersects(candidate, $0) }) {
            return diff
        }

        guard let nearest = regions.min(by: { separationDistanceSquared(candidate, $0) < separationDistanceSquared(candidate, $1) }) else {
            return diff
        }

        var adjusted = candidate
        let nudge: CGFloat = 1

        if right(adjusted) <= left(nearest) {
            adjusted.x += left(nearest) - right(adjusted) + nudge
        } else if left(adjusted) >= right(nearest) {
            adjusted.x += right(nearest) - left(adjusted) - nudge
        }

        if bottom(adjusted) <= top(nearest) {
            adjusted.y += top(nearest) - bottom(adjusted) + nudge
        } else if top(adjusted) >= bottom(nearest) {
            adjusted.y += bottom(nearest) - top(adjusted) - nudge
        }

        diff.x = adjusted.x
        diff.y = adjusted.y
        return diff
    }

    static func snapWithinDiff(_ a: Box, _ bound: BoundingBox) -> Point {
        let newPos = snapWithin(a, bound)
        return Point(
            x: newPos.x.map { $0 - a.x } ?? 0,
            y: newPos.y.map { $0 - a.y } ?? 0
        )
    }

    static func applySnap(_ original: Point, _ snaps: Diff...) -> Point {
        return snaps.reduce(original) { prev, s in
            Point(
                x: s.x ?? prev.x,
                y: s.y ?? prev.y
            )
        }
    }

    static func boundingBox(_ nodes: [Box]) -> Box {
        precondition(!nodes.isEmpty, "boundingBox requires at least one box")
        let b = nodes[0]
        var topVal = top(b)
        var rightVal = right(b)
        var bottomVal = bottom(b)
        var leftVal = left(b)

        for node in nodes.dropFirst() {
            topVal = min(topVal, top(node))
            rightVal = max(rightVal, right(node))
            bottomVal = max(bottomVal, bottom(node))
            leftVal = min(leftVal, left(node))
        }

        return Box(x: leftVal, y: topVal, width: rightVal - leftVal, height: bottomVal - topVal)
    }

    static func applyDiff(_ a: Point, _ b: Point) -> Point {
        Point(x: a.x + b.x, y: a.y + b.y)
    }

    static func applyMultipleDiffs(_ initial: Point, _ diffs: Point...) -> Point {
        let meta = diffs.reduce(Point(x: 0, y: 0)) { m, d in
            Point(
                x: (m.x == 0 || d.x == 0) ? m.x + d.x : min(m.x, d.x),
                y: (m.y == 0 || d.y == 0) ? m.y + d.y : min(m.y, d.y)
            )
        }
        return applyDiff(initial, meta)
    }

    // Find all nodes connected to `node` via the given predicate
    static func traceConnection(areConnected: @escaping (Box, Box) -> Bool) -> (_ candidates: [Box], _ node: Box) -> Set<Box> {
        return { candidates, node in
            var connected = Set<Box>()
            func check(_ n: Box) {
                for c in candidates where !connected.contains(c) && areConnected(c, n) {
                    connected.insert(c)
                    check(c)
                }
            }
            check(node)
            return connected
        }
    }

    private static func separationDistanceSquared(_ a: Box, _ b: Box) -> CGFloat {
        let dx: CGFloat
        if right(a) < left(b) {
            dx = left(b) - right(a)
        } else if left(a) > right(b) {
            dx = left(a) - right(b)
        } else {
            dx = 0
        }

        let dy: CGFloat
        if bottom(a) < top(b) {
            dy = top(b) - bottom(a)
        } else if top(a) > bottom(b) {
            dy = top(a) - bottom(b)
        } else {
            dy = 0
        }

        return dx * dx + dy * dy
    }
}
