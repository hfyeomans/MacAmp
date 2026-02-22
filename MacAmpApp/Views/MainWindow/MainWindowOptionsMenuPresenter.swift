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
        menu.addItem(createMenuItem(
            title: "Time: Elapsed",
            isChecked: settings.timeDisplayMode == .elapsed,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .elapsed {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(createMenuItem(
            title: "Time: Remaining",
            isChecked: settings.timeDisplayMode == .remaining,
            action: { [weak settings] in
                if settings?.timeDisplayMode != .remaining {
                    settings?.toggleTimeDisplayMode()
                }
            }
        ))

        menu.addItem(.separator())

        menu.addItem(createMenuItem(
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
        menu.addItem(createMenuItem(
            title: "Repeat: Off",
            isChecked: audioPlayer.repeatMode == .off,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .off
            }
        ))

        menu.addItem(createMenuItem(
            title: "Repeat: All",
            isChecked: audioPlayer.repeatMode == .all,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .all
            }
        ))

        menu.addItem(createMenuItem(
            title: "Repeat: One",
            isChecked: audioPlayer.repeatMode == .one,
            keyEquivalent: "r",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.repeatMode = .one
            }
        ))

        menu.addItem(createMenuItem(
            title: "Shuffle",
            isChecked: audioPlayer.shuffleEnabled,
            keyEquivalent: "s",
            modifiers: .control,
            action: { [weak audioPlayer] in
                audioPlayer?.shuffleEnabled.toggle()
            }
        ))
    }

    // MARK: - Menu Item Factory

    private func createMenuItem(
        title: String,
        isChecked: Bool,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.state = isChecked ? .on : .off
        item.keyEquivalentModifierMask = modifiers

        let actionTarget = MenuItemActionTarget(action: action)
        item.target = actionTarget
        item.action = #selector(MenuItemActionTarget.execute)
        item.representedObject = actionTarget

        return item
    }
}

/// Bridges closures to NSMenuItem @objc action selectors.
@MainActor
private class MenuItemActionTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func execute() {
        action()
    }
}
