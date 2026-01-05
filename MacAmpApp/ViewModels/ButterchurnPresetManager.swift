import Foundation
import Observation

/// Manages Butterchurn visualization presets with cycling, randomization, and history
///
/// Features (inspired by webamp MilkdropState):
/// - Preset list from JS bridge
/// - Random or sequential cycling
/// - History stack for previous/next navigation
/// - Configurable cycle interval and transition duration
/// - UserDefaults persistence via AppSettings
@MainActor
@Observable
final class ButterchurnPresetManager {
    // MARK: - Observable State

    /// Available preset names (populated from JS on ready)
    var presets: [String] = []

    /// Current preset index (-1 if none selected)
    var currentPresetIndex: Int = -1

    /// Current preset name (computed from index)
    var currentPresetName: String? {
        guard currentPresetIndex >= 0, currentPresetIndex < presets.count else { return nil }
        return presets[currentPresetIndex]
    }

    /// Whether to randomize preset selection (default: true, matches Winamp)
    var isRandomize: Bool = true {
        didSet { appSettings?.butterchurnRandomize = isRandomize }
    }

    /// Whether automatic cycling is enabled (default: true)
    var isCycling: Bool = true {
        didSet {
            appSettings?.butterchurnCycling = isCycling
            if isCycling {
                startCycling()
            } else {
                stopCycling()
            }
        }
    }

    /// Cycle interval in seconds (default: 15s, Milkdrop standard)
    var cycleInterval: TimeInterval = 15.0 {
        didSet {
            appSettings?.butterchurnCycleInterval = cycleInterval
            if isCycling { restartCycling() }
        }
    }

    /// Transition duration in seconds (default: 2.7s, Milkdrop standard)
    var transitionDuration: Double = 2.7

    // MARK: - Private State

    /// History stack for previous preset navigation (webamp pattern)
    @ObservationIgnored private var presetHistory: [Int] = []

    /// Cycling timer
    @ObservationIgnored private var cycleTimer: Timer?

    /// Weak reference to bridge for JS calls
    @ObservationIgnored private weak var bridge: ButterchurnBridge?

    /// Weak reference to AppSettings for persistence
    @ObservationIgnored private weak var appSettings: AppSettings?

    // MARK: - Configuration

    /// Configure with bridge and settings
    /// - Parameters:
    ///   - bridge: ButterchurnBridge for JS communication
    ///   - appSettings: AppSettings for persistence
    func configure(bridge: ButterchurnBridge, appSettings: AppSettings) {
        self.bridge = bridge
        self.appSettings = appSettings

        // Load persisted settings
        isRandomize = appSettings.butterchurnRandomize
        isCycling = appSettings.butterchurnCycling
        cycleInterval = appSettings.butterchurnCycleInterval
    }

    /// Load presets from JS bridge ready callback
    /// - Parameter names: Array of preset names from butterchurnPresets
    func loadPresets(_ names: [String]) {
        presets = names
        presetHistory = []

        // Select initial preset
        if !presets.isEmpty {
            if isRandomize {
                selectRandomPreset(transition: 0)
            } else {
                selectPreset(at: 0, transition: 0)
            }
        }

        // Start cycling if enabled
        if isCycling {
            startCycling()
        }
    }

    // MARK: - Preset Navigation

    /// Select next preset (random or sequential based on isRandomize)
    func nextPreset() {
        guard presets.count > 1 else { return }

        if isRandomize {
            selectRandomPreset()
        } else {
            let nextIndex = (currentPresetIndex + 1) % presets.count
            selectPreset(at: nextIndex, addToHistory: true)
        }
    }

    /// Select previous preset from history
    func previousPreset() {
        // Need at least 2 items: current + previous
        guard presetHistory.count >= 2 else { return }

        // Pop current from history
        presetHistory.removeLast()

        // Get and select previous
        if let previousIndex = presetHistory.last {
            selectPreset(at: previousIndex, addToHistory: false)
        }
    }

    /// Select a random preset (avoiding current if possible)
    /// - Parameter transition: Transition duration (nil uses default)
    func selectRandomPreset(transition: Double? = nil) {
        guard presets.count > 1 else {
            if presets.count == 1 { selectPreset(at: 0, transition: transition) }
            return
        }

        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<presets.count)
        } while randomIndex == currentPresetIndex

        selectPreset(at: randomIndex, transition: transition, addToHistory: true)
    }

    /// Select preset at specific index
    /// - Parameters:
    ///   - index: Preset index
    ///   - transition: Transition duration (nil uses default)
    ///   - addToHistory: Whether to add to history stack
    func selectPreset(at index: Int, transition: Double? = nil, addToHistory: Bool = true) {
        guard index >= 0, index < presets.count else { return }

        currentPresetIndex = index

        if addToHistory {
            presetHistory.append(index)
            // Limit history size to prevent memory bloat
            if presetHistory.count > 100 {
                presetHistory.removeFirst(presetHistory.count - 100)
            }
        }

        // Call JS to load preset
        let transitionTime = transition ?? transitionDuration
        bridge?.loadPreset(at: index, transition: transitionTime)
    }

    /// Select preset by name
    /// - Parameters:
    ///   - name: Preset name to find
    ///   - transition: Transition duration (nil uses default)
    func selectPreset(byName name: String, transition: Double? = nil) {
        guard let index = presets.firstIndex(of: name) else { return }
        selectPreset(at: index, transition: transition)
    }

    // MARK: - Cycling

    /// Start automatic preset cycling
    func startCycling() {
        guard isCycling else { return }
        stopCycling()

        cycleTimer = Timer.scheduledTimer(withTimeInterval: cycleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextPreset()
            }
        }
    }

    /// Stop automatic preset cycling
    func stopCycling() {
        cycleTimer?.invalidate()
        cycleTimer = nil
    }

    /// Restart cycling (after interval change)
    private func restartCycling() {
        if isCycling {
            stopCycling()
            startCycling()
        }
    }

    // MARK: - Cleanup

    /// Clean up timers
    func cleanup() {
        stopCycling()
    }
}
