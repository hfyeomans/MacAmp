import Foundation
import SwiftUI
import Observation
import AppKit

/// Material integration levels for Liquid Glass UI support
enum MaterialIntegrationLevel: String, CaseIterable, Codable {
    case classic = "classic"
    case hybrid = "hybrid"
    case modern = "modern"

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .hybrid: return "Hybrid"
        case .modern: return "Modern"
        }
    }

    var description: String {
        switch self {
        case .classic: return "Traditional Winamp appearance with custom backgrounds"
        case .hybrid: return "Winamp chrome with macOS 26 Tahoe material containers"
        case .modern: return "Full macOS 26 Tahoe materials integration"
        }
    }
}

/// Global app settings for MacAmp
@Observable
@MainActor
final class AppSettings {
    var materialIntegration: MaterialIntegrationLevel {
        didSet {
            UserDefaults.standard.set(materialIntegration.rawValue, forKey: "MaterialIntegration")
        }
    }

    var enableLiquidGlass: Bool {
        didSet {
            UserDefaults.standard.set(enableLiquidGlass, forKey: "EnableLiquidGlass")
        }
    }

    @ObservationIgnored private static let shared = AppSettings()

    private init() {
        self.materialIntegration = Self.loadMaterialIntegration()
        self.enableLiquidGlass = Self.loadLiquidGlassSetting()

        // Load persisted double-size mode (defaults to false for 100% size)
        self.isDoubleSizeMode = UserDefaults.standard.bool(forKey: "isDoubleSizeMode")
        print("🚀 AppSettings initialized - isDoubleSizeMode: \(self.isDoubleSizeMode)")
    }
    
    static func instance() -> AppSettings {
        return shared
    }
    
    /// Whether to use system container backgrounds
    var shouldUseContainerBackground: Bool {
        guard enableLiquidGlass else { return false }
        return materialIntegration == .hybrid || materialIntegration == .modern
    }
    
    /// Whether to preserve custom Winamp chrome
    var shouldPreserveWinampChrome: Bool {
        return materialIntegration == .classic || materialIntegration == .hybrid
    }
    
    /// Whether to use full system materials
    var shouldUseFullSystemMaterials: Bool {
        guard enableLiquidGlass else { return false }
        return materialIntegration == .modern
    }

    // MARK: - Skin Settings

    /// Key for storing the selected skin identifier
    private static let selectedSkinKey = "SelectedSkinIdentifier"

    /// The currently selected skin identifier
    var selectedSkinIdentifier: String? {
        get {
            UserDefaults.standard.string(forKey: Self.selectedSkinKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.selectedSkinKey)
        }
    }

    /// Directory for user-installed skins
    static func userSkinsDirectory(fileManager: FileManager = .default) throws -> URL {
        try ensureSkinsDirectory(fileManager: fileManager)
    }

    private static func loadMaterialIntegration() -> MaterialIntegrationLevel {
        guard let savedRaw = UserDefaults.standard.string(forKey: "MaterialIntegration"),
              let saved = MaterialIntegrationLevel(rawValue: savedRaw) else {
            return .hybrid
        }
        return saved
    }

    private static func loadLiquidGlassSetting() -> Bool {
        guard let stored = UserDefaults.standard.object(forKey: "EnableLiquidGlass") as? Bool else {
            return true
        }
        return stored
    }

    @discardableResult
    static func ensureSkinsDirectory(
        fileManager: FileManager = .default,
        base: URL? = nil
    ) throws -> URL {
        let appSupport: URL
        if let base {
            appSupport = base
        } else {
            appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        let macampDir = appSupport.appendingPathComponent("MacAmp", isDirectory: true)
        let skinsDir = macampDir.appendingPathComponent("Skins", isDirectory: true)
        try fileManager.createDirectory(at: skinsDir, withIntermediateDirectories: true)
        return skinsDir
    }

    static func fallbackSkinsDirectory(fileManager: FileManager = .default) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("MacAmp/FallbackSkins", isDirectory: true)
    }

    // MARK: - Window Management (Double-Size Mode)

    /// Weak reference to prevent retain cycles
    weak var mainWindow: NSWindow?

    /// Base window size for scale calculations (not position)
    var baseWindowSize: NSSize = NSSize(width: 275, height: 116)

    // Note: Window observer removed to avoid Swift 6 concurrency issues
    // The dynamic targetWindowFrame calculation handles position preservation

    // MARK: - Double Size Mode

    /// Persists across app restarts - defaults to false (100% size)
    /// Note: Using didSet pattern instead of @AppStorage property wrapper
    /// to maintain @Observable reactivity
    var isDoubleSizeMode: Bool = false {
        didSet {
            print("📐 isDoubleSizeMode changed: \(oldValue) → \(isDoubleSizeMode)")
            UserDefaults.standard.set(isDoubleSizeMode, forKey: "isDoubleSizeMode")
        }
    }

    // MARK: - Clutter Bar States (Scaffolded)

    /// O - Options Menu (not yet implemented)
    var showOptionsMenu: Bool = false

    /// A - Always On Top (not yet implemented)
    var isAlwaysOnTop: Bool = false

    /// I - Info Dialog (not yet implemented)
    var showInfoDialog: Bool = false

    /// V - Visualizer Mode (not yet implemented)
    var visualizerMode: Int = 0

    // MARK: - Dynamic Frame Calculation

    /// Computes target frame based on current window position (no snap-back!)
    var targetWindowFrame: NSRect? {
        guard let window = mainWindow else { return nil }

        // Capture current top-left corner (anchor point)
        let currentTopLeft = NSPoint(
            x: window.frame.origin.x,
            y: window.frame.maxY  // macOS uses bottom-left origin
        )

        // Calculate target size based on mode
        let targetSize = isDoubleSizeMode
            ? NSSize(width: baseWindowSize.width * 2, height: baseWindowSize.height * 2)
            : baseWindowSize

        // Build frame from top-left anchor
        return NSRect(
            x: currentTopLeft.x,
            y: currentTopLeft.y - targetSize.height,  // Subtract height to position from top
            width: targetSize.width,
            height: targetSize.height
        )
    }

}
