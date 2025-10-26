//
//  PlaylistMenuButton.swift
//  MacAmp
//
//  Playlist menu button that shows NSMenu with sprite-based items
//  Matches Winamp behavior: click to open, click-away to dismiss
//

import SwiftUI
import AppKit

/// Represents a single menu item with sprites and action
struct PlaylistMenuItem {
    let normalSprite: String
    let selectedSprite: String
    let action: () -> Void
}

/// Button that triggers an NSMenu with sprite-based menu items
/// Positioned at specific coordinates in playlist window
struct PlaylistMenuButton: NSViewRepresentable {
    let position: CGPoint
    let menuItems: [PlaylistMenuItem]
    @Binding var isOpen: Bool

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView(frame: NSRect(origin: .zero, size: CGSize(width: 22, height: 18)))

        // Create transparent button for click target
        let button = NSButton(frame: containerView.bounds)
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))

        containerView.addSubview(button)

        context.coordinator.containerView = containerView
        context.coordinator.button = button

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update coordinator with latest state
        context.coordinator.isOpen = isOpen
        context.coordinator.menuItems = menuItems
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOpen: $isOpen, menuItems: menuItems)
    }

    class Coordinator: NSObject, NSMenuDelegate {
        @Binding var isOpen: Bool
        var menuItems: [PlaylistMenuItem]
        weak var containerView: NSView?
        weak var button: NSButton?
        private var currentMenu: NSMenu?

        init(isOpen: Binding<Bool>, menuItems: [PlaylistMenuItem]) {
            self._isOpen = isOpen
            self.menuItems = menuItems
        }

        @objc func buttonClicked(_ sender: NSButton) {
            // Toggle menu
            if isOpen {
                closeMenu()
            } else {
                showMenu()
            }
        }

        private func showMenu() {
            guard let button = button else { return }

            let menu = NSMenu()
            menu.delegate = self
            menu.autoenablesItems = false

            // Create sprite-based menu items
            for (index, item) in menuItems.enumerated() {
                let menuItem = SpriteMenuItem(
                    normalSprite: item.normalSprite,
                    selectedSprite: item.selectedSprite,
                    action: #selector(menuItemClicked(_:)),
                    target: self
                )
                menuItem.tag = index
                menu.addItem(menuItem)
            }

            currentMenu = menu
            isOpen = true

            // Position menu above the button
            let location = NSPoint(x: 0, y: button.bounds.height)
            menu.popUp(positioning: nil, at: location, in: button)
        }

        private func closeMenu() {
            currentMenu?.cancelTracking()
            currentMenu = nil
            isOpen = false
        }

        @objc func menuItemClicked(_ sender: NSMenuItem) {
            let index = sender.tag
            guard index >= 0 && index < menuItems.count else { return }

            // Execute the action
            menuItems[index].action()

            // Close menu
            closeMenu()
        }

        // MARK: - NSMenuDelegate

        func menuDidClose(_ menu: NSMenu) {
            // Menu closed (via click-away or Esc)
            DispatchQueue.main.async { [weak self] in
                self?.isOpen = false
            }
        }
    }
}
