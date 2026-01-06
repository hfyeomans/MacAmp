import SwiftUI
import AppKit

/// Milkdrop Window - GEN.bmp chrome with Butterchurn visualization
/// Visualization only active for local playback (AVAudioEngine)
/// Stream playback shows fallback placeholder
///
/// Context Menu (right-click):
/// - Randomize toggle
/// - Cycling toggle with interval submenu
/// - Next/Previous preset
/// - Current preset display
/// - Preset list submenu
struct WinampMilkdropWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(ButterchurnBridge.self) var bridge
    @Environment(ButterchurnPresetManager.self) var presetManager
    @Environment(PlaybackCoordinator.self) var playbackCoordinator

    /// MILKDROP window size state (segment-based resizing)
    @State private var sizeState = MilkdropWindowSizeState()

    // Menu state - keep strong reference to prevent premature deallocation
    @State private var activeContextMenu: NSMenu?

    var body: some View {
        MilkdropWindowChromeView(sizeState: sizeState) {
            ZStack {
                // ALWAYS create WebView - it must exist to send 'ready' message
                ButterchurnWebView(bridge: bridge)

                // Overlay loading/error state (fades when ready)
                if !bridge.isReady {
                    if let error = bridge.errorMessage {
                        fallbackView(message: error)
                    } else {
                        fallbackView(message: "Loading...")
                    }
                }

                // Invisible overlay to capture right-clicks for context menu
                RightClickCaptureView { location in
                    showContextMenu(at: location)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: bridge.isReady)
        }
        .frame(
            width: sizeState.pixelSize.width,
            height: sizeState.pixelSize.height,
            alignment: .topLeading
        )
        .fixedSize()
        .background(Color.black)
        .onAppear {
            // Configure bridge with audioPlayer for audio visualization
            bridge.configure(audioPlayer: audioPlayer)

            // Initial NSWindow frame sync with integral coordinates
            if let coordinator = WindowCoordinator.shared {
                let clampedSize = CGSize(
                    width: round(sizeState.pixelSize.width),
                    height: round(sizeState.pixelSize.height)
                )
                coordinator.updateMilkdropWindowSize(to: clampedSize)

                // Sync Butterchurn canvas to initial size
                bridge.setSize(width: sizeState.contentSize.width, height: sizeState.contentSize.height)
            }
        }
    }

    /// Fallback placeholder when Butterchurn is unavailable
    @ViewBuilder
    private func fallbackView(message: String) -> some View {
        VStack(spacing: 8) {
            Text("MILKDROP")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Context Menu

    /// Show Butterchurn context menu at the specified location
    private func showContextMenu(at location: NSPoint) {
        let menu = NSMenu()
        activeContextMenu = menu

        // MARK: Current Preset Header
        if let presetName = presetManager.currentPresetName {
            let headerItem = NSMenuItem(title: "▶ \(presetName)", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(.separator())
        }

        // MARK: Navigation
        menu.addItem(createMenuItem(
            title: "Next Preset",
            keyEquivalent: " ",
            modifiers: [],
            action: { [weak presetManager] in
                presetManager?.nextPreset()
            }
        ))

        menu.addItem(createMenuItem(
            title: "Previous Preset",
            keyEquivalent: "\u{08}", // Backspace
            modifiers: [],
            action: { [weak presetManager] in
                presetManager?.previousPreset()
            }
        ))

        menu.addItem(.separator())

        // MARK: Settings
        menu.addItem(createMenuItem(
            title: "Randomize",
            isChecked: presetManager.isRandomize,
            keyEquivalent: "r",
            modifiers: [],
            action: { [weak presetManager] in
                presetManager?.isRandomize.toggle()
            }
        ))

        menu.addItem(createMenuItem(
            title: "Auto-Cycle Presets",
            isChecked: presetManager.isCycling,
            keyEquivalent: "c",
            modifiers: [],
            action: { [weak presetManager] in
                presetManager?.isCycling.toggle()
            }
        ))

        // MARK: Cycle Interval Submenu
        let intervalSubmenu = NSMenu()
        let intervals: [(String, TimeInterval)] = [
            ("5 seconds", 5),
            ("10 seconds", 10),
            ("15 seconds", 15),
            ("30 seconds", 30),
            ("60 seconds", 60),
        ]

        for (title, interval) in intervals {
            let item = createMenuItem(
                title: title,
                isChecked: abs(presetManager.cycleInterval - interval) < 0.1,
                action: { [weak presetManager] in
                    presetManager?.cycleInterval = interval
                }
            )
            intervalSubmenu.addItem(item)
        }

        let intervalItem = NSMenuItem(title: "Cycle Interval", action: nil, keyEquivalent: "")
        intervalItem.submenu = intervalSubmenu
        menu.addItem(intervalItem)

        menu.addItem(.separator())

        // MARK: Show Track Title
        let currentDisplayTitle = playbackCoordinator.displayTitle
        menu.addItem(createMenuItem(
            title: "Show Track Title",
            keyEquivalent: "t",
            modifiers: [],
            action: { [weak bridge] in
                bridge?.showTrackTitle(currentDisplayTitle)
            }
        ))

        // MARK: Track Title Interval Submenu
        let titleIntervalSubmenu = NSMenu()
        let titleIntervals: [(String, TimeInterval)] = [
            ("Once (on request)", 0),
            ("Every 5 seconds", 5),
            ("Every 10 seconds", 10),
            ("Every 15 seconds", 15),
            ("Every 30 seconds", 30),
            ("Every 60 seconds", 60),
        ]

        for (title, interval) in titleIntervals {
            let item = createMenuItem(
                title: title,
                isChecked: abs(presetManager.trackTitleInterval - interval) < 0.1,
                action: { [weak presetManager] in
                    presetManager?.trackTitleInterval = interval
                }
            )
            titleIntervalSubmenu.addItem(item)
        }

        let titleIntervalItem = NSMenuItem(title: "Track Title Interval", action: nil, keyEquivalent: "")
        titleIntervalItem.submenu = titleIntervalSubmenu
        menu.addItem(titleIntervalItem)

        menu.addItem(.separator())

        // MARK: Preset List Submenu
        if !presetManager.presets.isEmpty {
            let presetSubmenu = NSMenu()

            for (index, name) in presetManager.presets.enumerated() {
                let item = createMenuItem(
                    title: name,
                    isChecked: index == presetManager.currentPresetIndex,
                    action: { [weak presetManager] in
                        presetManager?.selectPreset(at: index)
                    }
                )
                presetSubmenu.addItem(item)

                // Limit menu size for performance (show first 100)
                if index >= 99 {
                    let moreItem = NSMenuItem(title: "... and \(presetManager.presets.count - 100) more", action: nil, keyEquivalent: "")
                    moreItem.isEnabled = false
                    presetSubmenu.addItem(moreItem)
                    break
                }
            }

            let presetItem = NSMenuItem(title: "Presets (\(presetManager.presets.count))", action: nil, keyEquivalent: "")
            presetItem.submenu = presetSubmenu
            menu.addItem(presetItem)
        }

        // Show menu at click location
        menu.popUp(positioning: nil, at: location, in: nil)
    }

    /// Helper to create menu items with actions
    @MainActor
    private func createMenuItem(
        title: String,
        isChecked: Bool = false,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.state = isChecked ? .on : .off
        item.keyEquivalentModifierMask = modifiers

        let actionTarget = MilkdropMenuTarget(action: action)
        item.target = actionTarget
        item.action = #selector(MilkdropMenuTarget.execute)
        item.representedObject = actionTarget // Keep it alive

        return item
    }
}

// MARK: - Helper Classes

/// Helper class to bridge closures to NSMenuItem actions
@MainActor
private class MilkdropMenuTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func execute() {
        action()
    }
}

/// NSViewRepresentable that captures right-click events
struct RightClickCaptureView: NSViewRepresentable {
    let onRightClick: (NSPoint) -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }

    class RightClickNSView: NSView {
        var onRightClick: ((NSPoint) -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            // Convert to screen coordinates for NSMenu.popUp
            let screenPoint = event.locationInWindow
            if let window = self.window {
                let globalPoint = window.convertPoint(toScreen: screenPoint)
                onRightClick?(globalPoint)
            }
        }

        // Allow the view to receive mouse events
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }

        // Make view transparent and non-blocking for other events
        override var acceptsFirstResponder: Bool {
            return false
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            // Only handle right-click, pass through other events
            if NSEvent.pressedMouseButtons == 2 { // Right button
                return super.hitTest(point)
            }
            return nil
        }
    }
}
