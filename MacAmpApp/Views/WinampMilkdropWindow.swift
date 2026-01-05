import SwiftUI

/// Milkdrop Window - GEN.bmp chrome with Butterchurn visualization
/// Visualization only active for local playback (AVAudioEngine)
/// Stream playback shows fallback placeholder
struct WinampMilkdropWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(ButterchurnBridge.self) var bridge

    var body: some View {
        MilkdropWindowChromeView {
            Group {
                if bridge.isReady {
                    // Butterchurn visualization (local playback only)
                    ButterchurnWebView(bridge: bridge)
                } else if let error = bridge.errorMessage {
                    // Initialization failed
                    fallbackView(message: error)
                } else {
                    // Loading state
                    fallbackView(message: "Loading...")
                }
            }
        }
    }

    /// Fallback placeholder when Butterchurn is unavailable
    @ViewBuilder
    private func fallbackView(message: String) -> some View {
        VStack(spacing: 8) {
            Text("MILKDROP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
