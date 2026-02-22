import SwiftUI

struct PlaylistResizeHandle: View {
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    @Bindable var sizeState: PlaylistWindowSizeState
    @Binding var dragStartSize: Size2D?
    @Binding var isDragging: Bool
    let resizePreview: WindowResizePreviewOverlay

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20, height: 20)
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
                        let heightDelta = Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let candidate = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        if let coordinator = WindowCoordinator.shared {
                            let previewPixels = candidate.toPlaylistPixels()
                            coordinator.showPlaylistResizePreview(resizePreview, previewSize: previewPixels)
                        }
                    }
                    .onEnded { value in
                        guard let baseSize = dragStartSize else { return }

                        let widthDelta = Int(round(value.translation.width / PlaylistWindowSizeState.segmentWidth))
                        let heightDelta = Int(round(value.translation.height / PlaylistWindowSizeState.segmentHeight))

                        let finalSize = Size2D(
                            width: max(0, baseSize.width + widthDelta),
                            height: max(0, baseSize.height + heightDelta)
                        )

                        sizeState.size = finalSize

                        if let coordinator = WindowCoordinator.shared {
                            coordinator.updatePlaylistWindowSize(to: sizeState.pixelSize)
                            coordinator.hidePlaylistResizePreview(resizePreview)
                        }

                        isDragging = false
                        dragStartSize = nil
                        WindowSnapManager.shared.endProgrammaticAdjustment()
                    }
            )
            .position(x: windowWidth - 10, y: windowHeight - 10)
    }
}
