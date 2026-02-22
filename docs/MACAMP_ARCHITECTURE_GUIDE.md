# MacAmp Complete Architecture Guide

**Version:** 2.6.0
**Date:** 2026-02-22
**Project State:** Production-Ready (5-Window System, WindowCoordinator Refactoring, Internet Radio N1-N6 Fixes, Stream Volume/Balance (T5 Phase 1), AudioPlayer Decomposition, PlaylistWindow Decomposition, Swift Testing Migration, Swift 6, macOS 15+/26+)
**Purpose:** Deep technical reference for developers joining or maintaining MacAmp

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Metrics & Current State](#project-metrics--current-state)
3. [Three-Layer Architecture Deep Dive](#three-layer-architecture-deep-dive)
4. [Dual Audio Backend Architecture](#dual-audio-backend-architecture)
4a. [AudioPlayer Decomposition Architecture](#audioplayer-decomposition-architecture)
5. [Skin System Complete Architecture](#skin-system-complete-architecture)
6. [State Management Evolution](#state-management-evolution)
7. [SwiftUI Rendering Techniques](#swiftui-rendering-techniques)
8. [Audio Processing Pipeline](#audio-processing-pipeline)
9. [Internet Radio Streaming](#internet-radio-streaming)
10. [Modern Swift 6 Patterns](#modern-swift-6-patterns)
11. [Component Integration Maps](#component-integration-maps)
12. [Testing Strategies](#testing-strategies)
13. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
14. [Quick Reference](#quick-reference)

---

## Executive Summary

MacAmp is a pixel-perfect recreation of Winamp 2.x for macOS, built entirely with SwiftUI and modern Swift concurrency. It's not just a nostalgic clone—it's a case study in bridging 1997 desktop UI patterns with 2025 Apple platform technologies.

### What Makes MacAmp Unique

1. **Dual Audio Architecture**: Solves the fundamental incompatibility between AVAudioEngine (needed for EQ) and AVPlayer (needed for streaming)
2. **Semantic Sprite System**: Decouples UI components from skin-specific graphics through semantic identifiers
3. **Three-Layer Pattern**: Clean separation inspired by web frameworks (mechanism → bridge → presentation)
4. **Swift 6 Migration**: Full adoption of `@Observable` macro pattern with strict concurrency
5. **Pixel-Perfect Rendering**: Achieves exact Winamp visual fidelity using SwiftUI's absolute positioning

### Architecture Philosophy

```
"The skin is not the app. The app is not the skin."
```

This principle drives every architectural decision. MacAmp's core functionality (playing music, managing playlists, applying EQ) operates independently of any visual representation. A skin is merely a visual theme applied to semantic UI elements.

---

## Project Metrics & Current State

### Codebase Statistics (January 2026)

```
Total Swift Files:        79
Lines of Code:            16,320
Test Coverage:            42% (focused on critical paths)
Supported Formats:        MP3, M4A, FLAC, WAV, AAC, HTTP/HTTPS streams
Skin Compatibility:       100% (Winamp 2.x .wsz files)
macOS Support:            15.0+ (Sequoia), 26.0+ (Tahoe)
Architecture:             SwiftUI + AVFoundation
Deployment:               Developer ID signed, notarization-ready
```

### Component Breakdown (January 2026 - Post AudioPlayer Refactoring)

```
┌────────────────────────────────────────────────────────┐
│ Component               │ Files │ LoC   │ Status       │
├────────────────────────┼───────┼───────┼──────────────┤
│ Audio Engine           │  10   │ 3,457 │ Production   │
│   - AudioPlayer.swift  │   1   │   945 │ Mechanism    │
│   - EqualizerController│   1   │   198 │ Mechanism    │
│   - LockFreeRingBuffer │   1   │   212 │ Mechanism    │
│   - EQPresetStore      │   1   │   187 │ Mechanism    │
│   - MetadataLoader     │   1   │   171 │ Mechanism    │
│   - PlaylistController │   1   │   273 │ Mechanism    │
│   - VideoPlaybackCtrl  │   1   │   297 │ Mechanism    │
│   - VisualizerPipeline │   1   │   675 │ Mechanism    │
│   - StreamPlayer       │   1   │   212 │ Mechanism    │
│   - PlaybackCoord.     │   1   │   352 │ Mechanism    │
│ Window Management      │  11   │ 1,470 │ Production   │
│   - WindowCoordinator  │   1   │   223 │ Bridge/Facade│
│   - Coordinator+Layout │   1   │   153 │ Bridge       │
│   - WindowRegistry     │   1   │    83 │ Bridge       │
│   - FramePersistence   │   1   │   146 │ Bridge       │
│   - VisibilityCtrl     │   1   │   161 │ Bridge       │
│   - ResizeController   │   1   │   312 │ Bridge       │
│   - SettingsObserver   │   1   │   114 │ Bridge       │
│   - DelegateWiring     │   1   │    54 │ Bridge       │
│   - DockingTypes       │   1   │    50 │ Mechanism    │
│   - DockingGeometry    │   1   │   109 │ Mechanism    │
│   - FrameStore         │   1   │    65 │ Mechanism    │
│ Skin System            │   6   │ 2,134 │ Production   │
│ UI Views               │  12   │ 3,456 │ Production   │
│ State Management       │   4   │   987 │ Production   │
│ Models                 │  16   │ 2,389 │ Production   │
│   - Track.swift        │   1   │    42 │ Extracted    │
│ Utilities              │   7   │ 2,077 │ Production   │
└────────────────────────────────────────────────────────┘
```

**Metrics Improvement:**
- AudioPlayer.swift: 1,805 → 1,043 lines (-42.2%)
- 5 new focused components extracted
- Zero SwiftLint violations in extracted files
- Full Sendable conformance for Swift 6 readiness

### Recent Architectural Changes (October 2025 - February 2026)

1. **Internet Radio Support**: Added StreamPlayer with PlaybackCoordinator orchestration
2. **Swift 6 Migration**: Converted from ObservableObject to @Observable macro
3. **Semantic Sprites**: Replaced hard-coded sprite names with semantic identifiers
4. **Thread Safety**: Added @MainActor isolation and strict Sendable conformance
5. **Hot Skin Swapping**: Enabled runtime skin changes without app restart
6. **Clutter Bar Controls (v0.7.8)**: Implemented 4 of 5 clutter bar buttons
   - O Button: Options menu with time display toggle, double-size, repeat, shuffle (Ctrl+O, Ctrl+T)
   - A Button: Always On Top window level control (Ctrl+A)
   - I Button: Track Information dialog with metadata display (Ctrl+I)
   - D Button: Double Size UI scaling 100%/200% (Ctrl+D)
   - V Button: Visualizer control (scaffolded, pending implementation)
7. **Three-State Repeat Mode (v0.7.9)**: Migrated from boolean to enum-based repeat system
8. **Stream Volume Control (T5 Phase 1, v1.0.6)**: Centralized volume/balance routing through PlaybackCoordinator. Volume and balance sliders now propagate to all backends (AudioPlayer, StreamPlayer, VideoPlaybackController) via `setVolume()`/`setBalance()`. Added capability flags (`supportsEQ`, `supportsBalance`, `supportsVisualizer`) to dim unavailable controls during stream playback. Removed AudioPlayer's direct knowledge of VideoPlaybackController for volume propagation.
   - RepeatMode enum: off/all/one matching Winamp 5 Modern skins
   - "1" badge overlay for repeat-one mode (ZStack pattern)
   - Manual skip vs auto-advance distinction with isManualSkip parameter
   - Options menu with 3 explicit items and checkmarks
8. **Five-Window Architecture (TASK 2, Days 1-8)**: Expanded from 3 to 5 windows
   - Video Window: Native macOS video playback with VIDEO.bmp chrome (Days 1-6)
   - Milkdrop Window: Visualization container with GEN.bmp chrome (Days 7-8)
   - WindowDelegateMultiplexer pattern for each window controller
   - Unified focus state management across all 5 windows
   - Magnetic docking cluster detection for all window combinations

9. **AudioPlayer Decomposition (v0.8.0, January 2026)**: Full Option C extraction
   - Reduced AudioPlayer from 1,805 to 1,043 lines (-42.2%)
   - Extracted 5 focused components following three-layer architecture:
     - **EQPresetStore** (187 lines): EQ preset persistence (UserDefaults + JSON file)
     - **MetadataLoader** (171 lines): Async track/video metadata extraction (nonisolated struct)
     - **PlaylistController** (273 lines): Playlist state and navigation logic
     - **VideoPlaybackController** (297 lines): AVPlayer lifecycle and observer management
     - **VisualizerPipeline** (675 lines): Audio tap, FFT processing, SPSC shared buffer, Butterchurn data
   - Extracted **Track** model to `Models/Track.swift` with Sendable conformance (42 lines)
   - AudioPlayer remains in Mechanism layer, now focused on AVAudioEngine lifecycle
   - Full Swift 6 strict concurrency compliance (Sendable, @MainActor, Task.detached)
   - Background I/O for preset persistence (fire-and-forget pattern)
   - Oracle review: 10/10 quality gate achieved

10. **WindowCoordinator Refactoring (February 2026)**: Facade + Composition decomposition
   - Reduced WindowCoordinator from 1,357 to 223 lines (-84%)
   - Extracted 10 focused types using Facade + Composition pattern:
     - **WindowRegistry** (83 lines): Window ownership and lookup
     - **WindowFramePersistence** (146 lines): Frame save/load/suppression
     - **WindowVisibilityController** (161 lines): Show/hide/toggle + @Observable state
     - **WindowResizeController** (312 lines): Resize + docking-aware layout
     - **WindowSettingsObserver** (114 lines): Settings observation lifecycle
     - **WindowDelegateWiring** (54 lines): Delegate setup static factory
     - **WindowDockingTypes** (50 lines): Sendable value types
     - **WindowDockingGeometry** (109 lines): Pure geometry functions (nonisolated)
     - **WindowFrameStore** (65 lines): UserDefaults persistence wrapper
     - **WindowCoordinator+Layout** (153 lines): Initialization/presentation extension
   - Acyclic dependency graph (no controller-to-controller dependencies)
   - 5 Oracle reviews (gpt-5.3-codex, xhigh reasoning), all passed
   - 2 critical concurrency bugs found and fixed (debounce cancellation, observer lifecycle)
   - Swift 6.2 compliance: Grade A+ (95/100)
   - Thread Sanitizer clean on all phases
   - 10 unit tests added for pure types
   - See MULTI_WINDOW_ARCHITECTURE.md §10 for complete details

---

## Three-Layer Architecture Deep Dive

MacAmp's architecture follows a strict three-layer separation, inspired by web frameworks but adapted for SwiftUI's declarative paradigm.

### Layer Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│                   "What the user sees"                       │
│                                                               │
│  • Skin graphics (MAIN.BMP, EQ_EX.BMP, etc.)               │
│  • Color schemes (VISCOLOR.TXT, PLEDIT.TXT)                │
│  • Window layouts (from skin regions.txt)                   │
│  • Semantic → Actual sprite mapping                         │
├───────────────────────────────────────────────────────────────┤
│                      BRIDGE LAYER                            │
│                "How components find visuals"                 │
│                                                               │
│  • SpriteResolver (semantic → actual mapping)               │
│  • SimpleSpriteImage (sprite rendering)                     │
│  • DockingController (multi-window coordination)            │
│  • WindowFocusState (window focus tracking)                 │
│  • WindowFocusDelegate (focus event handling)               │
│  • ViewModels (business logic)                              │
├───────────────────────────────────────────────────────────────┤
│                     MECHANISM LAYER                          │
│                  "What the app does"                         │
│                                                               │
│  • PlaybackCoordinator (playback orchestration)             │
│  • AudioPlayer (AVAudioEngine for local files)              │
│  • EQPresetStore (preset persistence)                       │
│  • MetadataLoader (async metadata extraction)               │
│  • PlaylistController (playlist state/navigation)           │
│  • VideoPlaybackController (AVPlayer lifecycle)             │
│  • VisualizerPipeline (audio tap/FFT processing)            │
│  • StreamPlayer (AVPlayer for internet radio)               │
│  • PlaylistManager (queue management)                       │
│  • SkinManager (skin loading/hot-swap)                      │
│  • AppSettings (preferences persistence)                    │
└─────────────────────────────────────────────────────────────┘
```

### Layer Communication Rules

1. **Downward Only**: Upper layers can call lower layers, never reverse
2. **No Skip**: Presentation must go through Bridge to reach Mechanism
3. **State Flows Up**: State changes propagate upward via @Observable
4. **Commands Flow Down**: User actions flow downward as method calls

### Practical Example: Playing a Song

```swift
// USER CLICKS PLAY BUTTON IN UI

// 1. PRESENTATION LAYER (WinampMainWindow.swift)
SimpleSpriteImage(
    sprite: skinManager.resolvedSprites.playButton,  // Visual sprite
    action: .button(
        onClick: { playbackCoordinator.play() }      // Command flows down
    )
)

// 2. BRIDGE LAYER (PlaybackCoordinator.swift)
@MainActor
@Observable
final class PlaybackCoordinator {
    func play() {
        if let track = playlistManager.currentTrack {
            Task {
                await play(track: track)  // Orchestrates backends
            }
        }
    }

    func play(track: Track) async {
        // Route to appropriate backend
        if track.isStream {
            audioPlayer.stop()           // Prevent dual playback
            await streamPlayer.play(url: track.url)
        } else {
            streamPlayer.stop()           // Prevent dual playback
            audioPlayer.playTrack(track: track)
        }
    }
}

// 3. MECHANISM LAYER (AudioPlayer.swift)
@Observable
final class AudioPlayer {
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()

    func playTrack(track: Track) {
        // Load file
        guard let file = try? AVAudioFile(forReading: track.url) else { return }

        // Schedule playback
        playerNode.scheduleFile(file, at: nil)

        // Start engine and player
        try? engine.start()
        playerNode.play()

        // State flows up
        isPlaying = true
        currentTrack = track
    }
}
```

### Why Three Layers?

1. **Skin Independence**: Core functionality works without any skin
2. **Testability**: Can test audio playback without UI
3. **Modularity**: Can swap rendering layer (e.g., AppKit instead of SwiftUI)
4. **Maintainability**: Clear boundaries prevent spaghetti code

---

## Dual Audio Backend Architecture

MacAmp's most complex architectural challenge: supporting both local file playback with EQ and internet radio streaming. AVFoundation provides two incompatible audio systems that cannot be merged.

### The Fundamental Problem

```
AVAudioEngine (for local files):
┌──────────────┐    ┌─────────┐    ┌───────────┐    ┌──────────┐
│ AVAudioFile  │───▶│ Player  │───▶│ EQ Unit   │───▶│ Output   │
└──────────────┘    │  Node   │    │ (10-band) │    │  Node    │
                    └─────────┘    └───────────┘    └──────────┘
                          │              │                 │
                          └──────────────┴─────────────────┘
                                         │
                                    [Audio Tap]
                                         │
                                   ┌───────────┐
                                   │Visualizer │
                                   └───────────┘

✅ 10-band parametric EQ
✅ Real-time spectrum analysis
✅ Waveform visualization
❌ Cannot play HTTP streams
❌ Cannot handle HLS adaptive streaming


AVPlayer (for internet radio):
┌──────────────┐                              ┌──────────────┐
│  HTTP URL    │─────────────────────────────▶│ System Audio │
└──────────────┘         (Direct path)        └──────────────┘
                    No access to audio pipeline
                    (AVPlayer.volume is the only control)

✅ HTTP/HTTPS streaming
✅ HLS adaptive bitrate
✅ ICY metadata extraction
✅ Volume control (AVPlayer.volume, T5 Phase 1)
❌ Cannot insert AVAudioUnitEQ
❌ Cannot tap audio for visualization
❌ No access to raw PCM buffers
❌ No balance/pan control (no .pan property on AVPlayer)
```

### The Architectural Solution

Instead of trying to force these systems together (impossible), MacAmp uses the **Orchestrator Pattern** with PlaybackCoordinator as the central controller.

```swift
// PlaybackCoordinator.swift (Full orchestration logic)
@MainActor
@Observable
final class PlaybackCoordinator {
    // Dependencies
    private let audioPlayer: AudioPlayer       // Local files with EQ
    private let streamPlayer: StreamPlayer     // Internet radio

    // MARK: - Computed Play State (PR #49 - N1/N2 fixes)
    //
    // isPlaying and isPaused are computed properties derived from the active
    // audio source. This eliminates stale-state bugs where stored booleans
    // would drift out of sync with the actual backend state during buffering
    // stalls, error recovery, or rapid play/pause toggling.

    /// True when audio is actively rendering to speakers.
    /// During stream buffering stalls, returns false (audio is not being rendered).
    var isPlaying: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPlaying
        case .radioStation: return streamPlayer.isPlaying && !streamPlayer.isBuffering
        case .none: return false
        }
    }

    /// True when user has explicitly paused playback.
    /// False during buffering stalls (not user-initiated) and error states.
    var isPaused: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPaused
        case .radioStation:
            return !streamPlayer.isPlaying && !streamPlayer.isBuffering && streamPlayer.error == nil
        case .none: return false
        }
    }

    // Stored state
    private(set) var currentSource: PlaybackSource?
    private(set) var currentTitle: String?
    private(set) var currentTrack: Track?  // For playlist position tracking

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    // MARK: - Capability Flags (T5 Phase 1)
    //
    // These computed flags tell the UI which controls are available for the
    // current playback backend. AVPlayer (streams) has no EQ, no .pan, and
    // no audio tap — so those controls should be visually dimmed.

    /// Whether the stream backend is currently active and not in error state.
    private var isStreamBackendActive: Bool {
        guard case .radioStation = currentSource else { return false }
        return streamPlayer.error == nil
    }

    /// EQ is only available for local file playback (AVAudioEngine).
    var supportsEQ: Bool { !isStreamBackendActive }

    /// Balance/pan requires AVAudioPlayerNode.pan (AVPlayer has no .pan property).
    var supportsBalance: Bool { !isStreamBackendActive }

    /// Visualizer requires an audio tap on AVAudioEngine's mixer node.
    /// Phase 2 Loopback Bridge will enable this for streams.
    var supportsVisualizer: Bool { !isStreamBackendActive }

    // MARK: - Callback Wiring (PR #49 - N3 fix)
    //
    // AudioPlayer uses two separate callbacks instead of a single
    // externalPlaybackHandler. This split eliminates ambiguity about
    // whether a callback is for metadata refresh or track advance.

    init(audioPlayer: AudioPlayer, streamPlayer: StreamPlayer) {
        self.audioPlayer = audioPlayer
        self.streamPlayer = streamPlayer

        // Sync persisted volume/balance to stream player on init
        streamPlayer.volume = audioPlayer.volume
        streamPlayer.balance = audioPlayer.balance

        // Fires when placeholder track is replaced with loaded metadata
        self.audioPlayer.onTrackMetadataUpdate = { [weak self] track in
            guard let self else { return }
            self.updateTrackMetadata(track)
        }

        // Fires on end-of-track auto-advance
        self.audioPlayer.onPlaylistAdvanceRequest = { [weak self] track in
            guard let self else { return }
            Task { @MainActor in
                await self.handleExternalPlaylistAdvance(track: track)
            }
        }
    }

    // MARK: - Volume & Balance Routing (T5 Phase 1)
    //
    // Volume and balance changes propagate to ALL backends unconditionally.
    // This is simpler and more robust than checking which backend is active —
    // idle players accept the value as a no-op. AudioPlayer persists to
    // UserDefaults; StreamPlayer applies to AVPlayer.volume; coordinator
    // also propagates to VideoPlaybackController.

    /// Propagate volume to all backends. Called by UI volume slider binding.
    func setVolume(_ vol: Float) {
        audioPlayer.volume = vol        // Persists + sets playerNode.volume
        streamPlayer.volume = vol       // Sets AVPlayer.volume
        audioPlayer.videoPlaybackController.volume = vol
    }

    /// Propagate balance to all backends. Called by UI balance slider binding.
    /// StreamPlayer stores balance but cannot apply it (no AVPlayer .pan property).
    func setBalance(_ bal: Float) {
        audioPlayer.balance = bal       // Persists + sets playerNode.pan
        streamPlayer.balance = bal      // Stored for Phase 2 Loopback Bridge
    }

    // MARK: - Context-Aware Navigation (PR #49 - N4 fix)
    //
    // next()/previous() pass coordinator's currentTrack to AudioPlayer
    // so PlaylistController can resolve position even during stream
    // playback when audioPlayer.currentTrack is nil.

    func next() async {
        let action = audioPlayer.nextTrack(from: currentTrack, isManualSkip: true)
        await handlePlaylistAdvance(action: action)
    }

    func previous() async {
        let action = audioPlayer.previousTrack(from: currentTrack)
        await handlePlaylistAdvance(action: action)
    }

    // MARK: - Unified Playback Control

    func play(url: URL) async {
        if url.isFileURL {
            streamPlayer.stop()
            audioPlayer.addTrack(url: url)
            audioPlayer.play()
            currentSource = .localTrack(url)
            // ... title formatting ...
        } else {
            audioPlayer.stop()
            let station = RadioStation(name: url.lastPathComponent, streamURL: url)
            await streamPlayer.play(station: station)
            currentSource = .radioStation(station)
            currentTitle = streamPlayer.streamTitle ?? station.name
        }
    }

    func togglePlayPause() {
        switch currentSource {
        case .localTrack:
            if audioPlayer.isPlaying { audioPlayer.pause() }
            else { audioPlayer.play() }
            // No manual isPlaying/isPaused sync needed - computed from backend

        case .radioStation:
            if streamPlayer.isPlaying { streamPlayer.pause() }
            else { streamPlayer.resume() }
            // No manual isPlaying/isPaused sync needed - computed from backend

        case .none:
            break
        }
    }

    func stop() {
        audioPlayer.stop()
        streamPlayer.stop()
        currentSource = nil
        currentTitle = nil
        currentTrack = nil
        // isPlaying/isPaused automatically return false (currentSource is nil)
    }

    // Computed properties for UI
    var displayTitle: String {
        switch currentSource {
        case .radioStation:
            if streamPlayer.isBuffering {
                return "Buffering..."
            }
            return streamPlayer.streamTitle ?? currentTitle ?? "Internet Radio"

        case .localTrack:
            return currentTitle ?? "Unknown Track"

        case .none:
            return "MacAmp"
        }
    }
}
```

**Key architectural changes (PR #49, February 2026):**

1. **Computed play state**: `isPlaying` and `isPaused` are now computed properties that derive from the active backend, not stored booleans. This eliminates an entire class of state-synchronization bugs where stored flags would drift during buffering stalls, error recovery, or rapid user interaction.

2. **Split callbacks**: The former `externalPlaybackHandler` closure on AudioPlayer was split into two purpose-specific callbacks:
   - `onTrackMetadataUpdate: ((Track) -> Void)?` -- fires when a placeholder track is replaced with loaded metadata (title/artist arrived)
   - `onPlaylistAdvanceRequest: ((Track) -> Void)?` -- fires on end-of-track auto-advance, requesting the coordinator to play the next track

3. **Context-aware navigation**: `next()` and `previous()` pass `currentTrack` (the coordinator's track reference) to `audioPlayer.nextTrack(from:)` / `audioPlayer.previousTrack(from:)`. This resolves playlist position correctly during stream playback when `audioPlayer.currentTrack` is nil.

**Key architectural changes (T5 Phase 1, February 2026):**

4. **Centralized volume/balance routing**: `setVolume()` and `setBalance()` on PlaybackCoordinator propagate to all backends (AudioPlayer, StreamPlayer, VideoPlaybackController) unconditionally. This replaced direct `AudioPlayer.volume` didSet propagation to VideoPlaybackController and direct UI bindings to AudioPlayer properties.

5. **Capability flags**: `supportsEQ`, `supportsBalance`, and `supportsVisualizer` are computed properties on PlaybackCoordinator that return `false` when the stream backend is active. The UI uses these to dim EQ sliders, the balance slider, and (future) visualizer controls during stream playback. When a stream enters error state, flags re-enable so the user is not stuck with dimmed controls.

6. **StreamPlayer volume/balance**: StreamPlayer now has `volume` (applied to `AVPlayer.volume`) and `balance` (stored for Phase 2 Loopback Bridge). PlaybackCoordinator syncs AudioPlayer's persisted values to StreamPlayer on init.

7. **Asymmetric slider bindings**: Volume and balance sliders use `Binding<Float>(get: { audioPlayer.volume }, set: { playbackCoordinator.setVolume($0) })` instead of direct `$audioPlayer.volume` bindings. Reads come from AudioPlayer (source of truth for persistence); writes route through the coordinator for fan-out to all backends.

### Integration with UI

The UI uses PlaybackCoordinator's capability flags to enable/disable controls based on the active backend:

```swift
// File: MacAmpApp/Views/WinampMainWindow.swift (simplified excerpt)
// Purpose: Main window UI with coordinator-routed controls
// Context: Volume/balance route through PlaybackCoordinator; capability flags dim controls

struct WinampMainWindow: View {
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(StreamPlayer.self) var streamPlayer

    var body: some View {
        ZStack {
            // Title display (works for both local and streams)
            Text(playbackCoordinator.displayTitle)
                .at(x: 111, y: 27)

            // Play button (works for both)
            SimpleSpriteImage(
                sprite: skinManager.resolvedSprites.playButton,
                action: .button(onClick: {
                    playbackCoordinator.togglePlayPause()
                })
            ).at(x: 39, y: 88)

            // Volume slider - reads from AudioPlayer, writes through coordinator
            buildVolumeSlider()
            buildBalanceSlider()
        }
    }

    // MARK: - Volume & Balance (T5 Phase 1)
    // Asymmetric bindings: get from AudioPlayer, set through PlaybackCoordinator

    func buildVolumeSlider() -> some View {
        let volumeBinding = Binding<Float>(
            get: { audioPlayer.volume },
            set: { playbackCoordinator.setVolume($0) }
        )
        WinampVolumeSlider(volume: volumeBinding)
            .at(Coords.volumeSlider)
    }

    func buildBalanceSlider() -> some View {
        let balanceBinding = Binding<Float>(
            get: { audioPlayer.balance },
            set: { playbackCoordinator.setBalance($0) }
        )
        WinampBalanceSlider(balance: balanceBinding)
            .at(Coords.balanceSlider)
            .opacity(playbackCoordinator.supportsBalance ? 1.0 : 0.5)
            .allowsHitTesting(playbackCoordinator.supportsBalance)
            .help(playbackCoordinator.supportsBalance
                  ? "Balance"
                  : "Balance unavailable during streaming")
    }
}

// File: MacAmpApp/Views/WinampEqualizerWindow.swift (simplified excerpt)
// EQ sliders dim during stream playback via capability flag

eqSliders
    .opacity(playbackCoordinator.supportsEQ ? 1.0 : 0.5)
    .allowsHitTesting(playbackCoordinator.supportsEQ)
```

### Critical Implementation Details

1. **State Must Be @State**: PlaybackCoordinator MUST be stored as @State, not computed
   ```swift
   // ✅ CORRECT
   @State private var playbackCoordinator = PlaybackCoordinator(...)

   // ❌ WRONG - Will reset on every render!
   var playbackCoordinator: PlaybackCoordinator {
       PlaybackCoordinator(...)
   }
   ```

2. **Prevent Simultaneous Playback**: Always stop both backends before starting
   ```swift
   private func ensureExclusivePlayback() {
       audioPlayer.stop()    // Stop local playback
       streamPlayer.stop()   // Stop stream playback
   }
   ```

3. **Handle State Transitions**: Both backends have different state machines
   ```swift
   // AudioPlayer: immediate state changes
   audioPlayer.play()  // isPlaying = true immediately

   // StreamPlayer: async state changes
   await streamPlayer.play(url: url)  // Wait for buffering
   ```

---

## AudioPlayer Decomposition Architecture

The AudioPlayer class was refactored in January 2026 following the Option C incremental extraction strategy. This decomposition improves maintainability, testability, and Swift 6 concurrency compliance while preserving the existing API surface for view compatibility.

### Before: Monolithic AudioPlayer (1,805 lines)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AudioPlayer.swift (1,805 lines)                   │
│                     @Observable @MainActor final class                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │   Engine Layer      │  │   State Layer       │  │   UI Data       │  │
│  │   ─────────────     │  │   ───────────       │  │   ───────       │  │
│  │   audioEngine       │  │   playbackState     │  │   currentTitle  │  │
│  │   playerNode        │  │   isPlaying         │  │   currentTime   │  │
│  │   eqNode            │  │   isPaused          │  │   currentDur... │  │
│  │   audioFile         │  │   currentSeekID     │  │   playbackProg. │  │
│  │   progressTimer     │  │   seekGuardActive   │  │   visualizer... │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
│                                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │   EQ/Presets        │  │   Playlist          │  │   Video         │  │
│  │   ─────────────     │  │   ────────          │  │   ─────         │  │
│  │   preamp            │  │   playlist[]        │  │   videoPlayer   │  │
│  │   eqBands[]         │  │   currentTrack      │  │   videoEnd...   │  │
│  │   isEqOn            │  │   currentPlaylist...│  │   videoTime...  │  │
│  │   userPresets[]     │  │   shuffleEnabled    │  │   currentMedia. │  │
│  │   perTrackPresets{} │  │   repeatMode        │  │   videoMetadata │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
│                                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐                       │
│  │   Visualizer        │  │   Metadata          │                       │
│  │   ──────────        │  │   ────────          │                       │
│  │   visualizerTap...  │  │   channelCount      │                       │
│  │   visualizerPeaks[] │  │   bitrate           │                       │
│  │   latestRMS[]       │  │   sampleRate        │                       │
│  │   latestSpectrum[]  │  │                     │                       │
│  │   butterchurn...    │  │                     │                       │
│  └─────────────────────┘  └─────────────────────┘                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### After: Decomposed Architecture (1,043 + 5 components)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Mechanism Layer                             │
│                        (Business Logic & Persistence)                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────────┐  ┌───────────────────────┐                   │
│  │    EQPresetStore      │  │    MetadataLoader     │                   │
│  │    ─────────────      │  │    ──────────────     │                   │
│  │    @MainActor         │  │    nonisolated        │                   │
│  │    @Observable        │  │    struct (static)    │                   │
│  ├───────────────────────┤  ├───────────────────────┤                   │
│  │  • userPresets[]           │  │  • loadTrackMetadata()│                   │
│  │  • perTrackPresets{}       │  │  • loadAudioProperties│                   │
│  │  • loadUserPresets()       │  │  • loadVideoMetadata()│                   │
│  │  • savePreset(:forTrackURL:)│ │                       │                   │
│  │  • importEqfPreset()       │  │  ~171 lines           │                   │
│  │  ~187 lines           │  │  Swift 6.2 @concurrent│                   │
│  └───────────────────────┘  └───────────────────────┘                   │
│                                                                          │
│  ┌───────────────────────┐  ┌───────────────────────┐                   │
│  │  PlaylistController   │  │ VideoPlaybackController│                  │
│  │  ──────────────────   │  │ ─────────────────────  │                  │
│  │  @MainActor           │  │  @MainActor            │                  │
│  │  @Observable          │  │  @Observable           │                  │
│  ├───────────────────────┤  ├───────────────────────┤                   │
│  │  • playlist[]         │  │  • player: AVPlayer?   │                  │
│  │  • currentIndex       │  │  • endObserver         │                  │
│  │  • shuffleEnabled     │  │  • timeObserver        │                  │
│  │  • repeatMode         │  │  • loadVideo()         │                  │
│  │  • nextTrack() → Action│ │  • cleanup()           │                  │
│  │  • previousTrack()    │  │  • onPlaybackEnded     │                  │
│  │  ~273 lines           │  │  ~297 lines            │                  │
│  └───────────────────────┘  └───────────────────────┘                   │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      VisualizerPipeline                            │  │
│  │                      ──────────────────                            │  │
│  │                      @MainActor @Observable                        │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │  • VisualizerSharedBuffer (class, @unchecked Sendable, SPSC)      │  │
│  │  • VisualizerScratchBuffers (class, @unchecked Sendable)          │  │
│  │  • ButterchurnFrame (struct, Sendable)                            │  │
│  │  • installTap() - configures audio tap on mixer                   │  │
│  │  • removeTap() - nonisolated for deinit safety                    │  │
│  │  • makeTapHandler() - static, Sendable closure (SPSC publish)     │  │
│  │  • pollTimer (30 Hz) - consumes shared buffer on main thread      │  │
│  │  • getRMSData() / getWaveformSamples() / snapshotButterchurnFrame │  │
│  │  ~675 lines                                                        │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AudioPlayer (Core Engine)                       │  │
│  │                    ────────────────────────                        │  │
│  │                    @MainActor @Observable                          │  │
│  │                    1,043 lines after extraction                    │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │                                                                    │  │
│  │  Engine Core:                                                      │  │
│  │  ─────────────────────────────────────────────                     │  │
│  │  • audioEngine, playerNode, eqNode                                 │  │
│  │  • audioFile, progressTimer                                        │  │
│  │  • playbackState, isPlaying, isPaused                              │  │
│  │  • currentSeekID, seekGuardActive, isHandlingCompletion            │  │
│  │  • setupEngine(), configureEQ(), rewireForCurrentFile()            │  │
│  │  • scheduleFrom(), startEngineIfNeeded()                           │  │
│  │  • play(), pause(), stop(), eject()                                │  │
│  │  • seekToPercent(), seek()                                         │  │
│  │                                                                    │  │
│  │  Component References:                                             │  │
│  │  ─────────────────────                                             │  │
│  │  • eqPresetStore: EQPresetStore                                    │  │
│  │  • playlistController: PlaylistController                          │  │
│  │  • videoPlaybackController: VideoPlaybackController                │  │
│  │  • visualizerPipeline: VisualizerPipeline                          │  │
│  │                                                                    │  │
│  │  Computed Forwarding (maintains existing bindings):                │  │
│  │  ─────────────────────────────────────────────────                 │  │
│  │  var userPresets: [EQPreset] { eqPresetStore.userPresets }         │  │
│  │  var playlist: [Track] { playlistController.playlist }             │  │
│  │  var videoPlayer: AVPlayer? { videoPlaybackController.player }     │  │
│  │  var shuffleEnabled: Bool {                                        │  │
│  │      get { playlistController.shuffleEnabled }                     │  │
│  │      set { playlistController.shuffleEnabled = newValue }          │  │
│  │  }                                                                 │  │
│  │                                                                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           Presentation Layer                             │
│                             (SwiftUI Views)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Views access AudioPlayer only (never extracted components directly):    │
│                                                                          │
│  • WinampMainWindow      → audioPlayer.play/pause/stop                   │
│  • EqualizerView         → audioPlayer.eqBands, audioPlayer.preamp       │
│  • PlaylistView          → audioPlayer.playlist, audioPlayer.nextTrack   │
│  • SpectrumAnalyzerView  → audioPlayer.getFrequencyData()                │
│  • VideoWindowView       → audioPlayer.videoMetadataString               │
│                                                                          │
│  LAYER BOUNDARY: Views never import or access:                           │
│     EQPresetStore, PlaylistController, VisualizerPipeline, etc.          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Specifications

#### EQPresetStore (`MacAmpApp/Audio/EQPresetStore.swift`)

**Layer:** Mechanism
**Lines:** 187
**Purpose:** Manages persistence of EQ presets (user presets and per-track presets)

```swift
@MainActor
@Observable
final class EQPresetStore {
    // Published State
    private(set) var userPresets: [EQPreset] = []

    // Internal State (not observable)
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]

    // Background I/O with fire-and-forget pattern
    func savePerTrackPresets() {
        let presetsToSave = perTrackPresets  // Capture state
        Task.detached(priority: .utility) {
            // File I/O off main thread
        }
    }

    // Async import with background file reading
    func importEqfPreset(from url: URL) async -> EQPreset? {
        await Task.detached(priority: .userInitiated) {
            // Parse EQF file off main thread
        }.value
    }
}
```

**Key Patterns:**
- Background I/O via `Task.detached` for file operations
- Fire-and-forget saves (captures state before dispatch)
- Merge logic in `loadPerTrackPresets()` preserves in-flight changes
- `Sendable` conformance for `EQPreset` and `EqfPreset`

#### MetadataLoader (`MacAmpApp/Audio/MetadataLoader.swift`)

**Layer:** Mechanism (pure utility)
**Lines:** 171
**Purpose:** Async extraction of audio/video metadata from media files

```swift
struct MetadataLoader {
    // Result Types
    struct TrackMetadata { let title: String; let artist: String; let duration: TimeInterval }
    struct AudioProperties { let channelCount: Int; let bitrate: Int; let sampleRate: Int }
    struct VideoMetadata { let filename: String; let videoType: String; let width: Int; let height: Int }

    // Static async methods (Swift 6.2 @concurrent ready)
    static func loadTrackMetadata(from url: URL) async -> TrackMetadata
    static func loadAudioProperties(from url: URL) async -> AudioProperties?
    static func loadVideoMetadata(from url: URL) async -> VideoMetadata
}
```

**Key Patterns:**
- `nonisolated struct` with static methods (no shared state)
- Pure async functions suitable for `@concurrent` in Swift 6.2
- Graceful fallbacks for missing metadata

#### PlaylistController (`MacAmpApp/Audio/PlaylistController.swift`)

**Layer:** Mechanism
**Lines:** 273
**Purpose:** Playlist state management and navigation logic

```swift
@MainActor
@Observable
final class PlaylistController {
    // Navigation Action (returned to AudioPlayer)
    enum AdvanceAction: Equatable {
        case none
        case restartCurrent
        case playTrack(Track)
        case requestCoordinatorPlayback(Track)
        case endOfPlaylist
    }

    // State
    private(set) var playlist: [Track] = []
    var shuffleEnabled: Bool = false

    // Navigation logic returns actions (AudioPlayer handles execution)
    func nextTrack(isManualSkip: Bool = false) -> AdvanceAction
    func previousTrack() -> AdvanceAction
}
```

**Key Patterns:**
- Returns `AdvanceAction` enum instead of triggering playback directly
- AudioPlayer handles actions via `handlePlaylistAction(_:)` bridge method
- Repeat mode delegates to `AppSettings.instance().repeatMode`
- `pendingTrackURLs` encapsulated with `addPendingURL/removePendingURL` methods

#### VideoPlaybackController (`MacAmpApp/Audio/VideoPlaybackController.swift`)

**Layer:** Mechanism
**Lines:** 297
**Purpose:** AVPlayer lifecycle and observer management for video playback

```swift
@MainActor
@Observable
final class VideoPlaybackController {
    // AVPlayer State
    @ObservationIgnored private(set) var player: AVPlayer?
    private(set) var metadataString: String = ""

    // Observer Management (nonisolated(unsafe) for deinit access)
    @ObservationIgnored nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
    @ObservationIgnored nonisolated(unsafe) private var _playerForCleanup: AVPlayer?

    // Callbacks for cross-component sync
    var onPlaybackEnded: (() -> Void)?
    var onTimeUpdate: ((Double, Double, Double) -> Void)?

    // Lifecycle
    func loadVideo(url: URL, autoPlay: Bool = true)
    func cleanup()  // State reset and observer cleanup

    deinit {
        // Manual observer cleanup (cannot call @MainActor cleanup() from deinit)
        if let observer = timeObserver, let player = _playerForCleanup {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        _playerForCleanup?.pause()
    }
}
```

**Key Patterns:**
- `nonisolated(unsafe)` for properties accessed in deinit
- Callback pattern for AudioPlayer synchronization (`onTimeUpdate` for UI sync)
- `metadataTask` cancelled in cleanup() to prevent race conditions
- State reset in cleanup() prevents stale values after stop
- **deinit performs manual teardown** (cannot call @MainActor cleanup())

#### VisualizerPipeline (`MacAmpApp/Audio/VisualizerPipeline.swift`)

**Layer:** Mechanism
**Lines:** 675
**Purpose:** Audio visualization tap, FFT processing, SPSC shared buffer, and Butterchurn data generation

```swift
@MainActor
@Observable
final class VisualizerPipeline {
    // Tap State (nonisolated(unsafe) for removeTap() in deinit contexts)
    @ObservationIgnored nonisolated(unsafe) private var tapInstalled = false
    @ObservationIgnored nonisolated(unsafe) private weak var mixerNode: AVAudioMixerNode?
    @ObservationIgnored private let sharedBuffer = VisualizerSharedBuffer()
    @ObservationIgnored nonisolated(unsafe) private var pollTimer: Timer?

    // Cached AppSettings flag to avoid per-frame lookup
    var useSpectrum: Bool = true

    // Tap Management
    func installTap(on mixer: AVAudioMixerNode)
    nonisolated func removeTap()  // Safe for deinit
    nonisolated var isTapInstalled: Bool { tapInstalled }

    // Static Tap Handler Factory (publishes via SPSC shared buffer)
    private nonisolated static func makeTapHandler(
        sharedBuffer: VisualizerSharedBuffer,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void
}

// SPSC Shared Buffer (lock-free audio-to-main transfer)
private final class VisualizerSharedBuffer: @unchecked Sendable {
    func tryPublish(from: VisualizerScratchBuffers, ...) -> Bool  // Audio thread (non-blocking trylock)
    func consume() -> VisualizerData?                              // Main thread (blocking lock)
}

// Supporting Types (all Sendable)
struct ButterchurnFrame: Sendable { let spectrum: [Float]; let waveform: [Float]; let timestamp: TimeInterval }
struct VisualizerData: Sendable { let rms: [Float]; let spectrum: [Float]; let waveform: [Float]; ... }
private final class VisualizerScratchBuffers: @unchecked Sendable { ... }
```

**Key Patterns:**
- **SPSC shared buffer** replaces `Task { @MainActor }` for audio-to-main data transfer (zero allocations on audio thread). Uses `os_unfair_lock` with `trylock` on the audio thread (non-blocking, drops frame on contention) and regular lock on the main thread. A generation counter avoids redundant consumption. See `IMPLEMENTATION_PATTERNS.md` SPSC pattern section.
- **30 Hz poll timer** on main thread calls `sharedBuffer.consume()` to pull latest data
- Pre-allocated FFT buffers in `VisualizerScratchBuffers.init()` (no audio-thread allocations)
- Pre-computed Goertzel coefficients (recomputed only on sample rate change, not per-callback)
- `useSpectrum` cached to avoid per-frame AppSettings lookup
- `removeTap()` is `nonisolated` for safe cleanup from AudioPlayer.deinit
- **20-bar RMS** (not 19) per time bucket for spectrum visualization

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Interaction                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         SwiftUI Views (Presentation)                     │
│                                                                          │
│   EqualizerView ──────┐     PlaylistView ──────┐     SpectrumView ────┐  │
│                       │                        │                      │  │
└───────────────────────┼────────────────────────┼──────────────────────┼──┘
                        │                        │                      │
                        ▼                        ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AudioPlayer (Mechanism Layer)                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        Public API                                 │   │
│  │  • play() / pause() / stop()                                      │   │
│  │  • setEqBand(index:value:)          ──────▶ eqPresetStore         │   │
│  │  • nextTrack() / previousTrack()    ──────▶ playlistController    │   │
│  │  • getFrequencyData(bands:)         ──────▶ visualizerPipeline    │   │
│  │  • playVideoFile(url:)              ──────▶ videoController       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Engine Core (retained)                        │   │
│  │  • AVAudioEngine lifecycle                                        │   │
│  │  • AVAudioPlayerNode scheduling                                   │   │
│  │  • Seek guards (currentSeekID, seekGuardActive)                   │   │
│  │  • Progress timer                                                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
          │              │              │              │
          ▼              ▼              ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ EQPreset    │  │ Playlist    │  │ Visualizer  │  │ Video       │
│ Store       │  │ Controller  │  │ Pipeline    │  │ Controller  │
│             │  │             │  │             │  │             │
│ @Observable │  │ @Observable │  │ @Observable │  │ @Observable │
│ @MainActor  │  │ @MainActor  │  │ @MainActor  │  │ @MainActor  │
├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤
│ File I/O    │  │ Navigation  │  │ Core Audio  │  │ AVPlayer    │
│ UserDefaults│  │ Logic       │  │ Realtime    │  │ Observers   │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
          │                               │              │
          ▼                               │              ▼
┌─────────────────────────────┐           │ ┌─────────────────────────────┐
│       App Support Dir       │           │ │         AVPlayer            │
│   • perTrackPresets.json    │           │ │   (Video Playback)          │
│   • UserDefaults            │           │ │                             │
└─────────────────────────────┘           │ └─────────────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────────────┐
                              │    Butterchurn.js / WebGL   │
                              │    (Milkdrop Window)        │
                              └─────────────────────────────┘
```

### File Structure After Extraction

```
MacAmpApp/
├── Audio/
│   ├── AudioPlayer.swift              (~945 lines) - Engine Core + Facade
│   ├── EqualizerController.swift      (~198 lines) - EQ facade (extracted from AudioPlayer)
│   ├── LockFreeRingBuffer.swift       (~212 lines) - SPSC ring buffer for stream audio
│   ├── EQPresetStore.swift            (187 lines) - Preset persistence
│   ├── MetadataLoader.swift           (171 lines) - Track metadata
│   ├── PlaylistController.swift       (273 lines) - Playlist logic
│   ├── VideoPlaybackController.swift  (297 lines) - AVPlayer wrapper
│   ├── VisualizerPipeline.swift       (675 lines) - Audio tap + SPSC + FFT
│   ├── StreamPlayer.swift             (existing) - Internet radio
│   └── PlaybackCoordinator.swift      (existing) - Backend orchestration
│
├── ViewModels/
│   ├── WindowCoordinator.swift        (223 lines) - Window management facade
│   ├── WindowCoordinator+Layout.swift (153 lines) - Layout/presentation extension
│   ├── SkinManager.swift              (existing) - Skin loading
│   └── DockingController.swift        (existing) - Window docking
│
├── Windows/
│   ├── WindowRegistry.swift           (83 lines) - Window ownership
│   ├── WindowFramePersistence.swift   (146 lines) - Frame persistence
│   ├── WindowVisibilityController.swift (161 lines) - Visibility control
│   ├── WindowResizeController.swift   (312 lines) - Resize + docking
│   ├── WindowSettingsObserver.swift   (114 lines) - Settings observation
│   ├── WindowDelegateWiring.swift     (54 lines) - Delegate factory
│   ├── WindowDockingTypes.swift       (50 lines) - Value types
│   ├── WindowDockingGeometry.swift    (109 lines) - Pure geometry
│   ├── WindowFrameStore.swift         (65 lines) - UserDefaults wrapper
│   ├── WinampMainWindowController.swift (existing)
│   ├── WinampEqualizerWindowController.swift (existing)
│   ├── WinampPlaylistWindowController.swift (existing)
│   ├── WinampVideoWindowController.swift (existing)
│   └── WinampMilkdropWindowController.swift (existing)
│
├── Models/
│   ├── Track.swift                    (42 lines) - Track data model (Sendable)
│   ├── EQPreset.swift                 (existing, + Sendable)
│   ├── EqfPreset.swift                (existing, + Sendable)
│   └── ...
```

### Migration Notes

**Computed Forwarding Pattern:**
To maintain backwards compatibility, AudioPlayer exposes extracted state via computed properties:

```swift
// AudioPlayer.swift - Computed forwarding
var playlist: [Track] { playlistController.playlist }
var userPresets: [EQPreset] { eqPresetStore.userPresets }
var videoPlayer: AVPlayer? { videoPlaybackController.player }
var videoMetadataString: String { videoPlaybackController.metadataString }
var shuffleEnabled: Bool {
    get { playlistController.shuffleEnabled }
    set { playlistController.shuffleEnabled = newValue }
}
```

**Bridge Pattern for Playlist Navigation:**
```swift
// AudioPlayer.swift:1021-1042 - Bridge method
private func handlePlaylistAction(_ action: PlaylistController.AdvanceAction) -> PlaylistAdvanceAction {
    switch action {
    case .none: return .none
    case .restartCurrent:
        seek(to: 0, resume: true)  // Always resume for repeat-one
        return .restartCurrent
    case .playTrack(let track):
        playTrack(track: track)
        return .playLocally(track)
    case .requestCoordinatorPlayback(let track):
        return .requestCoordinatorPlayback(track)
    case .endOfPlaylist:
        return .none
    }
}
```

### Swift 6 Concurrency Compliance

All extracted components follow strict Swift 6 concurrency patterns:

| Type | Conformance | Notes |
|------|-------------|-------|
| `Track` | `Sendable` | Value type, all properties Sendable |
| `PlaybackState` | `Sendable` | Enum with Sendable associated values |
| `PlaybackStopReason` | `Sendable` | Simple enum |
| `EQPreset` | `Sendable` | Value type |
| `EqfPreset` | `Sendable` | Value type |
| `ButterchurnFrame` | `Sendable` | Value type with [Float] arrays |
| `VisualizerData` | `Sendable` | Container struct |
| `VisualizerScratchBuffers` | `@unchecked Sendable` | Confined to audio tap queue |
| `VisualizerSharedBuffer` | `@unchecked Sendable` | SPSC lock-free buffer (os_unfair_lock) |

**Background I/O Pattern:**
```swift
// Fire-and-forget save (EQPresetStore.swift:130-146)
func savePerTrackPresets() {
    guard let url = presetsFileURL() else { return }

    // Capture current state for background write
    let presetsToSave = perTrackPresets

    // Perform file I/O off main thread (fire-and-forget with error logging)
    Task.detached(priority: .utility) {
        do {
            let data = try JSONEncoder().encode(presetsToSave)
            try data.write(to: url, options: .atomic)
            AppLog.debug(.audio, "Saved \(presetsToSave.count) per-track presets")
        } catch {
            AppLog.warn(.audio, "Failed to save per-track presets: \(error)")
        }
    }
}
```

### Risk Mitigation

**VisualizerPipeline - SPSC Shared Buffer Safety:**
- `removeTap()` is `nonisolated` and safe to call from deinit
- AudioPlayer.deinit calls `visualizerPipeline.removeTap()` before deallocation
- Audio thread uses `os_unfair_lock_trylock` (non-blocking; drops frame on contention)
- Main thread uses `os_unfair_lock_lock` (safe to block briefly on 30 Hz timer)
- Generation counter prevents redundant consumption of unchanged data
- Poll timer invalidated in `removeTap()` to prevent stale callbacks

**VideoPlaybackController - Observer Cleanup:**
- `cleanup()` removes observers and resets state (called during stop/eject)
- **deinit performs manual observer teardown** (cannot call @MainActor cleanup())
- Shadow property `_playerForCleanup` ensures AVPlayer access in deinit
- `nonisolated(unsafe)` properties enable deinit cleanup without actor hopping

**EQPresetStore - Race Condition Prevention:**
- `loadPerTrackPresets()` merges loaded data with in-memory changes
- `perTrackPresetsLoaded` flag prevents early-save overwrites
- Fire-and-forget pattern captures state snapshot before dispatch

---

## Skin System Complete Architecture

The skin system is MacAmp's crown jewel—a complete implementation of Winamp 2.x skin loading with semantic sprite resolution.

### Skin Loading Pipeline

```
.wsz file (ZIP archive)
         │
         ▼
┌──────────────────┐
│  SkinManager     │
│  - Extract ZIP   │
│  - Parse files   │
└──────────────────┘
         │
    ┌────┴────┬─────────┬──────────┬─────────┐
    ▼         ▼         ▼          ▼         ▼
  main.bmp  eq_ex.bmp  pledit.txt viscolor.txt region.txt
    │         │         │          │         │
    ▼         ▼         ▼          ▼         ▼
┌────────────────────────────────────────────────────┐
│           Skin Model (in-memory)                   │
│  - Image cache (NSImage)                          │
│  - Color schemes (parsed)                         │
│  - Window regions (if present)                    │
└────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────┐
│  SpriteResolver  │
│  - Semantic map  │
│  - Fallback gen  │
└──────────────────┘
         │
         ▼
   ResolvedSprites
   (Ready for UI)
```

### Semantic Sprite Mapping

Traditional approach (fragile):
```swift
// ❌ Hardcoded sprite names break with different skins
Image("MAIN_PLAY_BUTTON_NORMAL")  // What if skin uses PLAY_NORM?
```

MacAmp's approach (resilient):
```swift
// ✅ Semantic identifier works with any skin
SimpleSpriteImage(sprite: skinManager.resolvedSprites.playButton)
```

### SpriteResolver Implementation

```swift
// SpriteResolver.swift (Core resolution logic)
final class SpriteResolver {
    private let skin: Skin
    private var cache: [SemanticSprite: ResolvedSprite] = [:]

    func resolve(_ semantic: SemanticSprite) -> ResolvedSprite {
        // Check cache
        if let cached = cache[semantic] {
            return cached
        }

        // Try primary mapping
        if let sprite = tryPrimaryMapping(semantic) {
            cache[semantic] = sprite
            return sprite
        }

        // Try alternative names (handle skin variations)
        if let sprite = tryAlternativeMapping(semantic) {
            cache[semantic] = sprite
            return sprite
        }

        // Generate fallback
        let fallback = generateFallback(semantic)
        cache[semantic] = fallback
        return fallback
    }

    private func tryPrimaryMapping(_ semantic: SemanticSprite) -> ResolvedSprite? {
        let primaryNames = mapSemanticToPrimary(semantic)

        for name in primaryNames {
            if let sprite = skin.sprites[name] {
                return ResolvedSprite(
                    image: sprite.image,
                    rect: sprite.rect,
                    source: .skin(name)
                )
            }
        }

        return nil
    }

    private func mapSemanticToPrimary(_ semantic: SemanticSprite) -> [String] {
        switch semantic {
        case .playButton:
            return ["CBUTTONS_PLAY_NORM", "PLAY_BUTTON", "MAIN_PLAY"]
        case .pauseButton:
            return ["CBUTTONS_PAUSE_NORM", "PAUSE_BUTTON", "MAIN_PAUSE"]
        case .digit(let n):
            return ["NUM_\(n)", "DIGIT_\(n)", "NUMBER_\(n)"]
        case .eqSliderThumb:
            return ["EQ_SLIDER", "EQSLID", "EQ_THUMB"]
        // ... hundreds more mappings
        }
    }

    private func generateFallback(_ semantic: SemanticSprite) -> ResolvedSprite {
        // Generate appropriate placeholder based on semantic type
        switch semantic {
        case .playButton, .pauseButton, .stopButton:
            return generateButtonFallback(size: CGSize(width: 23, height: 18))
        case .digit:
            return generateDigitFallback()
        case .eqSliderThumb:
            return generateSliderFallback()
        default:
            return generateGenericFallback()
        }
    }
}
```

### Skin File Parsing

```swift
// VISCOLOR.TXT Parser (Visualization colors)
struct VisColorParser {
    static func parse(_ data: Data) -> VisualizationColors {
        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
        var colors = VisualizationColors()

        for (index, line) in lines.enumerated() {
            guard !line.isEmpty, !line.hasPrefix("//") else { continue }
            let components = line.components(separatedBy: ",")
            guard components.count == 3 else { continue }

            let r = Int(components[0]) ?? 0
            let g = Int(components[1]) ?? 0
            let b = Int(components[2]) ?? 0
            let color = NSColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)

            switch index {
            case 0...17: colors.normal.append(color)    // 18 spectrum colors
            case 18: colors.background = color           // Visualizer background
            case 19: colors.gridlines = color            // Spectrum gridlines
            case 20: colors.waveform = color             // Oscilloscope line
            case 21: colors.waveformDot = color          // Oscilloscope dots
            case 22: colors.volumeBar = color            // Volume indicator
            // ... continue for all 24 colors
            }
        }

        return colors
    }
}

// PLEDIT.TXT Parser (Playlist colors)
struct PLEditParser {
    static func parse(_ data: Data) -> PlaylistColors {
        let text = String(data: data, encoding: .windowsCP1252) ??
                   String(data: data, encoding: .utf8) ?? ""

        var colors = PlaylistColors()
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.components(separatedBy: "=")
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            if let color = parseColor(value) {
                switch key.uppercased() {
                case "NORMAL": colors.normal = color
                case "CURRENT": colors.current = color
                case "NORMALBG": colors.normalBackground = color
                case "SELECTEDBG": colors.selectedBackground = color
                case "MBFONT": colors.minibroserFont = color
                case "MBBG": colors.minibrowserBackground = color
                // ... all other color keys
                }
            }
        }

        return colors
    }

    private static func parseColor(_ hex: String) -> NSColor? {
        // Parse #RRGGBB or RRGGBB format
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6 else { return nil }

        let scanner = Scanner(string: cleaned)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        return NSColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
```

### Hot Skin Swapping

```swift
// SkinManager.swift (Hot-swap implementation)
@MainActor
@Observable
final class SkinManager {
    private(set) var currentSkin: Skin?
    private(set) var resolvedSprites: ResolvedSpriteCollection = .empty
    private(set) var isLoading = false

    func loadSkin(from url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Extract and parse skin
            let skin = try await extractSkin(from: url)

            // Create resolver with new skin
            let resolver = SpriteResolver(skin: skin)

            // Resolve all sprites
            let resolved = ResolvedSpriteCollection(
                // Main window
                mainBackground: resolver.resolve(.mainWindowBackground),
                playButton: resolver.resolve(.playButton),
                pauseButton: resolver.resolve(.pauseButton),
                stopButton: resolver.resolve(.stopButton),
                // ... resolve all sprites
            )

            // Atomic update (UI will redraw automatically)
            currentSkin = skin
            resolvedSprites = resolved

            // Save preference
            AppSettings.shared.lastSkinPath = url.path

        } catch {
            print("Failed to load skin: \(error)")
            // Keep current skin on failure
        }
    }
}
```

---

## State Management Evolution

MacAmp has undergone a complete state management migration from ObservableObject to Swift 6's @Observable macro.

### Migration Timeline

```
Phase 1 (Original): ObservableObject + @Published
         ↓
Phase 2 (Hybrid): Mix of ObservableObject and @Observable
         ↓
Phase 3 (Current): Full @Observable with @MainActor
```

### Before: ObservableObject Pattern

```swift
// ❌ OLD: ObservableObject pattern (verbose, error-prone)
class AudioPlayer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Manual timer setup for updates
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentTime()
            }
            .store(in: &cancellables)
    }

    private func updateCurrentTime() {
        // Must manually trigger @Published
        objectWillChange.send()
        currentTime = playerNode.currentTime
    }
}

// Usage in View
struct PlayerView: View {
    @StateObject private var audioPlayer = AudioPlayer()  // Or @ObservedObject

    var body: some View {
        Text("\(audioPlayer.currentTime)")
    }
}
```

### After: @Observable Pattern

```swift
// ✅ NEW: @Observable pattern (clean, automatic)
@MainActor
@Observable
final class AudioPlayer {
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0.0
    private(set) var duration: Double = 0.0

    // No @Published needed!
    // No objectWillChange needed!
    // No cancellables needed!

    init() {
        // Timer still needed but simpler
        Task {
            while true {
                try await Task.sleep(for: .milliseconds(100))
                updateCurrentTime()
            }
        }
    }

    private func updateCurrentTime() {
        // Automatic change detection!
        currentTime = playerNode.currentTime
    }
}

// Usage in View
struct PlayerView: View {
    @Environment(AudioPlayer.self) var audioPlayer  // Clean injection

    var body: some View {
        Text("\(audioPlayer.currentTime)")
    }
}
```

### Key Migration Patterns

1. **Class Declaration**
   ```swift
   // Before
   class MyClass: ObservableObject

   // After
   @Observable
   final class MyClass
   ```

2. **Published Properties**
   ```swift
   // Before
   @Published var value: Int = 0

   // After
   var value: Int = 0  // Automatically observable!
   ```

3. **Non-Observable Properties**
   ```swift
   // Before
   var cached: Int = 0  // Not published

   // After
   @ObservationIgnored var cached: Int = 0  // Explicitly ignored
   ```

4. **View Integration**
   ```swift
   // Before
   @StateObject private var model = MyModel()
   @ObservedObject var sharedModel: SharedModel
   @EnvironmentObject var appModel: AppModel

   // After
   @State private var model = MyModel()
   @Environment(SharedModel.self) var sharedModel
   @Environment(AppModel.self) var appModel
   ```

5. **Enum State with Persistence (RepeatMode Pattern)**
   ```swift
   // File: MacAmpApp/Models/AppSettings.swift:232-266
   enum RepeatMode: String, Codable, CaseIterable {
       case off = "off"
       case all = "all"
       case one = "one"

       func next() -> RepeatMode {
           let cases = Self.allCases
           guard let index = cases.firstIndex(of: self) else { return self }
           let nextIndex = (index + 1) % cases.count
           return cases[nextIndex]
       }

       var label: String {
           switch self {
           case .off: return "Repeat: Off"
           case .all: return "Repeat: All"
           case .one: return "Repeat: One"
           }
       }

       var isActive: Bool { self != .off }
   }

   // In AppSettings class
   var repeatMode: RepeatMode = .off {
       didSet {
           UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
       }
   }
   ```

### Thread Safety with @MainActor

```swift
// Thread-safe state management
@MainActor
@Observable
final class PlaylistManager {
    private(set) var tracks: [Track] = []
    private(set) var currentIndex: Int = 0

    // All methods automatically run on main thread
    func addTrack(_ track: Track) {
        tracks.append(track)
    }

    // Async operations maintain main actor context
    func loadPlaylist(from url: URL) async {
        let loadedTracks = await loadTracksFromDisk(url)
        tracks = loadedTracks  // Safe: runs on main thread
    }

    // Background work with explicit context switch
    func processHeavyTask() async {
        // Switch to background
        let result = await Task.detached {
            // Heavy computation here
            return computeResult()
        }.value

        // Automatically back on main thread
        self.processedResult = result
    }
}
```

### Environment Injection Pattern

```swift
// MacAmpApp.swift (Root injection)
@main
struct MacAmpApp: App {
    // Create shared instances
    @State private var audioPlayer = AudioPlayer()
    @State private var streamPlayer = StreamPlayer()
    @State private var playbackCoordinator: PlaybackCoordinator
    @State private var skinManager = SkinManager()
    @State private var dockingController = DockingController()
    @State private var appSettings = AppSettings.shared

    init() {
        let audio = AudioPlayer()
        let stream = StreamPlayer()
        let coordinator = PlaybackCoordinator(
            audioPlayer: audio,
            streamPlayer: stream
        )

        _audioPlayer = State(initialValue: audio)
        _streamPlayer = State(initialValue: stream)
        _playbackCoordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioPlayer)
                .environment(streamPlayer)
                .environment(playbackCoordinator)
                .environment(skinManager)
                .environment(dockingController)
                .environment(appSettings)
        }
    }
}

// Child view usage
struct WinampMainWindow: View {
    // Automatic injection from environment
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(SkinManager.self) var skinManager
    @Environment(AppSettings.self) var settings

    var body: some View {
        // Direct usage, no property wrappers needed
        Text(playbackCoordinator.displayTitle)
    }
}
```

---

## Window Focus State Management

The WindowFocusState system provides centralized tracking of which MacAmp window is currently focused, enabling proper active/inactive titlebar rendering.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  Views read focus state for titlebar sprite selection       │
├─────────────────────────────────────────────────────────────┤
│                      BRIDGE LAYER                            │
│  WindowFocusState (@Observable state container)             │
│  WindowFocusDelegate (NSWindowDelegate adapter)             │
├─────────────────────────────────────────────────────────────┤
│                     MECHANISM LAYER                          │
│  NSWindow focus notifications via multiplexer               │
└─────────────────────────────────────────────────────────────┘
```

### WindowFocusState Model

```swift
// File: MacAmpApp/Models/WindowFocusState.swift
// Purpose: Track which window is currently key (focused)
// Pattern: @Observable @MainActor singleton

@Observable
@MainActor
final class WindowFocusState {
    var isMainKey: Bool = true       // Main window starts focused
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false

    // Computed for any-window-focused check
    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey ||
        isVideoKey || isMilkdropKey
    }
}
```

### Focus Delegate Integration

```swift
// File: MacAmpApp/Utilities/WindowFocusDelegate.swift
// Purpose: Bridge AppKit focus events to Observable state
// Pattern: NSWindowDelegate adapter

@MainActor
final class WindowFocusDelegate: NSObject, NSWindowDelegate {
    private let kind: WindowKind
    private let focusState: WindowFocusState

    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure mutual exclusivity - only one window is key
        focusState.isMainKey = (kind == .main)
        focusState.isEqualizerKey = (kind == .equalizer)
        focusState.isPlaylistKey = (kind == .playlist)
        focusState.isVideoKey = (kind == .video)
        focusState.isMilkdropKey = (kind == .milkdrop)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clear focus for this specific window
        switch kind {
        case .main: focusState.isMainKey = false
        case .equalizer: focusState.isEqualizerKey = false
        case .playlist: focusState.isPlaylistKey = false
        case .video: focusState.isVideoKey = false
        case .milkdrop: focusState.isMilkdropKey = false
        }
    }
}
```

### View Layer Usage

```swift
// File: MacAmpApp/Views/Windows/VideoWindowChromeView.swift
// Example: Using focus state for active/inactive titlebar

struct VideoWindowChromeView: View {
    @Environment(WindowFocusState.self) private var windowFocusState
    @Environment(SkinManager.self) private var skinManager

    private var isWindowActive: Bool {
        windowFocusState.isVideoKey
    }

    var body: some View {
        SimpleSpriteImage(
            sprite: skinManager.sprite(
                for: .videoTitleBar,
                state: isWindowActive ? .active : .inactive
            )
        )
    }
}
```

### Wiring Through WindowCoordinator

```swift
// File: MacAmpApp/ViewModels/WindowCoordinator.swift:68,284-286
// Integration: Create delegates and add to multiplexers

private let windowFocusState: WindowFocusState
private var videoFocusDelegate: WindowFocusDelegate?

// In setupDelegates()
videoFocusDelegate = WindowFocusDelegate(
    kind: .video,
    focusState: windowFocusState
)
videoDelegateMultiplexer?.add(delegate: videoFocusDelegate!)
```

### Key Design Decisions

1. **@Observable Pattern**: Provides fine-grained SwiftUI updates when focus changes
2. **Mutual Exclusivity**: Only one window can be key at a time (macOS convention)
3. **Bridge Layer Position**: Follows three-layer architecture principles
4. **Delegate Multiplexer**: Coexists with persistence and snapping delegates

For complete documentation, see: `docs/WINDOW_FOCUS_ARCHITECTURE.md`

---

## Five-Window NSWindowController Stack

MacAmp's window management evolved from a 3-window system (Main, Equalizer, Playlist) to a complete 5-window multimedia stack during TASK 2 implementation.

### Window Controller Architecture (Post-Refactoring, Feb 2026)

**Note:** As of February 2026, WindowCoordinator was refactored from a 1,357-line god object into an 11-file Facade + Composition architecture. See MULTI_WINDOW_ARCHITECTURE.md §10 for complete details.

```
┌─────────────────────────────────────────────────────────────┐
│              WindowCoordinator (Facade, 223 lines)           │
│                  "Composition root + API forwarding"          │
│                                                              │
│ Composed Controllers:                                       │
│  • registry: WindowRegistry (owns 5 NSWindowControllers)   │
│  • framePersistence: WindowFramePersistence                │
│  • visibility: WindowVisibilityController (@Observable)    │
│  • resizeController: WindowResizeController                │
│  • settingsObserver: WindowSettingsObserver (lifecycle)    │
│  • delegateWiring: WindowDelegateWiring (static factory)   │
├──────────────────────────────────────────────────────────────┤
│                      WindowRegistry (83 lines)               │
│                   "Window ownership layer"                   │
│                                                              │
│ NSWindowController instances (strong references):           │
│  • mainController:     WinampMainWindowController           │
│  • eqController:       WinampEqualizerWindowController      │
│  • playlistController: WinampPlaylistWindowController       │
│  • videoController:    WinampVideoWindowController          │
│  • milkdropController: WinampMilkdropWindowController       │
│                                                              │
│ Provides:                                                    │
│  • window(for: WindowKind) -> NSWindow?                     │
│  • windowKind(for: NSWindow) -> WindowKind?                 │
│  • forEachWindow(_ body: (NSWindow, WindowKind) -> Void)    │
├──────────────────────────────────────────────────────────────┤
│              WindowDelegateWiring (54 lines)                 │
│              "Static factory for delegate setup"             │
│                                                              │
│ Manages (via WindowDelegateMultiplexer):                    │
│  • focusDelegates: [WindowFocusDelegate] (5 instances)      │
│  • multiplexers: [WindowDelegateMultiplexer] (5 instances)  │
│                                                              │
│ Static Factory Pattern:                                      │
│  wire(registry:persistenceDelegate:windowFocusState:)        │
│    → Iterates all 5 windows                                 │
│    → Registers with WindowSnapManager                       │
│    → Creates multiplexer combining:                         │
│        • WindowSnapManager.shared (magnetic snapping)       │
│        • WindowPersistenceDelegate (frame saving)           │
│        • WindowFocusDelegate (focus tracking)               │
│    → Returns struct with strong references                  │
└─────────────────────────────────────────────────────────────┘
```

**Dependency Graph:**
```
WindowCoordinator
    ├── WindowRegistry (no deps)
    ├── WindowFramePersistence (depends on: WindowRegistry, WindowFrameStore)
    ├── WindowVisibilityController (depends on: WindowRegistry, AppSettings)
    ├── WindowResizeController (depends on: WindowRegistry, WindowFramePersistence)
    ├── WindowSettingsObserver (depends on: AppSettings only)
    └── WindowDelegateWiring (depends on: WindowRegistry, persistence, focus state)

All acyclic - no controller-to-controller dependencies.
```

### Window Lifecycle Management (Post-Refactoring)

**Refactored Feb 2026:** Window ownership moved to WindowRegistry, visibility to WindowVisibilityController, delegate wiring to WindowDelegateWiring.

```swift
// WindowCoordinator.swift (223 lines) - Facade pattern
@MainActor
@Observable
final class WindowCoordinator {
    // Composed controllers
    let registry: WindowRegistry  // Owns 5 NSWindowController instances
    let visibility: WindowVisibilityController  // Show/hide logic (@Observable)
    private let settingsObserver: WindowSettingsObserver  // Observes 4 settings
    private var delegateWiring: WindowDelegateWiring?  // Holds multiplexers + focus delegates

    // Forwarding methods (facade API)
    func showVideo() { visibility.showVideo() }
    func showMilkdrop() { visibility.showMilkdrop() }
    func minimizeKeyWindow() { visibility.minimizeKeyWindow() }

    // Forwarding properties (@Observable chaining)
    var isEQWindowVisible: Bool {
        get { visibility.isEQWindowVisible }
        set { visibility.isEQWindowVisible = newValue }
    }

    var mainWindow: NSWindow? { registry.mainWindow }
    var videoWindow: NSWindow? { registry.videoWindow }
}
```

**WindowRegistry.swift (83 lines) - Window ownership:**
```swift
@MainActor
final class WindowRegistry {
    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController
    private let videoController: NSWindowController
    private let milkdropController: NSWindowController

    var mainWindow: NSWindow? { mainController.window }
    func window(for kind: WindowKind) -> NSWindow?
    func windowKind(for window: NSWindow) -> WindowKind?
}
```

**WindowDelegateWiring.swift (54 lines) - Static factory:**
```swift
@MainActor
struct WindowDelegateWiring {
    let focusDelegates: [WindowFocusDelegate]  // 5 instances
    let multiplexers: [WindowDelegateMultiplexer]  // 5 instances

    static func wire(
        registry: WindowRegistry,
        persistenceDelegate: WindowPersistenceDelegate?,
        windowFocusState: WindowFocusState
    ) -> WindowDelegateWiring {
        // Iterates all 5 windows, sets up snap + persistence + focus delegates
        // Returns struct with strong references (NSWindow.delegate is weak)
    }
}
```

### Window Kind Enumeration

```swift
enum WindowKind: String, CaseIterable {
    case main = "main"
    case equalizer = "equalizer"
    case playlist = "playlist"
    case video = "video"         // Added in TASK 2
    case milkdrop = "milkdrop"   // Added in TASK 2

    var defaultFrame: NSRect {
        switch self {
        case .main: return NSRect(x: 100, y: 500, width: 275, height: 116)
        case .equalizer: return NSRect(x: 100, y: 384, width: 275, height: 116)
        case .playlist: return NSRect(x: 100, y: 268, width: 275, height: 116)
        case .video: return NSRect(x: 385, y: 500, width: 275, height: 232)
        case .milkdrop: return NSRect(x: 385, y: 268, width: 275, height: 232)
        }
    }
}
```

### Cluster Detection for 5 Windows

The WindowSnapManager now detects clusters across all 5 windows:

```swift
// WindowSnapManager discovers connected window groups
func discoverCluster(containing window: NSWindow) -> Set<WindowKind> {
    var cluster = Set<WindowKind>()
    var toCheck = [window]
    var checked = Set<ObjectIdentifier>()

    while !toCheck.isEmpty {
        let current = toCheck.removeFirst()
        let currentId = ObjectIdentifier(current)

        guard !checked.contains(currentId),
              let currentKind = windowKind(for: current) else { continue }

        checked.insert(currentId)
        cluster.insert(currentKind)

        // Find all connected windows (including video/milkdrop)
        for (otherWindow, _) in registeredWindows {
            guard otherWindow !== current,
                  !checked.contains(ObjectIdentifier(otherWindow)),
                  areWindowsConnected(current, otherWindow) else { continue }
            toCheck.append(otherWindow)
        }
    }

    return cluster
}
```

### Focus State Integration

Each window participates in the unified focus state system:

```swift
// WindowFocusState tracks all 5 windows
@Observable
final class WindowFocusState {
    var focusedWindow: WindowKind? = nil

    func updateFocus(to window: WindowKind?) {
        if focusedWindow != window {
            focusedWindow = window
        }
    }
}

// Each controller gets a focus delegate
let videoFocusDelegate = WindowFocusDelegate(
    windowKind: .video,
    focusState: windowFocusState
)
```

### Key Implementation Points

1. **Controller Lifecycle**: All 5 controllers created at app launch, windows shown/hidden as needed
2. **Delegate Multiplexing**: Each window combines focus, persistence, and snap delegates
3. **Memory Management**: Controllers and multiplexers stored as properties (prevent deallocation)
4. **UserDefaults Keys**: Each window has visibility and frame persistence keys
5. **Keyboard Shortcuts**: Ctrl+V (video), Ctrl+K (milkdrop) for window toggling

---

## SwiftUI Rendering Techniques

Achieving pixel-perfect Winamp rendering in SwiftUI requires specific techniques that override SwiftUI's automatic layout system.

### Absolute Positioning

SwiftUI wants to use flexible layouts. Winamp needs exact pixel positions.

```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift:85-89
// Purpose: Extension for absolute positioning of sprites
// Context: Provides Winamp-style top-left origin positioning

extension View {
    /// Position view at exact coordinates (top-left origin like Winamp)
    func at(x: CGFloat, y: CGFloat) -> some View {
        self.offset(x: x, y: y)
    }
}

// Usage: Place play button at exact Winamp coordinates
SimpleSpriteImage(sprite: playButton)
    .at(x: 39, y: 88)  // Exact pixels from top-left
```

### Pixel-Perfect Image Rendering

```swift
// Disable image interpolation for crisp pixels
struct SimpleSpriteImage: View {
    let sprite: ResolvedSprite

    var body: some View {
        Image(nsImage: sprite.image)
            .interpolation(.none)  // CRITICAL: No smoothing!
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: sprite.rect.width, height: sprite.rect.height)
            .clipped()
    }
}
```

### Z-Layer Background Masking

Prevent unnecessary redraws of static backgrounds:

```swift
struct WinampMainWindow: View {
    var body: some View {
        ZStack {
            // Layer 0: Static background (never changes)
            SimpleSpriteImage(sprite: mainBackground)
                .allowsHitTesting(false)  // Pass through clicks
                .zIndex(0)

            // Layer 1: Dynamic elements (can change)
            Group {
                TimeDisplay()
                    .at(x: 39, y: 26)
                    .zIndex(1)

                SpectrumAnalyzer()
                    .at(x: 24, y: 43)
                    .zIndex(1)
            }

            // Layer 2: Interactive controls (top layer)
            Group {
                PlayButton()
                    .at(x: 39, y: 88)
                    .zIndex(2)

                VolumeSlider()
                    .at(x: 107, y: 57)
                    .zIndex(2)
            }
        }
        .frame(width: 275, height: 116)  // Exact Winamp size
        .fixedSize()  // Prevent any resizing
    }
}
```

### Sprite Sheet Slicing

```swift
// File: MacAmpApp/Extensions/NSImage+Extensions.swift (pattern used throughout)
// Purpose: Extract sprites from composite bitmap images
// Context: Core technique for slicing Winamp skin bitmaps

extension NSImage {
    func cropped(to rect: NSRect) -> NSImage? {
        guard let cgImage = self.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return nil }

        // Convert NSRect to CGRect for cropping
        let cgRect = CGRect(
            x: rect.origin.x,
            y: CGFloat(cgImage.height) - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        guard let croppedCGImage = cgImage.cropping(to: cgRect) else {
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: rect.size)
        croppedImage.isTemplate = false  // Prevent system tinting
        return croppedImage
    }
}

// Real usage from skin loading:
// File: MacAmpApp/ViewModels/SkinManager.swift (sprite extraction pattern)
private func extractSprites(from sheet: NSImage, sprites: [Sprite]) -> [String: NSImage] {
    var extracted: [String: NSImage] = [:]

    for sprite in sprites {
        if let croppedImage = sheet.cropped(to: sprite.rect) {
            extracted[sprite.name] = croppedImage
        }
    }

    return extracted
}
```

### Custom Hit Testing

```swift
// Transparent areas shouldn't be clickable
struct TransparentHitTestView: View {
    let sprite: ResolvedSprite
    let action: () -> Void

    var body: some View {
        SimpleSpriteImage(sprite: sprite)
            .onTapGesture { action() }
            .allowsHitTesting(true)
            .contentShape(Rectangle())  // Define clickable area
    }
}
```

### Multi-State Components

```swift
// File: MacAmpApp/Views/Components/SimpleSpriteImage.swift (button action pattern)
// Purpose: Components with normal/hover/pressed states
// Context: Actual implementation used throughout the UI

struct SimpleSpriteImage: View {
    let source: SpriteSource
    let action: SpriteAction?
    @Environment(SkinManager.self) var skinManager

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        if let imageName = resolveSpriteName(),
           let image = skinManager.currentSkin?.images[imageName] {

            // Apply interaction based on action type
            switch action {
            case .button(let onClick, let whilePressed, let onRelease):
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressed {
                                    isPressed = true
                                    whilePressed?()
                                }
                            }
                            .onEnded { _ in
                                if isPressed {
                                    isPressed = false
                                    onRelease?()
                                    onClick?()
                                }
                            }
                    )

            case .toggle(let isOn, let onChange):
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
                    .onTapGesture {
                        onChange(!isOn)
                    }

            default:
                Image(nsImage: image)
                    .interpolation(.none)
                    .antialiased(false)
            }
        }
    }
}
```

---

## Audio Processing Pipeline

MacAmp's audio processing uses AVAudioEngine for sophisticated real-time audio manipulation, with visualization processing extracted to the VisualizerPipeline component.

### AVAudioEngine Graph

```
┌────────────────────────────────────────────────────────────┐
│                   AVAudioEngine Graph                       │
│              (AudioPlayer.swift: lines 29-31)               │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  AVAudioFile ──┐                                            │
│                ▼                                            │
│        AVAudioPlayerNode                                    │
│                │                                            │
│                ▼                                            │
│        AVAudioUnitEQ (10-band)                             │
│                │                                            │
│                ▼                                            │
│        AVAudioMixerNode (main)                             │
│                │                                            │
│          ┌─────┴─────┐                                     │
│          ▼           ▼                                     │
│    [Audio Tap]  OutputNode                                 │
│          │                                                 │
│          ▼                                                 │
│    VisualizerPipeline                                      │
│    • 2048-sample buffer (Butterchurn FFT)                  │
│    • Goertzel-like DFT (20 frequency bars)                 │
│    • RMS calculation per time bucket (20 bars)             │
│    • Waveform downsampling (76 samples)                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Visualizer Pipeline Architecture

The visualizer tap processing was extracted to `VisualizerPipeline.swift` for single responsibility and testability:

```
┌───────────────────────────────────────────────────────────────────────────┐
│                        VisualizerPipeline                                  │
│                    (MacAmpApp/Audio/VisualizerPipeline.swift)              │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  installTap(on: AVAudioMixerNode)                                          │
│       │                                                                    │
│       ▼                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    Audio Tap Handler                                 │  │
│  │                (realtime audio thread)                               │  │
│  ├─────────────────────────────────────────────────────────────────────┤  │
│  │                                                                      │  │
│  │  1. Mix channels to mono                                             │  │
│  │     └─ Average all channels into scratch.mono[]                      │  │
│  │                                                                      │  │
│  │  2. Compute RMS per time bucket (20 bars)                            │  │
│  │     └─ sqrt(sum(x²) / n) * 4.0, clamped to 0-1                       │  │
│  │                                                                      │  │
│  │  3. Compute spectrum via Goertzel algorithm (20 bars)                │  │
│  │     └─ 20 frequency bands, 50-16000 Hz                               │  │
│  │     └─ Hybrid log/linear scale (0.91*log + 0.09*linear)              │  │
│  │     └─ Frequency-dependent gain equalization                         │  │
│  │                                                                      │  │
│  │  4. Capture waveform samples (76 points for oscilloscope)            │  │
│  │                                                                      │  │
│  │  5. Process Butterchurn FFT (2048-point → 1024 bins)                 │  │
│  │     └─ Uses pre-allocated buffers (no audio-thread allocations)      │  │
│  │     └─ Pre-computed Hann window                                      │  │
│  │     └─ vDSP_DFT_Execute for FFT                                      │  │
│  │                                                                      │  │
│  │  6. Publish to SPSC shared buffer (non-blocking)                     │  │
│  │     └─ sharedBuffer.tryPublish() — drops frame on contention          │  │
│  │     └─ Zero allocations on audio thread                               │  │
│  │                                                                      │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │              30 Hz Poll Timer (Main Thread)                          │  │
│  ├─────────────────────────────────────────────────────────────────────┤  │
│  │  sharedBuffer.consume() → VisualizerData?                           │  │
│  │  └─ Returns nil if no new data (generation counter check)           │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│       │                                                                    │
│       ▼                                                                    │
│  updateLevels(with: VisualizerData, useSpectrum: Bool)                     │
│       │                                                                    │
│       ▼                                                                    │
│  • Store latestRMS, latestSpectrum, latestWaveform                         │
│  • Store butterchurnSpectrum, butterchurnWaveform                          │
│  • Apply smoothing (alpha-blend with previous levels)                      │
│  • Apply peak falloff (decay over time)                                    │
│  • Update observable `levels` array                                        │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
```

### Butterchurn Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     BUTTERCHURN AUDIO DATA FLOW                           │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   Audio File (.mp3/flac)                                                  │
│        │                                                                  │
│        ▼                                                                  │
│   AVAudioEngine (sample rate from file format)                            │
│        │                                                                  │
│        ▼                                                                  │
│   installTap(2048 samples) ─────▶ Mono downsample + vDSP FFT              │
│        │                                                                  │
│        ▼                                                                  │
│   VisualizerPipeline.swift                                                │
│   ├── @ObservationIgnored butterchurnSpectrum[1024]                       │
│   ├── @ObservationIgnored butterchurnWaveform[1024]                       │
│   └── snapshotButterchurnFrame() → ButterchurnFrame                       │
│        │                                                                  │
│        ▼ (called by AudioPlayer)                                          │
│   AudioPlayer.snapshotButterchurnFrame()                                  │
│   └── returns nil if video/stream playback (no PCM access)                │
│        │                                                                  │
│        ▼ (30 FPS Timer)                                                   │
│   ButterchurnBridge.swift                                                 │
│   └── callAsyncJavaScript("receiveAudioData([...])")                      │
│        │                                                                  │
│        ▼ (WKWebView)                                                      │
│   bridge.js                                                               │
│   └── ScriptProcessorNode → Butterchurn analyser                          │
│        │                                                                  │
│        ▼ (60 FPS requestAnimationFrame)                                   │
│   butterchurn.min.js                                                      │
│   └── visualizer.render() → WebGL Canvas                                  │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### VisualizerScratchBuffers - Pre-allocated FFT Buffers

To avoid allocations on the realtime audio thread, `VisualizerScratchBuffers` pre-allocates all FFT working buffers:

```swift
// VisualizerPipeline.swift (VisualizerScratchBuffers)
private final class VisualizerScratchBuffers: @unchecked Sendable {
    // Pre-allocated FFT working buffers
    private var hannWindow: [Float] = Array(repeating: 0, count: 2048)
    private var fftInputReal: [Float] = Array(repeating: 0, count: 1024)
    private var fftInputImag: [Float] = Array(repeating: 0, count: 1024)
    private var fftOutputReal: [Float] = Array(repeating: 0, count: 1024)
    private var fftOutputImag: [Float] = Array(repeating: 0, count: 1024)

    init() {
        // Pre-compute Hann window (never changes)
        vDSP_hann_window(&hannWindow, vDSP_Length(2048), Int32(vDSP_HANN_NORM))

        // Create FFT setup (log2(2048) = 11)
        fftSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(2048), .FORWARD)
    }
}
```

### EQ Implementation

The 10-band parametric EQ has been extracted from AudioPlayer into `EqualizerController.swift` (facade pattern). AudioPlayer now forwards EQ operations to `equalizer.eqNode`:

```swift
// EqualizerController.swift - EQ facade (extracted from AudioPlayer)
// AudioPlayer holds: let equalizer = EqualizerController()
// AudioPlayer forwards: var isEqOn { equalizer.isEqOn }

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
        band.bandwidth = 1.0
        band.gain = eqBands[i]
        band.bypass = false
    }
    eqNode.globalGain = preamp
    eqNode.bypass = !isEqOn
}
```

### EQ Preset Persistence (Extracted to EQPresetStore)

EQ preset persistence is now managed by `EQPresetStore`:

```swift
// EQPresetStore.swift:130-146 - Background I/O pattern
func savePerTrackPresets() {
    guard let url = presetsFileURL() else { return }

    // Capture current state for background write
    let presetsToSave = perTrackPresets

    // Perform file I/O off main thread (fire-and-forget with error logging)
    Task.detached(priority: .utility) {
        do {
            let data = try JSONEncoder().encode(presetsToSave)
            try data.write(to: url, options: .atomic)
            AppLog.debug(.audio, "Saved \(presetsToSave.count) per-track presets")
        } catch {
            AppLog.warn(.audio, "Failed to save per-track presets: \(error)")
        }
    }
}
```

### Repeat Mode Implementation (PlaylistController)

Repeat mode logic is now in PlaylistController with navigation actions:

```swift
// PlaylistController.swift:171-213
func nextTrack(isManualSkip: Bool = false) -> AdvanceAction {
    guard !playlist.isEmpty else { return .none }

    // Repeat-one: Only auto-restart on track end, allow manual skips
    if repeatMode == .one && !isManualSkip {
        guard let track = currentTrack else { return .none }
        return track.isStream ? .requestCoordinatorPlayback(track) : .restartCurrent
    }

    // Shuffle mode: pick random track
    if shuffleEnabled {
        guard let randomTrack = playlist.randomElement() else { return .none }
        // ... update currentIndex
        return randomTrack.isStream ? .requestCoordinatorPlayback(randomTrack) : .playTrack(randomTrack)
    }

    // Sequential navigation
    let nextIndex = resolveActiveIndex() + 1
    if nextIndex < playlist.count {
        let track = playlist[nextIndex]
        currentIndex = nextIndex
        return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
    }

    // End of playlist
    if repeatMode == .all {
        let track = playlist[0]
        currentIndex = 0
        return track.isStream ? .requestCoordinatorPlayback(track) : .playTrack(track)
    }

    hasEnded = true
    currentIndex = nil
    return .endOfPlaylist
}
```

AudioPlayer bridges this to actual playback:

```swift
// AudioPlayer.swift:1021-1042
private func handlePlaylistAction(_ action: PlaylistController.AdvanceAction) -> PlaylistAdvanceAction {
    switch action {
    case .none: return .none
    case .restartCurrent:
        // Always resume: repeat-one at end-of-track means "restart and play"
        seek(to: 0, resume: true)
        return .restartCurrent
    case .playTrack(let track):
        playTrack(track: track)
        return .playLocally(track)
    case .requestCoordinatorPlayback(let track):
        return .requestCoordinatorPlayback(track)
    case .endOfPlaylist:
        return .none
    }
}
```

### Spectrum Analyzer (20-bar Goertzel Implementation)

```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift
// Purpose: Real-time spectrum analysis using Goertzel-like single-bin DFT
// Context: More efficient than FFT for specific frequency detection
// Data transfer: SPSC shared buffer (replaces Task { @MainActor })

private nonisolated static func makeTapHandler(
    sharedBuffer: VisualizerSharedBuffer,
    scratch: VisualizerScratchBuffers
) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
    { buffer, _ in
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return }

        let bars = 20
        // prepare() clamps to pre-allocated capacity (no allocation on audio thread)
        let cappedFrameCount = scratch.prepare(
            frameCount: frameCount, bars: bars,
            sampleRate: Float(buffer.format.sampleRate)  // Triggers Goertzel recompute on rate change
        )

        // Convert to mono by averaging channels
        scratch.withMono { mono in
            let invCount = 1.0 / Float(channelCount)
            for frame in 0..<cappedFrameCount {
                var sum: Float = 0
                for channel in 0..<channelCount { sum += ptr[channel][frame] }
                mono[frame] = sum * invCount
            }
        }

        // RMS + Spectrum (using pre-computed Goertzel coefficients)
        scratch.withMonoReadOnly { mono in
            scratch.withRms { rms in /* ... RMS per time bucket ... */ }
            scratch.withSpectrum { spectrum in
                let coefficients = scratch.goertzel.coefficients  // Pre-computed
                let gains = scratch.goertzel.equalizationGains    // Pre-computed
                // Goertzel single-bin DFT using cached coefficients
                // (eliminates 20x pow() + 20x cos() per callback)
            }
        }

        // Process Butterchurn FFT (2048-point → 1024 bins)
        scratch.withMonoReadOnly { mono in
            scratch.processButterchurnFFT(samples: mono, validCount: cappedFrameCount)
        }

        // Publish to SPSC shared buffer (non-blocking: drops frame on contention)
        _ = sharedBuffer.tryPublish(from: scratch, oscilloscopeSamples: 76,
                                     validFrameCount: cappedFrameCount)
    }
}
```

---

## Internet Radio Streaming

Internet radio support was added in October 2025, requiring significant architectural changes.

### Stream Types Supported

```
1. HTTP/HTTPS Audio Streams
   - MP3 streams (audio/mpeg)
   - AAC streams (audio/aac)
   - OGG Vorbis (audio/ogg)

2. HLS Adaptive Streaming
   - .m3u8 playlists
   - Multi-bitrate support
   - Automatic quality switching

3. Metadata Protocols
   - ICY (SHOUTcast/Icecast)
   - ID3v2 in-stream tags
   - HLS timed metadata
```

### StreamPlayer Architecture

```swift
// StreamPlayer.swift (Complete implementation)
@MainActor
@Observable
final class StreamPlayer: NSObject {
    // Observable state
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var bitrate: Int?
    private(set) var error: String?

    // Volume & Balance (T5 Phase 1)
    // Volume is applied directly to AVPlayer.volume.
    // Balance is stored but NOT applied — AVPlayer has no .pan property.
    // Phase 2 Loopback Bridge will route streams through AVAudioEngine
    // where playerNode.pan can apply balance.
    var volume: Float = 0.75 {
        didSet { player.volume = volume }
    }
    var balance: Float = 0.0  // Stored for Phase 2

    // AVPlayer setup
    private let player = AVPlayer()
    private var metadataOutput: AVPlayerItemMetadataOutput?

    // Play a station
    func play(station: RadioStation) async {
        // Apply current volume before playback starts
        player.volume = volume
        reset()

        // Configure for streaming
        let asset = AVURLAsset(url: station.streamURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Icy-MetaData": "1",  // Request ICY metadata
                "User-Agent": "MacAmp/2.0"
            ]
        ])

        let playerItem = AVPlayerItem(asset: asset)

        // Setup metadata extraction
        setupMetadataOutput(for: playerItem)

        // Configure buffering
        playerItem.preferredForwardBufferDuration = 5.0  // 5 second buffer

        // Start playback
        player.replaceCurrentItem(with: playerItem)
        player.play()

        isPlaying = true

        // Monitor buffering
        observeBuffering(for: playerItem)
    }

    private func setupMetadataOutput(for item: AVPlayerItem) {
        let metadataOutput = AVPlayerItemMetadataOutput()
        metadataOutput.setDelegate(self, queue: .main)

        // Configure for ICY metadata
        metadataOutput.advanceIntervalForDelegateInvocation = 1.0

        item.add(metadataOutput)
        self.metadataOutput = metadataOutput
    }

    private func observeBuffering(for item: AVPlayerItem) {
        Task {
            for await status in item.publisher(for: \.status).values {
                switch status {
                case .readyToPlay:
                    isBuffering = false
                case .failed:
                    error = item.error?.localizedDescription
                    isBuffering = false
                    isPlaying = false
                case .unknown:
                    isBuffering = true
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Metadata Extraction
// Note: ICY metadata extraction through AVPlayerItemMetadataOutput
// The actual implementation monitors player item metadata changes
extension StreamPlayer: AVPlayerItemMetadataOutputPushDelegate {
    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        for group in groups {
            processMetadataGroup(group)
        }
    }

    private func processMetadataGroup(_ group: AVTimedMetadataGroup) {
        for item in group.items {
            // Process common metadata keys
            if let commonKey = item.commonKey {
                switch commonKey {
                case .commonKeyTitle:
                    streamTitle = item.stringValue
                case .commonKeyArtist:
                    streamArtist = item.stringValue
                default:
                    break
                }
            }

            // Process ICY metadata if present
            // Note: ICY metadata comes through timed metadata groups
            if let key = item.key as? String {
                if key.contains("StreamTitle") {
                    parseICYStreamTitle(item.stringValue)
                }
            }
        }
    }

    private func parseICYStreamTitle(_ title: String?) {
        guard let title = title else { return }

        // ICY format: "Artist - Title"
        let parts = title.split(separator: " - ", maxSplits: 1)
        if parts.count == 2 {
            streamArtist = String(parts[0])
            streamTitle = String(parts[1])
        } else {
            streamTitle = title
            streamArtist = nil
        }
    }
}
```

### Radio Station Management

```swift
// RadioStationLibrary.swift
@MainActor
@Observable
final class RadioStationLibrary {
    private(set) var stations: [RadioStation] = []
    private(set) var categories: [String: [RadioStation]] = [:]

    init() {
        loadBuiltInStations()
    }

    private func loadBuiltInStations() {
        stations = [
            // SomaFM Stations
            RadioStation(
                name: "SomaFM - Groove Salad",
                streamURL: URL(string: "https://somafm.com/groovesalad130.pls")!,
                genre: "Ambient/Downtempo",
                bitrate: 128
            ),
            RadioStation(
                name: "SomaFM - Drone Zone",
                streamURL: URL(string: "https://somafm.com/dronezone130.pls")!,
                genre: "Ambient",
                bitrate: 128
            ),

            // Classic stations
            RadioStation(
                name: "Digitally Imported - Trance",
                streamURL: URL(string: "https://www.di.fm/trance.pls")!,
                genre: "Trance",
                bitrate: 128
            ),

            // ... more stations
        ]

        // Organize by genre
        for station in stations {
            if categories[station.genre] == nil {
                categories[station.genre] = []
            }
            categories[station.genre]?.append(station)
        }
    }

    func addCustomStation(_ station: RadioStation) {
        stations.append(station)
        save()
    }

    private func save() {
        // Persist to UserDefaults
        if let encoded = try? JSONEncoder().encode(stations) {
            UserDefaults.standard.set(encoded, forKey: "CustomStations")
        }
    }
}
```

### Internet Radio Integration Fixes (PR #49, February 2026)

PR #49 addressed six systematic bugs (N1-N6) in the internet radio integration layer. These bugs surfaced during real-world testing of stream playback with playlist navigation and UI state display.

**N1/N2 - Computed Play State**: PlaybackCoordinator's `isPlaying` and `isPaused` were stored booleans that drifted out of sync with actual backend state during buffering stalls, error recovery, and rapid toggling. Replaced with computed properties that derive from the active audio source (see updated PlaybackCoordinator in section 4.3 above).

**N3 - Split Callbacks**: AudioPlayer's single `externalPlaybackHandler` closure conflated two distinct events: metadata arrival and end-of-track auto-advance. Split into `onTrackMetadataUpdate` and `onPlaylistAdvanceRequest` callbacks, eliminating ambiguous dispatch in PlaybackCoordinator's init.

**N4 - Context-Aware Playlist Navigation**: During stream playback, `audioPlayer.currentTrack` is nil because AudioPlayer is not the active backend. PlaylistController's `nextTrack(from:)` and `previousTrack(from:)` overloads accept an external track reference so the coordinator can pass its own `currentTrack` for position resolution.

**N5 - TrackInfoView Stream Gating**: TrackInfoView's stream info section now gates on `case .radioStation = playbackCoordinator.currentSource` and uses `playbackCoordinator.displayTitle` for live ICY metadata display, rather than relying on AudioPlayer state which is empty during stream playback.

**N6 - File Structure**: WinampMainWindow and WinampPlaylistWindow were initially split into main file + extension files to reduce per-file complexity. The WinampPlaylistWindow extension pattern (`WinampPlaylistWindow+Menus.swift`) was subsequently identified as an anti-pattern (access widening via `internal` properties, no SwiftUI recomposition boundaries) and replaced with proper child-view decomposition:
- `WinampPlaylistWindow+Menus.swift` was DELETED and replaced by child view structs in `PlaylistWindow/` subdirectory (PR merged, decomposition COMPLETE)
- `WinampMainWindow.swift` + `WinampMainWindow+Helpers.swift` remain as-is; proper decomposition is PLANNED for Wave 2
- `tasks/mainwindow-layer-decomposition/` — Extract WinampMainWindow into child view structs + @Observable interaction state (Wave 2)

### Stream Volume & Balance Control (T5 Phase 1, February 2026)

T5 Phase 1 addressed a fundamental gap: volume and balance changes from the UI only affected AudioPlayer, leaving StreamPlayer and VideoPlaybackController unsynchronized during internet radio playback.

**Problem:** Volume and balance sliders were bound directly to `$audioPlayer.volume` / `$audioPlayer.balance`. During stream playback, moving the volume slider had no effect on the audible stream because StreamPlayer (AVPlayer) was not receiving the change. VideoPlaybackController was receiving volume changes via AudioPlayer's `didSet`, coupling AudioPlayer to a sibling it should not know about.

**Solution:** PlaybackCoordinator gained two routing methods (`setVolume()`, `setBalance()`) that propagate to all backends unconditionally. UI sliders use asymmetric `Binding<Float>` that reads from AudioPlayer (source of truth for persistence) but writes through the coordinator.

**Capability Flags:** Three computed properties (`supportsEQ`, `supportsBalance`, `supportsVisualizer`) gate UI controls. They return `false` when the stream backend is active (and not in error state), causing:
- EQ sliders to dim (50% opacity, hit testing disabled) in WinampEqualizerWindow
- Balance slider to dim in WinampMainWindow+Helpers
- Controls to re-enable when stream enters error state (no stuck dimmed UI)

**Depreciated Patterns (see `tasks/internet-streaming-volume-control/depreciated.md`):**
- `AudioPlayer.volume.didSet` no longer propagates to `videoPlaybackController.volume` (coordinator handles it)
- Direct `$audioPlayer.volume` / `$audioPlayer.balance` UI bindings replaced with coordinator-routed asymmetric bindings
- Note: `AudioPlayer.init()` still sets `videoPlaybackController.volume = volume` during engine setup (before coordinator exists); this is correct for initialization

The PlaylistWindow decomposition follows the Gemini + Oracle converged architecture (Lesson #25 in BUILDING_RETRO_MACOS_APPS_SKILL.md).

---

## Modern Swift 6 Patterns

Swift 6 introduces strict concurrency checking and new patterns for thread safety.

### Strict Concurrency

```swift
// Enable strict concurrency in Package.swift
let package = Package(
    name: "MacAmp",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MacAmpApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
```

### Sendable Conformance

```swift
// Make types Sendable for cross-actor passing
struct Track: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    let duration: Double
}

// For classes with mutable state
final class AudioBuffer: @unchecked Sendable {
    // @unchecked because we manage thread safety manually
    private let lock = NSLock()
    private var buffer: [Float] = []

    func append(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(contentsOf: samples)
    }
}
```

### Actor Isolation

```swift
// Use actors for concurrent state management
actor PlaylistCache {
    private var cache: [URL: [Track]] = [:]

    func tracks(for playlist: URL) async -> [Track]? {
        if let cached = cache[playlist] {
            return cached
        }

        // Load from disk
        let tracks = await loadPlaylist(from: playlist)
        cache[playlist] = tracks
        return tracks
    }

    func invalidate() {
        cache.removeAll()
    }
}

// Usage from MainActor
@MainActor
class PlaylistManager {
    private let cache = PlaylistCache()

    func loadPlaylist(url: URL) async {
        let tracks = await cache.tracks(for: url)
        self.tracks = tracks ?? []
    }
}
```

### Task Groups

```swift
// Parallel processing with structured concurrency
func loadMultiplePlaylists(urls: [URL]) async -> [Track] {
    await withTaskGroup(of: [Track].self) { group in
        for url in urls {
            group.addTask {
                await self.loadPlaylist(from: url)
            }
        }

        var allTracks: [Track] = []
        for await tracks in group {
            allTracks.append(contentsOf: tracks)
        }
        return allTracks
    }
}
```

### AsyncStream for Events

```swift
// Replace Combine publishers with AsyncStream
@Observable
final class AudioPlayer {
    private(set) var events: AsyncStream<PlayerEvent>
    private var continuation: AsyncStream<PlayerEvent>.Continuation?

    init() {
        (events, continuation) = AsyncStream<PlayerEvent>.makeStream()
    }

    private func sendEvent(_ event: PlayerEvent) {
        continuation?.yield(event)
    }
}

// Consumer
Task {
    for await event in audioPlayer.events {
        switch event {
        case .trackChanged(let track):
            updateUI(for: track)
        case .playbackEnded:
            playNextTrack()
        }
    }
}
```

---

## Window Snap Manager

MacAmp implements Winamp's magnetic window docking with a sophisticated edge detection and cluster management system.

### Architecture Overview

```swift
// File: MacAmpApp/Utilities/WindowSnapManager.swift:1-172
// Purpose: Magnetic window snapping with 10px threshold
// Context: Critical for authentic Winamp multi-window experience

@MainActor
final class WindowSnapManager: NSObject, NSWindowDelegate {
    static let shared = WindowSnapManager()

    private struct TrackedWindow {
        weak var window: NSWindow?
        let kind: WindowKind
    }

    private var windows: [WindowKind: TrackedWindow] = [:]
    private var lastOrigins: [ObjectIdentifier: NSPoint] = [:]
    private var isAdjusting = false

    func register(window: NSWindow, kind: WindowKind) {
        // Configure for classic borderless look
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        windows[kind] = TrackedWindow(window: window, kind: kind)
        window.delegate = self
        lastOrigins[ObjectIdentifier(window)] = window.frame.origin
    }
}

> **2025-11 Update** – `WindowSnapManager` now exposes two additional helpers that the coordinator relies on during double-size toggles:
> - `beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` suspend magnetic snapping while we recompute frames.
> - `clusterKinds(containing:)` returns the set of `WindowKind` values currently touching the requested window. `resizeMainAndEQWindows` calls this with `.playlist` to determine whether the playlist is docked to the main window, the equalizer, or floating.
```

### Core Algorithm: Window Move Handler

```swift
// File: MacAmpApp/Utilities/WindowSnapManager.swift:33-136
// Purpose: Handles window movement with magnetic snapping
// Context: Uses connected cluster detection for group movement

func windowDidMove(_ notification: Notification) {
    guard !isAdjusting else { return }
    guard let movedWindow = notification.object as? NSWindow else { return }

    // Convert to top-left coordinate space for calculations
    let allScreens = NSScreen.screens
    let virtualTop: CGFloat = allScreens.map { $0.frame.maxY }.max() ?? 0
    let virtualLeft: CGFloat = allScreens.map { $0.frame.minX }.min() ?? 0

    func box(for window: NSWindow) -> Box {
        let f = window.frame
        let x = f.origin.x - virtualLeft
        let yTop = virtualTop - (f.origin.y + f.size.height)
        return Box(x: x, y: yTop, width: f.size.width, height: f.size.height)
    }

    // Find connected cluster (windows already docked together)
    let clusterIDs = connectedCluster(start: movedID, boxes: idToBox)

    // Move entire cluster as a unit
    isAdjusting = true
    for id in clusterIDs where id != movedID {
        if let w = idToWindow[id] {
            let origin = w.frame.origin
            w.setFrameOrigin(NSPoint(x: origin.x + userDelta.x, y: origin.y + userDelta.y))
        }
    }
    isAdjusting = false

    // Snap cluster to other windows and screen edges
    let otherBoxes = otherIDs.compactMap { idToBox[$0] }
    let diffToOthers = SnapUtils.snapToMany(groupBox, otherBoxes)
    let diffWithin = SnapUtils.snapWithin(groupBox, BoundingBox(width: virtualWidth, height: virtualHeight))
    let snappedGroupPoint = SnapUtils.applySnap(Point(x: groupBox.x, y: groupBox.y), diffToOthers, diffWithin)
}
```

### Connection Detection

```swift
// File: MacAmpApp/Utilities/WindowSnapManager.swift:139-155
// Purpose: Determines if two windows are magnetically connected
// Context: 10px threshold for edge proximity

private func boxesAreConnected(_ a: Box, _ b: Box) -> Bool {
    // Vertical stacking - check if x overlaps and edges are near
    if SnapUtils.overlapX(a, b) {
        if SnapUtils.near(SnapUtils.top(a), SnapUtils.bottom(b)) { return true }
        if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.top(b)) { return true }
        if SnapUtils.near(SnapUtils.top(a), SnapUtils.top(b)) { return true }
        if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.bottom(b)) { return true }
    }
    // Horizontal side-by-side - check if y overlaps and edges are near
    if SnapUtils.overlapY(a, b) {
        if SnapUtils.near(SnapUtils.left(a), SnapUtils.right(b)) { return true }
        if SnapUtils.near(SnapUtils.right(a), SnapUtils.left(b)) { return true }
        if SnapUtils.near(SnapUtils.left(a), SnapUtils.left(b)) { return true }
        if SnapUtils.near(SnapUtils.right(a), SnapUtils.right(b)) { return true }
    }
    return false
}
```

### Cluster Discovery

```swift
// File: MacAmpApp/Utilities/WindowSnapManager.swift:157-171
// Purpose: Find all windows connected as a group
// Context: Uses depth-first search to find connected components

private func connectedCluster(start: ObjectIdentifier, boxes: [ObjectIdentifier: Box]) -> Set<ObjectIdentifier> {
    var visited: Set<ObjectIdentifier> = []
    var stack: [ObjectIdentifier] = [start]
    while let id = stack.popLast() {
        if visited.contains(id) { continue }
        visited.insert(id)
        guard let box = boxes[id] else { continue }
        for (otherID, otherBox) in boxes where otherID != id {
            if !visited.contains(otherID) && boxesAreConnected(box, otherBox) {
                stack.append(otherID)
            }
        }
    }
    return visited
}
```

### Key Features

1. **10px Snap Threshold**: Windows snap when edges come within 10 pixels
2. **Cluster Movement**: Docked windows move together as a group
3. **Screen Edge Snapping**: Windows also snap to display boundaries
4. **Multi-Monitor Support**: Works across multiple displays
5. **Feedback Prevention**: `isAdjusting` flag prevents snap loops

---

## Sprite-Based Menu System

MacAmp implements custom NSMenuItem rendering using SwiftUI views for sprite-based menus with keyboard navigation support.

### SpriteMenuItem Architecture

```swift
// File: MacAmpApp/Views/Components/SpriteMenuItem.swift:31-96
// Purpose: Custom NSMenuItem that displays skin sprites
// Context: Bridges AppKit menus with SwiftUI sprite rendering

@MainActor
final class SpriteMenuItem: NSMenuItem {
    private let normalSpriteName: String
    private let selectedSpriteName: String
    private let skinManager: SkinManager
    private var hostingView: NSHostingView<SpriteMenuItemView>?

    /// Custom highlighted state managed by PlaylistMenuDelegate
    /// Note: Different from NSMenuItem's built-in isHighlighted
    var spriteHighlighted: Bool = false {
        didSet {
            updateView()
        }
    }

    init(normalSprite: String, selectedSprite: String, skinManager: SkinManager, action: Selector?, target: AnyObject?) {
        self.normalSpriteName = normalSprite
        self.selectedSpriteName = selectedSprite
        self.skinManager = skinManager

        super.init(title: "", action: action, keyEquivalent: "")
        self.target = target

        setupView()
    }

    private func setupView() {
        // Create click forwarding container (delegate handles highlighting)
        let container = ClickForwardingView(frame: NSRect(x: 0, y: 0, width: 22, height: 18))
        container.menuItem = self

        // Embed SwiftUI sprite view in NSMenuItem
        let spriteView = SpriteMenuItemView(
            normalSprite: normalSpriteName,
            selectedSprite: selectedSpriteName,
            isHighlighted: spriteHighlighted,
            skinManager: skinManager
        )

        let hosting = NSHostingView(rootView: spriteView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]

        container.addSubview(hosting)

        self.view = container  // Custom view for NSMenuItem
        self.hostingView = hosting
    }
}
```

### Click Forwarding Pattern

```swift
// File: MacAmpApp/Views/Components/SpriteMenuItem.swift:14-26
// Purpose: Forward clicks from custom view to menu item
// Context: NSMenuItem with custom views need explicit click handling

final class ClickForwardingView: NSView {
    weak var menuItem: NSMenuItem?

    override func mouseDown(with event: NSEvent) {
        // Forward click to menu item's action/target
        if let menuItem = menuItem,
           let action = menuItem.action,
           let target = menuItem.target {
            NSApp.sendAction(action, to: target, from: menuItem)
        }
        menuItem?.menu?.cancelTracking()
    }
}
```

### PlaylistMenuDelegate - Keyboard Navigation

```swift
// File: MacAmpApp/Views/Components/PlaylistMenuDelegate.swift:15-41
// Purpose: NSMenuDelegate enabling keyboard navigation for sprite menus
// Context: Critical for accessibility and keyboard control

@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    /// Called for both mouse hover AND keyboard navigation
    /// This is the key method that enables arrow key support
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update all sprite menu items in this menu
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                // Swap sprites based on highlight state
                sprite.spriteHighlighted = (menuItem === item)
            }
        }
    }

    /// Handle Enter key to activate highlighted item
    func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
        // Check for Enter or Return key
        if let key = event.charactersIgnoringModifiers,
           key == "\r" || key == "\n" {
            if let highlightedItem = menu.highlightedItem {
                // Trigger the highlighted item's action
                menu.performActionForItem(at: menu.index(of: highlightedItem))
                return true  // We handled the key event
            }
        }
        return false
    }
}
```

### SwiftUI Sprite Rendering in Menus

```swift
// File: MacAmpApp/Views/Components/SpriteMenuItem.swift:99-118
// Purpose: SwiftUI view rendered inside NSMenuItem
// Context: Allows pixel-perfect sprite rendering in native menus

struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHighlighted: Bool
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHighlighted ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .interpolation(.none)  // Pixel-perfect rendering
                .antialiased(false)
                .resizable()
                .frame(width: 22, height: 18)
        } else {
            // Fallback if sprite not found
            Color.gray
                .frame(width: 22, height: 18)
        }
    }
}
```

### Integration Example

```swift
// Usage in playlist window menu creation
let menu = NSMenu()
menu.delegate = PlaylistMenuDelegate()  // Enable keyboard navigation

// Add sprite-based menu items
let playItem = SpriteMenuItem(
    normalSprite: "PLEDIT_PLAY",
    selectedSprite: "PLEDIT_PLAY_SELECTED",
    skinManager: skinManager,
    action: #selector(playSelectedTrack),
    target: self
)
menu.addItem(playItem)

let removeItem = SpriteMenuItem(
    normalSprite: "PLEDIT_REMOVE",
    selectedSprite: "PLEDIT_REMOVE_SELECTED",
    skinManager: skinManager,
    action: #selector(removeSelectedTrack),
    target: self
)
menu.addItem(removeItem)
```

### Key Features

1. **NSHostingView Bridge**: Embeds SwiftUI views in NSMenuItem
2. **Sprite Swapping**: Normal → Selected sprite on highlight
3. **Keyboard Navigation**: Full arrow key and Enter support via delegate
4. **VoiceOver Compatible**: Accessibility through NSMenuDelegate
5. **Click Forwarding**: Custom views properly trigger menu actions

---

## Video Window Architecture

The Video Window provides native macOS video playback capability with authentic Winamp chrome, implemented during TASK 2 (Days 1-6).

### Window Controller Implementation

```swift
// File: MacAmpApp/Windows/WinampVideoWindowController.swift
@MainActor
final class WinampVideoWindowController: NSWindowController {

    init(skinManager: SkinManager, playbackCoordinator: PlaybackCoordinator,
         appSettings: AppSettings, windowFocusState: WindowFocusState) {

        // Create the video window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        window.isReleasedWhenClosed = false
        window.title = "Video"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.minSize = CGSize(width: 275, height: 232)

        super.init(window: window)

        // Set up the content view with chrome + video player
        let videoView = WinampVideoWindow(
            skinManager: skinManager,
            playbackCoordinator: playbackCoordinator,
            appSettings: appSettings
        )

        let hostingController = NSHostingController(rootView: videoView)
        window.contentViewController = hostingController
    }
}
```

### Chrome Structure (VIDEO.bmp)

The video window chrome uses VIDEO.bmp sprites, divided into 6 sections:

```swift
// VIDEO.bmp layout (275x116 total)
enum VideoSprite {
    case topLeft      // 0,0 25x20 - Rounded corner with gradient
    case topCenter    // 25,0 150x20 - Titlebar with "VIDEO" text
    case topRight     // 175,0 100x20 - Close/minimize buttons
    case bottomLeft   // 0,20 125x38 - Control buttons
    case bottomCenter // 125,20 25x38 - Slider/position
    case bottomRight  // 150,20 125x38 - Volume/options
}

// Chrome rendering structure
struct VideoWindowChromeView: View {
    var body: some View {
        ZStack {
            // Background chrome layer
            VStack(spacing: 0) {
                // Top section (titlebar)
                HStack(spacing: 0) {
                    SimpleSpriteImage(sprite: topLeft)
                    SimpleSpriteImage(sprite: topCenter)
                    SimpleSpriteImage(sprite: topRight)
                }

                // Bottom section (controls)
                HStack(spacing: 0) {
                    SimpleSpriteImage(sprite: bottomLeft)
                    SimpleSpriteImage(sprite: bottomCenter)
                    SimpleSpriteImage(sprite: bottomRight)
                }
            }

            // Video content area (inset)
            VideoPlayer(player: player)
                .frame(width: 253, height: 174)
                .offset(x: 11, y: 29)  // Position within chrome
        }
    }
}
```

### AVPlayer Integration

The video window uses AVPlayer for maximum format compatibility:

```swift
// Video playback management
@Observable
final class VideoPlayerManager {
    private(set) var player: AVPlayer = AVPlayer()
    private var timeObserver: Any?

    func loadVideo(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Add time observer for progress updates
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.updatePlaybackTime(time)
        }
    }

    func play() { player.play() }
    func pause() { player.pause() }
    func stop() {
        player.pause()
        player.seek(to: .zero)
    }
}
```

### Focus State Integration

The video window participates in the unified focus system:

```swift
// Focus chrome changes (normal vs selected sprites)
struct VideoWindowChromeView: View {
    @Environment(\.windowFocusState) var windowFocusState

    var isSelected: Bool {
        windowFocusState.focusedWindow == .video
    }

    var body: some View {
        // Use selected sprites when window has focus
        let topSprite = isSelected ? topCenterSelected : topCenterNormal
        SimpleSpriteImage(sprite: topSprite)
    }
}
```

### Window Resizing (1x/2x)

Video window supports double-size mode alongside other windows:

```swift
// Double-size synchronization
func updateVideoWindowSize() {
    guard let window = videoController.window else { return }

    let scale: CGFloat = appSettings.isDoubleSize ? 2.0 : 1.0
    let baseSize = CGSize(width: 275, height: 232)

    window.setContentSize(CGSize(
        width: baseSize.width * scale,
        height: baseSize.height * scale
    ))
}
```

### Fallback Chrome System

When VIDEO.bmp is missing, the window generates fallback chrome:

```swift
// Fallback chrome generation
func generateFallbackVideoChrome() -> NSImage {
    return NSImage(size: CGSize(width: 275, height: 58)) { rect in
        // Draw gradient background
        let gradient = NSGradient(colors: [
            NSColor(white: 0.15, alpha: 1.0),
            NSColor(white: 0.25, alpha: 1.0)
        ])
        gradient?.draw(in: rect, angle: -90)

        // Draw "VIDEO" text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.white
        ]
        "VIDEO".draw(at: CGPoint(x: 12, y: 5), withAttributes: attrs)

        return true
    }
}
```

### Key Implementation Details

1. **Activation**: V button toggles visibility (Ctrl+V keyboard shortcut)
2. **File Support**: MP4, MOV, M4V, AVI (QuickTime-compatible formats)
3. **Chrome Rendering**: VIDEO.bmp sprites with focus state variants
4. **Position Persistence**: Window frame saved to UserDefaults
5. **Docking Support**: Magnetic snapping via WindowSnapManager
6. **Audio Routing**: Shares audio session with main playback engine

For complete documentation, see: `docs/VIDEO_WINDOW.md`

---

## Milkdrop Window Architecture

The Milkdrop Window provides audio visualization via Butterchurn.js - a WebGL port of the legendary Milkdrop 2 visualizer. Implemented during TASK 2 (Days 7-8) for window chrome, with Butterchurn integration completed in January 2026 (7 phases, Oracle Grade A).

### Window Controller Implementation

```swift
// File: MacAmpApp/Windows/WinampMilkdropWindowController.swift
@MainActor
final class WinampMilkdropWindowController: NSWindowController {

    init(skinManager: SkinManager, appSettings: AppSettings,
         windowFocusState: WindowFocusState) {

        // Create the milkdrop window (same size as video)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        window.isReleasedWhenClosed = false
        window.title = "Visualization"
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.minSize = CGSize(width: 275, height: 232)

        super.init(window: window)

        // Set up the content view with GEN chrome
        let milkdropView = WinampMilkdropWindow(
            skinManager: skinManager,
            appSettings: appSettings
        )

        let hostingController = NSHostingController(rootView: milkdropView)
        window.contentViewController = hostingController
    }
}
```

### GEN.bmp Two-Piece Pattern

The Milkdrop window uses GEN.bmp sprites, which follow a unique two-piece pattern for each element:

```swift
// GEN.bmp sprite structure - Two pieces per element
struct GenSprite {
    let normal: NSImage    // First piece: normal state
    let selected: NSImage  // Second piece: selected/focused state
}

// 6-section titlebar layout
enum GenTitlebarSection {
    case topLeft       // GEN_TOP_LEFT + GEN_TOP_LEFT_SELECTED
    case topLeftEnd    // GEN_TOP_LEFT_END + GEN_TOP_LEFT_END_SELECTED
    case topTitle      // GEN_TOP_TITLE + GEN_TOP_TITLE_SELECTED
    case topRightBegin // GEN_TOP_RIGHT_BEGIN + GEN_TOP_RIGHT_BEGIN_SELECTED
    case topRight      // GEN_TOP_RIGHT + GEN_TOP_RIGHT_SELECTED
    case topRightEnd   // GEN_TOP_RIGHT_END + GEN_TOP_RIGHT_END_SELECTED
}
```

### Chrome Rendering with Focus State

```swift
struct MilkdropWindowChromeView: View {
    @Environment(\.windowFocusState) var windowFocusState
    let skinManager: SkinManager

    var isSelected: Bool {
        windowFocusState.focusedWindow == .milkdrop
    }

    var body: some View {
        ZStack {
            // Background chrome
            VStack(spacing: 0) {
                // 6-section titlebar
                HStack(spacing: 0) {
                    renderTitlebarSection(.topLeft)
                    renderTitlebarSection(.topLeftEnd)
                    renderTitlebarSection(.topTitle)
                    renderTitlebarSection(.topRightBegin)
                    renderTitlebarSection(.topRight)
                    renderTitlebarSection(.topRightEnd)
                }
                .frame(height: 20)

                // Middle section with borders
                HStack(spacing: 0) {
                    // Left border (GEN_MIDDLE_LEFT)
                    SimpleSpriteImage(
                        sprite: isSelected ? genMiddleLeftSelected : genMiddleLeft
                    )
                    .frame(width: 11)

                    // Content area (visualization placeholder)
                    VisualizationContent()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right border (GEN_MIDDLE_RIGHT)
                    SimpleSpriteImage(
                        sprite: isSelected ? genMiddleRightSelected : genMiddleRight
                    )
                    .frame(width: 8)
                }

                // Bottom bar
                HStack(spacing: 0) {
                    SimpleSpriteImage(
                        sprite: isSelected ? genBottomSelected : genBottom
                    )
                }
                .frame(height: 14)
            }
        }
    }

    func renderTitlebarSection(_ section: GenTitlebarSection) -> some View {
        // Use selected sprite when window has focus
        let sprite = isSelected ?
            skinManager.getGenSprite(section, selected: true) :
            skinManager.getGenSprite(section, selected: false)

        return SimpleSpriteImage(sprite: sprite)
    }
}
```

### Butterchurn Integration Architecture

Butterchurn.js provides real-time audio visualization via WKWebView with Swift audio bridge:

```
┌─────────────────────────────────────────────────────────────┐
│                    WKWebView Container                       │
├─────────────────────────────────────────────────────────────┤
│  WKUserScript Injection (atDocumentStart):                  │
│    1. butterchurn.min.js      (270KB - ES module bundled)   │
│    2. butterchurnPresets.min.js (187KB - preset library)    │
│                                                              │
│  WKUserScript Injection (atDocumentEnd):                    │
│    3. bridge.js               (Swift↔JS communication)      │
├─────────────────────────────────────────────────────────────┤
│  WebGL Canvas (60 FPS)                                       │
│    • Butterchurn visualizer instance                        │
│    • 100+ presets from butterchurnPresets library           │
│    • Hybrid WASM mode (see MILKDROP_WINDOW.md §9.10)        │
└─────────────────────────────────────────────────────────────┘
          │                              ▲
          │ postMessage("ready")         │ audioData[1024]
          │ postMessage("presetsLoaded") │ loadPreset(index)
          ▼                              │ showTrackTitle(text)
┌─────────────────────────────────────────────────────────────┐
│                    ButterchurnBridge                         │
│  @Observable @MainActor                                      │
│    • Timer: 30 FPS audio updates to JS                      │
│    • callAsyncJavaScript for reliable execution             │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**

```swift
// ButterchurnBridge.swift - Swift→JS communication
@Observable @MainActor
final class ButterchurnBridge {
    var isReady: Bool = false
    var errorMessage: String?
    var onPresetsLoaded: (([String]) -> Void)?

    private weak var audioPlayer: AudioPlayer?
    private var audioTimer: Timer?
    @ObservationIgnored private weak var webView: WKWebView?

    func sendAudioData() {
        guard isReady, let audioPlayer = audioPlayer else { return }
        let samples = audioPlayer.getVisualizationSamples(count: 1024)
        webView?.callAsyncJavaScript(
            "if (window.receiveAudioData) window.receiveAudioData([\(samples)]);",
            in: nil, in: .page
        ) { _ in }
    }
}

// ButterchurnPresetManager.swift - Preset lifecycle
@Observable @MainActor
final class ButterchurnPresetManager {
    var presets: [String] = []
    var currentPresetIndex: Int = -1
    var isRandomize: Bool = true      // Persisted
    var isCycling: Bool = true        // Persisted
    var cycleInterval: TimeInterval = 15.0
    var trackTitleInterval: TimeInterval = 0  // 0 = manual only

    @ObservationIgnored private var presetHistory: [Int] = []
    @ObservationIgnored private var cycleTimer: Timer?
}
```

### Fallback Chrome Generation

When GEN.bmp is missing, generates procedural chrome:

```swift
func generateFallbackGenChrome() -> GenChromeSet {
    // Generate gradient-based chrome elements
    func createGradientImage(size: CGSize, title: String? = nil) -> NSImage {
        return NSImage(size: size) { rect in
            // Draw gradient background
            let gradient = NSGradient(colors: [
                NSColor(white: 0.2, alpha: 1.0),
                NSColor(white: 0.3, alpha: 1.0)
            ])
            gradient?.draw(in: rect, angle: -90)

            // Draw title if provided
            if let title = title {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor.white
                ]
                title.draw(at: CGPoint(x: 8, y: 5), withAttributes: attrs)
            }

            return true
        }
    }

    return GenChromeSet(
        topLeft: createGradientImage(size: CGSize(width: 25, height: 20)),
        topTitle: createGradientImage(size: CGSize(width: 100, height: 20), title: "VISUALIZATION"),
        // ... generate all sections
    )
}
```

### Butterchurn Audio Data Flow

Complete path from audio file to WebGL visualization:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     BUTTERCHURN AUDIO DATA FLOW                          │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   Audio File (.mp3/flac)                                                  │
│        │                                                                  │
│        ▼                                                                  │
│   AVAudioEngine (48kHz stereo)                                            │
│        │                                                                  │
│        ▼                                                                  │
│   installTap(2048 samples) ─────▶ Mono downsample + vDSP FFT              │
│        │                                                                  │
│        ▼                                                                  │
│   AudioPlayer.swift                                                       │
│   ├── @ObservationIgnored butterchurnSpectrum[1024]                      │
│   ├── @ObservationIgnored butterchurnWaveform[1024]                      │
│   └── snapshotButterchurnFrame() → ButterchurnFrame                      │
│        │                                                                  │
│        ▼ (30 FPS Timer)                                                   │
│   ButterchurnBridge.swift                                                 │
│   └── callAsyncJavaScript("receiveAudioData([...])")                      │
│        │                                                                  │
│        ▼ (WKWebView)                                                      │
│   bridge.js                                                               │
│   └── ScriptProcessorNode → Butterchurn analyser                          │
│        │                                                                  │
│        ▼ (60 FPS requestAnimationFrame)                                   │
│   butterchurn.min.js                                                      │
│   └── visualizer.render() → WebGL Canvas                                  │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

**Note:** Butterchurn visualization only available for local file playback.
Internet radio streams (AVPlayer backend) cannot provide PCM audio data.

### Key Implementation Details

1. **Activation**: Ctrl+K keyboard shortcut (matches Winamp)
2. **Chrome Source**: GEN.bmp sprites with two-piece pattern
3. **Focus States**: Normal/selected sprite pairs for all elements
4. **Content Area**: 256×198 pixels for WebGL canvas
5. **Visualization**: Butterchurn.js via WKWebView with WKUserScript injection
6. **Audio Bridge**: 30 FPS Swift→JS using callAsyncJavaScript
7. **Preset Management**: Cycling, randomization, history, 100+ presets
8. **Track Title**: Manual or interval-based display (5s/10s/15s/30s/60s)
9. **Context Menu**: Right-click for preset navigation and settings
10. **Persistence**: All settings saved to UserDefaults via AppSettings

### Sprite Discovery Process

The two-piece GEN pattern was discovered through empirical analysis:

```swift
// Day 7 Research: GEN sprite pattern discovery
// File: tasks/milk-drop-video-support/milkdrop-analysis-hank.md

// Pattern discovered:
// - Each UI element has exactly 2 sprites
// - First sprite: normal state
// - Second sprite: selected/focused state
// - No pressed states (unlike MAIN.BMP buttons)

// Example mapping:
GEN_TOP_LEFT (index 0) → normal state
GEN_TOP_LEFT_SELECTED (index 1) → focused state
```

For complete documentation, see: `docs/MILKDROP_WINDOW.md`

---

## M3U Playlist Parser

MacAmp supports M3U and M3U8 playlist formats with both local files and internet radio streams.

### Parser Architecture

```swift
// File: MacAmpApp/Models/M3UParser.swift:25-125
// Purpose: Parse M3U/M3U8 playlist files with EXTINF metadata
// Context: Critical for playlist loading and internet radio support

struct M3UParser {
    /// Parse an M3U file from disk
    static func parse(fileURL: URL) throws -> [M3UEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw M3UParseError.fileNotFound
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw M3UParseError.encodingError
        }

        return try parse(content: content, relativeTo: fileURL)
    }

    /// Parse M3U content from a string
    static func parse(content: String, relativeTo baseURL: URL? = nil) throws -> [M3UEntry] {
        var entries: [M3UEntry] = []
        let lines = content.components(separatedBy: .newlines)

        var currentTitle: String?
        var currentDuration: Int?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Parse EXTINF metadata
            if trimmed.hasPrefix("#EXTINF:") {
                // Format: #EXTINF:duration,title
                let parts = trimmed.dropFirst(8).components(separatedBy: ",")
                if let durationStr = parts.first?.trimmingCharacters(in: .whitespaces),
                   let duration = Int(durationStr) {
                    currentDuration = duration
                }
                if parts.count > 1 {
                    currentTitle = parts.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            // Skip other comments (including #EXTM3U header)
            if trimmed.hasPrefix("#") { continue }

            // This is a URL/path line
            if let url = resolveURL(trimmed, relativeTo: baseURL) {
                let entry = M3UEntry(
                    url: url,
                    title: currentTitle,
                    duration: currentDuration
                )
                entries.append(entry)

                // Reset metadata for next entry
                currentTitle = nil
                currentDuration = nil
            }
        }

        guard !entries.isEmpty else {
            throw M3UParseError.emptyPlaylist
        }

        return entries
    }
}
```

### URL Resolution Logic

```swift
// File: MacAmpApp/Models/M3UParser.swift:93-124
// Purpose: Resolve relative paths and handle various URL formats
// Context: Supports HTTP streams, Unix paths, Windows paths

private static func resolveURL(_ urlString: String, relativeTo baseURL: URL?) -> URL? {
    let trimmed = urlString.trimmingCharacters(in: .whitespaces)

    // Handle HTTP/HTTPS URLs (internet radio streams)
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
        return URL(string: trimmed)
    }

    // Handle absolute file paths (Unix-style)
    if trimmed.hasPrefix("/") {
        return URL(fileURLWithPath: trimmed)
    }

    // Handle Windows absolute paths (C:\, D:\, etc.)
    if trimmed.count > 2 && trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)] == ":" {
        // Convert Windows path to Unix path
        let unixPath = trimmed.replacingOccurrences(of: "\\", with: "/")
        return URL(fileURLWithPath: unixPath)
    }

    // Handle relative paths
    if let base = baseURL {
        // Get the directory containing the M3U file
        let baseDir = base.deletingLastPathComponent()
        // Resolve relative path from M3U directory
        return URL(fileURLWithPath: trimmed, relativeTo: baseDir).standardized
    }

    // Fallback: try as file URL
    return URL(fileURLWithPath: trimmed)
}
```

### M3UEntry Model

```swift
// File: MacAmpApp/Models/M3UEntry.swift
// Purpose: Data model for parsed playlist entries
// Context: Supports both local files and streams

struct M3UEntry: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let title: String?
    let duration: Int?  // In seconds, from EXTINF

    var isStream: Bool {
        url.scheme?.lowercased().hasPrefix("http") == true
    }

    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return url.lastPathComponent
    }
}
```

### Integration with Playlist System

```swift
// Usage in playlist loading
func loadM3UPlaylist(from url: URL) async throws -> [Track] {
    let entries = try M3UParser.parse(fileURL: url)

    return entries.map { entry in
        Track(
            url: entry.url,
            title: entry.displayTitle,
            artist: "",  // M3U doesn't specify artist
            duration: Double(entry.duration ?? 0),
            isStream: entry.isStream
        )
    }
}
```

### Supported Formats

```
Standard M3U:
# Comment
/path/to/song1.mp3
/path/to/song2.mp3
http://stream.example.com/radio

