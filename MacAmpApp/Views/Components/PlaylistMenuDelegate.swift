//
//  PlaylistMenuDelegate.swift
//  MacAmp
//
//  Created for Phase 3: NSMenuDelegate pattern implementation
//  Enables keyboard navigation and VoiceOver support for sprite-based menus
//

import AppKit

/// Delegate that manages highlighting for sprite-based menu items
/// Handles both mouse hover and keyboard navigation (arrow keys, Enter, Escape)
/// Enables VoiceOver accessibility for menu items
@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    /// Called when a menu item is about to be highlighted (mouse hover OR keyboard navigation)
    /// This is the key method that enables keyboard navigation support
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update all sprite menu items in this menu
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                // Highlight if this is the item being highlighted, unhighlight otherwise
                sprite.spriteHighlighted = (menuItem === item)
            }
        }
    }
}
