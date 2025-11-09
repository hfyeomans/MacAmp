import AppKit
import SwiftUI

class WinampPlaylistWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator) {
        // ORACLE BLOCKING ISSUE #1 FIX: Truly borderless windows
        // .borderless = 0, so [.borderless, .titled] keeps .titled mask!
        // For custom Winamp chrome, use .borderless ONLY (no system chrome)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),  // Taller for playlist!
            styleMask: [.borderless],  // ONLY borderless - no .titled!
            backing: .buffered,
            defer: false
        )

        // Borderless configuration
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false  // Custom drag regions required

        // Create view with environment injection
        let contentView = WinampPlaylistWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)

        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)
    }
}
