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
        didSet {
            eqNode.globalGain = preamp
            fanOutToVideoTaps()
        }
    }
    var eqBands: [Float] = Array(repeating: 0.0, count: 10) { // 10 bands, -12.0 to 12.0 dB
        didSet {
            for i in 0..<eqNode.bands.count {
                eqNode.bands[i].gain = i < eqBands.count ? eqBands[i] : 0.0
            }
            fanOutToVideoTaps()
        }
    }
    var isEqOn: Bool = false {
        didSet {
            eqNode.bypass = !isEqOn
            UserDefaults.standard.set(isEqOn, forKey: "isEqOn")
            fanOutToVideoTaps()
        }
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

    // MARK: - Video-tap EQ fanout (S3-2 Phase 5, ADR-5)
    //
    // `EqualizerController` is the single owner of EQ state. On any change it fans
    // out to two consumers: the engine `AVAudioUnitEQ` (the didSet handlers above)
    // and any registered video-tap `VideoTapContext`s (here). Each video tap gets
    // the recomputed `BiquadCoefficientSet` (via `installCoefficients` — the Mutex
    // hand-off, ADR-4 amendment #2) plus the `isEqOn` / preamp atomics. Coefficients
    // depend on sample rate, which the render thread publishes per tap in
    // `pendingSampleRate`; `pollVideoTapSampleRates()` catches the rate becoming
    // known after registration. Writes ONLY the Mutex (coefficients) + atomics —
    // never the render-confined cascade field (that stays inside the render thread).

    @ObservationIgnored private var registeredVideoTapContexts: [WeakBox<VideoTapContext>] = []
    /// Last sample rate each Context's coefficients were computed at, so the poll
    /// only recomputes when the rate actually changes (keyed by object identity).
    @ObservationIgnored private var lastFannedSampleRate: [ObjectIdentifier: Double] = [:]

    /// Register a video-tap Context for EQ fanout and immediately push current state.
    func registerVideoTapContext(_ context: VideoTapContext) {
        registeredVideoTapContexts.removeAll { $0.value == nil || $0.value === context }
        registeredVideoTapContexts.append(WeakBox(context))
        pushEQState(to: context)
    }

    /// Remove a Context from EQ fanout (by identity) and drop its rate record.
    func unregisterVideoTapContext(_ context: VideoTapContext) {
        registeredVideoTapContexts.removeAll { $0.value == nil || $0.value === context }
        lastFannedSampleRate.removeValue(forKey: ObjectIdentifier(context))
    }

    /// Recompute + reinstall coefficients for a Context whose sample rate just changed.
    func handleSampleRateChange(_ context: VideoTapContext, newSampleRate: Double) {
        pushEQState(to: context, sampleRate: newSampleRate)
    }

    /// Main-thread poll (driven at 30 Hz during video): if a registered Context's
    /// render-published `pendingSampleRate` differs from what we last computed for,
    /// recompute. Catches the rate becoming known after registration (e.g. EQ-on
    /// when video starts) without a user EQ change.
    func pollVideoTapSampleRates() {
        guard !registeredVideoTapContexts.isEmpty else { return }
        for box in registeredVideoTapContexts {
            guard let context = box.value else { continue }
            let current = Double(bitPattern: context.pendingSampleRate.load(ordering: .relaxed))
            if lastFannedSampleRate[ObjectIdentifier(context)] != current {
                pushEQState(to: context, sampleRate: current)
            }
        }
    }

    /// Fan current EQ state out to every live registered Context.
    private func fanOutToVideoTaps() {
        guard !registeredVideoTapContexts.isEmpty else { return } // fast path: audio-only
        registeredVideoTapContexts.removeAll { $0.value == nil }
        for box in registeredVideoTapContexts {
            guard let context = box.value else { continue }
            pushEQState(to: context)
        }
    }

    /// Push the current EQ state (gate + preamp + recomputed coefficients) to one
    /// Context. `sampleRate` defaults to the Context's render-published rate.
    private func pushEQState(to context: VideoTapContext, sampleRate: Double? = nil) {
        let state = equalizerState
        let rate = sampleRate ?? Double(bitPattern: context.pendingSampleRate.load(ordering: .relaxed))
        context.isEqOn.store(state.isEqOn, ordering: .relaxed)
        context.preampLinearGainBits.store(state.preampLinearGain.bitPattern, ordering: .relaxed)
        context.installCoefficients(BiquadCoefficientSet.compute(for: state, sampleRate: rate))
        lastFannedSampleRate[ObjectIdentifier(context)] = rate
    }

    // MARK: - Initialization

    init() {
        configureEQ()
        // Restore EQ on/off state
        if UserDefaults.standard.object(forKey: "isEqOn") != nil {
            isEqOn = UserDefaults.standard.bool(forKey: "isEqOn")
        }
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

    /// Configure the 10-band EQ with Winamp frequency centers.
    ///
    /// Classic skin labels show "60 170 310" but actual Winamp 2.x/3.x processing
    /// frequencies are 70, 180, 320. The tight 12k/14k/16k clustering is intentional —
    /// Nullsoft likely designed it to help users tune out high-frequency MP3 encoding artifacts.
    ///
    /// Winamp's FFT-based "Fast EQ" had no traditional filter shapes. Shelf filters
    /// at the endpoints better approximate Winamp's perceptual behavior (sub-bass and
    /// air control) than strict parametric everywhere.
    private func configureEQ() {
        // Single source of truth shared with the video-tap cascade — keeps the
        // engine↔tap numerical match from drifting (Winamp internal frequencies,
        // NOT the skin labels 60/170/310).
        let freqs = BiquadCoefficientSet.frequencies
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
            band.bandwidth = 1.0 // ~1 octave; Winamp's proportional Q ranged ~0.6-1.4
            band.gain = eqBands[i]
            band.bypass = false
        }
        eqNode.globalGain = preamp
        eqNode.bypass = !isEqOn
    }
}

/// Immutable snapshot of equalizer state, produced on the main thread by
/// `EqualizerController` and consumed by `BiquadCoefficientSet.compute` to build
/// the video-tap biquad cascade. `EqualizerController` remains the single source
/// of EQ truth (ADR-5); this is a read-only projection.
///
/// (Plan called for a `private nested` type; `internal` is required so
/// `BiquadCoefficientSet.compute` can consume it across files.)
struct EqualizerState: Sendable, Equatable {
    let isEqOn: Bool
    /// Preamp as a linear gain multiplier. Engine side stores dB in
    /// `AVAudioUnitEQ.globalGain`; the tap applies this linear value directly.
    /// `10^(preampDB/20)`.
    let preampLinearGain: Float
    /// 10 per-band gains in dB, indexed to `BiquadCoefficientSet.frequencies`.
    let bandGainsDB: [Float]
}

extension EqualizerController {
    /// Current EQ state as an immutable snapshot. Phase 5 fans this out to
    /// registered video-tap contexts on each EQ change.
    var equalizerState: EqualizerState {
        EqualizerState(isEqOn: isEqOn,
                       preampLinearGain: Float(pow(10.0, Double(preamp) / 20.0)),
                       bandGainsDB: eqBands)
    }
}