Extended M3U (M3U8):
#EXTM3U
#EXTINF:180,Artist - Song Title
/path/to/song1.mp3
#EXTINF:-1,Radio Station Name
http://stream.example.com/radio
```

### Key Features

1. **Format Support**: M3U and M3U8 (extended) formats
2. **Stream Detection**: Automatic detection of HTTP/HTTPS streams
3. **Path Resolution**: Handles relative paths, absolute paths, Windows paths
4. **EXTINF Parsing**: Extracts duration and title metadata
5. **Error Handling**: Graceful handling of malformed files

---

## WindowAccessor Pattern

MacAmp uses WindowAccessor to bridge SwiftUI views with NSWindow functionality for window management.

### Implementation

```swift
// File: MacAmpApp/Utilities/WindowAccessor.swift:1-24
// Purpose: Access NSWindow from SwiftUI views
// Context: Required for window-level operations not exposed by SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onWindow(window)
        }
    }
}
```

### Usage Pattern

```swift
// Example: Configure window properties from SwiftUI
struct WinampMainWindow: View {
    var body: some View {
        ZStack {
            // Window configuration layer
            WindowAccessor { window in
                // Configure NSWindow properties
                window.isMovableByWindowBackground = true
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.standardWindowButton(.closeButton)?.isHidden = false
                window.standardWindowButton(.miniaturizeButton)?.isHidden = false
                window.standardWindowButton(.zoomButton)?.isHidden = true

                // Register with snap manager
                WindowSnapManager.shared.register(window: window, kind: .main)
            }
            .frame(width: 0, height: 0)  // Invisible

            // Actual window content
            MainWindowContent()
        }
    }
}
```

### Common Use Cases

1. **Window Registration**: Register windows with WindowSnapManager
2. **Titlebar Configuration**: Hide or customize the titlebar
3. **Window Buttons**: Show/hide traffic light buttons
4. **Draggable Background**: Make window draggable by background
5. **Window Level**: Set floating or normal window level

---

## Component Integration Maps

### Window Docking System (5-Window)

```
┌──────────────────────────────────────────────────┐
│           WindowSnapManager.shared                │
│                                                   │
│  • Magnetic window snapping (10px threshold)     │
│  • Connected cluster detection (5 windows)       │
│  • Screen edge snapping                          │
│  • Multi-monitor coordinate transformation       │
└──────────────────────────────────────────────────┘
                    │
     ┌──────────────┼──────────────┐
     ▼              ▼              ▼
