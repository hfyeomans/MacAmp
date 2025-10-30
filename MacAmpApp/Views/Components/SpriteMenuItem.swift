//
//  SpriteMenuItem.swift
//  MacAmp
//
//  Created for playlist menu system - sprite-based menu items with hover states
//  Phase 3: Refactored to use NSMenuDelegate pattern for keyboard navigation
//

import SwiftUI
import AppKit

/// Minimal view that forwards clicks to the menu item
/// No hover tracking - delegate handles highlighting
final class ClickForwardingView: NSView {
    weak var menuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        // Forward click to menu item action
        if let menuItem = menuItem,
           let action = menuItem.action,
           let target = menuItem.target {
            NSApp.sendAction(action, to: target, from: menuItem)
        }
        menuItem?.menu?.cancelTracking()
    }
}

/// Custom NSMenuItem that displays a sprite and swaps to selected sprite on highlight
/// Highlighting is managed by PlaylistMenuDelegate for both mouse and keyboard navigation
@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager
    private var hostingView: NSHostingView<SpriteMenuItemView>?

    /// Custom highlighted state set by PlaylistMenuDelegate
    /// Handles both mouse hover and keyboard navigation
    /// Note: Different from NSMenuItem's built-in isHighlighted
    var spriteHighlighted: Bool = false {
        didSet {
            updateView()
        }
    }

    init(normalSprite: String, selectedSprite: String, skinManager: SkinManager, action: Selector?, target: AnyObject?) {
        self.normalSpriteName = normalSprite
        self.selectedSpriteName = selectedSprite
        self.skinManager = skinManager

        super.init(title: "", action: action, keyEquivalent: "")
        self.target = target

        setupView()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupView() {
        // Create click forwarding container (NO hover tracking - delegate handles highlighting)
        let container = ClickForwardingView(frame: NSRect(x: 0, y: 0, width: 22, height: 18))
        container.menuItem = self

        // Create SwiftUI sprite view
        let spriteView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHighlighted: spriteHighlighted,
            skinManager: skinManager
        )

        let hosting = NSHostingView(rootView: spriteView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]

        container.addSubview(hosting)

        self.view = container
        self.hostingView = hosting
    }

    private func updateView() {
        guard let hostingView = hostingView else { return }

        let updatedView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHighlighted: spriteHighlighted,
            skinManager: skinManager
        )

        hostingView.rootView = updatedView
    }
}

/// SwiftUI view that renders a sprite, swapping between normal and selected states
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHighlighted: Bool
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHighlighted ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 22, height: 18)
        } else {
            // Fallback if sprite not found
            Color.gray
                .frame(width: 22, height: 18)
        }
    }
}
