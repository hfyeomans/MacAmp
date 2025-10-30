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
    @Environment(SkinManager.self) var skinManager

    let text: String
    let spacing: CGFloat

    init(_ text: String, spacing: CGFloat = 1) {
        self.text = text
        self.spacing = spacing
    }

    /// Get the text color from PLEDIT.TXT (Normal=#00FF00 or skin-specific)
    private var textColor: Color {
        skinManager.currentSkin?.playlistStyle.normalTextColor ?? Color(red: 0, green: 1.0, blue: 0)
    }

    var body: some View {
        PlaylistBitmapText(
            text,
            color: textColor,
            spacing: spacing,
            fallbackSize: 8,
            fallbackDesign: Font.Design.monospaced
        )
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
    .environment(SkinManager())
}
