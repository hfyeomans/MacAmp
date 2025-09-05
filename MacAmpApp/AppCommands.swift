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

            Divider()

            Button("Shade/Unshade Main") { dockingController.toggleShade(.main) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Shade/Unshade Playlist") { dockingController.toggleShade(.playlist) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Shade/Unshade Equalizer") { dockingController.toggleShade(.equalizer) }
                .keyboardShortcut("3", modifiers: [.command, .option])

            Divider()

            Button("Move Main Left") { dockingController.moveVisiblePane(type: .main, toVisibleIndex: 0) }
            Button("Move Main Right") {
                let count = dockingController.panes.filter{ $0.visible }.count
                dockingController.moveVisiblePane(type: .main, toVisibleIndex: max(0, count - 1))
            }
        }
    }
}
