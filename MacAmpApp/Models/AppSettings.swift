import Foundation
import SwiftUI

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
        // Load material integration preference
        if let savedRaw = UserDefaults.standard.string(forKey: "MaterialIntegration"),
           let saved = MaterialIntegrationLevel(rawValue: savedRaw) {
            self.materialIntegration = saved
        } else {
            self.materialIntegration = .hybrid // Default for macOS 26 Tahoe
        }
        
        // Load Liquid Glass preference (defaults to true for macOS 26 Tahoe)
        self.enableLiquidGlass = UserDefaults.standard.object(forKey: "EnableLiquidGlass") as? Bool ?? true
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
}