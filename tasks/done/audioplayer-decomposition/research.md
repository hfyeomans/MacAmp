# Research: AudioPlayer.swift Decomposition

> **Description:** Research findings for decomposing AudioPlayer.swift. Originally written for Phases 1-3 (1,070 lines), re-baselined for Phase 4 (1,143 lines post-T7/T8).
> **Purpose:** Contains all analysis, measurements, dependency mapping, and reference patterns needed to create an informed decomposition plan.

---

## Phase 4 Re-Baseline (2026-03-22)

### Why Re-Baseline Is Needed

AudioPlayer.swift grew from 945 lines (post Phase 1-3) to **1,143 lines** after:
- **T7 (PR #57):** Added Stream Bridge section — `streamSourceNode`, `streamRingBuffer`, `isBridgeActive`, `isEngineRendering`, `makeStreamRenderBlock`, `activateStreamBridge`, `deactivateStreamBridge` (~161 lines)
- **T8 (PR #58):** Changed `deinit` to `isolated deinit`, added `@concurrent` patterns

The original Phase 4 plan targeted ~200 lines of engine transport extraction to bring the file from ~945 → ~680. The file is now 1,143 — the extraction surface is larger and more urgent.

### Current SwiftLint Status

| Rule | Warning | Error | AudioPlayer.swift | Status |
|------|---------|-------|-------------------|--------|
| `file_length` | 600 | **1,200** | **1,143** | 57 lines from ERROR |
| `type_body_length` | 400 | **600** | ~1,130 | **WAY OVER ERROR** |

Two inline suppressions remain: `// swiftlint:disable file_length` (line 1) and `// swiftlint:disable:this type_body_length` (line 8).

### Current File Structure (1,143 lines)

| Section | Lines | Count | Responsibility |
|---------|-------|-------|----------------|
| Imports + class decl + Keys | 1-12 | 12 | Boilerplate |
| Engine properties | 14-28 | 15 | audioEngine, playerNode, audioFile, stream bridge props |
| Extracted controllers + forwarding | 30-151 | 122 | EQ, visualizer, playlist, video forwarding |
| init + deinit | 153-191 | 39 | Setup, volume restore, callbacks |
| State machine | 193-227 | 35 | transition, setDerivedState, shouldIgnoreCompletion |
| Track Management | 229-414 | 186 | addTrack, playTrack, loadAudioFile |
| Transport (play/pause/stop/eject) | 416-532 | 117 | play(), pause(), stop(), eject() |
| EQ Forwarding methods | 534-553 | 20 | One-liners to EqualizerController |
| **Engine Wiring** | 555-712 | **158** | setupEngine, rewireForCurrentFile, scheduleFrom, startEngineIfNeeded, startProgressTimer |
| Visualizer Tap | 714-724 | 11 | install/remove tap |
| **Stream Bridge** | 726-886 | **161** | makeStreamRenderBlock, activateStreamBridge, deactivateStreamBridge |
| **Seeking/Scrubbing** | 888-998 | **111** | seekToPercent, seek |
| Visualizer Forwarding | 1000-1017 | 18 | getFrequencyData, getRMS, getWaveform |
| onPlaybackEnded | 1019-1058 | 40 | Completion handling |
| Playlist navigation | 1060-1143 | 84 | next/previous, handlePlaylistAction |

### Extraction Candidates for Phase 4

**Three major blocks** are extractable (430 lines total):

1. **Engine Wiring (158 lines):** setupEngine, rewireForCurrentFile, scheduleFrom, startEngineIfNeeded, startProgressTimer
2. **Stream Bridge (161 lines):** makeStreamRenderBlock, activateStreamBridge, deactivateStreamBridge
3. **Seeking (111 lines):** seekToPercent, seek

These three blocks share a common dependency: they all operate on `audioEngine`, `playerNode`, `streamSourceNode`, and `equalizer.eqNode`.

### Coupling Analysis

**Properties accessed by Engine Wiring + Stream Bridge + Seeking:**
- `audioEngine` (owned by AudioPlayer, shared across all three)
- `playerNode` (owned by AudioPlayer, used by engine wiring + transport + seeking)
- `equalizer.eqNode` (owned by EqualizerController, wired into engine graph)
- `audioFile` (set by loadAudioFile, read by scheduleFrom + seek)
- `streamSourceNode` / `streamRingBuffer` (stream bridge state)
- `progressTimer` / `playheadOffset` (progress tracking state)
- `currentSeekID` / `seekGuardActive` / `isHandlingCompletion` (seek state machine)
- `visualizerPipeline` (tap install/remove)
- `volume` / `balance` (applied to nodes after wiring)

**Key coupling point:** `play()`, `pause()`, `stop()` directly access `playerNode` and `audioEngine`. If engine wiring is extracted, transport methods either:
- (a) Call through the extracted controller
- (b) Keep a reference to playerNode (leaky but pragmatic)

**Stream Bridge coupling:** `activateStreamBridge` and `deactivateStreamBridge` are called from `PlaybackCoordinator` (external). They rewire the entire engine graph. `rewireForCurrentFile` also calls `deactivateStreamBridge` to clean up before local file playback.

### External Callers

**Stream Bridge (external):**
- `PlaybackCoordinator.swift` — calls `activateStreamBridge(ringBuffer:sampleRate:)` and `deactivateStreamBridge()`
- `StreamPlayer.swift` — calls `deactivateStreamBridge()` on cleanup

**Transport (external):**
- `PlaybackCoordinator.swift` — calls `play()`, `pause()`, `stop()`, `eject()`
- UI views (via PlaybackCoordinator) — never call AudioPlayer transport directly

**Seeking (external):**
- `PlaybackCoordinator.swift` — calls `seekToPercent()`, `seek(to:)`
- `MainWindowSlidersLayer.swift` — binding to `seekToPercent`

**`isEngineRendering` (external):**
- `VisualizerView.swift` — reads `audioPlayer.isEngineRendering` to gate animation
- `OscilloscopeView.swift` — same
- `ButterchurnWebView.swift` — uses `isEngineRendering` for data gating

**`isBridgeActive` (external):**
- `PlaybackCoordinator.swift` — reads to determine if stream bridge needs cleanup

### Test Coverage

`AudioPlayerStateTests.swift` — only 2 tests:
- `stop()` → `.stopped(.manual)`
- `eject()` → `.stopped(.ejected)`

No tests for: play, pause, seek, seekToPercent, scheduleFrom, seek state machine guards, stream bridge lifecycle.

### Architecture Constraint

Per D-STRUCTURE decision (2026-03-15): decompose in place. New files go to `MacAmpApp/Audio/` alongside `AudioPlayer.swift`. Do not move to target folders during S1.

---

## Phase 1-3 Research (HISTORICAL — completed, see below)

*(Original Phase 1-3 research preserved for reference — sections 1-11 from original document)*
