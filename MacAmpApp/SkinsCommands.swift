import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Commands for the Skins menu
struct SkinsCommands: Commands {
    @ObservedObject var skinManager: SkinManager

    var body: some Commands {
        CommandMenu("Skins") {
            // Current skin indicator
            Section {
                if skinManager.currentSkin != nil,
                   let currentMetadata = skinManager.availableSkins.first(where: { $0.id == AppSettings.instance().selectedSkinIdentifier }) {
                    Text("Current: \(currentMetadata.name)")
                        .disabled(true)
                }
            }

            Divider()

            // Bundled skins
            Section("Bundled Skins") {
                ForEach(skinManager.availableSkins.filter { $0.source == .bundled }) { skin in
                    Button(skin.name) {
                        skinManager.switchToSkin(identifier: skin.id)
                    }
                    .keyboardShortcut(keyboardShortcut(for: skin))
                }
            }

            // User-installed skins (if any)
            let userSkins = skinManager.availableSkins.filter { $0.source == .user }
            if !userSkins.isEmpty {
                Divider()
                Section("My Skins") {
                    ForEach(userSkins) { skin in
                        Button(skin.name) {
                            skinManager.switchToSkin(identifier: skin.id)
                        }
                    }
                }
            }

            Divider()

            // File operations
            Section {
                Button("Import Skin File...") {
                    openSkinFilePicker()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Open Skins Folder") {
                    do {
                        let directory = try AppSettings.userSkinsDirectory()
                        NSWorkspace.shared.open(directory)
                    } catch {
                        skinManager.loadingError = "Unable to open skins folder: \(error.localizedDescription)"
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            Divider()

            // Refresh
            Section {
                Button("Refresh Skins") {
                    skinManager.scanAvailableSkins()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }

    // MARK: - Helper Methods

    /// Generate keyboard shortcut for bundled skins (Cmd+Shift+1, Cmd+Shift+2, etc.)
    private func keyboardShortcut(for skin: SkinMetadata) -> KeyboardShortcut? {
        let bundledSkins = skinManager.availableSkins.filter { $0.source == .bundled }
        if let index = bundledSkins.firstIndex(where: { $0.id == skin.id }) {
            if index < 9 {
                let key = String(index + 1)
                return KeyboardShortcut(KeyEquivalent(Character(key)), modifiers: [.command, .shift])
            }
        }
        return nil
    }

    /// Open file picker to select and import a .wsz skin file
    private func openSkinFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Winamp Skin"
        panel.message = "Choose a .wsz skin file to import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "wsz")].compactMap { $0 }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                await skinManager.importSkin(from: url)
            }
        }
    }
}
