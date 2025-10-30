import SwiftUI

@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(dockingController)
                .environment(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        WindowGroup("Preferences", id: "preferences") {
            PreferencesView()
                .environment(settings)
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
