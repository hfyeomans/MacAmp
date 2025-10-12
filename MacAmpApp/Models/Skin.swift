
import SwiftUI
import AppKit
import Foundation

// MARK: - Fully Parsed Skin

// Represents a fully parsed Winamp skin.
struct Skin {
    // The 24 colors used by the visualizer.
    let visualizerColors: [Color]

    // Styling for the playlist editor.
    let playlistStyle: PlaylistStyle

    // A dictionary mapping sprite names (e.g., "MAIN_CLOSE_BUTTON")
    // to the actual image.
    let images: [String: NSImage]

    // A dictionary mapping cursor names to NSCursor objects.
    let cursors: [String: NSCursor]

    // TODO: Add properties for the other skin elements like
    // region, genLetterWidths, etc.
}

struct PlaylistStyle {
    let normalTextColor: Color
    let currentTextColor: Color
    let backgroundColor: Color
    let selectedBackgroundColor: Color
    let fontName: String?
}

// MARK: - Skin Metadata (for skin picker/switcher)

/// Metadata about an available skin (before it's fully loaded)
struct SkinMetadata: Identifiable, Hashable {
    let id: String          // Unique identifier (e.g., "bundled:Winamp" or "user:MySkin")
    let name: String        // Display name (e.g., "Classic Winamp")
    let url: URL            // Path to .wsz file
    let source: SkinSource  // Where the skin comes from

    /// Optional preview thumbnail (for future enhancement)
    var thumbnailURL: URL? = nil

    init(id: String, name: String, url: URL, source: SkinSource) {
        self.id = id
        self.name = name
        self.url = url
        self.source = source
    }
}

/// Source type for skin
enum SkinSource: Hashable {
    case bundled     // Shipped with app
    case user        // User-installed in ~/Library/Application Support/MacAmp/Skins/
    case temporary   // One-time load from arbitrary location
}

// MARK: - Bundled Skins

extension SkinMetadata {
    /// Built-in bundled skins
    static var bundledSkins: [SkinMetadata] {
        var skins: [SkinMetadata] = []

        // For SPM, resources are in Assets/ subdirectory
        // Try both paths for compatibility
        func findSkin(named name: String) -> URL? {
            NSLog("🔍 Searching for bundled skin: \(name)")
            // Try direct path first
            if let url = Bundle.main.url(forResource: name, withExtension: "wsz") {
                NSLog("✅ Found skin at root: \(url.path)")
                return url
            }
            // Try in Assets subdirectory
            if let url = Bundle.main.url(forResource: name, withExtension: "wsz", subdirectory: "Assets") {
                NSLog("✅ Found skin in Assets/: \(url.path)")
                return url
            }
            NSLog("❌ Skin not found in bundle: \(name).wsz")
            return nil
        }

        // Winamp default skin
        if let url = findSkin(named: "Winamp") {
            skins.append(SkinMetadata(
                id: "bundled:Winamp",
                name: "Classic Winamp",
                url: url,
                source: .bundled
            ))
        }

        // Internet Archive skin
        if let url = findSkin(named: "Internet-Archive") {
            skins.append(SkinMetadata(
                id: "bundled:Internet-Archive",
                name: "Internet Archive",
                url: url,
                source: .bundled
            ))
        }

        NSLog("🎁 SkinMetadata.bundledSkins: Found \(skins.count) bundled skins")
        return skins
    }
}
