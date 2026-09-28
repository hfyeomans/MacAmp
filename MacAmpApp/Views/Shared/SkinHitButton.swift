import SwiftUI

/// A Winamp button whose normal image is part of the window's bitmap (titlebar and shade-strip
/// buttons): an invisible hit area that draws only the skin's pressed sprite while held.
struct SkinHitButton: View {
    let pressedSprite: String?
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    init(pressedSprite: String? = nil, width: CGFloat, height: CGFloat, action: @escaping () -> Void) {
        self.pressedSprite = pressedSprite
        self.width = width
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(PressedSpriteStyle(pressedSprite: pressedSprite, width: width, height: height))
            .focusable(false)
    }

    private struct PressedSpriteStyle: ButtonStyle {
        let pressedSprite: String?
        let width: CGFloat
        let height: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                if configuration.isPressed, let pressedSprite {
                    SimpleSpriteImage(pressedSprite, width: width, height: height)
                } else {
                    Color.clear
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
    }
}
