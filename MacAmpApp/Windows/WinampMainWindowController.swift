import AppKit
import SwiftUI

@MainActor
class WinampMainWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        // ORACLE BLOCKING ISSUE #1 FIX: Truly borderless windows
        // .borderless = 0, so [.borderless, .titled] keeps .titled mask!
        // For custom Winamp chrome, use .borderless ONLY (no system chrome)

        // CRITICAL: Use BorderlessWindow subclass for canBecomeKey/canBecomeMain
        // Standard borderless NSWindow doesn't accept first responder
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 116),
            styleMask: [.borderless],  // ONLY borderless - no .titled!
            backing: .buffered,
            defer: false
        )

        // CRITICAL FIX #2: Apply standard Winamp window configuration
        // Extracted from UnifiedDockView.configureWindow()
        WinampWindowConfigurator.apply(to: window)

        // Borderless visual configuration
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        // Create view with environment injection
        let rootView = WinampMainWindow()
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
