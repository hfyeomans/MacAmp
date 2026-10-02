import SwiftUI

@main
struct MacAmpApp: App {
    @State private var skinManager: SkinManager
    @State private var audioPlayer: AudioPlayer
    @State private var settings: AppSettings
    @State private var radioLibrary: RadioStationLibrary
    @State private var streamPlayer: StreamPlayer
    @State private var playbackCoordinator: PlaybackCoordinator
    @State private var windowFocusState: WindowFocusState
    @State private var windowCoordinator: WindowCoordinator

    init() {
        let skinManager = SkinManager()
        let audioPlayer = AudioPlayer()
        let settings = AppSettings.instance()
        let radioLibrary = RadioStationLibrary()
        let streamPlayer = StreamPlayer()
        let playbackCoordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)

        _skinManager = State(initialValue: skinManager)
        _audioPlayer = State(initialValue: audioPlayer)
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

        // Initialize WindowCoordinator (creates separate NSWindows for Main, EQ, Playlist, etc.)
        let coordinator = WindowCoordinator(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator,
            windowFocusState: windowFocusState
        )
        WindowCoordinator.shared = coordinator
        _windowCoordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        // Main windows are NSWindows created by WindowCoordinator

        // ARCHITECTURAL FIX: Provide a "main" SwiftUI Window scene
        // This satisfies SwiftUI's requirement for at least one main scene
        // The actual UI is in NSWindows created by WindowCoordinator
        WindowGroup(id: "main-placeholder") {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .defaultSize(width: 0, height: 0)
        .windowResizability(.contentSize)

        Settings {
            EmptyView()
        }
        // Commands are defined once here and apply to all window groups
        .commands {
            AppCommands(windowCoordinator: windowCoordinator, audioPlayer: audioPlayer, settings: settings, playbackCoordinator: playbackCoordinator)
            SkinsCommands(skinManager: skinManager)
        }
    }
}
