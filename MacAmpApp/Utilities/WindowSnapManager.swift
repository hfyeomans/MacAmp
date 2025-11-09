import AppKit
import Foundation

enum WindowKind: Hashable {
    case main
    case playlist
    case equalizer
}

@MainActor
final class WindowSnapManager: NSObject, NSWindowDelegate {
    static let shared = WindowSnapManager()

    private struct TrackedWindow {
        weak var window: NSWindow?
        let kind: WindowKind
    }

    private var windows: [WindowKind: TrackedWindow] = [:]
    private var lastOrigins: [ObjectIdentifier: NSPoint] = [:]
    private var isAdjusting = false

    func register(window: NSWindow, kind: WindowKind) {
        // Set minimum titlebar style and disable tabs for classic look
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        windows[kind] = TrackedWindow(window: window, kind: kind)
        window.delegate = self
        lastOrigins[ObjectIdentifier(window)] = window.frame.origin
    }

    func windowDidMove(_ notification: Notification) {
        guard !isAdjusting else { return }
        guard let movedWindow = notification.object as? NSWindow else { return }

        // Determine which tracked kind moved
        guard let movedKind = windows.first(where: { $0.value.window === movedWindow })?.key else { return }

        // Build Box list in a top-left origin coordinate space
        let allScreens = NSScreen.screens
        guard !allScreens.isEmpty else { return }
        let virtualTop: CGFloat = allScreens.map { $0.frame.maxY }.max() ?? 0
        let virtualLeft: CGFloat = allScreens.map { $0.frame.minX }.min() ?? 0
        let virtualRight: CGFloat = allScreens.map { $0.frame.maxX }.max() ?? 0
        let virtualBottom: CGFloat = allScreens.map { $0.frame.minY }.min() ?? 0
        let virtualWidth = virtualRight - virtualLeft
        let virtualHeight = (virtualTop - virtualBottom)

        func box(for window: NSWindow) -> Box {
            let f = window.frame
            let x = f.origin.x - virtualLeft
            let yTop = virtualTop - (f.origin.y + f.size.height)
            return Box(x: x, y: yTop, width: f.size.width, height: f.size.height)
        }

        func apply(box: Box, to window: NSWindow) {
            // Convert top-left box back to AppKit bottom-left origin
            let newOriginX = box.x + virtualLeft
            let newOriginY = virtualTop - (box.y + box.height)
            let newOrigin = NSPoint(x: newOriginX, y: newOriginY)
            let currentOrigin = window.frame.origin
            // Only move if changed by at least 1px to avoid feedback loops
            if abs(currentOrigin.x - newOrigin.x) >= 1 || abs(currentOrigin.y - newOrigin.y) >= 1 {
                isAdjusting = true
                window.setFrameOrigin(newOrigin)
                isAdjusting = false
            }
        }

        guard let moved = windows[movedKind]?.window else { return }
        let movedID = ObjectIdentifier(moved)

        // Compute user delta from last origin
        let currentOrigin = moved.frame.origin
        let lastOrigin = lastOrigins[movedID] ?? currentOrigin
        let userDelta = NSPoint(x: currentOrigin.x - lastOrigin.x, y: currentOrigin.y - lastOrigin.y)

        // Build mapping from window -> box
        var idToWindow: [ObjectIdentifier: NSWindow] = [:]
        var idToBox: [ObjectIdentifier: Box] = [:]
        for (_, tracked) in windows {
            if let w = tracked.window {
                let id = ObjectIdentifier(w)
                idToWindow[id] = w
                idToBox[id] = box(for: w)
            }
        }

        // Find connected cluster including the moved window
        let clusterIDs = connectedCluster(start: movedID, boxes: idToBox)
        let otherIDs = Set(idToBox.keys).subtracting(clusterIDs)

        // 1) Move the rest of the cluster by the user's delta (the moved window already moved)
        isAdjusting = true
        for id in clusterIDs where id != movedID {
            if let w = idToWindow[id] {
                let origin = w.frame.origin
                w.setFrameOrigin(NSPoint(x: origin.x + userDelta.x, y: origin.y + userDelta.y))
            }
        }
        isAdjusting = false

        // Recompute cluster box after move
        var clusterBoxes: [Box] = []
        for id in clusterIDs {
            if let w = idToWindow[id] { clusterBoxes.append(box(for: w)) }
        }
        guard !clusterBoxes.isEmpty else { return }
        let groupBox = SnapUtils.boundingBox(clusterBoxes)

        // Snap the whole cluster to other windows and screen edges
        let otherBoxes = otherIDs.compactMap { idToBox[$0] }
        let diffToOthers = SnapUtils.snapToMany(groupBox, otherBoxes)
        let diffWithin = SnapUtils.snapWithin(groupBox, BoundingBox(width: virtualWidth, height: virtualHeight))
        let snappedGroupPoint = SnapUtils.applySnap(Point(x: groupBox.x, y: groupBox.y), diffToOthers, diffWithin)
        let groupDelta = CGPoint(x: snappedGroupPoint.x - groupBox.x, y: snappedGroupPoint.y - groupBox.y)

        if abs(groupDelta.x) >= 1 || abs(groupDelta.y) >= 1 {
            isAdjusting = true
            for id in clusterIDs {
                if let w = idToWindow[id] {
                    let origin = w.frame.origin
                    // CRITICAL FIX: Y-axis inversion for AppKit coordinates
                    // groupDelta is in top-left space, NSWindow uses bottom-left
                    // Must negate Y to convert coordinate systems
                    w.setFrameOrigin(NSPoint(
                        x: origin.x + groupDelta.x,
                        y: origin.y - groupDelta.y  // Negate Y for AppKit
                    ))
                }
            }
            isAdjusting = false
        }

        // Update last origins for all tracked windows to current
        for (_, tracked) in windows {
            if let w = tracked.window {
                lastOrigins[ObjectIdentifier(w)] = w.frame.origin
            }
        }
    }

    // Determine if two boxes are connected (snapped) according to snap rules
    private func boxesAreConnected(_ a: Box, _ b: Box) -> Bool {
        // Connected vertically (stacked) when x overlaps and edges near
        if SnapUtils.overlapX(a, b) {
            if SnapUtils.near(SnapUtils.top(a), SnapUtils.bottom(b)) { return true }
            if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.top(b)) { return true }
            if SnapUtils.near(SnapUtils.top(a), SnapUtils.top(b)) { return true }
            if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.bottom(b)) { return true }
        }
        // Connected horizontally (side-by-side) when y overlaps and edges near
        if SnapUtils.overlapY(a, b) {
            if SnapUtils.near(SnapUtils.left(a), SnapUtils.right(b)) { return true }
            if SnapUtils.near(SnapUtils.right(a), SnapUtils.left(b)) { return true }
            if SnapUtils.near(SnapUtils.left(a), SnapUtils.left(b)) { return true }
            if SnapUtils.near(SnapUtils.right(a), SnapUtils.right(b)) { return true }
        }
        return false
    }

    private func connectedCluster(start: ObjectIdentifier, boxes: [ObjectIdentifier: Box]) -> Set<ObjectIdentifier> {
        var visited: Set<ObjectIdentifier> = []
        var stack: [ObjectIdentifier] = [start]
        while let id = stack.popLast() {
            if visited.contains(id) { continue }
            visited.insert(id)
            guard let box = boxes[id] else { continue }
            for (otherID, otherBox) in boxes where otherID != id {
                if !visited.contains(otherID) && boxesAreConnected(box, otherBox) {
                    stack.append(otherID)
                }
            }
        }
        return visited
    }
}
