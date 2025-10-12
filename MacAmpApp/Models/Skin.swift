
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
        let fileManager = FileManager.default

        // Determine the correct bundle URL based on build type
        let bundleURL: URL
        #if SWIFT_PACKAGE
        // For SPM command-line builds: Use Bundle.module which points to the resource bundle
        bundleURL = Bundle.module.bundleURL
        #else
        // For Xcode app builds: Use Bundle.main.resourceURL which points to Contents/Resources/
        // Fall back to bundleURL if resourceURL is nil (shouldn't happen in practice)
        bundleURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        #endif

        NSLog("🔍 Bundle path: \(bundleURL.path)")
        NSLog("🔍 Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        NSLog("🔍 Resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")

        // SPM places resources directly at bundle root, not in subdirectories
        // Use direct path construction instead of url(forResource:withExtension:)
        func findSkin(named name: String) -> URL? {
            let filename = "\(name).wsz"
            NSLog("🔍 Searching for bundled skin: \(filename)")

            // Construct direct path to bundle root
            let bundleRootURL = bundleURL.appendingPathComponent(filename)
            NSLog("🔍 Checking path: \(bundleRootURL.path)")

            if fileManager.fileExists(atPath: bundleRootURL.path) {
                NSLog("✅ Found \(filename) at: \(bundleRootURL.path)")
                return bundleRootURL
            }

            // Fallback: Try Skins subdirectory (for cases where SPM nests resources)
            let skinsURL = bundleURL.appendingPathComponent("Skins").appendingPathComponent(filename)
            NSLog("🔍 Checking fallback path: \(skinsURL.path)")

            if fileManager.fileExists(atPath: skinsURL.path) {
                NSLog("✅ Found \(filename) in Skins/: \(skinsURL.path)")
                return skinsURL
            }

            NSLog("❌ Skin not found in bundle: \(filename)")
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

        NSLog("🎁 Total bundled skins found: \(skins.count)")
        for skin in skins {
            NSLog("  📦 \(skin.name) [\(skin.id)] -> \(skin.url.path)")
        }

        return skins
    }
}
