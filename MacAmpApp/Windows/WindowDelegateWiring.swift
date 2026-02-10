import AppKit

/// Holds strong references to delegate multiplexers and focus delegates.
/// Created via `wire()` static factory; coordinator stores the returned instance.
@MainActor
struct WindowDelegateWiring {
    let focusDelegates: [WindowFocusDelegate]
    let multiplexers: [WindowDelegateMultiplexer]

    /// Wire up all delegate multiplexers, snap manager, persistence, and focus delegates.
    static func wire(
        registry: WindowRegistry,
        persistenceDelegate: WindowPersistenceDelegate?,
        windowFocusState: WindowFocusState
    ) -> WindowDelegateWiring {
        let windowKinds: [(WindowKind, NSWindow?)] = [
            (.main, registry.mainWindow),
            (.equalizer, registry.eqWindow),
            (.playlist, registry.playlistWindow),
            (.video, registry.videoWindow),
            (.milkdrop, registry.milkdropWindow)
        ]

        var multiplexers: [WindowDelegateMultiplexer] = []
        var focusDelegates: [WindowFocusDelegate] = []

        for (kind, window) in windowKinds {
            guard let window else { continue }

            // Register with snap manager
            WindowSnapManager.shared.register(window: window, kind: kind)

            // Create multiplexer with snap manager as first delegate
            let multiplexer = WindowDelegateMultiplexer()
            multiplexer.add(delegate: WindowSnapManager.shared)

            // Add persistence delegate
            if let persistenceDelegate {
                multiplexer.add(delegate: persistenceDelegate)
            }

            // Add focus delegate
            let focusDelegate = WindowFocusDelegate(kind: kind, focusState: windowFocusState)
            multiplexer.add(delegate: focusDelegate)

            window.delegate = multiplexer

            multiplexers.append(multiplexer)
            focusDelegates.append(focusDelegate)
        }

        return WindowDelegateWiring(focusDelegates: focusDelegates, multiplexers: multiplexers)
    }
}
