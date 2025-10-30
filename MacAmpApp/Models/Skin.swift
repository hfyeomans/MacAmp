
import SwiftUI
import AppKit
import Foundation

// MARK: - Fully Parsed Skin

// Represents a fully parsed Winamp skin.
/// SAFETY: Skin instances are immutable (all let properties) and accessed only via @MainActor SkinManager
struct Skin: @unchecked Sendable {
    // The 24 colors used by the visualizer.
    let visualizerColors: [Color]

    // Styling for the playlist editor.
    let playlistStyle: PlaylistStyle

    // A dictionary mapping sprite names (e.g., "MAIN_CLOSE_BUTTON")
    // to the actual image.
    let images: [String: NSImage]

    // A dictionary mapping cursor names to NSCursor objects.
    let cursors: [String: NSCursor]

    // Additional skin elements (region maps, letter widths, etc.) can be added as parsing expands.
}

struct PlaylistStyle: Sendable {
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

        // Determine the correct bundle URL based on build type, guarding against missing resources
        #if SWIFT_PACKAGE
        let baseURL = Bundle.module.resourceURL ?? Bundle.module.bundleURL
        #else
        let baseURL = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        #endif

        var bundleURL = baseURL
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: bundleURL.path, isDirectory: &isDir) || !isDir.boolValue {
            // Fall back to bundle root if resource path isn't a directory
            bundleURL = Bundle.main.bundleURL
        }

        NSLog("🔍 Bundle path: \(bundleURL.path)")
        NSLog("🔍 Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        NSLog("🔍 Resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")

        // SPM places resources directly at bundle root, not in subdirectories
        // Use direct path construction instead of url(forResource:withExtension:)
        func findSkin(named name: String) -> URL? {
            let filename = "\(name).wsz"
            NSLog("🔍 Searching for bundled skin: \(filename)")

            func isUsableSkin(at url: URL) -> Bool {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue,
                      fileManager.isReadableFile(atPath: url.path) else {
                    return false
                }
                return true
            }

            // Construct direct path to bundle root
            let bundleRootURL = bundleURL.appendingPathComponent(filename)
            NSLog("🔍 Checking path: \(bundleRootURL.path)")

            if isUsableSkin(at: bundleRootURL) {
                NSLog("✅ Found \(filename) at: \(bundleRootURL.path)")
                return bundleRootURL
            }

            // Fallback: Try Skins subdirectory (for cases where SPM nests resources)
            let skinsURL = bundleURL.appendingPathComponent("Skins").appendingPathComponent(filename)
            NSLog("🔍 Checking fallback path: \(skinsURL.path)")

            if isUsableSkin(at: skinsURL) {
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

        // Tron Vaporwave skin
        if let url = findSkin(named: "Tron-Vaporwave-by-LuigiHann") {
            skins.append(SkinMetadata(
                id: "bundled:Tron-Vaporwave",
                name: "Tron Vaporwave",
                url: url,
                source: .bundled
            ))
        }

        // Winamp3 Classified skin
        if let url = findSkin(named: "Winamp3_Classified_v5.5") {
            skins.append(SkinMetadata(
                id: "bundled:Winamp3-Classified",
                name: "Winamp3 Classified",
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
