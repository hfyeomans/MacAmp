import SwiftUI
import AppKit

@MainActor
@Observable
final class PlaylistWindowInteractionState {
    var selectedIndices: Set<Int> = []
    var isShadeMode: Bool = false
    var scrollOffset: Int = 0
    var dragStartSize: Size2D?
    var isDragging: Bool = false
    private(set) var resizePreview = WindowResizePreviewOverlay()
    private(set) var keyboardMonitor: Any?

    func installKeyboardMonitor(playlistCount: @escaping () -> Int) {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyPress(event: event, playlistCount: playlistCount()) ?? event
        }
    }

    func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    func handleTrackTap(index: Int) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.shift) {
            if selectedIndices.contains(index) {
                selectedIndices.remove(index)
            } else {
                selectedIndices.insert(index)
            }
        } else {
            selectedIndices = [index]
        }
    }

    func handleKeyPress(event: NSEvent, playlistCount: Int) -> NSEvent? {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectedIndices = Set(0..<playlistCount)
            return nil
        }

        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d") {
            selectedIndices = []
            return nil
        }

        return event
    }

    func clampScrollOffset(maxOffset: Int) {
        if scrollOffset > maxOffset {
            scrollOffset = maxOffset
        }
    }
}
