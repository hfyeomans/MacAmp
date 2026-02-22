import SwiftUI
import AppKit

@MainActor
struct PlaylistMenuPresenter {
    let skinManager: SkinManager
    let audioPlayer: AudioPlayer
    let menuDelegate: PlaylistMenuDelegate
    let windowHeight: CGFloat
    let windowWidth: CGFloat
    let selectedIndices: Set<Int>

    private func playlistContentView() -> NSView? {
        if let view = WindowCoordinator.shared?.playlistWindow?.contentView {
            return view
        }
        return NSApp.keyWindow?.contentView
    }

    private func presentPlaylistMenu(_ menu: NSMenu, at point: NSPoint) {
        guard let contentView = playlistContentView() else { return }
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    func showAddMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate

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

        presentPlaylistMenu(menu, at: NSPoint(x: 12, y: windowHeight - 68))
    }

    func showRemMenu() {
        PlaylistWindowActions.shared.selectedIndices = selectedIndices

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate

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

        presentPlaylistMenu(menu, at: NSPoint(x: 41, y: windowHeight - 87))
    }

    func showSelNotSupportedAlert() {
        let alert = NSAlert()
        alert.messageText = "Selection Menu"
        alert.informativeText = "Not supported yet. Use Shift+click for multi-select (planned feature)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showMiscMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate

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

        presentPlaylistMenu(menu, at: NSPoint(x: 100, y: windowHeight - 68))
    }

    func showListMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = menuDelegate

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

        presentPlaylistMenu(menu, at: NSPoint(x: windowWidth - 46, y: windowHeight - 68))
    }
}
