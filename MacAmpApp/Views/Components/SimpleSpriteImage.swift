import SwiftUI

/// Simple, pixel-perfect sprite rendering component (replaces over-engineered PixelGrid)
struct SimpleSpriteImage: View {
    let spriteKey: String
    let width: CGFloat?
    let height: CGFloat?
    
    @EnvironmentObject var skinManager: SkinManager
    
    init(_ spriteKey: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.spriteKey = spriteKey
        self.width = width
        self.height = height
    }
    
    var body: some View {
        if let skin = skinManager.currentSkin,
           let image = skin.images[spriteKey] {
            Image(nsImage: image)
                .interpolation(.none)      // Pixel-perfect rendering
                .antialiased(false)        // No antialiasing
                .frame(width: width, height: height)
        } else {
            // Missing sprite placeholder - obvious purple rectangle for debugging
            Rectangle()
                .fill(Color.purple)
                .frame(width: width ?? 32, height: height ?? 32)
                .overlay(
                    Text("?")
                        .font(.system(size: min(width ?? 32, height ?? 32) / 4, weight: .bold))
                        .foregroundColor(.white)
                )
                .onAppear {
                    print("❌ MISSING SPRITE: '\(spriteKey)' not found in skin")
                }
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
    static let playlistBase = CGSize(width: 275, height: 232)
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
    .environmentObject(SkinManager())
}