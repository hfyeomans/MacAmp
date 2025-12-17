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

        // Resize constraints: Allow segment-based resizing (25×29px increments)
        // Uses PlaylistWindowSizeState.baseWidth/baseHeight as minimum (275×116px)
        window.minSize = NSSize(
            width: PlaylistWindowSizeState.baseWidth,
            height: PlaylistWindowSizeState.baseHeight
        )
        window.maxSize = NSSize(width: 2000, height: 900)  // Allow horizontal expansion

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
