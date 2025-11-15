import AppKit

/// AppKit-based resize preview that can extend beyond window bounds
/// Creates a separate overlay window that floats above the resizing window
final class WindowResizePreviewOverlay {
    private var overlayWindow: NSWindow?
    private weak var targetWindow: NSWindow?

    func show(in window: NSWindow, previewSize: CGSize) {
        targetWindow = window

        // Create overlay window if needed
        if overlayWindow == nil {
            print("🔷 Creating overlay window")
            let overlay = NSWindow(
                contentRect: .zero,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            overlay.hasShadow = false
            overlay.level = .floating  // Above normal windows
            overlay.ignoresMouseEvents = true  // Pass through clicks
            overlay.collectionBehavior = [.canJoinAllSpaces, .stationary]

            overlayWindow = overlay
        }

        guard let overlay = overlayWindow else { return }

        // Position overlay at same location as target window, with preview size
        var frame = window.frame
        let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height)
        frame.size = previewSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - previewSize.height)

        overlay.setFrame(frame, display: true, animate: false)

        // Update or create visual content
        if let existingView = overlay.contentView as? PreviewContentView {
            existingView.previewSize = previewSize
        } else {
            let contentView = PreviewContentView(frame: NSRect(origin: .zero, size: previewSize))
            overlay.contentView = contentView
        }

        overlay.orderFront(nil)
        print("🔷 Preview shown at \(frame), size: \(previewSize)")
    }

    func update(previewSize: CGSize) {
        guard let overlay = overlayWindow,
              let target = targetWindow else { return }

        // Update overlay to match new preview size, anchored to target's top-left
        var frame = target.frame
        let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height)
        frame.size = previewSize
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - previewSize.height)

        overlay.setFrame(frame, display: false)
        (overlay.contentView as? PreviewContentView)?.previewSize = previewSize
    }

    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        targetWindow = nil
    }
}

/// Custom NSView that draws the preview rectangle
private final class PreviewContentView: NSView {
    var previewSize: CGSize = .zero {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }  // Match SwiftUI coordinates

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = NSRect(origin: .zero, size: previewSize)

        // Light colored, mostly transparent fill
        NSColor.systemCyan.withAlphaComponent(0.15).setFill()
        rect.fill()

        // Visible stroke
        let path = NSBezierPath(rect: rect.insetBy(dx: 1.5, dy: 1.5))
        path.lineWidth = 3
        NSColor.systemCyan.withAlphaComponent(0.8).setStroke()
        path.stroke()
    }
}
