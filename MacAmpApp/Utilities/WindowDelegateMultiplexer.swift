import AppKit

/// Delegate multiplexer pattern for NSWindow
/// Allows multiple delegates to receive the same NSWindowDelegate events
///
/// Purpose: WindowSnapManager needs windowDidMove, but we may also want:
/// - Custom close handlers
/// - Resize observers for playlist
/// - Focus management for z-order
/// - Future delegate-based features
///
/// CRITICAL: NSWindow.delegate is weak - WindowCoordinator must store multiplexer as property!
@MainActor
final class WindowDelegateMultiplexer: NSObject, NSWindowDelegate {
    private var delegates: [NSWindowDelegate] = []

    /// Add a delegate to receive forwarded events
    func add(delegate: NSWindowDelegate) {
        delegates.append(delegate)
    }

    // MARK: - NSWindowDelegate Method Forwarding
    // All methods use optional chaining since not all delegates implement all methods

    func windowDidMove(_ notification: Notification) {
        delegates.forEach { $0.windowDidMove?(notification) }
    }

    func windowDidResize(_ notification: Notification) {
        delegates.forEach { $0.windowDidResize?(notification) }
    }

    func windowDidBecomeMain(_ notification: Notification) {
        delegates.forEach { $0.windowDidBecomeMain?(notification) }
    }

    func windowDidResignMain(_ notification: Notification) {
        delegates.forEach { $0.windowDidResignMain?(notification) }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        delegates.forEach { $0.windowDidBecomeKey?(notification) }
    }

    func windowDidResignKey(_ notification: Notification) {
        delegates.forEach { $0.windowDidResignKey?(notification) }
    }

    func windowWillClose(_ notification: Notification) {
        delegates.forEach { $0.windowWillClose?(notification) }
    }

    func windowDidMiniaturize(_ notification: Notification) {
        delegates.forEach { $0.windowDidMiniaturize?(notification) }
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        delegates.forEach { $0.windowDidDeminiaturize?(notification) }
    }

    func windowWillMiniaturize(_ notification: Notification) {
        delegates.forEach { $0.windowWillMiniaturize?(notification) }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        delegates.forEach { $0.windowDidChangeScreen?(notification) }
    }

    func windowDidChangeScreenProfile(_ notification: Notification) {
        delegates.forEach { $0.windowDidChangeScreenProfile?(notification) }
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        delegates.forEach { $0.windowDidChangeBackingProperties?(notification) }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // All delegates must agree to close (AND logic)
        for delegate in delegates {
            if let shouldClose = delegate.windowShouldClose?(sender), !shouldClose {
                return false
            }
        }
        return true
    }
}
