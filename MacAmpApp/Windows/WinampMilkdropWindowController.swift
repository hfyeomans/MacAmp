import AppKit
import SwiftUI

@MainActor
class WinampMilkdropWindowController: NSWindowController {
    /// Butterchurn bridge instance (owned by controller, shared with view)
    let butterchurnBridge: ButterchurnBridge

    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        AppLog.debug(.window, "WinampMilkdropWindowController: init() called")

        // Create Butterchurn bridge (owned by controller for lifecycle management)
        let bridge = ButterchurnBridge()

        // Create borderless window (follows TASK 1 pattern)
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),  // Matches Video/Playlist size
            styleMask: [.borderless],  // Borderless only
            backing: .buffered,
            defer: false
        )

        AppLog.debug(.window, "WinampMilkdropWindowController: BorderlessWindow created")

        // Apply standard Winamp window configuration
        WinampWindowConfigurator.apply(to: window)

        // Borderless visual configuration
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        // Create view with environment injection (including Butterchurn bridge)
        let rootView = WinampMilkdropWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)
            .environment(windowFocusState)
            .environment(bridge)

        let hostingController = NSHostingController(rootView: rootView)

        AppLog.debug(.window, "WinampMilkdropWindowController: Creating window with size \(window.frame.size)")

        // CRITICAL: Only set contentViewController - DO NOT set contentView
        // Setting contentView releases the hosting controller, breaking SwiftUI lifecycle
        window.contentViewController = hostingController

        AppLog.debug(.window, "WinampMilkdropWindowController: Content controller set, SwiftUI lifecycle enabled")

        // Install translucent backing layer (prevents bleed-through)
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window, bridge: bridge)
    }

    init(window: NSWindow, bridge: ButterchurnBridge) {
        self.butterchurnBridge = bridge
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
