import SwiftUI
import AppKit

@MainActor
final class PlaylistWindowActions: NSObject {
    static let shared = PlaylistWindowActions()

    var selectedIndices: Set<Int> = []
    weak var radioLibrary: RadioStationLibrary?

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
        openPanel.allowedContentTypes = [.audio, .playlist]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Add Files to Playlist"
        openPanel.message = "Select audio files or playlists"

        openPanel.begin { response in
            if response == .OK {
                let urls = openPanel.urls
                Task { @MainActor [weak self, urls, audioPlayer, playbackCoordinator] in
                    guard let self else { return }

                    // Remember if playlist was empty (for autoplay detection)
                    let wasEmpty = audioPlayer.playlist.isEmpty

                    self.handleSelectedURLs(urls, audioPlayer: audioPlayer)

                    // If playlist was empty and AudioPlayer autoplayed, sync coordinator state
                    if wasEmpty, let firstTrack = audioPlayer.currentTrack, let coordinator = playbackCoordinator {
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
                // Load M3U/M3U8 files using radioLibrary
                if let radioLibrary {
                    loadM3UPlaylist(url, audioPlayer: audioPlayer, radioLibrary: radioLibrary)
                } else {
                    // Fallback if radioLibrary not available (shouldn't happen)
                    showAlert("Error", "Radio library not initialized. Please restart the app.")
                }
            } else {
                audioPlayer.addTrack(url: url)
            }
        }
    }

    private func loadM3UPlaylist(_ url: URL, audioPlayer: AudioPlayer, radioLibrary: RadioStationLibrary) {
        do {
            let entries = try M3UParser.parse(fileURL: url)
            var addedStreams = 0
            var addedFiles = 0

            for entry in entries {
                if entry.isRemoteStream {
                    // Add to playlist as Track (Winamp behavior)
                    // RadioStationLibrary is ONLY for favorites menu (Phase 5+)
                    let streamTrack = Track(
                        url: entry.url,
                        title: entry.title ?? "Unknown Station",
                        artist: "Internet Radio",
                        duration: 0.0  // Streams have no duration
                    )
                    audioPlayer.playlist.append(streamTrack)
                    addedStreams += 1
                } else {
                    // Add local file to playlist
                    audioPlayer.addTrack(url: entry.url)
                    addedFiles += 1
                }
            }

            // Show feedback
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
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Load M3U Playlist"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
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

            // Add to playlist as Track (Winamp behavior)
            // RadioStationLibrary is ONLY for favorites menu (Phase 5+)
            let stationName = url.host ?? url.lastPathComponent
            let streamTrack = Track(
                url: url,
                title: stationName,
                artist: "Internet Radio",
                duration: 0.0
            )

            audioPlayer.playlist.append(streamTrack)

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
        presentAddFilesPanel(audioPlayer: audioPlayer)
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
                if index < audioPlayer.playlist.count {
                    audioPlayer.playlist.remove(at: index)
                }
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
            audioPlayer.playlist = selectedTracks
            PlaylistWindowActions.shared.selectedIndices = []
        }
    }

    @objc func removeAll(_ sender: NSMenuItem) {
        guard let audioPlayer = sender.representedObject as? AudioPlayer else {
            return
        }
        audioPlayer.playlist = []
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
        showAlert("New List", "Not supported yet")
    }

    @objc func saveList(_ sender: NSMenuItem) {
        showAlert("Save List", "Not supported yet")
    }

    @objc func loadList(_ sender: NSMenuItem) {
        showAlert("Load List", "Not supported yet")
    }
}

struct WinampPlaylistWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(RadioStationLibrary.self) var radioLibrary
    @Environment(PlaybackCoordinator.self) var playbackCoordinator

    @State private var selectedIndices: Set<Int> = []
    @State private var isShadeMode: Bool = false
    @State private var keyboardMonitor: Any?
    @State private var menuDelegate = PlaylistMenuDelegate()  // Phase 3: NSMenuDelegate for keyboard nav

    private let windowWidth: CGFloat = 275
    private let windowHeight: CGFloat = 232

    private var totalPlaylistDuration: Double {
        audioPlayer.playlist.reduce(0.0) { total, track in
            total + track.duration
        }
    }

