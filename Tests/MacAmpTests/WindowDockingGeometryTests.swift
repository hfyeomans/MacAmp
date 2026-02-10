import XCTest
@testable import MacAmp

final class WindowDockingGeometryTests: XCTestCase {

    // MARK: - determineAttachment

    func testBelowAttachmentDetected() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 100, y: 384, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .below(let xOffset) = attachment else {
            XCTFail("Expected .below attachment, got \(String(describing: attachment))")
            return
        }
        XCTAssertEqual(xOffset, 0, accuracy: 0.01)
    }

    func testAboveAttachmentDetected() {
        let anchor = NSRect(x: 100, y: 384, width: 275, height: 116)
        let playlist = NSRect(x: 100, y: 500, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .above(let xOffset) = attachment else {
            XCTFail("Expected .above attachment, got \(String(describing: attachment))")
            return
        }
        XCTAssertEqual(xOffset, 0, accuracy: 0.01)
    }

    func testRightAttachmentDetected() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 375, y: 500, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .right(let yOffset) = attachment else {
            XCTFail("Expected .right attachment, got \(String(describing: attachment))")
            return
        }
        XCTAssertEqual(yOffset, 0, accuracy: 0.01)
    }

    func testNoAttachmentWhenFarApart() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 800, y: 100, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        XCTAssertNil(attachment, "Windows far apart should not produce an attachment")
    }

    // MARK: - playlistOrigin

    func testPlaylistOriginBelow() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let size = NSSize(width: 275, height: 116)

        let origin = WindowDockingGeometry.playlistOrigin(
            for: .below(xOffset: 0),
            anchorFrame: anchor,
            playlistSize: size
        )

        XCTAssertEqual(origin.x, 100, accuracy: 0.01)
        XCTAssertEqual(origin.y, 384, accuracy: 0.01)
    }

    // MARK: - anchorFrame

    func testAnchorFrameReturnsMain() {
        let main = NSRect(x: 100, y: 500, width: 275, height: 116)
        let eq = NSRect(x: 100, y: 384, width: 275, height: 116)

        let result = WindowDockingGeometry.anchorFrame(.main, mainFrame: main, eqFrame: eq)
        XCTAssertEqual(result, main)
    }

    func testAnchorFrameReturnsNilForVideo() {
        let main = NSRect(x: 100, y: 500, width: 275, height: 116)
        let eq = NSRect(x: 100, y: 384, width: 275, height: 116)

        let result = WindowDockingGeometry.anchorFrame(.video, mainFrame: main, eqFrame: eq)
        XCTAssertNil(result)
    }
}
