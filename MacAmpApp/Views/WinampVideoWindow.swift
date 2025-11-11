import SwiftUI

/// Video Window - VIDEO.bmp skinned chrome with video playback area
struct WinampVideoWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings

    var body: some View {
        let hasVideo = skinManager.currentSkin?.hasVideoSprites ?? false

        // Use VIDEO.bmp chrome if available, otherwise fallback
        if hasVideo {
            // Skinned chrome using VIDEO.bmp sprites (registered as VIDEO_* keys)
            VideoWindowChromeView {
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
            }
        } else {
            // Fallback chrome when VIDEO.bmp not available
            VideoWindowFallbackChrome {
                ZStack {
                    Color.black

                    Text("Video Window (No VIDEO.bmp)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 275, height: 232)  // Ensure fallback has same size
        }
    }
}

/// Fallback chrome when VIDEO.bmp missing from skin
/// Uses classic Winamp style (dark gray with beveled edges)
struct VideoWindowFallbackChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(red: 0.16, green: 0.16, blue: 0.20)  // Classic Winamp dark gray
                .frame(width: 275, height: 232)

            // Titlebar with classic Winamp gradient
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.0, blue: 0.5),  // Dark blue
                    Color(red: 0.0, green: 0.5, blue: 0.8)   // Lighter blue
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 275, height: 20)
            .overlay(
                Text("WINAMP VIDEO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            )
            .position(x: 137.5, y: 10)

            // Content area
            content
                .frame(width: 256, height: 174)
                .position(x: 137.5, y: 107)  // Center in content area

            // Bottom bar with classic style
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                .frame(width: 275, height: 38)
                .overlay(
                    Text("No VIDEO.bmp - Using Fallback")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                )
                .position(x: 137.5, y: 213)

            // Left/right borders
            Rectangle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.30))
                .frame(width: 11, height: 174)
                .position(x: 5.5, y: 107)

            Rectangle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.30))
                .frame(width: 8, height: 174)
                .position(x: 271, y: 107)
        }
        .frame(width: 275, height: 232)
    }
}
