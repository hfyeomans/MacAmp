import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppCommands: Commands {
    @Bindable var dockingController: DockingController
    @Bindable var audioPlayer: AudioPlayer
    @Bindable var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Windows") {
            Button(dockingController.showMain ? "Hide Main" : "Show Main") { dockingController.toggleMain() }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button(dockingController.showPlaylist ? "Hide Playlist" : "Show Playlist") { dockingController.togglePlaylist() }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button(dockingController.showEqualizer ? "Hide Equalizer" : "Show Equalizer") { dockingController.toggleEqualizer() }
                .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("Shade/Unshade Main") { dockingController.toggleShade(.main) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Shade/Unshade Playlist") { dockingController.toggleShade(.playlist) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Shade/Unshade Equalizer") { dockingController.toggleShade(.equalizer) }
                .keyboardShortcut("3", modifiers: [.command, .option])

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

            // Vertical stacking - no horizontal movement needed
            // Windows now stack vertically in fixed order: Main -> EQ -> Playlist
        }
        
        CommandGroup(replacing: .newItem) {
            Button("Open Files...") {
                presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        CommandGroup(replacing: .appSettings) {
            Button("Preferences...") {
                openWindow(id: "preferences")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Audio Files"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                audioPlayer.addTrack(url: url)
            }
        }
    }
}
