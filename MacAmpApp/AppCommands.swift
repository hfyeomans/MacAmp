import SwiftUI

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Windows") {
            Button("Show Playlist") { openWindow(id: "playlistWindow") }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("Show Equalizer") { openWindow(id: "equalizerWindow") }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

