import SwiftUI
import AppKit

struct SkinnedText: View {
    @Environment(SkinManager.self) var skinManager
    let text: String
    let spacing: CGFloat

    init(_ text: String, spacing: CGFloat = 1) {
        self.text = text
        self.spacing = spacing
    }

    private func imageForChar(_ ch: Character) -> NSImage? {
        let code = String(ch).utf16.first ?? 32
        let key = "CHARACTER_\(code)"
        return skinManager.currentSkin?.images[key]
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text), id: \.self) { ch in
                if let img = imageForChar(ch) {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .antialiased(false)
                        .resizable()
                        .frame(width: img.size.width, height: img.size.height)
                } else {
                    // Fallback to system text character if missing
                    Text(String(ch))
                        .font(.system(size: 10))
                }
            }
        }
    }
}

