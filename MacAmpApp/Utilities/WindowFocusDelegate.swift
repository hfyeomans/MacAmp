import AppKit
import Foundation

/// Window Focus Delegate - Updates WindowFocusState when windows gain/lose focus
/// Follows WindowPersistenceDelegate pattern from WindowCoordinator
/// Part of Bridge layer - wired through WindowDelegateMultiplexer
@MainActor
final class WindowFocusDelegate: NSObject, NSWindowDelegate {
    private let kind: WindowKind
    private let focusState: WindowFocusState

    init(kind: WindowKind, focusState: WindowFocusState) {
        self.kind = kind
        self.focusState = focusState
        super.init()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Reset all focus states, then set this window as focused
        focusState.isMainKey = (kind == .main)
        focusState.isEqualizerKey = (kind == .equalizer)
        focusState.isPlaylistKey = (kind == .playlist)
        focusState.isVideoKey = (kind == .video)
        focusState.isMilkdropKey = (kind == .milkdrop)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Window lost focus - set its state to false
        switch kind {
        case .main:
            focusState.isMainKey = false
        case .equalizer:
            focusState.isEqualizerKey = false
        case .playlist:
            focusState.isPlaylistKey = false
        case .video:
            focusState.isVideoKey = false
        case .milkdrop:
            focusState.isMilkdropKey = false
        }
    }
}
