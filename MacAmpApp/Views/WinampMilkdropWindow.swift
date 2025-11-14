import SwiftUI

/// Milkdrop Window - Audio visualization using Butterchurn
struct WinampMilkdropWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings

    @State private var spectrum: [Float] = []
    @State private var waveform: [Float] = []

    var body: some View {
        MilkdropWindowChromeView {
            // Butterchurn visualization WebView
            ButterchurnWebView(spectrum: $spectrum, waveform: $waveform)
                .frame(minWidth: 100, minHeight: 100)  // Ensure minimum size
                .onAppear {
                    print("🟢 WinampMilkdropWindow: Content area appeared")
                }
                .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                    // Update audio data at ~60fps
                    // TODO: Get FFT data from AudioPlayer (Day 9)
                    // For now, pass empty arrays - Butterchurn will show default animation
                    spectrum = []
                    waveform = []
                }
        }
        .onAppear {
            print("🟢 WinampMilkdropWindow: Window appeared")
        }
    }
}
