import AppKit

/// Manages window resize operations, docking-aware layout, and resize preview overlays.
@MainActor
final class WindowResizeController {
    private let registry: WindowRegistry
    private let persistence: WindowFramePersistence

    init(registry: WindowRegistry, persistence: WindowFramePersistence) {
        self.registry = registry
        self.persistence = persistence
    }

    // MARK: - Top-Left Anchor Helper

    /// Compute a new frame anchored at top-left after resizing.
    /// macOS uses bottom-left origins, so this preserves the visual top-left corner.
    private func topLeftAnchoredFrame(from frame: NSRect, newSize: CGSize) -> NSRect {
        let topLeft = NSPoint(x: round(frame.origin.x), y: round(frame.origin.y + frame.size.height))
        return NSRect(origin: NSPoint(x: topLeft.x, y: topLeft.y - newSize.height), size: newSize)
    }

    // MARK: - Double-Size Resize

    /// Main and EQ scale in place (top-left fixed, shade height kept); every attached window follows.
    func resizeMainAndEQWindows(doubled: Bool, animated _: Bool = true, persistResult: Bool = true) {
        guard let main = registry.mainWindow, let eq = registry.eqWindow else { return }
        // SwiftUI may already have resized Main/EQ (top-left fixed), so sizes come from the scale change, not the frame.
        let (from, to): (CGFloat, CGFloat) = doubled ? (1, 2) : (2, 1)
        func unscaled(_ window: NSWindow, base: CGFloat) -> CGSize {
            let current = max(1, (window.frame.width / base).rounded())
            return CGSize(width: window.frame.width / current, height: window.frame.height / current)
        }
        let unit: [WindowKind: CGSize] = [
            .main: unscaled(main, base: WinampSizes.main.width),
            .equalizer: unscaled(eq, base: WinampSizes.equalizer.width),
        ]
        var boxes: [WindowKind: Box] = [:]
        registry.forEachWindow { window, kind in
            var box = DockGraph.box(for: window.frame)
            if let size = unit[kind] {
                box.width = size.width * from
                box.height = size.height * from
            }
            boxes[kind] = box
        }
        let newSizes = unit.mapValues { CGSize(width: $0.width * to, height: $0.height * to) }
        let after = DockGraph.followResize(boxes: boxes, newSizes: newSizes, order: WindowSnapManager.dockOrder)

        persistence.beginSuppressingPersistence()
        WindowSnapManager.shared.beginProgrammaticAdjustment()
        registry.forEachWindow { window, kind in
            guard let box = after[kind] else { return }
            let frame = DockGraph.frame(for: box)
            if newSizes[kind] != nil {
                window.setFrame(frame, display: true)
            } else if frame.origin != window.frame.origin {
                window.setFrameOrigin(frame.origin)
            }
        }
        WindowSnapManager.shared.endProgrammaticAdjustment()
        persistence.endSuppressingPersistence()
        if persistResult {
            persistence.schedulePersistenceFlush()
        }
    }

    // MARK: - Window Size Updates

    func updateVideoWindowSize(to pixelSize: CGSize) {
        guard let video = registry.videoWindow, video.frame.size != pixelSize else { return }
        resize(.video, to: pixelSize)
        AppLog.debug(.window, "[VIDEO RESIZE] size: \(pixelSize), frame: \(video.frame)")
    }

    func updateMilkdropWindowSize(to pixelSize: CGSize) {
        guard let milkdrop = registry.milkdropWindow, milkdrop.frame.size != pixelSize else { return }
        let roundedSize = CGSize(width: round(pixelSize.width), height: round(pixelSize.height))
        resize(.milkdrop, to: roundedSize)
        AppLog.debug(.window, "[MILKDROP RESIZE] size: \(roundedSize), frame: \(milkdrop.frame)")
    }

    func updatePlaylistWindowSize(to pixelSize: CGSize) {
        guard let playlist = registry.playlistWindow, playlist.frame.size != pixelSize else { return }
        resize(.playlist, to: pixelSize)
        AppLog.debug(.window, "[PLAYLIST RESIZE] size: \(pixelSize), frame: \(playlist.frame)")
    }

    /// Resizes a window top-left anchored; windows attached below or to its right follow.
    private func resize(_ kind: WindowKind, to size: CGSize) {
        guard let window = registry.window(for: kind) else { return }
        var boxes: [WindowKind: Box] = [:]
        registry.forEachWindow { other, otherKind in boxes[otherKind] = DockGraph.box(for: other.frame) }
        let after = DockGraph.followResize(boxes: boxes, newSizes: [kind: size], order: WindowSnapManager.dockOrder)

        WindowSnapManager.shared.beginProgrammaticAdjustment()
        window.setFrame(topLeftAnchoredFrame(from: window.frame, newSize: size), display: true)
        registry.forEachWindow { other, otherKind in
            guard otherKind != kind, let box = after[otherKind] else { return }
            let origin = DockGraph.frame(for: box).origin
            if origin != other.frame.origin { other.setFrameOrigin(origin) }
        }
        WindowSnapManager.shared.endProgrammaticAdjustment()
    }

    // MARK: - Resize Preview Overlays

    func showVideoResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = registry.videoWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    func hideVideoResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }

    func showPlaylistResizePreview(_ overlay: WindowResizePreviewOverlay, previewSize: CGSize) {
        guard let window = registry.playlistWindow else { return }
        overlay.show(in: window, previewSize: previewSize)
    }

    func hidePlaylistResizePreview(_ overlay: WindowResizePreviewOverlay) {
        overlay.hide()
    }
}
