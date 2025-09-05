import SwiftUI

/// Hosts Main, Playlist, and Equalizer panes in a single macOS window.
struct DockingContainerView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var docking: DockingController

    private let interPaneSpacing: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: interPaneSpacing) {
            if docking.showMain {
                WinampMainWindow()
                    .environmentObject(skinManager)
                    .environmentObject(audioPlayer)
            }
            if docking.showPlaylist {
                WinampPlaylistWindow()
                    .environmentObject(skinManager)
                    .environmentObject(audioPlayer)
            }
            if docking.showEqualizer {
                WinampEqualizerWindow()
                    .environmentObject(skinManager)
                    .environmentObject(audioPlayer)
            }
        }
        .background(Color.black)
        .onAppear(perform: loadDefaultSkinIfNeeded)
    }

    private func loadDefaultSkinIfNeeded() {
        if skinManager.currentSkin == nil {
            var urlToLoad: URL? = Bundle.main.url(forResource: "Winamp", withExtension: "wsz")
            #if SWIFT_PACKAGE
            if urlToLoad == nil {
                urlToLoad = Bundle.module.url(forResource: "Winamp", withExtension: "wsz")
            }
            #endif
            if let skinURL = urlToLoad {
                skinManager.loadSkin(from: skinURL)
            }
        }
    }
}

#Preview {
    DockingContainerView()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(DockingController())
}

