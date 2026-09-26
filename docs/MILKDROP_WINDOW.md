# Milkdrop Window Implementation Guide

**Document Version**: 2.4.0
**Last Updated**: 2026-09-25
**Status**: Production (GEN.bmp chrome, Butterchurn visualization, segment-based resize, video-audio visualization)

---

## 1. Introduction

The Milkdrop window recreates the Winamp visualization window using GEN.bmp sprites and hosts Butterchurn.js, a WebGL port of the Milkdrop 2 engine, in a WKWebView.

### 1.1 Purpose

- **Primary**: Display Butterchurn audio visualizations synchronized with playback — local files, internet radio, and the audio track of video files
- **Secondary**: Preset cycling, randomization, and history navigation (matches Winamp behavior)
- **Tertiary**: Track title overlay display with configurable intervals

### 1.2 User Interaction

- **Open/Close**: Ctrl+K (toggles `settings.showMilkdropWindow`; matches Winamp)
- **Focus**: Click to focus, shows selected chrome state
- **Position**: Persisted across sessions in UserDefaults
- **Resize**: Drag bottom-right corner (25x29px segment grid)
- **Size**: Persisted across sessions (minimum 275x116, default 275x232, no maximum)
- **Docking**: Magnetic snapping to other MacAmp windows and screen edges
- **Context Menu** (right-click):
  - Current preset display (header)
  - Next/Previous preset navigation (Space/Backspace)
  - Randomize toggle (R key)
  - Auto-Cycle Presets toggle (C key)
  - Cycle Interval submenu (5s/10s/15s/30s/60s)
  - Show Track Title (T key)
  - Track Title Interval submenu (Once/5s/10s/15s/30s/60s)
  - Presets submenu (first 100 shown, then "... and N more")

---

## 2. Window Specifications

### 2.1 Dimensions

The window is resizable on Winamp's 25x29px segment grid (see §4.4):

| Property | Value | Notes |
|----------|-------|-------|
| Minimum Size | 275×116 | `Size2D.milkdropMinimum` [0,0], matches Main/EQ |
| Default Size | 275×232 | `Size2D.milkdropDefault` [0,4] |
| Width / Height Segment | 25px / 29px | `pixelWidth = 275 + w*25`, `pixelHeight = 116 + h*29` |
| Titlebar Height | 20px | GEN titlebar sprites |
| Bottom Bar Height | 14px | GEN bottom bar sprites |
| Left / Right Border | 11px / 8px | `GEN_MIDDLE_LEFT` / `GEN_MIDDLE_RIGHT` |
| Content Area | width − 19, height − 34 | 256×198 at the default size |

### 2.2 Sprite Source

All window chrome uses GEN.bmp sprites defined in `MacAmpApp/Models/SkinSprites.swift` (GEN section):

```swift
// Active/Selected titlebar (Y=0-19)
Sprite(name: "GEN_TOP_LEFT_SELECTED", x: 0, y: 0, width: 25, height: 20),
Sprite(name: "GEN_TOP_LEFT_END_SELECTED", x: 26, y: 0, width: 25, height: 20),
Sprite(name: "GEN_TOP_CENTER_FILL_SELECTED", x: 52, y: 0, width: 25, height: 20),
Sprite(name: "GEN_TOP_RIGHT_END_SELECTED", x: 78, y: 0, width: 25, height: 20),
Sprite(name: "GEN_TOP_LEFT_RIGHT_FILL_SELECTED", x: 104, y: 0, width: 25, height: 20),
Sprite(name: "GEN_TOP_RIGHT_SELECTED", x: 130, y: 0, width: 25, height: 20),

// Inactive titlebar (Y=21-40)
Sprite(name: "GEN_TOP_LEFT", x: 0, y: 21, width: 25, height: 20),
Sprite(name: "GEN_TOP_LEFT_END", x: 26, y: 21, width: 25, height: 20),
Sprite(name: "GEN_TOP_CENTER_FILL", x: 52, y: 21, width: 25, height: 20),
// ... etc
```

### 2.3 Coordinate Grid

At the default 275×232 size:

```
Column Grid (25px tiles):
Col 0:  X=0-24    (LEFT cap)
Col 1:  X=25-49   (LEFT_RIGHT_FILL)
Col 2:  X=50-74   (LEFT_RIGHT_FILL)
Col 3:  X=75-99   (LEFT_END)
Col 4:  X=100-124 (CENTER_FILL - text area)
Col 5:  X=125-149 (CENTER_FILL - text area)
Col 6:  X=150-174 (CENTER_FILL - text area)
Col 7:  X=175-199 (RIGHT_END)
Col 8:  X=200-224 (LEFT_RIGHT_FILL)
Col 9:  X=225-249 (LEFT_RIGHT_FILL)
Col 10: X=250-274 (RIGHT cap)

Vertical Layout:
Y=0-19:    Titlebar (drag handle)
Y=20-217:  Content area (198px)
Y=218-231: Bottom bar (14px)
```

