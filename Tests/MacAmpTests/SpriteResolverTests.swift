import Testing
import AppKit
@testable import MacAmp

@Suite("SpriteResolver")
struct SpriteResolverTests {
    private let emptySkin: Skin

    init() {
        emptySkin = Skin(
            visualizerColors: [],
            playlistStyle: PlaylistStyle(
                normalTextColor: .white,
                currentTextColor: .white,
                backgroundColor: .black,
                selectedBackgroundColor: .blue,
                fontName: nil
            ),
            images: [:],
            cursors: [:],
            loadedSheets: []
        )
    }

    @Test("Out-of-range digits return nil")
    func digitOutOfRangeReturnsNil() {
        let resolver = SpriteResolver(skin: emptySkin)
        #expect(resolver.resolve(.digit(-1)) == nil)
        #expect(resolver.resolve(.digit(10)) == nil)
    }

    @Test("Valid digit resolves when image is available")
    func digitResolvesWhenAvailable() {
        let skin = Skin(
            visualizerColors: emptySkin.visualizerColors,
            playlistStyle: emptySkin.playlistStyle,
            images: ["DIGIT_3": NSImage(size: NSSize(width: 9, height: 13))],
            cursors: [:],
            loadedSheets: []
        )
        let resolver = SpriteResolver(skin: skin)
        #expect(resolver.resolve(.digit(3)) == "DIGIT_3")
    }
}
