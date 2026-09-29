import SwiftUI

struct PlaylistResizeHandle: View {
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    @Bindable var sizeState: PlaylistWindowSizeState
    @Binding var dragStartSize: Size2D?
    @Binding var isDragging: Bool
    let resizePreview: WindowResizePreviewOverlay
    /// The shade strip's grip: resizes the width only and keeps the strip height.
    var widthOnly = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: widthOnly ? 9 : 20, height: widthOnly ? 9 : 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartSize == nil {
                            dragStartSize = sizeState.size
                            isDragging = true
                            WindowSnapManager.shared.beginProgrammaticAdjustment()
                        }

                        guard let baseSize = dragStartSize else { return }

                        let widthDelta = Int(round(value.translation.width / PlaylistWindowSizeState.segmentWidth))
                        let heightDelta = widthOnly ? 0 : Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let candidate = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        if let coordinator = WindowCoordinator.shared {
                            var previewPixels = candidate.toPixels()
                            if widthOnly { previewPixels.height = WinampSizes.playlistShade.height }
                            coordinator.showPlaylistResizePreview(resizePreview, previewSize: previewPixels)
                        }
                    }
                    .onEnded { value in
                        guard let baseSize = dragStartSize else { return }

                        let widthDelta = Int(round(value.translation.width / PlaylistWindowSizeState.segmentWidth))
                        let heightDelta = widthOnly ? 0 : Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let finalSize = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        sizeState.size = finalSize

                        if let coordinator = WindowCoordinator.shared {
                            var pixels = sizeState.pixelSize
                            if widthOnly { pixels.height = WinampSizes.playlistShade.height }
                            coordinator.updatePlaylistWindowSize(to: pixels)
                            coordinator.hidePlaylistResizePreview(resizePreview)
                        }

                        isDragging = false
                        dragStartSize = nil
                        WindowSnapManager.shared.endProgrammaticAdjustment()
                    }
            )
            // A drag cut off by the handle disappearing (e.g. a shade toggle) must close its bracket.
            .onDisappear {
                guard dragStartSize != nil else { return }
                dragStartSize = nil
                isDragging = false
                WindowCoordinator.shared?.hidePlaylistResizePreview(resizePreview)
                WindowSnapManager.shared.endProgrammaticAdjustment()
            }
            // Shade grip: Webamp's `right: 20px; top: 3px`.
            .position(x: widthOnly ? windowWidth - 24.5 : windowWidth - 10,
                      y: widthOnly ? 7.5 : windowHeight - 10)
    }
}
