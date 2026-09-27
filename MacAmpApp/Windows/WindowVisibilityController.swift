import AppKit
import Observation

/// Controls show/hide/toggle for all MacAmp windows and tracks observable visibility state.
@MainActor
@Observable
final class WindowVisibilityController {
    private let registry: WindowRegistry
    private let settings: AppSettings

    /// Persisted in AppSettings so the open/closed state survives relaunch.
    var isEQWindowVisible: Bool {
        get { settings.showEqualizerWindow }
        set { settings.showEqualizerWindow = newValue }
    }
    var isPlaylistWindowVisible: Bool {
        get { settings.showPlaylistWindow }
        set { settings.showPlaylistWindow = newValue }
    }
    var isMainWindowVisible: Bool = true

    init(registry: WindowRegistry, settings: AppSettings) {
        self.registry = registry
        self.settings = settings
    }

    // MARK: - Key Window Actions

    func minimizeKeyWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    // MARK: - EQ Window

    func showEQWindow(makeKey: Bool = false) {
        if makeKey {
            registry.eqWindow?.makeKeyAndOrderFront(nil)
        } else {
            registry.eqWindow?.orderFront(nil)
        }
        isEQWindowVisible = true
    }

    func hideEQWindow() {
        registry.eqWindow?.orderOut(nil)
        isEQWindowVisible = false
    }

    func toggleEQWindowVisibility() -> Bool {
        guard let eq = registry.eqWindow else { return false }
        if eq.isVisible {
            eq.orderOut(nil)
            isEQWindowVisible = false
            return false
        } else {
            eq.orderFront(nil)
            isEQWindowVisible = true
            return true
        }
    }

    var isEQWindowCurrentlyVisible: Bool {
        registry.eqWindow?.isVisible ?? false
    }

    // MARK: - Playlist Window

    func showPlaylistWindow(makeKey: Bool = false) {
        if makeKey {
            registry.playlistWindow?.makeKeyAndOrderFront(nil)
        } else {
            registry.playlistWindow?.orderFront(nil)
        }
        isPlaylistWindowVisible = true
    }

    func hidePlaylistWindow() {
        registry.playlistWindow?.orderOut(nil)
        isPlaylistWindowVisible = false
    }

    func togglePlaylistWindowVisibility() -> Bool {
        guard let playlist = registry.playlistWindow else { return false }
        if playlist.isVisible {
            playlist.orderOut(nil)
            isPlaylistWindowVisible = false
            return false
        } else {
            playlist.orderFront(nil)
            isPlaylistWindowVisible = true
            return true
        }
    }

    var isPlaylistWindowCurrentlyVisible: Bool {
        registry.playlistWindow?.isVisible ?? false
    }

    // MARK: - Menu Command Integration

    func showMain() {
        registry.mainWindow?.makeKeyAndOrderFront(nil)
        isMainWindowVisible = true
    }

    func hideMain() {
        registry.mainWindow?.orderOut(nil)
        isMainWindowVisible = false
    }

    func toggleMain() {
        if isMainWindowVisible { hideMain() } else { showMain() }
    }

    func showVideo() {
        AppLog.debug(.window, "showVideo() called")
        registry.videoWindow?.makeKeyAndOrderFront(nil)
    }

    func hideVideo() {
        AppLog.debug(.window, "hideVideo() called")
        registry.videoWindow?.orderOut(nil)
    }

    func showMilkdrop() {
        AppLog.debug(.window, "showMilkdrop() called, window exists: \(registry.milkdropWindow != nil)")
        registry.milkdropWindow?.makeKeyAndOrderFront(nil)
        AppLog.debug(.window, "milkdropWindow.isVisible: \(registry.milkdropWindow?.isVisible ?? false)")
    }

    func hideMilkdrop() {
        AppLog.debug(.window, "hideMilkdrop() called")
        registry.milkdropWindow?.orderOut(nil)
    }

    // MARK: - Batch Operations

    func showAllWindows() {
        registry.mainWindow?.makeKeyAndOrderFront(nil)
        isMainWindowVisible = true
        if settings.showEqualizerWindow {
            registry.eqWindow?.orderFront(nil)
        }
        if settings.showPlaylistWindow {
            registry.playlistWindow?.orderFront(nil)
        }

        if settings.showVideoWindow {
            registry.videoWindow?.orderFront(nil)
        }
        if settings.showMilkdropWindow {
            registry.milkdropWindow?.orderFront(nil)
        }

        focusAllWindows()
    }

    func focusAllWindows() {
        [registry.mainWindow, registry.eqWindow, registry.playlistWindow,
         registry.videoWindow, registry.milkdropWindow].forEach { window in
            if let contentView = window?.contentView {
                window?.makeFirstResponder(contentView)
            }
        }
    }
}
