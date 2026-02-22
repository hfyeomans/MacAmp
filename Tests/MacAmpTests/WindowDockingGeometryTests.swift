import Testing
import AppKit
@testable import MacAmp

@Suite("WindowDockingGeometry")
struct WindowDockingGeometryTests {

    // MARK: - determineAttachment

    @Test("Below attachment detected when playlist is directly below anchor")
    func belowAttachmentDetected() throws {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 100, y: 384, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .below(let xOffset) = attachment else {
            Issue.record("Expected .below attachment, got \(String(describing: attachment))")
            return
        }
        #expect(abs(xOffset) < 0.01)
    }

    @Test("Above attachment detected when playlist is directly above anchor")
    func aboveAttachmentDetected() throws {
        let anchor = NSRect(x: 100, y: 384, width: 275, height: 116)
        let playlist = NSRect(x: 100, y: 500, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .above(let xOffset) = attachment else {
            Issue.record("Expected .above attachment, got \(String(describing: attachment))")
            return
        }
        #expect(abs(xOffset) < 0.01)
    }

    @Test("Right attachment detected when playlist is directly to the right of anchor")
    func rightAttachmentDetected() throws {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 375, y: 500, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        guard case .right(let yOffset) = attachment else {
            Issue.record("Expected .right attachment, got \(String(describing: attachment))")
            return
        }
        #expect(abs(yOffset) < 0.01)
    }

    @Test("No attachment when windows are far apart")
    func noAttachmentWhenFarApart() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let playlist = NSRect(x: 800, y: 100, width: 275, height: 116)

        let attachment = WindowDockingGeometry.determineAttachment(
            anchorFrame: anchor,
            playlistFrame: playlist
        )

        #expect(attachment == nil, "Windows far apart should not produce an attachment")
    }

    // MARK: - playlistOrigin

    @Test("Playlist origin computed correctly for below attachment")
    func playlistOriginBelow() {
        let anchor = NSRect(x: 100, y: 500, width: 275, height: 116)
        let size = NSSize(width: 275, height: 116)

        let origin = WindowDockingGeometry.playlistOrigin(
            for: .below(xOffset: 0),
            anchorFrame: anchor,
            playlistSize: size
        )

        #expect(abs(origin.x - 100) < 0.01)
        #expect(abs(origin.y - 384) < 0.01)
    }

    // MARK: - anchorFrame

    @Test("anchorFrame returns main frame for .main anchor")
    func anchorFrameReturnsMain() {
        let main = NSRect(x: 100, y: 500, width: 275, height: 116)
        let eq = NSRect(x: 100, y: 384, width: 275, height: 116)

        let result = WindowDockingGeometry.anchorFrame(.main, mainFrame: main, eqFrame: eq)
        #expect(result == main)
    }

    @Test("anchorFrame returns nil for .video anchor")
    func anchorFrameReturnsNilForVideo() {
        let main = NSRect(x: 100, y: 500, width: 275, height: 116)
        let eq = NSRect(x: 100, y: 384, width: 275, height: 116)

        let result = WindowDockingGeometry.anchorFrame(.video, mainFrame: main, eqFrame: eq)
        #expect(result == nil)
    }
}
