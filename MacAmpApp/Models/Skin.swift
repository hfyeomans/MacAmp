
import SwiftUI
import AppKit

// Represents a fully parsed Winamp skin.
struct Skin {
    // The 24 colors used by the visualizer.
    let visualizerColors: [Color]

    // Styling for the playlist editor.
    let playlistStyle: PlaylistStyle

    // A dictionary mapping sprite names (e.g., "MAIN_CLOSE_BUTTON")
    // to the actual image.
    let images: [String: NSImage]

    // A dictionary mapping cursor names to NSCursor objects.
    let cursors: [String: NSCursor]

    // TODO: Add properties for the other skin elements like
    // region, genLetterWidths, etc.
}

struct PlaylistStyle {
    let normalTextColor: Color
    let currentTextColor: Color
    let backgroundColor: Color
    let selectedBackgroundColor: Color
    let fontName: String?
}
