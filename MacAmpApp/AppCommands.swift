import SwiftUI

struct AppCommands: Commands {
    let dockingController: DockingController
    let skinManager: SkinManager
    @StateObject private var settings = AppSettings.instance()
    @Environment(\.openWindow) private var openWindow

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

            // Vertical stacking - no horizontal movement needed
            // Windows now stack vertically in fixed order: Main -> EQ -> Playlist
        }
        
        CommandMenu("Appearance") {
            Menu("Material Integration: \(settings.materialIntegration.displayName)") {
                ForEach(MaterialIntegrationLevel.allCases, id: \.rawValue) { level in
                    Button(level.displayName) {
                        settings.materialIntegration = level
                    }
                    .help(level.description)
                }
            }
            
            Toggle("Enable Liquid Glass", isOn: $settings.enableLiquidGlass)
                .help("Enable modern macOS material effects")
                
            Divider()
            
            Button("Preferences...") {
                openWindow(id: "preferences")
            }
            .keyboardShortcut(",")
        }

        // MARK: - Debug Menu for Phase 1 Testing
        CommandMenu("Debug") {
            Section("Skin Switching Test") {
                Button("Switch to Classic Winamp") {
                    skinManager.switchToSkin(identifier: "bundled:Winamp")
                }
                .keyboardShortcut("1", modifiers: [.command, .control])

                Button("Switch to Internet Archive") {
                    skinManager.switchToSkin(identifier: "bundled:Internet-Archive")
                }
                .keyboardShortcut("2", modifiers: [.command, .control])
            }

            Divider()

            Section("Skin Info") {
                Text("Available Skins: \(skinManager.availableSkins.count)")
                    .disabled(true)

                if let current = skinManager.availableSkins.first(where: {
                    AppSettings.instance().selectedSkinIdentifier == $0.id
                }) {
                    Text("Current: \(current.name)")
                        .disabled(true)
                }
            }
        }
    }
}
