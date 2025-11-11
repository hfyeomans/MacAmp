import AppKit
import Foundation

enum WindowKind: Hashable {
    case main
    case playlist
    case equalizer
    case video      // NEW: Video window (VIDEO.bmp chrome, AVPlayer)
    case milkdrop   // NEW: Milkdrop visualization window (Butterchurn)
}

@MainActor
final class WindowSnapManager: NSObject, NSWindowDelegate {
    static let shared = WindowSnapManager()

    private struct TrackedWindow {
        weak var window: NSWindow?
        let kind: WindowKind
    }

    private struct VirtualScreenSpace {
        let top: CGFloat
        let left: CGFloat
        let bounds: BoundingBox
        let screenBoxes: [Box]
    }

    private var windows: [WindowKind: TrackedWindow] = [:]
    private var lastOrigins: [ObjectIdentifier: NSPoint] = [:]
    private var isAdjusting = false

    // PHASE 4: Public methods to disable snap manager during programmatic resizing
    // Prevents windowDidMove from triggering during double-size transitions
    func beginProgrammaticAdjustment() {
        isAdjusting = true
    }

    func endProgrammaticAdjustment() {
        isAdjusting = false
        // Update lastOrigins for all windows after programmatic adjustment
        for (_, tracked) in windows {
            if let w = tracked.window {
                lastOrigins[ObjectIdentifier(w)] = w.frame.origin
            }
        }
    }

    func register(window: NSWindow, kind: WindowKind) {
        // Set minimum titlebar style and disable tabs for classic look
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        windows[kind] = TrackedWindow(window: window, kind: kind)
        // PHASE 3: Delegate is now set via WindowDelegateMultiplexer in WindowCoordinator
        // This allows multiple delegates to coexist (WindowSnapManager + future custom handlers)
        lastOrigins[ObjectIdentifier(window)] = window.frame.origin
    }

    func clusterKinds(containing kind: WindowKind) -> Set<WindowKind>? {
        guard let (_, idToBox) = buildBoxes() else { return nil }
        guard let targetWindow = windows[kind]?.window else { return nil }
        let targetID = ObjectIdentifier(targetWindow)
        guard idToBox[targetID] != nil else { return nil }

        let clusterIDs = connectedCluster(start: targetID, boxes: idToBox)
        var connectedKinds: Set<WindowKind> = []
        for (candidateKind, tracked) in windows {
            guard let window = tracked.window else { continue }
            if clusterIDs.contains(ObjectIdentifier(window)) {
                connectedKinds.insert(candidateKind)
            }
        }
        return connectedKinds
    }

