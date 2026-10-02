import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppCommands: Commands {
    var windowCoordinator: WindowCoordinator
    @Bindable var audioPlayer: AudioPlayer
    @Bindable var settings: AppSettings
    var playbackCoordinator: PlaybackCoordinator

    var body: some Commands {
        CommandMenu("Options") {
            Button(windowCoordinator.isMainWindowVisible ? "Hide Main" : "Show Main") { windowCoordinator.toggleMain() }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button(windowCoordinator.isPlaylistWindowVisible ? "Hide Playlist" : "Show Playlist") { _ = windowCoordinator.togglePlaylistWindowVisibility() }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button(windowCoordinator.isEQWindowVisible ? "Hide Equalizer" : "Show Equalizer") { _ = windowCoordinator.toggleEQWindowVisibility() }
                .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("Shade/Unshade Main") { settings.isMainWindowShaded.toggle() }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Shade/Unshade Playlist") { settings.isPlaylistWindowShaded.toggle() }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Shade/Unshade Equalizer") { settings.isEqualizerWindowShaded.toggle() }
                .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Windowshade Mode") { settings.isMainWindowShaded.toggle() }
                .keyboardShortcut("w", modifiers: [.control])
            Button("Minimize All") { windowCoordinator.minimizeApp() }
                .keyboardShortcut("m", modifiers: [.option])
                .disabled(!windowCoordinator.isMainWindowVisible)

            Button("Reset Window Positions") { windowCoordinator.resetWindowPositions() }

            Divider()

            // Clutter bar functions
            Button(settings.isDoubleSizeMode ? "Normal Size" : "Double Size") {
                settings.isDoubleSizeMode.toggle()
            }
            .keyboardShortcut("d", modifiers: [.control])

            Button(settings.isAlwaysOnTop ? "Disable Always On Top" : "Enable Always On Top") {
                settings.isAlwaysOnTop.toggle()
            }
            .keyboardShortcut("a", modifiers: [.control])

            Button("Options Menu") {
                settings.showOptionsMenuTrigger = true
            }
            .keyboardShortcut("o", modifiers: [.control])

            Button("Time: \(settings.timeDisplayMode == .elapsed ? "Show Remaining" : "Show Elapsed")") {
                settings.toggleTimeDisplayMode()
            }
            .keyboardShortcut("t", modifiers: [.control])

            Button("Track Information") {
                settings.showTrackInfoDialog = true
            }
            .keyboardShortcut("i", modifiers: [.control])

            Button(audioPlayer.repeatMode.label) {
                audioPlayer.repeatMode = audioPlayer.repeatMode.next()
            }
            .keyboardShortcut("r", modifiers: [.control])

            // Video Window toggle - setting change triggers observer
            Button(settings.showVideoWindow ? "Hide Video Window" : "Show Video Window") {
                settings.showVideoWindow.toggle()
            }
            .keyboardShortcut("v", modifiers: [.control])

            // Milkdrop Window toggle - setting change triggers observer
            Button(settings.showMilkdropWindow ? "Hide Milkdrop" : "Show Milkdrop") {
                settings.showMilkdropWindow.toggle()
            }
            .keyboardShortcut("k", modifiers: [.control])

            // NOTE: Ctrl+1/Ctrl+2 removed - VIDEO window now uses drag resize with 1x/2x button presets

            // Vertical stacking - no horizontal movement needed
            // Windows now stack vertically in fixed order: Main -> EQ -> Playlist
        }
        
        CommandGroup(replacing: .newItem) {
            Button("Open Files...") {
                presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        // MacAmp has no settings window; hide the empty "Settings…" item.
        CommandGroup(replacing: .appSettings) {}
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Audio Files"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in
                let wasEmpty = audioPlayer.playlist.isEmpty
                for url in panel.urls {
                    audioPlayer.addTrack(url: url)
                }
                if wasEmpty, let firstTrack = audioPlayer.playlist.first {
                    await playbackCoordinator.play(track: firstTrack)
                }
            }
        }
    }
}
