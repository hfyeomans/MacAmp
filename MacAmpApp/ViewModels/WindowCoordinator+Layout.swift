import AppKit
import Observation

/// Layout, initialization, and presentation logic for WindowCoordinator.
/// Separated as an extension to keep the main facade file focused on composition and forwarding.
extension WindowCoordinator {
    enum LayoutDefaults {
        static let stackX: CGFloat = 100
        static let mainY: CGFloat = 500
    }

    // MARK: - Window Configuration

    func configureWindows() {
        [mainWindow, eqWindow, playlistWindow, videoWindow, milkdropWindow].forEach { window in
            window?.level = .normal
            window?.collectionBehavior = [.managed, .participatesInCycle]
        }
    }

    // MARK: - Initial Layout

    func applyInitialWindowLayout() {
        setDefaultPositions()
        _ = framePersistence.applyPersistedWindowPositions()
        framePersistence.persistAllWindowFrames()
    }

    func setDefaultPositions() {
        framePersistence.performWithoutPersistence {
            let x = LayoutDefaults.stackX
            let mainY = LayoutDefaults.mainY

            mainWindow?.setFrameOrigin(NSPoint(x: x, y: mainY))

            if let eqHeight = eqWindow?.frame.size.height {
                eqWindow?.setFrameOrigin(NSPoint(x: x, y: mainY - eqHeight))
            }

            if let eqY = eqWindow?.frame.origin.y,
               let playlistHeight = playlistWindow?.frame.size.height {
                playlistWindow?.setFrameOrigin(NSPoint(x: x, y: eqY - playlistHeight))
            }

            if let playlistY = playlistWindow?.frame.origin.y,
               let videoHeight = videoWindow?.frame.size.height {
                videoWindow?.setFrameOrigin(NSPoint(x: x, y: playlistY - videoHeight))
            }

            if let videoY = videoWindow?.frame.origin.y,
               let milkdropHeight = milkdropWindow?.frame.size.height {
                milkdropWindow?.setFrameOrigin(NSPoint(x: x, y: videoY - milkdropHeight))
            }
        }

        AppLog.debug(.window, "Default positions set (should be touching with 0 spacing):")
        if let main = mainWindow { AppLog.debug(.window, "  Main: \(main.frame)") }
        if let eq = eqWindow { AppLog.debug(.window, "  EQ: \(eq.frame)") }
        if let playlist = playlistWindow { AppLog.debug(.window, "  Playlist: \(playlist.frame)") }
        if let video = videoWindow { AppLog.debug(.window, "  Video: \(video.frame)") }
        if let milkdrop = milkdropWindow { AppLog.debug(.window, "  Milkdrop: \(milkdrop.frame)") }
    }

    /// Reset windows to default vertical stack (for testing double-size docking)
    func resetToDefaultStack() {
        WindowSnapManager.shared.beginProgrammaticAdjustment()
        framePersistence.beginSuppressingPersistence()

        guard let main = mainWindow, let eq = eqWindow, let playlist = playlistWindow else {
            WindowSnapManager.shared.endProgrammaticAdjustment()
            framePersistence.endSuppressingPersistence()
            return
        }

        let x = LayoutDefaults.stackX

        var mainFrame = main.frame
        mainFrame.origin = NSPoint(x: x, y: LayoutDefaults.mainY)
        main.setFrame(mainFrame, display: true)

        var eqFrame = eq.frame
        eqFrame.origin = NSPoint(x: x, y: mainFrame.origin.y - eqFrame.size.height)
        eq.setFrame(eqFrame, display: true)

        var playlistFrame = playlist.frame
        playlistFrame.origin = NSPoint(x: x, y: eqFrame.origin.y - playlistFrame.size.height)
        playlist.setFrame(playlistFrame, display: true)

        WindowSnapManager.shared.endProgrammaticAdjustment()
        framePersistence.endSuppressingPersistence()
        framePersistence.schedulePersistenceFlush()

        AppLog.debug(.window, "Windows reset to default vertical stack")
        AppLog.debug(.window, "  Main: \(mainFrame)")
        AppLog.debug(.window, "  EQ: \(eqFrame)")
        AppLog.debug(.window, "  Playlist: \(playlistFrame)")
    }

    // MARK: - Presentation

    var canPresentImmediately: Bool {
        if skinManager.isLoading {
            return false
        }
        if skinManager.currentSkin != nil {
            return true
        }
        return skinManager.loadingError != nil
    }

    func presentWindowsWhenReady() {
        if canPresentImmediately {
            presentInitialWindows()
            return
        }
        observeSkinReadiness()
    }

    private func observeSkinReadiness() {
        withObservationTracking {
            _ = self.skinManager.isLoading
            _ = self.skinManager.currentSkin
            _ = self.skinManager.loadingError
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.canPresentImmediately {
                    self.presentInitialWindows()
                } else {
                    self.observeSkinReadiness()
                }
            }
        }
        if canPresentImmediately {
            presentInitialWindows()
        }
    }

    func presentInitialWindows() {
        guard !hasPresentedInitialWindows else { return }
        hasPresentedInitialWindows = true
        NSApp.activate(ignoringOtherApps: true)
        showAllWindows()
    }

    // MARK: - Debug Logging

    func debugLogWindowPositions(step: String) {
        AppLog.debug(.window, step)

        func describe(window: NSWindow?, label: String) {
            guard let window else {
                AppLog.debug(.window, "  \(label): unavailable")
                return
            }
            let frame = window.frame
            AppLog.debug(.window, "  \(label): origin=(x: \(frame.origin.x), y: \(frame.origin.y)) size=(w: \(frame.size.width), h: \(frame.size.height))")
        }

        describe(window: mainWindow, label: "Main")
        describe(window: eqWindow, label: "EQ")
        describe(window: playlistWindow, label: "Playlist")
    }
}
