import SwiftUI

/// Milkdrop Window - Placeholder for Butterchurn visualization
struct WinampMilkdropWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings

    var body: some View {
        ZStack {
            // Black background for visualization area
            Color.black

            // Placeholder text
            VStack {
                Text("Milkdrop Window")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("400 × 300")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Text("Butterchurn visualization will appear here")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .frame(width: 400, height: 300)
    }
}
