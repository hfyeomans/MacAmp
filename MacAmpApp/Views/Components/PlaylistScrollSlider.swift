import SwiftUI

/// Winamp-style playlist scroll slider with gold thumb
/// Follows bridge layer pattern: receives bindings, handles presentation only
///
/// Bridge Contract:
/// - Mechanism: PlaylistManager provides `tracks.count`, `currentIndex`
/// - Bridge: PlaylistWindowSizeState provides `visibleTrackCount`
/// - Bridge: WinampPlaylistWindow owns `@State scrollOffset: Int`
/// - Presentation: This component renders thumb, handles drag
struct PlaylistScrollSlider: View {
    @Binding var scrollOffset: Int  // First visible track index
    let totalTracks: Int
    let visibleTracks: Int

    @Environment(SkinManager.self) private var skinManager

    private let handleWidth: CGFloat = 8
    private let handleHeight: CGFloat = 18

    @State private var isDragging = false

    // MARK: - Computed Properties

    /// Maximum scroll offset (0 when all tracks visible)
    private var maxScrollOffset: Int {
        max(0, totalTracks - visibleTracks)
    }

    /// Current scroll position as fraction (0.0 to 1.0)
    private var scrollPosition: CGFloat {
        guard maxScrollOffset > 0 else { return 0 }
        return CGFloat(scrollOffset) / CGFloat(maxScrollOffset)
    }

    /// Whether slider is disabled (all tracks visible)
    private var isDisabled: Bool {
        totalTracks <= visibleTracks
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height - handleHeight
            let handleOffset = scrollPosition * availableHeight

            ZStack(alignment: .top) {
                // Track (transparent - scroll track is part of PLAYLIST_RIGHT_TILE)
                Color.clear

                // Handle (gold thumb)
                SimpleSpriteImage(
                    isDragging ? "PLAYLIST_SCROLL_HANDLE_SELECTED" : "PLAYLIST_SCROLL_HANDLE",
                    width: handleWidth,
                    height: handleHeight
                )
                .offset(y: handleOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        guard !isDisabled else { return }

                        // Calculate new scroll offset from drag position
                        let newPosition = value.location.y / geometry.size.height
                        let clampedPosition = min(1, max(0, newPosition))
                        scrollOffset = Int(round(clampedPosition * CGFloat(maxScrollOffset)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .frame(width: handleWidth)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var scrollOffset = 0

        var body: some View {
            HStack {
                PlaylistScrollSlider(
                    scrollOffset: $scrollOffset,
                    totalTracks: 50,
                    visibleTracks: 10
                )
                .frame(height: 174)
                .background(Color.black.opacity(0.3))

                Text("Offset: \(scrollOffset)")
            }
            .padding()
            .environment(SkinManager())
        }
    }

    return PreviewWrapper()
}
