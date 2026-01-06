import AppKit
import SwiftUI

@MainActor
class WinampMilkdropWindowController: NSWindowController {
    /// Butterchurn bridge instance (owned by controller, shared with view)
    let butterchurnBridge: ButterchurnBridge

    /// Butterchurn preset manager (owned by controller for lifecycle management)
    let presetManager: ButterchurnPresetManager

    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer, dockingController: DockingController, settings: AppSettings, radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator, windowFocusState: WindowFocusState) {
        AppLog.debug(.window, "WinampMilkdropWindowController: init() called")

        // Create Butterchurn bridge (owned by controller for lifecycle management)
        let bridge = ButterchurnBridge()

        // Create preset manager and configure with bridge + settings + playback coordinator
        let presetMgr = ButterchurnPresetManager()
        presetMgr.configure(bridge: bridge, appSettings: settings, playbackCoordinator: playbackCoordinator)

        // Wire bridge's onPresetsLoaded callback to preset manager
        bridge.onPresetsLoaded = { [weak presetMgr] presetNames in
            presetMgr?.loadPresets(presetNames)
        }

        // Wire preset manager reference for cleanup coordination
        bridge.presetManager = presetMgr

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

        // Create view with environment injection (including Butterchurn bridge and preset manager)
        let rootView = WinampMilkdropWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)
            .environment(windowFocusState)
            .environment(bridge)
            .environment(presetMgr)

        let hostingController = NSHostingController(rootView: rootView)

        AppLog.debug(.window, "WinampMilkdropWindowController: Creating window with size \(window.frame.size)")

        // CRITICAL: Only set contentViewController - DO NOT set contentView
        // Setting contentView releases the hosting controller, breaking SwiftUI lifecycle
        window.contentViewController = hostingController

        AppLog.debug(.window, "WinampMilkdropWindowController: Content controller set, SwiftUI lifecycle enabled")

        // Install translucent backing layer (prevents bleed-through)
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window, bridge: bridge, presetManager: presetMgr)
    }

    init(window: NSWindow, bridge: ButterchurnBridge, presetManager: ButterchurnPresetManager) {
        self.butterchurnBridge = bridge
        self.presetManager = presetManager
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
