import Foundation
import Observation

/// Window Focus State - Tracks which windows are currently focused
/// Part of Bridge layer - updated by WindowFocusDelegate, read by Presentation views
/// Follows MacAmp three-layer architecture (Mechanism → Bridge → Presentation)
@Observable
@MainActor
final class WindowFocusState {
    /// Main window is key (focused)
    var isMainKey: Bool = true

    /// Equalizer window is key
    var isEqualizerKey: Bool = false

    /// Playlist window is key
    var isPlaylistKey: Bool = false

    /// Video window is key
    var isVideoKey: Bool = false

    /// Milkdrop window is key
    var isMilkdropKey: Bool = false

    /// Computed: Is ANY window currently focused?
    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey || isVideoKey || isMilkdropKey
    }
}
