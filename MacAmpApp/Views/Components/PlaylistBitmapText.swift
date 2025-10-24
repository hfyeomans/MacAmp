import SwiftUI
import AppKit

/// General-purpose bitmap text renderer for the playlist using TEXT.BMP glyphs.
/// Applies PLEDIT-based colors and falls back to system text when glyphs are missing.
struct PlaylistBitmapText: View {
    @EnvironmentObject var skinManager: SkinManager

    let text: String
    let color: Color
    let spacing: CGFloat
    let fallbackSize: CGFloat
    let fallbackDesign: Font.Design

    init(
        _ text: String,
        color: Color,
        spacing: CGFloat = 1,
        fallbackSize: CGFloat = 9,
        fallbackDesign: Font.Design = .default
    ) {
        self.text = text
        self.color = color
        self.spacing = spacing
        self.fallbackSize = fallbackSize
        self.fallbackDesign = fallbackDesign
    }

    private func imageForChar(_ ch: Character) -> NSImage? {
        let code = String(ch).utf16.first ?? 32
        let key = "CHARACTER_\(code)"
        return skinManager.currentSkin?.images[key]
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if let img = imageForChar(ch) {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .antialiased(false)
                        .resizable()
                        .frame(width: img.size.width, height: img.size.height)
                        .colorMultiply(color)
                } else {
                    Text(String(ch))
                        .font(.system(size: fallbackSize, design: fallbackDesign))
                        .foregroundColor(color)
                }
            }
        }
    }
}
