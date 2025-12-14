import AppKit
import SwiftUI

@MainActor
class WinampPlaylistWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        // Playlist window is user-resizable (width fixed at 275, height 232-900)
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.borderless, .resizable],  // Allow resizing!
            backing: .buffered,
            defer: false
        )

        // Resize constraints (Winamp behavior: height only, fixed width)
        window.minSize = NSSize(width: 275, height: 232)  // Minimum size
        window.maxSize = NSSize(width: 275, height: 900)  // Max height, fixed width

        // CRITICAL FIX #2: Apply standard Winamp window configuration
        WinampWindowConfigurator.apply(to: window)

        // Borderless visual configuration
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        // Create view with environment injection
        let rootView = WinampPlaylistWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)
            .environment(windowFocusState)

        let hostingController = NSHostingController(rootView: rootView)
        let hostingView = hostingController.view
        hostingView.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
        hostingView.autoresizingMask = [.width, .height]

        window.contentViewController = hostingController
        window.contentView = hostingView
        window.makeFirstResponder(hostingView)

        // Install translucent backing layer (prevents bleed-through)
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window)
    }
}
