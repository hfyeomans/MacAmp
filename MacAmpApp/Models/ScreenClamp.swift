import CoreGraphics

/// Moves window groups back onto a screen with one offset per group, so docked windows keep their
/// relative positions (Webamp `ensureWindowsAreOnScreen`, applied per docked group). AppKit coordinates.
enum ScreenClamp {
    /// The visible frame overlapping `union` the most, or the first (main) screen when none overlaps.
    static func screen(for union: CGRect, visibleFrames: [CGRect]) -> CGRect? {
        let best = visibleFrames.max { overlapArea($0, union) < overlapArea($1, union) }
        if let best, overlapArea(best, union) > 0 { return best }
        return visibleFrames.first
    }

    /// Offset bringing `union` inside `visible`. A group larger than the screen keeps its left and
    /// top edges on screen so the titlebar stays reachable.
    static func offset(for union: CGRect, in visible: CGRect) -> CGVector {
        var dx: CGFloat = 0
        if union.width > visible.width || union.minX < visible.minX {
            dx = visible.minX - union.minX
        } else if union.maxX > visible.maxX {
            dx = visible.maxX - union.maxX
        }
        var dy: CGFloat = 0
        if union.height > visible.height || union.maxY > visible.maxY {
            dy = visible.maxY - union.maxY
        } else if union.minY < visible.minY {
            dy = visible.minY - union.minY
        }
        return CGVector(dx: dx, dy: dy)
    }

    /// New frames for the windows that must move. Each group is measured by its visible members
    /// (all members when none is visible) and every member moves by the same offset. When several
    /// groups are stranded and together fit on the target screen, they move by one shared offset so
    /// their arrangement survives (Webamp); otherwise each group is clamped on its own.
    static func clamp<ID: Hashable>(
        groups: [Set<ID>], frames: [ID: CGRect], visible: Set<ID>, visibleFrames: [CGRect]
    ) -> [ID: CGRect] {
        var stranded: [(group: Set<ID>, union: CGRect)] = []
        for group in groups {
            guard let union = measuredUnion(of: group, frames: frames, visible: visible),
                  let target = screen(for: union, visibleFrames: visibleFrames),
                  !isNegligible(offset(for: union, in: target)) else { continue }
            stranded.append((group, union))
        }
        guard let firstUnion = stranded.first?.union else { return [:] }

        let combined = stranded.dropFirst().reduce(firstUnion) { $0.union($1.union) }
        if stranded.count > 1, let target = screen(for: combined, visibleFrames: visibleFrames),
           combined.width <= target.width, combined.height <= target.height {
            return shifted(stranded.map(\.group), by: offset(for: combined, in: target), frames: frames)
        }
        var moved: [ID: CGRect] = [:]
        for (group, union) in stranded {
            guard let target = screen(for: union, visibleFrames: visibleFrames) else { continue }
            moved.merge(shifted([group], by: offset(for: union, in: target), frames: frames)) { $1 }
        }
        return moved
    }

    /// Each group moved by the origin change of the display it was on (a primary-display change
    /// re-bases every coordinate). Groups whose display is gone keep their frames.
    static func translate<ID: Hashable>(
        groups: [Set<ID>], frames: [ID: CGRect], from oldDisplays: [UInt32: CGRect], to newDisplays: [UInt32: CGRect]
    ) -> [ID: CGRect] {
        var result = frames
        for group in groups {
            let members = group.compactMap { frames[$0] }
            guard let first = members.first else { continue }
            let union = members.dropFirst().reduce(first) { $0.union($1) }
            guard let display = oldDisplays.max(by: { overlapArea($0.value, union) < overlapArea($1.value, union) }),
                  overlapArea(display.value, union) > 0,
                  let now = newDisplays[display.key] else { continue }
            let dx = now.minX - display.value.minX, dy = now.minY - display.value.minY
            for id in group { result[id] = frames[id]?.offsetBy(dx: dx, dy: dy) }
        }
        return result
    }

    /// Rigid docked groups: each member keeps its `snapshot` offset from the group's anchor, and the
    /// group is placed where the anchor is now (top-left corner). Used when macOS has moved windows
    /// back one by one.
    static func rigid<ID: Hashable>(
        groups: [Set<ID>], snapshot: [ID: CGRect], current: [ID: CGRect], anchor: (Set<ID>) -> ID?
    ) -> [ID: CGRect] {
        var result: [ID: CGRect] = [:]
        for group in groups {
            guard let anchorID = anchor(group), let was = snapshot[anchorID], let now = current[anchorID] else { continue }
            let dx = now.minX - was.minX, dy = now.maxY - was.maxY
            for id in group { result[id] = snapshot[id]?.offsetBy(dx: dx, dy: dy) }
        }
        return result
    }

    private static func measuredUnion<ID: Hashable>(of group: Set<ID>, frames: [ID: CGRect], visible: Set<ID>) -> CGRect? {
        let shown = group.intersection(visible)
        let measured = (shown.isEmpty ? group : shown).compactMap { frames[$0] }
        guard let first = measured.first else { return nil }
        return measured.dropFirst().reduce(first) { $0.union($1) }
    }

    private static func shifted<ID: Hashable>(_ groups: [Set<ID>], by delta: CGVector, frames: [ID: CGRect]) -> [ID: CGRect] {
        guard !isNegligible(delta) else { return [:] }
        var moved: [ID: CGRect] = [:]
        for id in groups.joined() {
            if let frame = frames[id] { moved[id] = frame.offsetBy(dx: delta.dx, dy: delta.dy) }
        }
        return moved
    }

    private static func isNegligible(_ delta: CGVector) -> Bool { abs(delta.dx) < 1 && abs(delta.dy) < 1 }

    private static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let overlap = a.intersection(b)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }
}
