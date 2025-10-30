import SwiftUI

@main
struct MacAmpApp: App {
    @StateObject private var skinManager = SkinManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
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
            AppCommands(dockingController: dockingController, audioPlayer: audioPlayer)
            SkinsCommands(skinManager: skinManager)
        }
    }
}
