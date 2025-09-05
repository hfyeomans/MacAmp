import SwiftUI

@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var dockingController = DockingController()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
                .environmentObject(dockingController)
        }

        // Legacy auxiliary windows kept for debugging only (may be removed later)
        // WindowGroup("Playlist", id: "playlistWindow") { ... }
        // WindowGroup("Equalizer", id: "equalizerWindow") { ... }

        .commands {
            AppCommands(dockingController: dockingController)
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