Main Window    EQ Window    Playlist Window
     │              │              │
     └──────────────┴──────────────┘
                    │
     ┌──────────────┼──────────────┐
     ▼                             ▼
Video Window              Milkdrop Window
     │                             │
     └─────────────────────────────┘
                    │
                    ▼
            WindowAccessor
    (NSWindow manipulation via NSViewRepresentable)
```

### Playlist System

```
M3U/PLS File
     │
     ▼
M3UParser ──────► [Track] ──────► PlaylistManager
                                         │
                    ┌────────────────────┼────────────┐
                    ▼                    ▼            ▼
              Current Track        Track Queue    Shuffle Logic
                    │                    │            │
                    └────────────────────┴────────────┘
                                         │
                                         ▼
                                PlaybackCoordinator
```

### Visualization Pipeline

```
Audio Buffer (PCM from AVAudioEngine)
        │
        ▼
  [Audio Tap - MTAudioProcessingTap]
        │
   ┌────┴────┐
   ▼         ▼
  FFT    Waveform
   │     Extraction
   │         │
   ▼         ▼
20-band   Scope
Spectrum  Points
   │         │
   └────┬────┘
        │
   ┌────┴────────────┐
   ▼                 ▼
Main Window      Milkdrop Window
Spectrum Viz     Butterchurn.js (100+ presets)
(60 FPS)         Placeholder Animation
```

---

## UI Controls & Features

### Clutter Bar Buttons

The clutter bar is a vertical strip of 5 control buttons on the left side of the main window, providing quick access to player settings and information. As of v0.7.8, 4 of 5 buttons are functional.

**Button Locations** (WinampMainWindow.swift Coords):
```swift
static let clutterButtonO = CGPoint(x: 10, y: 25)  // top: 3px relative
static let clutterButtonA = CGPoint(x: 10, y: 33)  // top: 11px relative
static let clutterButtonI = CGPoint(x: 10, y: 40)  // top: 18px relative
static let clutterButtonD = CGPoint(x: 10, y: 47)  // top: 25px relative
static let clutterButtonV = CGPoint(x: 10, y: 55)  // top: 33px relative
```

**O Button - Options Menu** (v0.7.8):
- **Purpose**: Context menu with player settings
- **Functionality**:
  - Time display toggle (elapsed ⇄ remaining)
  - Double-size mode toggle
  - Repeat mode options (3 items with checkmarks):
    - Repeat: Off ✓ (when off)
    - Repeat: All ✓ (when all)
    - Repeat: One ✓ (when one)
  - Shuffle mode toggle
- **Implementation**: NSMenu via MenuItemTarget bridge
- **Keyboard Shortcuts**: Ctrl+O (menu), Ctrl+T (time toggle), Ctrl+R (cycle repeat)
- **State**: AppSettings.timeDisplayMode, AppSettings.repeatMode with UserDefaults persistence
- **Sprites**: MAIN_CLUTTER_BAR_BUTTON_O / BUTTON_O_SELECTED

**A Button - Always On Top** (v0.7.6):
- **Purpose**: Toggle window floating level
- **Functionality**: Keeps MacAmp windows above other apps
- **Implementation**: NSWindow.level = .floating
- **Keyboard Shortcut**: Ctrl+A
- **State**: AppSettings.isAlwaysOnTop with persistence
- **Sprites**: MAIN_CLUTTER_BAR_BUTTON_A / BUTTON_A_SELECTED

**I Button - Track Information** (v0.7.8):
- **Purpose**: Display track/stream metadata
- **Functionality**:
  - Shows title, artist, duration
  - Technical details: bitrate, sample rate, channels
  - Stream-aware with graceful fallbacks
- **Implementation**: SwiftUI sheet with TrackInfoView
- **Keyboard Shortcut**: Ctrl+I
- **State**: AppSettings.showTrackInfoDialog (transient, not persisted)
- **Sprites**: MAIN_CLUTTER_BAR_BUTTON_I / BUTTON_I_SELECTED

**D Button - Double Size** (v0.7.5):
- **Purpose**: Scale UI between 100% and 200%
- **Functionality**: Applies to all windows (main, EQ, playlist)
- **Implementation**: UnifiedDockView.scaleEffect(scale, anchor: .topLeading)
- **Keyboard Shortcut**: Ctrl+D
- **State**: AppSettings.isDoubleSizeMode with persistence
- **Sprites**: MAIN_CLUTTER_BAR_BUTTON_D / BUTTON_D_SELECTED

**V Button - Visualizer** (scaffolded):
- **Purpose**: Toggle visualizer modes (spectrum/oscilloscope/none)
- **Status**: Scaffolded, pending implementation
- **Implementation**: To be implemented
- **Sprites**: MAIN_CLUTTER_BAR_BUTTON_V defined

**Architecture Pattern**:
```swift
// Clutter bar button pattern (proven in D/A/O/I implementations)
// Real example from AppSettings.swift:
@Observable
@MainActor
final class AppSettings {
    var isDoubleSizeMode: Bool = false {
        didSet {
            UserDefaults.standard.set(isDoubleSizeMode, forKey: "isDoubleSizeMode")
        }
    }
}

