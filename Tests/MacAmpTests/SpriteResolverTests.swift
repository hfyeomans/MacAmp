import XCTest
import AppKit
@testable import MacAmp

final class SpriteResolverTests: XCTestCase {
    private func makeEmptySkin() -> Skin {
        Skin(
            visualizerColors: [],
            playlistStyle: PlaylistStyle(
                normalTextColor: .white,
                currentTextColor: .white,
                backgroundColor: .black,
                selectedBackgroundColor: .blue,
                fontName: nil
            ),
            images: [:],
            cursors: [:]
        )
    }

    func testDigitOutOfRangeReturnsNil() {
        let resolver = SpriteResolver(skin: makeEmptySkin())
        XCTAssertNil(resolver.resolve(.digit(-1)))
        XCTAssertNil(resolver.resolve(.digit(10)))
    }

    func testDigitResolvesWhenAvailable() {
        var skin = makeEmptySkin()
        skin = Skin(
            visualizerColors: skin.visualizerColors,
            playlistStyle: skin.playlistStyle,
            images: ["DIGIT_3": NSImage(size: NSSize(width: 9, height: 13))],
            cursors: [:]
        )
        let resolver = SpriteResolver(skin: skin)
        XCTAssertEqual(resolver.resolve(.digit(3)), "DIGIT_3")
    }
}
