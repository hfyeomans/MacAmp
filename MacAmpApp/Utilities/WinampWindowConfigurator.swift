import AppKit

/// Shared window configuration helper for all Winamp windows
/// Extracted from UnifiedDockView.configureWindow() method
struct WinampWindowConfigurator {
    /// Apply standard Winamp window configuration to an NSWindow
    /// - Parameter window: The window to configure
    static func apply(to window: NSWindow) {
        // Configure window style mask to remove title bar completely
        window.styleMask.insert(.borderless)
        window.styleMask.remove(.titled)

        // DO NOT make entire window draggable - causes slider conflicts
        // We'll use custom DragGesture on title bars only (Phase 1B)
        window.isMovableByWindowBackground = false

        // Remove title bar appearance completely
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Ensure no separator line between title bar and content
        if #available(macOS 11.0, *) {
            window.toolbar = nil
        }

        // Allow window to be in front of other windows (baseline)
        window.level = .normal

        // Allow window to be moved (via custom drag regions in Phase 1B)
        window.isMovable = true
    }
}
