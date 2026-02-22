import AVFoundation
import Observation

/// Manages equalizer state and 10-band parametric EQ node.
/// Extracted from AudioPlayer as part of facade decomposition.
///
/// **Layer:** Mechanism (audio processing)
/// **Responsibilities:**
/// - Owns AVAudioUnitEQ node lifecycle and band configuration
/// - Manages EQ preset save/load/import via EQPresetStore
/// - Handles per-track auto-EQ logic
@Observable
@MainActor
final class EqualizerController {
    // MARK: - EQ Node

    /// 10-band parametric EQ (attached to AudioPlayer's engine graph)
    let eqNode = AVAudioUnitEQ(numberOfBands: 10)

    // MARK: - Observable State
    // didSet handlers keep the eqNode in sync regardless of assignment path
    // (direct property write or behavioral method like setPreamp/toggleEq).

    var preamp: Float = 0.0 { // -12.0 to 12.0 dB (typical range)
        didSet { eqNode.globalGain = preamp }
    }
    var eqBands: [Float] = Array(repeating: 0.0, count: 10) { // 10 bands, -12.0 to 12.0 dB
        didSet {
            for i in 0..<eqNode.bands.count {
                eqNode.bands[i].gain = i < eqBands.count ? eqBands[i] : 0.0
            }
        }
    }
    var isEqOn: Bool = false {
        didSet { eqNode.bypass = !isEqOn }
    }
    var eqAutoEnabled: Bool = false
    var useLogScaleBands: Bool = true
    var appliedAutoPresetTrack: String?

    // MARK: - Extracted Controllers

    let eqPresetStore = EQPresetStore()

    // Computed forwarding
    var userPresets: [EQPreset] { eqPresetStore.userPresets }

    // MARK: - Private State

    @ObservationIgnored private var autoEQTask: Task<Void, Never>?
    @ObservationIgnored private var autoPresetClearTask: Task<Void, Never>?
    @ObservationIgnored private var appliedAutoPresetURL: String?

    // MARK: - Initialization

    init() {
        configureEQ()
    }

    // MARK: - EQ Control Methods

    func setPreamp(value: Float) {
        preamp = value // didSet syncs eqNode.globalGain
        if !isEqOn && value != 0 {
            toggleEq(isOn: true)
        }
        AppLog.debug(.audio, "Set Preamp to \(value), EQ is \(isEqOn ? "ON" : "OFF")")
    }

    func setEqBand(index: Int, value: Float) {
        guard index >= 0 && index < eqBands.count else { return }
        eqBands[index] = value // didSet syncs eqNode.bands
        AppLog.debug(.audio, "Set EQ Band \(index) to \(value)")
    }

    func toggleEq(isOn: Bool) {
        isEqOn = isOn // didSet syncs eqNode.bypass
        AppLog.debug(.audio, "EQ is now \(isOn ? "On" : "Off")")
    }

    // MARK: - Presets

    func applyPreset(_ preset: EqfPreset) {
        setPreamp(value: preset.preampDB)
        for (i, g) in preset.bandsDB.enumerated() { setEqBand(index: i, value: g) }
        toggleEq(isOn: true)
    }

    func applyEQPreset(_ preset: EQPreset) {
        setPreamp(value: preset.preamp)
        for (i, g) in preset.bands.enumerated() { setEqBand(index: i, value: g) }
        toggleEq(isOn: true)
        AppLog.info(.audio, "Applied EQ preset: \(preset.name)")
    }

    func getCurrentEQPreset(name: String) -> EQPreset {
        EQPreset(name: name, preamp: preamp, bands: Array(eqBands))
    }

    func saveUserPreset(named rawName: String) {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let preset = getCurrentEQPreset(name: trimmedName)
        eqPresetStore.storeUserPreset(preset)
        AppLog.info(.audio, "Saved user EQ preset '\(trimmedName)'")
    }

    func deleteUserPreset(id: UUID) {
        eqPresetStore.deleteUserPreset(id: id)
    }

    func importEqfPreset(from url: URL) {
        Task { [weak self] in
            guard let self else { return }
            if let preset = await self.eqPresetStore.importEqfPreset(from: url) {
                self.applyEQPreset(preset)
            }
        }
    }

    // MARK: - Per-Track EQ

    /// Save current EQ settings as a preset for the given track
    func savePresetForCurrentTrack(_ track: Track) {
        let p = EqfPreset(name: track.title, preampDB: preamp, bandsDB: eqBands)
        eqPresetStore.savePreset(p, forTrackURL: track.url.absoluteString)
        AppLog.debug(.audio, "Saved per-track EQ preset for \(track.title)")
    }

    /// Apply a saved per-track EQ preset, or generate one if none exists
    func applyAutoPreset(for track: Track) {
        guard eqAutoEnabled else { return }
        if let preset = eqPresetStore.preset(forTrackURL: track.url.absoluteString) {
            applyPreset(preset)
            appliedAutoPresetTrack = track.title
            autoPresetClearTask?.cancel()
            let trackURL = track.url.absoluteString
            autoPresetClearTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.appliedAutoPresetURL == trackURL {
                    self.appliedAutoPresetTrack = nil
                    self.appliedAutoPresetURL = nil
                }
            }
            appliedAutoPresetURL = trackURL
            AppLog.debug(.audio, "Applied per-track EQ preset for \(track.title)")
        } else {
            generateAutoPreset(for: track)
        }
    }

    /// Enable or disable auto-EQ, optionally applying for the current track
    func setAutoEQEnabled(_ isEnabled: Bool, currentTrack: Track?) {
        guard eqAutoEnabled != isEnabled else { return }
        eqAutoEnabled = isEnabled
        if isEnabled, let current = currentTrack {
            applyAutoPreset(for: current)
        } else {
            autoEQTask?.cancel()
            autoEQTask = nil
            autoPresetClearTask?.cancel()
            autoPresetClearTask = nil
            appliedAutoPresetTrack = nil
            appliedAutoPresetURL = nil
        }
    }

    private func generateAutoPreset(for track: Track) {
        autoEQTask?.cancel()
        autoEQTask = nil
        AppLog.debug(.audio, "AutoEQ: automatic analysis disabled, no preset generated for \(track.title)")
    }

    // MARK: - EQ Configuration

    /// Configure the 10-band EQ with Winamp frequency centers
    private func configureEQ() {
        // Winamp 10-band centers (Hz): 60,170,310,600,1k,3k,6k,12k,14k,16k
        let freqs: [Float] = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]
        for i in 0..<min(eqNode.bands.count, freqs.count) {
            let band = eqNode.bands[i]
            if i == 0 {
                band.filterType = .lowShelf
            } else if i == freqs.count - 1 {
                band.filterType = .highShelf
            } else {
                band.filterType = .parametric
            }
            band.frequency = freqs[i]
            band.bandwidth = 1.0 // Octaves for parametric; harmless for shelves
            band.gain = eqBands[i]
            band.bypass = false
        }
        eqNode.globalGain = preamp
        eqNode.bypass = !isEqOn
    }
}