    private var remainingTime: Double {
        guard audioPlayer.currentDuration > 0 else { return 0 }
        return max(0, audioPlayer.currentDuration - audioPlayer.currentTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private var trackTimeText: String {
        guard audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ":"
        }

        let current = formatTime(audioPlayer.currentTime)
        let total = formatTime(totalPlaylistDuration)
        return "\(current) / \(total)"
    }

    private var remainingTimeText: String {
        guard audioPlayer.isPlaying,
              audioPlayer.currentTrack != nil,
              audioPlayer.currentDuration > 0 else {
            return ""
        }

        let remaining = formatTime(remainingTime)
        return "-\(remaining)"
    }

    private var playlistStyle: PlaylistStyle {
        skinManager.currentSkin?.playlistStyle ?? PlaylistStyle(
            normalTextColor: Color(red: 0, green: 1.0, blue: 0),
            currentTextColor: .white,
            backgroundColor: Color.black,
            selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
            fontName: nil
        )
    }

    private var playlistBackgroundColor: Color {
        playlistStyle.backgroundColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !isShadeMode {
                    buildCompleteBackground()
                    buildContentOverlay()
                } else {
                    buildShadeMode()
                }
            }
            .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        }
        .frame(width: windowWidth, height: isShadeMode ? 14 : windowHeight)
        .onAppear {
            // Store monitor reference to keep it alive
            keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                return handleKeyPress(event: event)
            }

