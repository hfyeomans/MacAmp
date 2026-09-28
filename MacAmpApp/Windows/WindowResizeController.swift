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
        guard let video = registry.videoWindow else { return }

        var frame = video.frame
        guard frame.size != pixelSize else { return }

        AppLog.debug(.window, "[VIDEO RESIZE] Before: Frame: \(frame), Origin: (\(frame.origin.x), \(frame.origin.y)), Size: \(frame.size), ContentView: \(video.contentView?.frame ?? .zero)")

        frame = topLeftAnchoredFrame(from: frame, newSize: pixelSize)

        WindowSnapManager.shared.beginProgrammaticAdjustment()
        video.setFrame(frame, display: true)
        WindowSnapManager.shared.endProgrammaticAdjustment()

        AppLog.debug(.window, "[VIDEO RESIZE] After: Frame: \(video.frame), Origin: (\(video.frame.origin.x), \(video.frame.origin.y)), Size: \(video.frame.size)")
    }

    func updateMilkdropWindowSize(to pixelSize: CGSize) {
        guard let milkdrop = registry.milkdropWindow else { return }

        var frame = milkdrop.frame
        guard frame.size != pixelSize else { return }

        let roundedSize = CGSize(
            width: round(pixelSize.width),
            height: round(pixelSize.height)
        )

        frame = topLeftAnchoredFrame(from: frame, newSize: roundedSize)

        WindowSnapManager.shared.beginProgrammaticAdjustment()
        milkdrop.setFrame(frame, display: true)
        WindowSnapManager.shared.endProgrammaticAdjustment()

        AppLog.debug(.window, "[MILKDROP RESIZE] size: \(roundedSize), frame: \(frame)")
    }

    func updatePlaylistWindowSize(to pixelSize: CGSize) {
        guard let playlist = registry.playlistWindow else { return }

        var frame = playlist.frame
        guard frame.size != pixelSize else { return }

        frame = topLeftAnchoredFrame(from: frame, newSize: pixelSize)

        WindowSnapManager.shared.beginProgrammaticAdjustment()
        playlist.setFrame(frame, display: true)
        WindowSnapManager.shared.endProgrammaticAdjustment()

        AppLog.debug(.window, "[PLAYLIST RESIZE] size: \(pixelSize), frame: \(frame)")
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
