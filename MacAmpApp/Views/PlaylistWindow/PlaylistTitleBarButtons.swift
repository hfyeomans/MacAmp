import SwiftUI

struct PlaylistTitleBarButtons: View {
    let windowWidth: CGFloat
    let onMinimize: () -> Void
    let onShadeToggle: () -> Void
    let onClose: () -> Void

    var body: some View {
        let buttonY: CGFloat = 7.5

        Button(action: onMinimize, label: {
            SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 26.5, y: buttonY)

        Button(action: onShadeToggle, label: {
            SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 16.5, y: buttonY)

        Button(action: onClose, label: {
            SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
        })
        .buttonStyle(.plain)
        .focusable(false)
        .position(x: windowWidth - 6.5, y: buttonY)
    }
}