// In WinampMainWindow.swift:
let dSpriteName = settings.isDoubleSizeMode
    ? "MAIN_CLUTTER_BAR_BUTTON_D_SELECTED"
    : "MAIN_CLUTTER_BAR_BUTTON_D"

Button(action: {
    settings.isDoubleSizeMode.toggle()
}) {
    SimpleSpriteImage(dSpriteName, width: 8, height: 8)
}
.buttonStyle(.plain)
.help("Toggle window size")
```

### Repeat Mode Button (Winamp 5 Modern Pattern)

**Implementation** (v0.7.9):
- **State**: AppSettings.RepeatMode enum (off/all/one)
- **Persistence**: UserDefaults with didSet pattern
- **Visual**: ZStack with "1" badge overlay for repeat-one mode
- **Badge Specs**: 8px bold font, white color, shadow for legibility
- **Interaction**: Click button to cycle Off → All → One → Off
- **Keyboard**: Ctrl+R cycles through modes
- **Migration**: Boolean true → .all, false → .off (preserves user preference)

**UI Implementation Pattern**:
```swift
// File: MacAmpApp/Views/WinampMainWindow.swift
// Repeat button with "1" badge overlay (Winamp 5 Modern fidelity)
ZStack(alignment: .center) {
    // Base repeat button
    SimpleSpriteImage(
        source: .legacy(settings.repeatMode.isActive ?
                       "REPEAT_BUTTON_ACTIVE_NORM" :
                       "REPEAT_BUTTON_INACTIVE_NORM"),
        action: .button(onClick: {
            settings.repeatMode = settings.repeatMode.next()
        })
    )

    // "1" badge overlay (only for repeat-one mode)
    if settings.repeatMode == .one {
        Text("1")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.9), radius: 1, x: 0, y: 1)
            .allowsHitTesting(false)  // Pass clicks through
    }
}
.help(settings.repeatMode.label)
.at(x: 210, y: 89)
```

### Time Display System

**Implementation** (v0.7.8):
- **State**: AppSettings.timeDisplayMode (elapsed/remaining)
- **Persistence**: UserDefaults with didSet pattern
- **Visual**: Minus sign centered at y:6 in 9x13 container for remaining mode
- **Interaction**: Click time display or Ctrl+T to toggle
- **Integration**: Synchronized with O button menu checkmarks

**Technical Details**:
```swift
enum TimeDisplayMode: String, Codable {
    case elapsed = "elapsed"      // 00:00 → track duration
    case remaining = "remaining"  // -duration → -00:00
}
```

### Volume & Balance Sliders

**Implementation** (v1.0.6, updated T5 Phase 1):

**Signal Flow (T5 Phase 1 Coordinator Routing):**
```
UI Slider → PlaybackCoordinator.setVolume() → AudioPlayer.volume (persists + playerNode)
                                             → StreamPlayer.volume (AVPlayer.volume)
                                             → VideoPlaybackController.volume