---

## 3. Architecture

Shared window infrastructure (three-layer pattern, controller stack, focus, snapping) is described in the [Architecture Guide](MACAMP_ARCHITECTURE_GUIDE.md#milkdrop-window-architecture). Milkdrop-specific pieces:

### 3.1 Layers

- **Mechanism:** WKWebView + Butterchurn JS (`Butterchurn/`), the shared `VisualizerFeed` producers (§9.4)
- **Bridge:** `ButterchurnBridge` (Swift↔JS), `ButterchurnPresetManager`, `AudioPlayer.snapshotButterchurnFrame()`, `WindowFocusState`, `AppSettings`
- **Presentation:** `WinampMilkdropWindow`, `MilkdropWindowChromeView`, `ButterchurnWebView`

### 3.2 NSWindowController Pattern

`WinampMilkdropWindowController` (`MacAmpApp/Windows/WinampMilkdropWindowController.swift`) follows the same pattern as the Video window: a 275×232 `BorderlessWindow`, `WinampWindowConfigurator.apply(to:)`, `hasShadow = true`, an `NSHostingController` set as `contentViewController` only (setting `contentView` would release the hosting controller), then `installHitSurface(on:)`. In addition it creates and owns the `ButterchurnBridge` and `ButterchurnPresetManager`, calling `presetManager.configure(bridge:appSettings:playbackCoordinator:)`.

### 3.3 Environment Injection

- `SkinManager`: GEN.bmp sprites
- `AudioPlayer`: source of Butterchurn audio frames (`snapshotButterchurnFrame()`, see §9.4)
- `DockingController`, `AppSettings`, `RadioStationLibrary`, `PlaybackCoordinator`
- `WindowFocusState`: focus tracking for chrome state
- `ButterchurnBridge`, `ButterchurnPresetManager`: owned by the controller

---

## 4. GEN.bmp Chrome Implementation

`MilkdropWindowChromeView` (`MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`) lays out all chrome from `MilkdropWindowSizeState` (`MacAmpApp/Models/MilkdropWindowSizeState.swift`).

### 4.1 Titlebar Composition (7 Sections - Dynamic)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LEFT_CAP │ LEFT_GOLD(n) │ LEFT_END │ CENTER(3) │ RIGHT_END │ RIGHT_GOLD(n) │ RIGHT_CAP │
│   25px   │    n×25px    │   25px   │   75px    │   25px    │     n×25px    │   25px    │
└─────────────────────────────────────────────────────────────────────────┘

Fixed: LEFT_CAP + LEFT_END + RIGHT_END + RIGHT_CAP = 100px
Center: 3 grey tiles = 75px (fixed, centerGreyTileCount)
Variable: LEFT_GOLD + RIGHT_GOLD expand symmetrically (n = goldFillerTilesPerSide)
```

| Section | Sprite (`suffix` = `_SELECTED` when focused) | X position (centre) |
|---------|------|------|
| Left cap | `GEN_TOP_LEFT` | 12.5 |
| Left gold ×n | `GEN_TOP_LEFT_RIGHT_FILL` | 37.5 + i·25 |
| Left end | `GEN_TOP_LEFT_END` | `centerStart − 12.5` |
| Centre ×3 | `GEN_TOP_CENTER_FILL` | `centerStart + 12.5 + i·25` |
| Right end | `GEN_TOP_RIGHT_END` | `centerStart + 87.5` |
| Right gold ×n | `GEN_TOP_LEFT_RIGHT_FILL` | `centerStart + 112.5 + i·25` |
| Right cap (close) | `GEN_TOP_RIGHT` | width − 12.5 |

The whole titlebar is wrapped in `WinampTitlebarDragHandle(windowKind: .milkdrop, …)`; "MILKDROP HD" letters (§6) sit at `milkdropLettersCenterX`, y = 8.

```swift
// MilkdropWindowSizeState.swift
var goldFillerTilesPerSide: Int {
    let goldSpace = pixelSize.width - 100 - 75  // Fixed caps/ends (100) + center grey (75)
    let perSide = goldSpace / 2.0
    return max(0, Int(ceil(perSide / 25.0)))
}
var centerSectionStartX: CGFloat { 25 + CGFloat(goldFillerTilesPerSide) * 25 + 25 }
var milkdropLettersCenterX: CGFloat { centerSectionStartX + 37.5 }
```

**Use `ceil()`, not floor, for the gold count.** Floor division leaves a visible gap at widths where `perSide` is not a multiple of 25; `ceil()` overlaps slightly instead:

| Width | goldSpace | perSide | floor() | ceil() |
|-------|-----------|---------|---------|--------|
| 275px | 100px | 50px | 2 tiles | 2 tiles |
| 300px | 125px | 62.5px | 2 tiles (gap) | 3 tiles |
| 325px | 150px | 75px | 3 tiles | 3 tiles |

### 4.2 Side Borders

`GEN_MIDDLE_LEFT` (11×29) at x = 5.5 and `GEN_MIDDLE_RIGHT` (8×29) at x = width − 4, tiled from y = 20 + 14.5 in 29px steps; the count is `verticalBorderTileCount` (7 at the default size).

### 4.3 Bottom Bar

At y = height − 7: `GEN_BOTTOM_LEFT` (125×14) at x = 62.5, `centerTileCount` two-piece fill tiles (§5) from x = 125, and `GEN_BOTTOM_RIGHT` (125×14, contains the resize corner) at x = width − 62.5.

### 4.4 Resize Gesture

A 20×20 clear area at the bottom-right corner with `DragGesture(minimumDistance: 0)`, the same pattern as the Video window:

- **First tick:** capture `dragStartSize`, `WindowSnapManager.shared.beginProgrammaticAdjustment()`.
- **onChanged:** candidate = start + `round(dx/25)`, `round(dy/29)` segments (clamped at 0); only the AppKit `WindowResizePreviewOverlay` is updated (`resizePreview.show(in: coordinator.milkdropWindow, previewSize:)`).
- **onEnded:** commit `sizeState.size` (persists via `didSet`), `WindowCoordinator.shared?.updateMilkdropWindowSize(to:)`, hide the preview, `bridge.setSize(width:height:)` with the new content size, clear drag state, `endProgrammaticAdjustment()`.

### 4.5 Frame and Canvas Sync

- `WindowCoordinator.updateMilkdropWindowSize(to:)` forwards to `WindowResizeController.updateMilkdropWindowSize(to:)`, which rounds to integral pixels and keeps the top-left corner fixed (macOS frames are bottom-left origin).
- `ButterchurnBridge.setSize(width:height:)` calls `window.macampButterchurn?.setSize(w, h)` (guarded by `isReady`).
- `WinampMilkdropWindow.onAppear` configures the bridge with `AudioPlayer`, does the initial frame sync and the initial canvas `setSize`.

---

## 5. Two-Piece Sprite Discovery

### 5.1 The Cyan Delimiter Pattern

GEN.bmp uses cyan pixels (#00C6FF) as sprite boundary markers:

```
Normal sprite:     [SPRITE_PIXELS]
Two-piece sprite:  [TOP_PIXELS]
                   [CYAN_LINE]     ← Not part of sprite!
                   [BOTTOM_1PX]
```

### 5.2 GEN_BOTTOM_FILL Structure

```swift
// SkinSprites.swift definitions
Sprite(name: "GEN_BOTTOM_FILL_TOP", x: 127, y: 72, width: 25, height: 13),
Sprite(name: "GEN_BOTTOM_FILL_BOTTOM", x: 127, y: 87, width: 25, height: 1),

// Usage: Stack vertically with no gap (13px + 1px = 14px)
VStack(spacing: 0) {
    SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)
    SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)
}
```

Extracting the two pieces separately keeps the cyan line out of the rendered sprite. The GEN letters use the same pattern (§6).

### 5.3 Verification Process

```bash
magick GEN.png -crop 25x13+127+72 test_top.png
magick test_top.png txt:- | grep "00C6FF"   # no output = clean extraction
magick GEN.png -crop 25x1+127+87 test_bottom.png
magick test_bottom.png txt:- | grep "00C6FF"
```

---

## 6. Titlebar Letter System

### 6.1 GEN Letter Sprites

GEN.bmp contains letter sprites for titlebar text, each split into a top and bottom piece:

```
Row (Y=88-94):  Selected/active letter tops (6px)
Row (Y=95):     Selected letter bottoms (2px)
Row (Y=96-102): Normal/inactive letter tops (6px)
Row (Y=108):    Normal letter bottoms (1px)
```

### 6.2 Current Implementation

The titlebar renders the fixed text "MILKDROP HD" from `GEN_TEXT_[SELECTED_]<letter>_TOP` / `_BOTTOM` sprites defined at fixed coordinates in `SkinSprites.swift` (selected bottoms are 2px, normal 1px). Letter widths are hard-coded in `MilkdropWindowChromeView.milkdropLetters`: M=8, I=4, L=5, K=7, D=6, R=7, O=6, P=6, H=6, plus a 5px word space and a 1px gap between H and D — 67px, centred in the 75px grey section.

### 6.3 Limitation: Per-Skin Letter Extraction

Letter X positions vary between skins, so fixed coordinates can pick the wrong glyphs on skins with a different GEN.bmp layout. Dynamic extraction (scan for non-cyan pixels to find letter boundaries at load time, as webamp's `genGenTextSprites()` in `skinParser.js` does) is not implemented.

---

## 7. Focus Integration

`WindowFocusDelegate` sets `WindowFocusState.isMilkdropKey` when the window becomes key and clears it on resign. `MilkdropWindowChromeView` reads it:

```swift
@Environment(WindowFocusState.self) private var windowFocusState
private var isWindowActive: Bool { windowFocusState.isMilkdropKey }
// let suffix = isWindowActive ? "_SELECTED" : ""
```

The titlebar pieces and letters switch between normal and `_SELECTED` sprites immediately. See [Window Focus State Management](MACAMP_ARCHITECTURE_GUIDE.md#window-focus-state-management).

---

## 8. Loading and Error State

`WinampMilkdropWindow` always creates the `ButterchurnWebView` (it must exist to send `ready`). While `bridge.isReady` is false it overlays a black placeholder with "MILKDROP" and either "Loading..." or `bridge.errorMessage`; the overlay fades out (0.3 s) once ready. A transparent `RightClickCaptureView` on top captures right-clicks for the context menu.

---

## 9. Butterchurn Integration

### 9.1 Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WKWebView (ButterchurnWebView)            │
├─────────────────────────────────────────────────────────────┤
│  WKUserScript injection (atDocumentStart):                  │
│    1. butterchurn.min.js            (library, WASM built in)│
│    2. butterchurnPresets.min.js     (base preset pack)      │
│    3. butterchurnPresetsExtra.min.js (extra pack, optional) │
│  WKUserScript injection (atDocumentEnd):                    │
│    4. bridge.js  (init, preset merge, Swift↔JS interface)   │
├─────────────────────────────────────────────────────────────┤
│  index.html canvas + WebGL, 60 FPS requestAnimationFrame    │
└─────────────────────────────────────────────────────────────┘
          │ postMessage "ready"          ▲ setAudioData(spectrum, waveform)
          │   (preset names + counts)    │ loadPreset(index, transition)
          │ postMessage "loadFailed"     │ showTrackTitle(title), setSize(w, h)
          ▼                              │ start() / stop() / dispose()
┌─────────────────────────────────────────────────────────────┐
│          ButterchurnBridge (@MainActor @Observable)          │
│    isReady, presetCount, presetNames, errorMessage           │
│    onPresetsLoaded → ButterchurnPresetManager                │
│    30 FPS Task loop: audio frames to JS                      │
└─────────────────────────────────────────────────────────────┘
          ▲
          │ AudioPlayer.snapshotButterchurnFrame()
          │ (1024 FFT bins + 1024 waveform samples; nil when idle)
┌─────────────────────────────────────────────────────────────┐
│          VisualizerPipeline + VisualizerFeed (§9.4)          │
└─────────────────────────────────────────────────────────────┘
```