    func areConnected(_ first: WindowKind, _ second: WindowKind) -> Bool {
        guard let cluster = clusterKinds(containing: first) else { return false }
        return cluster.contains(second)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isAdjusting else { return }
        guard let movedWindow = notification.object as? NSWindow else { return }

        // Determine which tracked kind moved
        guard let movedKind = windows.first(where: { $0.value.window === movedWindow })?.key else { return }

        guard let virtualSpace = makeVirtualSpace() else { return }
        let virtualTop = virtualSpace.top
        let virtualLeft = virtualSpace.left

        func box(for window: NSWindow) -> Box {
            let f = window.frame
            let x = f.origin.x - virtualLeft
            let yTop = virtualTop - (f.origin.y + f.size.height)
            return Box(x: x, y: yTop, width: f.size.width, height: f.size.height)
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

        // Recompute cluster boxes after move, mapping ID to Box
        var clusterIdToBox: [ObjectIdentifier: Box] = [:]
        for id in clusterIDs {
            if let w = idToWindow[id] {
                clusterIdToBox[id] = box(for: w)
            }
        }
        let clusterBoxes = Array(clusterIdToBox.values)
        guard !clusterBoxes.isEmpty else { return }
        let groupBox = SnapUtils.boundingBox(clusterBoxes)

        // Snap the whole cluster to other windows and screen edges
        let otherBoxes = otherIDs.compactMap { idToBox[$0] }
        let diffToOthers = SnapUtils.snapToMany(groupBox, otherBoxes)
        let diffWithin = SnapUtils.snapWithinUnion(groupBox, union: virtualSpace.bounds, regions: virtualSpace.screenBoxes)
        let snappedGroupPoint = SnapUtils.applySnap(Point(x: groupBox.x, y: groupBox.y), diffToOthers, diffWithin)
        let groupDelta = CGPoint(x: snappedGroupPoint.x - groupBox.x, y: snappedGroupPoint.y - groupBox.y)

        if abs(groupDelta.x) >= 1 || abs(groupDelta.y) >= 1 {
            isAdjusting = true
            for id in clusterIDs {
                if let w = idToWindow[id], var b = clusterIdToBox[id] {
                    // GEMINI FIX: Apply delta to box in top-left space
                    b.x += groupDelta.x
                    b.y += groupDelta.y
                    // Convert the new box position back to AppKit coordinates and apply
                    apply(box: b, to: w, virtualTop: virtualTop, virtualLeft: virtualLeft)
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

    // Helper to convert top-left box coordinates back to AppKit bottom-left origin and apply to window
    private func apply(box: Box, to window: NSWindow, virtualTop: CGFloat, virtualLeft: CGFloat) {
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

    // MARK: - Custom Drag Support (Oracle's Solution - Phase 2)

    private struct DragContext {
        let draggedWindowID: ObjectIdentifier
        let clusterIDs: Set<ObjectIdentifier>
        let baseBoxes: [ObjectIdentifier: Box]
        let virtualSpace: VirtualScreenSpace
        var lastInputDelta: CGPoint = .zero
    }

    private var dragContexts: [WindowKind: DragContext] = [:]

    func beginCustomDrag(kind: WindowKind, startPointInScreen _: NSPoint) {
        guard let window = windows[kind]?.window else { return }
        guard let (virtualSpace, idToBox) = buildBoxes() else { return }
        let draggedID = ObjectIdentifier(window)
        guard idToBox[draggedID] != nil else { return }

        // WEBAMP BEHAVIOR: Window-specific cluster logic
        // Main window → drags entire cluster (static)
        // EQ/Playlist → drags only itself (separates from cluster, allows re-snapping)
        let clusterIDs: Set<ObjectIdentifier>
        if kind == .main {
            // Main window: Capture full connected cluster
            clusterIDs = connectedCluster(start: draggedID, boxes: idToBox)
        } else {
            // EQ/Playlist: Move only this window (separates from cluster)
            clusterIDs = [draggedID]
        }

        var baseBoxes: [ObjectIdentifier: Box] = [:]
        for id in clusterIDs {
            if let box = idToBox[id] {
                baseBoxes[id] = box
            }
        }

        dragContexts[kind] = DragContext(
            draggedWindowID: draggedID,
            clusterIDs: clusterIDs,
            baseBoxes: baseBoxes,
            virtualSpace: virtualSpace
        )
    }

    func updateCustomDrag(kind: WindowKind, cumulativeDelta delta: CGPoint) {
        guard var context = dragContexts[kind] else { return }
        guard delta != context.lastInputDelta else { return }

        var idToWindow: [ObjectIdentifier: NSWindow] = [:]
        for (_, tracked) in windows {
            if let window = tracked.window {
                idToWindow[ObjectIdentifier(window)] = window
            }
        }

        guard
            context.baseBoxes[context.draggedWindowID] != nil
        else {
            dragContexts.removeValue(forKey: kind)
            return
        }

        let liveBoxes = boxes(in: context.virtualSpace)
        let otherBoxes = liveBoxes.compactMap { entry -> Box? in
            context.clusterIDs.contains(entry.key) ? nil : entry.value
        }

        let topLeftDelta = CGPoint(x: delta.x, y: -delta.y)

        // P0 FIX (Oracle + Gemini): Snap cluster bounding box, not just dragged window
        // This prevents cluster windows from drifting off-screen
        let clusterBaseBox = SnapUtils.boundingBox(Array(context.baseBoxes.values))
        var translatedGroupBox = clusterBaseBox
        translatedGroupBox.x += topLeftDelta.x
        translatedGroupBox.y += topLeftDelta.y

        let diffToOthers = SnapUtils.snapToMany(translatedGroupBox, otherBoxes)
        let diffWithin = SnapUtils.snapWithinUnion(
            translatedGroupBox,
            union: context.virtualSpace.bounds,
            regions: context.virtualSpace.screenBoxes
        )
        let snappedPoint = SnapUtils.applySnap(
            Point(x: translatedGroupBox.x, y: translatedGroupBox.y),
            diffToOthers,
            diffWithin
        )
        let snapDelta = CGPoint(
            x: snappedPoint.x - translatedGroupBox.x,
            y: snappedPoint.y - translatedGroupBox.y
        )
        let finalDelta = CGPoint(
            x: topLeftDelta.x + snapDelta.x,
            y: topLeftDelta.y + snapDelta.y
        )

        for (id, baseBox) in context.baseBoxes {
            guard let window = idToWindow[id] else { continue }
            var movedBox = baseBox
            movedBox.x += finalDelta.x
            movedBox.y += finalDelta.y

            isAdjusting = true
            apply(
                box: movedBox,
                to: window,
                virtualTop: context.virtualSpace.top,
                virtualLeft: context.virtualSpace.left
            )
            isAdjusting = false
        }

        context.lastInputDelta = delta
        dragContexts[kind] = context
    }

    func endCustomDrag(kind: WindowKind) {
        dragContexts.removeValue(forKey: kind)
        for (_, tracked) in windows {
            if let w = tracked.window {
                lastOrigins[ObjectIdentifier(w)] = w.frame.origin
            }
        }
    }

    private func buildBoxes() -> (VirtualScreenSpace, [ObjectIdentifier: Box])? {
        guard let virtualSpace = makeVirtualSpace() else { return nil }
        return (virtualSpace, boxes(in: virtualSpace))
    }

    private func makeVirtualSpace() -> VirtualScreenSpace? {
        let allScreens = NSScreen.screens
        guard !allScreens.isEmpty else { return nil }

        let virtualTop: CGFloat = allScreens.map { $0.frame.maxY }.max() ?? 0
        let virtualLeft: CGFloat = allScreens.map { $0.frame.minX }.min() ?? 0
        let virtualRight: CGFloat = allScreens.map { $0.frame.maxX }.max() ?? 0
        let virtualBottom: CGFloat = allScreens.map { $0.frame.minY }.min() ?? 0
        let bounds = BoundingBox(width: virtualRight - virtualLeft, height: virtualTop - virtualBottom)
        let screenBoxes = allScreens.map { screen -> Box in
            let visible = screen.visibleFrame
            let x = visible.origin.x - virtualLeft
            let yTop = virtualTop - (visible.origin.y + visible.size.height)
            return Box(x: x, y: yTop, width: visible.size.width, height: visible.size.height)
        }
        return VirtualScreenSpace(top: virtualTop, left: virtualLeft, bounds: bounds, screenBoxes: screenBoxes)
    }

    private func boxes(in space: VirtualScreenSpace) -> [ObjectIdentifier: Box] {
        var idToBox: [ObjectIdentifier: Box] = [:]
        for (_, tracked) in windows {
            if let window = tracked.window {
                idToBox[ObjectIdentifier(window)] = box(for: window, in: space)
            }
        }
        return idToBox
    }

    private func box(for window: NSWindow, in space: VirtualScreenSpace) -> Box {
        let frame = window.frame
        let x = frame.origin.x - space.left
        let yTop = space.top - (frame.origin.y + frame.size.height)
        return Box(x: x, y: yTop, width: frame.size.width, height: frame.size.height)
    }
}