UI Slider → PlaybackCoordinator.setBalance() → AudioPlayer.balance (persists + playerNode.pan)
                                              → StreamPlayer.balance (stored, no AVPlayer .pan)
```

The UI uses asymmetric `Binding<Float>` -- reads from AudioPlayer (source of truth for persistence), writes through PlaybackCoordinator for fan-out to all backends. This replaced direct `$audioPlayer.volume` bindings that bypassed StreamPlayer and VideoPlaybackController.

**State & Persistence** (AudioPlayer mechanism layer):
```swift
// AudioPlayer.swift - Centralized UserDefaults keys
private enum Keys {
    static let volume = "volume"
    static let balance = "balance"
}

// IMPORTANT: All external volume changes must go through PlaybackCoordinator.setVolume()
// AudioPlayer.volume didSet only handles local concerns (playerNode + persistence).
var volume: Float = 0.75 {  // 0.0 to 1.0, default 0.75 (audible)
    didSet {
        playerNode.volume = volume
        UserDefaults.standard.set(volume, forKey: Keys.volume)
    }
}

var balance: Float = 0.0 {  // -1.0 (left) to 1.0 (right)
    didSet {
        playerNode.pan = balance
        UserDefaults.standard.set(balance, forKey: Keys.balance)
    }
}

// Restoration in init()
init() {
    if let saved = UserDefaults.standard.object(forKey: Keys.volume) as? Float {
        self.volume = saved
    }
    if let saved = UserDefaults.standard.object(forKey: Keys.balance) as? Float {
        self.balance = saved
    }
}
```

**Coordinator Routing** (PlaybackCoordinator):
```swift
// PlaybackCoordinator.swift - Fan-out to all backends
func setVolume(_ vol: Float) {
    audioPlayer.volume = vol                      // Persists + playerNode
    streamPlayer.volume = vol                     // AVPlayer.volume
    audioPlayer.videoPlaybackController.volume = vol
}

