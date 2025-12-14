
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

    // Track which optional sheets were actually loaded (not fallback)
    let loadedSheets: Set<String>

    // Additional skin elements (region maps, letter widths, etc.) can be added as parsing expands.
}

// MARK: - Video Window Sprite Access

extension Skin {
    /// Check if VIDEO sprites are available (either from this skin or default fallback)
    var hasVideoSprites: Bool {
        // Check if VIDEO sprites exist in images dictionary
        // This works whether they came from current skin or default Winamp fallback
        return images["VIDEO_TITLEBAR_TOP_CENTER_ACTIVE"] != nil
    }
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

        AppLog.debug(.skin, "Bundle path: \(bundleURL.path)")
        AppLog.debug(.skin, "Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        AppLog.debug(.skin, "Resource URL: \(Bundle.main.resourceURL?.path ?? "nil")")

        // SPM places resources directly at bundle root, not in subdirectories
        // Use direct path construction instead of url(forResource:withExtension:)
        func findSkin(named name: String) -> URL? {
            let filename = "\(name).wsz"
            AppLog.debug(.skin, "Searching for bundled skin: \(filename)")

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
            AppLog.debug(.skin, "Checking path: \(bundleRootURL.path)")

            if isUsableSkin(at: bundleRootURL) {
                AppLog.info(.skin, "Found \(filename) at: \(bundleRootURL.path)")
                return bundleRootURL
            }

            // Fallback: Try Skins subdirectory (for cases where SPM nests resources)
            let skinsURL = bundleURL.appendingPathComponent("Skins").appendingPathComponent(filename)
            AppLog.debug(.skin, "Checking fallback path: \(skinsURL.path)")

            if isUsableSkin(at: skinsURL) {
                AppLog.info(.skin, "Found \(filename) in Skins/: \(skinsURL.path)")
                return skinsURL
            }

            AppLog.error(.skin, "Skin not found in bundle: \(filename)")
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

        // KenWood KDC 7000 Elite skin
        if let url = findSkin(named: "KenWood_KDC_7000_Elite") {
            skins.append(SkinMetadata(
                id: "bundled:KenWood-KDC-7000",
                name: "KenWood KDC-7000 Elite",
                url: url,
                source: .bundled
            ))
        }

        // Mac OS X skin
        if let url = findSkin(named: "Mac_OS-X_skin") {
            skins.append(SkinMetadata(
                id: "bundled:Mac-OS-X",
                name: "Mac OS X",
                url: url,
                source: .bundled
            ))
        }

        // Sony MP3 Player skin
        if let url = findSkin(named: "Sony_MP3_Player_") {
            skins.append(SkinMetadata(
                id: "bundled:Sony-MP3",
                name: "Sony MP3 Player",
                url: url,
                source: .bundled
            ))
        }

        AppLog.info(.skin, "Total bundled skins found: \(skins.count)")
        for skin in skins {
            AppLog.debug(.skin, "  \(skin.name) [\(skin.id)] -> \(skin.url.path)")
        }

        return skins
    }
}
