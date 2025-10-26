//
//  SpriteMenuItem.swift
//  MacAmp
//
//  Created for playlist menu system - sprite-based menu items with hover states
//

import SwiftUI
import AppKit

/// Custom view that handles hover tracking and click forwarding to menu item
class HoverTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    weak var menuItem: NSMenuItem?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }

        // Add new tracking area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        // Forward click to the menu item's action
        // This is the key fix - custom views block NSMenuItem clicks
        if let menuItem = menuItem,
           let action = menuItem.action,
           let target = menuItem.target {
            NSApp.sendAction(action, to: target, from: menuItem)
        }

        // Close the menu after click
        if let enclosingMenu = menuItem?.menu {
            enclosingMenu.cancelTracking()
        }
    }
}

/// Custom NSMenuItem that displays a sprite and swaps to selected sprite on hover
class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager
    private var hostingView: NSHostingView<SpriteMenuItemView>?
    private var hoverTrackingView: HoverTrackingView?
    private var isHovered: Bool = false {
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
        // Create container view for hover tracking and click forwarding
        let container = HoverTrackingView(frame: NSRect(x: 0, y: 0, width: 22, height: 18))
        container.onHoverChanged = { [weak self] hovered in
            self?.isHovered = hovered
        }
        container.menuItem = self  // Connect view to menu item for click forwarding

        // Create SwiftUI sprite view with skinManager injected
        let spriteView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHovered: isHovered,
            skinManager: skinManager
        )

        let hosting = NSHostingView(rootView: spriteView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]

        container.addSubview(hosting)

        self.view = container
        self.hostingView = hosting
        self.hoverTrackingView = container
    }

    private func updateView() {
        guard let hostingView = hostingView else { return }

        let updatedView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHovered: isHovered,
            skinManager: skinManager
        )

        hostingView.rootView = updatedView
    }
}

/// SwiftUI view that renders a sprite, swapping between normal and selected states
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHovered: Bool
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHovered ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .resizable()
                .frame(width: 22, height: 18)
        } else {
            // Fallback if sprite not found
            Color.gray
                .frame(width: 22, height: 18)
        }
    }
}