func setBalance(_ bal: Float) {
    audioPlayer.balance = bal                     // Persists + playerNode.pan
    streamPlayer.balance = bal                    // Stored for Phase 2
}
```

**UI Binding Pattern** (WinampMainWindow+Helpers.swift):
```swift
// Asymmetric binding: read from AudioPlayer, write through coordinator
let volumeBinding = Binding<Float>(
    get: { audioPlayer.volume },
    set: { playbackCoordinator.setVolume($0) }
)
WinampVolumeSlider(volume: volumeBinding)

let balanceBinding = Binding<Float>(
    get: { audioPlayer.balance },
    set: { playbackCoordinator.setBalance($0) }
)
WinampBalanceSlider(balance: balanceBinding)
    .opacity(playbackCoordinator.supportsBalance ? 1.0 : 0.5)
    .allowsHitTesting(playbackCoordinator.supportsBalance)
```

**Capability-Based Dimming** (T5 Phase 1):
- Balance slider dims (50% opacity, hit testing disabled) during stream playback
- EQ sliders dim via `playbackCoordinator.supportsEQ` in WinampEqualizerWindow
- Controls re-enable when stream enters error state (user not stuck with dimmed UI)
- Tooltip changes to "Balance unavailable during streaming" when dimmed

**Balance Slider Color Gradient** (WinampVolumeSlider.swift):
- BALANCE.BMP: 28 frames stacked vertically (15px each, 420px total)
- Frame 0 (top) = green (neutral center), Frame 27 (bottom) = red (full L/R)
- Uses webamp-compatible linear mapping: `floor(abs(balance) * 27) * 15`
- Symmetric via `abs(balance)`: both full-left and full-right show red

**Haptic Snap-to-Center**:
- Fires once on entry into center zone (not every frame)
- Threshold: 12% of slider range
- Uses NSHapticFeedbackManager for system-native feedback

---

## Testing Strategies

### Test Plan & Configurations

**Test target**: `MacAmpTests` (`Tests/MacAmpTests`)
**Test plan**: `MacAmpApp.xcodeproj/xcshareddata/xctestplans/MacAmpApp.xctestplan`

**Configurations**:
- Core: AppSettingsTests, EQCodecTests, SpriteResolverTests
- Concurrency: AudioPlayerStateTests, DockingControllerTests, PlaylistNavigationTests, SkinManagerTests
- All: full MacAmpTests target

**CLI**:
```bash
xcodebuild test -project MacAmpApp.xcodeproj -scheme MacAmpApp -destination 'platform=macOS' -testPlan MacAmpApp -only-test-configuration Core -derivedDataPath build/DerivedDataTests
```

Swap `Core` for `Concurrency` or `All` as needed.

### Unit Tests

```swift
// Tests/MacAmpTests/SpriteResolverTests.swift
// Uses Swift Testing framework (swift-tools-version 6.2)
import Testing
@testable import MacAmpApp

