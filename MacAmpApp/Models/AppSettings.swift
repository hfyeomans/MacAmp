import Foundation
import SwiftUI

/// Spectrum analyzer frequency mapping modes
enum SpectrumFrequencyMapping: String, CaseIterable, Codable {
    case logarithmic = "logarithmic"
    case adjustedLog = "adjustedLog"
    case hybrid = "hybrid"

    var displayName: String {
        switch self {
        case .logarithmic: return "Logarithmic (Original)"
        case .adjustedLog: return "Adjusted Log (Balanced)"
        case .hybrid: return "Hybrid (Webamp-style)"
        }
    }

    var description: String {
        switch self {
        case .logarithmic: return "Original logarithmic scaling - bass-focused"
        case .adjustedLog: return "Gentler curve - more mid-range representation"
        case .hybrid: return "91% log + 9% linear - matches Winamp feel"
        }
    }
}

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
@MainActor
final class AppSettings: ObservableObject {
    @Published var spectrumFrequencyMapping: SpectrumFrequencyMapping {
        didSet {
            UserDefaults.standard.set(spectrumFrequencyMapping.rawValue, forKey: "SpectrumFrequencyMapping")
        }
    }

    @Published var materialIntegration: MaterialIntegrationLevel {
        didSet {
            UserDefaults.standard.set(materialIntegration.rawValue, forKey: "MaterialIntegration")
        }
    }

    @Published var enableLiquidGlass: Bool {
        didSet {
            UserDefaults.standard.set(enableLiquidGlass, forKey: "EnableLiquidGlass")
        }
    }

    private static let shared = AppSettings()

    private init() {
        self.spectrumFrequencyMapping = Self.loadSpectrumMapping()
        self.materialIntegration = Self.loadMaterialIntegration()
        self.enableLiquidGlass = Self.loadLiquidGlassSetting()
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

    private static func loadSpectrumMapping() -> SpectrumFrequencyMapping {
        guard let savedRaw = UserDefaults.standard.string(forKey: "SpectrumFrequencyMapping"),
              let saved = SpectrumFrequencyMapping(rawValue: savedRaw) else {
            return .hybrid  // Default to webamp-style hybrid
        }
        return saved
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
}
