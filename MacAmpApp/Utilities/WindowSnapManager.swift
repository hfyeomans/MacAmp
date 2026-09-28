import AppKit

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
        /// The menu-bar strip (frame top to visible top) of each display that has one.
        let menuBarStrips: [Box]
    }

    private var windows: [WindowKind: TrackedWindow] = [:]
    private var lastFrames: [ObjectIdentifier: NSRect] = [:]
    private var isAdjusting = false
    /// Nesting depth of `begin/endProgrammaticAdjustment`; callers may bracket code that brackets again.
    private var programmaticDepth = 0

    // Public methods to disable snap manager during programmatic resizing
    func beginProgrammaticAdjustment() {
        programmaticDepth += 1
    }

    func endProgrammaticAdjustment() {
        programmaticDepth = max(0, programmaticDepth - 1)
        if programmaticDepth == 0 { recordFrames() }
    }

    private func recordFrames() {
        for (_, tracked) in windows {
            if let w = tracked.window {
                lastFrames[ObjectIdentifier(w)] = w.frame
            }
        }
    }

    func register(window: NSWindow, kind: WindowKind) {
        windows[kind] = TrackedWindow(window: window, kind: kind)
        // Delegate is set via WindowDelegateMultiplexer in WindowCoordinator
        lastFrames[ObjectIdentifier(window)] = window.frame
    }

    func clusterKinds(containing kind: WindowKind) -> Set<WindowKind>? {
        guard let (_, idToBox) = buildBoxes() else { return nil }
        guard let targetWindow = windows[kind]?.window else { return nil }
        let targetID = ObjectIdentifier(targetWindow)
        guard idToBox[targetID] != nil else { return nil }

        let clusterIDs = DockGraph.cluster(from: targetID, boxes: idToBox)
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
        guard !isAdjusting, programmaticDepth == 0 else { return }
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

        // A move caused by a size change (shade/unshade keeps the top edge) is handled in windowDidResize.
        let lastFrame = lastFrames[movedID] ?? moved.frame
        guard lastFrame.size == moved.frame.size else { return }
        let currentOrigin = moved.frame.origin
        let userDelta = NSPoint(x: currentOrigin.x - lastFrame.origin.x, y: currentOrigin.y - lastFrame.origin.y)
        guard abs(userDelta.x) >= 1 || abs(userDelta.y) >= 1 else { return }

        // Build mapping from window -> box (ONLY for visible windows)
        var idToWindow: [ObjectIdentifier: NSWindow] = [:]
        var idToBox: [ObjectIdentifier: Box] = [:]
        for (_, tracked) in windows {
            if let w = tracked.window, w.isVisible {  // FIX: Skip invisible windows
                let id = ObjectIdentifier(w)
                idToWindow[id] = w
                idToBox[id] = box(for: w)
            }
        }

        // Find connected cluster including the moved window
        let clusterIDs = DockGraph.cluster(from: movedID, boxes: idToBox)
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

        recordFrames()
    }

    /// Shade/unshade (and other top-anchored height changes) of Main, EQ or Playlist: move the
    /// windows docked below by the same amount so the chain stays attached.
    func windowDidResize(_ notification: Notification) {
        guard !isAdjusting, programmaticDepth == 0, let resized = notification.object as? NSWindow,
              let kind = windows.first(where: { $0.value.window === resized })?.key else { return }
        defer { recordFrames() }
        guard kind == .main || kind == .equalizer || kind == .playlist else { return }
        let resizedID = ObjectIdentifier(resized)
        guard let old = lastFrames[resizedID], let space = makeVirtualSpace() else { return }
        let new = resized.frame
        guard abs(new.width - old.width) < 1, abs(new.maxY - old.maxY) < 1,
              abs(new.height - old.height) >= 1 else { return }

        let below = DockGraph.dockedBelow(resizedID, oldBox: box(for: old, in: space),
                                          boxes: boxes(in: space, includeHidden: true))
        let dy = new.minY - old.minY
        isAdjusting = true
        for (_, tracked) in windows {
            guard let w = tracked.window, below.contains(ObjectIdentifier(w)) else { continue }
            w.setFrameOrigin(NSPoint(x: w.frame.origin.x, y: w.frame.origin.y + dy))
        }
        isAdjusting = false
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

    // MARK: - Custom Drag Support

    private struct DragContext {
        let draggedWindowID: ObjectIdentifier
        let clusterIDs: Set<ObjectIdentifier>
        let baseBoxes: [ObjectIdentifier: Box]
        let virtualSpace: VirtualScreenSpace
        let snapping: Bool
        var lastInputDelta: CGPoint = .zero
    }

    private var dragContexts: [WindowKind: DragContext] = [:]

    func beginCustomDrag(kind: WindowKind, startPointInScreen _: NSPoint) {
        guard let window = windows[kind]?.window, let virtualSpace = makeVirtualSpace() else { return }
        let draggedID = ObjectIdentifier(window)
        // Closed windows keep their saved frame and still link the chain, so they move with the group.
        let idToBox = boxes(in: virtualSpace, includeHidden: true)
        guard idToBox[draggedID] != nil else { return }

        // Winamp: Main drags its docked group; other windows drag alone (detach).
        // Shift at mouse-down turns snapping off for this drag, and Main then moves alone.
        let snapping = !NSEvent.modifierFlags.contains(.shift)
        let clusterIDs: Set<ObjectIdentifier> = (kind == .main && snapping)
            ? DockGraph.cluster(from: draggedID, boxes: idToBox)
            : [draggedID]

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
            virtualSpace: virtualSpace,
            snapping: snapping
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

        // Snap cluster bounding box, not just dragged window (prevents off-screen drift)
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
        let snapDelta = context.snapping ? CGPoint(
            x: snappedPoint.x - translatedGroupBox.x,
            y: snappedPoint.y - translatedGroupBox.y
        ) : .zero
        var finalDelta = CGPoint(
            x: topLeftDelta.x + snapDelta.x,
            y: topLeftDelta.y + snapDelta.y
        )
        // Keep the group out of the menu-bar strip: macOS pushes any window whose top enters it
        // back down on its own, which splits the group.
        let groupTop = clusterBaseBox.y + finalDelta.y
        let groupCenterX = clusterBaseBox.x + finalDelta.x + clusterBaseBox.width / 2
        if let strip = context.virtualSpace.menuBarStrips.first(where: {
            groupCenterX >= SnapUtils.left($0) && groupCenterX <= SnapUtils.right($0)
                && groupTop < SnapUtils.bottom($0) && groupTop >= SnapUtils.top($0) - SnapUtils.SNAP_DISTANCE
        }) {
            finalDelta.y += SnapUtils.bottom(strip) - groupTop
        }

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
        recordFrames()
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
        let menuBarStrips = allScreens.compactMap { screen -> Box? in
            let inset = screen.frame.maxY - screen.visibleFrame.maxY
            guard inset > 0 else { return nil }
            return Box(x: screen.frame.minX - virtualLeft, y: virtualTop - screen.frame.maxY,
                       width: screen.frame.width, height: inset)
        }
        return VirtualScreenSpace(top: virtualTop, left: virtualLeft, bounds: bounds,
                                  screenBoxes: screenBoxes, menuBarStrips: menuBarStrips)
    }

    /// Snapping targets visible windows only; docking chains may include closed windows.
    private func boxes(in space: VirtualScreenSpace, includeHidden: Bool = false) -> [ObjectIdentifier: Box] {
        var idToBox: [ObjectIdentifier: Box] = [:]
        for (_, tracked) in windows {
            if let window = tracked.window, includeHidden || window.isVisible {
                idToBox[ObjectIdentifier(window)] = box(for: window.frame, in: space)
            }
        }
        return idToBox
    }

    private func box(for frame: NSRect, in space: VirtualScreenSpace) -> Box {
        let x = frame.origin.x - space.left
        let yTop = space.top - (frame.origin.y + frame.size.height)
        return Box(x: x, y: yTop, width: frame.size.width, height: frame.size.height)
    }
}
