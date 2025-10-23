import SwiftUI
import AppKit

/// Sprite-based text renderer for playlist time displays
/// Uses CHARACTER sprites from TEXT.BMP with colors from PLEDIT.TXT
///
/// Unlike SkinnedText (which uses raw character sprites), this component:
/// 1. Applies PLEDIT.TXT normalTextColor for proper skin theming
/// 2. Uses monospaced layout for time display (5px char width + 1px spacing)
/// 3. Optimized for playlist info bar rendering
struct PlaylistTimeText: View {
    @EnvironmentObject var skinManager: SkinManager

    let text: String
    let spacing: CGFloat

    init(_ text: String, spacing: CGFloat = 1) {
        self.text = text
        self.spacing = spacing
    }

    /// Get CHARACTER sprite image for a given character
    private func imageForChar(_ ch: Character) -> NSImage? {
        // Convert character to UTF-16 code (ASCII-compatible)
        let code = String(ch).utf16.first ?? 32
        let key = "CHARACTER_\(code)"
        return skinManager.currentSkin?.images[key]
    }

    /// Get the text color from PLEDIT.TXT (Normal=#00FF00 or skin-specific)
    private var textColor: Color {
        skinManager.currentSkin?.playlistStyle.normalTextColor ?? Color(red: 0, green: 1.0, blue: 0)
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if let img = imageForChar(ch) {
                    // Render CHARACTER sprite with PLEDIT.TXT color overlay
                    // IMPORTANT: Flip vertically because NSImage uses bottom-left origin
                    // but SwiftUI uses top-left origin
                    Image(nsImage: img)
                        .interpolation(.none)
                        .antialiased(false)
                        .resizable()
                        .frame(width: img.size.width, height: img.size.height)
                        .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))  // Flip vertically
                        .colorMultiply(textColor)  // Apply PLEDIT.TXT Normal color
                } else {
                    // Fallback: Use system font if character sprite missing
                    Text(String(ch))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(textColor)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 10) {
            PlaylistTimeText("12:34 / 56:78")
            PlaylistTimeText("-9:87")
            PlaylistTimeText(":")
        }
    }
    .frame(width: 200, height: 100)
    .environmentObject(SkinManager())
}
