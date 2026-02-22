import Testing
import Foundation
@testable import MacAmp

@MainActor
@Suite("Playlist Navigation", .tags(.audio))
struct PlaylistNavigationTests {
    private let testRoot: URL

    init() {
        testRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("nextTrack returns stream handoff for mixed playlist")
    func nextTrackReturnsStreamActionForMixedPlaylist() throws {
        let player = AudioPlayer()
        defer { player.stop() }

        let localURL = testRoot.appendingPathComponent("mono_test.wav")
        let localTrack = Track(url: localURL, title: "Local", artist: "Artist", duration: 10)
        let streamURL = try #require(URL(string: "https://example.com/stream"))
        let streamTrack = Track(url: streamURL, title: "Stream", artist: "", duration: 0)

        player.playlistController.addTrack(localTrack)
        player.playlistController.addTrack(streamTrack)
        player.currentTrack = localTrack
        player.updatePlaylistPosition(with: localTrack)

        let action = player.nextTrack()
        guard case .requestCoordinatorPlayback(let handoffTrack) = action else {
            Issue.record("Expected stream handoff from nextTrack, got \(action)")
            return
        }

        #expect(handoffTrack.id == streamTrack.id)
        #expect(player.playlist.count == 2)
    }

    @Test("previousTrack returns local playback when backing up from stream")
    func previousTrackReturnsLocalWhenBackingUpFromStream() throws {
        let player = AudioPlayer()
        defer { player.stop() }

        let localURL = testRoot.appendingPathComponent("mono_test.wav")
        let localTrack = Track(url: localURL, title: "Local", artist: "Artist", duration: 10)
        let streamURL = try #require(URL(string: "https://example.com/stream"))
        let streamTrack = Track(url: streamURL, title: "Stream", artist: "", duration: 0)

        player.playlistController.addTrack(localTrack)
        player.playlistController.addTrack(streamTrack)
        // Position at stream track (index 1) — "currently playing stream"
        player.updatePlaylistPosition(with: streamTrack)
        player.currentTrack = streamTrack

        let action = player.previousTrack()
        guard case .playLocally(let selectedTrack) = action else {
            Issue.record("Expected local playback when rewinding from stream, got \(action)")
            return
        }

        #expect(selectedTrack.id == localTrack.id)
        #expect(player.playlist.count == 2)
    }
}
