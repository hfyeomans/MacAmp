import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PresetsButton: View {
    let eqPresetsBtn: NSImage
    let eqPresetsBtnSel: NSImage
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var skinManager: SkinManager
    @State private var showPopover = false
    @State private var folderPresets: [(String, EqfPreset)] = []
    @State private var eqfFolderURL: URL? = nil

    private let folderDefaultsKey = "EQFPresetFolder"

    private func loadFolderURLFromDefaults() {
        if let path = UserDefaults.standard.string(forKey: folderDefaultsKey) {
            eqfFolderURL = URL(fileURLWithPath: path)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                eqfFolderURL = url
                UserDefaults.standard.set(url.path, forKey: folderDefaultsKey)
                loadPresetsFromFolder()
            }
        }
    }

    private func loadPresetsFromFolder() {
        folderPresets.removeAll()
        guard let folder = eqfFolderURL else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension.lowercased() == "eqf" {
            if let data = try? Data(contentsOf: url), let preset = EQFCodec.parse(data: data) {
                let name = preset.name ?? url.deletingPathExtension().lastPathComponent
                folderPresets.append((name, preset))
            }
        }
        folderPresets.sort { $0.0.lowercased() < $1.0.lowercased() }
    }

    private var builtins: [(String, EqfPreset)] {
        [
            ("Flat", EqfPreset(name: "Flat", preampDB: 0, bandsDB: Array(repeating: 0, count: 10))),
            ("Rock", EqfPreset(name: "Rock", preampDB: 0, bandsDB: [5, 3, 2, 0, -2, -3, -2, 0, 2, 3])),
            ("Pop", EqfPreset(name: "Pop", preampDB: 0, bandsDB: [-1, 2, 4, 5, 3, 0, -1, -1, 0, 0])),
            ("Classical", EqfPreset(name: "Classical", preampDB: 0, bandsDB: [3, 2, 0, -2, -3, -2, 0, 2, 3, 4])),
            ("Jazz", EqfPreset(name: "Jazz", preampDB: 0, bandsDB: [0, 2, 3, 3, 1, 0, 1, 3, 4, 5])),
            ("Bass", EqfPreset(name: "Bass", preampDB: -2, bandsDB: [6, 5, 4, 2, 0, -2, -4, -6, -7, -8])),
            ("Treble", EqfPreset(name: "Treble", preampDB: -2, bandsDB: [-6, -5, -4, -3, -2, 0, 2, 4, 6, 7])),
        ]
    }

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(nsImage: showPopover ? eqPresetsBtnSel : eqPresetsBtn)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 44, height: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                SkinnedText("Presets")
                    .environmentObject(skinManager)
                Divider()
                SkinnedText("Built-in")
                    .environmentObject(skinManager)
                ForEach(builtins, id: \.0) { name, preset in
                    Button(action: { audioPlayer.applyPreset(preset) }) {
                        SkinnedText(name)
                            .environmentObject(skinManager)
                    }
                }
                if !folderPresets.isEmpty {
                    Divider()
                    SkinnedText("Folder Presets")
                        .environmentObject(skinManager)
                    ForEach(Array(folderPresets.enumerated()), id: \.offset) { _, item in
                        Button(action: { audioPlayer.applyPreset(item.1) }) {
                            SkinnedText(item.0).environmentObject(skinManager)
                        }
                    }
                }
                Divider()
                Button(action: { audioPlayer.savePresetForCurrentTrack() }) {
                    SkinnedText("Save for This Track").environmentObject(skinManager)
                }
                Button(action: { Self.loadEqf(into: audioPlayer) }) {
                    SkinnedText("Load EQF...").environmentObject(skinManager)
                }
                Button(action: { Self.saveEqf(from: audioPlayer) }) {
                    SkinnedText("Save EQF...").environmentObject(skinManager)
                }
                Button(action: { chooseFolder() }) {
                    SkinnedText("Choose Folder...").environmentObject(skinManager)
                }
            }
            .padding(12)
            .frame(minWidth: 200)
            .onAppear {
                loadFolderURLFromDefaults()
                loadPresetsFromFolder()
            }
        }
    }

    private static func loadEqf(into player: AudioPlayer) {
        let open = NSOpenPanel()
        if let eqf = UTType(filenameExtension: "eqf") {
            open.allowedContentTypes = [eqf]
        }
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        open.begin { resp in
            if resp == .OK, let url = open.url, let data = try? Data(contentsOf: url), let preset = EQFCodec.parse(data: data) {
                player.applyPreset(preset)
            }
        }
    }

    private static func saveEqf(from player: AudioPlayer) {
        let save = NSSavePanel()
        if let eqf = UTType(filenameExtension: "eqf") {
            save.allowedContentTypes = [eqf]
        }
        save.nameFieldStringValue = "preset.eqf"
        save.begin { resp in
            if resp == .OK, let url = save.url {
                let preset = EqfPreset(name: nil, preampDB: player.preamp, bandsDB: player.eqBands)
                if let data = EQFCodec.serialize(preset) {
                    try? data.write(to: url)
                }
            }
        }
    }
}
