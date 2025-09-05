import SwiftUI

@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            WinampMainWindow()  // NEW: Pixel-perfect Winamp main window
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
                .onAppear {
                    // Load a sample skin. Make sure 'Winamp.wsz' is in your project's Assets folder.
                    // For a real app, you'd have a more robust way to select and load skins.
                    var urlToLoad: URL? = Bundle.main.url(forResource: "Winamp", withExtension: "wsz")
                    #if SWIFT_PACKAGE
                    if urlToLoad == nil {
                        urlToLoad = Bundle.module.url(forResource: "Winamp", withExtension: "wsz")
                    }
                    #endif
                    if let skinURL = urlToLoad {
                        skinManager.loadSkin(from: skinURL)
                    } else {
                        print("Error: Winamp.wsz not found in app bundle. Please add it to your Assets folder.")
                    }
                    // Show auxiliary windows on first launch for easier discovery
                    // TEMPORARILY DISABLE AUTO-OPENING WINDOWS FOR DEBUG
                    /* DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.sendAction(#selector(NSApplication.showPlaylist), to: nil, from: nil)
                        NSApp.sendAction(#selector(NSApplication.showEqualizer), to: nil, from: nil)
                    } */
                }
        }

        WindowGroup("Playlist", id: "playlistWindow") {
            WinampPlaylistWindow()  // NEW: Pixel-perfect Winamp playlist
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        }

        WindowGroup("Equalizer", id: "equalizerWindow") {
            WinampEqualizerWindow()  // NEW: Pixel-perfect Winamp equalizer
                .environmentObject(skinManager) 
                .environmentObject(audioPlayer)
        }

        .commands {
            AppCommands()
        }
    }
}

private extension NSApplication {
    @objc func showPlaylist() {
        NSApp.keyWindow?.windowController?.document // no-op; keep selector
        NSApp.sendAction(#selector(AppCommandsShim.openPlaylist), to: nil, from: nil)
    }
    @objc func showEqualizer() {
        NSApp.sendAction(#selector(AppCommandsShim.openEqualizer), to: nil, from: nil)
    }
}

@objc final class AppCommandsShim: NSObject {
    @objc func openPlaylist() {}
    @objc func openEqualizer() {}
}
