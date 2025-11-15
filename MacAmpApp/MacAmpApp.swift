import SwiftUI

@main
struct MacAmpApp: App {
    @State private var skinManager: SkinManager
    @State private var audioPlayer: AudioPlayer
    @State private var dockingController: DockingController
    @State private var settings: AppSettings
    @State private var radioLibrary: RadioStationLibrary
    @State private var streamPlayer: StreamPlayer
    @State private var playbackCoordinator: PlaybackCoordinator
    @State private var windowFocusState: WindowFocusState

    init() {
        let skinManager = SkinManager()
        let audioPlayer = AudioPlayer()
        let dockingController = DockingController()
        let settings = AppSettings.instance()
        let radioLibrary = RadioStationLibrary()
        let streamPlayer = StreamPlayer()
        let playbackCoordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        _skinManager = State(initialValue: skinManager)
        _audioPlayer = State(initialValue: audioPlayer)
        _dockingController = State(initialValue: dockingController)
        _settings = State(initialValue: settings)
        _radioLibrary = State(initialValue: radioLibrary)
        _streamPlayer = State(initialValue: streamPlayer)
        _playbackCoordinator = State(initialValue: playbackCoordinator)

        // CRITICAL FIX #1: Skin auto-loading (from UnifiedDockView.ensureSkin)
        // Load initial skin before creating windows
        if skinManager.currentSkin == nil {
            skinManager.loadInitialSkin()
        }

        // Create window focus state for all windows
        let windowFocusState = WindowFocusState()
        _windowFocusState = State(initialValue: windowFocusState)

        // PHASE 1A: Initialize WindowCoordinator (creates 3 independent NSWindows)
        // This replaces UnifiedDockView with separate windows
        WindowCoordinator.shared = WindowCoordinator(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )
    }

    var body: some Scene {
        // PHASE 1A: UnifiedDockView replaced by WindowCoordinator
        // 3 independent NSWindows created manually in WindowCoordinator.init()
        // Keep Settings window for preferences
        Settings {
            EmptyView()
        }

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
