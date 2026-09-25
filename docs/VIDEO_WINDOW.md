# MacAmp Video Window Documentation

**Version:** 3.0.0
**Last Updated:** 2026-09-25
**Status:** Production Ready (TASK 2 + Part 21 + AVPlayer-native video audio DSP)
**Author:** MacAmp Development Team

---

## Table of Contents

1. [Introduction](#introduction)
2. [Window Specifications](#window-specifications)
3. [Architecture Overview](#architecture-overview)
4. [Chrome Components](#chrome-components)
5. [Video Playback System](#video-playback-system)
6. [Video Audio DSP Pipeline](#video-audio-dsp-pipeline)
7. [Window Focus Integration](#window-focus-integration)
8. [Window Resizing (1x/2x)](#window-resizing-1x2x)
9. [Persistence & Window Docking](#persistence--window-docking)
10. [Fallback Chrome System](#fallback-chrome-system)
11. [Implementation Patterns](#implementation-patterns)
12. [Testing Guidelines](#testing-guidelines)
13. [Future Enhancements](#future-enhancements)
14. [Appendix: Sprite Definitions](#appendix-sprite-definitions)

---

## Introduction

The Video Window is a core component of MacAmp's media playback system, providing native video playback with authentic Winamp skinning. Implemented during TASK 2 (Days 1-6), it establishes MacAmp as a complete multimedia player matching Winamp's capabilities.

### Purpose

- **Video Playback:** Native macOS video rendering via AVPlayer
- **Winamp Audio Controls on Video:** 10-band EQ, preamp, balance, spectrum/oscilloscope and Milkdrop all apply to the video's audio (in-place processing tap, see [Video Audio DSP Pipeline](#video-audio-dsp-pipeline))
- **Skinned Chrome:** Pixel-perfect VIDEO.bmp sprite rendering
- **Seamless Integration:** Works with MacAmp's 5-window system
- **Format Support:** MP4, MOV, M4V, and other QuickTime-compatible formats

### Activation Methods

1. **V Button:** Click the "V" button on the main window (toggles visibility)
2. **Keyboard:** Press `Ctrl+V` to toggle window visibility
3. **Menu:** Windows → Show/Hide Video Window
4. **Playlist:** Playing a video file does not open the window automatically (open it with V / Ctrl+V); while open with no video loaded it shows "No video loaded"

### Historical Context

Winamp's video window evolved from simple plugin support (Winamp 2.x) to integrated video playback (Winamp 5.x). MacAmp implements the Winamp 5.x model with modern macOS video capabilities while maintaining classic visual authenticity.

---

## Window Specifications

### Dimensions

```swift
// Standard (1x) Size - matches Playlist window height
static let windowSize = CGSize(width: 275, height: 232)

// Component breakdown:
static let titlebarHeight: CGFloat = 20   // Draggable titlebar
static let bottomBarHeight: CGFloat = 38  // Controls and metadata
static let leftBorderWidth: CGFloat = 11  // Left chrome border
static let rightBorderWidth: CGFloat = 8  // Right chrome border

// Content area (actual video viewport):
static let contentWidth: CGFloat = 256   // 275 - 11 - 8
static let contentHeight: CGFloat = 174  // 232 - 20 - 38
```

### Coordinate System

```
Window Layout (275×232):
┌─────────────────────────────────────────┐
│ Titlebar (0,0,275,20)                   │ ← Draggable
├─────────────────────────────────────────┤
│L│                                     │R│
│ │     Video Content Area              │ │
│ │     (11,20,256,174)                │ │
│ │                                     │ │
│11│                                   │8│
├─────────────────────────────────────────┤
│ Bottom Bar (0,194,275,38)               │ ← Controls
└─────────────────────────────────────────┘
```

### VIDEO.bmp Resource

The video window chrome is rendered using sprites extracted from `VIDEO.bmp`:

- **Source:** `skins/{skin-name}/VIDEO.bmp`
- **Dimensions:** Variable (typically 306×164 or similar)
- **Color Depth:** 8-bit indexed (Winamp palette)
- **Required:** No (fallback chrome available)

---

## Architecture Overview

### Window Controller Pattern

```swift
// WinampVideoWindowController.swift
class WinampVideoWindowController: NSWindowController {
    convenience init(
        skinManager: SkinManager,
        audioPlayer: AudioPlayer,
        dockingController: DockingController,
        settings: AppSettings,
        radioLibrary: RadioStationLibrary,
        playbackCoordinator: PlaybackCoordinator,
        windowFocusState: WindowFocusState
    ) {
        // Create borderless window (NSWindowController pattern)
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Apply Winamp window configuration
        WinampWindowConfigurator.apply(to: window)

        // Create SwiftUI view with environment injection
        let rootView = WinampVideoWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            // ... inject all dependencies

        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController

        self.init(window: window)
    }
}
```

### Five-Window System Integration

MacAmp manages five windows as a coordinated system:

```
WindowCoordinator
├── Main Window (always visible)
├── Equalizer Window
├── Playlist Window
├── Video Window      ← Our focus
└── Milkdrop Window
```

Each window:
- Has its own NSWindowController
- Shares environment objects via injection
- Participates in magnetic docking
- Maintains position persistence
- Responds to focus changes

### Layer Architecture

Following MacAmp's three-layer pattern:

1. **Mechanism Layer:** AVPlayer, AVPlayerView (AVKit framework), `VideoPlaybackController` (AVPlayer lifecycle, observers, seek), `VideoTap` + `VideoTapContext` + `BiquadCascade` (in-place audio DSP on the render thread)
2. **Bridge Layer:** AVPlayerViewRepresentable, AudioPlayer (media-type routing, `startVideoLoad`, balance fanout), EqualizerController (EQ fanout)
3. **Presentation Layer:** VideoWindowChromeView, WinampVideoWindow

---

## Chrome Components

### Titlebar System

The titlebar consists of four sprite sections that change based on window focus:

```swift
// Active window sprites (bright blue gradient)
VIDEO_TITLEBAR_TOP_LEFT_ACTIVE     // 25×20 - Left cap
VIDEO_TITLEBAR_TOP_CENTER_ACTIVE   // 100×20 - "WINAMP VIDEO" text
VIDEO_TITLEBAR_STRETCHY_ACTIVE     // 25×20 - Tileable middle
VIDEO_TITLEBAR_TOP_RIGHT_ACTIVE    // 25×20 - Right cap with close button

// Inactive window sprites (dark gray)
VIDEO_TITLEBAR_TOP_LEFT_INACTIVE
VIDEO_TITLEBAR_TOP_CENTER_INACTIVE
VIDEO_TITLEBAR_STRETCHY_INACTIVE
VIDEO_TITLEBAR_TOP_RIGHT_INACTIVE
```

**Rendering Logic:**

```swift
// VideoWindowChromeView.swift
let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"

// Left cap
SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_\(suffix)", width: 25, height: 20)
    .position(x: 12.5, y: 10)

// Stretchy tiles (3 copies to fill width)
ForEach(0..<3, id: \.self) { i in
    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
}

// Center text
SimpleSpriteImage("VIDEO_TITLEBAR_TOP_CENTER_\(suffix)", width: 100, height: 20)
    .position(x: 137.5, y: 10)
```

### Border System

Vertical borders use tiled sprites (29px tiles):

```swift
// Side border sprites
VIDEO_BORDER_LEFT   // 11×29 - Left border tile
VIDEO_BORDER_RIGHT  // 8×29 - Right border tile

// Tiling calculation
let sideHeight: CGFloat = 174  // Content area height
let sideTileCount = Int(ceil(sideHeight / 29))  // 6 tiles needed

// Render tiles
ForEach(0..<sideTileCount, id: \.self) { i in
    SimpleSpriteImage("VIDEO_BORDER_LEFT", width: 11, height: 29)
        .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)
}
```

### Bottom Bar

The bottom bar contains controls and metadata display:

```swift
// Bottom bar sprites (38px height)
VIDEO_BOTTOM_LEFT   // 125×38 - Buttons area
VIDEO_BOTTOM_TILE   // 25×38 - Stretchy center
VIDEO_BOTTOM_RIGHT  // 125×38 - Info display area

// Button sprites (in VIDEO_BOTTOM_LEFT region)
VIDEO_FULLSCREEN_BUTTON  // 15×18 @ (9, 51)
VIDEO_1X_BUTTON         // 15×18 @ (24, 51)
VIDEO_2X_BUTTON         // 15×18 @ (39, 51)
VIDEO_MISC_BUTTON       // 15×18 @ (69, 51)

// Pressed states
VIDEO_FULLSCREEN_BUTTON_PRESSED
VIDEO_1X_BUTTON_PRESSED
VIDEO_2X_BUTTON_PRESSED
VIDEO_MISC_BUTTON_PRESSED
```

### Metadata Display

Video metadata scrolls in the bottom-right section:

```swift
// Metadata string composition
let metadataString = "\(filename) - \(codec) - \(width)×\(height)"

// TEXT.bmp sprite rendering (5×6 per character)
HStack(spacing: 0) {
    ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, character in
        SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)
    }
}

// Scrolling animation (when text exceeds display width)
.offset(x: textWidth > displayWidth ? metadataScrollOffset : 0, y: 0)
.onAppear {
    if textWidth > displayWidth {
        startMetadataScrolling(textWidth: textWidth, displayWidth: displayWidth)
    }
}
```

---

## Video Playback System

### AVPlayerViewRepresentable

Bridges AppKit's AVPlayerView to SwiftUI:

```swift
// AVPlayerViewRepresentable.swift
struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none           // Use VIDEO.bmp controls
        view.videoGravity = .resizeAspect   // Maintain aspect ratio
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        view.allowsPictureInPicturePlayback = false
        view.updatesNowPlayingInfoCenter = false  // PlaybackCoordinator owns remote commands
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
```

**Remote commands are MacAmp's, not AVKit's.** A default `AVPlayerView` registers its own
Now Playing / `MPRemoteCommandCenter` handler. System pause commands (AirPods removed, case
closed, route loss) would then pause the `AVPlayer` directly, behind `VideoPlaybackController`:
the UI stays "playing", audio goes silent, and the next Play press pauses. With
`updatesNowPlayingInfoCenter = false`, media keys, AirPods and other remote commands all go
through `PlaybackCoordinator.setupRemoteCommands()` → `AudioPlayer` →
`VideoPlaybackController`, so transport state stays truthful. `VideoPlaybackController`
does not observe `AVPlayer.timeControlStatus`, so any other pause path that bypasses
MacAmp would desync the same way.

### Format Support

**Supported Video Formats:**
- MP4 (H.264, H.265/HEVC)
- MOV (QuickTime)
- M4V (iTunes Video)
- AVI (limited codecs)
- Any format supported by AVFoundation

**Audio Track Handling:**
- Video audio stays on AVPlayer (it is not routed through `AVAudioEngine`)
- 10-band EQ, preamp, balance and the visualizers apply via an in-place processing tap on the first audio track (see [Video Audio DSP Pipeline](#video-audio-dsp-pipeline))
- Volume control synchronized with main window (`AVPlayer.volume`)
- The tap is pinned to stereo, so mono is upmixed and 5.1+ downmixed before processing; multichannel output is not yet supported (issue #88)

### Media Type Switching

```swift
// AudioPlayer.swift
enum MediaType {
    case audio
    case video
}

// Detection by extension in playTrack(track:)
private func detectMediaType(url: URL) -> MediaType {
    let videoExtensions = ["mp4", "mov", "m4v", "avi"]
    return videoExtensions.contains(url.pathExtension.lowercased()) ? .video : .audio
}
```

`playTrack(track:)` tears down the outgoing media type before loading the new one:

| Transition | Teardown |
|------------|----------|
| audio → video | `engine.removeVisualizerTapIfNeeded()` |
| video → audio | `invalidateInFlightVideoLoad()`, `pauseAndDetachVideoTapIfNeeded()`, `videoPlaybackController.cleanup()`, `visualizerPipeline.stopVideoVisualization()` |
| video → video | `pauseAndDetachVideoTapIfNeeded()` (then a fresh tap is built for the new item) |

For video it then calls `startVideoLoad(track:)` (async) and
`visualizerPipeline.startVideoVisualization()`, and transitions to `.playing`; the AVPlayer
starts once the asynchronous load finishes (see [Tap Lifecycle](#tap-lifecycle)). For audio
it calls `loadAudioFile(url:)` + `play()`.

### Part 21: Unified Video Controls

`AudioPlayer` is the façade the UI talks to; for video it forwards to
`VideoPlaybackController` (`MacAmpApp/Audio/VideoPlaybackController.swift`), which owns the
`AVPlayer`, its observers and seek handling.

**Volume Synchronization:**

```swift
// AudioPlayer.swift — volume fans out to both backends
var volume: Float = 0.75 {
    didSet {
        engine?.setVolume(volume)
        videoPlaybackController.volume = volume
    }
}

// VideoPlaybackController.swift
var volume: Float = 1.0 {
    didSet { player?.volume = volume }
}
// loadVideo(...) applies it to each new player: `player?.volume = volume`
```

Persistence is call-site-driven (`commitVolumeToDefaults()` at gesture end), not in the setter.

**Time Observer Pattern:**

```swift
// VideoPlaybackController.swift — setupTimeObserver()
timeObserver = player.addPeriodicTimeObserver(
    forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
    queue: .main
) { [weak self, weak player] time in
    Task { @MainActor in
        guard let self, let player else { return }
        guard self.player === player else { return }  // ignore ticks from a replaced player
        let seconds = time.seconds
        self.currentTime = seconds
        if let item = player.currentItem, item.duration.seconds.isFinite {
            let dur = item.duration.seconds
            self.duration = dur
            self.progress = dur > 0 ? seconds / dur : 0
            self.onTimeUpdate?(seconds, dur, self.progress)
        }
    }
}

// AudioPlayer.init — mirror into the UI-bound properties (all three are stored)
videoPlaybackController.onTimeUpdate = { [weak self] time, duration, progress in
    guard let self else { return }
    self.currentTime = time
    self.currentDuration = duration
    self.playbackProgress = progress
}
```

**Cleanup:**

`VideoPlaybackController.cleanup()` cancels the metadata task, removes the time and
end-of-item observers, pauses and releases the player, and resets all playback state.
`AudioPlayer` wraps it with the tap teardown (`invalidateInFlightVideoLoad()` +
`pauseAndDetachVideoTapIfNeeded()`) and `visualizerPipeline.stopVideoVisualization()` on
`stop()` and on a video → audio switch.

**Seeking Support:**

```swift
// AudioPlayer.swift
func seek(to time: Double, resume: Bool? = nil) {
    if currentMediaType == .video {
        videoPlaybackController.seek(to: time, resume: resume, completion: videoSeekCompletion)
        return
    }
    // ... audio path
}

func seekToPercent(_ percent: Double, resume: Bool? = nil) {
    if currentMediaType == .video {
        videoPlaybackController.seekToPercent(percent, resume: resume, completion: videoSeekCompletion)
        return
    }
    // ... audio path
}
```

`VideoPlaybackController.seek` seeks with default tolerance (nearest keyframe; fast, avoids
-12860 decode errors). In the completion it ignores a stale player (identity guard), records
the actual position, and applies `resume`:

| `resume` | After seek |
|----------|------------|
| `true` | play (`isPlaying = true`, `isPaused = false`) |
| `false` | pause (`isPlaying = false`, `isPaused = true`) |
| `nil` | keep the current intent, re-read at completion time: play if `isPlaying`, else stay paused or loaded-idle (`isPaused` untouched) |

`videoSeekCompletion` then syncs `currentTime`, `playbackProgress`, `currentDuration` and the
`.playing` / `.paused` transport state back onto `AudioPlayer`. A seek also flushes the
tap's EQ filter history (see [Seek and Filter State](#seek-and-filter-state)).

**Stale-callback guards:** the end-of-item notification, periodic time observer and seek
completion all check that the player (or item) they captured is still the current one, so a
superseding `loadVideo` can't have old callbacks mutate transport state.

---

## Video Audio DSP Pipeline

Video audio stays on `AVPlayer`; it is never routed through `AVAudioEngine`. Winamp's audio
controls reach it through an in-place `MTAudioProcessingTap` attached to the
`AVPlayerItem`'s `audioMix`. The tap processes the decoded samples before AVPlayer renders
them to whatever output is current (speakers, HDMI, AirPods, AirPlay 2), so route changes
are handled by AVFoundation, not by MacAmp. Design rationale and the full decision record
(ADR-1…12): `tasks/avplayer-native-video-dsp/plan.md`.

### Signal Path

```
AVURLAsset ──▶ AVPlayerItem ──▶ AVPlayer ──▶ current output route
                   │ .audioMix (set once, before the AVPlayer exists)
                   ▼
   MTAudioProcessingTap on audioTracks.first
   (PreEffects; stereo Float32 non-interleaved at the source sample rate)
                   │
   tapProcess, per render slice (AVFoundation's tap thread):
     1. MTAudioProcessingTapGetSourceAudio
     2. format gate — process only 32-bit Float LPCM, otherwise pass through
     3. StartOfStream flag (seek / new stream) → reset EQ filter history
     4. preamp          (linear gain)
     5. 10-band EQ      (biquad cascade, only while EQ is on)
     6. balance         (gain on channel 0 = L, channel 1 = R)
     7. videoTapVisualizerRender → shared VisualizerFeed
     8. deadline telemetry on every 64th callback
```

The visualizer step runs on the already-processed buffer, so the spectrum, oscilloscope and
Milkdrop react to the EQ'd sound (see `docs/MILKDROP_WINDOW.md` §9.4 for the feed and
consumer side).

### Files

| File | Role |
|------|------|
| `MacAmpApp/Audio/VideoDSP/VideoTap.swift` | C tap callbacks (`init`/`prepare`/`process`/`unprepare`/`finalize`), `buildAudioMix`, `preferredProcessingFormat(for:)`, `detach(from:)`, `balanceGains` |
| `MacAmpApp/Audio/VideoDSP/VideoTapContext.swift` | Per-tap state shared between main and render threads: `Atomic` fields (balance, `isEqOn`, preamp, format tag, `pendingSampleRate`, telemetry), `Mutex<BiquadCoefficientSet?>`, render-confined cascade and scratch buffers |
| `MacAmpApp/Audio/VideoDSP/BiquadCascade.swift` | Render-confined 10-band Transposed Direct Form II cascade with per-channel history; `reset()` |
| `MacAmpApp/Audio/VideoDSP/BiquadCoefficientSet.swift` | RBJ cookbook coefficients; `frequencies` shared with `EqualizerController.configureEQ` |
| `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift` | Visualizer producer for video (mono mix → RMS, Goertzel, Butterchurn FFT → feed) |
| `MacAmpApp/Audio/RenderThreadSafe.swift` | Marker protocol listing which field types may be stored in the `@unchecked Sendable` context |
| `MacAmpApp/Audio/VisualizerFeed.swift`, `VisualizerScratchBuffers.swift` | Shared single-slot feed and per-tap scratch (also used by the engine tap) |
| `MacAmpApp/Audio/AudioPlayer.swift` | `startVideoLoad`, `pauseAndDetachVideoTapIfNeeded`, `invalidateInFlightVideoLoad`, balance fanout, `isVisualizerRendering` |
| `MacAmpApp/Audio/EqualizerController.swift` | EQ fanout to registered taps (`registerVideoTapContext`, `pollVideoTapSampleRates`) |
| `MacAmpApp/Audio/VideoPlaybackController.swift` | `loadVideo(url:autoPlay:audioMixBuilder:isStillRelevant:)` |

### Tap Lifecycle

One tap per `AVPlayerItem`, and the item's `audioMix` is never changed while it plays.

```
playTrack(.video)
  └─ startVideoLoad(track:)                     // bumps videoLoadGeneration
       └─ Task: videoPlaybackController.loadVideo(url:, autoPlay: false,
                  audioMixBuilder:, isStillRelevant:)
            1. cleanup() the previous player
            2. asset = AVURLAsset(url:)
            3. audioMixBuilder(asset):
                 loadTracks(.audio) → first track (none → nil, player built without a tap)
                 preferredProcessingFormat(for:) → stereo @ source rate
                 VideoTapContext(feed: visualizerPipeline.sharedFeed)
                 VideoTap.buildAudioMix(...)   // passRetained(context) → tap → AVMutableAudioMix
                 register context with EqualizerController + AudioPlayer balance registry
            4. isStillRelevant()? else abort — nothing constructed or mutated
            5. AVPlayerItem(asset:); item.audioMix = mix   // once
            6. AVPlayer(playerItem:), observers, time observer
       └─ if still current and playbackState == .playing → videoPlaybackController.play()
```

- **Staleness.** `videoLoadGeneration` is rechecked after every `await`; a superseded load
  returns before building a player. Task cancellation is advisory only (`loadTracks` does
  not honor it).
- **Context lifetime.** `buildAudioMix` retains the context (`Unmanaged.passRetained`);
  the tap's `finalize` callback releases it when AVFoundation drops the tap. If tap
  creation fails, the retain is released before throwing, and the video plays without DSP.
- **Teardown** (`pauseAndDetachVideoTapIfNeeded`): pause the player if playing, then
  `VideoTap.detach(from:)` (`audioMix = nil`), unregister from both fanout registries. The
  pause comes first so the mix is never mutated during playback.
- **Pass-through.** If the negotiated format isn't 32-bit Float LPCM, `tapProcess` returns
  the source audio untouched.

### Processing Format (Stereo Pin)

The tap is created with `MTAudioProcessingTapCreateWithPreferredFormat`, requesting stereo
Float32 non-interleaved at the source track's sample rate (`VideoTap.preferredProcessingFormat(for:)`).
If the source format can't be read it falls back to `MTAudioProcessingTapCreate`
(system-chosen format).

- A tap format that follows the output device caused audible volume pumping and cut-outs
  over AirPlay 2; pinning to the source rate removes it.
- Stereo means mono sources are upmixed and 5.1+ sources downmixed before the tap, so
  channels 0/1 are always L/R and balance moves between the left and right speakers.
- The format gate in `tapPrepare` still validates whatever format is actually negotiated.

### EQ, Preamp and Balance Fanout

State keeps its existing owners; each tap context is a read-only consumer.

| State | Owner | Path to the tap |
|-------|-------|-----------------|
| `isEqOn`, preamp, 10 band gains | `EqualizerController` | `didSet` → `fanOutToVideoTaps()` → `isEqOn` / preamp atomics + `BiquadCoefficientSet.compute(for:sampleRate:)` → `installCoefficients` (Mutex) |
| balance | `AudioPlayer` | `didSet` → `fanOutBalanceToVideoTaps()` → `balance` atomic |

- Registries hold `WeakBox<VideoTapContext>` and are pruned on each fanout; registration
  pushes current state immediately.
- Coefficients depend on the sample rate, which only `tapPrepare` knows. It publishes
  `pendingSampleRate`; `EqualizerController.pollVideoTapSampleRates()` runs on the
  visualizer's 30 Hz tick (`VisualizerPipeline.onPollTick`) and recomputes when the rate
  changes (first prepare, or a re-prepare after a route change).
- On the render thread, coefficients are read with a non-blocking `withLockIfAvailable`; on
  contention the previous coefficients are reused for that slice. The filter itself runs
  lock-free.
- The engine `AVAudioUnitEQ` and the tap cascade use the same band frequencies and gain
  law; `BiquadNumericalMatchTests` holds them within 0.5 dB.
- Turning EQ back on resets filter history first, so re-enabling does not click.

### Seek and Filter State

AVFoundation sets `kMTAudioProcessingTapFlag_StartOfStream` on the first slice after a seek
or a new stream. `tapProcess` then resets the cascade's filter history, so no ringing from
before the seek leaks into the new position.

### Route Changes

AirPods connect/disconnect, AirPlay 2, and system output switches keep the same tap and
context; AVFoundation may re-prepare the tap on the new route, and the sample-rate poll
recomputes coefficients. EQ, balance and the visualizer carry across the switch. Remote
pause/resume from AirPods (one bud out, case closed) arrives through `PlaybackCoordinator`
(see [AVPlayerViewRepresentable](#avplayerviewrepresentable)).

### Visualizer During Video

- `VideoTapContext` is created with `visualizerPipeline.sharedFeed`; the tap is the only
  producer during video (the engine mixer tap is removed on the audio → video switch).
- `startVideoVisualization()` / `stopVideoVisualization()` run the 30 Hz feed poll, because
  no engine tap is installed to start it.
- `AudioPlayer.isVisualizerRendering` (`isEngineRendering || (currentMediaType == .video && videoPlaybackController.isPlaying)`)
  gates `getFrequencyData`, `snapshotButterchurnFrame` and `VisualizerView`, so pausing the
  video freezes the visualizers.

### Telemetry

Every 64th callback times the full DSP + visualizer work against the slice's deadline
(frames ÷ sample rate). More than 10% of the deadline increments `budgetOverrunCount`; more
than 50% also increments `deadlineRiskCount` and records the host time. There is no log output;
read `VideoTapContext.diagnosticSnapshot` from LLDB.

### Known Limitations

- **Video → audio does not auto-play.** After a video, starting an audio track may need a
  manual Next/Play. Open; tracked as P-6 in `tasks/avplayer-native-video-dsp/placeholder.md`.
- **Stereo only.** 5.1+ video is downmixed to stereo, including on multichannel or spatial
  outputs. Multichannel output: issue #88.
- **First audio track only.** No audio-track picker; the tap attaches to `audioTracks.first`.
- **Pauses that bypass MacAmp desync the UI.** `VideoPlaybackController` does not observe
  `AVPlayer.timeControlStatus`.

---

## Window Focus Integration

### WindowFocusState

Tracks which window is key (active):

```swift
// WindowFocusState.swift
@Observable
final class WindowFocusState {
    private(set) var focusedWindow: WindowKind? = nil

    var isVideoKey: Bool {
        focusedWindow == .video
    }

    func setFocusedWindow(_ kind: WindowKind?) {
        focusedWindow = kind
    }
}
```

### Titlebar State Changes

The video window titlebar responds to focus changes:

```swift
// VideoWindowChromeView.swift
@Environment(WindowFocusState.self) private var windowFocusState

private var isWindowActive: Bool {
    windowFocusState.isVideoKey
}

// In body:
let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"
SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_\(suffix)", ...)
```

**Visual States:**
- **Active:** Bright blue gradient, white text
- **Inactive:** Dark gray, dimmed appearance
- **Transition:** Immediate sprite swap on focus change

---

## Window Resizing (Full Quantized Resize)

### Size2D Model (Part 21 Implementation)

```swift
// Size2D.swift - Quantized resize with 25×29px segments
struct Size2D: Codable, Equatable {
    var w: Int  // Width segments (0 = 275px base)
    var h: Int  // Height segments (0 = 116px base)

    // Presets
    static let videoMinimum = Size2D(w: 0, h: 0)   // 275×116 (matches Main/EQ)
    static let videoDefault = Size2D(w: 0, h: 4)   // 275×232 (standard VIDEO size)
    static let video2x = Size2D(w: 11, h: 12)      // 550×464 (2x default)

    // Conversion to pixels
    func toPixels() -> CGSize {
        CGSize(
            width: 275 + CGFloat(w) * 25,   // 25px width increments
            height: 116 + CGFloat(h) * 29    // 29px height increments
        )
    }
}
```

### VideoWindowSizeState Observable

```swift
// VideoWindowSizeState.swift - State management with persistence
@Observable
@MainActor
final class VideoWindowSizeState {
    var size: Size2D = .videoDefault {
        didSet { persist() }
    }

    var pixelSize: CGSize { size.toPixels() }
    var contentSize: CGSize {
        CGSize(width: pixelSize.width - 19, height: pixelSize.height - 58)
    }
    var centerWidth: CGFloat { pixelSize.width - 250 }
    var centerTileCount: Int { max(0, Int(centerWidth / 25)) }

    private func persist() {
        UserDefaults.standard.set(size.w, forKey: "videoSizeW")
        UserDefaults.standard.set(size.h, forKey: "videoSizeH")
    }
}
```

### 1x/2x Preset Buttons

Clickable overlays over baked-on sprites:

```swift
// VideoWindowChromeView.swift - Button overlays
// 1X button at (31.5, 212)
Button(action: { sizeState.size = .videoDefault }) {
    Color.clear.frame(width: 15, height: 18)
}
.position(x: 31.5, y: 212)
.focusable(false)

// 2X button at (46.5, 212)
Button(action: { sizeState.size = .video2x }) {
    Color.clear.frame(width: 15, height: 18)
}
.position(x: 46.5, y: 212)
.focusable(false)
```

### Resize Handle Implementation

```swift
// VideoWindowChromeView.swift - 20×20px drag area in bottom-right
private func buildVideoResizeHandle() -> some View {
    Color.clear
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let delta = value.translation
                    let wSegments = Int(round(delta.width / 25))
                    let hSegments = Int(round(delta.height / 29))

                    let candidate = Size2D(
                        w: max(0, startSize.w + wSegments),
                        h: max(0, startSize.h + hSegments)
                    )

                    // Show preview overlay (AppKit window)
                    if let coordinator = WindowCoordinator.shared {
                        coordinator.showVideoResizePreview(resizePreview, previewSize: candidate.toPixels())
                    }

                    // Update state (quantized)
                    withAnimation(.none) {
                        sizeState.size = candidate
                    }
                }
                .onEnded { _ in
                    WindowCoordinator.shared?.hideVideoResizePreview(resizePreview)
                    WindowCoordinator.shared?.syncVideoWindowFrame(sizeState.pixelSize)
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

### Dynamic Chrome Tiling

```swift
// Titlebar stretchy tiles - calculated dynamically
let stretchyTilesPerSide = Int(ceil(CGFloat(centerTileCount) / 2))

// Left stretchy tiles
ForEach(0..<stretchyTilesPerSide, id: \.self) { i in
    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
}

// Bottom bar center tiles
ForEach(0..<centerTileCount, id: \.self) { i in
    SimpleSpriteImage("VIDEO_BOTTOM_TILE", width: 25, height: 38)
        .position(x: 125 + 12.5 + CGFloat(i) * 25, y: bottomBarY)
}
```

### Preview Overlay (AppKit)

```swift
// WindowResizePreviewOverlay.swift - Shows preview during drag
class WindowResizePreviewOverlay {
    private var overlayWindow: NSPanel?

    func show(in parentWindow: NSWindow, previewSize: CGSize) {
        // Create borderless overlay panel
        // Draw dashed rectangle showing target size
        // Visible even when growing beyond current window bounds
    }

    func hide() {
        overlayWindow?.orderOut(nil)
    }
}
```

### Key Improvements (Part 21)

- **Full Any-to-Any Resize:** Not limited to 1x/2x presets
- **Quantized Segments:** 25×29px snapping for consistent chrome tiling
- **AppKit Preview:** Overlay visible when resizing larger (solves SwiftUI clipping)
- **No Jitter:** Preview pattern + no NSWindow spam during drag
- **Buttons Still Work:** 1x/2x as Size2D presets, not scale factors

---

## Persistence & Window Docking

### Position Persistence

Window positions are saved to UserDefaults:

```swift
// WindowCoordinator.swift
private func saveWindowPositions() {
    if let video = videoWindow {
        UserDefaults.standard.set(
            NSStringFromRect(video.frame),
            forKey: "videoWindowFrame"
        )
    }
}

private func restoreWindowPositions() {
    if let frameString = UserDefaults.standard.string(forKey: "videoWindowFrame"),
       let video = videoWindow {
        let frame = NSRectFromString(frameString)
        video.setFrame(frame, display: false)
    }
}
```

### Magnetic Docking

The video window participates in MacAmp's magnetic window snapping:

```swift
// WindowSnapManager.swift
enum WindowKind: String, CaseIterable {
    case main, equalizer, playlist, video, milkdrop

    var defaultSize: CGSize {
        switch self {
        case .video:
            return CGSize(width: 275, height: 232)
        default:
            // ... other window sizes
        }
    }
}

// Docking behavior:
// - Snaps to screen edges (10px threshold)
// - Snaps to other MacAmp windows
// - Forms window clusters
// - Maintains relative positions when dragging clusters
```

### Visibility State

```swift
// AppSettings.swift
var showVideoWindow: Bool = false {
    didSet {
        UserDefaults.standard.set(showVideoWindow, forKey: "showVideoWindow")
    }
}

// WindowCoordinator observer pattern
private func setupVideoWindowObserver() {
    videoWindowTask = Task { @MainActor [weak self] in
        guard let self else { return }

        withObservationTracking {
            _ = self.settings.showVideoWindow
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.settings.showVideoWindow {
                    self.showVideoWindow()
                } else {
                    self.hideVideoWindow()
                }
                self.setupVideoWindowObserver()
            }
        }
    }
}
```

---

## Fallback Chrome System

When VIDEO.bmp is missing from a skin, the window displays fallback chrome:

### Fallback Implementation

```swift
// WinampVideoWindow.swift
struct VideoWindowFallbackChrome<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Dark gray background (Winamp classic color)
            Color(red: 0.16, green: 0.16, blue: 0.20)
                .frame(width: 275, height: 232)

            // Gradient titlebar
            WinampTitlebarDragHandle(windowKind: .video, size: CGSize(width: 275, height: 20)) {
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.0, blue: 0.5),
                        Color(red: 0.0, green: 0.5, blue: 0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay(
                    Text("WINAMP VIDEO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )
            }

            // Content area
            content
                .frame(width: 256, height: 174)
                .position(x: 137.5, y: 107)

            // Bottom bar
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16))
                .frame(width: 275, height: 38)
                .overlay(
                    Text("No VIDEO.bmp - Using Fallback")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                )
        }
    }
}
```

### Fallback Appearance

- **Colors:** Classic Winamp 2.x dark gray palette
- **Titlebar:** Blue gradient with white text
- **Borders:** Simplified solid colors (no sprites)
- **Bottom Bar:** Dark gray with status text
- **Functionality:** Full video playback, no buttons

### Skin Detection

```swift
// SkinManager checks for VIDEO.bmp
var hasVideoSprites: Bool {
    currentSkin?.sprites["VIDEO_TITLEBAR_TOP_LEFT_ACTIVE"] != nil
}

// Usage in view
if skinManager.currentSkin?.hasVideoSprites ?? false {
    VideoWindowChromeView { content }
} else {
    VideoWindowFallbackChrome { content }
}
```

---

## Implementation Patterns

### Sprite Resolution Pattern

Never hard-code sprite names. Use semantic resolution:

```swift
// ❌ WRONG: Hard-coded sprite names
let sprite = loadBitmap("VIDEO.bmp")

// ✅ CORRECT: Semantic sprite keys
SimpleSpriteImage("VIDEO_TITLEBAR_TOP_LEFT_ACTIVE", width: 25, height: 20)
```

### Position Calculation Pattern

Use absolute positioning with .position() modifier:

```swift
// ✅ CORRECT: Absolute positioning
SimpleSpriteImage(spriteName, width: w, height: h)
    .position(x: centerX, y: centerY)  // Center point

// ❌ AVOID: Frame-based positioning (less precise)
SimpleSpriteImage(spriteName)
    .frame(width: w, height: h)
    .offset(x: offsetX, y: offsetY)
```

### Environment Injection Pattern

Pass all dependencies through environment:

```swift
// In window controller
let rootView = WinampVideoWindow()
    .environment(skinManager)
    .environment(audioPlayer)
    .environment(settings)
    // ... inject all required objects

// In view
@Environment(SkinManager.self) var skinManager
@Environment(AudioPlayer.self) var audioPlayer
```

### Observer Pattern

Use withObservationTracking for reactive updates:

```swift
private func setupSizeObserver() {
    sizeTask = Task { @MainActor [weak self] in
        guard let self else { return }

        withObservationTracking {
            _ = self.settings.videoWindowSizeMode
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resizeVideoWindow(mode: self.settings.videoWindowSizeMode)
                self.setupSizeObserver()  // Re-register
            }
        }
    }
}
```

---

## Testing Guidelines

### Manual Testing Checklist

**Window Basics:**
- [ ] V button toggles window visibility
- [ ] Ctrl+V keyboard shortcut works
- [ ] Window appears at saved position
- [ ] Window saves position on quit

**Video Playback:**
- [ ] MP4 files play correctly
- [ ] MOV files play correctly
- [ ] Audio tracks play through speakers
- [ ] Volume control affects video audio
- [ ] Play/pause/stop controls work

**Video Audio DSP:**
- [ ] EQ on/off, band drags and preamp change video audio in real time, without clicks
- [ ] Balance full left / full right / centre hits the left / right / both speakers (stereo and 5.1 sources)
- [ ] Repeated seeks/scrubs with EQ boosted: clean audio right after each seek
- [ ] Spectrum, oscilloscope and Milkdrop animate from the video's audio; pausing freezes them
- [ ] Route changes mid-video (AirPods connect/disconnect, AirPlay 2, system output switch): audio resumes, EQ still applied, lip sync intact
- [ ] AirPods one-bud-out / case close pauses through MacAmp (UI shows paused); one Play press resumes
- [ ] Video ↔ audio switches: no crash, EQ carries over (video → audio may need Next: known P-6)

**Skinning:**
- [ ] VIDEO.bmp chrome renders correctly
- [ ] Fallback chrome appears when VIDEO.bmp missing
- [ ] Active/inactive titlebar states change on focus
- [ ] Metadata text scrolls when too long

**Window Resizing:**
- [ ] Ctrl+1 switches to 1x size
- [ ] Ctrl+2 switches to 2x size
- [ ] Video content scales properly
- [ ] Window position maintained during resize

**Integration:**
- [ ] Magnetic docking to other windows
- [ ] Cluster dragging with other windows
- [ ] Always-on-top mode applies correctly
- [ ] Focus tracking updates titlebar

### Automated Testing

```swift
// Example test structure (Swift Testing)
@Test("Video window is created and shown")
@MainActor
func videoWindowCreation() throws {
    let coordinator = WindowCoordinator(...)

    // Show video window
    coordinator.settings.showVideoWindow = true

    // Verify window exists
    let window = try #require(coordinator.videoWindow)
    #expect(window.isVisible)
}

@Test("Video size mode persists")
@MainActor
func videoSizeMode() {
    let settings = AppSettings()

    // Test persistence
    settings.videoWindowSizeMode = .twoX
    #expect(UserDefaults.standard.string(forKey: "videoWindowSizeMode") == "2x")
}
```

**Video audio DSP suites** (`Tests/MacAmpTests/`, Swift Testing; run with Thread Sanitizer):

| Suite | Covers |
|-------|--------|
| `VideoTapLifecycleTests` | Context retain/release balance, tap-create failure, rapid build/attach cycles, item replacement |
| `VideoTapFanoutTests` | EQ and balance fanout to registered contexts, sample-rate poll |
| `BiquadNumericalMatchTests` | Tap cascade vs `AVAudioUnitEQ` within 0.5 dB |
| `VideoTapVisualizerRenderTests` | Video visualizer producer output |
| `VideoTapTelemetryTests` | Deadline telemetry counters |
| `VideoTapCPUBenchmarkTests` | Debug-build regression guard on DSP cost per callback |
| `VideoSeekStateMatrixTests` | `resume: true/false/nil` seek outcomes |
| `VideoTapSendableContractTests` | `VideoTapContext` stored fields stay render-thread-safe |

### Performance Testing

**Key Metrics:**
- Video decode performance (CPU usage)
- Memory usage during playback
- Window resize animation smoothness
- Sprite rendering performance

**Target Performance:**
- < 5% CPU for UI rendering
- < 30% CPU for 1080p video decode
- 60 FPS window animations
- < 50MB memory for chrome sprites

**Measured — video audio tap (Apple Silicon, Release):** `tapProcess` costs about 0.4–1.0% of
one core across 44.1 kHz stereo, 48 kHz stereo and 5.1 sources, with zero budget overruns or
deadline risks in the telemetry counters.

---

## Future Enhancements

### Planned Features

**Chrome Scaling (Priority: High)**
- Scale VIDEO.bmp sprites in 2x mode
- Implement sprite scaling pipeline
- Match main window scaling behavior

**Interactive Buttons (Priority: Medium)**
- Wire up fullscreen button to AVPlayerView
- Add context menu for video options

**Video Audio (Priority: Medium)**
- Fix video → audio auto-play (P-6)
- Multichannel (5.1+) output through the tap instead of the stereo downmix (issue #88)

**Advanced Playback (Priority: Low)**
- Subtitle support (.srt, .vtt)
- Audio track selection (the DSP tap currently attaches to the first audio track only)
- Playback speed controls
- Frame-by-frame stepping

### Technical Debt

**Current Issues:**
- Chrome remains 1x in 2x mode
- Chrome buttons other than 1x/2x are visual-only (1x/2x are clickable overlays, Part 21)
- No fullscreen mode implementation
- Limited codec support (QuickTime only)

**Refactoring Opportunities:**
- Extract metadata scrolling to reusable component
- Unify sprite scaling across all windows
- Create shared video controls component

### API Considerations

**macOS 26 (Tahoe) Opportunities:**
- New AVKit APIs for video processing
- Enhanced HDR video support
- Improved codec support
- Picture-in-Picture enhancements

---

## Appendix: Sprite Definitions

### Complete VIDEO.bmp Sprite Map

```swift
// From SkinSprites.swift
let videoSprites = [
    // Active titlebar (y: 0-20)
    Sprite(name: "VIDEO_TITLEBAR_TOP_LEFT_ACTIVE", x: 0, y: 0, width: 25, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_TOP_CENTER_ACTIVE", x: 26, y: 0, width: 100, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_STRETCHY_ACTIVE", x: 127, y: 0, width: 25, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_TOP_RIGHT_ACTIVE", x: 153, y: 0, width: 25, height: 20),

    // Inactive titlebar (y: 21-41)
    Sprite(name: "VIDEO_TITLEBAR_TOP_LEFT_INACTIVE", x: 0, y: 21, width: 25, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_TOP_CENTER_INACTIVE", x: 26, y: 21, width: 100, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_STRETCHY_INACTIVE", x: 127, y: 21, width: 25, height: 20),
    Sprite(name: "VIDEO_TITLEBAR_TOP_RIGHT_INACTIVE", x: 153, y: 21, width: 25, height: 20),

    // Side borders
    Sprite(name: "VIDEO_BORDER_LEFT", x: 127, y: 42, width: 11, height: 29),
    Sprite(name: "VIDEO_BORDER_RIGHT", x: 139, y: 42, width: 8, height: 29),

    // Bottom bar sections
    Sprite(name: "VIDEO_BOTTOM_LEFT", x: 0, y: 42, width: 125, height: 38),
    Sprite(name: "VIDEO_BOTTOM_RIGHT", x: 0, y: 81, width: 125, height: 38),
    Sprite(name: "VIDEO_BOTTOM_TILE", x: 127, y: 81, width: 25, height: 38),

    // Buttons (normal state)
    Sprite(name: "VIDEO_CLOSE_BUTTON", x: 167, y: 3, width: 9, height: 9),
    Sprite(name: "VIDEO_FULLSCREEN_BUTTON", x: 9, y: 51, width: 15, height: 18),
    Sprite(name: "VIDEO_1X_BUTTON", x: 24, y: 51, width: 15, height: 18),
    Sprite(name: "VIDEO_2X_BUTTON", x: 39, y: 51, width: 15, height: 18),
    Sprite(name: "VIDEO_MISC_BUTTON", x: 69, y: 51, width: 15, height: 18),

    // Buttons (pressed state)
    Sprite(name: "VIDEO_CLOSE_BUTTON_PRESSED", x: 148, y: 42, width: 9, height: 9),
    Sprite(name: "VIDEO_FULLSCREEN_BUTTON_PRESSED", x: 158, y: 42, width: 15, height: 18),
    Sprite(name: "VIDEO_1X_BUTTON_PRESSED", x: 173, y: 42, width: 15, height: 18),
    Sprite(name: "VIDEO_2X_BUTTON_PRESSED", x: 188, y: 42, width: 15, height: 18),
    Sprite(name: "VIDEO_MISC_BUTTON_PRESSED", x: 218, y: 42, width: 15, height: 18)
]
```

### Sprite Extraction Pipeline

```swift
// SkinLoader.swift extracts VIDEO.bmp automatically
if let videoBMP = loadBitmap("VIDEO.bmp") {
    extractSprites(from: videoBMP, definitions: videoSprites)
}

// Sprites available via semantic keys:
skinManager.currentSkin?.sprites["VIDEO_TITLEBAR_TOP_LEFT_ACTIVE"]
```

### Coordinate Reference

```
VIDEO.bmp Layout (typical 306×164):

[Active Titlebar - y:0-20]
├─ Left Cap (0,0,25,20)
├─ Center Text (26,0,100,20)
├─ Stretchy (127,0,25,20)
└─ Right Cap (153,0,25,20)

[Inactive Titlebar - y:21-41]
├─ Left Cap (0,21,25,20)
├─ Center Text (26,21,100,20)
├─ Stretchy (127,21,25,20)
└─ Right Cap (153,21,25,20)

[Chrome Components - y:42+]
├─ Bottom Left (0,42,125,38)
├─ Bottom Right (0,81,125,38)
├─ Left Border (127,42,11,29)
├─ Right Border (139,42,8,29)
└─ Bottom Tile (127,81,25,38)

[Buttons - embedded in chrome]
├─ Fullscreen (9,51,15,18)
├─ 1x Size (24,51,15,18)
├─ 2x Size (39,51,15,18)
└─ Misc (69,51,15,18)
```

---

## Summary

The MacAmp Video Window represents a complete implementation of Winamp's video playback capabilities with modern macOS integration. Through careful sprite extraction, precise positioning, and native AVPlayer integration, it provides authentic visual presentation while leveraging platform-native video decoding.

Key achievements:
- ✅ Pixel-perfect VIDEO.bmp skinning (24 sprites)
- ✅ Native video format support (MP4, MOV, M4V)
- ✅ Focus-aware chrome states (active/inactive titlebars)
- ✅ Magnetic window docking (5-window system)
- ✅ Fallback for missing sprites (classic gray chrome)
- ✅ **Full quantized resize** (25×29px segments) - Part 21
- ✅ **1x/2x preset buttons** (clickable overlays) - Part 21
- ✅ **Volume slider sync** (video audio control) - Part 21
- ✅ **Seek bar functionality** (drag to any position) - Part 21
- ✅ **Time display integration** (elapsed/remaining) - Part 21
- ✅ **Metadata ticker** (auto-scrolling filename, codec, resolution)
- ✅ **AppKit preview overlay** (resize visualization)
- ✅ **EQ, preamp and balance on video audio** (in-place `MTAudioProcessingTap`, AVPlayer kept)
- ✅ **Visualizers and Milkdrop driven by video audio** (shared `VisualizerFeed`)
- ✅ **Route-change safe** (AirPods, AirPlay 2, output switches keep the same tap)
- ✅ **MacAmp-owned remote commands** during video (AVKit Now Playing disabled)

Part 21 additions complete the video window as a fully functional media player with unified controls matching audio playback behavior. The Size2D quantized resize model enables any-to-any window sizing while maintaining pixel-perfect chrome rendering. The video audio DSP pipeline brings the Winamp EQ, balance and visualizers to video without leaving AVPlayer.

Future work focuses on fullscreen mode, subtitle support, and additional codec support. The architecture is designed for extensibility while maintaining the authentic Winamp experience that defines MacAmp.

---

**Document Version History:**
- v3.0.0 (2026-09-25): AVPlayer-native video audio DSP
  - Added Video Audio DSP Pipeline section (tap lifecycle, stereo pin, EQ/balance fanout, seek reset, route changes, visualizer, telemetry, known limitations)
  - Removed "EQ not available for video" limitation
  - Updated playback snippets to `VideoPlaybackController` and async `loadVideo`
  - Documented `updatesNowPlayingInfoCenter = false` and remote-command ownership
  - Corrected activation methods (no automatic window open)
- v2.0.0 (2025-11-15): Part 21 Video Control Unification
  - Added Size2D quantized resize documentation
  - Added volume/seek/time integration patterns
  - Added WindowCoordinator bridge patterns
  - Added @MainActor and Task { } patterns
  - Updated from scaleEffect to full resize
- v1.0.0 (2025-11-14): Initial comprehensive documentation
  - TASK 2 Days 1-6 implementation
  - VIDEO.bmp sprite system
  - Focus tracking architecture