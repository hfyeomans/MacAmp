import SwiftUI
import AppKit

/// Custom titlebar drag region for borderless windows
/// Allows dragging window by a specific area (typically top 14px)
struct TitlebarDragRegion: View {
    @State private var windowReference: NSWindow?
    @State private var initialWindowOrigin: NSPoint?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())  // Ensure hit-testing works
            .background(
                WindowAccessor { window in
                    if windowReference == nil {
                        windowReference = window
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value)
                    }
                    .onEnded { _ in
                        endDrag()
                    }
            )
    }

    private func handleDrag(_ value: DragGesture.Value) {
        guard let window = windowReference else { return }

        // Capture initial window position on first drag event
        if initialWindowOrigin == nil {
            initialWindowOrigin = window.frame.origin
        }

        guard let startOrigin = initialWindowOrigin else { return }

        // Calculate new position from initial + translation
        // Note: NSWindow uses bottom-left origin, SwiftUI uses top-left
        // Y translation is inverted for AppKit coordinate system
        let newOrigin = NSPoint(
            x: startOrigin.x + value.translation.width,
            y: startOrigin.y - value.translation.height  // Flip Y for AppKit
        )

        // Move window (animate: false for smooth dragging)
        window.setFrame(
            NSRect(origin: newOrigin, size: window.frame.size),
            display: true,
            animate: false
        )
    }

    private func endDrag() {
        // Reset for next drag
        initialWindowOrigin = nil
    }
}
