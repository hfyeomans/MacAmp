import Foundation
import SwiftUI
import Observation

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

        // Load persisted clutter bar states (default to false)
        self.isDoubleSizeMode = UserDefaults.standard.bool(forKey: "isDoubleSizeMode")
        self.isAlwaysOnTop = UserDefaults.standard.bool(forKey: "isAlwaysOnTop")

        // Load persisted visualizer mode (default to spectrum)
        let rawMode = UserDefaults.standard.integer(forKey: "visualizerMode")
        self.visualizerMode = VisualizerMode(rawValue: rawMode) ?? .spectrum
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

    // MARK: - Double Size Mode

    /// Persists across app restarts - defaults to false (100% size)
    /// Note: Using didSet pattern instead of @AppStorage property wrapper
    /// to maintain @Observable reactivity
    var isDoubleSizeMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDoubleSizeMode, forKey: "isDoubleSizeMode")
        }
    }

    // MARK: - Always On Top Mode

    /// Persists across app restarts - defaults to false (normal window level)
    /// Note: Using didSet pattern to maintain @Observable reactivity
    var isAlwaysOnTop: Bool = false {
        didSet {
            UserDefaults.standard.set(isAlwaysOnTop, forKey: "isAlwaysOnTop")
        }
    }

    // MARK: - Clutter Bar States (Scaffolded for Future Implementation)

    /// O - Options Menu (not yet implemented)
    var showOptionsMenu: Bool = false

    /// I - Info Dialog (not yet implemented)
    var showInfoDialog: Bool = false

    // MARK: - Visualizer Mode

    /// Visualizer display modes
    enum VisualizerMode: Int, Codable, CaseIterable {
        case none = 0
        case spectrum = 1
        case oscilloscope = 2
    }

    /// Current visualizer mode - click analyzer to cycle
    var visualizerMode: VisualizerMode = .spectrum {
        didSet {
            UserDefaults.standard.set(visualizerMode.rawValue, forKey: "visualizerMode")
        }
    }

}