JS→Swift messages go through the `butterchurn` script message handler. `ready` carries preset count and names (and base/extra pack counts); on `ready` the bridge starts the audio loop and calls `onPresetsLoaded`. `loadFailed` calls `markLoadFailed`.

### 9.2 Key Implementation Files

| File | Purpose |
|------|---------|
| `MacAmpApp/ViewModels/ButterchurnBridge.swift` | Swift↔JS bridge, 30 FPS audio frames, canvas resize |
| `MacAmpApp/ViewModels/ButterchurnPresetManager.swift` | Preset cycling, history, track-title timer, persistence |
| `MacAmpApp/Views/Windows/ButterchurnWebView.swift` | WKWebView wrapper, script injection, navigation delegate |
| `MacAmpApp/Views/WinampMilkdropWindow.swift` | Main view, loading overlay, context menu |
| `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift` | GEN.bmp chrome, dynamic titlebar, resize gesture |
| `MacAmpApp/Models/MilkdropWindowSizeState.swift` | Size state (segments, persistence, titlebar layout) |
| `MacAmpApp/Windows/WinampMilkdropWindowController.swift` | Controller owning bridge + preset manager |
| `MacAmpApp/Windows/WindowResizeController.swift` | `updateMilkdropWindowSize(to:)` |
| `MacAmpApp/Audio/VisualizerPipeline.swift`, `VisualizerFeed.swift`, `VisualizerScratchBuffers.swift` | Shared audio feed (engine producer, 30 Hz poll, `snapshotButterchurnFrame()`) |
| `MacAmpApp/Audio/VideoDSP/VideoTapVisualizerRender.swift` | Video producer |
| `Butterchurn/` | `butterchurn.min.js`, `butterchurnPresets.min.js`, `butterchurnPresetsExtra.min.js`, `bridge.js`, `index.html` |

