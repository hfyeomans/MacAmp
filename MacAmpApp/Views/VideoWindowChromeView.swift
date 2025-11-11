import SwiftUI

/// Video Window Chrome - Renders VIDEO.bmp skinnable window frame
struct VideoWindowChromeView<Content: View>: View {
    let sprites: SkinManager.VideoWindowSprites
    @ViewBuilder let content: Content

    @State private var isWindowActive = true

    var body: some View {
        VStack(spacing: 0) {
            // Titlebar (active/inactive based on window focus)
            VideoWindowTitlebar(sprites: sprites, isActive: isWindowActive)
                .frame(height: 20)  // Titlebar sprite height

            // Content area (video player or placeholder)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom control bar (using VIDEO.bmp bottom sprites)
            VideoWindowBottomBar(sprites: sprites)
                .frame(height: 38)  // Bottom bar sprite height
        }
        .overlay(
            // Window borders (left/right vertical strips)
            VideoWindowBorders(sprites: sprites)
        )
    }
}

/// Titlebar component with VIDEO.bmp sprites
struct VideoWindowTitlebar: View {
    let sprites: SkinManager.VideoWindowSprites
    let isActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Left cap
            if let leftCap = isActive ? sprites.titlebarTopLeft.active : sprites.titlebarTopLeft.inactive {
                Image(nsImage: leftCap)
                    .resizable()
                    .frame(width: 25, height: 20)
            }

            // Center section
            if let center = isActive ? sprites.titlebarTopCenter.active : sprites.titlebarTopCenter.inactive {
                Image(nsImage: center)
                    .resizable()
                    .frame(width: 100, height: 20)
            }

            // Stretchy bit (tileable)
            if let stretchy = isActive ? sprites.titlebarTopStretchyBit.active : sprites.titlebarTopStretchyBit.inactive {
                Image(nsImage: stretchy)
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: 20)
            }

            // Right cap
            if let rightCap = isActive ? sprites.titlebarTopRight.active : sprites.titlebarTopRight.inactive {
                Image(nsImage: rightCap)
                    .resizable()
                    .frame(width: 25, height: 20)
            }
        }
        .frame(height: 20)
    }
}

/// Bottom control bar with VIDEO.bmp sprites
struct VideoWindowBottomBar: View {
    let sprites: SkinManager.VideoWindowSprites

    var body: some View {
        HStack(spacing: 0) {
            // Left section (fixed)
            if let left = sprites.bottomLeft {
                Image(nsImage: left)
                    .resizable()
                    .frame(width: 125, height: 38)
            }

            // Center stretchy section (tiles to fill width)
            if let center = sprites.bottomStretchyBit {
                Image(nsImage: center)
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: 38)
            }

            // Right section (fixed)
            if let right = sprites.bottomRight {
                Image(nsImage: right)
                    .resizable()
                    .frame(width: 125, height: 38)
            }
        }
        .frame(height: 38)
    }
}

/// Window borders (left/right vertical strips)
struct VideoWindowBorders: View {
    let sprites: SkinManager.VideoWindowSprites

    var body: some View {
        HStack(spacing: 0) {
            // Left border
            if let left = sprites.borderLeft {
                Image(nsImage: left)
                    .resizable()
                    .frame(width: 11)
            }

            Spacer()

            // Right border
            if let right = sprites.borderRight {
                Image(nsImage: right)
                    .resizable()
                    .frame(width: 8)
            }
        }
        .allowsHitTesting(false)  // Borders are decorative only
    }
}
