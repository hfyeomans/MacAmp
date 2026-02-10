import AppKit

/// Manages window frame persistence: save/load positions, suppression during programmatic moves.
@MainActor
final class WindowFramePersistence {
    private let registry: WindowRegistry
    private let windowFrameStore: WindowFrameStore
    private let settings: AppSettings
    private var persistenceSuppressionCount = 0
    @MainActor private var persistenceTask: Task<Void, Never>?
    // swiftlint:disable:next weak_delegate
    private(set) var persistenceDelegate: WindowPersistenceDelegate?  // Intentionally strong: NSWindow.delegate is weak

    init(registry: WindowRegistry, settings: AppSettings, windowFrameStore: WindowFrameStore = WindowFrameStore()) {
        self.registry = registry
        self.settings = settings
        self.windowFrameStore = windowFrameStore
        self.persistenceDelegate = WindowPersistenceDelegate(persistence: self)
    }

    // MARK: - Suppression

    func beginSuppressingPersistence() {
        persistenceSuppressionCount += 1
    }

    func endSuppressingPersistence() {
        persistenceSuppressionCount = max(0, persistenceSuppressionCount - 1)
    }

    func performWithoutPersistence(_ work: () -> Void) {
        beginSuppressingPersistence()
        work()
        endSuppressingPersistence()
    }

    // MARK: - Persistence

    func persistAllWindowFrames() {
        registry.forEachWindow { window, kind in
            windowFrameStore.save(frame: window.frame, for: kind)
        }
    }

    func schedulePersistenceFlush() {
        guard persistenceSuppressionCount == 0 else { return }
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            self?.persistAllWindowFrames()
        }
    }

    func handleWindowGeometryChange(notification: Notification) {
        guard persistenceSuppressionCount == 0 else { return }
        guard let window = notification.object as? NSWindow else { return }
        guard registry.windowKind(for: window) != nil else { return }
        schedulePersistenceFlush()
    }

    // MARK: - Layout Restoration

    @discardableResult
    func applyPersistedWindowPositions() -> Bool {
        beginSuppressingPersistence()
        defer { endSuppressingPersistence() }

        var applied = false
        let scale: CGFloat = settings.isDoubleSizeMode ? 2 : 1

        applied = restoreMainWindow(scale: scale) || applied
        applied = restoreEQWindow(scale: scale) || applied
        applied = restorePlaylistWindow() || applied
        applied = restoreOriginOnly(kind: .video) || applied
        applied = restoreOriginOnly(kind: .milkdrop) || applied

        return applied
    }

    private func restoreMainWindow(scale: CGFloat) -> Bool {
        guard let main = registry.mainWindow,
              let stored = windowFrameStore.frame(for: .main) else { return false }
        var frame = main.frame
        frame.size = CGSize(width: WinampSizes.main.width * scale, height: WinampSizes.main.height * scale)
        frame.origin = stored.origin
        main.setFrame(frame, display: true)
        return true
    }

    private func restoreEQWindow(scale: CGFloat) -> Bool {
        guard let eq = registry.eqWindow,
              let stored = windowFrameStore.frame(for: .equalizer) else { return false }
        var frame = eq.frame
        frame.size = CGSize(width: WinampSizes.equalizer.width * scale, height: WinampSizes.equalizer.height * scale)
        frame.origin = stored.origin
        eq.setFrame(frame, display: true)
        return true
    }

    private func restorePlaylistWindow() -> Bool {
        guard let playlist = registry.playlistWindow,
              var stored = windowFrameStore.frame(for: .playlist) else { return false }
        let clampedWidth = max(PlaylistWindowSizeState.baseWidth, stored.size.width)
        let clampedHeight = max(
            PlaylistWindowSizeState.baseHeight,
            min(LayoutDefaults.playlistMaxHeight, stored.size.height)
        )
        stored.size = CGSize(width: clampedWidth, height: clampedHeight)
        playlist.setFrame(stored, display: true)
        return true
    }

    private func restoreOriginOnly(kind: WindowKind) -> Bool {
        guard let window = registry.window(for: kind),
              let stored = windowFrameStore.frame(for: kind) else { return false }
        var frame = window.frame
        frame.origin = stored.origin
        window.setFrame(frame, display: true)
        return true
    }

    // MARK: - Constants

    enum LayoutDefaults {
        static let playlistMaxHeight: CGFloat = 900
    }
}

// MARK: - WindowPersistenceDelegate

@MainActor
final class WindowPersistenceDelegate: NSObject, NSWindowDelegate {
    weak var persistence: WindowFramePersistence?

    init(persistence: WindowFramePersistence) {
        self.persistence = persistence
    }

    func windowDidMove(_ notification: Notification) {
        persistence?.handleWindowGeometryChange(notification: notification)
    }

    func windowDidResize(_ notification: Notification) {
        persistence?.handleWindowGeometryChange(notification: notification)
    }
}
