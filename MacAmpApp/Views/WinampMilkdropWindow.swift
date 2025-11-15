import SwiftUI

/// Milkdrop Window - GEN.bmp chrome foundation
/// Butterchurn visualization deferred (see BUTTERCHURN_BLOCKERS.md)
struct WinampMilkdropWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings

    var body: some View {
        MilkdropWindowChromeView {
            // Placeholder content - Butterchurn deferred
            VStack {
                Text("MILKDROP")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("275 × 232")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.top, 4)

                Text("Visualization: Deferred")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
    }
}
