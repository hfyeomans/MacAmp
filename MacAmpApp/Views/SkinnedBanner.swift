import SwiftUI
import AppKit

struct SkinnedBanner<Content: View>: View {
    let fill: NSImage?
    let height: CGFloat
    @ViewBuilder var content: Content

    init(fill: NSImage?, height: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.height = height
        self.content = content()
    }

    var body: some View {
        ZStack {
            if let img = fill {
                Image(nsImage: img)
                    .resizable(resizingMode: .tile)
                    .frame(height: height)
            } else {
                Rectangle().fill(Color.black.opacity(0.6)).frame(height: height)
            }
            HStack { content }.padding(.horizontal, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

