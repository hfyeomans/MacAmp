# Plan: AudioPlayer.swift Decomposition

> **Description:** Implementation plan for decomposing AudioPlayer.swift using the facade pattern.
> **Purpose:** Step-by-step extraction plan with code changes, verification steps, and risk assessment.
> **Phase 1-3:** COMPLETE (PR #52 merged). Extracted EqualizerController, consolidated visualizer forwarding, removed FourCC.
> **Phase 4:** Re-baselined 2026-03-22 against 1,143-line file (post-T7/T8). Oracle-reviewed extraction strategy.

---

## Phase 4: Engine + Stream Bridge + Transport Extraction

### Oracle Review Summary (2026-03-22, gpt-5.3-codex xhigh)

1. Engine wiring + stream bridge must stay in ONE controller (shared format invariants, -10868 lessons)
2. Keep seek state machine in AudioPlayer — partial move splits one state machine across two owners
3. If node ownership moves, transport must follow (play/pause/stop touch playerNode/audioEngine)
4. Facade pattern preserved — callers continue using AudioPlayer API
5. Add seek characterization tests BEFORE extraction to prevent blind-spot regressions

### Extraction Target

| What Moves | Lines | Destination |
|------------|-------|-------------|
| Engine Wiring (setupEngine, rewireForCurrentFile, scheduleFrom, startEngineIfNeeded, startProgressTimer) | 158 | AudioEngineController.swift |
| Stream Bridge (makeStreamRenderBlock, activateStreamBridge, deactivateStreamBridge) | 161 | AudioEngineController.swift |
| Audio Transport (engine-level play/pause/stop on playerNode) | ~50 | AudioEngineController.swift |
| Visualizer Tap (install/remove) | 11 | AudioEngineController.swift |
| Engine properties (audioEngine, playerNode, audioFile, streamSourceNode, streamRingBuffer, progressTimer, playheadOffset) | ~15 | AudioEngineController.swift |

**Total extracted:** ~395 lines
**AudioPlayer after:** ~748 lines (down from 1,143)
**New file:** AudioEngineController.swift (~420 lines including class boilerplate)

### What Stays in AudioPlayer

| What Stays | Reason |
|------------|--------|
| Seek state machine (currentSeekID, seekGuardActive, isHandlingCompletion, shouldIgnoreCompletion) | Oracle: partial move splits state machine across two owners |
| seekToPercent / seek | Tightly coupled to seek state machine + onPlaybackEnded |
| onPlaybackEnded | Uses seek guards, playlist navigation, state transitions |
| playTrack (orchestration) | Routes between audio/video, calls engine controller for audio |
| play/pause/stop/eject (orchestration) | Orchestrate video + audio; delegate engine operations to controller |
| Track Management | Playlist operations, metadata loading |
| Playlist Navigation | next/previous track handling |
| All forwarding (EQ, visualizer, etc.) | Unchanged facade surface |
| isBridgeActive, isEngineRendering | Observable state — stays in AudioPlayer, updated by callbacks from controller |

### What Stays vs What Was Planned Originally

The original Phase 4 plan proposed extracting an `AudioEngineTransport` focused on the seek/transport pipeline. The Oracle review changed the strategy: **engine graph management + stream bridge is the safer extraction** because those methods are more self-contained, while seek has tentacles everywhere.

Seeking extraction is deferred to a future Phase 5 (after seek tests stabilize the behavior).

---

## Implementation Steps

### Step 0: Seek State Machine Characterization Tests (PREREQUISITE)

Add tests to `AudioPlayerStateTests.swift` that capture current seek-related behavior:

- `playTrack()` sets `seekGuardActive = true` then clears after delay
- `stop()` resets `currentSeekID` and calls `scheduleFrom(time: 0)`
- `shouldIgnoreCompletion` returns true for mismatched seekID
- `shouldIgnoreCompletion` returns true when `seekGuardActive && seekID == nil`
- `shouldIgnoreCompletion` returns true when stopped(.manual) or stopped(.ejected)

These tests lock in current behavior before refactoring.

### Step 1: Create AudioEngineController.swift

New file: `MacAmpApp/Audio/AudioEngineController.swift`

```swift
@MainActor
final class AudioEngineController {
    // Engine internals (moved from AudioPlayer)
    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    private(set) var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var playheadOffset: Double = 0

    // Stream bridge state
    private var streamSourceNode: AVAudioSourceNode?
    private var streamRingBuffer: LockFreeRingBuffer?

    // External dependencies (injected)
    private let eqNode: AVAudioUnitEQ
    private let visualizerPipeline: VisualizerPipeline

    // Callbacks to AudioPlayer for state updates
    var onProgressUpdate: ((Double, Double) -> Void)?  // (currentTime, progress)
    var onPlaybackEnded: ((UUID?) -> Void)?  // seekID for completion filtering

    init(eqNode: AVAudioUnitEQ, visualizerPipeline: VisualizerPipeline) {
        self.eqNode = eqNode
        self.visualizerPipeline = visualizerPipeline
        setupEngine()
    }
}
```

### Step 2: Move Engine Wiring Methods

Move from AudioPlayer to AudioEngineController:
- `setupEngine()` → `private func setupEngine()`
- `rewireForCurrentFile()` → `func rewireForFile(_ file: AVAudioFile)`
- `scheduleFrom(time:seekID:)` → `func scheduleFrom(time:seekID:) -> Bool`
- `startEngineIfNeeded()` → `@discardableResult func startEngineIfNeeded() -> Bool`
- `startProgressTimer()` → `func startProgressTimer()`

**Signature changes:**
- `rewireForCurrentFile` becomes `rewireForFile(_ file:)` — receives audioFile as parameter
- `scheduleFrom` completion handler calls `self.onPlaybackEnded?(completionID)` instead of `self?.onPlaybackEnded(fromSeekID:)`
- `startProgressTimer` calls `self.onProgressUpdate?(current, progress)` instead of updating properties directly

### Step 3: Move Stream Bridge

Move from AudioPlayer to AudioEngineController:
- `makeStreamRenderBlock(ringBuffer:)` → stays `nonisolated static`
- `activateStreamBridge(ringBuffer:sampleRate:)` → public method
- `deactivateStreamBridge()` → public method

**Returns `isBridgeActive` state** via a property or callback so AudioPlayer can update its observable `isBridgeActive`.

### Step 4: Move Visualizer Tap Helpers

Move from AudioPlayer to AudioEngineController:
- `installVisualizerTapIfNeeded()` → uses `audioEngine.mainMixerNode` + `visualizerPipeline`
- `removeVisualizerTapIfNeeded()` → same

### Step 5: Add Audio Transport Methods

New methods on AudioEngineController for engine-level transport:
- `func playAudio()` — `playerNode.play()` + `startProgressTimer()`
- `func pauseAudio()` — `playerNode.pause()`
- `func stopAudio()` — `playerNode.stop()` + `progressTimer?.invalidate()`
- `var isPlayerNodePlaying: Bool` — forwards `playerNode.isPlaying`

### Step 6: Wire Volume/Balance

AudioEngineController provides:
- `func setVolume(_ volume: Float)` — sets `playerNode.volume` + `streamSourceNode?.volume`
- `func setBalance(_ balance: Float)` — sets `playerNode.pan` + `streamSourceNode?.pan`

AudioPlayer's `volume`/`balance` didSet calls `engine.setVolume(volume)` / `engine.setBalance(balance)`.

### Step 7: Update AudioPlayer

- Replace direct `audioEngine`/`playerNode` access with `engine.*` calls
- `let engine = AudioEngineController(eqNode: equalizer.eqNode, visualizerPipeline: visualizerPipeline)`
- `play()` calls `engine.playAudio()` for audio path (video path unchanged)
- `pause()` calls `engine.pauseAudio()` for audio path
- `stop()` calls `engine.stopAudio()` + `engine.scheduleFrom(time: 0, seekID: currentSeekID)`
- `loadAudioFile()` calls `engine.loadFile(url:)` or sets `engine.audioFile` then `engine.rewireForFile()`
- `seek()` calls `engine.scheduleFrom()`, `engine.startEngineIfNeeded()`, `engine.playAudio()`, etc.
- `activateStreamBridge`/`deactivateStreamBridge` forward to `engine.*`
- `isEngineRendering` reads from `engine.audioEngine.isRunning`
- `isBridgeActive` updated via engine callback

### Step 8: Update init/deinit

- `init`: Create engine controller, wire callbacks
- `isolated deinit`: Call `engine.shutdown()` (invalidate timer, deactivate bridge, remove tap)

---

## Verification Plan

### Build Verification (each step)
- Build with Thread Sanitizer enabled
- `swift test` passes (40 tests + new seek tests)

### Functional Verification (after all steps)
- Local file playback: play, pause, stop, seek, next/previous
- Internet radio: stream starts, volume works, EQ works, visualizer works
- Switch between local and stream without audio glitches
- Seek to end of track triggers next track
- Repeat modes work (off, all, one)
- EQ stays applied across local/stream switches
- Volume/balance persists and applies to both paths

### Regression Checks
- No -10868 errors (format stickiness after stream bridge)
- No visualizer pause during volume slider drag (pre-existing, shouldn't worsen)
- No seek state corruption (stale completions, guard leaks)
- `isEngineRendering` correctly gates visualizer animation

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Seek completion regression | Medium | HIGH | Characterization tests first; seek stays in AudioPlayer |
| -10868 format errors after bridge | Low | HIGH | Engine+bridge in ONE controller; format lessons preserved |
| Timer/tap lifecycle leak | Medium | Medium | deinit calls engine.shutdown(); tests verify cleanup |
| Volume/balance not propagating | Low | Medium | didSet → engine.setVolume; test with stream + local |
| Public API drift | Low | Low | Facade pattern; all AudioPlayer signatures unchanged |

---

## Expected Results

| Metric | Before | After Phase 4 |
|--------|--------|---------------|
| AudioPlayer.swift | 1,143 lines | ~748 lines |
| AudioEngineController.swift | — | ~420 lines |
| swiftlint file_length | Suppressed (1,143 > 600 warning) | Suppressed (748 > 600, but well under 1,200 error) |
| swiftlint type_body_length | Suppressed (1,130 > 600 error) | ~735 — still over 600 error, suppression remains |
| Seek state machine | In AudioPlayer | In AudioPlayer (unchanged) |
| Future Phase 5 | — | Extract seek when tests are stable |

**Note:** type_body_length suppression cannot be removed until seek extraction (Phase 5) or further forwarding cleanup. Phase 4 gets the file safely away from the 1,200-line error cliff and establishes clean engine ownership boundaries.

---

## Out of Scope (Phase 4)

1. Seek extraction — deferred to Phase 5 (Oracle recommendation)
2. Folder moves — decompose in place per D-STRUCTURE decision
3. PlaybackCoordinator changes — facade preserved
4. Video transport changes — video path stays in AudioPlayer
5. Unit tests for stream bridge lifecycle — future task
