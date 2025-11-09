import SwiftUI

/// SwiftUI view that wraps titlebar content and makes it draggable using custom drag
/// This replaces WindowDragGesture() with our custom magnetic snapping drag implementation
///
/// CRITICAL FIX (Oracle): Explicit size parameter prevents layout regression
/// - ZStack must have explicit frame matching sprite size (275×14)
/// - TitlebarDragCaptureView needs same frame to be hit-testable
/// - Top-leading alignment preserves .at() positioning from parent
struct WinampTitlebarDragHandle<Content: View>: View {
    let windowKind: WindowKind
    let size: CGSize
    let content: Content

    init(windowKind: WindowKind, size: CGSize, @ViewBuilder content: () -> Content) {
        self.windowKind = windowKind
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Underlying drag capture layer - MUST have explicit frame to be hit-testable
            TitlebarDragCaptureView(windowKind: windowKind)
                .frame(width: size.width, height: size.height)

            // Visible content (titlebar sprite, etc.)
            // Frame ensures content doesn't expand ZStack, allowsHitTesting(false) delegates events to capture view
            content
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .allowsHitTesting(false) // Content doesn't capture events, capture view does
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
