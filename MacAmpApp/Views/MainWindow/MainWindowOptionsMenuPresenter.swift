import SwiftUI
import AppKit

/// Bridges AppKit NSMenu to SwiftUI for the Options (O) button menu.
/// Absorbs MenuItemTarget and menu lifecycle management from the old extension.
@MainActor
final class MainWindowOptionsMenuPresenter {
    private var activeMenu: NSMenu?

    func showOptionsMenu(from buttonPosition: CGPoint, settings: AppSettings,
                         audioPlayer: AudioPlayer, isDoubleSizeMode: Bool) {
        let menu = NSMenu()
        activeMenu = menu

        buildOptionsMenuItems(menu: menu, settings: settings, audioPlayer: audioPlayer)

        let mainWindow = NSApp.windows.first { window in
            window.isVisible && !window.isMiniaturized &&
                (window.frame.width == WinampSizes.main.width ||
                 window.frame.width == WinampSizes.main.width * 2)
        } ?? NSApp.keyWindow

        if let window = mainWindow {
            let scale: CGFloat = isDoubleSizeMode ? 2.0 : 1.0
            let screenPoint = NSPoint(
                x: window.frame.minX + (buttonPosition.x * scale),
                y: window.frame.maxY - ((buttonPosition.y + 8) * scale)
            )
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
    }

    // MARK: - Menu Construction

    private func buildOptionsMenuItems(menu: NSMenu, settings: AppSettings, audioPlayer: AudioPlayer) {
        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Time: Elapsed",
            isChecked: settings.timeDisplayMode == .elapsed,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .elapsed {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Time: Remaining",
            isChecked: settings.timeDisplayMode == .remaining,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .remaining {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(.separator())

        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Double Size",
            isChecked: settings.isDoubleSizeMode,
            keyEquivalent: "d",
            modifiers: .control,
            action: { [weak settings] in
                settings?.isDoubleSizeMode.toggle()
            }
        ))

        buildRepeatShuffleMenuItems(menu: menu, audioPlayer: audioPlayer)
    }

    private func buildRepeatShuffleMenuItems(menu: NSMenu, audioPlayer: AudioPlayer) {
        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Repeat: Off",
            isChecked: audioPlayer.repeatMode == .off,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .off
            }
        ))

        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Repeat: All",
            isChecked: audioPlayer.repeatMode == .all,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .all
            }
        ))

        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Repeat: One",
            isChecked: audioPlayer.repeatMode == .one,
            keyEquivalent: "r",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .one
            }
        ))

        menu.addItem(MenuItemFactory.createMenuItem(
            title: "Shuffle",
            isChecked: audioPlayer.shuffleEnabled,
            keyEquivalent: "s",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.shuffleEnabled.toggle()
            }
        ))
    }

}
