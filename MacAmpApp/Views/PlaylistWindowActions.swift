import SwiftUI
import AppKit

@MainActor
final class PlaylistWindowActions: NSObject {
    static let shared = PlaylistWindowActions()

    var selectedIndices: Set<Int> = []
    weak var radioLibrary: RadioStationLibrary?

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func presentAddFilesPanel(audioPlayer: AudioPlayer, playbackCoordinator: PlaybackCoordinator? = nil) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .playlist, .movie]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Add Files to Playlist"
        openPanel.message = "Select audio files, video files, or playlists"

        openPanel.begin { response in
            if response == .OK {
                let urls = openPanel.urls
                Task { @MainActor [weak self, urls, audioPlayer, playbackCoordinator] in
                    guard let self else { return }

                    let wasEmpty = audioPlayer.playlist.isEmpty

                    self.handleSelectedURLs(urls, audioPlayer: audioPlayer)

                    if wasEmpty, let firstTrack = audioPlayer.currentTrack, let coordinator = playbackCoordinator {
                        await coordinator.play(track: firstTrack)
                    }

                    // Note: onPlaylistAdvanceRequest/onTrackMetadataUpdate are set in PlaybackCoordinator init
                    // Not here - setting them here would clobber coordinator's handlers
                }
            }
        }
    }

    private func handleSelectedURLs(_ urls: [URL], audioPlayer: AudioPlayer) {
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "m3u" || fileExtension == "m3u8" {
                if let radioLibrary {
                    loadM3UPlaylist(url, audioPlayer: audioPlayer, radioLibrary: radioLibrary)
                } else {
                    showAlert("Error", "Radio library not initialized. Please restart the app.")
                }
            } else {
                audioPlayer.addTrack(url: url)
            }
        }
    }

    private func loadM3UPlaylist(_ url: URL, audioPlayer: AudioPlayer, radioLibrary: RadioStationLibrary) {
        do {
            let entries = try M3UParser.parse(fileURL: url)
            var addedStreams = 0
            var addedFiles = 0

            for entry in entries {
                if entry.isRemoteStream {
                    let streamTrack = Track(
                        url: entry.url,
                        title: entry.title ?? "Unknown Station",
                        artist: "Internet Radio",
                        duration: 0.0
                    )
                    audioPlayer.addStreamTrack(streamTrack)
                    addedStreams += 1
                } else {
                    audioPlayer.addTrack(url: entry.url)
                    addedFiles += 1
                }
            }

            let alert = NSAlert()
            alert.messageText = "M3U Playlist Loaded"

            var message = ""
            if addedFiles > 0 {
                message += "Added \(addedFiles) local file(s)"
            }
            if addedStreams > 0 {
                if !message.isEmpty { message += "\n" }
                message += "Added \(addedStreams) internet radio stream(s)"
            }
            message += "\n\nAll items visible in playlist."

            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Load M3U Playlist"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func addURL(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            showAlert("Error", "Audio player not available")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Add Internet Radio Station"
        alert.informativeText = "Enter the stream URL (HTTP or HTTPS):"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "http://stream.example.com/radio.mp3"
        alert.accessoryView = input

        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let urlString = input.stringValue.trimmingCharacters(in: .whitespaces)

            guard !urlString.isEmpty else {
                showAlert("Invalid URL", "Please enter a valid URL")
                return
            }

            guard let url = URL(string: urlString),
                  url.scheme == "http" || url.scheme == "https" else {
                showAlert("Invalid URL", "URL must start with http:// or https://")
                return
            }

            let stationName = url.host ?? url.lastPathComponent
            let streamTrack = Track(
                url: url,
                title: stationName,
                artist: "Internet Radio",
                duration: 0.0
            )

            audioPlayer.addStreamTrack(streamTrack)

            showAlert("Stream Added", "Added '\(stationName)' to playlist.\n\nClick to play!")
        }
    }

    @objc func addDirectory(_ sender: NSMenuItem) {
        addFile(sender)
    }

    @objc func addFile(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }
        presentAddFilesPanel(audioPlayer: audioPlayer)
    }

    @objc func removeSelected(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }

        let indices = PlaylistWindowActions.shared.selectedIndices
        if indices.isEmpty {
            showAlert("Remove Selected", "No tracks selected")
        } else {
            for index in indices.sorted().reversed() {
                audioPlayer.removeTrack(at: index)
            }
            PlaylistWindowActions.shared.selectedIndices = []
        }
    }

    @objc func cropPlaylist(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }

        let indices = PlaylistWindowActions.shared.selectedIndices
        if indices.isEmpty {
            showAlert("Crop Playlist", "No tracks selected. Select tracks to keep, then crop.")
        } else {
            let validIndices = indices.sorted().filter { $0 < audioPlayer.playlist.count }
            let selectedTracks = validIndices.map { audioPlayer.playlist[$0] }
            audioPlayer.replacePlaylist(with: selectedTracks)
            PlaylistWindowActions.shared.selectedIndices = []
        }
    }

    @objc func removeAll(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }
        audioPlayer.clearPlaylist()
    }

    @objc func removeMisc(_ sender: NSMenuItem) {
        showAlert("Remove Misc", "Not supported yet")
    }

    @objc func sortList(_ sender: NSMenuItem) {
        showAlert("Sort List", "Not supported yet")
    }

    @objc func fileInfo(_ sender: NSMenuItem) {
        showAlert("File Info", "Not supported yet")
    }

    @objc func miscOptions(_ sender: NSMenuItem) {
        showAlert("Misc Options", "Not supported yet")
    }

    @objc func newList(_ sender: NSMenuItem) {
        showAlert("New List", "Not supported yet")
    }

    @objc func saveList(_ sender: NSMenuItem) {
        showAlert("Save List", "Not supported yet")
    }

    @objc func loadList(_ sender: NSMenuItem) {
        showAlert("Load List", "Not supported yet")
    }
}
