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

        // Ensure SwiftUI gestures receive mouse movement updates
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        window.isRestorable = false
        window.isReleasedWhenClosed = false

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

    /// Install translucent backing layer to prevent 0-alpha holes and bleed-through
    /// Call after window.contentView is set
    /// - Parameter window: The window with content view
    static func installHitSurface(on window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear

        guard let contentView = window.contentView else { return }

        // Ensure layer-backed for hit testing
        if !contentView.wantsLayer {
            contentView.wantsLayer = true
        }

        contentView.layer?.isOpaque = false
        // Nearly invisible backing (0.001 alpha) - prevents bleed-through
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.001).cgColor
    }
}
