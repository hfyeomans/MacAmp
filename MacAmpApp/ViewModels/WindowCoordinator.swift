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

    // Store references for observation/state checks
    private let settings: AppSettings
    private let skinManager: SkinManager

    @ObservationIgnored private var skinPresentationTask: Task<Void, Never>?
    private var hasPresentedInitialWindows = false

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
        // Store shared state references
        self.settings = settings
        self.skinManager = skinManager

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

        // Show windows only after the initial skin has loaded
        presentWindowsWhenReady()

        // CRITICAL FIX #3: Set initial window levels from persisted always-on-top state
        // From UnifiedDockView.swift line 80
        updateWindowLevels(settings.isAlwaysOnTop)

        // CRITICAL FIX #3: Observe always-on-top changes
        // From UnifiedDockView.swift lines 65-68
        // Note: AppSettings is @Observable, so we can track changes
        // Using withObservationTracking for reactive updates
        setupAlwaysOnTopObserver()
    }

    // CRITICAL FIX #3: Always-on-top observer
    // Migrated from UnifiedDockView.swift lines 65-68
    private func setupAlwaysOnTopObserver() {
        // Use Task to observe changes to isAlwaysOnTop
        Task { @MainActor in
            while true {
                // Wait for next change
                try? await Task.sleep(for: .milliseconds(100))

                // Check if always-on-top changed
                updateWindowLevels(settings.isAlwaysOnTop)
            }
        }
    }

    deinit {
        skinPresentationTask?.cancel()
    }

    private func updateWindowLevels(_ alwaysOnTop: Bool) {
        let level: NSWindow.Level = alwaysOnTop ? .floating : .normal
        mainWindow?.level = level
        eqWindow?.level = level
        playlistWindow?.level = level
    }

    private var canPresentImmediately: Bool {
        if skinManager.isLoading {
            return false
        }
        if skinManager.currentSkin != nil {
            return true
        }
        return skinManager.loadingError != nil
    }

    private func presentWindowsWhenReady() {
        if canPresentImmediately {
            presentInitialWindows()
            return
        }

        skinPresentationTask?.cancel()
        skinPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !self.canPresentImmediately {
                try? await Task.sleep(for: .milliseconds(50))
            }
            self.presentInitialWindows()
        }
    }

    private func presentInitialWindows() {
        guard !hasPresentedInitialWindows else { return }
        hasPresentedInitialWindows = true
        NSApp.activate(ignoringOtherApps: true)
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
        focusAllWindows()
    }

    // Menu command integration
    func showMain() { mainWindow?.makeKeyAndOrderFront(nil) }
    func hideMain() { mainWindow?.orderOut(nil) }
    func showEqualizer() { eqWindow?.makeKeyAndOrderFront(nil) }
    func hideEqualizer() { eqWindow?.orderOut(nil) }
    func showPlaylist() { playlistWindow?.makeKeyAndOrderFront(nil) }
    func hidePlaylist() { playlistWindow?.orderOut(nil) }

    private func focusAllWindows() {
        [mainWindow, eqWindow, playlistWindow].forEach { window in
            if let contentView = window?.contentView {
                window?.makeFirstResponder(contentView)
            }
        }
    }
}