`Butterchurn/` sits at the project root and is bundled as a folder resource by `project.yml` (`path: Butterchurn`, `type: folder`, `buildPhase: resources`).

### 9.3 WKUserScript Injection Strategy

WKWebView's `<script src="...">` fails for local files, so `ButterchurnWebView.makeNSView` reads each JS file from the bundle as a string and injects it with `WKUserScript` (libraries at `.atDocumentStart`, `bridge.js` at `.atDocumentEnd`, all `forMainFrameOnly: true`; `butterchurn.min.js` is an ES module, so `loadBundleJS` rewrites its `export{X as default}` into a `window.butterchurn` global, while the preset packs are UMD and load as-is), registers the bridge as the `butterchurn` message handler, then loads `Butterchurn/index.html` with `loadFileURL(_:allowingReadAccessTo:)`. If `index.html` is missing it loads an inline fallback page with a canvas. The web view has a transparent background and is inspectable.

### 9.4 Audio Data Pipeline

**End-to-End Audio Flow (local files, streams and video):**

Butterchurn has one consumer path and two producers. Whichever producer is live
publishes pre-computed arrays into the shared `VisualizerFeed`; everything from the
feed onward is identical for audio and video.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BUTTERCHURN AUDIO DATA FLOW                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  PRODUCER A — local files + streams        PRODUCER B — video files          │
│  ┌───────────────────────────────┐         ┌───────────────────────────────┐ │
│  │ AVAudioEngine (EQ → mixer)    │         │ AVPlayer + AVPlayerItem       │ │
│  │ mainMixerNode.installTap      │         │ .audioMix MTAudioProcessingTap│ │
│  │ (2048-frame buffers)          │         │ (after EQ / preamp / balance) │ │
│  │ VisualizerPipeline            │         │ videoTapVisualizerRender()    │ │
│  │   .makeTapHandler             │         │                               │ │
│  └───────────────┬───────────────┘         └───────────────┬───────────────┘ │
│                  │  render thread: mono mix → 20× RMS, 20× Goertzel,         │
│                  │  2048-pt FFT (1024 bins) + 1024 waveform, per-tap scratch  │
│                  └──────────────┬──────────────────────────┘                  │
│                                 ▼ tryPublish() (trylock; drop on contention)  │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        VisualizerFeed (single slot, SPSC)      │            │
│                  └───────────────────────────────────────────────┘            │
│                                 │ consume() — 30 Hz main-thread poll          │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        VisualizerPipeline.swift                │            │
│                  │  butterchurnSpectrum[1024] / Waveform[1024]    │            │
│                  │  snapshotButterchurnFrame() → ButterchurnFrame │            │
│                  └───────────────────────────────────────────────┘            │
│                                 │                                             │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        AudioPlayer.snapshotButterchurnFrame()  │            │
│                  │  nil unless isVisualizerRendering              │            │
│                  └───────────────────────────────────────────────┘            │
│                                 │ (30 FPS Task loop)                          │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        ButterchurnBridge.swift                 │            │
│                  │  sendAudioFrame() → callAsyncJavaScript        │            │
│                  │  macampButterchurn.setAudioData(spec, wave)    │            │
│                  └───────────────────────────────────────────────┘            │
│                                 │ (WKWebView)                                 │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        bridge.js (JavaScript)                  │            │
│                  │  latestWaveform ← waveform                     │            │
│                  │  ScriptProcessorNode → Butterchurn analyser    │            │
│                  └───────────────────────────────────────────────┘            │
│                                 │ (60 FPS RAF)                                │
│                                 ▼                                             │
│                  ┌───────────────────────────────────────────────┐            │
│                  │        butterchurn.min.js                      │            │
│                  │  visualizer.render() → WebGL Canvas            │            │
│                  └───────────────────────────────────────────────┘            │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Producer A (engine tap).** `AudioEngineController` manages the tap
(`installVisualizerTapIfNeeded()` / `removeVisualizerTapIfNeeded()`), calling through to
`VisualizerPipeline.installTap(on:)` / `removeTap()`. Ownership chain: `AudioPlayer` →
`AudioEngineController` → `VisualizerPipeline`. Installing the tap also starts the 30 Hz
feed poll.

