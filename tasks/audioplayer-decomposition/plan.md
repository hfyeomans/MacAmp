# Plan: AudioPlayer.swift Decomposition

> **Description:** Implementation plan for decomposing AudioPlayer.swift from 1,070 lines to ~680 lines using the facade pattern established by the WindowCoordinator refactor (PR #45).
> **Purpose:** Step-by-step extraction plan with code changes, file listings, verification steps, and risk assessment for each phase.

---

## Overview

| Metric | Before | After (Target) |
|--------|--------|----------------|
| AudioPlayer.swift | 1,070 lines | ~680 lines |
| swiftlint suppressions | 2 (`file_length` + `type_body_length`) | 0–1 |
| New files | 0 | 1 (`EqualizerController.swift`) |
| Modified files | 1 | 2 (`AudioPlayer.swift`, `VisualizerPipeline.swift`) |
| Deleted code | FourCC extension (if unused) | ~12 lines |

---

## Phase 1: Extract EqualizerController (~120 lines)

**Risk: Low** — EQ methods are self-contained with no seek/transport entanglement.

### 1.1 Create EqualizerController.swift

**New file:** `MacAmpApp/Audio/EqualizerController.swift`

```swift
import AVFoundation
import Observation

@Observable
@MainActor
final class EqualizerController {
    // EQ node (owned by this controller, attached to engine by AudioPlayer)
    let eqNode = AVAudioUnitEQ(numberOfBands: 10)

    // Observable state
    var preamp: Float = 0.0
    var eqBands: [Float] = Array(repeating: 0.0, count: 10)
    var isEqOn: Bool = false
    var eqAutoEnabled: Bool = false
    var useLogScaleBands: Bool = true
    var appliedAutoPresetTrack: String?

    // Extracted controllers
    let eqPresetStore = EQPresetStore()

    // Computed forwarding
    var userPresets: [EQPreset] { eqPresetStore.userPresets }

    @ObservationIgnored private var autoEQTask: Task<Void, Never>?

    // All EQ methods moved here:
    // setPreamp, setEqBand, toggleEq, applyPreset, applyEQPreset,
    // getCurrentEQPreset, saveUserPreset, deleteUserPreset,
    // importEqfPreset, savePresetForCurrentTrack,
    // applyAutoPreset, setAutoEQEnabled, generateAutoPreset,
    // configureEQ
}
```

### 1.2 Move Methods

Move these methods from AudioPlayer to EqualizerController (cut-paste, no logic changes):

| Method | AudioPlayer Lines | Notes |
|--------|-------------------|-------|
| `setPreamp(value:)` | 523-531 | Direct move |
| `setEqBand(index:value:)` | 533-538 | Direct move |
| `toggleEq(isOn:)` | 540-544 | Direct move |
| `applyPreset(_:)` | 547-551 | Direct move |
| `applyEQPreset(_:)` | 553-558 | Direct move |
| `getCurrentEQPreset(name:)` | 560-562 | Direct move |
| `saveUserPreset(named:)` | 564-570 | Direct move |
| `deleteUserPreset(id:)` | 572-574 | Direct move |
| `importEqfPreset(from:)` | 576-583 | Direct move |
| `savePresetForCurrentTrack()` | 585-590 | Needs `currentTrack` passed as parameter |
| `applyAutoPreset(for:)` | 592-608 | Direct move |
| `setAutoEQEnabled(_:)` | 610-620 | Needs `currentTrack` passed as parameter |
| `generateAutoPreset(for:)` | 622-626 | Direct move |
| `configureEQ()` | 636-655 | Direct move |

### 1.3 Add Forwarding in AudioPlayer

```swift
// AudioPlayer.swift — replace direct EQ methods with forwarding
let equalizer = EqualizerController()

// Forwarding (backwards compatibility)
var preamp: Float {
    get { equalizer.preamp }
    set { equalizer.preamp = newValue }
}
var eqBands: [Float] {
    get { equalizer.eqBands }
    set { equalizer.eqBands = newValue }
}
var isEqOn: Bool {
    get { equalizer.isEqOn }
    set { equalizer.isEqOn = newValue }
}
// ... etc for all observable EQ properties

func setPreamp(value: Float) { equalizer.setPreamp(value: value) }
func setEqBand(index: Int, value: Float) { equalizer.setEqBand(index: index, value: value) }
func toggleEq(isOn: Bool) { equalizer.toggleEq(isOn: isOn) }
func applyPreset(_ preset: EqfPreset) { equalizer.applyPreset(preset) }
func applyEQPreset(_ preset: EQPreset) { equalizer.applyEQPreset(preset) }
// ... etc
```

### 1.4 Wire eqNode into Engine

In `setupEngine()`, attach the equalizer's node:

```swift
private func setupEngine() {
    audioEngine.attach(playerNode)
    audioEngine.attach(equalizer.eqNode)  // Changed from self.eqNode
}
```

In `rewireForCurrentFile()`, connect through the equalizer's node:

```swift
audioEngine.connect(playerNode, to: equalizer.eqNode, format: nil)
audioEngine.connect(equalizer.eqNode, to: audioEngine.mainMixerNode, format: nil)
```

### 1.5 Handle `savePresetForCurrentTrack()` Dependency

This method accesses `currentTrack`. Change signature to accept the track:

```swift
// EqualizerController:
func savePresetForCurrentTrack(_ track: Track) { ... }

// AudioPlayer forwarding:
func savePresetForCurrentTrack() {
    guard let t = currentTrack else { return }
    equalizer.savePresetForCurrentTrack(t)
}
```

Same pattern for `setAutoEQEnabled(_:)` and `applyAutoPreset(for:)`.

### 1.6 Verification

- Build with Thread Sanitizer
- Verify all 10 EQ bands respond in EQ window
- Verify preamp slider works
- Verify EQ on/off toggle
- Verify preset save/load/delete
- Verify auto-EQ applies on track change
- Run tests

---

## Phase 2: Consolidate Visualizer Forwarding (~70 lines)

**Risk: Low** — Moving one standalone method and removing thin wrappers.

### 2.1 Move `getFrequencyData(bands:)` to VisualizerPipeline

This 40-line method (lines 904-943) has its own log-scaling logic and doesn't forward to `VisualizerPipeline`. It belongs there.

```swift
// Move to VisualizerPipeline.swift:
func getFrequencyData(bands: Int, isPlaying: Bool) -> [Float] {
    // ... existing implementation
    // Uses self.levels instead of visualizerLevels
}
```

### 2.2 Remove Pure Forwarding Methods

These methods on AudioPlayer are pure one-line forwards that can be replaced by callers accessing `visualizerPipeline` directly, OR kept as thin forwards:

```swift
// Keep as forwards for API stability:
func getRMSData(bands: Int) -> [Float] { visualizerPipeline.getRMSData(bands: bands) }
func getWaveformSamples(count: Int) -> [Float] { visualizerPipeline.getWaveformSamples(count: count) }
func snapshotButterchurnFrame() -> ButterchurnFrame? {
    guard currentMediaType == .audio && isPlaying else { return nil }
    return visualizerPipeline.snapshotButterchurnFrame()
}
func getFrequencyData(bands: Int) -> [Float] {
    visualizerPipeline.getFrequencyData(bands: bands, isPlaying: isPlaying)
}
```

### 2.3 Remove Unnecessary Forwarding Properties

Evaluate whether callers can access `visualizerPipeline` directly instead of through forwarding computed properties on AudioPlayer. If callers use `@Environment(AudioPlayer.self)`, they can also access `audioPlayer.visualizerPipeline.levels`.

### 2.4 Verification

- Build with Thread Sanitizer
- Verify spectrum analyzer renders correctly
- Verify oscilloscope waveform renders correctly
- Verify Butterchurn/MilkDrop visualizer receives data

---

## Phase 3: Clean Up FourCC Extension (~12 lines)

**Risk: Zero.**

### 3.1 Check Usage

```bash
rg "fourCC" --type swift MacAmpApp/
```

If unused, delete lines 8-19 entirely. If used, move to a `Utilities/` extension file.

### 3.2 Verification

- Build succeeds

---

## Phase 4: Optional — Engine Transport Extraction (~200 lines)

**Risk: Medium-High.** Only proceed if Phases 1-3 bring the file to an acceptable size and there's appetite for more.

### 4.1 Create AudioEngineTransport

Extract AVAudioEngine lifecycle and file scheduling:

```swift
@MainActor
final class AudioEngineTransport {
    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var playheadOffset: Double = 0

    func setup() { ... }
    func rewireForFile(_ file: AVAudioFile, eqNode: AVAudioUnitEQ) { ... }
    func scheduleFrom(time: Double, seekID: UUID, completion: @escaping (UUID) -> Void) -> Bool { ... }
    func startIfNeeded() { ... }
    func startProgressTimer(callback: @escaping (Double, Double) -> Void) { ... }
}
```

### 4.2 Coupling Issues

`seek()` and `play()`/`pause()`/`stop()` would need to call through the transport controller. This changes the internal call graph significantly and requires careful handling of:

- `currentSeekID` and `seekGuardActive` (seek state machine)
- `isHandlingCompletion` (re-entrancy guard)
- Completion handler wiring (`onPlaybackEnded`)

**Recommendation:** Defer this phase unless Phases 1-3 are insufficient. The seek/transport pipeline was heavily debugged (multiple seek guard mechanisms) and is high-risk to refactor.

---

## Expected File Sizes After Each Phase

| Phase | AudioPlayer.swift | New Files | Suppressions |
|-------|-------------------|-----------|--------------|
| Current | 1,070 | — | 2 |
| After Phase 1 | ~940 | EqualizerController.swift (~150) | 1 (file_length only) |
| After Phase 2 | ~870 | — | 1 |
| After Phase 3 | ~858 | — | 1 |
| After Phase 4 | ~680 | AudioEngineTransport.swift (~200) | 0 |

---

## Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|-----------|
| 1: EQ Controller | **Low** | Self-contained methods, no transport coupling |
| 2: Visualizer consolidation | **Low** | Moving one method, removing thin wrappers |
| 3: FourCC cleanup | **Zero** | Delete or move unused code |
| 4: Engine transport | **Medium-High** | Complex seek state machine, defer if not needed |

---

## Out of Scope

1. **Volume/balance persistence debouncing** — noted in review, can be addressed separately
2. **Default volume 1.0 → 0.75 change** — already shipped in PR #43, not reverting
3. **PlaybackCoordinator changes** — AudioPlayer's public API stays unchanged (facade pattern)
4. **Unit tests** — separate task (AudioPlayer currently has no unit tests)
5. **`@Environment` migration for EQ** — views still access `@Environment(AudioPlayer.self)`
