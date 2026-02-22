# TODO: AudioPlayer.swift Decomposition

> **Description:** Checklist of all implementation tasks for decomposing AudioPlayer.swift, derived from the plan.
> **Purpose:** Each item is a discrete, verifiable unit of work. Items are checked off as completed.

---

## Phase 1: Extract EqualizerController

- [ ] Create `MacAmpApp/Audio/EqualizerController.swift` with `@Observable @MainActor` class
- [ ] Move `eqNode` (AVAudioUnitEQ) ownership to EqualizerController
- [ ] Move EQ state properties: `preamp`, `eqBands`, `isEqOn`, `eqAutoEnabled`, `useLogScaleBands`, `appliedAutoPresetTrack`, `autoEQTask`
- [ ] Move `eqPresetStore` and `userPresets` computed property to EqualizerController
- [ ] Move methods: `setPreamp`, `setEqBand`, `toggleEq`
- [ ] Move methods: `applyPreset`, `applyEQPreset`, `getCurrentEQPreset`
- [ ] Move methods: `saveUserPreset`, `deleteUserPreset`, `importEqfPreset`
- [ ] Move methods: `savePresetForCurrentTrack` (change signature to accept `Track` parameter)
- [ ] Move methods: `applyAutoPreset`, `setAutoEQEnabled` (change signature to accept `Track?`), `generateAutoPreset`
- [ ] Move `configureEQ()` to EqualizerController
- [ ] Add `let equalizer = EqualizerController()` to AudioPlayer
- [ ] Add forwarding computed properties on AudioPlayer for all moved observable state
- [ ] Add forwarding methods on AudioPlayer for all moved methods
- [ ] Update `setupEngine()` to use `equalizer.eqNode`
- [ ] Update `rewireForCurrentFile()` to use `equalizer.eqNode`
- [ ] Update `playTrack()` to call `equalizer.applyAutoPreset(for:)` instead of `self.applyAutoPreset(for:)`
- [ ] Build with Thread Sanitizer
- [ ] Verify EQ window: all 10 bands, preamp, on/off toggle
- [ ] Verify preset save/load/delete
- [ ] Verify auto-EQ applies on track change

## Phase 2: Consolidate Visualizer Forwarding

- [ ] Move `getFrequencyData(bands:)` implementation to `VisualizerPipeline.swift` (add `isPlaying` parameter or use internal `levels`)
- [ ] Replace AudioPlayer's `getFrequencyData` with forwarding call
- [ ] Evaluate which visualizer forwarding properties can be simplified
- [ ] Remove the dedicated `// MARK: - Visualizer Support` and `// MARK: - Butterchurn Audio Data` sections (merge into a single small forwarding block)
- [ ] Build with Thread Sanitizer
- [ ] Verify spectrum analyzer renders correctly
- [ ] Verify oscilloscope waveform renders correctly
- [ ] Verify Butterchurn/MilkDrop visualizer receives data

## Phase 3: Clean Up FourCC Extension

- [ ] Search codebase for `fourCC` usage: `rg "fourCC" --type swift MacAmpApp/`
- [ ] If unused: delete lines 8-19 from AudioPlayer.swift
- [ ] If used: move to a shared extension file
- [ ] Build succeeds

## Phase 4: Engine Transport Extraction (DEFERRED)

- [ ] Evaluate if Phases 1-3 bring file below thresholds
- [ ] If needed: create `AudioEngineTransport.swift`
- [ ] If needed: extract `setupEngine`, `rewireForCurrentFile`, `scheduleFrom`, `startEngineIfNeeded`, `startProgressTimer`
- [ ] If needed: refactor `play/pause/stop/seek` to use transport controller
- [ ] Oracle review on seek state machine changes

## Post-Implementation

- [ ] Remove `// swiftlint:disable file_length` if file is under 1,200 lines
- [ ] Remove `// swiftlint:disable:this type_body_length` if type body is under 600 lines
- [ ] Run full swiftlint check: no new warnings
- [ ] Update state.md with final line counts
- [ ] Update deprecated.md with any removed patterns
- [ ] Commit with descriptive message
