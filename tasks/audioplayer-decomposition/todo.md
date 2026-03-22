# TODO: AudioPlayer.swift Decomposition

> **Description:** Checklist of all implementation tasks for decomposing AudioPlayer.swift, derived from the plan.
> **Purpose:** Each item is a discrete, verifiable unit of work. Items are checked off as completed.

---

## Phase 1: Extract EqualizerController — COMPLETE (PR #52)

- [x] Create EqualizerController.swift, move EQ methods/state, add forwarding
- [x] Build with Thread Sanitizer — PASSED

## Phase 2: Consolidate Visualizer Forwarding — COMPLETE (PR #52)

- [x] Move getFrequencyData to VisualizerPipeline, consolidate MARK sections
- [x] Build with Thread Sanitizer — PASSED

## Phase 3: Clean Up FourCC Extension — COMPLETE (PR #52)

- [x] Delete unused FourCC extension
- [x] Build succeeds — PASSED

## Phase 4: Engine + Stream Bridge + Transport Extraction (Sprint S1)

### Step 0: Seek State Machine Characterization Tests (PREREQUISITE)
- [ ] Add test: playTrack sets seekGuardActive then clears
- [ ] Add test: stop resets currentSeekID
- [ ] Add test: shouldIgnoreCompletion returns true for mismatched seekID
- [ ] Add test: shouldIgnoreCompletion returns true when seekGuardActive && seekID == nil
- [ ] Add test: shouldIgnoreCompletion returns true when stopped(.manual) or stopped(.ejected)
- [ ] `swift test` passes with new tests
- [ ] Commit: "test: add seek state machine characterization tests"

### Step 1: Create AudioEngineController.swift
- [ ] Create `MacAmpApp/Audio/AudioEngineController.swift` with class skeleton
- [ ] Move engine properties: audioEngine, playerNode, audioFile, progressTimer, playheadOffset
- [ ] Move stream bridge properties: streamSourceNode, streamRingBuffer
- [ ] Inject dependencies: eqNode, visualizerPipeline
- [ ] Add callback properties: onProgressUpdate, onPlaybackEnded
- [ ] Build succeeds

### Step 2: Move Engine Wiring Methods
- [ ] Move setupEngine() (called from init)
- [ ] Move rewireForCurrentFile() → rewireForFile(_ file:)
- [ ] Move scheduleFrom(time:seekID:) — wire completion to onPlaybackEnded callback
- [ ] Move startEngineIfNeeded()
- [ ] Move startProgressTimer() — wire progress to onProgressUpdate callback
- [ ] Build with Thread Sanitizer — PASSES
- [ ] Commit: "refactor: extract engine wiring to AudioEngineController"

### Step 3: Move Stream Bridge
- [ ] Move makeStreamRenderBlock (static)
- [ ] Move activateStreamBridge(ringBuffer:sampleRate:)
- [ ] Move deactivateStreamBridge()
- [ ] Add isBridgeActive tracking + callback to AudioPlayer
- [ ] Build with Thread Sanitizer — PASSES
- [ ] Commit: "refactor: extract stream bridge to AudioEngineController"

### Step 4: Move Visualizer Tap + Audio Transport
- [ ] Move installVisualizerTapIfNeeded()
- [ ] Move removeVisualizerTapIfNeeded()
- [ ] Add playAudio(), pauseAudio(), stopAudio() methods
- [ ] Add setVolume/setBalance methods
- [ ] Add isPlayerNodePlaying property
- [ ] Build with Thread Sanitizer — PASSES
- [ ] Commit: "refactor: extract visualizer tap and audio transport to AudioEngineController"

### Step 5: Update AudioPlayer to Use Controller
- [ ] Create engine instance in init
- [ ] Wire callbacks (onProgressUpdate, onPlaybackEnded)
- [ ] Update play/pause/stop/eject to use engine methods
- [ ] Update loadAudioFile to use engine
- [ ] Update seek/seekToPercent to use engine
- [ ] Update volume/balance didSet to use engine.setVolume/setBalance
- [ ] Update activateStreamBridge/deactivateStreamBridge to forward
- [ ] Update isEngineRendering to read from engine
- [ ] Update isBridgeActive to read from engine
- [ ] Update isolated deinit to call engine.shutdown()
- [ ] Remove all direct audioEngine/playerNode/streamSourceNode access from AudioPlayer
- [ ] Build with Thread Sanitizer — PASSES
- [ ] `swift test` passes (all 40+ tests)
- [ ] Commit: "refactor: wire AudioPlayer through AudioEngineController"

### Step 6: Oracle Review
- [ ] Run `/codex-oracle-workflow` review on uncommitted changes
- [ ] Address all ACTIONABLE findings
- [ ] Commit fixes

### Step 7: Verification
- [ ] Verify line counts: AudioPlayer < 800, AudioEngineController < 500
- [ ] Verify swiftlint: no new violations (suppressions still needed but file_length safe)
- [ ] Run `swift test` with Thread Sanitizer
- [ ] Update state.md with final metrics
- [ ] Create PR for user review

## Post-Phase 4

- [ ] Remove `// swiftlint:disable file_length` if AudioPlayer under 600 (unlikely without Phase 5)
- [ ] Remove `// swiftlint:disable:this type_body_length` if type body under 600 (unlikely without Phase 5)
- [ ] Update shared `_context/state.md` and `_context/tasks_index.md`