**Producer B (video tap).** Video audio stays on `AVPlayer`, and the engine mixer tap is
removed when playback switches to video. The video's `MTAudioProcessingTap` runs
`videoTapVisualizerRender(...)` at the end of each render callback, on the buffer it has
just processed, and publishes to the same feed via `VisualizerPipeline.sharedFeed`. Because
no engine tap is installed, the poll timer is driven separately:

| Event | Call |
|-------|------|
| Video track starts (`playTrack` `.video` branch) | `visualizerPipeline.startVideoVisualization()` |
| Repeat-one restart of a video | `startVideoVisualization()` (restart bypasses `playTrack`) |
| Video reaches end | `stopVideoVisualization()` |
| `stop()` during video, or video → audio switch | `stopVideoVisualization()` (also clears stale bars) |

Tap internals: [AVPlayer-Native Video DSP](MACAMP_ARCHITECTURE_GUIDE.md#avplayer-native-video-dsp) and
[VIDEO_WINDOW.md](VIDEO_WINDOW.md#video-audio-dsp-pipeline); why the two producers are parallel
functions rather than one generalized handler: `tasks/avplayer-native-video-dsp/plan.md` (ADR-6).

**Invariants:**
- Only one producer is live at a time, so the single-slot last-write-wins feed needs no
  producer coordination.
- Both producers see the post-EQ signal (engine tap on `mainMixerNode`, video tap after its
  in-place EQ/preamp/balance), so Milkdrop reacts to what the user hears.
- The RMS and Goertzel math in `videoTapVisualizerRender` must stay numerically identical
  to `VisualizerPipeline.makeTapHandler`; the Butterchurn FFT is shared
  (`VisualizerScratchBuffers.processButterchurnFFT`).
- `AudioPlayer.isVisualizerRendering` (`isEngineRendering`, or video with
  `videoPlaybackController.isPlaying`) gates every UI consumer: `snapshotButterchurnFrame()`,
  `getFrequencyData(bands:)` and the main-window `VisualizerView`. Pausing a video therefore
  freezes Butterchurn exactly as pausing a music track does.

**Frame Rates:**
- **Producer callbacks:** engine tap at 2048-frame buffers; the video tap at whatever slice
  size the route delivers (≈4096 frames wired, ≈1920 on Bluetooth). The FFT always runs on
  2048 points.
- **Feed poll:** 30 Hz (`Timer` in `.common` run-loop mode, so it keeps firing during drags)
- **Swift→JS updates:** 30 FPS (async `Task` loop, ~33 ms sleep)
- **WebGL rendering:** 60 FPS (requestAnimationFrame)

**30 FPS Swift→JS Audio Updates:**

```swift
// ButterchurnBridge.swift
private func startAudioUpdates() {
    guard audioUpdateTask == nil else { return }
    audioUpdateTask = Task { @MainActor [weak self] in
        while !Task.isCancelled {
            self?.sendAudioFrame()
            try? await Task.sleep(nanoseconds: 33_333_333) // ~30 FPS
        }
    }
}

private func sendAudioFrame() {
    guard isReady, let webView = webView else { return }

    // nil when nothing is rendering (idle, paused, stopped) — freeze the canvas
    guard let frame = audioPlayer?.snapshotButterchurnFrame() else {
        if isVisualizationActive {
            isVisualizationActive = false
            webView.evaluateJavaScript("window.macampButterchurn?.stop();", completionHandler: nil)
        }
        return
    }
    if !isVisualizationActive {
        isVisualizationActive = true
        webView.evaluateJavaScript("window.macampButterchurn?.start();", completionHandler: nil)
    }

    let spectrumInts = frame.spectrum.map { Int(min(255, max(0, $0 * 255))) }
    webView.callAsyncJavaScript(
        "window.macampButterchurn?.setAudioData(spectrum, waveform);",
        arguments: ["spectrum": spectrumInts, "waveform": frame.waveform],
        in: nil, in: .page, completionHandler: nil
    )
}
```

**JS side (bridge.js):** `setAudioData` copies the waveform into `latestWaveform`. A muted
`ScriptProcessorNode` (1024-frame buffer) replays that buffer into Butterchurn's internal
analyser, which derives its own spectrum (the Swift spectrum argument is currently unused).
`start()` / `stop()` toggle the 60 FPS `requestAnimationFrame` render loop.

```javascript
// bridge.js
scriptProcessor.onaudioprocess = function(e) {
    var output = e.outputBuffer.getChannelData(0);
    for (var i = 0; i < output.length; i++) {
        output[i] = latestWaveform[waveformWriteIndex];
        waveformWriteIndex = (waveformWriteIndex + 1) % latestWaveform.length;
    }
};
// scriptProcessor → muteGain(0) → destination; visualizer.connectAudio(scriptProcessor)
```

### 9.5 ButterchurnPresetManager

`ButterchurnPresetManager` (`@MainActor @Observable`) holds `presets`, `currentPresetIndex`, `isRandomize`, `isCycling`, `cycleInterval` (default 15 s), `transitionDuration` (2.7 s) and `trackTitleInterval` (0 = on request only). Settings write through to `AppSettings` in their `didSet`s.

- `nextPreset()` (needs ≥ 2 presets): random if `isRandomize` (never repeats the current preset), else sequential with wrap-around.
- `previousPreset()`: pops the current entry from `presetHistory` and re-selects the previous one without re-adding it. History is capped at 100 entries.
- `selectPreset(at:transition:addToHistory:)` calls `bridge.loadPreset(at:transition:)`.
- Cycle and track-title timers are `Timer`s added to `RunLoop.main` in `.common` mode; callbacks use `MainActor.assumeIsolated`. `cleanup()` stops both (called from `bridge.cleanup()`).

### 9.6 Context Menu Implementation

`WinampMilkdropWindow.showContextMenu(at:)` builds an `NSMenu` on right-click (from `RightClickCaptureView`), keeps it in `@State activeContextMenu` so it is not deallocated while open, and creates items with `MenuItemFactory.createMenuItem(title:keyEquivalent:modifiers:action:)` (closure-to-selector bridge via `MenuActionTarget`, `MacAmpApp/Utilities/`). Items are listed in §1.2. The menu is shown with `menu.popUp(positioning: nil, at: location, in: nil)`.

### 9.7 Pitfalls

- **Guard every Swift→JS call** on `isReady` and a live `webView` (`sendAudioFrame`, `loadPreset`, `showTrackTitle`, `setSize`, `pauseRendering`/`resumeRendering`); calls before `ready` or after a failure go to a dead page.
- **Surface WebView failures.** `ButterchurnWebView.Coordinator` (`WKNavigationDelegate`) routes `didFail`, `didFailProvisionalNavigation` and `webViewWebContentProcessDidTerminate` to `bridge.markLoadFailed`, which clears `isReady` and the preset list, sets `errorMessage` and stops the audio loop. `bridge.js` can also post `loadFailed`.
- **Pass per-frame data as arguments.** Audio frames use `callAsyncJavaScript(_:arguments:in:in:)` with typed arguments rather than string interpolation; `showTrackTitle` JSON-encodes the title so quotes, newlines and Unicode are safe.
- **Timers on the main run loop in `.common` mode** with `MainActor.assumeIsolated`, so they keep firing during drags and stay main-actor-correct.
- **Break the retain cycle.** `dismantleNSView` removes the `butterchurn` script message handler and calls `bridge.cleanup()` (stops the audio loop and preset timers, calls JS `dispose()`, drops the web view).
- **`ceil()` for titlebar filler tiles** (§4.1).

### 9.8 Persistence Pattern

`AppSettings` persists Butterchurn settings with `didSet` → UserDefaults: `butterchurnRandomize` (default true), `butterchurnCycling` (true), `butterchurnCycleInterval` (15.0; a saved 0 falls back to 15), `butterchurnTrackTitleInterval` (0). Window size is persisted by `MilkdropWindowSizeState` (§10.1).

### 9.9 Track Title Display

`ButterchurnPresetManager.trackTitleInterval` > 0 starts a repeating timer that shows the title immediately and then every interval; 0 means only "Show Track Title" (T) shows it. `showCurrentTrackTitle()` reads `playbackCoordinator.displayTitle` and calls `bridge.showTrackTitle(_:)`, which calls `window.macampButterchurn.showTrackTitle(title)`; bridge.js runs Butterchurn's `visualizer.launchSongTitleAnim(title)`.

### 9.10 WASM Rendering Mode Configuration

`bridge.js` creates the visualizer with `width`/`height` from the canvas, `pixelRatio: window.devicePixelRatio || 1` and `textureRatio: 1`, without `onlyUseWASM`, so Butterchurn uses WASM with a JavaScript fallback (hybrid mode). `butterchurn.min.js` includes the WASM code (no separate `.wasm` file) and auto-detects support.

| Mode | Security | Compatibility |
|------|----------|---------------|
| Hybrid (current) | JS fallback less sandboxed; acceptable inside WKWebView's sandbox | Works everywhere |
| WASM-only (`onlyUseWASM: true`) | Memory-sandboxed | Fails without WASM |

Hybrid is kept because WKWebView already sandboxes the content, every supported macOS has WASM, and hybrid degrades gracefully. Switching is a one-line option change in `createVisualizer`.

---

## 10. Persistence & Docking

### 10.1 Window Position and Size Persistence

- **Frame:** saved for all windows by `WindowFramePersistence` via `WindowFrameStore` under UserDefaults key `WindowFrame.milkdrop` (debounced 150 ms after geometry changes; suppressed during programmatic moves).
- **Size (segments):** `MilkdropWindowSizeState.size.didSet` saves `["width": Int, "height": Int]` under `milkdropWindowSize`; `loadSize()` restores it clamped to `milkdropMinimum`, defaulting to `milkdropDefault`.

### 10.2 Magnetic Docking

The window is registered with `WindowSnapManager` as `WindowKind.milkdrop`: it snaps to screen edges and other MacAmp windows within `SnapUtils.SNAP_DISTANCE` (15px), forms clusters and moves with them. See [Window Snap Manager](MACAMP_ARCHITECTURE_GUIDE.md#window-snap-manager).

### 10.3 Window Lifecycle

Ctrl+K (or the Options menu item) toggles `AppSettings.showMilkdropWindow` (persisted). `WindowSettingsObserver` observes it and `WindowCoordinator` calls `showMilkdrop()` (`makeKeyAndOrderFront`) or `hideMilkdrop()` (`orderOut`) through `WindowVisibilityController`. Hiding orders the window out; the controller, bridge and web view are not torn down.

---

## 11. Testing

**Chrome and focus**
- Ctrl+K opens/closes; `_SELECTED` sprites when focused, normal sprites after clicking another window
- Titlebar sections align with no gaps at several widths (e.g. 275, 300, 325px); side borders and bottom bar tile correctly; close button in place
- Resize drag shows the preview, snaps to 25×29 steps, and the Butterchurn canvas follows
- Position and size persist across relaunch; magnetic docking and titlebar drag work
- Test with the default skin, classic skins and skins with different GEN.bmp layouts (letters may render wrongly, §6.3)

**Audio sources** (window open)
- Local file: visuals react to the music; pause freezes the canvas, play resumes it
- Internet radio: visuals react to the stream
- Video file: visuals react to the video's audio; pause freezes, seek keeps animating
- Change EQ bands while a video plays: visuals follow the EQ'd sound
- Video → audio and audio → video switches: no stale frame, no stuck canvas
- Toggle Milkdrop and cycle main-window visualizer modes during video: no glitch

Automated coverage for the video producer: `Tests/MacAmpTests/VideoTapVisualizerRenderTests.swift`.

### 11.1 WKWebView Console Errors (Non-Fatal)

On macOS 26 (Tahoe) and later, the WKWebView hosting Butterchurn logs non-fatal WebKit/system errors that do not affect rendering or audio reception and need no code change:

| Error Source | Message (excerpt) | Impact |
|---|---|---|
| pasteboard | `Failed to get or set pasteboard data` | None -- no clipboard use |
| launchservicesd | `LSApplicationProxy ... requires update` | None -- system service noise |
| RunningBoard | `Connection to service ... interrupted` | None -- process management noise |
| Metal | `Shader compilation warning` / `GPU validation` | None -- WebGL shaders compile successfully |

Root cause: WebKit bug [302212](https://bugs.webkit.org/show_bug.cgi?id=302212) — the WebContent process emits spurious diagnostics for pasteboard access, launch services queries and Metal shader compilation (not seen on macOS 15).

---

## 12. Future Work

- **Visualization:** native Metal renderer (port from WebGL), projectM integration for native `.milk` presets, custom preset editor
- **Titlebar text:** per-skin GEN letter extraction by pixel scanning (§6.3); preset names in the titlebar
- **Audio analysis:** beat detection (BPM), multi-band analysis, audio-reactive preset selection. Current input is a 2048-point FFT (1024 bins) + 1024-sample waveform from the engine or video tap (§9.4)

Historical research and plans: `tasks/stale/milk-drop-video-support/`, `tasks/done/milkdrop-window-resize/`.

---

**Version History:**
- v2.4.0 (2026-09-25): Pruned; review-history and phase logs removed; snippets checked against code
- v2.3.0 (2026-09-25): Video audio drives Butterchurn via the shared `VisualizerFeed`
- Segment-based window resize (Size2D, 7-section dynamic titlebar, `ceil()` tile fix)
- Butterchurn integration (WKUserScript injection, 30 FPS bridge, preset manager, context menu, track title)
- Initial GEN.bmp chrome and two-piece sprite discovery
