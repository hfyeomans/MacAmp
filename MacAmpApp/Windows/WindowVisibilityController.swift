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

    // MARK: - EQ Window

    func showEQWindow(makeKey: Bool = false) {
        isEQWindowVisible = true
        guard !deferWhileMinimized(.equalizer) else { return }
        if makeKey {
            registry.eqWindow?.makeKeyAndOrderFront(nil)
        } else {
            registry.eqWindow?.orderFront(nil)
        }
    }

    func hideEQWindow() {
        registry.eqWindow?.orderOut(nil)
        isEQWindowVisible = false
    }

    func toggleEQWindowVisibility() -> Bool {
        guard let eq = registry.eqWindow else { return false }
        let show = isGroupMinimized ? !isEQWindowVisible : !eq.isVisible
        if show { showEQWindow() } else { hideEQWindow() }
        return show
    }

    var isEQWindowCurrentlyVisible: Bool {
        registry.eqWindow?.isVisible ?? false
    }

    // MARK: - Playlist Window

    func showPlaylistWindow(makeKey: Bool = false) {
        isPlaylistWindowVisible = true
        guard !deferWhileMinimized(.playlist) else { return }
        if makeKey {
            registry.playlistWindow?.makeKeyAndOrderFront(nil)
        } else {
            registry.playlistWindow?.orderFront(nil)
        }
    }

    func hidePlaylistWindow() {
        registry.playlistWindow?.orderOut(nil)
        isPlaylistWindowVisible = false
    }

    func togglePlaylistWindowVisibility() -> Bool {
        guard let playlist = registry.playlistWindow else { return false }
        let show = isGroupMinimized ? !isPlaylistWindowVisible : !playlist.isVisible
        if show { showPlaylistWindow() } else { hidePlaylistWindow() }
        return show
    }

    var isPlaylistWindowCurrentlyVisible: Bool {
        registry.playlistWindow?.isVisible ?? false
    }

    // MARK: - Menu Command Integration

    func showMain() {
        guard let main = registry.mainWindow else { return }
        if main.isMiniaturized {
            main.deminiaturize(nil)
        } else {
            main.makeKeyAndOrderFront(nil)
        }
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
        guard !deferWhileMinimized(.video) else { return }
        registry.videoWindow?.makeKeyAndOrderFront(nil)
    }

    func hideVideo() {
        AppLog.debug(.window, "hideVideo() called")
        registry.videoWindow?.orderOut(nil)
    }

    func showMilkdrop() {
        AppLog.debug(.window, "showMilkdrop() called, window exists: \(registry.milkdropWindow != nil)")
        guard !deferWhileMinimized(.milkdrop) else { return }
        registry.milkdropWindow?.makeKeyAndOrderFront(nil)
        AppLog.debug(.window, "milkdropWindow.isVisible: \(registry.milkdropWindow?.isVisible ?? false)")
    }

    func hideMilkdrop() {
        AppLog.debug(.window, "hideMilkdrop() called")
        registry.milkdropWindow?.orderOut(nil)
    }

    // MARK: - Group Minimize

    /// Windows the group minimize hid; they come back with Main if still open in settings.
    @ObservationIgnored private var minimizedWith: Set<WindowKind> = []
    @ObservationIgnored private var deminiaturizeToken: NotificationCenter.ObservationToken?
    /// Runs after the group returns from the Dock.
    @ObservationIgnored var onGroupRestored: (@MainActor () -> Void)?

    var canMinimizeGroup: Bool {
        guard let main = registry.mainWindow else { return false }
        return main.isVisible && !main.isMiniaturized
    }

    private var isGroupMinimized: Bool { registry.mainWindow?.isMiniaturized == true }

    /// Winamp minimize: one Dock tile (Main's); the other windows hide without changing their open state.
    func minimizeGroup() {
        guard canMinimizeGroup, let main = registry.mainWindow else { return }
        registry.forEachWindow { window, kind in
            guard kind != .main, window.isVisible else { return }
            minimizedWith.insert(kind)
            window.orderOut(nil)
        }
        isMainWindowVisible = false
        main.miniaturize(nil)
    }

    /// Observes Main for any deminiaturize, however Main was minimized.
    func start() {
        guard deminiaturizeToken == nil, let main = registry.mainWindow else { return }
        deminiaturizeToken = NotificationCenter.default.addObserver(of: main, for: .didDeminiaturize) { [weak self] _ in
            self?.restoreMinimizedGroup()
        }
    }

    func stop() {
        if let deminiaturizeToken { NotificationCenter.default.removeObserver(deminiaturizeToken) }
        deminiaturizeToken = nil
    }

    private func restoreMinimizedGroup() {
        isMainWindowVisible = true
        for kind in minimizedWith where isOpen(kind) { registry.window(for: kind)?.orderFront(nil) }
        minimizedWith = []
        onGroupRestored?()
    }

    private func isOpen(_ kind: WindowKind) -> Bool {
        switch kind {
        case .main: true
        case .equalizer: settings.showEqualizerWindow
        case .playlist: settings.showPlaylistWindow
        case .video: settings.showVideoWindow
        case .milkdrop: settings.showMilkdropWindow
        }
    }

    /// While minimized, a window turned on waits to come back with Main.
    private func deferWhileMinimized(_ kind: WindowKind) -> Bool {
        guard isGroupMinimized else { return false }
        minimizedWith.insert(kind)
        return true
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