@Suite struct SpriteResolverTests {
    @Test func semanticResolution() {
        let skin = MockSkin()
        let resolver = SpriteResolver(skin: skin)

        // Test primary mapping
        let playButton = resolver.resolve(.playButton)
        #expect(playButton.source == .skin("CBUTTONS_PLAY_NORM"))

        // Test fallback generation
        let missing = resolver.resolve(.customButton)
        #expect(missing.source == .generated)
    }

    @Test func alternativeMapping() {
        let skin = MockSkin(sprites: ["PLAY_BUTTON": mockSprite])
        let resolver = SpriteResolver(skin: skin)

        // Should find alternative name
        let playButton = resolver.resolve(.playButton)
        #expect(playButton.source == .skin("PLAY_BUTTON"))
    }
}
```

### Integration Tests

```swift
// Tests/MacAmpTests/PlaybackCoordinatorTests.swift
// Uses Swift Testing framework (swift-tools-version 6.2)
import Testing
@testable import MacAmpApp

@Suite @MainActor struct PlaybackCoordinatorTests {
    @Test func exclusivePlayback() async {
        let audioPlayer = MockAudioPlayer()
        let streamPlayer = MockStreamPlayer()
        let coordinator = PlaybackCoordinator(
            audioPlayer: audioPlayer,
            streamPlayer: streamPlayer
        )

        // Start local playback
        let localTrack = Track(url: URL(fileURLWithPath: "/test.mp3"))
        await coordinator.play(track: localTrack)

        #expect(audioPlayer.isPlaying)
        #expect(!streamPlayer.isPlaying)

        // Switch to stream
        let streamTrack = Track(url: URL(string: "http://stream.mp3")!)
        await coordinator.play(track: streamTrack)

        #expect(!audioPlayer.isPlaying)
        #expect(streamPlayer.isPlaying)
    }
}
```

### UI Tests

```swift
// UITests/MacAmpUITests.swift
// UI tests still use XCTest (XCUIApplication requires it)
import XCTest

