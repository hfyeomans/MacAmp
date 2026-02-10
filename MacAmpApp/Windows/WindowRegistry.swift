import AppKit

/// Owns the 5 NSWindowController instances and provides window lookup by kind.
@MainActor
final class WindowRegistry {
    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController
    private let videoController: NSWindowController
    private let milkdropController: NSWindowController
    private var windowKinds: [ObjectIdentifier: WindowKind] = [:]

    init(
        mainController: NSWindowController,
        eqController: NSWindowController,
        playlistController: NSWindowController,
        videoController: NSWindowController,
        milkdropController: NSWindowController
    ) {
        self.mainController = mainController
        self.eqController = eqController
        self.playlistController = playlistController
        self.videoController = videoController
        self.milkdropController = milkdropController
        mapWindowsToKinds()
    }

    // MARK: - Window Accessors

    var mainWindow: NSWindow? { mainController.window }
    var eqWindow: NSWindow? { eqController.window }
    var playlistWindow: NSWindow? { playlistController.window }
    var videoWindow: NSWindow? { videoController.window }
    var milkdropWindow: NSWindow? { milkdropController.window }

    // MARK: - Window Lookup

    func window(for kind: WindowKind) -> NSWindow? {
        switch kind {
        case .main: return mainWindow
        case .equalizer: return eqWindow
        case .playlist: return playlistWindow
        case .video: return videoWindow
        case .milkdrop: return milkdropWindow
        }
    }

    func windowKind(for window: NSWindow) -> WindowKind? {
        windowKinds[ObjectIdentifier(window)]
    }

    func forEachWindow(_ body: (NSWindow, WindowKind) -> Void) {
        let pairs: [(NSWindow?, WindowKind)] = [
            (mainWindow, .main),
            (eqWindow, .equalizer),
            (playlistWindow, .playlist),
            (videoWindow, .video),
            (milkdropWindow, .milkdrop)
        ]
        for (window, kind) in pairs {
            if let window { body(window, kind) }
        }
    }

    /// Live anchor frame from actual window positions.
    func liveAnchorFrame(_ anchor: WindowKind) -> NSRect? {
        switch anchor {
        case .main: return mainWindow?.frame
        case .equalizer: return eqWindow?.frame
        case .playlist: return playlistWindow?.frame
        default: return nil
        }
    }

    // MARK: - Private

    private func mapWindowsToKinds() {
        windowKinds.removeAll()
        forEachWindow { window, kind in
            windowKinds[ObjectIdentifier(window)] = kind
        }
    }
}