            // Inject radioLibrary into shared actions for ADD URL functionality
            PlaylistWindowActions.shared.radioLibrary = radioLibrary
        }
        .onDisappear {
            // Clean up keyboard monitor
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
    }
    
    private func handleKeyPress(event: NSEvent) -> NSEvent? {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectedIndices = Set(0..<audioPlayer.playlist.count)
            return nil
        }

        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d") {
            selectedIndices = []
            return nil
        }

        return event
    }

    @ViewBuilder
    private func buildCompleteBackground() -> some View {
            SimpleSpriteImage("PLAYLIST_TOP_LEFT_CORNER", width: 25, height: 20)
                .position(x: 12.5, y: 10)
            
            ForEach(0..<10, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_TOP_TILE", width: 25, height: 20)
                    .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
            }
            
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 100, height: 20)
                .position(x: 137.5, y: 10)
                .gesture(WindowDragGesture())
            
            SimpleSpriteImage("PLAYLIST_TOP_RIGHT_CORNER", width: 25, height: 20)
                .position(x: 262.5, y: 10)
            
            let sideHeight = 192
            let leftTileCount = Int(ceil(CGFloat(sideHeight) / 29))
            ForEach(0..<leftTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_LEFT_TILE", width: 12, height: 29)
                    .position(x: 6, y: 20 + 14.5 + CGFloat(i) * 29)
            }
            
            ForEach(0..<leftTileCount, id: \.self) { i in
                SimpleSpriteImage("PLAYLIST_RIGHT_TILE", width: 20, height: 29)
                    .position(x: 265, y: 20 + 14.5 + CGFloat(i) * 29)
            }
            
            HStack(spacing: 0) {
                SimpleSpriteImage("PLAYLIST_BOTTOM_LEFT_CORNER", width: 125, height: 38)
                    .frame(width: 125, height: 38)

                SimpleSpriteImage("PLAYLIST_BOTTOM_RIGHT_CORNER", width: 154, height: 38)
                    .frame(width: 154, height: 38)
            }
            .frame(width: windowWidth, height: 38)
            .position(x: (windowWidth / 2) + 2, y: 213)  // Shift entire HStack 2px right
    }
    
    @ViewBuilder
    private func buildContentOverlay() -> some View {
            playlistBackgroundColor
                .frame(width: 243, height: 170)
                .position(x: 133.5, y: 105)

            buildTrackList()
                .frame(width: 243, height: 174)
                .position(x: 133.5, y: 107)
                .clipped()
            
            buildBottomControls()
            buildPlaylistTransportButtons()
            buildTimeDisplays()
            buildTitleBarButtons()
            
        SimpleSpriteImage("PLAYLIST_SCROLL_HANDLE", width: 8, height: 18)
            .position(x: 260, y: 30)
    }
    
    @ViewBuilder
    private func buildTrackList() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
                    trackRow(track: track, index: index)
                        .frame(width: 243, height: 13)
                        .background(trackBackground(track: track, index: index))
                        .onTapGesture(count: 2) {
                            // Double-click: Play via PlaybackCoordinator (handles both local + streams)
                            Task {
                                await playbackCoordinator.play(track: track)
                            }
                        }
                        .onTapGesture {
                            // Single-click: Handle selection
                            let modifiers = NSEvent.modifierFlags

                            if modifiers.contains(.shift) {
                                if selectedIndices.contains(index) {
                                    selectedIndices.remove(index)
                                } else {
                                    selectedIndices.insert(index)
                                }
                            } else {
                                selectedIndices = [index]
                            }
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func trackRow(track: Track, index: Int) -> some View {
        let textColor = trackTextColor(track: track)
        HStack(spacing: 2) {
            // Track number - real text instead of bitmap font
            Text("\(index + 1).")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 18, alignment: .trailing)

            // Track title and artist - real text instead of bitmap font
            Text("\(track.title) - \(track.artist)")
                .font(.system(size: 9))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            // Duration - real text instead of bitmap font
            Text(formatDuration(track.duration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 38, alignment: .trailing)
                .padding(.trailing, 3)
        }
        .padding(.horizontal, 2)
    }
    
    @ViewBuilder
    private func buildBottomControls() -> some View {
        Button(action: { showAddMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: 16, y: 208)

        Button(action: { showRemMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: 42, y: 208)

        Button(action: { showSelNotSupportedAlert() }) {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: 78, y: 208)

        Button(action: { showMiscMenu() }) {
            Color.clear.frame(width: 18, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: 105, y: 208)

        Button(action: { showListMenu() }) {
            Color.clear.frame(width: 22, height: 18).contentShape(Rectangle())
        }.buttonStyle(.plain).position(x: 243, y: 208)
    }

    @ViewBuilder
    private func buildPlaylistTransportButtons() -> some View {
            Button(action: {
                Task { await playbackCoordinator.previous() }
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 133, y: 220)

            Button(action: {
                playbackCoordinator.togglePlayPause()
        }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 144, y: 220)

            Button(action: {
                playbackCoordinator.pause()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 155, y: 220)

            Button(action: {
                playbackCoordinator.stop()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 166, y: 220)

            Button(action: {
                Task { await playbackCoordinator.next() }
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 177, y: 220)

            Button(action: {
                openFileDialog()
            }) {
                Color.clear
                    .frame(width: 10, height: 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 183, y: 220)
    }

    @ViewBuilder
    private func buildTimeDisplays() -> some View {
            PlaylistTimeText(trackTimeText)
                .position(x: 176, y: 206)

        if !remainingTimeText.isEmpty {
            PlaylistTimeText(remainingTimeText)
                .position(x: 203, y: 219)
        }
    }

    @ViewBuilder
    private func buildTitleBarButtons() -> some View {
            Button(action: { NSApp.keyWindow?.miniaturize(nil) }) {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 248.5, y: 7.5)
            
            Button(action: {
                isShadeMode.toggle()
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 258.5, y: 7.5)
            
            Button(action: { NSApp.keyWindow?.close() }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .position(x: 268.5, y: 7.5)
    }

    @ViewBuilder
    private func buildShadeMode() -> some View {
        ZStack {
            SimpleSpriteImage("PLAYLIST_TITLE_BAR", width: 275, height: 14)
                .position(x: 137.5, y: 7)

            if let currentTrack = playbackCoordinator.currentTrack {
                Text("\(currentTrack.title) - \(currentTrack.artist)")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 200)
                    .position(x: 100, y: 7)
            } else {
                Text("Winamp Playlist")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .position(x: 100, y: 7)
            }

            buildTitleBarButtons()
        }
        .frame(width: windowWidth, height: 14)
    }

    private func trackTextColor(track: Track) -> Color {
        // Use coordinator's current track for highlighting
        if let currentTrack = playbackCoordinator.currentTrack, currentTrack.url == track.url {
            return playlistStyle.currentTextColor
        }
        return playlistStyle.normalTextColor
    }

    private func trackBackground(track: Track, index: Int) -> Color {
        // Only show background for selected tracks (not current track)
        if selectedIndices.contains(index) {
            return playlistStyle.selectedBackgroundColor.opacity(0.6)
        }
        return Color.clear
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func openFileDialog() {
        PlaylistWindowActions.shared.presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
    }

    
    private func removeSelectedTrack() {
        guard let index = selectedIndices.first,
              index < audioPlayer.playlist.count else { return }
        audioPlayer.playlist.remove(at: index)
        selectedIndices.remove(index)
    }

    private func showAddMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Phase 3: Enable keyboard navigation

        let addURLItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_URL",
            selectedSprite: "PLAYLIST_ADD_URL_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addURL),
            target: PlaylistWindowActions.shared
        )
        addURLItem.representedObject = audioPlayer
        menu.addItem(addURLItem)

        let addDirItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_DIR",
            selectedSprite: "PLAYLIST_ADD_DIR_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addDirectory),
            target: PlaylistWindowActions.shared
        )
        addDirItem.representedObject = audioPlayer
        menu.addItem(addDirItem)

        let addFileItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_ADD_FILE",
            selectedSprite: "PLAYLIST_ADD_FILE_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.addFile),
            target: PlaylistWindowActions.shared
        )
        addFileItem.representedObject = audioPlayer
        menu.addItem(addFileItem)

        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
           let contentView = window.contentView {
            let location = NSPoint(x: 10, y: 396)
            menu.popUp(positioning: nil, at: location, in: contentView)
        }
    }

    private func showRemMenu() {
        PlaylistWindowActions.shared.selectedIndices = selectedIndices

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Phase 3: Enable keyboard navigation

        let remMiscItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_MISC",
            selectedSprite: "PLAYLIST_REMOVE_MISC_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeMisc),
            target: PlaylistWindowActions.shared
        )
        remMiscItem.representedObject = audioPlayer
        menu.addItem(remMiscItem)

        let remAllItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_ALL",
            selectedSprite: "PLAYLIST_REMOVE_ALL_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeAll),
            target: PlaylistWindowActions.shared
        )
        remAllItem.representedObject = audioPlayer
        menu.addItem(remAllItem)

        let cropItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_CROP",
            selectedSprite: "PLAYLIST_CROP_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.cropPlaylist),
            target: PlaylistWindowActions.shared
        )
        cropItem.representedObject = audioPlayer
        menu.addItem(cropItem)

        let remSelItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_REMOVE_SELECTED",
            selectedSprite: "PLAYLIST_REMOVE_SELECTED_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.removeSelected),
            target: PlaylistWindowActions.shared
        )
        remSelItem.representedObject = audioPlayer
        menu.addItem(remSelItem)

        if let window = NSApplication.shared.windows.first(where: { $0.contentView != nil }),
           let contentView = window.contentView {
            let location = NSPoint(x: 39, y: 378)
            menu.popUp(positioning: nil, at: location, in: contentView)
        }
    }

    private func showSelNotSupportedAlert() {
        let alert = NSAlert()
        alert.messageText = "Selection Menu"
        alert.informativeText = "Not supported yet. Use Shift+click for multi-select (planned feature)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showMiscMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Phase 3: Enable keyboard navigation

        let sortItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_SORT_LIST",
            selectedSprite: "PLAYLIST_SORT_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.sortList),
            target: PlaylistWindowActions.shared
        )
        sortItem.representedObject = audioPlayer
        menu.addItem(sortItem)

        let fileInfoItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_FILE_INFO",
            selectedSprite: "PLAYLIST_FILE_INFO_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.fileInfo),
            target: PlaylistWindowActions.shared
        )
        fileInfoItem.representedObject = audioPlayer
        menu.addItem(fileInfoItem)

        let miscOptionsItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_MISC_OPTIONS",
            selectedSprite: "PLAYLIST_MISC_OPTIONS_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.miscOptions),
            target: PlaylistWindowActions.shared
        )
        miscOptionsItem.representedObject = audioPlayer
        menu.addItem(miscOptionsItem)

        if let window = NSApplication.shared.windows.first(where: { $0.contentView != nil }),
           let contentView = window.contentView {
            let location = NSPoint(x: 100, y: 397)
            menu.popUp(positioning: nil, at: location, in: contentView)
        }
    }

    private func showListMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate  // Phase 3: Enable keyboard navigation

        let newListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_NEW_LIST",
            selectedSprite: "PLAYLIST_NEW_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.newList),
            target: PlaylistWindowActions.shared
        )
        newListItem.representedObject = audioPlayer
        menu.addItem(newListItem)

        let saveListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_SAVE_LIST",
            selectedSprite: "PLAYLIST_SAVE_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.saveList),
            target: PlaylistWindowActions.shared
        )
        saveListItem.representedObject = audioPlayer
        menu.addItem(saveListItem)

        let loadListItem = SpriteMenuItem(
            normalSprite: "PLAYLIST_LOAD_LIST",
            selectedSprite: "PLAYLIST_LOAD_LIST_SELECTED",
            skinManager: skinManager,
            action: #selector(PlaylistWindowActions.loadList),
            target: PlaylistWindowActions.shared
        )
        loadListItem.representedObject = audioPlayer
        menu.addItem(loadListItem)

        if let window = NSApplication.shared.windows.first(where: { $0.contentView != nil }),
           let contentView = window.contentView {
            let location = NSPoint(x: 228, y: 397)
            menu.popUp(positioning: nil, at: location, in: contentView)
        }
    }
}

extension SimpleSpriteImage {
    func position(x: CGFloat, y: CGFloat) -> some View {
        self.position(CGPoint(x: x, y: y))
    }
}

#Preview {
    WinampPlaylistWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
        .environment(AppSettings.instance())
}