final class MacAmpUITests: XCTestCase {
    func testSkinLoading() {
        let app = XCUIApplication()
        app.launch()

        // Open skin selector
        app.menuBars.menuItems["Skins"].click()
        app.menuItems["Load Skin..."].click()

        // Select test skin
        let dialog = app.dialogs.firstMatch
        dialog.textFields.firstMatch.typeText("TestSkin.wsz")
        dialog.buttons["Open"].click()

        // Verify skin loaded
        XCTAssertTrue(app.windows["main"].exists)
        XCTAssertTrue(app.images["mainBackground"].exists)
    }
}
```

---

## Common Pitfalls & Solutions

### Pitfall 1: State Object Lifecycle

**Problem**: Creating computed properties for stateful objects
```swift
// ❌ WRONG - Resets on every view update!
var playbackCoordinator: PlaybackCoordinator {
    PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
}
```

**Solution**: Use @State for proper lifecycle
```swift
// ✅ CORRECT - Persists across view updates
@State private var playbackCoordinator = PlaybackCoordinator(...)
```

### Pitfall 2: Threading Violations

**Problem**: Updating UI from background thread
```swift
// ❌ Crashes with purple warning
Task.detached {
    let result = await heavyComputation()
    self.displayText = result  // CRASH: Not on main thread!
}
```

**Solution**: Use @MainActor or explicit dispatch
```swift
// ✅ Safe update
Task.detached {
    let result = await heavyComputation()
    await MainActor.run {
        self.displayText = result
    }
}
```

### Pitfall 3: AVAudioEngine State

**Problem**: Not handling audio session interruptions
```swift
// ❌ Crashes after phone call on iOS or system audio change
engine.start()  // Throws after interruption
```

**Solution**: Implement proper error handling
```swift
// ✅ Resilient to interruptions
do {
    try engine.start()
} catch {
    // Reset audio graph
    resetAudioEngine()
    try? engine.start()
}
```

### Pitfall 4: Memory Leaks in Closures

**Problem**: Strong reference cycles
```swift
// ❌ Leak - self captured strongly
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
    self.updateTime()  // Strong reference to self
}
```

**Solution**: Use weak references
```swift
// ✅ No leak
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
    self?.updateTime()
}
```

### Pitfall 5: SwiftUI Redraw Storms

**Problem**: Entire view hierarchy redraws on state change
```swift
// ❌ Everything redraws when time updates
struct PlayerView: View {
    @ObservedObject var player: AudioPlayer  // Updates every 100ms

    var body: some View {
        VStack {
            ExpensiveView()  // Redraws unnecessarily
            TimeDisplay(time: player.currentTime)
            AnotherExpensiveView()  // Also redraws
        }
    }
}
```

**Solution**: Isolate frequently updating state
```swift
// ✅ Only TimeDisplay redraws
struct PlayerView: View {
    var body: some View {
        VStack {
            ExpensiveView()
            TimeDisplayContainer()  // Isolated updates
            AnotherExpensiveView()
        }
    }
}

struct TimeDisplayContainer: View {
    @ObservedObject var player: AudioPlayer

    var body: some View {
        TimeDisplay(time: player.currentTime)
    }
}
```

---

## Quick Reference

### Key Files & Their Purposes

```
MacAmpApp/
├── Audio/
│   ├── AudioPlayer.swift           # AVAudioEngine facade, local playback, volume/balance (~948 lines)
│   ├── EqualizerController.swift   # EQ facade (extracted from AudioPlayer, ~198 lines)
│   ├── LockFreeRingBuffer.swift    # SPSC ring buffer for stream audio (~212 lines)
│   ├── EQPresetStore.swift         # EQ preset persistence (187 lines)
│   ├── MetadataLoader.swift        # Async track/video metadata (171 lines)
│   ├── PlaylistController.swift    # Playlist state and navigation (273 lines)
│   ├── VideoPlaybackController.swift # AVPlayer lifecycle (297 lines)
│   ├── VisualizerPipeline.swift    # Audio tap, FFT, SPSC buffer, Butterchurn (675 lines)
│   ├── StreamPlayer.swift          # AVPlayer, internet radio, volume/balance (212 lines)
│   └── PlaybackCoordinator.swift   # Orchestrates both backends, volume/balance routing, capability flags (407 lines)
│
├── Models/
│   ├── Track.swift                 # Track data model (42 lines, Sendable)
│   ├── SpriteResolver.swift        # Semantic → actual sprite mapping
│   ├── Skin.swift                  # Skin model and loading
│   └── RadioStation.swift          # Internet radio station model
│
├── ViewModels/
│   ├── SkinManager.swift           # Skin loading and hot-swap
│   ├── DockingController.swift     # Window magnetic docking
│   └── PlaylistManager.swift       # Playlist and queue management
│
├── Views/
│   ├── WinampMainWindow.swift      # Main player window
│   ├── WinampEqualizerWindow.swift # 10-band EQ window
│   ├── WinampPlaylistWindow.swift  # Playlist window
│   ├── WinampVideoWindow.swift     # Video playback window
│   ├── WinampMilkdropWindow.swift  # Visualization window
│   └── Components/
│       ├── SimpleSpriteImage.swift # Sprite rendering
│       └── SkinnedText.swift       # Bitmap font rendering
│
├── Windows/
│   ├── WindowRegistry.swift                  # Window ownership + lookup (83 lines)
│   ├── WindowFramePersistence.swift          # Frame save/load/suppress (146 lines)
│   ├── WindowVisibilityController.swift      # Show/hide/toggle (@Observable, 161 lines)
│   ├── WindowResizeController.swift          # Resize + docking (312 lines)
│   ├── WindowSettingsObserver.swift          # Settings observation (114 lines)
│   ├── WindowDelegateWiring.swift            # Delegate factory (54 lines)
│   ├── WindowDockingTypes.swift              # Value types (Sendable, 50 lines)
│   ├── WindowDockingGeometry.swift           # Pure geometry (nonisolated, 109 lines)
│   ├── WindowFrameStore.swift                # UserDefaults persistence (65 lines)
│   ├── WinampMainWindowController.swift      # NSWindowController for main
│   ├── WinampEqualizerWindowController.swift # NSWindowController for EQ
│   ├── WinampPlaylistWindowController.swift  # NSWindowController for playlist
│   ├── WinampVideoWindowController.swift     # NSWindowController for video
│   └── WinampMilkdropWindowController.swift  # NSWindowController for milkdrop
│
└── MacAmpApp.swift                 # App entry point, DI setup
```

### Common Tasks

**Load a skin:**
```swift
await skinManager.loadSkin(from: URL(fileURLWithPath: "/path/to/skin.wsz"))
```

**Play a file:**
```swift
await playbackCoordinator.play(url: URL(fileURLWithPath: "/path/to/song.mp3"))
```

**Play internet radio:**
```swift
let station = RadioStation(name: "My Station", streamURL: URL(string: "http://stream.url")!)
await playbackCoordinator.play(station: station)
```

**Apply EQ preset:**
```swift
audioPlayer.applyEQPreset(.rock)
```

**Set repeat mode:**
```swift
// Set specific mode
audioPlayer.repeatMode = .one  // Repeat current track
audioPlayer.repeatMode = .all  // Loop playlist
audioPlayer.repeatMode = .off  // Stop at end

// Cycle through modes (button behavior)
audioPlayer.repeatMode = audioPlayer.repeatMode.next()
```

**Add to playlist:**
```swift
playlistManager.addTrack(Track(url: url, title: "Song", artist: "Artist", duration: 180))
```

**Dock windows:**
```swift
dockingController.dockWindow(.equalizer, to: .main, edge: .bottom)
```

### Build & Run

```bash
# Debug build
xcodebuild -scheme MacAmp -configuration Debug build

# Release build with optimizations
xcodebuild -scheme MacAmp -configuration Release \
    -archivePath MacAmp.xcarchive archive

# Run tests
swift test

# Clean build
xcodebuild clean
```

### Performance Metrics

```
Audio Latency:        < 10ms
Skin Load Time:       < 500ms (typical .wsz)
Memory Usage:         ~50MB idle, ~80MB playing
CPU (Playing):        2-5% (M1 Mac)
CPU (Visualizer):     5-10% (60 FPS spectrum)
```

### Sprite File Reference

**Core Window Sprites:**
```
MAIN.BMP         # Main window chrome (275x116)
EQ_EX.BMP        # Equalizer window chrome (275x116)
PLEDIT.BMP       # Playlist window chrome (275x164)
VIDEO.BMP        # Video window chrome (275x116) - 6 sections
GEN.BMP          # Generic/Milkdrop chrome - Two-piece pattern
```

**Button Sprites:**
```
CBUTTONS.BMP     # Control buttons (play, pause, stop, prev, next)
SHUFREP.BMP      # Shuffle and repeat buttons (4 states each)
TITLEBAR.BMP     # Titlebar buttons (close, minimize, shade)
```

**Display Elements:**
```
NUMBERS.BMP      # Time display digits (0-9)
TEXT.BMP         # Scrolling text display font
MONOSTER.BMP     # Stereo/mono indicators
VOLUME.BMP       # Volume slider sprites
BALANCE.BMP      # Balance slider sprites
POSBAR.BMP       # Position/seek bar sprites
```

**Visualization:**
```
VISCOLOR.TXT     # Spectrum analyzer color palette
```

**Text Configuration:**
```
PLEDIT.TXT       # Playlist text colors and fonts
REGION.TXT       # Window shape regions (for non-rectangular windows)
```

**GEN.bmp Sprite Pattern (Milkdrop):**
```
// Two-piece pattern: each element has normal + selected state
GEN_TOP_LEFT           # Index 0: Normal state
GEN_TOP_LEFT_SELECTED  # Index 1: Selected/focused state

// 6-section titlebar layout:
- GEN_TOP_LEFT / GEN_TOP_LEFT_SELECTED
- GEN_TOP_LEFT_END / GEN_TOP_LEFT_END_SELECTED
- GEN_TOP_TITLE / GEN_TOP_TITLE_SELECTED
- GEN_TOP_RIGHT_BEGIN / GEN_TOP_RIGHT_BEGIN_SELECTED
- GEN_TOP_RIGHT / GEN_TOP_RIGHT_SELECTED
- GEN_TOP_RIGHT_END / GEN_TOP_RIGHT_END_SELECTED

// Borders and bottom:
- GEN_MIDDLE_LEFT / GEN_MIDDLE_LEFT_SELECTED
- GEN_MIDDLE_RIGHT / GEN_MIDDLE_RIGHT_SELECTED
- GEN_BOTTOM / GEN_BOTTOM_SELECTED
```

---

## Conclusion

MacAmp demonstrates that retro UI aesthetics and modern development practices are not mutually exclusive. By carefully architecting around platform limitations (dual audio backends), leveraging modern language features (Swift 6 concurrency), and maintaining strict architectural boundaries (three-layer pattern), we've created a maintainable, performant, and pixel-perfect recreation of a beloved classic.

The key insight: **The skin is not the app**. This separation enables MacAmp to be simultaneously a faithful Winamp clone and a modern macOS application built with 2025's best practices.

For developers joining the project: start with `PlaybackCoordinator.swift` to understand the orchestration pattern, explore `SpriteResolver.swift` for the semantic mapping system, and examine `WinampMainWindow.swift` to see how it all comes together in SwiftUI.

Welcome to MacAmp. May your audio be crisp and your skins be pixel-perfect.

---

*Document Version: 2.4.0 | Last Updated: 2026-02-09 | Lines: 4,555*

**Recent Updates (v2.4.0 - 2026-02-09):**
- Added WindowCoordinator refactoring to Recent Architectural Changes (#10)
- Updated Component Breakdown table with Window Management section (11 files, 1,470 lines)
- Updated Five-Window NSWindowController Stack with post-refactoring architecture
- Updated File Structure Quick Reference with Windows/ directory breakdown
- Cross-referenced MULTI_WINDOW_ARCHITECTURE.md §10 for refactoring details
