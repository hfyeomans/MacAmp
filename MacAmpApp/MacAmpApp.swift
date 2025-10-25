import SwiftUI

@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var dockingController = DockingController()
    @StateObject private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
                .environmentObject(dockingController)
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
                .environmentObject(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Commands are defined once here and apply to all window groups
        .commands {
            AppCommands(dockingController: dockingController, audioPlayer: audioPlayer, settings: settings)
            SkinsCommands(skinManager: skinManager)
        }
    }
}
