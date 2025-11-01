import Foundation
import XCTest
@testable import MacAmp

@MainActor
final class PlaylistNavigationTests: XCTestCase {
    func testNextTrackReturnsStreamActionForMixedPlaylist() async throws {
        let player = AudioPlayer()
        defer { player.stop() }

        let testRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let localURL = testRoot.appendingPathComponent("mono_test.wav")
        let localTrack = Track(url: localURL, title: "Local", artist: "Artist", duration: 10)
        let streamURL = URL(string: "https://example.com/stream")!
        let streamTrack = Track(url: streamURL, title: "Stream", artist: "", duration: 0)

        player.playlist = [localTrack, streamTrack]
        player.currentTrack = localTrack
        player.updatePlaylistPosition(with: localTrack)

        let action = player.nextTrack()
        guard case .requestCoordinatorPlayback(let handoffTrack) = action else {
            XCTFail("Expected stream handoff from nextTrack")
            return
        }

        XCTAssertEqual(handoffTrack.id, streamTrack.id)
        XCTAssertEqual(player.playlist.count, 2)
    }

    func testPreviousTrackReturnsLocalWhenBackingUpFromStream() async throws {
        let player = AudioPlayer()
        defer { player.stop() }

        let testRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let localURL = testRoot.appendingPathComponent("mono_test.wav")
        let localTrack = Track(url: localURL, title: "Local", artist: "Artist", duration: 10)
        let streamURL = URL(string: "https://example.com/stream")!
        let streamTrack = Track(url: streamURL, title: "Stream", artist: "", duration: 0)

        player.playlist = [localTrack, streamTrack]
        player.updatePlaylistPosition(with: streamTrack)
        player.currentTrack = localTrack

        let action = player.previousTrack()
        guard case .playLocally(let selectedTrack) = action else {
            XCTFail("Expected local playback when rewinding from stream")
            return
        }

        XCTAssertEqual(selectedTrack.id, localTrack.id)
        XCTAssertEqual(player.playlist.count, 2)
    }
}
