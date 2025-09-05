import SwiftUI

struct AppCommands: Commands {
    let dockingController: DockingController

    var body: some Commands {
        CommandMenu("View") {
            Button(dockingController.showMain ? "Hide Main" : "Show Main") { dockingController.toggleMain() }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button(dockingController.showPlaylist ? "Hide Playlist" : "Show Playlist") { dockingController.togglePlaylist() }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button(dockingController.showEqualizer ? "Hide Equalizer" : "Show Equalizer") { dockingController.toggleEqualizer() }
                .keyboardShortcut("3", modifiers: [.command, .shift])
        }
    }
}
