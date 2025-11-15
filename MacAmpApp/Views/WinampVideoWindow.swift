import SwiftUI

/// Video Window - VIDEO.bmp skinned chrome with video playback area
struct WinampVideoWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer

    // Video window size state (segment-based resizing)
    @State private var sizeState = VideoWindowSizeState()
    @State private var dragPreviewSize: Size2D?  // Preview during resize drag

    var body: some View {
        let hasVideo = skinManager.currentSkin?.hasVideoSprites ?? false

        Group {
            if hasVideo {
                // Skinned chrome using VIDEO.bmp sprites with dynamic sizing
                VideoWindowChromeView(content: {
                    // Content area - video player or placeholder
                    if audioPlayer.currentMediaType == .video,
                       let player = audioPlayer.videoPlayer {
                        // Show video player
                        AVPlayerViewRepresentable(player: player)
                    } else {
                        // No video loaded
                        ZStack {
                            Color.black

                            Text("No video loaded")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }, sizeState: sizeState, dragPreviewSize: $dragPreviewSize)
            } else {
                // Fallback chrome when VIDEO.bmp not available
                VideoWindowFallbackChrome(content: {
                    ZStack {
                        Color.black

                        Text("Video Window (No VIDEO.bmp)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }, sizeState: sizeState)
            }
        }
        .frame(
            width: sizeState.pixelSize.width,
            height: sizeState.pixelSize.height,
            alignment: .topLeading
        )
        .fixedSize()
        .background(Color.black)
        .overlay(alignment: .topLeading) {
            // Resize preview overlay - extends beyond current window bounds
            if let previewSize = dragPreviewSize {
                let previewPixels = previewSize.toVideoPixels()
                Rectangle()
                    .strokeBorder(Color.cyan, lineWidth: 3)
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: previewPixels.width, height: previewPixels.height)
                    .allowsHitTesting(false)  // Don't intercept clicks
            }
        }
        .onAppear {
            // Initial NSWindow frame sync with integral coordinates
            if let coordinator = WindowCoordinator.shared {
                let clampedSize = CGSize(
                    width: round(sizeState.pixelSize.width),
                    height: round(sizeState.pixelSize.height)
                )
                coordinator.updateVideoWindowSize(to: clampedSize)
            }
        }
        // NOTE: onChange removed - NSWindow sync happens in resize gesture onEnded
        // This prevents calling setFrame() on every size change during drag (jitter source)
    }
}

/// Fallback chrome when VIDEO.bmp missing from skin
/// Uses classic Winamp style (dark gray with beveled edges)
struct VideoWindowFallbackChrome<Content: View>: View {
    @ViewBuilder let content: Content
    let sizeState: VideoWindowSizeState

    private var pixelSize: CGSize {
        sizeState.pixelSize
    }

    private var contentSize: CGSize {
        sizeState.contentSize
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(red: 0.16, green: 0.16, blue: 0.20)
                .frame(width: pixelSize.width, height: pixelSize.height)

            // Draggable titlebar with classic Winamp gradient
            WinampTitlebarDragHandle(windowKind: .video, size: CGSize(width: pixelSize.width, height: 20)) {
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.0, blue: 0.5),
                        Color(red: 0.0, green: 0.5, blue: 0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: pixelSize.width, height: 20)
                .overlay(
                    Text("WINAMP VIDEO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )
            }
            .position(x: pixelSize.width / 2, y: 10)

            // Content area (dynamic size)
            content
                .frame(width: contentSize.width, height: contentSize.height)
                .position(x: pixelSize.width / 2, y: 20 + contentSize.height / 2)

            // Bottom bar with classic style
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                .frame(width: pixelSize.width, height: 38)
                .overlay(
                    Text("No VIDEO.bmp - Using Fallback")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                )
                .position(x: pixelSize.width / 2, y: pixelSize.height - 19)

            // Left/right borders (dynamic height)
            Rectangle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.30))
                .frame(width: 11, height: contentSize.height)
                .position(x: 5.5, y: 20 + contentSize.height / 2)

            Rectangle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.30))
                .frame(width: 8, height: contentSize.height)
                .position(x: pixelSize.width - 4, y: 20 + contentSize.height / 2)
        }
        .frame(width: pixelSize.width, height: pixelSize.height)
    }
}
