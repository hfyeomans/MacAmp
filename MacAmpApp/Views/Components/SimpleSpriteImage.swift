import SwiftUI

/// Sprite source type - supports both legacy hardcoded names and semantic sprite resolution
enum SpriteSource {
    case legacy(String)              // Old: hardcoded sprite names
    case semantic(SemanticSprite)    // New: semantic sprite requests

    var isDigit: Bool {
        if case .semantic(let s) = self, case .digit(_) = s {
            return true
        }
        return false
    }
}

/// Simple, pixel-perfect sprite rendering component (replaces over-engineered PixelGrid)
/// Now supports both legacy sprite names and semantic sprite resolution.
///
/// Usage:
/// ```swift
/// // Legacy (backward compatible):
/// SimpleSpriteImage("DIGIT_0", width: 9, height: 13)
///
/// // Semantic (new architecture):
/// SimpleSpriteImage(.digit(0), width: 9, height: 13)
/// ```
struct SimpleSpriteImage: View {
    let source: SpriteSource
    let width: CGFloat?
    let height: CGFloat?

    @Environment(SkinManager.self) var skinManager

    /// Initialize with semantic sprite (new architecture)
    init(_ semantic: SemanticSprite, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.source = .semantic(semantic)
        self.width = width
        self.height = height
    }

    /// Initialize with legacy sprite name (backward compatible)
    init(_ spriteKey: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.source = .legacy(spriteKey)
        self.width = width
        self.height = height
    }

    var body: some View {
        // Resolve sprite name ONCE when view is created
        // Pass the resolved name (not the semantic) to prevent re-resolution
        let spriteName = resolveSpriteName()

        if let name = spriteName, let image = skinManager.currentSkin?.images[name] {
            Image(nsImage: image)
                .interpolation(.none)
                .antialiased(false)
                .resizable()  // Force image to fill frame completely
                .aspectRatio(contentMode: .fill)  // Fill frame, ignore aspect ratio
                .frame(width: width, height: height)
                .clipped()  // Clip overflow from .fill mode
        } else {
            Rectangle()
                .fill(Color.purple)
                .frame(width: width ?? 32, height: height ?? 32)
                .overlay(
                    Text("?")
                        .font(.system(size: min(width ?? 32, height ?? 32) / 4, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private func resolveSpriteName() -> String? {
        switch source {
        case .legacy(let name):
            return name
        case .semantic(let semantic):
            guard let skin = skinManager.currentSkin else { return nil }
            return SpriteResolver(skin: skin).resolve(semantic)
        }
    }
}

/// Absolute positioning extension - replaces PixelGrid positioning
extension View {
    /// Position view at exact coordinates (top-left origin like Winamp)
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
    
    /// Position view at exact coordinates using CGPoint
    func at(_ point: CGPoint) -> some View {
        self.offset(x: point.x, y: point.y)
    }
}

/// Simple replacement for WindowSpec enum - direct sizes
struct WinampSizes {
    static let main = CGSize(width: 275, height: 116)
    static let mainShade = CGSize(width: 275, height: 14)
    static let equalizer = CGSize(width: 275, height: 116)
    static let equalizerShade = CGSize(width: 275, height: 14)
    static let playlistBase = CGSize(width: 275, height: 232)
    static let playlistShade = CGSize(width: 275, height: 14)
    static let video = CGSize(width: 275, height: 232)
    static let milkdrop = CGSize(width: 275, height: 232)
}

#Preview {
    // Test the component
    ZStack {
        Color.black
        
        VStack {
            SimpleSpriteImage("DIGIT_0", width: 9, height: 13)
            SimpleSpriteImage("MISSING_SPRITE", width: 32, height: 16)
        }
    }
    .frame(width: 200, height: 200)
    .environment(SkinManager())
}