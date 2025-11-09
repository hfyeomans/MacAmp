import AppKit
import SwiftUI
import Observation  // ORACLE CODE QUALITY: Required for @Observable

@MainActor
@Observable
final class WindowCoordinator {
    static var shared: WindowCoordinator!  // Initialized in MacAmpApp.init()

    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController

    // ORACLE BLOCKING ISSUE #2 FIX: Retain delegate multiplexers
    // NOTE: These will be added in Phase 3 (Day 11-12) when WindowDelegateMultiplexer is created
    // NSWindow.delegate is weak - must store multiplexers or they deallocate!
    // For now (Phase 1A), we don't use delegates yet - this comes in Phase 2-3
    // TODO PHASE 3: Uncomment these properties when creating WindowDelegateMultiplexer
    // private var mainDelegateMultiplexer: WindowDelegateMultiplexer?
    // private var eqDelegateMultiplexer: WindowDelegateMultiplexer?
    // private var playlistDelegateMultiplexer: WindowDelegateMultiplexer?

    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    var playlistWindow: NSWindow? { playlistController.window }

    init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator) {
        // Create Main window with environment injection
        mainController = WinampMainWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Create EQ window with environment injection
        eqController = WinampEqualizerWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Create Playlist window with environment injection
        playlistController = WinampPlaylistWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Configure windows (borderless, transparent titlebar)
        configureWindows()

        // Position in default stack
        setDefaultPositions()

        // Show windows
        showAllWindows()
    }

    private func configureWindows() {
        // ORACLE NOTE: Windows already created as borderless in controllers
        // No additional style mask changes needed here
        // This method can be removed or used for other window setup

        // Optional: Additional window configuration
        [mainWindow, eqWindow, playlistWindow].forEach { window in
            window?.level = .normal
            window?.collectionBehavior = [.managed, .participatesInCycle]
        }
    }

    private func setDefaultPositions() {
        // Stack vertically in screen coords
        // Note: NSWindow uses bottom-left origin (not top-left like SwiftUI)
        mainWindow?.setFrameOrigin(NSPoint(x: 100, y: 500))
        eqWindow?.setFrameOrigin(NSPoint(x: 100, y: 384))  // 116px below Main
        playlistWindow?.setFrameOrigin(NSPoint(x: 100, y: 152))  // 232px below EQ
    }

    func showAllWindows() {
        mainWindow?.makeKeyAndOrderFront(nil)
        eqWindow?.orderFront(nil)
        playlistWindow?.orderFront(nil)
    }

    // Menu command integration
    func showMain() { mainWindow?.makeKeyAndOrderFront(nil) }
    func hideMain() { mainWindow?.orderOut(nil) }
    func showEqualizer() { eqWindow?.makeKeyAndOrderFront(nil) }
    func hideEqualizer() { eqWindow?.orderOut(nil) }
    func showPlaylist() { playlistWindow?.makeKeyAndOrderFront(nil) }
    func hidePlaylist() { playlistWindow?.orderOut(nil) }
}
