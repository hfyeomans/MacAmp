# MacAmp Video Window Documentation

**Version:** 3.1.0
**Last Updated:** 2026-09-25
**Status:** Production (VIDEO.bmp chrome, quantized resize, AVPlayer-native video audio DSP)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Window Specifications](#window-specifications)
3. [Architecture Overview](#architecture-overview)
4. [Chrome Components](#chrome-components)
5. [Video Playback System](#video-playback-system)
6. [Video Audio DSP Pipeline](#video-audio-dsp-pipeline)
7. [Window Focus Integration](#window-focus-integration)
8. [Window Resizing](#window-resizing)
9. [Persistence & Window Docking](#persistence--window-docking)
10. [Fallback Chrome System](#fallback-chrome-system)
11. [Testing Guidelines](#testing-guidelines)
12. [Future Enhancements](#future-enhancements)
13. [Appendix: Sprite Definitions](#appendix-sprite-definitions)

---

## Introduction

The Video Window plays local video files through AVPlayer inside VIDEO.bmp-skinned chrome, following the Winamp 5.x integrated video model.

### Purpose

- **Video Playback:** Native macOS video rendering via AVPlayer
- **Winamp Audio Controls on Video:** 10-band EQ, preamp, balance, spectrum/oscilloscope and Milkdrop all apply to the video's audio (in-place processing tap, see [Video Audio DSP Pipeline](#video-audio-dsp-pipeline))
- **Skinned Chrome:** Pixel-perfect VIDEO.bmp sprite rendering
- **Seamless Integration:** Works with MacAmp's 5-window system
- **Format Support:** MP4, MOV, M4V, and other QuickTime-compatible formats

### Activation Methods

1. **V Button:** Click the "V" button on the main window (toggles `settings.showVideoWindow`)
2. **Keyboard:** Press `Ctrl+V` to toggle window visibility
3. **Menu:** Options → Show/Hide Video Window
4. **Playlist:** Playing a video file does not open the window automatically (open it with V / Ctrl+V); while open with no video loaded it shows "No video loaded"

---

## Window Specifications

### Dimensions

Default size is 275×232 (matches the Playlist default). Chrome sizes come from `VideoWindowLayout` in `VideoWindowChromeView.swift`:

| Part | Size |
|------|------|
| Titlebar | 20 px high (draggable) |
| Bottom bar | 38 px high; 125 px fixed left + 125 px fixed right sections |
| Left / right border | 11 px / 8 px wide |
| Content area | `pixelSize - (19, 58)` → 256×174 at the default size |

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

- **Source:** `VIDEO.bmp` in the skin archive
- **Dimensions:** Variable (typically 306×164 or similar)
- **Color Depth:** 8-bit indexed (Winamp palette)
- **Required:** No (default-skin sprites or fallback chrome are used)

---

## Architecture Overview

Shared window infrastructure (controller stack, three-layer pattern, focus) is documented in the [Architecture Guide](MACAMP_ARCHITECTURE_GUIDE.md#video-window-architecture); this section lists what is specific to the video window.

### Window Controller Pattern

`WinampVideoWindowController` (`MacAmpApp/Windows/WinampVideoWindowController.swift`) creates a 275×232 `BorderlessWindow`, applies `WinampWindowConfigurator.apply(to:)`, enables the shadow, hosts `WinampVideoWindow` in an `NSHostingController` set as `contentViewController` (never `contentView`, which would release the hosting controller), then calls `WinampWindowConfigurator.installHitSurface(on:)`. It injects `SkinManager`, `AudioPlayer`, `DockingController`, `AppSettings`, `RadioStationLibrary`, `PlaybackCoordinator` and `WindowFocusState` into the environment.

### Five-Window System Integration

The video window is one of the five windows owned by `WindowCoordinator` (Main, Equalizer, Playlist, Video, Milkdrop). Like the others it has its own `NSWindowController`, shares environment objects, participates in magnetic docking, persists its frame and tracks focus.

### Layer Architecture

Following the [three-layer pattern](MACAMP_ARCHITECTURE_GUIDE.md#three-layer-architecture-deep-dive):

1. **Mechanism:** AVPlayer, AVPlayerView, `VideoPlaybackController` (AVPlayer lifecycle, observers, seek), `VideoTap` + `VideoTapContext` + `BiquadCascade` (in-place audio DSP on the render thread)
2. **Bridge:** `AVPlayerViewRepresentable`, `AudioPlayer` (media-type routing, `startVideoLoad`, balance fanout), `EqualizerController` (EQ fanout)
3. **Presentation:** `VideoWindowChromeView`, `WinampVideoWindow`

---

## Chrome Components

All chrome is laid out in `VideoWindowChromeView` with absolute `.position()` and tile counts from `VideoWindowSizeState`, so it follows the window size.

### Titlebar System

Four sprites per focus state (`suffix` = `ACTIVE` / `INACTIVE`):

| Sprite | Size | Placement |
|--------|------|-----------|
| `VIDEO_TITLEBAR_TOP_LEFT_<suffix>` | 25×20 | left cap, x = 12.5 |
| `VIDEO_TITLEBAR_STRETCHY_<suffix>` | 25×20 | `stretchyTilesPerSide` tiles each side of the centre |
| `VIDEO_TITLEBAR_TOP_CENTER_<suffix>` | 100×20 | "WINAMP VIDEO", centred at `pixelSize.width / 2` |
| `VIDEO_TITLEBAR_TOP_RIGHT_<suffix>` | 25×20 | right cap, x = width − 12.5 |

`stretchyTilesPerSide = ceil((width − 50 − 100) / 2 / 25)` (3 at 275 px; overlap is fine). Left tiles start at x = 37.5; right tiles start at `centerX + 50`. The whole titlebar is wrapped in `WinampTitlebarDragHandle(windowKind: .video, …)`.

### Border System

`VIDEO_BORDER_LEFT` (11×29) and `VIDEO_BORDER_RIGHT` (8×29) are tiled vertically from y = 20; `verticalBorderTileCount = ceil((height − 58) / 29)`.

### Bottom Bar

- `VIDEO_BOTTOM_LEFT` (125×38, baked-on buttons) at the left, `VIDEO_BOTTOM_RIGHT` (125×38, metadata area) at the right, and `centerTileCount = Int(max(0, width − 250) / 25)` copies of `VIDEO_BOTTOM_TILE` (25×38) starting at x = 125.
- Baked-on buttons: fullscreen, 1x, 2x, misc (normal and `_PRESSED` sprites exist). Only **1x** and **2x** are clickable (transparent overlays, see [1x/2x Preset Buttons](#1x2x-preset-buttons)); the others are visual only.

### Metadata Display

`audioPlayer.videoMetadataString` (from `VideoPlaybackController.metadataString`, built by `MetadataLoader.VideoMetadata.displayString`) has the Winamp form `filename (M4V): Video: 1280x720` (or `Video: Unknown`). It is drawn with TEXT.bmp `CHARACTER_<ascii>` sprites (5×6, letters mapped to lowercase codes) in a 160 px clipped box at x = width − 110. When wider than the box, a `Timer` (0.15 s, `.common` run-loop mode so it keeps running during gestures) scrolls it 5 px per tick and wraps; the timer resets when the string changes and is invalidated on disappear.

---

## Video Playback System

### AVPlayerViewRepresentable

`AVPlayerViewRepresentable` wraps `AVPlayerView` with `controlsStyle = .none`, `videoGravity = .resizeAspect`, fullscreen/sharing buttons and PiP disabled, and `updatesNowPlayingInfoCenter = false`. `updateNSView` swaps the player only when the instance changes.

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

`AudioPlayer.detectMediaType(url:)` classifies by extension: `mp4`, `mov`, `m4v`, `avi` → `.video`, everything else → `.audio`.

`playTrack(track:)` tears down the outgoing media type before loading the new one:

| Transition | Teardown |
|------------|----------|
| audio → video | `engine.removeVisualizerTapIfNeeded()` |
| video → audio | `invalidateInFlightVideoLoad()`, `pauseAndDetachVideoTapIfNeeded()`, `videoPlaybackController.cleanup()`, `visualizerPipeline.stopVideoVisualization()` |
| video → video | `pauseAndDetachVideoTapIfNeeded()` (then a fresh tap is built for the new item) |

For video it then calls `startVideoLoad(track:)` (async) and
`visualizerPipeline.startVideoVisualization()`, and transitions to `.playing`; the AVPlayer
starts once the asynchronous load finishes. For audio it calls `loadAudioFile(url:)` + `play()`.

### Unified Video Controls

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

`AudioPlayer.seek(to:resume:)` and `seekToPercent(_:resume:)` forward to
`videoPlaybackController.seek` / `seekToPercent` (with `completion: videoSeekCompletion`)
when `currentMediaType == .video`. `VideoPlaybackController.seek` seeks with default
tolerance (nearest keyframe; fast, avoids -12860 decode errors). In the completion it
ignores a stale player (identity guard), records the actual position, and applies `resume`:

| `resume` | After seek |
|----------|------------|
| `true` | play (`isPlaying = true`, `isPaused = false`) |
| `false` | pause (`isPlaying = false`, `isPaused = true`) |
| `nil` | keep the current intent, re-read at completion time: play if `isPlaying`, else stay paused or loaded-idle (`isPaused` untouched) |

`videoSeekCompletion` then syncs `currentTime`, `playbackProgress`, `currentDuration` and the
`.playing` / `.paused` transport state back onto `AudioPlayer`. A seek also flushes the
tap's EQ filter history, so no ringing from before the seek leaks into the new position.

**Stale-callback guards:** the end-of-item notification, periodic time observer and seek
completion all check that the player (or item) they captured is still the current one, so a
superseding `loadVideo` can't have old callbacks mutate transport state.

---

## Video Audio DSP Pipeline

Video audio stays on `AVPlayer`; it is never routed through `AVAudioEngine`. Winamp's audio
controls reach it through an in-place `MTAudioProcessingTap` on the `AVPlayerItem`'s
`audioMix`, which processes decoded samples before AVPlayer renders them to the current
output (speakers, HDMI, AirPods, AirPlay 2). Internals (render path, biquad EQ, fanout,
concurrency contract, telemetry) are in the Architecture Guide:
[AVPlayer-Native Video DSP](MACAMP_ARCHITECTURE_GUIDE.md#avplayer-native-video-dsp). Code:
`MacAmpApp/Audio/VideoDSP/`. Decision record: `tasks/avplayer-native-video-dsp/plan.md`.

**What the user gets**

- Preamp, 10-band EQ and balance change video audio in real time; turning EQ back on resets
  filter history first, so it does not click. The tap's EQ matches the engine `AVAudioUnitEQ`
  within 0.5 dB (`BiquadNumericalMatchTests`).
- Spectrum, oscilloscope and Milkdrop are driven by the processed (post-EQ, post-balance)
  video audio through the shared `VisualizerFeed`; pausing the video freezes them
  (`AudioPlayer.isVisualizerRendering`). See [MILKDROP_WINDOW.md §9.4](MILKDROP_WINDOW.md#94-audio-data-pipeline)
  for the consumer side.
- Route changes (AirPods connect/disconnect, AirPlay 2, system output switch) keep the same
  tap; EQ, balance and the visualizer carry across. Remote pause/resume from AirPods arrives
  through `PlaybackCoordinator` (see [AVPlayerViewRepresentable](#avplayerviewrepresentable)).
- Seeks and new streams flush the EQ filter history (`StartOfStream` flag).

**Invariants that affect the window**

- One tap per `AVPlayerItem`; `audioMix` is set before the `AVPlayer` is constructed and is
  never mutated while playing. Teardown (`pauseAndDetachVideoTapIfNeeded`) pauses first, then
  detaches the mix and unregisters the tap context.
- Loads are asynchronous and generation-checked (`videoLoadGeneration`): a superseded load
  never builds a player, and auto-play happens only if the load is still current and
  `playbackState == .playing`.
- A video with no audio track plays without a tap; if tap creation fails, the video plays
  without DSP. A non-Float32 negotiated format passes through untouched.
- The tap format is pinned to stereo Float32 at the source sample rate (a device-following
  format caused volume pumping over AirPlay 2), so channels 0/1 are always L/R for balance.
- Video volume is `AVPlayer.volume`, not applied in the tap.

**Measured cost** (Apple Silicon, Release): `tapProcess` about 0.4–1.0% of one core across
44.1 kHz stereo, 48 kHz stereo and 5.1 sources, with zero budget overruns or deadline risks.
Telemetry is read from `VideoTapContext.diagnosticSnapshot` in LLDB (nothing is logged).

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

`WindowFocusState` (`@MainActor @Observable`) holds one Bool per window (`isMainKey`, `isEqualizerKey`, `isPlaylistKey`, `isVideoKey`, `isMilkdropKey`). `WindowFocusDelegate` sets `isVideoKey` when the video window becomes key and clears it on resign. `VideoWindowChromeView` reads it:

```swift
@Environment(WindowFocusState.self) private var windowFocusState
private var isWindowActive: Bool { windowFocusState.isVideoKey }
// titlebar: let suffix = isWindowActive ? "ACTIVE" : "INACTIVE"
```

Active shows the skin's bright titlebar, inactive the dimmed one; the sprite swap is immediate. See [Window Focus State Management](MACAMP_ARCHITECTURE_GUIDE.md#window-focus-state-management).

---

## Window Resizing

The window resizes any-to-any in quantized 25×29 px segments, so chrome tiles always fit.

### Size2D Model

`Size2D` (`MacAmpApp/Models/Size2D.swift`) stores `width` / `height` in segments on a shared 275×116 base (`toPixels()` = `275 + width*25`, `116 + height*29`), with `clamped(min:max:)`. Video presets:

| Preset | Segments | Pixels |
|--------|----------|--------|
| `videoMinimum` | [0,0] | 275×116 (matches Main/EQ) |
| `videoDefault` | [0,4] | 275×232 |
| `video2x` | [11,12] | 550×464 |

### VideoWindowSizeState Observable

`VideoWindowSizeState` (`@MainActor @Observable`, owned as `@State` by `WinampVideoWindow`) holds `size` and derives `pixelSize`, `contentSize`, `centerWidth`, `centerTileCount`, `stretchyTilesPerSide`, `titlebarTileDistribution` and `verticalBorderTileCount`. `size.didSet` persists to UserDefaults key `videoWindowSize` as `["width": Int, "height": Int]`; `init` loads and clamps to `videoMinimum` (default `videoDefault`).

### 1x/2x Preset Buttons

Transparent 15×18 `Button` overlays (`.buttonStyle(.plain)`, `.focusable(false)`) sit over the baked-on sprites at x = 31.5 (1x → `.videoDefault`) and x = 46.5 (2x → `.video2x`), y = `bottomBarY`. Each wraps the change in `WindowSnapManager.shared.beginProgrammaticAdjustment()` / `endProgrammaticAdjustment()` and calls `WindowCoordinator.shared?.updateVideoWindowSize(to:)`.

### Resize Handle Implementation

A 20×20 clear area at the bottom-right corner with `DragGesture(minimumDistance: 0)`:

- **First tick:** capture `dragStartSize`, call `beginProgrammaticAdjustment()`.
- **onChanged:** compute `Size2D(width: max(0, start.width + round(dx/25)), height: max(0, start.height + round(dy/29)))` and only update the AppKit preview via `coordinator.showVideoResizePreview(resizePreview, previewSize:)`. `sizeState` is **not** changed during the drag.
- **onEnded:** commit `sizeState.size`, call `coordinator.updateVideoWindowSize(to:)` with rounded pixels, hide the preview, clear drag state, `endProgrammaticAdjustment()`.

Committing only at the end avoids calling `setFrame` on every drag tick (the jitter source). `WinampVideoWindow.onAppear` does one initial frame sync.

### Preview Overlay (AppKit)

`WindowResizePreviewOverlay` (`MacAmpApp/Utilities/WindowResizePreviewOverlay.swift`) shows a borderless `.floating` `NSWindow` outlining the target size. Because it is a separate window it stays visible when growing beyond the current bounds (a SwiftUI overlay would be clipped). `hide()` orders it out.

---

## Persistence & Window Docking

### Position Persistence

Frames are saved for every window by `WindowFramePersistence` (`MacAmpApp/Windows/`) through `WindowFrameStore`, under UserDefaults key `WindowFrame.video`. Geometry-change notifications schedule a debounced flush (150 ms); programmatic moves suppress persistence. The window's size in segments is persisted separately by `VideoWindowSizeState`.

### Magnetic Docking

The window is registered with `WindowSnapManager` as `WindowKind.video`: it snaps to screen edges and other MacAmp windows within `SnapUtils.SNAP_DISTANCE` (15 px), joins clusters and moves with them. Double-size mode does not scale the video window; `WindowResizeController` repositions it to stay docked. See [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager).

### Visibility State

`AppSettings.showVideoWindow` persists via `didSet` (key `showVideoWindow`). `WindowSettingsObserver.observeShowVideo()` watches it with recursive `withObservationTracking` and calls `WindowCoordinator`'s `onShowVideoChanged` handler, which calls `showVideo()` (only once the initial windows have been presented) or `hideVideo()`.

---

## Fallback Chrome System

`WinampVideoWindow` checks `skinManager.currentSkin?.hasVideoSprites`, a `Skin` extension that tests for `VIDEO_TITLEBAR_TOP_CENTER_ACTIVE` in the skin's images (which may come from the skin itself or the default Winamp fallback sprites). If present it uses `VideoWindowChromeView`; otherwise `VideoWindowFallbackChrome`:

- Dark gray background (`0.16, 0.16, 0.20`), sized from the same `VideoWindowSizeState`
- Draggable blue gradient titlebar (`WinampTitlebarDragHandle`) with "WINAMP VIDEO" text
- Solid-colour side borders; bottom bar reading "No VIDEO.bmp - Using Fallback"
- Content placeholder "Video Window (No VIDEO.bmp)"; no buttons or resize handle

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
- [ ] 1x button restores 275×232; 2x button gives 550×464
- [ ] Corner drag resizes in 25×29 steps with the preview outline; chrome tiles fill the width
- [ ] Video content scales properly
- [ ] Window position maintained during resize

**Integration:**
- [ ] Magnetic docking to other windows
- [ ] Cluster dragging with other windows
- [ ] Always-on-top mode applies correctly
- [ ] Focus tracking updates titlebar

### Automated Testing

Video audio DSP suites (`Tests/MacAmpTests/`, Swift Testing; run with Thread Sanitizer):

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

Window geometry is covered by `WindowFrameStoreTests` and `WindowDockingGeometryTests`.

---

## Future Enhancements

**Current gaps:**
- Chrome stays 1x in double-size mode (no VIDEO.bmp sprite scaling)
- Chrome buttons other than 1x/2x are visual only; no fullscreen mode
- Codec support is whatever AVFoundation decodes

**Planned:**
- Chrome scaling for double-size mode, matching the main window
- Wire the fullscreen button to `AVPlayerView`; context menu for video options
- Fix video → audio auto-play (P-6); multichannel (5.1+) output through the tap (issue #88)
- Subtitles (.srt, .vtt), audio-track selection, playback speed, frame stepping

---

## Appendix: Sprite Definitions

### Complete VIDEO.bmp Sprite Map

Defined in `MacAmpApp/Models/SkinSprites.swift` (VIDEO sheet) and extracted with the rest of the skin; views reference them by these keys:

```swift
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
Sprite(name: "VIDEO_MISC_BUTTON_PRESSED", x: 218, y: 42, width: 15, height: 18),
```

---

**Document Version History:**
- v3.1.0 (2026-09-25): Pruned; DSP internals moved to the Architecture Guide; snippets replaced with current code
- v3.0.0 (2026-09-25): AVPlayer-native video audio DSP (EQ, preamp, balance, visualizers on video audio)
- v2.0.0 (2025-11-15): Size2D quantized resize; unified volume/seek/time controls
- v1.0.0 (2025-11-14): Initial documentation (VIDEO.bmp sprites, focus tracking)
