import SwiftUI
import AppKit

/// NSView that captures drag events and forwards them to WindowSnapManager
/// This is the low-level drag capture component that replaces WindowDragGesture
final class TitlebarDragCaptureNSView: NSView {
    let windowKind: WindowKind
    var initialMouseLocation: NSPoint = .zero
    var isDragging: Bool = false

    init(windowKind: WindowKind) {
        self.windowKind = windowKind
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        // Convert event location to screen coordinates
        let locationInWindow = event.locationInWindow
        let screenLocation = window.convertPoint(toScreen: locationInWindow)

        initialMouseLocation = screenLocation
        isDragging = true

        // Begin custom drag tracking
        WindowSnapManager.shared.beginCustomDrag(kind: windowKind, startPointInScreen: screenLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = self.window else { return }

        // Convert event location to screen coordinates
        let locationInWindow = event.locationInWindow
        let currentScreenLocation = window.convertPoint(toScreen: locationInWindow)

        // Calculate cumulative delta from initial position
        let cumulativeDelta = CGPoint(
            x: currentScreenLocation.x - initialMouseLocation.x,
            y: currentScreenLocation.y - initialMouseLocation.y
        )

        // Update drag (WindowSnapManager will move all windows in cluster with snapping)
        WindowSnapManager.shared.updateCustomDrag(kind: windowKind, cumulativeDelta: cumulativeDelta)
    }

    override func mouseUp(with _: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        // End custom drag tracking
        WindowSnapManager.shared.endCustomDrag(kind: windowKind)
    }
}

/// SwiftUI wrapper for TitlebarDragCaptureNSView
struct TitlebarDragCaptureView: NSViewRepresentable {
    let windowKind: WindowKind

    func makeNSView(context: Context) -> TitlebarDragCaptureNSView {
        TitlebarDragCaptureNSView(windowKind: windowKind)
    }

    func updateNSView(_ nsView: TitlebarDragCaptureNSView, context: Context) {
        // No updates needed
    }
}
