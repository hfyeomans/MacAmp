import Foundation
import Observation

/// Coordinates playback between local files (AudioPlayer) and internet radio streams (StreamPlayer).
///
/// This coordinator prevents both backends from playing simultaneously, which would cause audio chaos.
/// It provides a unified API for the UI to play content regardless of source type.
///
/// **Architecture:**
/// - Local files (.mp3, .flac, etc.) → AudioPlayer with 10-band EQ
/// - Internet radio (http://, https://) → StreamPlayer (AVPlayer, no EQ)
///
/// **Usage:**
/// ```swift
/// // Play a file URL
/// await coordinator.play(url: fileURL)
///
/// // Play a radio station
/// await coordinator.play(station: myStation)
///
/// // Unified controls
/// coordinator.pause()
/// coordinator.stop()
/// coordinator.togglePlayPause()
/// ```
///
/// **State Queries:**
/// - `streamTitle` - Current track/stream title
/// - `streamArtist` - Stream artist (radio only)
/// - `isBuffering` - Buffering state (radio only)
/// - `error` - Error message if playback failed
@MainActor
@Observable
final class PlaybackCoordinator {
    // MARK: - Dependencies

    private let audioPlayer: AudioPlayer       // Local files with EQ
    private let streamPlayer: StreamPlayer     // Internet radio

    // MARK: - Unified State

    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var currentSource: PlaybackSource?
    private(set) var currentTitle: String?

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    // MARK: - Initialization

    init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
        self.audioPlayer = audioPlayer
        self.streamPlayer = streamPlayer
    }

    // MARK: - Unified Playback Control

    func play(url: URL) async {
        if url.isFileURL {
            // Stop stream if playing
            streamPlayer.stop()

            // Play local file with EQ
            audioPlayer.addTrack(url: url)
            audioPlayer.play()
            currentSource = .localTrack(url)
            currentTitle = url.deletingPathExtension().lastPathComponent
            isPlaying = audioPlayer.isPlaying
        } else {
            // Stop local file if playing
            audioPlayer.stop()

            // Play stream (no EQ)
            let station = RadioStation(name: url.lastPathComponent, streamURL: url)
            await streamPlayer.play(station: station)
            currentSource = .radioStation(station)
            currentTitle = streamPlayer.streamTitle ?? station.name
            isPlaying = streamPlayer.isPlaying
        }

        isPaused = false
    }

    func play(station: RadioStation) async {
        // Stop local file if playing
        audioPlayer.stop()

        // Play stream
        await streamPlayer.play(station: station)
        currentSource = .radioStation(station)
        currentTitle = streamPlayer.streamTitle ?? station.name
        isPlaying = streamPlayer.isPlaying
        isPaused = false
    }

    func pause() {
        switch currentSource {
        case .localTrack:
            audioPlayer.pause()
            isPlaying = audioPlayer.isPlaying
        case .radioStation:
            streamPlayer.pause()
            isPlaying = streamPlayer.isPlaying
        case .none:
            break
        }

        isPaused = true
    }

    func stop() {
        audioPlayer.stop()
        streamPlayer.stop()
        isPlaying = false
        isPaused = false
        currentSource = nil
        currentTitle = nil
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    private func resume() {
        switch currentSource {
        case .localTrack:
            audioPlayer.play()
            isPlaying = audioPlayer.isPlaying
        case .radioStation(let station):
            Task {
                await streamPlayer.play(station: station)
                isPlaying = streamPlayer.isPlaying
            }
        case .none:
            break
        }

        isPaused = false
    }

    // MARK: - State Queries

    var streamTitle: String? {
        switch currentSource {
        case .localTrack(let url):
            return url.deletingPathExtension().lastPathComponent
        case .radioStation:
            return streamPlayer.streamTitle
        case .none:
            return nil
        }
    }

    var streamArtist: String? {
        streamPlayer.streamArtist
    }

    var isBuffering: Bool {
        streamPlayer.isBuffering
    }

    var error: String? {
        streamPlayer.error
    }
}
