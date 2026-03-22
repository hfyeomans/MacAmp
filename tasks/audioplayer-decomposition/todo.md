# TODO: AudioPlayer.swift Decomposition

> **Description:** Checklist of all implementation tasks for decomposing AudioPlayer.swift, derived from the plan.
> **Purpose:** Each item is a discrete, verifiable unit of work. Items are checked off as completed.

---

## Phase 1: Extract EqualizerController

- [x] Create `MacAmpApp/Audio/EqualizerController.swift` with `@Observable @MainActor` class
- [x] Move `eqNode` (AVAudioUnitEQ) ownership to EqualizerController
- [x] Move EQ state properties: `preamp`, `eqBands`, `isEqOn`, `eqAutoEnabled`, `useLogScaleBands`, `appliedAutoPresetTrack`, `autoEQTask`
- [x] Move `eqPresetStore` and `userPresets` computed property to EqualizerController
- [x] Move methods: `setPreamp`, `setEqBand`, `toggleEq`
- [x] Move methods: `applyPreset`, `applyEQPreset`, `getCurrentEQPreset`
- [x] Move methods: `saveUserPreset`, `deleteUserPreset`, `importEqfPreset`
- [x] Move methods: `savePresetForCurrentTrack` (change signature to accept `Track` parameter)
- [x] Move methods: `applyAutoPreset`, `setAutoEQEnabled` (change signature to accept `Track?`), `generateAutoPreset`
- [x] Move `configureEQ()` to EqualizerController
- [x] Add `let equalizer = EqualizerController()` to AudioPlayer
- [x] Add forwarding computed properties on AudioPlayer for all moved observable state
- [x] Add forwarding methods on AudioPlayer for all moved methods
- [x] Update `setupEngine()` to use `equalizer.eqNode`
- [x] Update `rewireForCurrentFile()` to use `equalizer.eqNode`
- [x] Update `playTrack()` to call `equalizer.applyAutoPreset(for:)` instead of `self.applyAutoPreset(for:)`
- [x] Build with Thread Sanitizer — **PASSED** (commit `1b7e76f`)
- [ ] Verify EQ window: all 10 bands, preamp, on/off toggle (requires manual testing)
- [ ] Verify preset save/load/delete (requires manual testing)
- [ ] Verify auto-EQ applies on track change (requires manual testing)

## Phase 2: Consolidate Visualizer Forwarding

- [x] Move `getFrequencyData(bands:)` implementation to `VisualizerPipeline.swift` (added `isPlaying` parameter)
- [x] Replace AudioPlayer's `getFrequencyData` with forwarding call
- [x] Merged `// MARK: - Visualizer Support` and `// MARK: - Butterchurn Audio Data` into single `// MARK: - Visualizer Forwarding` block
- [x] Build with Thread Sanitizer — **PASSED** (commit `2fbed90`)
- [ ] Verify spectrum analyzer renders correctly (requires manual testing)
- [ ] Verify oscilloscope waveform renders correctly (requires manual testing)
- [ ] Verify Butterchurn/MilkDrop visualizer receives data (requires manual testing)

## Phase 3: Clean Up FourCC Extension

- [x] Search codebase for `fourCC` usage — **No callers found**
- [x] Deleted lines 8-19 from AudioPlayer.swift (unused extension)
- [x] Removed stale extraction comments
- [x] Build succeeds — **PASSED** (commit `37c3598`)

## Oracle Review #1 Fixes

- [x] Made `equalizer` `private` to enforce facade boundary
- [x] Added `didSet` handlers on `preamp`, `eqBands`, `isEqOn` for eqNode sync
- [x] Removed redundant manual node assignments from behavioral methods
- [x] Build with Thread Sanitizer — **PASSED** (commit `8679123`)

## Oracle Review #2 Fixes

- [x] Fix deinit crash: `removeTap()` main-queue precondition — dispatch to main when deinit runs off-thread
- [x] Harden `eqBands` didSet: zero remaining eqNode bands when array has fewer than 10 elements
- [x] Make `visualizerPipeline` `private` to match `equalizer` facade enforcement
- [x] Build with Thread Sanitizer — **PASSED** (commit `c87aa07`)

## CodeRabbit Review Fixes

- [x] Make `configureEQ()` `private` in EqualizerController — only called from `init()`
- [x] Remove unused `import Combine` and `import Accelerate` from AudioPlayer.swift
- [x] Verify swiftlint suppressions — **cannot remove** (945 lines, still above 600 warning threshold)
- [x] Build with Thread Sanitizer — **PASSED** (commit `dd8866e`)

## Gemini Review Fix

- [x] Use URL-based identity for auto-preset clear task instead of track title
- [x] Cancel stale clear tasks when new preset is applied
- [x] Build with Thread Sanitizer — **PASSED** (commit `b1d8700`)

## Phase 4: Engine Transport Extraction (UNLOCKED — Sprint S1)

- [x] Evaluate if Phases 1-3 bring file below thresholds — **No:** 945 lines at Ph1-3 completion, now **1,143 lines** post-T7/T8. Approaching 1,200-line error threshold.
- [ ] **PREREQUISITE:** Add seek state machine unit tests before starting extraction. Current `AudioPlayerStateTests.swift` has only 2 tests (stop + eject) — no coverage of play/pause/seek/scheduleFrom state transitions, seekID matching, or guard interactions.
- [ ] Re-baseline Phase 4 plan against current 1,143-line file (T7 added stream source node, T8 added isolated deinit + @concurrent)
- [ ] Decompose in place: new files stay in `Audio/` (current location). Folder moves to `Audio/Playback/` are deferred to post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
- [ ] If needed: create `AudioEngineTransport.swift`
- [ ] If needed: extract `setupEngine`, `rewireForCurrentFile`, `scheduleFrom`, `startEngineIfNeeded`, `startProgressTimer`
- [ ] If needed: refactor `play/pause/stop/seek` to use transport controller
- [ ] Consider stream bridge methods (`activateStreamBridge`, `deactivateStreamBridge`, `streamSourceNode`) — these were added by T7 and may belong with transport or in a separate stream-bridge extract
- [ ] Oracle review on seek state machine changes

## Post-Implementation (Phases 1-3 — COMPLETE)

- [x] Run full swiftlint check: no new warnings — **0 violations**
- [x] Update state.md with final line counts
- [x] Update deprecated.md with removed patterns
- [x] Commits with descriptive messages (7 commits across 3 phases + 4 review rounds)
- [x] PR #52 created and **merged**

## Post-Implementation (Phase 4 — after Phase 4 lands)

- [ ] Remove `// swiftlint:disable file_length` if file is under 600 lines (currently 1,143 — requires Phase 4)
- [ ] Remove `// swiftlint:disable:this type_body_length` if type body is under 400 lines (currently ~1,100 — requires Phase 4)
- [ ] Run full swiftlint check with Thread Sanitizer
- [ ] Update state.md with post-Phase 4 line counts
- [ ] Update deprecated.md with any removed patterns
