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

### Step 0: Seek State Machine Characterization Tests (PREREQUISITE) — COMPLETE
- [x] Add 13 characterization tests covering stop/eject state reset, initial state, play/pause no-ops, volume/balance persistence, bridge/engine initial values
- [x] Note: seekGuardActive/currentSeekID/shouldIgnoreCompletion are private — tested through observable behavior (state transitions, property values)
- [x] `swift test` passes — 53 tests (up from 40)
- [x] Commit: `ccd0213` "test: add seek state machine characterization tests"

### Steps 1-5: Create AudioEngineController + Rewrite AudioPlayer — COMPLETE
- [x] Create `MacAmpApp/Audio/AudioEngineController.swift` (419 lines → 413 after Oracle fixes)
- [x] Move engine properties, stream bridge, graph wiring, transport, visualizer tap, progress timer
- [x] Inject eqNode + visualizerPipeline, wire callbacks (onProgressUpdate, onPlaybackEnded, onBridgeStateChanged)
- [x] Rewrite AudioPlayer to delegate all engine operations through controller
- [x] Fix volume/balance didSet crash (optional chaining during init)
- [x] Build succeeds, `swift test` passes (53 tests)
- [x] Commit: `5582f0d` "refactor: extract AudioEngineController from AudioPlayer (Phase 4)"

### Step 6: Oracle Review — COMPLETE
- [x] Oracle review (gpt-5.3-codex xhigh) — 3 findings
- [x] [MEDIUM] Fix currentDuration regression — sync from engine file duration after loadAudioFile
- [x] [LOW] Remove no-op async task from scheduleFrom hot path
- [x] [LOW] Noted: completion-ID defensiveness acceptable (all callers pass non-nil)
- [x] Commit: `924bc1e` "fix: address Oracle review findings for Phase 4 extraction"

### Step 7: Verification + PR — COMPLETE
- [x] Line counts: AudioPlayer 705, AudioEngineController 413 (total 1,118)
- [x] `swift test` passes — 53 tests, 0 failures
- [x] Facade preserved — all AudioPlayer public API signatures unchanged
- [x] XcodeBuildMCP build + test with Thread Sanitizer — PASSES
- [x] PR #60 created, user reviewed + manual tested, merged (2026-03-22)

## Post-Phase 4

- [ ] Remove `// swiftlint:disable file_length` if AudioPlayer under 600 (requires Phase 5 seek extraction)
- [ ] Remove `// swiftlint:disable:this type_body_length` if type body under 600 (requires Phase 5 seek extraction)
- [x] Update shared `_context/state.md` and `_context/tasks_index.md` — done (2026-03-22)
