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
            ZStack {
                // ALWAYS create WebView - it must exist to send 'ready' message
                ButterchurnWebView(bridge: bridge)

                // Overlay loading/error state (fades when ready)
                if !bridge.isReady {
                    if let error = bridge.errorMessage {
                        fallbackView(message: error)
                    } else {
                        fallbackView(message: "Loading...")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: bridge.isReady)
        }
        .onAppear {
            // Configure bridge with audioPlayer for Phase 3 audio data
            bridge.configure(audioPlayer: audioPlayer)
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
