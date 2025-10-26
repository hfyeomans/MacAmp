//
//  PlaylistMenuButton.swift
//  MacAmp
//
//  Playlist menu button components
//  NOTE: Currently not used - menu functionality implemented directly in WinampPlaylistWindow
//

import SwiftUI
import AppKit

/// Represents a single menu item with sprites and action
struct PlaylistMenuItem {
    let normalSprite: String
    let selectedSprite: String
    let action: () -> Void
}

// NOTE: Menu button functionality currently implemented directly in WinampPlaylistWindow.showAddMenu()
// This file kept for future refactoring if we want to make menus reusable components
