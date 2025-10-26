//
//  SpriteMenuItem.swift
//  MacAmp
//
//  Created for playlist menu system - sprite-based menu items with hover states
//

import SwiftUI
import AppKit

/// Custom NSMenuItem that displays a sprite and swaps to selected sprite on hover
class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private var hostingView: NSHostingView<SpriteMenuItemView>?
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false {
        didSet {
            updateView()
        }
    }

    init(normalSprite: String, selectedSprite: String, action: Selector?, target: AnyObject?) {
        self.normalSpriteName = normalSprite
        self.selectedSpriteName = selectedSprite

        super.init(title: "", action: action, keyEquivalent: "")
        self.target = target

        setupView()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupView() {
        let spriteView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHovered: isHovered
        )

        let hosting = NSHostingView(rootView: spriteView)
        hosting.frame = NSRect(x: 0, y: 0, width: 22, height: 18)

        // Add tracking area for hover detection
        let trackingArea = NSTrackingArea(
            rect: hosting.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        hosting.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea

        self.view = hosting
        self.hostingView = hosting
    }

    private func updateView() {
        guard let hostingView = hostingView else { return }

        let updatedView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHovered: isHovered
        )

        hostingView.rootView = updatedView
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}

/// SwiftUI view that renders a sprite, swapping between normal and selected states
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHovered: Bool

    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        SimpleSpriteImage(
            isHovered ? selectedSprite : normalSprite,
            width: 22,
            height: 18
        )
        .frame(width: 22, height: 18)
    }
}
