import SwiftUI

@main
struct MacAmpApp: App {
    @State private var skinManager = SkinManager()
    @State private var audioPlayer = AudioPlayer()
    @State private var dockingController = DockingController()
    @State private var settings = AppSettings.instance()
    @State private var radioLibrary = RadioStationLibrary()
    @State private var streamPlayer = StreamPlayer()

    // Computed property for PlaybackCoordinator (recreated when audioPlayer changes)
    private var playbackCoordinator: PlaybackCoordinator {
        PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
    }

    var body: some Scene {
        WindowGroup {
            UnifiedDockView()
                .environment(skinManager)
                .environment(audioPlayer)
                .environment(dockingController)
                .environment(settings)
                .environment(radioLibrary)
                .environment(playbackCoordinator)
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
