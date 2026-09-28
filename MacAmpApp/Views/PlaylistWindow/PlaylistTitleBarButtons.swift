import SwiftUI

/// Shade and close are part of the titlebar bitmap; only the pressed sprite is drawn.
struct PlaylistTitleBarButtons: View {
    let windowWidth: CGFloat
    let shaded: Bool
    let onShadeToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        let buttonY: CGFloat = 7.5

        SkinHitButton(pressedSprite: shaded ? "PLAYLIST_EXPAND_SELECTED" : "PLAYLIST_COLLAPSE_SELECTED",
                      width: 9, height: 9, action: onShadeToggle)
            .position(x: windowWidth - 16.5, y: buttonY)

        SkinHitButton(pressedSprite: "PLAYLIST_CLOSE_SELECTED", width: 9, height: 9, action: onClose)
            .position(x: windowWidth - 6.5, y: buttonY)
    }
}
