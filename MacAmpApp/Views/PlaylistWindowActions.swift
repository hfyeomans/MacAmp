import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class PlaylistWindowActions: NSObject {
    static let shared = PlaylistWindowActions()

    var selectedIndices: Set<Int> = []
    weak var radioLibrary: RadioStationLibrary?
    weak var playbackCoordinator: PlaybackCoordinator?

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
        let m3uType = UTType(filenameExtension: "m3u") ?? .plainText
        let m3u8Type = UTType(filenameExtension: "m3u8") ?? .plainText
        openPanel.allowedContentTypes = [.audio, m3uType, m3u8Type, .movie]
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

                    // Auto-play first track via coordinator when playlist was empty
                    let coordinator = playbackCoordinator ?? self.playbackCoordinator
                    if wasEmpty, let firstTrack = audioPlayer.playlist.first, let coordinator {
                        await coordinator.play(track: firstTrack)
                    }
                }
            }
        }
    }

    private func handleSelectedURLs(_ urls: [URL], audioPlayer: AudioPlayer) {
        for url in urls {
            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "m3u" || fileExtension == "m3u8" {
                loadM3UPlaylist(url, audioPlayer: audioPlayer)
            } else {
                audioPlayer.addTrack(url: url)
            }
        }
    }

    private func loadM3UPlaylist(_ url: URL, audioPlayer: AudioPlayer) {
        Task.detached(priority: .userInitiated) {
            let result: Result<[M3UEntry], Error>
            do {
                result = .success(try M3UParser.parse(fileURL: url))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                switch result {
                case .success(let entries):
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

                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Failed to Load M3U Playlist"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
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
        presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
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
        guard let audioPlayer = sender.representedObject as? AudioPlayer else { return }
        audioPlayer.clearPlaylist()
    }

    @objc func saveList(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else { return }
        guard !audioPlayer.playlist.isEmpty else {
            showAlert("Save List", "Playlist is empty")
            return
        }

        let savePanel = NSSavePanel()
        let m3uSaveType = UTType(filenameExtension: "m3u") ?? .plainText
        savePanel.allowedContentTypes = [m3uSaveType]
        savePanel.nameFieldStringValue = "playlist.m3u"
        savePanel.title = "Save Playlist"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let tracks = audioPlayer.playlist
                Task.detached(priority: .userInitiated) {
                    do {
                        try M3UWriter.write(tracks: tracks, to: url)
                    } catch {
                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "Failed to Save Playlist"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }

    @objc func loadList(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else { return }

        let m3uType = UTType(filenameExtension: "m3u") ?? .plainText
        let m3u8Type = UTType(filenameExtension: "m3u8") ?? .plainText

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [m3uType, m3u8Type]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "Load Playlist"
        openPanel.message = "Select an M3U playlist file"

        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task.detached(priority: .userInitiated) {
                    // Parse off main actor to avoid blocking UI
                    let result: Result<[M3UEntry], Error>
                    do {
                        result = .success(try M3UParser.parse(fileURL: url))
                    } catch {
                        result = .failure(error)
                    }

                    switch result {
                    case .success(let entries):
                        await MainActor.run {
                            // LOAD LIST replaces the playlist (Winamp behavior)
                            audioPlayer.clearPlaylist()
                            for entry in entries {
                                if entry.isRemoteStream {
                                    let streamTrack = Track(
                                        url: entry.url,
                                        title: entry.title ?? "Unknown Station",
                                        artist: "Internet Radio",
                                        duration: 0.0
                                    )
                                    audioPlayer.addStreamTrack(streamTrack)
                                } else {
                                    audioPlayer.addTrack(url: entry.url)
                                }
                            }
                        }
                        // Auto-play first track via coordinator (capture in same MainActor hop)
                        let (firstTrack, coordinator): (Track?, PlaybackCoordinator?) = await MainActor.run {
                            (audioPlayer.playlist.first, self.playbackCoordinator)
                        }
                        if let track = firstTrack, let coordinator {
                            await coordinator.play(track: track)
                        }
                    case .failure(let error):
                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "Failed to Load Playlist"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }
}
