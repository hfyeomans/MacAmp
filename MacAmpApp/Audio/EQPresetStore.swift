import Foundation
import Observation

/// Manages persistence of EQ presets (user presets and per-track presets).
/// Extracted from AudioPlayer as part of the Option C incremental refactoring.
///
/// Layer: Mechanism (like AppSettings)
/// Responsibilities:
/// - Load/save user EQ presets to UserDefaults
/// - Load/save per-track presets to JSON file in Application Support
/// - Parse and store imported EQF preset files
@MainActor
@Observable
final class EQPresetStore {
    // MARK: - Published State
    private(set) var userPresets: [EQPreset] = []

    // MARK: - Internal State
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]

    // MARK: - Configuration
    @ObservationIgnored private let presetsFileName = "perTrackPresets.json"
    @ObservationIgnored private let userPresetDefaultsKey = "MacAmp.UserEQPresets.v1"

    // MARK: - Initialization
    init() {
        loadUserPresets()
        loadPerTrackPresets()
    }

    // MARK: - User Presets (UserDefaults)

    private func loadUserPresets() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: userPresetDefaultsKey) else { return }
        do {
            var decoded = try JSONDecoder().decode([EQPreset].self, from: data)
            decoded.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            userPresets = decoded
            AppLog.debug(.audio, "Loaded \(decoded.count) user EQ presets")
        } catch {
            AppLog.warn(.audio, "Failed to decode user EQ presets: \(error)")
            userPresets = []
        }
    }

    private func persistUserPresets() {
        do {
            let data = try JSONEncoder().encode(userPresets)
            UserDefaults.standard.set(data, forKey: userPresetDefaultsKey)
        } catch {
            AppLog.warn(.audio, "Failed to persist user EQ presets: \(error)")
        }
    }

    func storeUserPreset(_ preset: EQPreset) {
        if let index = userPresets.firstIndex(where: { $0.name.caseInsensitiveCompare(preset.name) == .orderedSame }) {
            userPresets[index] = preset
        } else {
            userPresets.append(preset)
        }
        userPresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistUserPresets()
    }

    func deleteUserPreset(id: UUID) {
        if let index = userPresets.firstIndex(where: { $0.id == id }) {
            let removed = userPresets.remove(at: index)
            persistUserPresets()
            AppLog.info(.audio, "Deleted user EQ preset '\(removed.name)'")
        }
    }

    // MARK: - Per-Track Presets (JSON File)

    private func appSupportDirectory() -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("MacAmp", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                AppLog.error(.audio, "Failed to create app support dir: \(error)")
            }
        }
        return dir
    }

    private func presetsFileURL() -> URL? {
        appSupportDirectory()?.appendingPathComponent(presetsFileName)
    }

    private func loadPerTrackPresets() {
        guard let url = presetsFileURL(), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([String: EqfPreset].self, from: data)
            perTrackPresets = loaded
            AppLog.debug(.audio, "Loaded \(loaded.count) per-track presets")
        } catch {
            AppLog.warn(.audio, "Failed to load per-track presets: \(error)")
        }
    }

    func savePerTrackPresets() {
        guard let url = presetsFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(perTrackPresets)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.warn(.audio, "Failed to save per-track presets: \(error)")
        }
    }

    func preset(forTrackURL urlString: String) -> EqfPreset? {
        perTrackPresets[urlString]
    }

    func savePreset(_ preset: EqfPreset, forTrackURL urlString: String) {
        perTrackPresets[urlString] = preset
        savePerTrackPresets()
    }

    // MARK: - EQF Import

    /// Parses an EQF file and stores it as a user preset.
    /// Returns the parsed preset for the caller to apply if desired.
    func importEqfPreset(from url: URL) async -> EQPreset? {
        // Perform file I/O off main thread
        let result: EQPreset? = await Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url)
                guard let eqfPreset = EQFCodec.parse(data: data) else {
                    AppLog.warn(.audio, "Failed to parse EQF preset at \(url.lastPathComponent)")
                    return nil
                }
                let suggestedName = eqfPreset.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackName = url.deletingPathExtension().lastPathComponent
                let finalName = suggestedName.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
                return EQPreset(name: finalName, preamp: eqfPreset.preampDB, bands: eqfPreset.bandsDB)
            } catch {
                AppLog.error(.audio, "Failed to load EQF preset: \(error)")
                return nil
            }
        }.value

        // Store on main actor
        if let preset = result {
            storeUserPreset(preset)
            AppLog.info(.audio, "Imported EQ preset '\(preset.name)' from EQF")
        }
        return result
    }
}
