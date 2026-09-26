# MacAmp Complete Architecture Guide

**Version:** 3.3.0
**Date:** 2026-09-25
**Scope:** Current architecture (macOS 27+, Swift 6.2): five-window system, unified audio pipeline, AVPlayer-native video DSP
**Purpose:** Deep technical reference for developers joining or maintaining MacAmp: what the system is and why. Code-level patterns (snippet, when to use, pitfalls) live in [IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md).

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Metrics & Current State](#project-metrics--current-state)
3. [Three-Layer Architecture Deep Dive](#three-layer-architecture-deep-dive)
4. [Unified Audio Pipeline Architecture](#unified-audio-pipeline-architecture)
4a. [AudioPlayer Decomposition Architecture](#audioplayer-decomposition-architecture)
5. [Skin System Complete Architecture](#skin-system-complete-architecture)
6. [State Management Evolution](#state-management-evolution)
6a. [Window Focus State Management](#window-focus-state-management)
6b. [Five-Window NSWindowController Stack](#five-window-nswindowcontroller-stack)
7. [SwiftUI Rendering Techniques](#swiftui-rendering-techniques)
8. [Audio Processing Pipeline](#audio-processing-pipeline)
8a. [AVPlayer-Native Video DSP](#avplayer-native-video-dsp)
9. [Internet Radio Streaming](#internet-radio-streaming)
10. [Modern Swift 6.2 Patterns](#modern-swift-62-patterns)
10a. [Window Snap Manager](#window-snap-manager)
10b. [Sprite-Based Menu System](#sprite-based-menu-system)
10c. [Video Window Architecture](#video-window-architecture)
10d. [Milkdrop Window Architecture](#milkdrop-window-architecture)
10e. [M3U Playlist Parser](#m3u-playlist-parser)
11. [Component Integration Maps](#component-integration-maps)
11a. [UI Controls & Features](#ui-controls--features)
12. [Testing Strategies](#testing-strategies)
13. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
14. [Quick Reference](#quick-reference)

---

## Executive Summary

MacAmp is a pixel-perfect recreation of Winamp 2.x for macOS, built entirely with SwiftUI and modern Swift concurrency. It's not just a nostalgic clone—it's a case study in bridging 1997 desktop UI patterns with 2025 Apple platform technologies.

### What Makes MacAmp Unique

1. **Two DSP Paths, One Set of Controls**: A custom stream decode pipeline feeds local audio files and internet radio through AVAudioEngine; local video stays on AVPlayer and gets the same EQ, preamp, balance and visualizer through an in-place `MTAudioProcessingTap`. The EQ and balance controls drive both paths
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

### Codebase Statistics (September 2026)

```
Total Swift Files:        122 (MacAmpApp/)
Lines of Code:            ~20,400
Tests:                    119 (Swift Testing, run under Thread Sanitizer)
Supported Formats:        MP3, M4A, FLAC, WAV, AAC, HTTP/HTTPS streams; MP4/MOV/M4V/AVI video
Skins:                    Winamp 2.x .wsz
macOS Support:            27.0+ (minimum raised 2026-09-25; macOS 15/26 supported by earlier releases)
Architecture:             SwiftUI + AVFoundation
Deployment:               Developer ID signed, notarization-ready
```

### Component Breakdown

Line counts from `wc -l` on 2026-09-25. Other sections of this guide deliberately omit per-file sizes.

| Directory | Files | Lines | Contents |
|---|---:|---:|---|
| `Audio/` (top level) | 15 | 5,367 | Playback facade, engine, EQ, visualizer, stream player, coordinator |
| `Audio/VideoDSP/` | 5 | 925 | `MTAudioProcessingTap` video DSP |
| `Audio/Streaming/` | 5 | 1,528 | Stream decode chain |
| `Windows/` | 15 | 1,350 | NSWindowControllers and WindowCoordinator collaborators |
| `ViewModels/` | 8 | 1,705 | SkinManager, WindowCoordinator, Butterchurn, docking |
| `Views/` | 41 | 5,514 | incl. `MainWindow/` (10 files, 1,060), `PlaylistWindow/` (7, 587), `Components/` (10), `Windows/` (4), `Shared/` (2) |
| `Models/` | 20 | 2,895 | Settings, skin model/parsers, sprite resolver, M3U, sizing state |
| `Utilities/` | 10 | 807 | Logging, window configuration, snapping, `WeakBox` |
| App root | 3 | 316 | `MacAmpApp.swift`, `AppCommands.swift`, `SkinsCommands.swift` |

`Audio/ObjCBridge/` adds `AUAudioUnitWorkgroupShim.h/.m` (17 + 23 lines) for `os_workgroup` access.

**Audio mechanism files:**

| File | Lines | Isolation |
|---|---:|---|
| `AudioPlayer.swift` | 1,082 | `@MainActor` facade |
| `Streaming/StreamDecodePipeline.swift` | 825 | `@MainActor` + queue-confined `DecodeContext` |
| `StreamPlayer.swift` | 714 | `@MainActor` |
| `PlaybackCoordinator.swift` | 587 | `@MainActor` |
| `AudioEngineController.swift` | 578 | `@MainActor` |
| `VisualizerPipeline.swift` | 416 | `@MainActor` |
| `VideoPlaybackController.swift` | 362 | `@MainActor` |
| `EqualizerController.swift` | 316 | `@MainActor` |
| `VideoDSP/VideoTap.swift` | 306 | C callbacks |
| `Streaming/AudioConverterDecoder.swift` | 298 | Decode-queue-confined |
| `PlaylistController.swift` | 286 | `@MainActor` |
| `VideoDSP/VideoTapContext.swift` | 224 | `Atomic` / `Mutex` fields |
| `LockFreeRingBuffer.swift` | 218 | SPSC, lock-free |
| `Streaming/ICYFramer.swift` | 200 | `Sendable` struct |
| `VisualizerScratchBuffers.swift` | 195 | Render-confined |
| `EQPresetStore.swift` | 191 | `@MainActor` |
| `Streaming/AudioFileStreamParser.swift` | 186 | Decode-queue-confined |
| `MetadataLoader.swift` | 169 | `nonisolated` struct |
| `VideoDSP/BiquadCoefficientSet.swift` | 167 | `Sendable` |
| `VideoDSP/VideoTapVisualizerRender.swift` | 129 | Render-confined |
| `VisualizerFeed.swift` | 112 | SPSC hand-off |
| `VideoDSP/BiquadCascade.swift` | 99 | Render-confined |
| `AudioEngineConfigurationObserver.swift` | 93 | `@MainActor` |
| `RenderThreadSafe.swift` | 48 | Marker protocol |
| `Streaming/QueueConfined.swift` | 19 | Protocol |

### Recent Architectural Changes

- **2026-09 — AVPlayer-native video DSP:** EQ, preamp, balance and the visualizer work for local video through an in-place `MTAudioProcessingTap`; `VisualizerPipeline` split into `VisualizerFeed` + `VisualizerScratchBuffers`; `AudioEngineConfigurationObserver` handles output-route changes. See [AVPlayer-Native Video DSP](#avplayer-native-video-dsp).
- **2026-09-25 — Minimum OS raised to macOS 27.**
- **2026-03 — Network auto-reconnect:** typed `StreamTerminationReason`, exponential backoff. See [Auto-Reconnect State Machine](#auto-reconnect-state-machine).
- **2026-03 — Unified audio pipeline and `AudioEngineController`:** streams decode to PCM and play through AVAudioEngine; the engine graph lifecycle moved out of `AudioPlayer`.
- **2026-02 — Window and view decomposition:** `WindowCoordinator` became a facade over 10 collaborators ([MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md) §10); the main and playlist windows became `MainWindow/` (10 files) and `PlaylistWindow/` (7 files) child-view decompositions.

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
│  • AudioPlayer (facade for local files + engine + video)    │
│  • AudioEngineController (AVAudioEngine graph lifecycle)    │
│  • EqualizerController (EQ state, engine + video-tap fanout)│
│  • EQPresetStore (preset persistence)                       │
│  • MetadataLoader (async metadata extraction)               │
│  • PlaylistController (playlist state/navigation)           │
│  • VideoPlaybackController (AVPlayer + audioMix lifecycle)  │
│  • VideoDSP/ (MTAudioProcessingTap in-place video DSP)      │
│  • VisualizerPipeline (engine tap, VisualizerFeed consumer) │
│  • StreamPlayer (stream decode pipeline for internet radio)  │

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

// 1. PRESENTATION (MainWindow/MainWindowTransportLayer.swift)
Button(action: { playbackCoordinator.togglePlayPause() }, label: {
    SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
})
.buttonStyle(.plain)
.focusable(false)
.at(Layout.playButton)

// 2. ORCHESTRATION (PlaybackCoordinator.swift): togglePlayPause() resumes the current
//    source; starting a track (playlist, next/previous) goes through play(track:),
//    which routes to exactly one backend
func play(track: Track) async {
    audioPlayer.updatePlaylistPosition(with: track)
    currentTrack = track

    if track.isStream {
        stopAllBackends()
        await streamPlayer.play(url: track.url, title: track.title, artist: track.artist)
        currentSource = .radioStation(RadioStation(name: track.title, streamURL: track.url))
        currentTitle = track.title
    } else {
        stopAllBackends()
        audioPlayer.playTrack(track: track)
        updateLocalPlaybackState(for: track)
    }
    updateNowPlayingInfo()
}

// 3. MECHANISM (AudioPlayer + AudioEngineController)
// playTrack detects the media type by extension. Audio: schedule the file on
// AVAudioPlayerNode, start the engine, install the visualizer tap. Video: build
// the AVPlayer with its audio tap. Either way playbackState transitions to
// .playing and @Observable state flows back up to the views.
```

### Why Three Layers?

1. **Skin Independence**: Core functionality works without any skin
2. **Testability**: Can test audio playback without UI
3. **Modularity**: Can swap rendering layer (e.g., AppKit instead of SwiftUI)
4. **Maintainability**: Clear boundaries prevent spaghetti code

---

## Unified Audio Pipeline Architecture

MacAmp routes all audio-only sources -- local files and internet radio streams -- through a single AVAudioEngine graph. This unified pipeline provides EQ, visualization, and balance for every audio source.

Local **video** is the one exception: its audio stays on AVPlayer and is processed in place by an `MTAudioProcessingTap`, with the same EQ/preamp/balance state and the same visualizer feed. See [AVPlayer-Native Video DSP](#avplayer-native-video-dsp).

Before March 2026, streams played through AVPlayer, which exposes no decoded PCM, so streams had no EQ, visualizer or balance. A custom decode pipeline now feeds decoded PCM into the same AVAudioEngine that plays local files.

### The Unified Architecture

```
LOCAL FILES (AVAudioPlayerNode path):
AVAudioFile ──► AVAudioPlayerNode ──┐
                                     │
                                     ▼
                              AVAudioUnitEQ(10-band)
                                     │
                              mainMixerNode ──► [visualizer tap] ──► VisualizerPipeline
                                     │
                                outputNode ──► Speakers

INTERNET RADIO (custom decode pipeline):
HTTP URL ──► URLSession ──► ICYFramer ──► AudioFileStreamParser
                │               │                     │
           [HTTP headers]  [StreamTitle]        [compressed packets]
           [icy-metaint]   [StreamArtist]              │
                                              AudioConverterDecoder
                                                       │
                                                [Float32 PCM]
                                                       │
                                              LockFreeRingBuffer
                                               (SPSC, 32768 frames)
                                                       │
                                              AVAudioSourceNode ──┐
                                                                   │
                                                                   ▼
                                                            AVAudioUnitEQ(10-band)
                                                                   │
                                                            mainMixerNode ──► [visualizer tap]
                                                                   │
                                                              outputNode ──► Speakers

LOCAL VIDEO (AVPlayer-native path -- does NOT enter the engine):
AVURLAsset ──► AVPlayerItem(audioMix) ──► AVPlayer ──► Speakers
                        │
                 MTAudioProcessingTap (PreEffects, in place)
                 preamp → 10-band biquad EQ → balance → VisualizerFeed
```

**Key insight:** Both audio-only paths converge at AVAudioEngine. The engine does not know or care whether PCM came from a local file or a decoded stream. EQ, visualizer tap, and balance all apply uniformly. The video path reaches the same user-facing result without the engine: `EqualizerController` and `AudioPlayer.balance` push their state into the tap, and the tap publishes to the same `VisualizerFeed`.

### Stream Decode Pipeline Components

The decode chain lives in `MacAmpApp/Audio/Streaming/` (plus `QueueConfined.swift`, the queue-confinement protocol):

**ICYFramer** (`ICYFramer.swift`) -- Pure `Sendable` struct. Strips ICY metadata from the HTTP byte stream before audio reaches the parser. Parses `icy-metaint` from HTTP response headers, counts audio bytes, and extracts metadata blocks at intervals. Emits `.audio(Data)` and `.metadata(ICYMetadata)` chunks. No shared state beyond counters.

**AudioFileStreamParser** (`AudioFileStreamParser.swift`) -- Wraps Apple's C-based `AudioFileStream` API. Accepts compressed audio chunks from ICYFramer, discovers the stream format (ASBD), extracts magic cookies (for AAC), and emits compressed packet batches. Decode-queue-confined with `dispatchPrecondition` assertions.

**AudioConverterDecoder** (`AudioConverterDecoder.swift`) -- Wraps Apple's `AudioConverter` API. Converts compressed packets (MP3/AAC) to Float32 interleaved stereo PCM at the detected source sample rate. `44.1 kHz` is common for MP3 streams, but it is not a hard-coded stream rate; the implementation only falls back to `44100` if the parser reports `0`. Manages its own packet queue with strict buffer lifetime contracts (input buffers remain valid until the next callback invocation). Decode-queue-confined.

**StreamDecodePipeline** (`StreamDecodePipeline.swift`) -- `@MainActor` orchestrator. Manages the URLSession data task, routes bytes through the decode chain, and publishes state changes to StreamPlayer via `@MainActor @Sendable` callbacks. Internally uses a `DecodeContext` (`@unchecked Sendable`, queue-confined) that owns all decode-queue state. A generation token prevents stale callbacks from previous streams.

### Threading Model

```
Main Thread (@MainActor)       Decode Queue (serial)        Audio IO Thread (RT)
├─ StreamDecodePipeline        ├─ DecodeContext              ├─ AVAudioSourceNode
│  ├─ start()/stop()/pause()   │  ├─ ICYFramer.consume()    │  render block
│  ├─ state callbacks          │  ├─ AudioFileStreamParser   │  ringBuffer.read()
│  └─ generation tracking      │  │  .parse()               │  (zero allocations)
│                              │  ├─ AudioConverterDecoder   │
├─ StreamPlayer                │  │  .decode()              └─ isSilence flag
│  ├─ observable state         │  └─ ringBuffer.write() ───►
│  └─ pipeline callbacks       │
│                              └─ SessionDelegateProxy
├─ PlaybackCoordinator             (URLSession delegate)
│  ├─ bridge lifecycle
│  └─ capability flags
│
└─ UI state updates
```

**Three isolation domains** with clean boundaries:
- **MainActor**: lifecycle, state, UI updates
- **Decode queue** (serial `DispatchQueue`): all data processing -- can allocate, not real-time
- **Audio IO thread**: render block only -- zero allocations, real-time-safe

Video playback adds a separate real-time domain, the `MTAudioProcessingTap` render thread owned by MediaToolbox (see [Audio Mechanism Concurrency Contract](#audio-mechanism-concurrency-contract)).

### The Orchestrator Pattern

`PlaybackCoordinator` is the single orchestrator for every source. It owns `AudioPlayer` (local files, video, the engine) and `StreamPlayer` (radio), guarantees only one backend plays at a time (`stopAllBackends()` deactivates the stream bridge and stops both players before any switch), and manages the stream bridge: when a stream's format is detected and prebuffering completes, `StreamPlayer.onFormatReady` activates the `AVAudioSourceNode` bridge in `AudioPlayer`; `onStreamTerminated` deactivates it.

```swift
// PlaybackCoordinator.swift (excerpt)
@MainActor
@Observable
final class PlaybackCoordinator {
    private let audioPlayer: AudioPlayer       // Local files (+ video) with EQ
    private let streamPlayer: StreamPlayer     // Internet radio

    // Derived from the active source, never stored
    var isPlaying: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPlaying
        case .radioStation: return streamPlayer.isPlaying && !streamPlayer.isBuffering
        case .none: return false
        }
    }

    var isPaused: Bool {
        switch currentSource {
        case .localTrack: return audioPlayer.isPaused
        case .radioStation:
            return !streamPlayer.isPlaying && !streamPlayer.isBuffering && streamPlayer.error == nil
        case .none: return false
        }
    }

    private(set) var currentSource: PlaybackSource?
    private(set) var currentTitle: String?
    private(set) var currentTrack: Track?  // For playlist position tracking

    enum PlaybackSource {
        case localTrack(URL)
        case radioStation(RadioStation)
    }

    // Stream in error state counts as inactive so controls re-enable
    private var isStreamBackendActive: Bool {
        guard case .radioStation = currentSource else { return false }
        return streamPlayer.error == nil
    }

    var supportsAudioProcessing: Bool { !isStreamBackendActive || audioPlayer.isBridgeActive }

    func togglePlayPause() {
        if isPlaying { pause() } else if isPaused { resume() }
    }

    func next() async {
        let action = audioPlayer.nextTrack(from: currentTrack, isManualSkip: true)
        await handlePlaylistAdvance(action: action)
    }
}
```

**Key behaviours:**

1. **Computed play state.** `isPlaying` / `isPaused` derive from the active backend, so they cannot drift during buffering stalls, error recovery or rapid toggling. A buffering stream reports `isPlaying == false`.
2. **Purpose-specific callbacks.** `AudioPlayer.onTrackMetadataUpdate` fires when a placeholder track gets its loaded metadata; `onPlaylistAdvanceRequest` fires on end-of-track auto-advance. Other wiring in `init`: `onPlaybackFinished` (clears source state and Now Playing), `StreamPlayer.onFormatReady` / `onStreamTerminated` (bridge lifecycle; `onFormatReady` also shares the audio IO workgroup with the decode thread), `onMetadataChanged` / `onStreamStateChanged` (Now Playing), `silenceGateForwarder`, and `AudioPlayer.onEngineReconfigured`.
3. **Context-aware navigation.** `next()` / `previous()` pass the coordinator's `currentTrack` to `audioPlayer.nextTrack(from:)` / `previousTrack(from:)`, so playlist position resolves even during stream playback, when `audioPlayer.currentTrack` is nil.
4. **Volume/balance routing.** `setVolume()` / `setBalance()` short-circuit same-value writes and write through to `AudioPlayer`, whose `didSet`s fan out to every backend; `commitVolume()` / `commitBalance()` persist on drag end. See [Volume & Balance Sliders](#volume--balance-sliders).
5. **Capability flag.** `supportsAudioProcessing` is `true` unless a stream is active, error-free and its bridge is not yet up, so the UI dims EQ and balance only during stream prebuffering. Video is not a stream source, so the flag is `true` and EQ/balance act on the video tap.
6. **Display title.** `displayTitle` shows "Connecting..." while a stream buffers, the stream's user-facing error message on failure, otherwise "station - ICY title"; for local tracks it prefixes the playlist position ("3. ").
7. **Remote commands.** The coordinator owns `MPRemoteCommandCenter` and Now Playing info for all sources.

### Integration with UI

Views read state from `AudioPlayer` and route writes through `PlaybackCoordinator`. The balance slider (`MainWindowSlidersLayer`) and the EQ sliders (`WinampEqualizerWindow`) dim to 50% opacity and disable hit testing when `supportsAudioProcessing` is false; the balance tooltip reads "Balance unavailable during streaming". `TrackInfoView` shows stream info when `playbackCoordinator.currentSource` is `.radioStation` and uses `playbackCoordinator.displayTitle` for live ICY metadata. The binding and dimming code is in [IMPLEMENTATION_PATTERNS.md → Asymmetric Binding](IMPLEMENTATION_PATTERNS.md#pattern-asymmetric-binding-for-coordinator-routing) and [Capability Flag Pattern](IMPLEMENTATION_PATTERNS.md#pattern-capability-flag-pattern).

### Critical Implementation Details

1. **Exclusive playback:** every source switch goes through `stopAllBackends()` (deactivate stream bridge, stop `AudioPlayer`, stop `StreamPlayer`).
2. **Different state machines:** `AudioPlayer` state changes synchronously on `play()`; `StreamPlayer.play(...)` is `async` and reports buffering first.
3. **Stateful objects are `@State`, never computed properties** (see [Pitfall 1](#pitfall-1-state-object-lifecycle)).

### Output Route Changes (Engine Reconfiguration)

Switching the output device (Control Center, AirPlay, HDMI hot-plug, sleep/wake) stops AVAudioEngine and posts `AVAudioEngineConfigurationChange`, often 2-3 times within 100 ms. `AudioEngineConfigurationObserver` (`@MainActor`, owned by `AudioEngineController`) collapses each burst into one will/did pair:

```
notification burst ──► onWillReconfigure (first notification)
                          AudioEngineController → PreReconfigureSnapshot → AudioPlayer
                          AudioPlayer (audio media only): record isPlaying/isPaused/currentTime,
                            bump currentSeekID, arm seek guards
                   ──► 150 ms quiet window
                   ──► onDidReconfigure
                          AudioEngineController: reconnect stream bridge at the new output rate,
                            verify mixer → output, prepare + restart engine
                          AudioPlayer: re-apply volume/balance; when audio is the current media,
                            reschedule the local file from the saved time (resume if it was playing,
                            show paused if it was paused, leave stopped as is); release guards
                          PlaybackCoordinator (onEngineReconfigured): re-share the audio IO
                            workgroup with the stream decode thread if the bridge is active
```

`AudioPlayer` overrides the engine's `wasPlaying`/`currentTime` with its own state because the engine has already stopped when the notification arrives. `did` is not guaranteed after `will` if the observer is stopped mid-burst, so the user-intent entry points (`play`, `stop`, `seek`, `playTrack`) call `cancelPendingReconfigure()` to drop the snapshot and clear the guards. `pause` instead rewrites the pending snapshot to paused: the engine has already auto-stopped, so dropping the snapshot would leave the UI playing over silence. The will-handler ignores video media: after audio → video the previous track's file stays loaded and `isPlaying` is true, so a format change during video would otherwise resume the old track under the video, and the armed guards would swallow the video's end-of-item callback. AVPlayer handles its own route changes, and the video tap's pinned processing format keeps its DSP independent of the output device. Only output **format** changes (sample rate / channel count) post the configuration notification; switching between two outputs with the same format does not. The debounce code: [Debounced Will/Did Notification Bursts](IMPLEMENTATION_PATTERNS.md#pattern-debounced-willdid-notification-bursts).

---

## AudioPlayer Decomposition Architecture

`AudioPlayer` was once a single 1,805-line class that owned the engine, playback state, EQ and presets, the playlist, video and the visualizer. It has been split into focused `@MainActor` components while keeping its public API (views still talk only to `AudioPlayer`).

### Decomposed Architecture

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
│  │  • importEqfPreset()       │  │  @concurrent N/A      │                   │
│  │  (owned by EqualizerController) │                       │                   │
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
│  │  • repeatMode         │  │  • loadVideo() async   │                  │
│  │  • nextTrack() → Action│ │  • cleanup()           │                  │
│  │  • previousTrack()    │  │  • onPlaybackEnded     │                  │
│  └───────────────────────┘  └───────────────────────┘                   │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      VisualizerPipeline                            │  │
│  │                      ──────────────────                            │  │
│  │                      @MainActor @Observable                        │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │  • feed: VisualizerFeed (VisualizerFeed.swift, SPSC, 2 producers) │  │
│  │  • VisualizerScratchBuffers (own file, one instance per producer) │  │
│  │  • ButterchurnFrame (struct, Sendable)                            │  │
│  │  • installTap() / removeTap() - engine mixer tap                  │  │
│  │  • start/stopVideoVisualization() - poll timer for video          │  │
│  │  • makeTapHandler() - static, Sendable closure (feed publish)     │  │
│  │  • pollTimer (30 Hz, .common) - consumes feed, fires onPollTick   │  │
│  │  • getRMSData() / getWaveformSamples() / snapshotButterchurnFrame │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                  AudioEngineController (Engine Graph)              │  │
│  │                  ──────────────────────────────────                │  │
│  │                  @MainActor                                        │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │  • audioEngine, playerNode, eqNode, streamSourceNode              │  │
│  │  • setupEngine(), rewireForFile(_:) (explicit graph format)       │  │
│  │  • activateStreamBridge() / deactivateStreamBridge()              │  │
│  │  • startEngineIfNeeded(), scheduleFrom(), seek, eject             │  │
│  │  • audioFile, progressTimer, visualizer tap install/remove        │  │
│  │  • isBridgeActive flag for capability checks                      │  │
│  │  • configObserver: AudioEngineConfigurationObserver (route chg)   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AudioPlayer (Facade)                            │  │
│  │                    ───────────────────                             │  │
│  │                    @MainActor @Observable                          │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │                                                                    │  │
│  │  Playback Control:                                                 │  │
│  │  ─────────────────────────────────────────────                     │  │
│  │  • play(), pause(), stop(), eject()                                │  │
│  │  • seekToPercent(), seek()                                         │  │
│  │  • playbackState, isPlaying, isPaused                              │  │
│  │  • currentSeekID, seekGuardActive, isHandlingCompletion            │  │
│  │                                                                    │  │
│  │  Video Tap Orchestration:                                          │  │
│  │  ─────────────────────────────────────────────                     │  │
│  │  • startVideoLoad() + videoLoadGeneration (stale-load guard)       │  │
│  │  • audioMixBuilder closure → VideoTap.buildAudioMix()              │  │
│  │  • pauseAndDetachVideoTapIfNeeded()                                │  │
│  │  • balance registry: [WeakBox<VideoTapContext>]                    │  │
│  │  • isVisualizerRendering (engine OR playing video)                 │  │
│  │                                                                    │  │
│  │  Component References:                                             │  │
│  │  ─────────────────────                                             │  │
│  │  • engine: AudioEngineController                                   │  │
│  │  • equalizer: EqualizerController (owns EQPresetStore)             │  │
│  │  • playlistController: PlaylistController                          │  │
│  │  • videoPlaybackController: VideoPlaybackController                │  │
│  │  • visualizerPipeline: VisualizerPipeline                          │  │
│  │                                                                    │  │
│  │  Computed Forwarding (maintains existing bindings):                │  │
│  │  ─────────────────────────────────────────────────                 │  │
│  │  var userPresets: [EQPreset] { equalizer.userPresets }             │  │
│  │  var playlist: [Track] { playlistController.playlist }             │  │
│  │  var videoPlayer: AVPlayer? { videoPlaybackController.player }     │  │
│  │  isBridgeActive (stored; set by engine.onBridgeStateChanged)      │  │
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
│  • MainWindow/ (10 files) → playbackCoordinator + audioPlayer state      │
│  • WinampEqualizerWindow → audioPlayer.eqBands, audioPlayer.preamp       │
│  • PlaylistWindow/ (7 files) → audioPlayer.playlist                      │
│  • VisualizerView        → audioPlayer.getFrequencyData(bands:)          │
│  • VideoWindowChromeView → audioPlayer.videoMetadataString               │
│                                                                          │
│  LAYER BOUNDARY: Views never import or access:                           │
│     EQPresetStore, PlaylistController, VisualizerPipeline, etc.          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Specifications

#### EQPresetStore (`MacAmpApp/Audio/EQPresetStore.swift`)

**Layer:** Mechanism
**Purpose:** Manages persistence of EQ presets (user presets and per-track presets). Owned by `EqualizerController`.

```swift
@MainActor
@Observable
final class EQPresetStore {
    private(set) var userPresets: [EQPreset] = []                  // UserDefaults "MacAmp.UserEQPresets.v1"
    @ObservationIgnored var perTrackPresets: [String: EqfPreset] = [:]  // perTrackPresets.json

    func storeUserPreset(_ preset: EQPreset)
    func preset(forTrackURL urlString: String) -> EqfPreset?
    func savePreset(_ preset: EqfPreset, forTrackURL urlString: String)
    func savePerTrackPresets()                                    // serialized, off-main write
    func importEqfPreset(from url: URL) async -> EQPreset?
}
```

**Key Patterns:**
- File I/O in `@concurrent` static functions (`loadPresetsFromDisk`, `savePresetsToDisk`, `parseEqfFile`); code in [Background I/O with @concurrent](IMPLEMENTATION_PATTERNS.md#pattern-background-io-with-concurrent-static-functions-swift-62)
- Saves capture a snapshot and chain on the previous save task, so writes land in order
- `loadPerTrackPresets()` merges loaded data under in-memory changes made during the load
- `EQPreset` and `EqfPreset` are `Sendable`

#### MetadataLoader (`MacAmpApp/Audio/MetadataLoader.swift`)

**Layer:** Mechanism (pure utility)
**Purpose:** Async extraction of audio/video metadata from media files

```swift
struct MetadataLoader {
    // Result Types
    struct TrackMetadata { let title: String; let artist: String; let duration: TimeInterval }
    struct AudioProperties { let channelCount: Int; let bitrate: Int; let sampleRate: Int }
    struct VideoMetadata { let filename: String; let videoType: String; let width: Int; let height: Int }

    // Static async methods (@concurrent not needed: methods await immediately)
    static func loadTrackMetadata(from url: URL) async -> TrackMetadata
    static func loadAudioProperties(from url: URL) async -> AudioProperties?
    static func loadVideoMetadata(from url: URL) async -> VideoMetadata
}
```

**Key Patterns:**
- `nonisolated struct` with static methods (no shared state)
- `@concurrent` not needed: methods `await` immediately (`AVAsset.load`), no blocking I/O before suspension
- Graceful fallbacks for missing metadata

#### PlaylistController (`MacAmpApp/Audio/PlaylistController.swift`)

**Layer:** Mechanism
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
**Purpose:** AVPlayer lifecycle, audio-mix installation and observer management for video playback

```swift
@MainActor
@Observable
final class VideoPlaybackController {
    // AVPlayer State — observed: WinampVideoWindow swaps the placeholder for the
    // player when the async load assigns it
    private(set) var player: AVPlayer?
    private(set) var metadataString: String = ""

    // Observer Management
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var timeObserver: Any?

    // Callbacks for cross-component sync
    var onPlaybackEnded: (() -> Void)?
    var onTimeUpdate: ((Double, Double, Double) -> Void)?

    // Lifecycle
    func loadVideo(
        url: URL,
        autoPlay: Bool = true,
        audioMixBuilder: ((AVURLAsset) async -> AVMutableAudioMix?)? = nil,
        isStillRelevant: (() -> Bool)? = nil
    ) async
    func cleanup()  // State reset and observer cleanup

    isolated deinit {
        // isolated deinit runs on @MainActor -- safe to access all properties directly
        metadataTask?.cancel()
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player?.pause()
    }
}
```

**Key Patterns:**
- **audioMix at item construction:** `cleanup()` → `AVURLAsset` → `await audioMixBuilder(asset)` → `isStillRelevant()` check → `AVPlayerItem(asset:)` → `playerItem.audioMix = mix` → `AVPlayer(playerItem:)`. The player never sees an item without its mix, and a superseded load returns before any player, observer or state is touched (the built mix is dropped, which finalizes its tap)
- Identity guards: the end-of-item, periodic-time and seek completions ignore callbacks from a player/item that a newer load has replaced
- `seek(to:resume:)` with `resume: nil` preserves current intent: a loaded-but-never-started video stays idle rather than becoming "paused"
- Callback pattern for AudioPlayer synchronization (`onTimeUpdate` for UI sync)
- `metadataTask` cancelled in both cleanup() and isolated deinit to prevent race conditions
- State reset in cleanup() prevents stale values after stop
- `isolated deinit` (Swift 6.2) runs on `@MainActor` and cleans up observers and the player directly

#### VisualizerPipeline (`MacAmpApp/Audio/VisualizerPipeline.swift`)

**Layer:** Mechanism
**Purpose:** Engine visualizer tap, consumption of the shared visualizer feed, and Butterchurn data

```swift
@MainActor
@Observable
final class VisualizerPipeline {
    // Tap State
    @ObservationIgnored private var tapInstalled = false
    @ObservationIgnored private weak var mixerNode: AVAudioMixerNode?
    @ObservationIgnored private let feed = VisualizerFeed()
    @ObservationIgnored private var pollTimer: Timer?

    /// Fired on every 30 Hz poll tick; AudioPlayer uses it to poll video-tap sample rates
    @ObservationIgnored var onPollTick: (@MainActor () -> Void)?
    /// Handed to each VideoTapContext so the video tap publishes to the same feed
    var sharedFeed: VisualizerFeed { feed }

    // Cached AppSettings flag to avoid per-frame lookup
    var useSpectrum: Bool = true

    // Engine tap (local files + streams)
    func installTap(on mixer: AVAudioMixerNode)
    func removeTap()
    // Video: no engine tap, so the poll timer is started/stopped explicitly
    func startVideoVisualization()
    func stopVideoVisualization()   // also clears stale data

    // Static Tap Handler Factory (publishes to the feed)
    private nonisolated static func makeTapHandler(
        feed: VisualizerFeed,
        scratch: VisualizerScratchBuffers
    ) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void
}

// VisualizerFeed.swift — single-slot SPSC hand-off, two producers (engine tap, video tap)
final class VisualizerFeed: @unchecked Sendable {
    func tryPublish(from: VisualizerScratchBuffers, ...) -> Bool  // Render thread (non-blocking trylock)
    func consume() -> VisualizerData?                              // Main thread (blocking lock)
}

// VisualizerScratchBuffers.swift — one instance per producer, render-confined
final class VisualizerScratchBuffers: @unchecked Sendable { ... }

// Supporting Types (all Sendable)
struct ButterchurnFrame: Sendable { let spectrum: [Float]; let waveform: [Float]; let timestamp: TimeInterval }
struct VisualizerData: Sendable { let rms: [Float]; let spectrum: [Float]; let waveform: [Float]; ... }
```

**Key Patterns:**
- **`VisualizerFeed`** (`VisualizerFeed.swift`) carries audio-to-main data with zero allocations on the render thread. Uses `os_unfair_lock` with `trylock` on the producer side (non-blocking, drops frame on contention) and a regular lock on the main thread. A generation counter avoids redundant consumption. Last write wins; only one producer is active at a time (engine tap for audio, video tap for video). See [SPSC Shared Buffer](IMPLEMENTATION_PATTERNS.md#pattern-spsc-shared-buffer-for-audio-to-main-thread-transfer).
- **30 Hz poll timer** (`.common` run-loop mode) on the main thread calls `feed.consume()`; it runs while the engine tap is installed or between `startVideoVisualization()` and `stopVideoVisualization()`
- Pre-allocated FFT buffers in `VisualizerScratchBuffers.init()` (no render-thread allocations)
- Pre-computed Goertzel coefficients (recomputed only on sample rate change, not per-callback)
- `useSpectrum` cached to avoid per-frame AppSettings lookup
- `isolated deinit` invalidates the poll timer as a backstop; normal teardown goes through `removeTap()`
- **20-bar RMS** (not 19) per time bucket for spectrum visualization

### Migration Notes

`AudioPlayer` keeps a stable API through computed forwarding properties (`playlist`, `userPresets`, `videoPlayer`, `videoMetadataString`, `shuffleEnabled`, `repeatMode`, EQ and visualizer settings); see [Computed Forwarding](IMPLEMENTATION_PATTERNS.md#pattern-computed-forwarding-for-api-compatibility). Playlist navigation returns a `PlaylistController.AdvanceAction` that `AudioPlayer.handlePlaylistAction(_:)` executes; see [Action-Based Bridge](IMPLEMENTATION_PATTERNS.md#pattern-action-based-bridge-pattern). The full file layout is in [Quick Reference](#key-files--their-purposes).

### Swift 6 Concurrency Compliance

Types that cross isolation boundaries. The `@unchecked Sendable` rows follow the [Audio Mechanism Concurrency Contract](#audio-mechanism-concurrency-contract):

| Type | Conformance | Notes |
|------|-------------|-------|
| `Track` | `Sendable` | Value type, all properties Sendable |
| `PlaybackState` | `Sendable` | Enum with Sendable associated values |
| `PlaybackStopReason` | `Sendable` | Simple enum |
| `EQPreset` | `Sendable` | Value type |
| `EqfPreset` | `Sendable` | Value type |
| `ButterchurnFrame` | `Sendable` | Value type with [Float] arrays |
| `VisualizerData` | `Sendable` | Container struct |
| `VisualizerScratchBuffers` | `@unchecked Sendable` | One instance per producer, confined to that producer's render thread |
| `VisualizerFeed` | `@unchecked Sendable` | SPSC single-slot hand-off (os_unfair_lock, trylock on producer side) |
| `VideoTapContext` | `@unchecked Sendable` | FFI boundary; every stored field is `Atomic`, `Mutex`, `let` or `RenderThreadSafe` |
| `BiquadCoefs` / `BiquadCoefficientSet` | `Sendable` | Flat value types, copied under `withLockIfAvailable` |
| `BiquadCascade` | `RenderThreadSafe` (not `Sendable`) | Render-confined: created on main, then touched only in `tapProcess` |
| `EqualizerState` | `Sendable` | Main-thread snapshot fed to `BiquadCoefficientSet.compute` |
| `VideoTapDiagnostics` | `Sendable` | Telemetry snapshot read on main |
| `PreReconfigureSnapshot` | `Sendable` | Engine route-change snapshot |

Preset persistence runs off the main actor through `@concurrent` static functions with serialized saves; see [Background I/O with @concurrent](IMPLEMENTATION_PATTERNS.md#pattern-background-io-with-concurrent-static-functions-swift-62).

### Risk Mitigation

**VisualizerPipeline - VisualizerFeed Safety:**
- `AudioEngineController.shutdown()` (from AudioPlayer's `isolated deinit`) calls `visualizerPipeline.removeTap()`
- Producers (engine tap, video tap) use `os_unfair_lock_trylock` (non-blocking; drop frame on contention)
- Main thread uses `os_unfair_lock_lock` (safe to block briefly on 30 Hz timer)
- Generation counter prevents redundant consumption of unchanged data
- Poll timer invalidated in `removeTap()` / `stopVideoVisualization()` to prevent stale callbacks; video completion, stop and video→audio switches all stop it

**VideoPlaybackController - Observer Cleanup:**
- `cleanup()` removes observers and resets state (called during stop/eject)
- `isolated deinit` repeats the observer teardown as a backstop, directly on `@MainActor`

**EQPresetStore - Race Condition Prevention:**
- `loadPerTrackPresets()` merges loaded data with in-memory changes
- Saves capture a state snapshot before dispatch

---

## Skin System Complete Architecture

The skin system loads Winamp 2.x `.wsz` skins and resolves UI elements to sprites through semantic identifiers. Detail: [SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md) (sprite catalog, resolver rules) and [WINAMP_SKIN_VARIATIONS.md](WINAMP_SKIN_VARIATIONS.md) (format quirks).

### Skin Loading Pipeline

```
.wsz file (ZIP archive)
         │
         ▼
SkinArchiveLoader.loadAsync (@concurrent, off the main actor)
  - extracts the expected BMP sheets (SkinSprites.defaultSprites + NUMS_EX) and text files
         │
         ▼
SkinManager.applySkinPayload (@MainActor)
  - crops every sprite from its sheet (ImageSlicing, autoreleasepool per crop)
  - sheets the skin lacks → sprites extracted lazily from the bundled default skin
  - VISCOLOR.TXT → VisColorParser, PLEDIT.TXT → PLEditParser
         │
         ▼
Skin (images, visualizerColors, playlistStyle, cursors, loadedSheets)
         │
         ▼
Views: SimpleSpriteImage(name or SemanticSprite) → SpriteResolver → skin.images[name]
```

**Memory behaviour:**
- The bundled default skin is kept only as its ZIP payload (~200 KB). It is parsed in full only when it is the selected skin (`loadInitialSkin` parses the already-loaded payload instead of re-extracting it).
- For a custom skin missing a sheet, `fallbackSpritesFromDefaultSkin` extracts only that sheet from the default payload and caches the sprites in `defaultSkinSpriteCache`.
- At rest, memory holds the current skin's sprites plus that payload and the partial fallback cache.
- `NSImage.cropped(to:)` (`Models/ImageSlicing.swift`) draws each crop into its own sRGB RGBA8 `CGContext` and wraps `context.makeImage()`, so a sprite owns only its own pixels instead of retaining the parent sheet's buffer.

### Semantic Sprite Mapping

Views request sprites by meaning, not by skin-specific name:

```swift
SimpleSpriteImage(.digit(0), width: 9, height: 13)         // semantic
SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18) // legacy name (still supported)
```

`SpriteResolver` (a `Sendable` struct over a `Skin`) maps a `SemanticSprite` to the first candidate name that exists in `skin.images`:

```swift
func resolve(_ semantic: SemanticSprite) -> String? {
    for candidate in candidates(for: semantic) where skin.images[candidate] != nil {
        return candidate
    }
    return nil  // caller handles fallback
}
```

Candidate priority: `_EX` variants before standard sprites, then `_SELECTED` over `_ACTIVE` over the base name. When nothing resolves, `SimpleSpriteImage` draws a purple placeholder with a "?" at the requested size.

### Hot Skin Swapping

`SkinManager` is `@MainActor @Observable`; swapping `currentSkin` re-renders every view that reads it, with no restart.

- `switchToSkin(identifier:)` looks the skin up in `availableSkins`, calls `loadSkin(from:)` and saves `AppSettings.selectedSkinIdentifier`.
- `loadSkin(from:)` sets `isLoading`, stamps a new `loadGeneration` UUID, loads the archive off the main actor, and applies the payload only if the generation is still current (a newer load wins; `CancellationError` is ignored).
- On failure it sets `loadingError` (`describeLoadError`) and keeps the current skin.

---

## State Management Evolution

All app state uses the `@Observable` macro with `@MainActor` isolation under Swift 6 strict concurrency. The migration from `ObservableObject` + `@Published` is complete. The how-to lives in [IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md): [@Observable with @MainActor](IMPLEMENTATION_PATTERNS.md#pattern-observable-with-mainactor), [Migrating from ObservableObject](IMPLEMENTATION_PATTERNS.md#migrating-from-observableobject-to-observable), [Enum State with Persistence](IMPLEMENTATION_PATTERNS.md#pattern-enum-state-with-persistence-repeatmode-pattern).

**Conventions:**
- `@ObservationIgnored` for non-UI storage (timers, tasks, registries, caches).
- The owning class persists its own settings in `didSet` → `UserDefaults` (`AppSettings`). Slider-driven values (volume, balance) are the exception: they persist once at drag end.
- Settings enums (`RepeatMode`, `TimeDisplayMode`, `VisualizerMode`) live in `AppSettings`. `AudioPlayer.repeatMode` forwards to `AppSettings.instance().repeatMode`. Loading `RepeatMode` migrates the old `audioPlayerRepeatEnabled` Bool (`true` → `.all`, `false` → `.off`).
- View-local interaction state is one `@Observable` class owned via `@State` (for example `WinampMainWindowInteractionState`), not scattered `@State` vars.
- Off-main work goes through `@concurrent` static functions or queue-confined types, never through mutable state shared with the main actor (see [Modern Swift 6.2 Patterns](#modern-swift-62-patterns)).

### Environment Injection Pattern

`MacAmpApp.init()` creates the shared instances once, stores them in `@State`, and hands them to `WindowCoordinator`. The Winamp windows are AppKit `NSWindow`s, so each window controller injects the environment into its `NSHostingController` root view:

```swift
// MacAmpApp.swift (excerpt)
init() {
    let skinManager = SkinManager()
    let audioPlayer = AudioPlayer()
    let dockingController = DockingController()
    let settings = AppSettings.instance()
    let radioLibrary = RadioStationLibrary()
    let streamPlayer = StreamPlayer()
    let playbackCoordinator = PlaybackCoordinator(audioPlayer: audioPlayer, streamPlayer: streamPlayer)
    // ... _x = State(initialValue: x) for each, skinManager.loadInitialSkin(), WindowFocusState() ...
    let coordinator = WindowCoordinator(skinManager: skinManager, audioPlayer: audioPlayer, /* ... */)
    WindowCoordinator.shared = coordinator
    dockingController.windowCoordinator = coordinator
}

// WinampVideoWindowController.swift (the other window controllers follow the same shape)
let rootView = WinampVideoWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(dockingController)
    .environment(settings)
    .environment(radioLibrary)
    .environment(playbackCoordinator)
    .environment(windowFocusState)
window.contentViewController = NSHostingController(rootView: rootView)  // never set contentView
```

The SwiftUI `body` only declares a hidden placeholder `WindowGroup`, a Preferences window and the menu commands (`AppCommands`, `SkinsCommands`). Child views read what they need with `@Environment(Type.self)`.

---

## Window Focus State Management

`WindowFocusState` tracks which MacAmp window is key so titlebars and chrome can switch between active and inactive sprites. It sits in the bridge layer: AppKit focus events come in through `WindowFocusDelegate`, views read the state. Full detail: [WINDOW_FOCUS_ARCHITECTURE.md](WINDOW_FOCUS_ARCHITECTURE.md).

```swift
// MacAmpApp/Models/WindowFocusState.swift
@Observable
@MainActor
final class WindowFocusState {
    var isMainKey: Bool = true       // Main window starts focused
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false

    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey || isVideoKey || isMilkdropKey
    }
}
```

- **Delegate:** `WindowFocusDelegate` (`Utilities/WindowFocusDelegate.swift`) sets all five flags in `windowDidBecomeKey` (only its own kind `true`, so exactly one window is key) and clears its own flag in `windowDidResignKey`.
- **Wiring:** `WindowDelegateWiring.wire(...)` creates one `WindowFocusDelegate` per window and adds it to that window's `WindowDelegateMultiplexer` next to `WindowSnapManager.shared` and the persistence delegate. It never replaces `window.delegate` with the focus delegate alone.
- **Views:** read a computed property, never a cached `@State` copy, e.g. `private var isWindowActive: Bool { windowFocusState.isMainKey }` selects `MAIN_TITLE_BAR_SELECTED` vs `MAIN_TITLE_BAR`.

---

## Five-Window NSWindowController Stack

MacAmp runs five windows (Main, Equalizer, Playlist, Video, Milkdrop), each an AppKit `NSWindowController` hosting SwiftUI. Full detail: [MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md).

### Window Controller Architecture

`WindowCoordinator` is a facade over focused collaborators ([WindowCoordinator Architecture](MULTI_WINDOW_ARCHITECTURE.md#windowcoordinator-architecture)):

```
┌─────────────────────────────────────────────────────────────┐
│              WindowCoordinator (Facade)                      │
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
│                      WindowRegistry                          │
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
│              WindowDelegateWiring                            │
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

### Window Lifecycle Management

```swift
// WindowCoordinator.swift - Facade pattern
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

**WindowRegistry.swift - Window ownership:**
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

**WindowDelegateWiring.swift - Static factory:**
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
// MacAmpApp/Utilities/WindowSnapManager.swift
enum WindowKind: Hashable {
    case main
    case playlist
    case equalizer
    case video
    case milkdrop
}
```

Cluster detection across all five windows is the snap manager's `connectedCluster` (see [Window Snap Manager](#window-snap-manager)); `WindowSnapManager.clusterKinds(containing:)` exposes it as a `Set<WindowKind>`.

### Key Implementation Points

1. **Controller Lifecycle**: All 5 controllers created at app launch, windows shown/hidden as needed
2. **Delegate Multiplexing**: Each window combines focus, persistence, and snap delegates
3. **Memory Management**: Controllers and multiplexers stored as properties (prevent deallocation)
4. **UserDefaults Keys**: Each window has visibility and frame persistence keys
5. **Keyboard Shortcuts**: Ctrl+V (video), Ctrl+K (milkdrop) for window toggling

---

## SwiftUI Rendering Techniques

Pixel-perfect Winamp rendering overrides SwiftUI's automatic layout. The code patterns are in [IMPLEMENTATION_PATTERNS.md → UI Component Patterns](IMPLEMENTATION_PATTERNS.md#ui-component-patterns).

### Absolute Positioning

Every element sits at an exact top-left pixel offset from `WinampMainWindowLayout` (or the equivalent per-window layout enum):

```swift
// MacAmpApp/Views/Components/SimpleSpriteImage.swift
extension View {
    func at(x: CGFloat, y: CGFloat) -> some View { self.offset(x: x, y: y) }
    func at(_ point: CGPoint) -> some View { self.offset(x: point.x, y: point.y) }
}
```

### Pixel-Perfect Image Rendering

`SimpleSpriteImage` draws `Image(nsImage:)` with `.interpolation(.none)`, `.antialiased(false)`, `.resizable()`, `.aspectRatio(contentMode: .fill)`, an explicit frame and `.clipped()`, so sprites stay crisp at 1x and in double-size mode. Double size is a `.scaleEffect(2, anchor: .topLeading)` on the main and EQ window roots, with `WindowResizeController.resizeMainAndEQWindows(doubled:)` resizing the NSWindows.

### Z-Layer Background Masking and Child-View Recomposition Boundaries

The main window root (`MainWindow/WinampMainWindow.swift`) stacks a static background sprite, the titlebar, and either `MainWindowFullLayer` or `MainWindowShadeLayer` in a `ZStack(alignment: .topLeading)` at a fixed 275×116 size. `MainWindowFullLayer` assembles the child layers (indicators, time display, track info, visualizer, transport, shuffle/repeat, sliders, window toggles, clutter bar).

Each child layer is its own `View` struct that reads only the `@Environment` values it needs, so SwiftUI re-evaluates only the affected layer: the transport layer re-evaluates only when `PlaybackCoordinator` changes; the sliders layer only when `AudioPlayer` volume/balance or scrubbing state changes. How to build one: [View Layer Decomposition (MainWindow)](IMPLEMENTATION_PATTERNS.md#pattern-view-layer-decomposition-mainwindow).

### Buttons and Hit Testing

Skinned buttons are plain SwiftUI `Button`s wrapping a `SimpleSpriteImage`, styled `.buttonStyle(.plain)` and `.focusable(false)`, positioned with `.at(...)`. Selected/active states swap the sprite name (for example `MAIN_CLUTTER_BAR_BUTTON_D` / `_SELECTED`). `SimpleSpriteImage` itself has no action or pressed state.

---

## Audio Processing Pipeline

MacAmp's audio processing uses AVAudioEngine for real-time processing, with visualization in the `VisualizerPipeline` component. This section covers the engine path (local audio files and streams); video audio is processed by the tap described in [AVPlayer-Native Video DSP](#avplayer-native-video-dsp), which feeds the same visualizer consumer.

### AVAudioEngine Graph (Unified Pipeline)

```
┌────────────────────────────────────────────────────────────────┐
│                      AVAudioEngine Graph                        │
│                 (owned by AudioEngineController)                │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  LOCAL FILES:                  STREAMS:                          │
│  AVAudioFile ──┐               LockFreeRingBuffer ──┐           │
│                ▼                                     ▼           │
│        AVAudioPlayerNode              AVAudioSourceNode          │
│                │                             │                   │
│                └──────────┬──────────────────┘                   │
│                           ▼                                      │
│                   AVAudioUnitEQ (10-band)                        │
│                           │                                      │
│                           ▼                                      │
│                   AVAudioMixerNode (main)                        │
│                           │                                      │
│                     ┌─────┴─────┐                                │
│                     ▼           ▼                                │
│               [Audio Tap]  OutputNode                            │
│                     │                                            │
│                     ▼                                            │
│               VisualizerPipeline                                 │
│               • 2048-sample buffer (Butterchurn FFT)             │
│               • Goertzel-like DFT (20 frequency bars)            │
│               • RMS calculation per time bucket (20 bars)        │
│               • Waveform downsampling (76 samples)               │
│                                                                  │
│  Only ONE input path is active at a time.                        │
│  Bridge lifecycle: PlaybackCoordinator activates/deactivates     │
│  the AVAudioSourceNode path based on playback source.            │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

### Visualizer Pipeline Architecture

Visualizer tap processing lives in `VisualizerPipeline.swift` (engine tap) and `VideoTapVisualizerRender.swift` (video tap):

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
│  │  6. Publish to VisualizerFeed (non-blocking)                         │  │
│  │     └─ feed.tryPublish() — drops frame on contention                  │  │
│  │     └─ Zero allocations on audio thread                               │  │
│  │                                                                      │  │
│  │  (Video: videoTapVisualizerRender runs steps 1-6 on the              │  │
│  │   MTAudioProcessingTap render thread and publishes to the same feed) │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │              30 Hz Poll Timer (Main Thread)                          │  │
│  ├─────────────────────────────────────────────────────────────────────┤  │
│  │  onPollTick?() → video-tap sample-rate poll (EQ fanout)             │  │
│  │  feed.consume() → VisualizerData?                                   │  │
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
│   Audio File / Stream                 Video File (AVPlayer)               │
│        │                                   │                              │
│        ▼                                   ▼                              │
│   AVAudioEngine mixer tap          MTAudioProcessingTap (post-EQ)         │
│   makeTapHandler                   videoTapVisualizerRender               │
│        │   Mono downmix + RMS + Goertzel + 2048-pt vDSP FFT               │
│        └──────────────┬────────────────────┘                              │
│                       ▼                                                   │
│   VisualizerFeed (one producer active at a time) ─▶ 30 Hz feed.consume()  │
│        │                                                                  │
│        ▼                                                                  │
│   VisualizerPipeline.swift                                                │
│   ├── @ObservationIgnored butterchurnSpectrum[1024]                       │
│   ├── @ObservationIgnored butterchurnWaveform[1024]                       │
│   └── snapshotButterchurnFrame() → ButterchurnFrame                       │
│        │                                                                  │
│        ▼ (called by AudioPlayer)                                          │
│   AudioPlayer.snapshotButterchurnFrame()                                  │
│   └── nil unless isVisualizerRendering (engine rendering OR video playing)│
│        │                                                                  │
│        ▼ (30 FPS async Task loop)                                         │
│   ButterchurnBridge.swift                                                 │
│   └── callAsyncJavaScript("…setAudioData(spectrum, waveform)")            │
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

To avoid allocations on the realtime audio thread, `VisualizerScratchBuffers` pre-allocates all FFT working buffers (its `@unchecked Sendable` follows the [Audio Mechanism Concurrency Contract](#audio-mechanism-concurrency-contract)). Each producer owns one instance: the engine tap creates one in `installTap`, and every `VideoTapContext` creates its own. Instances are never shared across taps.

```swift
// VisualizerScratchBuffers.swift
final class VisualizerScratchBuffers: @unchecked Sendable {
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

The 10-band parametric EQ lives in `EqualizerController.swift`, which owns the `AVAudioUnitEQ` node; `AudioPlayer` forwards its EQ properties to it:

```swift
// EqualizerController.swift
// AudioPlayer holds: private let equalizer = EqualizerController()
// AudioPlayer forwards: var isEqOn { equalizer.isEqOn }

private func configureEQ() {
    // Actual Winamp internal frequencies (skin labels show 60/170/310 but processing uses 70/180/320)
    // Tight 12k/14k/16k clustering is intentional — designed for MP3 artifact tuning
    // Shared with the video-tap cascade so the two EQ implementations cannot drift:
    // [70, 180, 320, 600, 1000, 3000, 6000, 12000, 14000, 16000]
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
        band.bandwidth = 1.0
        band.gain = eqBands[i]
        band.bypass = false
    }
    eqNode.globalGain = preamp
    eqNode.bypass = !isEqOn
}
```

`EqualizerController` stays the single owner of EQ state for both playback paths. The `preamp`, `eqBands` and `isEqOn` `didSet` handlers write the engine `AVAudioUnitEQ` and then fan the same state out to any registered video taps, where a software `BiquadCascade` reproduces this configuration (see [EQ and Balance Fanout](#eq-and-balance-fanout)).

### EQ Preset Persistence

`EQPresetStore` (owned by `EqualizerController`) keeps user presets in `UserDefaults` (`MacAmp.UserEQPresets.v1`) and per-track presets in `perTrackPresets.json` in Application Support. The JSON is read and written off the main actor with serialized saves; see [Background I/O with @concurrent](IMPLEMENTATION_PATTERNS.md#pattern-background-io-with-concurrent-static-functions-swift-62).

### Repeat Mode Implementation (PlaylistController)

`PlaylistController.nextTrack(isManualSkip:)` returns an `AdvanceAction`; it never starts playback itself:

- **Repeat-one**, automatic advance only: `.restartCurrent` for a local track, `.requestCoordinatorPlayback(track)` for a stream. A manual skip ignores repeat-one.
- **Shuffle:** a random playlist entry.
- **Sequential:** the next index; at the end, repeat-all wraps to index 0, otherwise `.endOfPlaylist`.
- Streams always come back as `.requestCoordinatorPlayback` so `PlaybackCoordinator` routes them to `StreamPlayer`.

`AudioPlayer.handlePlaylistAction(_:)` executes the action. `.restartCurrent` seeks to 0 with `resume: true` and, for video, re-arms the video visualizer poll timer that completion stopped. Code: [Action-Based Bridge Pattern](IMPLEMENTATION_PATTERNS.md#pattern-action-based-bridge-pattern).

### Spectrum Analyzer (20-bar Goertzel Implementation)

```swift
// File: MacAmpApp/Audio/VisualizerPipeline.swift
// Purpose: Real-time spectrum analysis using Goertzel-like single-bin DFT
// Context: More efficient than FFT for specific frequency detection
// Data transfer: VisualizerFeed (no allocations on the audio thread)
// The video producer (VideoTapVisualizerRender.swift) duplicates the RMS and
// Goertzel math on purpose; change both producers together.

private nonisolated static func makeTapHandler(
    feed: VisualizerFeed,
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

        // Publish to the feed (non-blocking: drops frame on contention)
        _ = feed.tryPublish(from: scratch, oscilloscopeSamples: 76,
                            validFrameCount: cappedFrameCount)
    }
}
```

---

## AVPlayer-Native Video DSP

Local video plays through AVPlayer, and its audio stays there. Instead of bridging video audio into AVAudioEngine, MacAmp attaches an `MTAudioProcessingTap` to the `AVPlayerItem` and applies preamp, EQ and balance to AVPlayer's own buffers in place, then feeds the processed signal to the shared visualizer. There is no ring buffer, no second clock domain and no extra sample-rate conversion stage. The decision record is `tasks/done/avplayer-native-video-dsp/plan.md` (ADR-1…ADR-12); background research is in `research.md` in the same folder.

### Topology

| Source | Routing | EQ + preamp | Balance | Visualizer producer |
|---|---|---|---|---|
| Local audio file | `AVAudioPlayerNode` → AVAudioEngine | `AVAudioUnitEQ` | `playerNode.pan` | Engine mixer tap (`makeTapHandler`) |
| Internet radio | `AVAudioSourceNode` → AVAudioEngine | `AVAudioUnitEQ` | `streamSourceNode.pan` | Engine mixer tap (`makeTapHandler`) |
| Local video | AVPlayer, tap on `AVPlayerItem.audioMix` | Tap: linear preamp + `BiquadCascade` | Tap: L/R gains | `videoTapVisualizerRender` |

Video volume is `AVPlayer.volume`, set by `AudioPlayer.volume`'s `didSet`; it is not applied in the tap. Streaming (HLS) video is not a target of this design: `MTAudioProcessingTap` does not fire reliably for streaming items (plan.md §2).

```
Video file
   │
   ▼
AVURLAsset ──► AVPlayerItem ──► AVPlayer ──► output device
                    │
               audioMix (set once, before the AVPlayer exists)
                    │
               MTAudioProcessingTap (PreEffects, stereo Float32 at source rate)
                    │  tapProcess, MediaToolbox render thread:
                    │  format gate → StartOfStream flush → preamp → biquad EQ
                    │  → balance → visualizer render → sampled deadline timing
                    ▼
               VideoTapContext ◄── EqualizerController (EQ state, coefficients)
                    │          ◄── AudioPlayer.balance
                    ▼
               VisualizerFeed ──► VisualizerPipeline (30 Hz consume)
```

### Tap Lifecycle

`AudioPlayer.playTrack` on a video calls `pauseAndDetachVideoTapIfNeeded()`, `startVideoLoad(track:)` and `visualizerPipeline.startVideoVisualization()`. `startVideoLoad` bumps `videoLoadGeneration` and runs a `@MainActor` task that calls `VideoPlaybackController.loadVideo(url:autoPlay: false, audioMixBuilder:isStillRelevant:)`. The `audioMixBuilder` closure:

1. awaits `asset.loadTracks(withMediaType: .audio)` and takes the first audio track (none → returns `nil`, and the player is built without a tap)
2. awaits `VideoTap.preferredProcessingFormat(for:)`
3. creates `VideoTapContext(feed: visualizerPipeline.sharedFeed)` and calls `VideoTap.buildAudioMix(audioTrack:context:preferredFormat:)`
4. only after a successful build, stores the Context and registers it with `EqualizerController` and the `AudioPlayer` balance registry

The generation is rechecked after every `await`, and `isStillRelevant` is checked again before `loadVideo` touches the item or player, so a superseded load never installs a tap or builds a player. Auto-play after the load happens only if the generation is still current and `playbackState` is `.playing`.

**Invariants:**
- One tap and one `VideoTapContext` per `AVPlayerItem`. `audioMix` is assigned to the item before `AVPlayer(playerItem:)` is constructed and is not mutated while playing.
- `buildAudioMix` retains the Context once (`Unmanaged.passRetained`) as the tap's client info; `tapFinalize` releases it exactly once. If tap creation fails, the retain is released before `VideoTapError.createFailed` is thrown.
- Teardown (stop, video→audio switch, next video) runs `pauseAndDetachVideoTapIfNeeded()`: pause the player if it is playing, set `audioMix = nil` (`VideoTap.detach(from:)`), and unregister the Context from both registries. `tapFinalize` may run later, asynchronously, when AVFoundation drops the tap; teardown does not wait for it.
- The registries hold `WeakBox<VideoTapContext>`, so they never extend a Context's lifetime.

### Processing Format

The tap is created with `MTAudioProcessingTapCreateWithPreferredFormat` (macOS 27), requesting the format from `VideoTap.preferredProcessingFormat(for:)`: **stereo Float32 non-interleaved at the source track's sample rate**. Without a preferred format the tap runs in a format chosen for the current output device, so its format changed with the route; over AirPlay 2 that produced audible volume pumping. If the source format cannot be read, the builder falls back to `MTAudioProcessingTapCreate`. Both use `kMTAudioProcessingTapCreationFlag_PreEffects`.

Consequence of the stereo pin: 5.1 and wider sources are downmixed, and mono is upmixed, before the tap, so channels 0 and 1 are always left and right for balance. Multichannel video currently plays as stereo on every output; true multichannel output is tracked as issue #88 (S4-4 `video-multichannel-output`).

### Render Path (`tapProcess`)

All five tap callbacks are file-scope closures that capture no Swift state; they reach the Context through `MTAudioProcessingTapGetStorage` and `Unmanaged`. `tapPrepare` validates the negotiated format and publishes the sample rate; `tapUnprepare` clears `isActive`. Each `tapProcess` call:

1. Pulls source audio with `MTAudioProcessingTapGetSourceAudio` (returns on error) and bumps the call/frame counters.
2. **Format gate:** DSP runs only on 32-bit float linear PCM (as validated in `tapPrepare`). Any other format, or a tap not yet prepared, passes through untouched.
3. **Discontinuity flush:** on `kMTAudioProcessingTapFlag_StartOfStream` (seek, new stream) the cascade's filter history is zeroed.
4. **Parameter load:** preamp, EQ-on and balance are read from atomics once per callback.
5. **Coefficient refresh (EQ on):** on an off→on edge the cascade is reset first. The render-owned coefficient cache is refreshed with `coefficients.withLockIfAvailable`: contended → keep the cached set; nothing installed yet → bypass; otherwise copy the new set.
6. **Per buffer / channel:** preamp multiply (skipped at unity gain), then the 10-band cascade when EQ is on, then the balance gain on channel 0 (L) and channel 1 (R), skipped at center. `VideoTap.balanceGains` keeps the near side at unity and attenuates the far side linearly (−1 mutes R, +1 mutes L), matching `AVAudioNode.pan`'s range.
7. **Visualizer:** `videoTapVisualizerRender` downmixes the processed buffer to mono, computes 20-bar RMS, 20-bar Goertzel spectrum and the 2048-point Butterchurn FFT into the Context's own `VisualizerScratchBuffers`, then calls `feed.tryPublish` (drops the frame on contention). The visualizer therefore shows the post-EQ, post-balance signal.
8. **Deadline telemetry:** every 64th callback times steps 4-7 against the buffer's duration and calls `recordProcessingDeadline`: over 10% of the budget increments `budgetOverrunCount`; over 50% increments `deadlineRiskCount` and stamps `lastDeadlineRiskHostTime`. The main thread reads these through `diagnosticSnapshot` (`VideoTapDiagnostics`). Nothing is logged from the render thread, and the Mach timebase is initialized in `buildAudioMix` so the render thread never pays for it.

### EQ Filter (`BiquadCoefficientSet` + `BiquadCascade`)

- `BiquadCoefficientSet.compute(for: EqualizerState, sampleRate:)` runs on the main thread using the RBJ Audio EQ Cookbook: low shelf at 70 Hz (band 0), eight peaking bands with 1-octave bandwidth, high shelf at 16 kHz (band 9), shelves at slope S = 1. Arithmetic is `Double`, storage `Float`. A 0 dB band becomes an exact identity section and is skipped at render time.
- `compute` fails closed to `.flat` for a non-finite or non-positive sample rate, a wrong-sized or non-finite gain array, any band at or above Nyquist, or any non-finite coefficient.
- `BiquadCoefficientSet.frequencies` is the single source of truth for band centers; `EqualizerController.configureEQ` reads the same array.
- `BiquadCascade` is Transposed Direct Form II with per-(band, channel) state in manually allocated buffers (no `Array` bounds, CoW or ARC in the inner loop), sized for 16 channels (`VideoTapContext.maxDSPChannels`). Filter state is flushed to zero below 1e-20 once per band per callback to avoid denormal stalls.
- Preamp is applied as a linear gain, `10^(dB/20)`, from `EqualizerState.preampLinearGain`.
- `BiquadNumericalMatchTests` holds the cascade to within 0.5 dB of `AVAudioUnitEQ` over 20 Hz–20 kHz.

### EQ and Balance Fanout

EQ and balance keep their existing owners; each fans out to the engine and to registered video taps:

| State | Owner | Engine write | Video-tap write |
|---|---|---|---|
| `isEqOn`, `preamp`, `eqBands` | `EqualizerController` | `AVAudioUnitEQ` in the `didSet`s | `fanOutToVideoTaps()` → `pushEQState`: `isEqOn` + preamp atomics, `installCoefficients(compute(...))` |
| `balance` | `AudioPlayer` | `engine.setBalance` in the `didSet` | `fanOutBalanceToVideoTaps()` → `balance` atomic |

- Registration pushes the current state immediately (`registerVideoTapContext`, `registerVideoTapContextForBalance`).
- Coefficients depend on the sample rate, which only becomes known when `tapPrepare` publishes `pendingSampleRate`. Until then `compute` returns `.flat`. `EqualizerController.pollVideoTapSampleRates()` runs on every 30 Hz `VisualizerPipeline.onPollTick` and recomputes for any Context whose published rate differs from the rate it last used.
- Both registries are `[WeakBox<VideoTapContext>]`, pruned of dead entries on each fan-out, with an early return when empty (audio-only playback pays nothing).
- The main thread writes only atomics and the coefficient `Mutex`; it never touches the cascade.

### Audio Mechanism Concurrency Contract

The tap's render thread belongs to MediaToolbox, not to Swift concurrency. It cannot hop to an actor or to `@MainActor`, and it must never block. The contract that follows from this:

- **When `@unchecked Sendable` is acceptable.** A bare `@unchecked Sendable` used to silence the compiler is a shortcut to avoid. It is acceptable only as a gated exception: the boundary genuinely needs it (a C callback, a real-time thread), the contract is written at the top of the type, every stored field is restricted as below, and tests enforce it. Types under this contract: `VideoTapContext`, `VisualizerFeed`, `VisualizerScratchBuffers`, with `BiquadCascade` render-confined via `RenderThreadSafe`. `StreamDecodePipeline`'s `DecodeContext` (queue-confined, `@unchecked Sendable`) predates the contract and is the next retrofit candidate.

- **Non-actor context.** `VideoTapContext` is a `final class … : @unchecked Sendable`. The `@unchecked` exists only for the C-callback boundary; the storage rules below keep the unsafety contained.
- **Permitted stored fields:** `Synchronization.Atomic<T>`; `Synchronization.Mutex<T>` (only for rarely changed, non-trivial state, and the render thread may only use `withLockIfAvailable`); `let` constants of immutable values; unsafe pointers whose lifetime the class manages; and types conforming to `RenderThreadSafe`. **Forbidden:** actor- or `@MainActor`-isolated types, non-`Sendable` references, closures that capture state, and any plain `var`.
- **`RenderThreadSafe`** (`Audio/RenderThreadSafe.swift`) is a `~Copyable` marker protocol. All conformances live in that one file: `Atomic`, `Mutex`, `Optional` (conditional), the unsafe pointer types, `AudioStreamBasicDescription`, `VisualizerFeed`, `VisualizerScratchBuffers` and `BiquadCascade` (safe by render-confinement: created on main in `VideoTapContext.init`, then touched only by `tapProcess`).
- **Encoding:** `Float` parameters are stored as `Atomic<UInt32>` bit patterns; the `Double` sample rate as `Atomic<UInt64>`.
- **Memory ordering:** parameters and telemetry use `.relaxed`. The format gate is a release/acquire pair: `tapPrepare` stores the sample rate and `isActive`, then release-stores the format tag; `tapProcess` acquire-loads the tag, so any render callback that sees the new tag also sees its sample rate.
- **Coefficient hand-off:** `Mutex<BiquadCoefficientSet?>`. Main installs with `withLock`; the render thread copies the value out with `withLockIfAvailable` and filters lock-free from its own cache. `BiquadCoefficientSet` is a flat tuple of `BiquadCoefs`, so the copy involves no heap, CoW or reference counting.
- **Visualizer hand-off:** `VisualizerFeed.tryPublish` takes a trylock and drops the frame on contention.
- **Render thread rules:** no allocation, no logging, no blocking lock, no Swift concurrency.
- **Library:** the video path uses the standard library's `Synchronization` module. The engine and stream paths still use the `swift-atomics` package (`ManagedAtomic` in `AudioEngineController` and `LockFreeRingBuffer`).
- **Enforcement:** the contract is written at the top of `VideoTapContext.swift`, and `VideoTapSendableContractTests` checks that every stored field conforms to `RenderThreadSafe`, that every stored `var` is `Atomic` or `Mutex`, and that `.cascade` is referenced only from the allowed files.

### Visualizer and UI Gating

During video no engine tap is installed, so `startVideoVisualization()` starts the 30 Hz poll timer on its own and `videoTapVisualizerRender` is the only producer. `AudioPlayer.isVisualizerRendering` (`isEngineRendering || (currentMediaType == .video && videoPlaybackController.isPlaying)`) gates `getFrequencyData`, `snapshotButterchurnFrame` (Milkdrop) and the `VisualizerView` / `OscilloscopeView` update timers. `stopVideoVisualization()` stops the timer and clears stale data on stop, on a video→audio switch and on video completion; a repeat-one restart starts it again.

### Remote Commands

`PlaybackCoordinator` owns media keys and AirPods commands (`MPRemoteCommandCenter`) for every source. `AVPlayerViewRepresentable` sets `updatesNowPlayingInfoCenter = false` on the `AVPlayerView`; left at its default, AVKit's own remote-command handling could pause the AVPlayer without the coordinator knowing.

### Known Limitations

- **Multichannel output:** 5.1+ video is downmixed to stereo in the tap (see Processing Format); issue #88, S4-4 `video-multichannel-output`.
- **P-6:** after a video, loading an audio track does not auto-play; the user has to press Next. Open and non-blocking (`tasks/done/avplayer-native-video-dsp/placeholder.md`).
- **Streaming video:** HLS video is not a supported target; `MTAudioProcessingTap` is unreliable for streaming items (plan.md §2).
- **macOS 27 deprecations:** the build carries 16 deprecated-API warnings (14 app, 2 test), including `AVPlayerItemDidPlayToEndTime` in `VideoPlaybackController` and `installTap(onBus:)` in `VisualizerPipeline`; S4-1 `swift64-macos27-readiness` replaces them.

**Tests:** `VideoTapLifecycleTests`, `VideoTapFanoutTests`, `VideoTapSendableContractTests`, `BiquadNumericalMatchTests`, `VideoTapVisualizerRenderTests`, `VideoTapTelemetryTests`, `VideoTapCPUBenchmarkTests`, `VideoSeekStateMatrixTests`, `EngineConfigObserverTests`.

---

## Internet Radio Streaming

Internet radio decodes streams to PCM with the custom pipeline described in [Unified Audio Pipeline Architecture](#unified-audio-pipeline-architecture) and plays them through AVAudioEngine, so streams get EQ, balance and the visualizer.

### Stream Types Supported

```
1. HTTP/HTTPS Progressive Audio Streams
   - MP3 streams (audio/mpeg) via AudioFileStream + AudioConverter
   - AAC streams (audio/aac, audio/aacp) via AudioFileStream + AudioConverter
   - Auto-detect (application/octet-stream) via AudioFileStream format hint = 0

2. Playlist Resolution (M3U/PLS)
   - .m3u / .m3u8 playlist files resolved to audio stream URL before streaming
   - .pls playlist files (FileN=url format) resolved before streaming

3. Metadata Protocols
   - ICY (SHOUTcast/Icecast) via custom ICYFramer
   - StreamTitle parsed as "Artist - Title" or plain title
```

### StreamPlayer Architecture (Unified Pipeline)

`StreamPlayer` is a `@MainActor @Observable` class (no AVPlayer, no `NSObject`, no Combine). It owns a `StreamDecodePipeline`, exposes observable state to the UI and hands the ring buffer to `PlaybackCoordinator` for the engine bridge. Volume and balance are applied by the engine (`AudioPlayer`'s `streamSourceNode`); `StreamPlayer` has no volume or balance state.

```swift
// StreamPlayer.swift (excerpt)
@MainActor
@Observable
final class StreamPlayer {
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var isReconnecting: Bool = false
    private(set) var currentStation: RadioStation?
    private(set) var streamTitle: String?
    private(set) var streamArtist: String?
    private(set) var error: String?
    private(set) var elapsedTime: Double = 0      // anchor-based stream clock

    private let pipeline = StreamDecodePipeline()

    // Bridge lifecycle, read by PlaybackCoordinator
    var currentRingBuffer: LockFreeRingBuffer? { ringBuffer }
    private(set) var currentSampleRate: Float64 = 0
    var onFormatReady: (@MainActor (Float64) -> Void)?
    var onStreamTerminated: (@MainActor () -> Void)?

    func play(station: RadioStation) async   // fresh LockFreeRingBuffer(capacity: 32768, channelCount: 2)
    func play(url: URL, title: String? = nil, artist: String? = nil) async
    func pause()
    func resume()
    func stop()
    func setAudioWorkgroup(_ workgroup: os_workgroup_t?)
}
```

`StreamPlayer` uses `isolated deinit` to stop the pipeline. ICY metadata comes from `ICYFramer`, not `AVPlayerItemMetadataOutput`.

The stream ring buffer is sized in frames, not seconds, so its effective buffering time changes with the decoded sample rate:

- `32768` frames at `44.1 kHz` is about `0.743 s`
- `32768` frames at `48 kHz` is about `0.683 s`
- `32768` frames at `96 kHz` is about `0.341 s`

Bitrate and sample rate are separate concepts in this pipeline. A `192 kbps` MP3 is a compressed data-rate figure; once decoded, the ring buffer carries PCM frames at the stream's detected sample rate.

### Auto-Reconnect State Machine

When a stream ends unexpectedly, `StreamPlayer` reconnects with exponential backoff. `StreamDecodePipeline.StreamTerminationReason` classifies why a stream ended, and its `userMessage` gives the string shown in the main window:

| Case | Reconnectable | Meaning | `userMessage` |
|------|:------------:|-------------|---|
| `networkError(String, Int)` | Depends | URLSession error; terminal for `NSURLErrorCannotFindHost`, `NSURLErrorUnsupportedURL`, `NSURLErrorBadURL`, reconnectable otherwise (connection lost, timeout) | "Host not found", "Connection timed out", "Connection lost", "No internet connection", "Cannot connect to server", else "Network error" |
| `serverClosed` | Yes | Server closed the connection | "Stream ended" |
| `httpClientError(Int)` | No | HTTP 4xx (except 429): bad URL, auth required | "HTTP error *code*" |
| `httpServerError(Int)` | Yes | HTTP 5xx and 429 Too Many Requests | "Server error *code*" |
| `decodeError(String)` | No | AudioConverter/AudioFileStream failure | "Unsupported audio format" |
| `invalidResponse` | No | Non-HTTP response | "Invalid server response" |
| `playlistResolutionFailed(String)` | Yes | M3U/PLS fetch failure (may be DNS) | "Playlist not found" |
| `userStopped` | No | User explicitly stopped playback | "" |

**Backoff:** 1 s, 2 s, 4 s, 8 s, then 16 s (capped); at most 10 attempts, after which the error reads "Connection lost after 10 attempts". Five seconds of stable playback resets the attempt counter.

**Bridge tear-down/re-create cycle:** each attempt first fires `onStreamTerminated` (PlaybackCoordinator deactivates the `AVAudioSourceNode` bridge), then creates a fresh `LockFreeRingBuffer` and restarts the decode pipeline; `onFormatReady` re-activates the bridge with the new buffer once the format is re-detected and prebuffering completes. Code: [Exponential Backoff Reconnect](IMPLEMENTATION_PATTERNS.md#pattern-exponential-backoff-reconnect-with-bridge-tear-down) and [Typed Stream Termination Reasons](IMPLEMENTATION_PATTERNS.md#pattern-typed-stream-termination-reasons).

### Radio Station Management

`RadioStationLibrary` (`Models/RadioStationLibrary.swift`, `@MainActor @Observable`) holds the user's saved stations: `addStation(_:)` (ignores a duplicate `streamURL`), `removeStation(id:)`, `removeAll()`. Stations persist as JSON under the `UserDefaults` key `MacAmp.RadioStations`. There are no built-in stations.

---

## Modern Swift 6.2 Patterns

The project builds with Swift 6.2 strict concurrency (swift-tools-version 6.2, macOS 27 minimum). The code-level patterns and migration steps are in [IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md); this section records where the language features are used.

### Strict Concurrency

```swift
// Package.swift (excerpt; the app itself is built from the XcodeGen project.yml)
// swift-tools-version: 6.2
let package = Package(
    name: "MacAmp",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
    ],
    // ...
)
```

`swift-atomics` (`ManagedAtomic`) serves the engine and stream paths. The video DSP path uses the standard library's `Synchronization` module (`Atomic`, `Mutex`) instead; see [Audio Mechanism Concurrency Contract](#audio-mechanism-concurrency-contract).

### `isolated deinit` (Swift 6.2)

`isolated deinit` runs the deinitializer on the class's actor, so `@MainActor` classes clean up their own properties directly instead of mirroring them into `nonisolated(unsafe)` copies. Pattern: [isolated deinit for @MainActor Cleanup](IMPLEMENTATION_PATTERNS.md#pattern-isolated-deinit-for-mainactor-cleanup-swift-62).

**Codebase usage (7 classes):**
- `AudioPlayer.isolated deinit` -- calls `engine.shutdown()` (stops the config observer, invalidates timer, deactivates bridge, removes tap)
- `VideoPlaybackController.isolated deinit` -- cancels tasks, removes observers, pauses player
- `VisualizerPipeline.isolated deinit` -- invalidates the poll timer (backstop)
- `AudioEngineConfigurationObserver.isolated deinit` -- cancels the watch and debounce tasks
- `StreamPlayer.isolated deinit` -- stops decode pipeline
- `StreamDecodePipeline.isolated deinit` -- tears down decode resources
- `WindowCoordinator.isolated deinit` -- stops settings observer

One `nonisolated(unsafe)` remains, a local `let` in `StreamDecodePipeline` that carries the `os_workgroup` across to the decode queue.

### `@concurrent` (Swift 6.2)

`@concurrent` runs a function off the caller's actor. MacAmp uses it on static functions for blocking I/O:

- `EQPresetStore`: `loadPresetsFromDisk`, `savePresetsToDisk`, `parseEqfFile`
- `SkinArchiveLoader.loadAsync(from:expectedSheets:)`: skin ZIP extraction

`MetadataLoader` does not need it: its methods `await` `AVAsset.load` immediately, with no blocking work before the suspension point. Pattern: [Background I/O with @concurrent](IMPLEMENTATION_PATTERNS.md#pattern-background-io-with-concurrent-static-functions-swift-62).

### Sendable and Isolation Domains

Value types that cross isolation boundaries are `Sendable` (see the table in [Swift 6 Concurrency Compliance](#swift-6-concurrency-compliance)). There are no custom actors: UI and orchestration state is `@MainActor`; the stream decode chain is confined to one serial queue (`QueueConfined`, `dispatchPrecondition`); real-time threads share state only through lock-free or trylock structures (`LockFreeRingBuffer`, `VisualizerFeed`, `VideoTapContext` atomics).

---

## Window Snap Manager

`WindowSnapManager` (`Utilities/WindowSnapManager.swift`, `@MainActor`, `NSWindowDelegate`, singleton `shared`) implements Winamp's magnetic docking. Geometry helpers live in `Models/SnapUtils.swift`. Multi-window context: [MULTI_WINDOW_ARCHITECTURE.md](MULTI_WINDOW_ARCHITECTURE.md).

- **Registration:** `WindowDelegateWiring` calls `register(window:kind:)` for each window and adds the manager to that window's `WindowDelegateMultiplexer`; `register` records the window and its last origin and does not set `window.delegate` itself.
- **Move handling (`windowDidMove`):** converts every window frame to a top-left virtual-screen space spanning all displays, finds the moved window's connected cluster, moves the rest of the cluster by the same delta, then snaps the cluster's bounding box to other windows (`SnapUtils.snapToMany`) and to the screen edges (`SnapUtils.snapWithin`).
- **Feedback prevention:** `isAdjusting` suppresses re-entry while the manager moves windows itself; `beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` let other code (double-size resize, window resize) suspend snapping.
- **Cluster queries:** `clusterKinds(containing:)` returns the `WindowKind`s touching a window (`WindowResizeController.resizeMainAndEQWindows` uses it to tell whether the playlist is docked to the main window, the equalizer or floating); `areConnected(_:_:)` wraps it.

### Connection Detection

```swift
// Two windows are connected when they overlap on one axis and an edge pair is near on the other
private func boxesAreConnected(_ a: Box, _ b: Box) -> Bool {
    if SnapUtils.overlapX(a, b) {
        if SnapUtils.near(SnapUtils.top(a), SnapUtils.bottom(b)) { return true }
        if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.top(b)) { return true }
        if SnapUtils.near(SnapUtils.top(a), SnapUtils.top(b)) { return true }
        if SnapUtils.near(SnapUtils.bottom(a), SnapUtils.bottom(b)) { return true }
    }
    if SnapUtils.overlapY(a, b) {
        if SnapUtils.near(SnapUtils.left(a), SnapUtils.right(b)) { return true }
        if SnapUtils.near(SnapUtils.right(a), SnapUtils.left(b)) { return true }
        if SnapUtils.near(SnapUtils.left(a), SnapUtils.left(b)) { return true }
        if SnapUtils.near(SnapUtils.right(a), SnapUtils.right(b)) { return true }
    }
    return false
}
```

`connectedCluster(start:boxes:)` is a depth-first search over `boxesAreConnected`, returning the set of window identifiers in the group.

### Key Features

1. **15px snap threshold:** `SnapUtils.SNAP_DISTANCE = 15`; `near` is `abs(a - b) < 15`
2. **Cluster movement:** docked windows move together as a group
3. **Screen edge snapping:** windows also snap to display boundaries
4. **Multi-monitor support:** the virtual space covers every `NSScreen`
5. **Feedback prevention:** `isAdjusting` prevents snap loops

---

## Sprite-Based Menu System

The playlist window's ADD/REM/MISC/LIST menus are `NSMenu`s whose items render skin sprites through SwiftUI, with full keyboard navigation.

- **`SpriteMenuItem`** (`Views/Components/SpriteMenuItem.swift`, `NSMenuItem` subclass): `init(normalSprite:selectedSprite:skinManager:action:target:)`. Its custom view is a `ClickForwardingView` (22×18) hosting a `SpriteMenuItemView` in an `NSHostingView`. Setting `spriteHighlighted` swaps between the normal and selected sprite (distinct from `NSMenuItem.isHighlighted`).
- **`ClickForwardingView`**: an item with a custom view receives no action automatically, so `mouseDown` calls `NSApp.sendAction(action, to: target, from: menuItem)` and then `menu?.cancelTracking()`.
- **`SpriteMenuItemView`**: draws the sprite with `.interpolation(.none)` / `.antialiased(false)` at 22×18, or a gray rectangle if the sprite is missing.
- **`PlaylistMenuDelegate`** (`NSMenuDelegate`): `menu(_:willHighlight:)` fires for mouse hover and arrow keys and sets `spriteHighlighted` on each item; `menuHasKeyEquivalent` handles Return/Enter by performing the highlighted item's action.

```swift
// PlaylistWindow/PlaylistMenuPresenter.swift (excerpt)
let menu = NSMenu()
menu.autoenablesItems = false
menu.delegate = menuDelegate   // stored property: NSMenu.delegate is weak

let addURLItem = SpriteMenuItem(
    normalSprite: "PLAYLIST_ADD_URL",
    selectedSprite: "PLAYLIST_ADD_URL_SELECTED",
    skinManager: skinManager,
    action: #selector(PlaylistWindowActions.addURL),
    target: PlaylistWindowActions.shared
)
addURLItem.representedObject = audioPlayer
menu.addItem(addURLItem)
```

---

## Video Window Architecture

The video window plays local video with VIDEO.bmp chrome. Full reference: [VIDEO_WINDOW.md](VIDEO_WINDOW.md).

- **Controller:** `WinampVideoWindowController` creates a `BorderlessWindow` (275×232, `.borderless`), applies `WinampWindowConfigurator.apply(to:)` and `installHitSurface(on:)`, and sets only `contentViewController` to an `NSHostingController` whose root view is `WinampVideoWindow` with the shared environment (setting `contentView` would release the hosting controller).
- **Chrome (`VideoWindowChromeView`):** built from VIDEO.bmp sprites positioned absolutely in a `ZStack`. The 20px titlebar uses `VIDEO_TITLEBAR_TOP_LEFT`, tiled `VIDEO_TITLEBAR_STRETCHY`, `VIDEO_TITLEBAR_TOP_CENTER` and `VIDEO_TITLEBAR_TOP_RIGHT` with an `_ACTIVE` / `_INACTIVE` suffix from `windowFocusState.isVideoKey`; side borders are `VIDEO_BORDER_LEFT` (11px) and `VIDEO_BORDER_RIGHT` (8px); the 38px bottom bar is `VIDEO_BOTTOM_LEFT` (125px), tiled `VIDEO_BOTTOM_TILE` and `VIDEO_BOTTOM_RIGHT` (125px), with a metadata ticker drawn from `CHARACTER_*` sprites.
- **Sizing:** `VideoWindowSizeState` resizes in 25×29px segments (`Size2D`; `[0,4]` = 275×232, `[11,12]` = 550×464), with a resize-preview overlay while dragging and 1x/2x presets.
- **Fallback:** when the skin has no VIDEO.bmp sprites (`Skin.hasVideoSprites` is false), `WinampVideoWindow` shows `VideoWindowFallbackChrome`.
- **Player:** `WinampVideoWindow` shows `AVPlayerViewRepresentable` only when `audioPlayer.currentMediaType == .video` and `audioPlayer.videoPlayer` exists, otherwise a black "No video loaded" placeholder.

### AVPlayer Integration

`VideoPlaybackController` (owned by `AudioPlayer`) builds a fresh `AVPlayer` per video, with the audio tap already on the item:

```swift
// VideoPlaybackController.loadVideo (simplified)
cleanup()
let asset = AVURLAsset(url: url)
let audioMix = await audioMixBuilder?(asset)        // VideoTap.buildAudioMix via AudioPlayer
if let isStillRelevant, !isStillRelevant() { return }  // superseded load: touch nothing
let playerItem = AVPlayerItem(asset: asset)
playerItem.audioMix = audioMix                        // set once, before the AVPlayer exists
player = AVPlayer(playerItem: playerItem)
// end-of-item + periodic time observers (identity-guarded), metadata task
```

`AVPlayerViewRepresentable` hides the AVKit controls and sets `updatesNowPlayingInfoCenter = false`. Video audio gets EQ, preamp, balance and visualizer data from the tap; see [AVPlayer-Native Video DSP](#avplayer-native-video-dsp).

### Key Implementation Details

1. **Activation**: V clutter button or Ctrl+V toggles `AppSettings.showVideoWindow` (persisted)
2. **File support**: `.mp4`, `.mov`, `.m4v`, `.avi` are detected as video by extension
3. **Position persistence**: window frame saved to UserDefaults
4. **Docking**: magnetic snapping via `WindowSnapManager`
5. **Audio routing**: audio stays on AVPlayer (not AVAudioEngine); an in-place `MTAudioProcessingTap` applies EQ, preamp and balance and feeds the visualizer

---

## Milkdrop Window Architecture

The Milkdrop window hosts Butterchurn.js, a WebGL port of the Milkdrop 2 visualizer, inside GEN.bmp chrome. Full reference: [MILKDROP_WINDOW.md](MILKDROP_WINDOW.md).

### Chrome (GEN.bmp)

`MilkdropWindowChromeView` builds the chrome from GEN.bmp sprites positioned absolutely in a `ZStack`, sized by `MilkdropWindowSizeState` (25×29px segments):

- **Titlebar (20px, 7 sections):** `GEN_TOP_LEFT` (25) + n × `GEN_TOP_LEFT_RIGHT_FILL` (gold filler) + `GEN_TOP_LEFT_END` + `GEN_TOP_CENTER_FILL` × 3 + `GEN_TOP_RIGHT_END` + n × `GEN_TOP_LEFT_RIGHT_FILL` + `GEN_TOP_RIGHT`. The fillers expand symmetrically as the window widens.
- **Focus:** every titlebar piece takes a `_SELECTED` suffix when `windowFocusState.isMilkdropKey` is true (GEN.bmp's two-state pattern: normal + selected, no pressed state).
- **Borders and bottom:** `GEN_MIDDLE_LEFT` (11px) / `GEN_MIDDLE_RIGHT` (8px); the 14px bottom bar is `GEN_BOTTOM_LEFT` (125) + tiled `GEN_BOTTOM_FILL_TOP` (13px) over `GEN_BOTTOM_FILL_BOTTOM` (1px) + `GEN_BOTTOM_RIGHT` (125).
- **Title letters:** each GEN.bmp letter is two discontiguous pieces separated by a 1px cyan boundary, drawn as `GEN_TEXT_<L>_TOP` (6px) over `GEN_TEXT_<L>_BOTTOM` (1px normal, 2px selected), with the `GEN_TEXT_SELECTED_` prefix when focused.

### Butterchurn Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WKWebView Container                       │
├─────────────────────────────────────────────────────────────┤
│  WKUserScript Injection (atDocumentStart):                  │
│    1. butterchurn.min.js            (238KB, ES module)      │
│    2. butterchurnPresets.min.js     (638KB, base pack)      │
│    3. butterchurnPresetsExtra.min.js (825KB, extra pack)    │
│                                                              │
│  WKUserScript Injection (atDocumentEnd):                    │
│    4. bridge.js               (Swift↔JS communication)      │
├─────────────────────────────────────────────────────────────┤
│  WebGL Canvas (60 FPS)                                       │
│    • Butterchurn visualizer instance                        │
│    • Presets from the base + extra packs                    │
│    • Hybrid WASM mode (see MILKDROP_WINDOW.md §9.10)        │
└─────────────────────────────────────────────────────────────┘
          │                              ▲
          │ postMessage("ready")         │ setAudioData(spectrum, waveform)
          │ postMessage("presetsLoaded") │ loadPreset(index)
          ▼                              │ showTrackTitle(text)
┌─────────────────────────────────────────────────────────────┐
│                    ButterchurnBridge                         │
│  @Observable @MainActor                                      │
│    • 30 FPS audio updates (async Task loop, ~33 ms sleep)    │
│    • callAsyncJavaScript with typed arguments                │
└─────────────────────────────────────────────────────────────┘
```

- **`ButterchurnBridge`** (`ViewModels/ButterchurnBridge.swift`): each tick calls `audioPlayer.snapshotButterchurnFrame()`. `nil` (nothing rendering) stops the JS visualizer until frames return; otherwise the spectrum is mapped from 0–1 floats to 0–255 ints and sent with the float waveform via `callAsyncJavaScript("window.macampButterchurn?.setAudioData(spectrum, waveform);", arguments:)`.
- **`ButterchurnPresetManager`** (`@Observable @MainActor`): `presets`, `currentPresetIndex`, `isRandomize` and `isCycling` (persisted), `cycleInterval` (default 15 s), `transitionDuration` (2.7 s), `trackTitleInterval` (0 = manual only), plus preset history and cycle/track-title timers.
- The audio feed is the shared visualizer feed: engine mixer tap for local files and radio, `MTAudioProcessingTap` producer for video. Diagram: [Butterchurn Data Flow](#butterchurn-data-flow).

### Key Implementation Details

1. **Activation**: Ctrl+K keyboard shortcut (matches Winamp)
2. **Chrome source**: GEN.bmp sprites with normal/selected pairs
3. **Visualization**: Butterchurn.js via WKWebView with WKUserScript injection
4. **Audio bridge**: 30 FPS Swift→JS using `callAsyncJavaScript`
5. **Preset management**: cycling, randomization, history, 100+ presets
6. **Track title**: manual or interval-based display (5s/10s/15s/30s/60s)
7. **Context menu**: right-click for preset navigation and settings
8. **Persistence**: settings saved to UserDefaults via AppSettings

---

## M3U Playlist Parser

`M3UParser` (`Models/M3UParser.swift`) reads M3U and M3U8 playlists with local files and internet radio streams; `M3UWriter` in the same file writes them.

- **`parse(fileURL:)`** throws `M3UParseError.fileNotFound` or `.encodingError` (UTF-8 only), then calls **`parse(content:relativeTo:)`**, which throws `.emptyPlaylist` when no entry resolves.
- **EXTINF:** `#EXTINF:duration,title` sets the duration (Int seconds; `-1` for streams) and title of the next path line; everything after the first comma is the title. Other `#` lines, including `#EXTM3U`, are skipped.
- **URL resolution (`resolveURL`)**, in order: `http://` / `https://` → remote URL; leading `/` → absolute file path; `X:` drive prefix → Windows path with `\` converted to `/`; otherwise relative to the playlist's directory (`.standardized`); no base URL → plain file URL.
- **`M3UEntry`**: `url`, optional `title`, optional `duration`, and `isRemoteStream` (scheme is `http` or `https`).
- **`M3UWriter.write(tracks:to:)`** writes `#EXTM3U`, then per track `#EXTINF:<duration>,<Artist - Title>` (title only when the artist is empty or "Unknown Artist"; duration `-1` for streams) and the URL (streams) or file path.

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

---

## Component Integration Maps

### Window Docking System (5-Window)

```
┌──────────────────────────────────────────────────┐
│           WindowSnapManager.shared                │
│                                                   │
│  • Magnetic window snapping (15px threshold)     │
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
       WinampWindowConfigurator
    (NSWindow config: borderless, hit surface,
     shadow, tabbingMode, titlebar properties)
```

### Playlist System

```
M3U/PLS File
     │
     ▼
M3UParser ──────► [Track] ──────► PlaylistController
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
PCM from AVAudioEngine            PCM from AVPlayer (video)
        │                                 │
        ▼                                 ▼
[Engine mixer tap]              [MTAudioProcessingTap]
        │                                 │
        └────────► VisualizerFeed ◄───────┘
                        │   (30 Hz consume)
        ┌───────────────┘
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
(60 FPS)
```

---

## UI Controls & Features

### Clutter Bar Buttons

The clutter bar is the vertical strip of five buttons on the left of the main window. All five are functional.

**Button locations** (`WinampMainWindowLayout.swift`):
```swift
static let clutterButtonO = CGPoint(x: 10, y: 25)  // top: 3px relative
static let clutterButtonA = CGPoint(x: 10, y: 33)  // top: 11px relative
static let clutterButtonI = CGPoint(x: 10, y: 40)  // top: 18px relative
static let clutterButtonD = CGPoint(x: 10, y: 47)  // top: 25px relative
static let clutterButtonV = CGPoint(x: 10, y: 55)  // top: 33px relative
```

| Button | Function | Shortcut | State | Implementation |
|---|---|---|---|---|
| **O** Options | Menu: time display toggle, double size, repeat Off/All/One (checkmarks), shuffle | Ctrl+O (menu), Ctrl+T (time), Ctrl+R (cycle repeat) | `AppSettings.timeDisplayMode`, `AppSettings.repeatMode` (persisted) | `NSMenu` via `MainWindowOptionsMenuPresenter` |
| **A** Always on Top | Keeps MacAmp windows above other apps (`NSWindow.Level.floating`) | Ctrl+A | `AppSettings.isAlwaysOnTop` (persisted) | `WindowCoordinator` updates window levels |
| **I** Track Info | Title, artist, duration; bitrate, sample rate, channels; stream-aware | Ctrl+I | `AppSettings.showTrackInfoDialog` (transient) | `TrackInfoView` sheet |
| **D** Double Size | Scales the main and EQ windows 100% ⇄ 200% | Ctrl+D | `AppSettings.isDoubleSizeMode` (persisted) | `.scaleEffect` + `resizeMainAndEQWindows(doubled:)` |
| **V** Video Window | Shows/hides the video window | Ctrl+V | `AppSettings.showVideoWindow` (persisted) | `WindowSettingsObserver` → `WindowVisibilityController` |

Sprites follow `MAIN_CLUTTER_BAR_BUTTON_<X>` / `MAIN_CLUTTER_BAR_BUTTON_<X>_SELECTED`. Each button is a plain `Button` that toggles the `AppSettings` flag and picks the sprite from it:

```swift
// MainWindow/MainWindowFullLayer.swift (buildClutterBarDV)
let dSprite = settings.isDoubleSizeMode
    ? "MAIN_CLUTTER_BAR_BUTTON_D_SELECTED"
    : "MAIN_CLUTTER_BAR_BUTTON_D"

Button(action: { settings.isDoubleSizeMode.toggle() }, label: {
    SimpleSpriteImage(dSprite, width: 8, height: 8)
})
.buttonStyle(.plain)
.focusable(false)
.help("Toggle window size")
.at(Layout.clutterButtonD)
```

### Repeat Mode Button (Winamp 5 Modern Pattern)

- **State:** `AppSettings.RepeatMode` (`off` / `all` / `one`), persisted with `didSet`; `AudioPlayer.repeatMode` forwards to it
- **Interaction:** click cycles Off → All → One → Off (`repeatMode.next()`); Ctrl+R does the same
- **Visual:** the button is lit when `repeatMode.isActive`; repeat-one adds a "1" badge in a `ZStack` (8pt bold white text, black shadow, offset x: 8)
- **Tooltip:** `repeatMode.label` ("Repeat: Off/All/One")
- **Migration:** the old Bool preference maps `true` → `.all`, `false` → `.off`
- **Code:** `MainWindowFullLayer.buildShuffleRepeatButtons`; enum pattern in [Enum State with Persistence](IMPLEMENTATION_PATTERNS.md#pattern-enum-state-with-persistence-repeatmode-pattern)

### Time Display System

- **State:** `AppSettings.timeDisplayMode` (`.elapsed` / `.remaining`), persisted with `didSet`; `toggleTimeDisplayMode()` flips it
- **Visual:** remaining mode draws a minus sign centered at y:6 in a 9×13 container
- **Interaction:** click the time display or press Ctrl+T; the O menu shows the matching checkmark

### Volume & Balance Sliders

**Signal flow:**
```
UI Slider → PlaybackCoordinator.setVolume() → AudioPlayer.volume didSet → engine.setVolume (playerNode + streamSourceNode)
                                                                        → VideoPlaybackController.volume (AVPlayer.volume)

UI Slider → PlaybackCoordinator.setBalance() → AudioPlayer.balance didSet → engine.setBalance (playerNode.pan + streamSourceNode.pan)
                                                                          → registered VideoTapContext.balance atomics

Drag end  → PlaybackCoordinator.commitVolume() / commitBalance() → UserDefaults
```

- **Source of truth:** `AudioPlayer.volume` (0.0–1.0, default 0.75) and `balance` (−1.0 left to 1.0 right, default 0). `init()` restores them with `UserDefaults.object(forKey:) as? Float`, so a saved 0 is distinguished from "never set".
- **Bindings:** asymmetric `Binding<Float>`: reads from `AudioPlayer`, writes through `PlaybackCoordinator`. The coordinator short-circuits same-value writes, and persistence happens once at drag end rather than on every gesture tick. Code: [Coordinator Volume Routing](IMPLEMENTATION_PATTERNS.md#pattern-coordinator-volume-routing), [Asymmetric Binding](IMPLEMENTATION_PATTERNS.md#pattern-asymmetric-binding-for-coordinator-routing), [UserDefaults Persistence](IMPLEMENTATION_PATTERNS.md#pattern-userdefaults-persistence-with-centralized-keys).
- **Video:** volume sets `AVPlayer.volume` and is not applied in the tap; balance is applied inside the video tap.
- **Streams:** play through the same engine graph, so `StreamPlayer` needs no volume or balance of its own.

**Capability-based dimming:**
- The balance slider (and the EQ sliders in `WinampEqualizerWindow`) dim to 50% opacity with hit testing disabled only during stream prebuffering, before the bridge activates
- Once the stream bridge is active, EQ, balance and the visualizer all work through the unified pipeline
- A stream in an error state re-enables the controls, so the user is not stuck with a dimmed UI
- During video the flag is `true`; EQ and balance act on the video tap
- While dimmed, the balance tooltip reads "Balance unavailable during streaming"

**Balance slider color gradient** (`WinampVolumeSlider.swift`):
- BALANCE.BMP: 28 frames stacked vertically (15px each, 420px total)
- Frame 0 (top) = green (neutral center), frame 27 (bottom) = red (full L/R)
- webamp-compatible linear mapping: `floor(abs(balance) * 27) * 15`
- Symmetric via `abs(balance)`: full left and full right both show red

**Haptic snap-to-center:**
- Fires once on entry into the center zone (not every frame)
- Threshold: 12% of slider range
- Uses `NSHapticFeedbackManager` for system-native feedback

---

## Testing Strategies

### Test Plan & Configurations

- **Framework:** Swift Testing (`@Suite` structs, `@Test`, `#expect`); UI tests are not part of the project
- **Target:** `MacAmpTests` (`Tests/MacAmpTests`), run through the `MacAmpApp` scheme's single "All" test-plan configuration
- **Project spec:** `project.yml` (XcodeGen; run `xcodegen generate` when the `.xcodeproj` is stale or missing)

```bash
xcodegen generate  # if xcodeproj is stale or missing
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS'   # also run without TSan: wall-clock benchmarks skip themselves under TSan
```

**Suites:** `AppSettingsTests`, `AudioPlayerStateTests`, `BiquadNumericalMatchTests`, `DockingControllerTests`, `EngineConfigObserverTests`, `EQCodecTests`, `LockFreeRingBufferTests`, `PlaylistNavigationTests`, `SkinManagerTests`, `SpriteResolverTests`, `StreamPauseTailTests`, `VideoSeekStateMatrixTests`, `VideoTapCPUBenchmarkTests`, `VideoTapFanoutTests`, `VideoTapLifecycleTests`, `VideoTapSendableContractTests`, `VideoTapTelemetryTests`, `VideoTapVisualizerRenderTests`, `WindowDockingGeometryTests`, `WindowFrameStoreTests` (tags in `TestTags.swift`).

### Unit Tests

```swift
// Tests/MacAmpTests/SpriteResolverTests.swift (excerpt)
import Testing
import AppKit
@testable import MacAmp

@Suite("SpriteResolver", .tags(.skin))
struct SpriteResolverTests {
    @Test("Out-of-range digits return nil", arguments: [-1, 10, 99, -100])
    func digitOutOfRange(_ digit: Int) {
        let resolver = SpriteResolver(skin: emptySkin)
        #expect(resolver.resolve(.digit(digit)) == nil)
    }
}
```

Testing patterns (async release polling, TSan-aware benchmarks, numerical match against `AVAudioUnitEQ`) are in [IMPLEMENTATION_PATTERNS.md → Testing Patterns](IMPLEMENTATION_PATTERNS.md#testing-patterns).

### Integration Testing

Manual, before release: load 3–5 different skins, test magnetic docking, verify local and radio playback, check keyboard shortcuts and double-size mode, compare against Winamp 5 Modern behaviour, and watch for visualizer frame drops.

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

**Problem**: Updating UI state from a background context
```swift
// ❌ Data race: self is @MainActor
Task.detached {
    let result = await heavyComputation()
    self.displayText = result
}
```

**Solution**: Do the work off-actor and assign on the main actor, e.g. a `@concurrent` static function awaited from `@MainActor` code (see [Modern Swift 6.2 Patterns](#modern-swift-62-patterns)), or `await MainActor.run { ... }`.

### Pitfall 3: AVAudioEngine State

**Problem**: Assuming `engine.start()` succeeds. It throws after interruptions and output-device changes.

**Solution**: Treat engine start as a hard gate: if it fails, abort (don't install taps or call `playerNode.play()`). Output-route changes are handled by the reconfigure flow in [Output Route Changes](#output-route-changes-engine-reconfiguration).

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

> **Companion pitfall: run-loop mode.** `Timer.scheduledTimer(withTimeInterval:repeats:block:)` schedules the timer in `.default` mode only. During an active `DragGesture` (or any `.eventTracking` mode: window move, scroll, menu), `.default`-mode timers are **paused**. If the timer feeds a producer→consumer pipeline (e.g., audio data poll → SwiftUI visualizer body), the consumer keeps running but reads stale data and looks frozen. **Use `Timer(...)` + `RunLoop.main.add(timer, forMode: .common)` for any timer that must keep firing during user gestures.** See `BUILDING_RETRO_MACOS_APPS_SKILL.md` → "Lesson: RunLoop Mode Discipline in Feeding Pipelines" for the audit checklist.

### Pitfall 5: SwiftUI Redraw Storms

**Problem**: A monolithic view body that reads fast-changing state (`AudioPlayer` time updates every 100 ms) re-evaluates every element on each change.

**Solution**: Split the window into child `View` structs that each read only the `@Environment` values they need; see [Z-Layer Background Masking and Child-View Recomposition Boundaries](#z-layer-background-masking-and-child-view-recomposition-boundaries) and [View Layer Decomposition](IMPLEMENTATION_PATTERNS.md#pattern-view-layer-decomposition-mainwindow).

---

## Quick Reference

### Key Files & Their Purposes

Line counts for the audio files are in [Component Breakdown](#component-breakdown).

```
MacAmpApp/
├── Audio/
│   ├── AudioPlayer.swift           # Playback facade, volume/balance, seek, video-tap orchestration
│   ├── AudioEngineController.swift # AVAudioEngine graph lifecycle, node wiring, bridge, route changes
│   ├── AudioEngineConfigurationObserver.swift # Debounced AVAudioEngineConfigurationChange observer
│   ├── EqualizerController.swift   # EQ state (owns EQPresetStore); engine EQ + video-tap fanout
│   ├── EQPresetStore.swift         # EQ preset persistence
│   ├── LockFreeRingBuffer.swift    # SPSC ring buffer for stream audio
│   ├── MetadataLoader.swift        # Async track/video metadata
│   ├── PlaylistController.swift    # Playlist state and navigation
│   ├── VideoPlaybackController.swift # AVPlayer lifecycle, audioMix at item construction
│   ├── VisualizerPipeline.swift    # Engine tap, feed consumer, Butterchurn data
│   ├── VisualizerFeed.swift        # SPSC visualizer hand-off, engine + video producers
│   ├── VisualizerScratchBuffers.swift # Per-producer RMS/Goertzel/FFT scratch
│   ├── RenderThreadSafe.swift      # Marker protocol + all conformances for render-thread storage
│   ├── StreamPlayer.swift          # Stream playback, auto-reconnect, owns StreamDecodePipeline
│   ├── PlaybackCoordinator.swift   # Orchestrates both backends, bridge lifecycle, capability flag, remote commands
│   ├── ObjCBridge/
│   │   ├── AUAudioUnitWorkgroupShim.h  # ObjC bridge for os_workgroup
│   │   └── AUAudioUnitWorkgroupShim.m  # ObjC bridge implementation
│   ├── VideoDSP/
│   │   ├── VideoTap.swift              # MTAudioProcessingTap callbacks, audio-mix builder, detach
│   │   ├── VideoTapContext.swift       # Render-thread state, Atomic/Mutex fields, telemetry
│   │   ├── BiquadCoefficientSet.swift  # RBJ coefficients + shared band frequencies
│   │   ├── BiquadCascade.swift         # Render-confined 10-band TDF-II filter
│   │   └── VideoTapVisualizerRender.swift # Video-side visualizer producer
│   └── Streaming/
│       ├── QueueConfined.swift         # Queue confinement protocol
│       ├── ICYFramer.swift             # ICY metadata protocol parser, Sendable struct
│       ├── AudioFileStreamParser.swift # AudioFileStream C API wrapper, decode-queue-confined
│       ├── AudioConverterDecoder.swift # AudioConverter C API wrapper, decode-queue-confined
│       └── StreamDecodePipeline.swift  # Pipeline orchestrator (@MainActor + DecodeContext)
│
├── Models/
│   ├── AppSettings.swift           # Preferences (didSet persistence), RepeatMode/TimeDisplayMode/VisualizerMode
│   ├── Track.swift                 # Track data model (Sendable)
│   ├── Skin.swift                  # Skin model
│   ├── SkinSprites.swift           # Sprite sheet coordinate tables
│   ├── SpriteResolver.swift        # Semantic → actual sprite mapping
│   ├── ImageSlicing.swift          # NSImage.cropped(to:) (independent pixel copy)
│   ├── VisColorParser.swift / PLEditParser.swift # VISCOLOR.TXT / PLEDIT.TXT
│   ├── EQPreset.swift / EQF.swift  # EQ preset models, EQF codec
│   ├── M3UParser.swift / M3UEntry.swift # Playlist parse/write
│   ├── RadioStation.swift / RadioStationLibrary.swift # Saved stations
│   ├── WindowFocusState.swift      # Key-window tracking
│   ├── SnapUtils.swift / Size2D.swift # Snap geometry, segment sizes
│   └── VideoWindowSizeState.swift / MilkdropWindowSizeState.swift / PlaylistWindowSizeState.swift
│
├── ViewModels/
│   ├── SkinManager.swift (+ SkinManager+Import.swift) # Skin loading, hot-swap, import
│   ├── SkinArchiveLoader.swift     # @concurrent ZIP extraction
│   ├── DockingController.swift     # Window magnetic docking
│   ├── ButterchurnBridge.swift     # Swift-to-JS Butterchurn bridge
│   ├── ButterchurnPresetManager.swift # Preset management
│   ├── WindowCoordinator.swift     # Window management facade
│   └── WindowCoordinator+Layout.swift # Layout/presentation
│
├── Views/
│   ├── MainWindow/                 # Main player window (10 files)
│   │   ├── WinampMainWindow.swift            # Root composition
│   │   ├── WinampMainWindowLayout.swift      # Coords constants enum
│   │   ├── WinampMainWindowInteractionState.swift # @Observable interaction state
│   │   ├── MainWindowOptionsMenuPresenter.swift # NSMenu bridge for O button
│   │   ├── MainWindowFullLayer.swift         # Full-mode composition
│   │   ├── MainWindowShadeLayer.swift        # Shade-mode composition
│   │   ├── MainWindowTransportLayer.swift    # Prev/play/pause/stop/next/eject
│   │   ├── MainWindowTrackInfoLayer.swift    # Scrolling text display
│   │   ├── MainWindowIndicatorsLayer.swift   # Play/pause, mono/stereo, bitrate, sample rate
│   │   └── MainWindowSlidersLayer.swift      # Volume, balance, position sliders
│   │
│   ├── PlaylistWindow/             # Playlist window (7 files)
│   │   ├── PlaylistBottomControlsView.swift  # Bottom control buttons
│   │   ├── PlaylistMenuPresenter.swift       # NSMenu bridge
│   │   ├── PlaylistResizeHandle.swift        # Resize handle
│   │   ├── PlaylistShadeView.swift           # Shade mode
│   │   ├── PlaylistTitleBarButtons.swift     # Titlebar controls
│   │   ├── PlaylistTrackListView.swift       # Track list rendering
│   │   └── PlaylistWindowInteractionState.swift # @Observable state
│   │
│   ├── WinampEqualizerWindow.swift # 10-band EQ window
│   ├── WinampPlaylistWindow.swift  # Playlist root composition
│   ├── PlaylistWindowActions.swift # Playlist NEW/LOAD/SAVE and ADD/REM actions
│   ├── WinampVideoWindow.swift     # Video playback window
│   ├── WinampMilkdropWindow.swift  # Visualization window
│   ├── VisualizerView.swift        # Spectrum/oscilloscope visualizer
│   ├── SkinnedText.swift           # Bitmap font text rendering
│   ├── PreferencesView.swift       # Preferences window
│   ├── Shared/
│   │   ├── TitlebarDragCaptureView.swift     # Titlebar drag NSView
│   │   └── WinampTitlebarDragHandle.swift    # Titlebar drag handle
│   │
│   ├── Windows/
│   │   ├── AVPlayerViewRepresentable.swift   # AVPlayerView bridge (Now Playing updates off)
│   │   ├── ButterchurnWebView.swift          # WKWebView for Butterchurn
│   │   ├── MilkdropWindowChromeView.swift    # Milkdrop GEN.BMP chrome
│   │   └── VideoWindowChromeView.swift       # Video VIDEO.BMP chrome
│   │
│   └── Components/
│       ├── EQPresetPickerView.swift          # EQ preset picker
│       ├── PlaylistBitmapText.swift          # Playlist bitmap text
│       ├── PlaylistMenuDelegate.swift        # Sprite-menu keyboard navigation
│       ├── PlaylistScrollSlider.swift        # Playlist scroll slider
│       ├── PlaylistTimeText.swift            # Playlist time text
│       ├── SimpleSpriteImage.swift           # Sprite rendering + .at() positioning
│       ├── SpriteMenuItem.swift              # Sprite menu item
│       ├── TrackInfoView.swift               # Track info display
│       ├── WinampVerticalSlider.swift        # EQ band slider
│       └── WinampVolumeSlider.swift          # Volume and balance sliders
│
├── Windows/
│   ├── BorderlessWindow.swift                # Borderless NSWindow subclass
│   ├── WindowRegistry.swift                  # Window ownership + lookup
│   ├── WindowFramePersistence.swift          # Frame save/load/suppress
│   ├── WindowVisibilityController.swift      # Show/hide/toggle (@Observable)
│   ├── WindowResizeController.swift          # Resize + docking
│   ├── WindowSettingsObserver.swift          # Settings observation
│   ├── WindowDelegateWiring.swift            # Delegate factory
│   ├── WindowDockingTypes.swift              # Value types (Sendable)
│   ├── WindowDockingGeometry.swift           # Pure geometry (nonisolated)
│   ├── WindowFrameStore.swift                # UserDefaults persistence
│   └── Winamp{Main,Equalizer,Playlist,Video,Milkdrop}WindowController.swift
│
├── Utilities/
│   ├── TimeFormatting.swift                  # Duration formatting
│   ├── WeakBox.swift                         # Weak reference wrapper for video-tap registries
│   ├── MenuActionTarget.swift                # NSMenu closure bridge (MenuItemFactory)
│   ├── WinampAlertHelper.swift               # Alert presentation helpers
│   ├── AppLogger.swift                       # Unified logging (AppLog)
│   ├── WinampWindowConfigurator.swift        # Window configuration
│   ├── WindowDelegateMultiplexer.swift       # Delegate multiplexer
│   ├── WindowFocusDelegate.swift             # Focus delegation
│   ├── WindowResizePreviewOverlay.swift      # Resize preview
│   └── WindowSnapManager.swift               # Magnetic snap logic
│
├── MacAmpApp.swift                 # App entry point, DI setup
├── AppCommands.swift               # App menu commands and shortcuts
└── SkinsCommands.swift             # Skins menu commands
```

### Common Tasks

**Load a skin:**
```swift
skinManager.loadSkin(from: URL(fileURLWithPath: "/path/to/skin.wsz"))  // loads asynchronously
skinManager.switchToSkin(identifier: "bundled:Winamp")                  // by identifier, saves the selection
```

**Play a track (local file or stream):**
```swift
await playbackCoordinator.play(track: track)
```

**Play internet radio:**
```swift
let station = RadioStation(name: "My Station", streamURL: url)
await playbackCoordinator.play(station: station)
```

**Apply EQ preset:**
```swift
audioPlayer.applyEQPreset(preset)   // an EQPreset, e.g. from EQPreset.builtIn
```

**Set repeat mode:**
```swift
audioPlayer.repeatMode = .one  // Repeat current track
audioPlayer.repeatMode = .all  // Loop playlist
audioPlayer.repeatMode = .off  // Stop at end
audioPlayer.repeatMode = audioPlayer.repeatMode.next()  // Cycle (button behavior)
```

**Add to playlist:**
```swift
audioPlayer.addTrack(url: url)
```

### Build & Run

```bash
# Debug build
xcodebuild -scheme MacAmpApp -configuration Debug build

# Release build with optimizations
xcodebuild -scheme MacAmpApp -configuration Release \
    -archivePath MacAmpApp.xcarchive archive

# Run tests
xcodebuild test -scheme MacAmpApp -destination 'platform=macOS' -enableThreadSanitizer YES

# Clean build
xcodebuild clean
```

Release signing and notarization: [RELEASE_BUILD_GUIDE.md](RELEASE_BUILD_GUIDE.md).

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
VIDEO.BMP        # Video window chrome (titlebar, borders, bottom bar)
GEN.BMP          # Generic/Milkdrop chrome - normal/selected pairs
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

**GEN.bmp sprite names (Milkdrop):** each element has a normal and a `_SELECTED` variant: `GEN_TOP_LEFT`, `GEN_TOP_LEFT_RIGHT_FILL`, `GEN_TOP_LEFT_END`, `GEN_TOP_CENTER_FILL`, `GEN_TOP_RIGHT_END`, `GEN_TOP_RIGHT`. Borders and bottom bar: `GEN_MIDDLE_LEFT`, `GEN_MIDDLE_RIGHT`, `GEN_BOTTOM_LEFT`, `GEN_BOTTOM_FILL_TOP`, `GEN_BOTTOM_FILL_BOTTOM`, `GEN_BOTTOM_RIGHT`.

---

## Conclusion

MacAmp demonstrates that retro UI aesthetics and modern development practices are not mutually exclusive. By building a unified audio pipeline (custom stream decode feeding AVAudioEngine) plus an in-place DSP tap for AVPlayer video, leveraging modern language features (Swift 6.2 concurrency), and maintaining strict architectural boundaries (three-layer pattern), we've created a maintainable, performant, and pixel-perfect recreation of a beloved classic.

The key insight: **The skin is not the app**. This separation enables MacAmp to be simultaneously a faithful Winamp clone and a modern macOS application.

For developers joining the project: start with `PlaybackCoordinator.swift` to understand the orchestration pattern, explore `SpriteResolver.swift` for the semantic mapping system, and examine the `MainWindow/` subdirectory to see how it all comes together in SwiftUI -- `WinampMainWindow.swift` is the root composition, `MainWindowFullLayer.swift` assembles child layers, and each layer struct (Transport, Sliders, Indicators, TrackInfo) creates a focused recomposition boundary.

Welcome to MacAmp. May your audio be crisp and your skins be pixel-perfect.

---

*Document Version: 3.3.0 | Last Updated: 2026-09-25*

**Recent updates** (full history in git):
- **3.3.0 (2026-09-25):** Pruned: one home per topic (code patterns moved to IMPLEMENTATION_PATTERNS.md), snippets checked against the code, per-file sizes consolidated into Component Breakdown, stale sections corrected.
- **3.2.0 (2026-09-25):** Added AVPlayer-Native Video DSP and Output Route Changes; `VisualizerSharedBuffer` → `VisualizerFeed`; balance reaches video taps.
- **3.0.0 (2026-03-22):** AudioEngineController extraction; network auto-reconnect.
- **2.9.0 (2026-03-14):** Unified audio pipeline replaced the dual AVPlayer/engine backends.
- **2.7.0 (2026-02-22):** MainWindow layer decomposition.
