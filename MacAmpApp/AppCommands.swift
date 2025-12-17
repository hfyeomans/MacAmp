import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AppCommands: Commands {
    @Bindable var dockingController: DockingController
    @Bindable var audioPlayer: AudioPlayer
    @Bindable var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Options") {
            Button(dockingController.showMain ? "Hide Main" : "Show Main") { dockingController.toggleMain() }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button(dockingController.showPlaylist ? "Hide Playlist" : "Show Playlist") { dockingController.togglePlaylist() }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button(dockingController.showEqualizer ? "Hide Equalizer" : "Show Equalizer") { dockingController.toggleEqualizer() }
                .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("Shade/Unshade Main") { settings.isMainWindowShaded.toggle() }
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
