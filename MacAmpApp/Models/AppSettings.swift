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
        self.isMainWindowShaded = UserDefaults.standard.bool(forKey: "isMainWindowShaded")
        self.showVideoWindow = UserDefaults.standard.bool(forKey: "showVideoWindow")
        self.showMilkdropWindow = UserDefaults.standard.bool(forKey: "showMilkdropWindow")

        // NOTE: videoWindowSizeMode loading removed - Size2D persisted in VideoWindowSizeState

        // Load persisted time display mode (default to elapsed)
        if let rawTimeMode = UserDefaults.standard.string(forKey: "timeDisplayMode"),
           let mode = TimeDisplayMode(rawValue: rawTimeMode) {
            self.timeDisplayMode = mode
        } else {
            self.timeDisplayMode = .elapsed
        }

        // Load persisted visualizer mode (default to spectrum)
        let rawMode = UserDefaults.standard.integer(forKey: "visualizerMode")
        self.visualizerMode = VisualizerMode(rawValue: rawMode) ?? .spectrum

        // Load repeat mode with migration from old boolean (preserves user preference)
        if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
           let mode = RepeatMode(rawValue: savedMode) {
            self.repeatMode = mode
        } else {
            // Migrate from old boolean key: true → .all, false → .off
            let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
            self.repeatMode = oldRepeat ? .all : .off
        }

        // Load Butterchurn settings (with sensible defaults)
        self.butterchurnRandomize = UserDefaults.standard.object(forKey: "butterchurnRandomize") as? Bool ?? true
        self.butterchurnCycling = UserDefaults.standard.object(forKey: "butterchurnCycling") as? Bool ?? true
        let savedInterval = UserDefaults.standard.double(forKey: "butterchurnCycleInterval")
        self.butterchurnCycleInterval = savedInterval > 0 ? savedInterval : 15.0
        self.butterchurnTrackTitleInterval = UserDefaults.standard.double(forKey: "butterchurnTrackTitleInterval")
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

    static func fallbackSkinsDirectory() -> URL {
        // URL.cachesDirectory is available in macOS 13+ and is non-optional.
        // .appending(component:directoryHint:) is the modern path API.
        URL.cachesDirectory
            .appending(component: "MacAmp", directoryHint: .isDirectory)
            .appending(component: "FallbackSkins", directoryHint: .isDirectory)
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

    // MARK: - Main Window Shade Mode

    /// Tracks whether the main window is in shade mode (14px compact bar)
    /// Used by playlist window to show mini visualizer when main visualizer is hidden
    /// Persists across app restarts - defaults to false (full window)
    var isMainWindowShaded: Bool = false {
        didSet {
            UserDefaults.standard.set(isMainWindowShaded, forKey: "isMainWindowShaded")
        }
    }

    // MARK: - Time Display Mode

    /// Time display mode for elapsed vs remaining time
    enum TimeDisplayMode: String, Codable, CaseIterable {
        case elapsed = "elapsed"
        case remaining = "remaining"
    }

    /// Current time display mode - persists across app restarts
    /// Note: Using didSet pattern to maintain @Observable reactivity
    var timeDisplayMode: TimeDisplayMode = .elapsed {
        didSet {
            UserDefaults.standard.set(timeDisplayMode.rawValue, forKey: "timeDisplayMode")
        }
    }

    /// Toggle between elapsed and remaining time display
    func toggleTimeDisplayMode() {
        timeDisplayMode = (timeDisplayMode == .elapsed) ? .remaining : .elapsed
    }

    // MARK: - Clutter Bar States

    /// O - Trigger Options Menu via keyboard (transient, not persisted)
    var showOptionsMenuTrigger: Bool = false

    /// I - Track Info Dialog (transient, not persisted)
    var showTrackInfoDialog: Bool = false

    // MARK: - Video Window (TASK 2: Day 6)

    /// V - Video Window visibility state (persisted)
    var showVideoWindow: Bool = false {
        didSet {
            UserDefaults.standard.set(showVideoWindow, forKey: "showVideoWindow")
        }
    }

    // NOTE: videoWindowSizeMode removed - replaced by Size2D in VideoWindowSizeState
    // Video window now uses segment-based resizing ([0,4] = 275×232, [11,12] = 550×464)

    // MARK: - Milkdrop Window (TASK 2: Day 7)

    /// Milkdrop Window visibility state (persisted)
    var showMilkdropWindow: Bool = false {
        didSet {
            UserDefaults.standard.set(showMilkdropWindow, forKey: "showMilkdropWindow")
        }
    }

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

    // MARK: - Butterchurn/Milkdrop Settings

    /// Whether to randomize preset selection (default: true, matches Winamp)
    var butterchurnRandomize: Bool = true {
        didSet {
            UserDefaults.standard.set(butterchurnRandomize, forKey: "butterchurnRandomize")
        }
    }

    /// Whether automatic preset cycling is enabled (default: true)
    var butterchurnCycling: Bool = true {
        didSet {
            UserDefaults.standard.set(butterchurnCycling, forKey: "butterchurnCycling")
        }
    }

    /// Preset cycle interval in seconds (default: 15s, Milkdrop standard)
    var butterchurnCycleInterval: Double = 15.0 {
        didSet {
            UserDefaults.standard.set(butterchurnCycleInterval, forKey: "butterchurnCycleInterval")
        }
    }

    /// Track title display interval in seconds (default: 0 = once/manual only)
    /// When > 0, track title is displayed at this interval automatically
    var butterchurnTrackTitleInterval: Double = 0 {
        didSet {
            UserDefaults.standard.set(butterchurnTrackTitleInterval, forKey: "butterchurnTrackTitleInterval")
        }
    }

    // MARK: - Repeat Mode

    /// Repeat mode matching Winamp 5 Modern behavior
    /// - off: Stop at playlist end
    /// - all: Loop entire playlist (Winamp repeat-all)
    /// - one: Repeat current track (shows "1" badge, Winamp repeat-one)
    enum RepeatMode: String, Codable, CaseIterable {
        case off = "off"
        case all = "all"
        case one = "one"

        /// Cycle to next mode (Winamp 5 Modern button behavior: Off → All → One → Off)
        func next() -> RepeatMode {
            let cases = Self.allCases
            guard let index = cases.firstIndex(of: self) else { return self }
            let nextIndex = (index + 1) % cases.count
            return cases[nextIndex]
        }

        /// UI display label for tooltips and menus
        var label: String {
            switch self {
            case .off: return "Repeat: Off"
            case .all: return "Repeat: All"
            case .one: return "Repeat: One"
            }
        }

        /// Button state - lit when all or one (Winamp 5 visual)
        var isActive: Bool {
            self != .off
        }
    }

    /// Current repeat mode - persists across app restarts
    /// Note: Using didSet pattern to maintain @Observable reactivity
    var repeatMode: RepeatMode = .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        }
    }

}
