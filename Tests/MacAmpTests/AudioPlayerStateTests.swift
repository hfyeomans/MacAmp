import XCTest
@testable import MacAmp

@MainActor
final class AudioPlayerStateTests: XCTestCase {
    func testStopTransitionsToManualStopped() async throws {
        let player = AudioPlayer()
        player.stop()
        XCTAssertEqual(player.playbackState, PlaybackState.stopped(.manual))
    }

    func testEjectTransitionsToEjectedStopped() async throws {
        let player = AudioPlayer()
        player.eject()
        XCTAssertEqual(player.playbackState, PlaybackState.stopped(.ejected))
    }
}
