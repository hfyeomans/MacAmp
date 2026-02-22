# Research: AudioPlayer.swift Decomposition

> **Description:** Research findings for decomposing AudioPlayer.swift from a single 1,070-line class into focused controllers using the facade pattern already established by the WindowCoordinator refactor (PR #45).
> **Purpose:** Contains all analysis, measurements, dependency mapping, and reference patterns needed to create an informed decomposition plan.

---

## 1. Origin: Code Review Findings

This task originates from a comprehensive code review of the last 5 merged PRs (#43–#48), conducted on 2026-02-18. The review covered:

- PR #48 — Memory & CPU optimization (SPSC audio thread, lazy skin loading)
- PR #46 — WindowCoordinator cleanup (observation, safe singleton, DI)
- PR #45 — WindowCoordinator decomposition (1,357 → 223 lines)
- PR #44 — Snyk ast-grep upgrade
- PR #43 — Balance slider color fix + volume/balance persistence

### Relevant Review Finding (PR #43)

PR #43 added two swiftlint inline suppressions to `AudioPlayer.swift`:

```swift
// Line 1:
// swiftlint:disable file_length

// Line 28:
final class AudioPlayer { // swiftlint:disable:this type_body_length
```

These were added because the PR increased the file size when adding volume/balance persistence (`UserDefaults` save/restore + `Keys` enum). The review flagged this as a code smell:

> **`swiftlint:disable file_length` and `swiftlint:disable:this type_body_length` added to `AudioPlayer.swift` — these are code smell indicators. The file may benefit from decomposition (similar to what PR #45 did for WindowCoordinator).**

The review also noted:

> **`UserDefaults.standard.set()` called on every `didSet` of volume/balance — this fires on every drag gesture frame. Consider debouncing or only persisting on `onEnded`.**

---

## 2. SwiftLint Configuration vs AudioPlayer.swift

### Project Thresholds (`.swiftlint.yml`)

| Rule | Warning | Error | AudioPlayer.swift |
|------|---------|-------|-------------------|
| `file_length` | 600 | 1,200 | **1,070 lines** — exceeds warning by 78%, approaching error |
| `type_body_length` | 400 | 600 | **~1,040 lines** — exceeds error threshold |

### Inline Suppressions

The file currently has 2 swiftlint suppressions:

1. `// swiftlint:disable file_length` (line 1) — disables for entire file
2. `// swiftlint:disable:this type_body_length` (line 28) — disables for class declaration

These suppressions indicate the file has organically grown past the project's own code quality standards. Rather than raising thresholds or accumulating more suppressions, decomposition is the correct fix.

---

## 3. Current File Structure Analysis

### AudioPlayer.swift — 1,070 lines

```
Lines   1-7     Imports + FourCC extension
Lines   8-24    Legacy extraction comments
Lines  26-175   Class declaration, properties, init, deinit
Lines 176-221   State machine (transition, setDerivedState, shouldIgnoreCompletion)
Lines 223-520   Track Management (addTrack, playTrack, play, pause, stop, eject)
Lines 522-626   EQ Control (setPreamp, setEqBand, toggleEq, presets, auto-EQ)
Lines 628-776   Engine Wiring (setupEngine, configureEQ, rewireForCurrentFile, scheduleFrom, startEngine, startProgressTimer)
Lines 778-788   Visualizer Tap (2 forwarding methods)
Lines 790-900   Seeking / Scrubbing (seekToPercent, seek)
Lines 902-966   Visualizer Support (getFrequencyData, getRMSData, getWaveformSamples, snapshotButterchurnFrame)
Lines 968-1007  onPlaybackEnded (completion handling)
Lines 1009-1070 Playlist Navigation (nextTrack, previousTrack, handlePlaylistAction)
```

### MARK Sections (8 total)

| MARK Section | Lines | Responsibility |
|-------------|-------|----------------|
| Extracted Controllers | 42-64 | Visualizer forwarding properties |
| Track Management | 223-520 | Load, play, pause, stop, eject, EQ |
| Engine Wiring | 628-776 | AVAudioEngine setup, graph, scheduling |
| Visualizer Tap | 778-788 | 2 thin forwarding methods |
| Seeking / Scrubbing | 790-900 | Percent-based and time-based seeking |
| Visualizer Support | 902-966 | Frequency/RMS/waveform data access |
| Butterchurn Audio Data | 955-966 | Single forwarding method |
| Playlist navigation | 1009-1070 | Next/previous track, playlist actions |

---

## 4. Dependency Analysis

### Properties by Category

**AVAudioEngine internals (private, implementation detail):**
- `audioEngine`, `playerNode`, `eqNode`, `audioFile`
- `progressTimer`, `playheadOffset`
- `currentSeekID`, `isHandlingCompletion`, `seekGuardActive`

**EQ state (public, UI-bound):**
- `preamp`, `eqBands`, `isEqOn`, `eqAutoEnabled`, `useLogScaleBands`
- `eqPresetStore`, `userPresets`, `appliedAutoPresetTrack`, `autoEQTask`

**Playback state (public, UI-bound):**
- `playbackState`, `isPlaying`, `isPaused`
- `currentTrackURL`, `currentTitle`, `currentDuration`, `currentTime`, `playbackProgress`
- `volume`, `balance`
- `currentTrack`, `currentMediaType`
- `channelCount`, `bitrate`, `sampleRate`

**Extracted controllers (already decomposed):**
- `visualizerPipeline` (VisualizerPipeline)
- `playlistController` (PlaylistController)
- `videoPlaybackController` (VideoPlaybackController)
- `eqPresetStore` (EQPresetStore)

### Cross-Cutting Concerns

1. **EQ methods access `eqNode` directly** — `setPreamp()`, `setEqBand()`, `toggleEq()`, `configureEQ()` all mutate `eqNode` bands/gain
2. **Seeking accesses `audioFile`, `playerNode`, `audioEngine`** — tightly coupled to engine internals
3. **`play()`/`pause()`/`stop()` access both audio and video** — dual-path routing
4. **`playTrack()` is the most complex method** — handles media type detection, cleanup, state transitions, EQ auto-preset, and delegates to `loadAudioFile()` and `videoPlaybackController`
5. **`onPlaybackEnded()` bridges seek, playlist, and state** — completion handler for both scheduled segments and seek operations

### Method Call Graph (key methods)

```
playTrack()
  ├── updatePlaylistPosition()
  ├── detectMediaType()
  ├── removeVisualizerTapIfNeeded() [if switching media types]
  ├── videoPlaybackController.cleanup() [if switching]
  ├── loadAudioFile() → rewireForCurrentFile() → scheduleFrom()
  ├── videoPlaybackController.loadVideo()
  ├── applyAutoPreset()
  └── play()
        ├── startEngineIfNeeded()
        ├── installVisualizerTapIfNeeded()
        ├── playerNode.play()
        └── startProgressTimer()

seek()
  ├── scheduleFrom() → playerNode.scheduleSegment()
  ├── startEngineIfNeeded()
  ├── installVisualizerTapIfNeeded()
  └── startProgressTimer()

onPlaybackEnded()
  ├── transition(.stopped)
  ├── nextTrack() → handlePlaylistAction()
  └── removeVisualizerTapIfNeeded()
```

---

## 5. Existing Decomposition Patterns in Codebase

### WindowCoordinator Facade Pattern (PR #45)

The WindowCoordinator was decomposed from 1,357 → 223 lines using:

1. **Extracted controllers:** `WindowVisibilityController`, `WindowResizeController`, `WindowSettingsObserver`, `WindowDelegateWiring`, `WindowFramePersistence`
2. **Facade forwarding:** The coordinator keeps the public API unchanged with one-line forwarding methods
3. **Stored references:** Each controller receives what it needs via init parameters
4. **@Observable on facade only:** Extracted controllers are not @Observable themselves (they mutate state on the facade)

```swift
// WindowCoordinator.swift (after decomposition)
func minimizeKeyWindow() { visibility.minimizeKeyWindow() }
func showEQWindow() { visibility.showEQWindow() }
func updateVideoWindowSize(to pixelSize: CGSize) { resizeController.updateVideoWindowSize(to: pixelSize) }
```

### Already-Extracted AudioPlayer Controllers

AudioPlayer has already extracted:
- `PlaylistController` (273 lines) — playlist state, shuffle, navigation
- `VideoPlaybackController` (297 lines) — AVPlayer lifecycle for video files
- `VisualizerPipeline` (677 lines) — audio tap, FFT, SPSC buffer
- `EQPresetStore` (187 lines) — preset persistence and import

These follow the same pattern: extracted responsibility with forwarding properties on AudioPlayer.

---

## 6. Decomposition Candidates

### Candidate A: EQ Controller (~120 lines extractable)

**What:** All equalizer control methods + `eqNode` ownership + auto-EQ logic

**Methods to extract:**
- `setPreamp(value:)` (lines 523-531)
- `setEqBand(index:value:)` (lines 533-538)
- `toggleEq(isOn:)` (lines 540-544)
- `applyPreset(_:)` (lines 547-551)
- `applyEQPreset(_:)` (lines 553-558)
- `getCurrentEQPreset(name:)` (lines 560-562)
- `saveUserPreset(named:)` (lines 564-570)
- `deleteUserPreset(id:)` (lines 572-574)
- `importEqfPreset(from:)` (lines 576-583)
- `savePresetForCurrentTrack()` (lines 585-590)
- `applyAutoPreset(for:)` (lines 592-608)
- `setAutoEQEnabled(_:)` (lines 610-620)
- `generateAutoPreset(for:)` (lines 622-626)
- `configureEQ()` (lines 636-655) — owns EQ node configuration

**Properties to move:**
- `eqNode` (AVAudioUnitEQ)
- `preamp`, `eqBands`, `isEqOn`, `eqAutoEnabled`, `useLogScaleBands`
- `eqPresetStore` (already extracted, would nest under EQ controller)
- `appliedAutoPresetTrack`, `autoEQTask`

**Coupling:** EQ controller needs access to `audioEngine` to attach/connect `eqNode`. This can be passed as an init parameter or the engine wiring can happen in AudioPlayer.

**Risk:** Low. EQ methods are self-contained. The `eqNode` is only accessed by EQ methods and `rewireForCurrentFile()`.

### Candidate B: Engine/Transport Controller (~200 lines extractable)

**What:** AVAudioEngine lifecycle, file scheduling, progress timer

**Methods to extract:**
- `setupEngine()` (lines 629-634)
- `rewireForCurrentFile()` (lines 657-680)
- `scheduleFrom(time:seekID:)` (lines 684-746)
- `startEngineIfNeeded()` (lines 748-753)
- `startProgressTimer()` (lines 755-776)

**Properties to move:**
- `audioEngine`, `playerNode`
- `audioFile`, `progressTimer`, `playheadOffset`

**Coupling:** High. `play()`, `pause()`, `stop()`, `seek()`, `playTrack()` all directly access `playerNode` and `audioEngine`. Extracting these requires refactoring every transport method to go through the controller.

**Risk:** Medium-High. The seek/schedule/completion pipeline is the most complex and bug-prone area (see `seekGuardActive`, `currentSeekID`, `isHandlingCompletion`). Changing this risks regressions.

### Candidate C: Seeking Controller (~120 lines extractable)

**What:** `seekToPercent()` and `seek()` methods

**Methods to extract:**
- `seekToPercent(_:resume:)` (lines 794-821)
- `seek(to:resume:)` (lines 824-900)

**Coupling:** Very high. `seek()` accesses `audioFile`, `playerNode`, `progressTimer`, `currentSeekID`, `seekGuardActive`, `scheduleFrom()`, `startEngineIfNeeded()`, `installVisualizerTapIfNeeded()`, `startProgressTimer()`, `transition()`, `onPlaybackEnded()`. This is a cross-cutting orchestration method, not a separable concern.

**Risk:** High. Not recommended as a standalone extraction — seeking is deeply entangled with transport.

### Candidate D: Visualizer Forwarding Consolidation (~70 lines removable)

**What:** Reduce visualizer forwarding boilerplate by exposing `visualizerPipeline` directly or consolidating forwarding properties

**Current forwarding:**
- `visualizerLevels` → `visualizerPipeline.levels`
- `useSpectrumVisualizer` → `AppSettings.instance().visualizerMode`
- `visualizerSmoothing` → `visualizerPipeline.smoothing`
- `visualizerPeakFalloff` → `visualizerPipeline.peakFalloff`
- `getFrequencyData(bands:)` (40 lines, own implementation — not a forward)
- `getRMSData(bands:)` → `visualizerPipeline.getRMSData(bands:)`
- `getWaveformSamples(count:)` → `visualizerPipeline.getWaveformSamples(count:)`
- `snapshotButterchurnFrame()` → `visualizerPipeline.snapshotButterchurnFrame()`
- `installVisualizerTapIfNeeded()` → `visualizerPipeline.installTap(on:)`
- `removeVisualizerTapIfNeeded()` → `visualizerPipeline.removeTap()` + `clearData()`

**Note:** `getFrequencyData(bands:)` (lines 904-943) is a standalone 40-line method with its own logarithmic scaling logic — it doesn't forward to `visualizerPipeline`. It could be moved to `VisualizerPipeline` itself.

**Risk:** Low. These are thin wrappers.

---

## 7. Recommended Extraction Priority

| Priority | Candidate | Lines Saved | Risk | Justification |
|----------|-----------|-------------|------|---------------|
| **1** | A: EQ Controller | ~120 | Low | Self-contained, no seek/transport entanglement |
| **2** | D: Visualizer consolidation | ~70 | Low | Move `getFrequencyData` to pipeline, remove pure forwards |
| **3** | B: Engine/Transport | ~200 | Medium-High | Largest gain but highest coupling to transport methods |
| **4** | C: Seeking | ~120 | High | Too entangled, defer unless combined with B |

### Expected Result

After extracting A and D (safest extractions):
- AudioPlayer.swift: ~1,070 - 120 - 70 = **~880 lines**
- Still above the 600-line warning but below the 1,200 error
- Two swiftlint suppressions can be reduced to one (`file_length` disable only)

After additionally extracting B:
- AudioPlayer.swift: ~880 - 200 = **~680 lines**
- Closer to the warning threshold
- `type_body_length` suppression can be removed

Full decomposition (A + B + D):
- AudioPlayer.swift: **~680 lines** — facade with transport orchestration
- New `EqualizerController.swift`: ~150 lines
- `VisualizerPipeline.swift`: +40 lines (absorb `getFrequencyData`)
- Total codebase line count stays roughly the same

---

## 8. External Callers of AudioPlayer

### Who accesses AudioPlayer directly?

```
PlaybackCoordinator.swift — audioPlayer.play/pause/stop/addTrack/nextTrack/previousTrack
MacAmpApp.swift — creates AudioPlayer, passes to coordinator
WinampMainWindow.swift — @Environment(AudioPlayer.self) for UI bindings
WinampEqualizerWindow.swift — EQ controls (setPreamp, setEqBand, toggleEq, presets)
WinampPlaylistWindow.swift — playlist display, track selection
Various views — isPlaying, currentTitle, volume, balance, playbackProgress
```

**Key constraint:** The facade pattern means AudioPlayer's public API must not change. All extractions must use internal controllers with forwarding methods on AudioPlayer.

---

## 9. The FourCC Extension

Lines 8-19 contain a `String` extension for FourCC codes:

```swift
extension String {
    init(fourCC: FourCharCode) { ... }
}
```

This is a utility extension that doesn't belong in `AudioPlayer.swift`. It should be moved to a utilities file or removed if unused.

### Usage check needed:
- Is `String(fourCC:)` actually used anywhere in the codebase? If not, it can be deleted entirely.

---

## 10. Volume/Balance Persistence Concern

From the code review:

```swift
var volume: Float = 0.75 {
    didSet {
        playerNode.volume = volume
        videoPlaybackController.volume = volume
        UserDefaults.standard.set(volume, forKey: Keys.volume)  // Every drag frame!
    }
}
```

`UserDefaults.standard.set()` is called on every `didSet` during drag gestures. While `UserDefaults` batches writes internally, this is unnecessary churn. The EQ controller extraction is a natural place to move volume/balance persistence with debouncing.

---

## 11. Reference: Other Audio/ Directory Files

| File | Lines | Responsibility |
|------|-------|----------------|
| `AudioPlayer.swift` | 1,070 | Main playback + EQ + engine + seeking |
| `VisualizerPipeline.swift` | 677 | Audio tap, FFT, SPSC buffer |
| `PlaybackCoordinator.swift` | 352 | Routes audio vs stream vs video |
| `VideoPlaybackController.swift` | 297 | AVPlayer for video files |
| `PlaylistController.swift` | 273 | Playlist state, shuffle, navigation |
| `StreamPlayer.swift` | 199 | Internet radio playback |
| `EQPresetStore.swift` | 187 | EQ preset persistence |
| `MetadataLoader.swift` | 171 | Async track/video metadata |

AudioPlayer.swift is the largest file in the Audio directory and the second-largest in the project (after VisualizerPipeline.swift at 677 lines, which is within thresholds).
