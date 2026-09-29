import AppKit

/// Custom NSWindow subclass that allows borderless windows to accept input and become key/main
class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Window › Minimize (Cmd+M) minimizes the whole player from any MacAmp window.
    override func performMiniaturize(_ sender: Any?) {
        WindowCoordinator.shared?.minimizeApp()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        item.action == #selector(performMiniaturize(_:))
            ? WindowCoordinator.shared?.canMinimizeApp ?? false
            : super.validateUserInterfaceItem(item)
    }
}
