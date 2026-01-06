# Milkdrop Window Implementation Guide

**Document Version**: 2.1.0
**Last Updated**: 2026-01-06
**Implementation**: Days 7-8 of TASK 2 (milk-drop-video-support) + Butterchurn Integration + Window Resize
**Status**: ✅ PRODUCTION - Complete with Butterchurn visualization and resizable window

---

## 1. Introduction

The Milkdrop window provides audio visualization capabilities in MacAmp, faithfully recreating the Winamp visualization window using GEN.bmp sprites. This window hosts the legendary Milkdrop visualizer via Butterchurn.js - a WebGL port of the original Milkdrop 2 visualization engine.

### 1.1 Purpose

- **Primary**: Display Butterchurn audio visualizations synchronized with music playback
- **Secondary**: Preset cycling, randomization, and history navigation (matches Winamp behavior)
- **Tertiary**: Track title overlay display with configurable intervals
- **Current State**: ✅ Complete with Butterchurn.js integration (7 phases)

### 1.2 User Interaction

- **Open/Close**: Ctrl+K keyboard shortcut (matches Winamp)
- **Focus**: Click to focus, shows selected chrome state
- **Position**: Persisted across sessions in UserDefaults
- **Resize**: Drag bottom-right corner (25x29px segment grid)
- **Size**: Persisted across sessions (minimum 275x116, default 275x232)
- **Docking**: Magnetic snapping to other MacAmp windows and screen edges
- **Context Menu** (right-click):
  - Current preset display (header)
  - Next/Previous preset navigation (Space/Backspace)
  - Randomize toggle (R key)
  - Auto-Cycle Presets toggle (C key)
  - Cycle Interval submenu (5s/10s/15s/30s/60s)
  - Show Track Title (T key)
  - Track Title Interval submenu (Once/5s/10s/15s/30s/60s)
  - Presets submenu (up to 100 shown)

### 1.3 Implementation Timeline

- **Days 1-6**: Video window implementation (complete)
- **Day 7**: GEN sprite research and two-piece discovery
- **Day 8**: Milkdrop window chrome implementation
- **Butterchurn Integration** (7 phases):
  - Phase 1: WKWebView lifecycle and Butterchurn setup
  - Phase 2: ButterchurnBridge Swift→JS audio pipeline
  - Phase 3: Preset loading from butterchurnPresets.min.js
  - Phase 4: Context menu with preset navigation
  - Phase 5: ButterchurnPresetManager (cycling, randomization, history)
  - Phase 6: Oracle A-grade fixes (error handling, thread safety)
  - Phase 7: Track title interval display feature
- **Window Resize** (7 phases, branch `feature/milkdrop-window-resize`):
  - Phase 1: Size2D presets + MilkdropWindowSizeState foundation
  - Phase 2: Size state wiring + WindowCoordinator + ButterchurnBridge sync
  - Phase 3: Dynamic chrome layout (7-section titlebar)
  - Phase 4: Resize gesture with AppKit preview overlay
  - Phase 5: WindowCoordinator.updateMilkdropWindowSize() (bundled in Phase 2)
  - Phase 6: ButterchurnBridge.setSize() canvas sync (bundled in Phase 2)
  - Phase 7: Titlebar tile gap fix using ceil() (Pattern 9)

---

## 2. Window Specifications

### 2.1 Dimensions

The MILKDROP window is **resizable** using Winamp's 25x29px segment grid system:

```swift
// Size constraints (segment-based resizing)
static let minimumSize = CGSize(width: 275, height: 116)  // Size2D[0,0]
static let defaultSize = CGSize(width: 275, height: 232)  // Size2D[0,4]

// Segment dimensions (matches Video/Playlist)
static let widthSegment: CGFloat = 25   // Horizontal resize increment
static let heightSegment: CGFloat = 29  // Vertical resize increment

// Component dimensions (fixed chrome)
static let titlebarHeight: CGFloat = 20   // GEN titlebar sprites
static let bottomBarHeight: CGFloat = 14  // GEN bottom bar sprites
static let leftBorderWidth: CGFloat = 11  // GEN_MIDDLE_LEFT width
static let rightBorderWidth: CGFloat = 8  // GEN_MIDDLE_RIGHT width
static let totalChrome: CGFloat = 34      // titlebar + bottom bar
static let totalBorders: CGFloat = 19     // left + right borders

// Content area (dynamic based on window size)
// contentWidth = pixelSize.width - 19 (borders)
// contentHeight = pixelSize.height - 34 (chrome)

// Example: At default 275x232
static let contentWidth: CGFloat = 256    // 275 - 19
static let contentHeight: CGFloat = 198   // 232 - 34
```

**Size Formula:**
```
pixelWidth = 275 + (widthSegments * 25)
pixelHeight = 116 + (heightSegments * 29)
```

### 2.2 Sprite Source

All window chrome uses GEN.bmp sprites at coordinates defined in `SkinSprites.swift`:

```swift
// GEN.bmp sprite definitions (excerpt)
static let genSprites: [Sprite] = [
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
]
```

### 2.3 Coordinate Grid

The 275×232 window is divided into a precise grid for sprite positioning:

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

### 3.1 Three-Layer Pattern

Following MacAmp's architectural principles (see `docs/MACAMP_ARCHITECTURE_GUIDE.md`):

```
Mechanism Layer: NSWindowController
    ↓
Bridge Layer: WindowFocusState, AppSettings
    ↓
Presentation Layer: SwiftUI Views
```

### 3.2 NSWindowController Pattern

`WinampMilkdropWindowController.swift` follows the established window controller pattern:

```swift
class WinampMilkdropWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer,
                     dockingController: DockingController, settings: AppSettings,
                     radioLibrary: RadioStationLibrary,
                     playbackCoordinator: PlaybackCoordinator,
                     windowFocusState: WindowFocusState) {

        // Create borderless window (matches Video/Playlist)
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 232),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Apply standard Winamp configuration
        WinampWindowConfigurator.apply(to: window)

        // Configure borderless appearance
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        // Create root view with environment injection
        let rootView = WinampMilkdropWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)
            .environment(windowFocusState)

        let hostingController = NSHostingController(rootView: rootView)

        // CRITICAL: Only set contentViewController
        // Setting contentView releases the hosting controller
        window.contentViewController = hostingController

        // Install translucent backing layer
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window)
    }
}
```

### 3.3 Environment Injection

All dependencies are injected via SwiftUI environment:

- `SkinManager`: Provides GEN.bmp sprites
- `AudioPlayer`: Future audio data for visualization
- `DockingController`: Magnetic window snapping
- `AppSettings`: Window position persistence
- `WindowFocusState`: Focus tracking for chrome state

---

## 4. GEN.bmp Chrome Implementation

### 4.1 Titlebar Composition (7 Sections - Dynamic)

The titlebar uses a sophisticated **7-section dynamic layout** that expands via gold filler tiles. This enables window resizing while maintaining visual consistency.

**Static Layout (fixed 275px - legacy reference):**
```
Section 1: LEFT_CAP         (25px)  - Close button
Section 2: LEFT_GOLD        (2×25)  - Gold decorative (dynamic)
Section 3: LEFT_END         (25px)  - Transition piece
Section 4: CENTER_FILL      (3×25)  - Grey text area (fixed)
Section 5: RIGHT_END        (25px)  - Transition piece
Section 6: RIGHT_GOLD       (2×25)  - Gold decorative (dynamic)
Section 7: RIGHT_CAP        (25px)  - End piece
```

**Dynamic Layout (resizable - current implementation):**
```
┌─────────────────────────────────────────────────────────────────────────┐
│ LEFT_CAP │ LEFT_GOLD(n) │ LEFT_END │ CENTER(3) │ RIGHT_END │ RIGHT_GOLD(n) │ RIGHT_CAP │
│   25px   │    n×25px    │   25px   │   75px    │   25px    │     n×25px    │   25px    │
└─────────────────────────────────────────────────────────────────────────┘

Fixed: LEFT_CAP + LEFT_END + RIGHT_END + RIGHT_CAP = 100px
Center: 3 grey tiles = 75px (fixed)
Variable: LEFT_GOLD + RIGHT_GOLD expand symmetrically (n = goldFillerTilesPerSide)
```

**See Section 12.3 for complete dynamic titlebar implementation with code examples.**

Legacy fixed-width implementation (275px only):

```swift
ZStack(alignment: .topLeading) {
    let suffix = isWindowActive ? "_SELECTED" : ""

    // Section 1: Left cap with close button
    SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
        .position(x: 12.5, y: 10)

    // Section 2: Left gold bar tiles (fixed at 2 for 275px)
    ForEach(0..<2, id: \.self) { i in
        SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
            .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
    }

    // Section 3: Left fixed transition
    SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: 20)
        .position(x: 87.5, y: 10)

    // Section 4: Center grey tiles (text area)
    ForEach(0..<3, id: \.self) { i in
        SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
            .position(x: 100 + 12.5 + CGFloat(i) * 25, y: 10)
    }

    // Sections 5-7: Mirror of left side...
}
```

### 4.2 Side Borders

Vertical borders use tiled sprites (29px per tile):

```swift
let sideHeight: CGFloat = 198  // Content area height
let sideTileCount = Int(ceil(sideHeight / 29))  // 7 tiles

ForEach(0..<sideTileCount, id: \.self) { i in
    // Left border (11px wide)
    SimpleSpriteImage("GEN_MIDDLE_LEFT", width: 11, height: 29)
        .position(x: 5.5, y: 20 + 14.5 + CGFloat(i) * 29)

    // Right border (8px wide)
    SimpleSpriteImage("GEN_MIDDLE_RIGHT", width: 8, height: 29)
        .position(x: 271, y: 20 + 14.5 + CGFloat(i) * 29)
}
```

### 4.3 Bottom Bar

The bottom bar uses three pieces:

```swift
// Left corner (125px)
SimpleSpriteImage("GEN_BOTTOM_LEFT", width: 125, height: 14)
    .position(x: 62.5, y: 225)

// Center fill (two-piece sprite - see Section 5)
VStack(spacing: 0) {
    SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)
    SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)
}
.position(x: 137.5, y: 225)

// Right corner with resize handle (125px)
SimpleSpriteImage("GEN_BOTTOM_RIGHT", width: 125, height: 14)
    .position(x: 212.5, y: 225)
```

---

## 5. Two-Piece Sprite Discovery

### 5.1 The Cyan Delimiter Pattern

A critical discovery during Day 7 research revealed that GEN.bmp uses cyan pixels (#00C6FF) as sprite boundary markers:

```
Normal sprite:     [SPRITE_PIXELS]
Two-piece sprite:  [TOP_PIXELS]
                   [CYAN_LINE]     ← Not part of sprite!
                   [BOTTOM_1PX]
```

### 5.2 GEN_BOTTOM_FILL Structure

The `GEN_BOTTOM_FILL` sprite is split into two pieces:

```swift
// SkinSprites.swift definitions
Sprite(name: "GEN_BOTTOM_FILL_TOP", x: 127, y: 72, width: 25, height: 13),
Sprite(name: "GEN_BOTTOM_FILL_BOTTOM", x: 127, y: 87, width: 25, height: 1),

// Usage: Stack vertically with no gap
VStack(spacing: 0) {
    SimpleSpriteImage("GEN_BOTTOM_FILL_TOP", width: 25, height: 13)    // Main part
    SimpleSpriteImage("GEN_BOTTOM_FILL_BOTTOM", width: 25, height: 1)  // 1px bottom
}
```

### 5.3 Why Two Pieces?

The two-piece structure allows for:
- Variable height content areas
- Clean sprite extraction without cyan boundaries
- Pixel-perfect alignment across different window sizes
- Same pattern used for GEN letters (88/95 for selected, 96/108 for normal)

### 5.4 Verification Process

During implementation, ImageMagick was used to verify sprite coordinates:

```bash
# Extract sprite and check for cyan pixels
magick GEN.png -crop 25x13+127+72 test_top.png
magick test_top.png txt:- | grep "00C6FF"
# No output = clean extraction ✓

magick GEN.png -crop 25x1+127+87 test_bottom.png
magick test_bottom.png txt:- | grep "00C6FF"
# No output = clean extraction ✓
```

---

## 6. Titlebar Letter System

### 6.1 GEN Letter Sprites

GEN.bmp contains 32 letter sprites for dynamic text rendering:

```
Letters: A-Z (26 letters)
Numbers: 0-9 (10 digits)
Special: ( ) - _ . (5 characters)
Total: 41 characters

Layout: Two rows
Row 1 (Y=88-94):  Selected/active letter tops (6px)
Row 2 (Y=96-102): Normal/inactive letter tops (6px)
Row 3 (Y=95):     Selected letter bottoms (1px)
Row 4 (Y=108):    Normal letter bottoms (1px)
```

### 6.2 Dynamic Extraction Challenge

Unlike standardized sprites, letter X positions vary by skin:

```swift
// PROBLEM: Letters don't have fixed X coordinates
// Different skins arrange letters differently in GEN.bmp
// Cannot hardcode like we do for titlebar pieces

// SOLUTION NEEDED: Pixel-scanning algorithm
// 1. Scan horizontally for non-cyan pixels
// 2. Detect letter boundaries dynamically
// 3. Build letter coordinate map at runtime
// 4. Cache for performance
```

### 6.3 Implementation Status

**Current**: DEFERRED - Complex feature requiring dedicated implementation time

**Future Implementation** (based on webamp's approach):
```javascript
// webamp/js/skinParser.js genGenTextSprites()
// Scans GEN.bmp to find letter boundaries dynamically
// Creates sprite map for each character
// Handles variable-width letters
```

**Workaround**: Currently showing static "MILKDROP" text, will implement dynamic text extraction in future session.

---

## 7. Focus Integration

### 7.1 WindowFocusState

The window participates in MacAmp's focus tracking system:

```swift
@Observable
@MainActor
final class WindowFocusState {
    var isMainKey: Bool = true
    var isEqualizerKey: Bool = false
    var isPlaylistKey: Bool = false
    var isVideoKey: Bool = false
    var isMilkdropKey: Bool = false  // Added for Milkdrop window

    var hasAnyFocus: Bool {
        isMainKey || isEqualizerKey || isPlaylistKey ||
        isVideoKey || isMilkdropKey
    }
}
```

### 7.2 Focus-Dependent Chrome

The window chrome changes based on focus state:

```swift
struct MilkdropWindowChromeView<Content: View>: View {
    @Environment(WindowFocusState.self) private var windowFocusState
    private var isWindowActive: Bool { windowFocusState.isMilkdropKey }

    var body: some View {
        ZStack {
            // Use _SELECTED suffix when focused
            let suffix = isWindowActive ? "_SELECTED" : ""

            SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", ...)
            SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", ...)
            // etc...
        }
    }
}
```

### 7.3 Focus Behavior

- **Click**: Window becomes key, `isMilkdropKey = true`
- **Click another MacAmp window**: `isMilkdropKey = false`
- **Visual feedback**: Chrome switches between normal and selected sprites
- **Delegate**: `WindowFocusDelegate` handles NSWindow focus events

---

## 8. Placeholder Content

### 8.1 Current Implementation

While visualization is deferred, the window displays informative placeholder:

```swift
struct WinampMilkdropWindow: View {
    var body: some View {
        MilkdropWindowChromeView {
            VStack {
                Text("MILKDROP")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("275 × 232")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.top, 4)

                Text("Visualization: Deferred")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
    }
}
```

### 8.2 Future Content Area

The 256×198px content area will host:
- Butterchurn.js visualization (via WKWebView)
- OR projectM native visualization
- OR custom Metal-based renderer
- OR simple waveform/spectrum analyzer

---

## 9. Butterchurn Integration ✅ COMPLETE

### 9.1 Solution Architecture

The Butterchurn integration uses WKUserScript injection to load JavaScript libraries:

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
│  HTML Canvas + WebGL Context                                 │
│    • 60 FPS render loop (requestAnimationFrame)             │
│    • Butterchurn visualizer instance                        │
│    • Audio data receiver (from Swift)                       │
└─────────────────────────────────────────────────────────────┘
          │                              ▲
          │ postMessage("ready")         │ audioData[1024]
          │ postMessage("presetsLoaded") │ loadPreset(index)
          ▼                              │ showTrackTitle(text)
┌─────────────────────────────────────────────────────────────┐
│                    ButterchurnBridge                         │
│  @Observable @MainActor                                      │
│    • isReady: Bool                                           │
│    • errorMessage: String?                                   │
│    • onPresetsLoaded: ([String]) -> Void                    │
│    • Timer: 30 FPS audio updates to JS                      │
│    • callAsyncJavaScript for reliable execution             │
└─────────────────────────────────────────────────────────────┘
          │                              ▲
          │ audioSamples[1024]           │ loadPreset()
          │ (Accelerate vDSP FFT)        │ showTrackTitle()
          ▼                              │
┌─────────────────────────────────────────────────────────────┐
│                    AVAudioEngine                             │
│    • installTap(1024 samples, 48kHz)                        │
│    • Goertzel-like 19-band spectrum analysis                │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Key Implementation Files

```swift
// Bridge (Swift→JS communication)
MacAmpApp/ViewModels/ButterchurnBridge.swift

// Preset Manager (cycling, history, persistence)
MacAmpApp/ViewModels/ButterchurnPresetManager.swift

// WKWebView wrapper
MacAmpApp/Views/Components/ButterchurnWebView.swift

// Window controller (owns bridge + preset manager)
MacAmpApp/Windows/WinampMilkdropWindowController.swift

// Main view with context menu
MacAmpApp/Views/WinampMilkdropWindow.swift

// JavaScript resources
MacAmpApp/Resources/butterchurn/
├── butterchurn.min.js       # ES module bundle
├── butterchurnPresets.min.js # Preset library
├── bridge.js                 # Swift↔JS interface
└── index.html                # Canvas + initialization
```

### 9.3 WKUserScript Injection Strategy

**Critical Discovery:** WKWebView's `<script src="...">` fails for local files, but WKUserScript works:

```swift
// ButterchurnWebView.swift - Load JS from bundle and inject
private func createUserScripts() -> [WKUserScript] {
    var scripts: [WKUserScript] = []

    // 1. Butterchurn library (atDocumentStart - before any rendering)
    if let url = Bundle.main.url(forResource: "butterchurn.min", withExtension: "js"),
       let content = try? String(contentsOf: url) {
        let script = WKUserScript(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        scripts.append(script)
    }

    // 2. Presets library (atDocumentStart)
    if let url = Bundle.main.url(forResource: "butterchurnPresets.min", withExtension: "js"),
       let content = try? String(contentsOf: url) {
        let script = WKUserScript(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        scripts.append(script)
    }

    // 3. Bridge script (atDocumentEnd - after DOM ready)
    if let url = Bundle.main.url(forResource: "bridge", withExtension: "js"),
       let content = try? String(contentsOf: url) {
        let script = WKUserScript(source: content, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        scripts.append(script)
    }

    return scripts
}
```

### 9.4 Audio Data Pipeline

**End-to-End Audio Flow (Local Playback Only):**

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BUTTERCHURN AUDIO DATA FLOW                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐   │
│  │ Audio File  │───▶│ AVAudioEngine   │───▶│ installTap(2048 samples)   │   │
│  │ (.mp3/flac) │    │ (48kHz stereo)  │    │ Mono downsample + FFT      │   │
│  └─────────────┘    └─────────────────┘    └─────────────────────────────┘   │
│                                                       │                       │
│                                                       ▼                       │
│                           ┌───────────────────────────────────────────────┐   │
│                           │        AudioPlayer.swift                       │   │
│                           │  @ObservationIgnored butterchurnSpectrum[1024] │   │
│                           │  @ObservationIgnored butterchurnWaveform[1024] │   │
│                           │  snapshotButterchurnFrame() → ButterchurnFrame │   │
│                           └───────────────────────────────────────────────┘   │
│                                                       │                       │
│                                                       ▼ (30 FPS Timer)        │
│                           ┌───────────────────────────────────────────────┐   │
│                           │        ButterchurnBridge.swift                 │   │
│                           │  sendAudioData() → callAsyncJavaScript         │   │
│                           │  "window.receiveAudioData([...samples])"       │   │
│                           └───────────────────────────────────────────────┘   │
│                                                       │                       │
│                                                       ▼ (WKWebView)           │
│                           ┌───────────────────────────────────────────────┐   │
│                           │        bridge.js (JavaScript)                  │   │
│                           │  receiveAudioData(data) → audioBuffer.set()    │   │
│                           │  ScriptProcessorNode → Butterchurn analyser    │   │
│                           └───────────────────────────────────────────────┘   │
│                                                       │                       │
│                                                       ▼ (60 FPS RAF)          │
│                           ┌───────────────────────────────────────────────┐   │
│                           │        butterchurn.min.js                      │   │
│                           │  visualizer.render() → WebGL Canvas            │   │
│                           │  100+ presets with audio-reactive shaders      │   │
│                           └───────────────────────────────────────────────┘   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Frame Rates:**
- **AVAudioEngine tap:** 48kHz continuous (2048 samples per buffer)
- **Swift→JS updates:** 30 FPS (33ms interval)
- **WebGL rendering:** 60 FPS (requestAnimationFrame)

**30 FPS Swift→JS Audio Updates:**

```swift
// ButterchurnBridge.swift - Timer-based audio streaming
private func startAudioTimer() {
    audioTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.sendAudioData()
        }
    }
}

private func sendAudioData() {
    guard isReady, let audioPlayer = audioPlayer else { return }

    // Get FFT samples from AVAudioEngine tap
    let samples = audioPlayer.getVisualizationSamples(count: 1024)

    // Convert to JSON array for JS
    let jsArray = samples.map { String(format: "%.4f", $0) }.joined(separator: ",")

    // Use callAsyncJavaScript for reliable delivery
    webView?.callAsyncJavaScript(
        "if (window.receiveAudioData) window.receiveAudioData([\(jsArray)]);",
        in: nil, in: .page
    ) { _ in }
}
```

**60 FPS JS Render Loop:**

```javascript
// bridge.js - Render loop with audio data
let audioData = new Float32Array(1024);

window.receiveAudioData = function(data) {
    audioData.set(data);
};

function render() {
    if (visualizer && isPlaying) {
        visualizer.render(audioData);
    }
    requestAnimationFrame(render);
}
requestAnimationFrame(render);
```

### 9.5 ButterchurnPresetManager

Manages preset cycling, randomization, and history:

```swift
// ButterchurnPresetManager.swift
@MainActor
@Observable
final class ButterchurnPresetManager {
    // Observable state
    var presets: [String] = []
    var currentPresetIndex: Int = -1
    var isRandomize: Bool = true      // Persisted
    var isCycling: Bool = true        // Persisted
    var cycleInterval: TimeInterval = 15.0  // Persisted
    var trackTitleInterval: TimeInterval = 0  // 0 = manual only

    // History for previous/next navigation
    @ObservationIgnored private var presetHistory: [Int] = []

    // Timer management
    @ObservationIgnored private var cycleTimer: Timer?
    @ObservationIgnored private var trackTitleTimer: Timer?

    func nextPreset() {
        if isRandomize {
            selectRandomPreset()
        } else {
            selectPreset(at: (currentPresetIndex + 1) % presets.count)
        }
    }

    func previousPreset() {
        guard presetHistory.count >= 2 else { return }
        presetHistory.removeLast()  // Pop current
        if let prev = presetHistory.last {
            selectPreset(at: prev, addToHistory: false)
        }
    }
}
```

### 9.6 Context Menu Implementation

Uses NSMenu with closure-to-selector bridge pattern:

```swift
// WinampMilkdropWindow.swift - Context menu via right-click overlay
private func showContextMenu(at location: NSPoint) {
    let menu = NSMenu()
    activeContextMenu = menu  // Keep strong reference!

    // Header: Current preset
    if let name = presetManager.currentPresetName {
        let item = NSMenuItem(title: "▶ \(name)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        menu.addItem(.separator())
    }

    // Navigation
    menu.addItem(createMenuItem(title: "Next Preset", keyEquivalent: " ", action: {
        [weak presetManager] in presetManager?.nextPreset()
    }))

    // Show at click location
    menu.popUp(positioning: nil, at: location, in: nil)
}

// Helper: Bridge Swift closure to NSMenuItem action
@MainActor
private class MilkdropMenuTarget: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func execute() { action() }
}

private func createMenuItem(title: String, action: @escaping () -> Void) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let target = MilkdropMenuTarget(action: action)
    item.target = target
    item.action = #selector(MilkdropMenuTarget.execute)
    item.representedObject = target  // Keep alive!
    return item
}
```

### 9.7 Critical Bug Fixes (Oracle A-Grade)

**Bug 1: markLoadFailed Called Before Setup**
```swift
// WRONG: Direct call before bridge configured
if !isReady { markLoadFailed("Setup incomplete") }

// CORRECT: Guard + async delay for initialization
func markLoadFailed(_ message: String) {
    guard isReady else { return }  // Only fail if was previously ready
    errorMessage = message
}
```

**Bug 2: isReady Guard in sendAudioData**
```swift
// WRONG: Send data without checking ready state
private func sendAudioData() {
    let samples = audioPlayer?.getVisualizationSamples(count: 1024) ?? []
    webView?.evaluateJavaScript(...)  // May execute before bridge ready
}

// CORRECT: Guard all JS calls
private func sendAudioData() {
    guard isReady, let audioPlayer = audioPlayer else { return }
    // Now safe to send
}
```

**Bug 3: WKNavigationDelegate Lifecycle**
```swift
// CRITICAL: Implement didFinish to know when page ready
extension ButterchurnWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Page loaded, scripts injected, now can receive messages
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        parent.bridge.markLoadFailed(error.localizedDescription)
    }
}
```

**Bug 4: callAsyncJavaScript vs evaluateJavaScript**
```swift
// WRONG: evaluateJavaScript can race with page load
webView.evaluateJavaScript("loadPreset(5)")

// CORRECT: callAsyncJavaScript waits for context
webView.callAsyncJavaScript(
    "loadPreset(\(index), \(transition))",
    in: nil,
    in: .page
) { result in
    // Handle completion
}
```

**Bug 5: Timer Thread Safety**
```swift
// WRONG: Timer callback not on main actor
cycleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
    self?.nextPreset()  // ⚠️ May be on wrong thread
}

// CORRECT: Dispatch to MainActor
cycleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
    Task { @MainActor in
        self?.nextPreset()
    }
}
```

### 9.8 Persistence Pattern

All settings use AppSettings with didSet persistence:

```swift
// AppSettings.swift
@Observable @MainActor
final class AppSettings {
    var butterchurnRandomize: Bool = true {
        didSet { UserDefaults.standard.set(butterchurnRandomize, forKey: "butterchurnRandomize") }
    }
    var butterchurnCycling: Bool = true {
        didSet { UserDefaults.standard.set(butterchurnCycling, forKey: "butterchurnCycling") }
    }
    var butterchurnCycleInterval: Double = 15.0 {
        didSet { UserDefaults.standard.set(butterchurnCycleInterval, forKey: "butterchurnCycleInterval") }
    }
    var butterchurnTrackTitleInterval: Double = 0 {
        didSet { UserDefaults.standard.set(butterchurnTrackTitleInterval, forKey: "butterchurnTrackTitleInterval") }
    }
}
```

### 9.9 Track Title Display (Phase 7)

Automatic or manual track title overlay on visualization:

```swift
// ButterchurnPresetManager.swift
var trackTitleInterval: TimeInterval = 0 {  // 0 = manual only
    didSet {
        appSettings?.butterchurnTrackTitleInterval = trackTitleInterval
        if trackTitleInterval > 0 {
            restartTrackTitleTimer()
        } else {
            stopTrackTitleTimer()
        }
    }
}

func showCurrentTrackTitle() {
    guard let displayTitle = playbackCoordinator?.displayTitle else { return }
    bridge?.showTrackTitle(displayTitle)
}

// bridge.js - Display with fade animation
window.showTrackTitle = function(title) {
    const overlay = document.getElementById('trackTitle');
    overlay.textContent = title;
    overlay.style.opacity = 1;
    setTimeout(() => { overlay.style.opacity = 0; }, 3000);
};
```

### 9.10 WASM Rendering Mode Configuration

Butterchurn.js supports two rendering modes:

**Hybrid Mode (Current Implementation):**
```javascript
// bridge.js - Current configuration (default behavior)
visualizer = butterchurn.createVisualizer(audioContext, canvas, {
    width: canvas.width,
    height: canvas.height,
    pixelRatio: window.devicePixelRatio || 1,
    textureRatio: 1
    // onlyUseWASM not specified - uses WASM with JavaScript fallback
});
```

**WASM-Only Mode (Recommended for Security):**
```javascript
// bridge.js - Hardened security configuration
visualizer = butterchurn.createVisualizer(audioContext, canvas, {
    width: canvas.width,
    height: canvas.height,
    pixelRatio: window.devicePixelRatio || 1,
    textureRatio: 1,
    onlyUseWASM: true  // Force WASM-only rendering
});
```

**Trade-offs:**

| Mode | Security | Compatibility | Notes |
|------|----------|---------------|-------|
| Hybrid (default) | ⚠️ JS fallback less sandboxed | ✅ Works everywhere | Acceptable with WKWebView sandboxing |
| WASM-only | ✅ Memory-sandboxed | ⚠️ Fails without WASM | Recommended for production |

**Note:** MacAmp uses hybrid mode because:
1. WKWebView already provides sandboxing
2. All modern macOS (15+) support WASM
3. Hybrid mode ensures graceful degradation

**Implementation Note:** The `butterchurn.min.js` file includes WASM code built-in (no separate `.wasm` file required). The library auto-detects WASM support and uses it when available.

---

## 10. Persistence & Docking

### 10.1 Window Position Persistence

Position saved to UserDefaults:

```swift
// AppSettings.swift
@Observable @MainActor
final class AppSettings {
    var milkdropWindowFrame: NSRect? {
        didSet {
            if let frame = milkdropWindowFrame {
                UserDefaults.standard.set(
                    NSStringFromRect(frame),
                    forKey: "milkdropWindowFrame"
                )
            }
        }
    }

    init() {
        // Restore saved position
        if let frameString = UserDefaults.standard.string(
            forKey: "milkdropWindowFrame") {
            milkdropWindowFrame = NSRectFromString(frameString)
        }
    }
}
```

### 10.2 Magnetic Docking

The window participates in MacAmp's magnetic docking system:

```swift
// DockingController manages all window snapping
dockingController.registerWindow(milkdropWindow, kind: .milkdrop)

// Snapping behavior:
- Snap to screen edges (10px threshold)
- Snap to other MacAmp windows
- Form window clusters
- Move as a group when docked
```

### 10.3 Window Lifecycle

```swift
// Open (Ctrl+K pressed)
1. Check if controller exists
2. Create if needed
3. Restore saved position
4. Show window
5. Update isMilkdropVisible = true

// Close (window closed)
1. Save current position
2. Update isMilkdropVisible = false
3. Controller remains in memory
```

---

## 11. Testing

### 11.1 Focus State Testing

```bash
# Test focus transitions
1. Open Milkdrop window (Ctrl+K)
2. Verify _SELECTED sprites shown
3. Click Main window
4. Verify normal sprites shown
5. Click back to Milkdrop
6. Verify _SELECTED sprites return
```

### 11.2 Sprite Alignment Testing

```bash
# Visual inspection points
- Titlebar sections align seamlessly
- No gaps between tiles
- Side borders tile correctly (7×29px tiles)
- Bottom bar pieces connect properly
- Close button in correct position
```

### 11.3 Multi-Skin Testing

Test with various skins to ensure GEN sprite compatibility:

```bash
# Test skins
- Base skin (default)
- Winamp Classic
- Custom skins with different GEN.bmp layouts
- Skins with missing GEN sprites (fallback behavior)
```

### 11.4 Window Management

```bash
# Test window operations
- Ctrl+K opens/closes
- Window position persists
- Magnetic docking works
- Drag via titlebar works
- Close button works
```

---

## 12. Future Work

### 12.1 Visualization Enhancements

**Completed:**
- ✅ Butterchurn.js integration via WKWebView
- ✅ Preset cycling with randomization and history
- ✅ Track title overlay display

**Future:**
1. **Native Metal Renderer** - Best performance, port from WebGL
2. **projectM Integration** - Load native .milk presets
3. **Custom Preset Editor** - Create/modify presets

### 12.2 Dynamic Text Rendering

Implement GEN letter extraction for titlebar text:
- ✅ Two-piece sprite system implemented
- ✅ Static "MILKDROP" letters rendered
- **Future:** Pixel-scanning for variable-width letters
- **Future:** Support for preset names in titlebar

### 12.3 Window Resizing - ✅ COMPLETE

**Implementation Status**: Complete (branch `feature/milkdrop-window-resize`)
**Commits**: `655c5d3` through `099705f` (7 phases)

The MILKDROP window now supports full segment-based resizing, matching the VIDEO window pattern.

#### 12.3.1 Architecture Overview

**Size Model (Size2D):**
```swift
// MacAmpApp/Models/Size2D.swift
struct Size2D: Equatable, Codable, Hashable {
    var width: Int   // Number of 25px segments beyond base width
    var height: Int  // Number of 29px segments beyond base height

    // MILKDROP presets
    static let milkdropMinimum = Size2D(width: 0, height: 0)  // 275×116
    static let milkdropDefault = Size2D(width: 0, height: 4)  // 275×232

    /// Convert segments to pixel dimensions for MILKDROP window
    func toMilkdropPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }
}
```

**Observable State (MilkdropWindowSizeState):**
```swift
// MacAmpApp/Models/MilkdropWindowSizeState.swift
@MainActor
@Observable
final class MilkdropWindowSizeState {
    /// Current size in segments (persisted via didSet)
    var size: Size2D = .milkdropDefault {
        didSet { saveSize() }
    }

    /// Pixel dimensions calculated from segments
    var pixelSize: CGSize { size.toMilkdropPixels() }

    /// Content dimensions (for Butterchurn canvas)
    var contentWidth: CGFloat { pixelSize.width - 19 }   // Minus borders
    var contentHeight: CGFloat { pixelSize.height - 34 } // Minus chrome
    var contentSize: CGSize { CGSize(width: contentWidth, height: contentHeight) }

    // Titlebar layout computed properties
    var goldFillerTilesPerSide: Int    // Dynamic gold expansion
    var centerSectionStartX: CGFloat   // After left gold + left end
    var milkdropLettersCenterX: CGFloat // Center of 75px grey section
}
```

#### 12.3.2 Specifications

| Property | Value | Notes |
|----------|-------|-------|
| Minimum Size | 275×116 | Size2D[0,0], matches Main/EQ |
| Default Size | 275×232 | Size2D[0,4], 4 height segments |
| Width Segment | 25px | Horizontal resize increment |
| Height Segment | 29px | Vertical resize increment |
| Titlebar Height | 20px | Fixed chrome |
| Bottom Bar Height | 14px | Fixed chrome |
| Left Border | 11px | GEN_MIDDLE_LEFT |
| Right Border | 8px | GEN_MIDDLE_RIGHT |

#### 12.3.3 Dynamic Chrome System (7-Section Titlebar)

The titlebar dynamically expands via gold filler tiles:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ LEFT_CAP │ LEFT_GOLD(n) │ LEFT_END │ CENTER(3) │ RIGHT_END │ RIGHT_GOLD(n) │ RIGHT_CAP │
│   25px   │    n×25px    │   25px   │   75px    │   25px    │     n×25px    │   25px    │
└─────────────────────────────────────────────────────────────────────────┘

Fixed sections: LEFT_CAP(25) + LEFT_END(25) + RIGHT_END(25) + RIGHT_CAP(25) = 100px
Center section: 3 grey tiles = 75px (fixed)
Variable sections: LEFT_GOLD + RIGHT_GOLD expand symmetrically
```

**Implementation in MilkdropWindowChromeView.swift:**

```swift
@ViewBuilder
private func buildDynamicTitlebar() -> some View {
    let suffix = isWindowActive ? "_SELECTED" : ""
    let goldTiles = sizeState.goldFillerTilesPerSide
    let centerStart = sizeState.centerSectionStartX

    ZStack(alignment: .topLeading) {
        // Section 1: Left cap (25px)
        SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
            .position(x: 12.5, y: 10)

        // Section 2: Left gold bar tiles (dynamic count)
        ForEach(0..<goldTiles, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 3: Left end (25px)
        SimpleSpriteImage("GEN_TOP_LEFT_END\(suffix)", width: 25, height: 20)
            .position(x: centerStart - 12.5, y: 10)

        // Section 4: Center grey tiles (fixed 3 tiles = 75px)
        ForEach(0..<sizeState.centerGreyTileCount, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_CENTER_FILL\(suffix)", width: 25, height: 20)
                .position(x: centerStart + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 5: Right end (25px)
        SimpleSpriteImage("GEN_TOP_RIGHT_END\(suffix)", width: 25, height: 20)
            .position(x: centerStart + 75 + 12.5, y: 10)

        // Section 6: Right gold bar tiles (symmetric with left)
        ForEach(0..<goldTiles, id: \.self) { i in
            SimpleSpriteImage("GEN_TOP_LEFT_RIGHT_FILL\(suffix)", width: 25, height: 20)
                .position(x: centerStart + 75 + 25 + 12.5 + CGFloat(i) * 25, y: 10)
        }

        // Section 7: Right cap with close button (25px)
        SimpleSpriteImage("GEN_TOP_RIGHT\(suffix)", width: 25, height: 20)
            .position(x: pixelSize.width - 12.5, y: 10)

        // MILKDROP HD letters - centered in 75px center section
        milkdropLetters
            .position(x: sizeState.milkdropLettersCenterX, y: 8)
    }
}
```

#### 12.3.4 Computed Properties

**Gold Filler Tiles (with ceil() pattern):**
```swift
// MilkdropWindowSizeState.swift
/// Gold filler tiles per side (symmetric)
/// Uses ceil() to ensure tiles fully cover the space at all widths (Pattern 9)
var goldFillerTilesPerSide: Int {
    let goldSpace = pixelSize.width - 100 - 75  // Fixed caps/ends (100) + center grey (75)
    let perSide = goldSpace / 2.0
    return max(0, Int(ceil(perSide / 25.0)))
}

/// X position for center section start (after LEFT_CAP + LEFT_GOLD + LEFT_END)
var centerSectionStartX: CGFloat {
    25 + CGFloat(goldFillerTilesPerSide) * 25 + 25
}

/// X position for MILKDROP HD letters (centered in 75px center section)
var milkdropLettersCenterX: CGFloat {
    centerSectionStartX + 37.5  // Center of 75px center section
}
```

**CRITICAL: ceil() Pattern (Pattern 9 from BUILDING_RETRO_MACOS_APPS_SKILL.md)**

The `ceil()` function ensures full tile coverage at all widths:

| Width | goldSpace | perSide | floor() | ceil() | Result |
|-------|-----------|---------|---------|--------|--------|
| 275px | 100px | 50px | 2 tiles | 2 tiles | OK |
| 300px | 125px | 62.5px | 2 tiles | 3 tiles | ceil() prevents gap |
| 325px | 150px | 75px | 3 tiles | 3 tiles | OK |

Without `ceil()`, widths like 300px would have a visible gap between the gold tiles and the center section.

#### 12.3.5 Resize Gesture

**DragGesture with Quantization:**
```swift
// MilkdropWindowChromeView.swift
@ViewBuilder
private func buildResizeHandle() -> some View {
    Rectangle()
        .fill(Color.clear)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Capture start size on first drag tick
                    if dragStartSize == nil {
                        dragStartSize = sizeState.size
                        isDragging = true
                        WindowSnapManager.shared.beginProgrammaticAdjustment()
                    }

                    guard let baseSize = dragStartSize else { return }

                    // Calculate quantized size from drag delta (25px width, 29px height)
                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let candidate = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Show AppKit preview overlay
                    if let coordinator = WindowCoordinator.shared,
                       let window = coordinator.milkdropWindow {
                        resizePreview.show(in: window, previewSize: candidate.toMilkdropPixels())
                    }
                }
                .onEnded { value in
                    guard let baseSize = dragStartSize else { return }

                    // Calculate final quantized size
                    let widthDelta = Int(round(value.translation.width / 25))
                    let heightDelta = Int(round(value.translation.height / 29))

                    let finalSize = Size2D(
                        width: max(0, baseSize.width + widthDelta),
                        height: max(0, baseSize.height + heightDelta)
                    )

                    // Commit size change (triggers persistence via didSet)
                    sizeState.size = finalSize

                    // Sync NSWindow with top-left anchoring
                    if let coordinator = WindowCoordinator.shared {
                        coordinator.updateMilkdropWindowSize(to: sizeState.pixelSize)
                    }

                    // Hide preview overlay
                    resizePreview.hide()

                    // Notify Butterchurn of canvas resize
                    bridge.setSize(width: contentSize.width, height: contentSize.height)

                    // Cleanup
                    isDragging = false
                    dragStartSize = nil
                    WindowSnapManager.shared.endProgrammaticAdjustment()
                }
        )
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)
}
```

**AppKit Preview Overlay:**

During drag, a translucent overlay shows the target size:
```swift
// WindowResizePreviewOverlay (shared with VIDEO window)
resizePreview.show(in: window, previewSize: candidate.toMilkdropPixels())
resizePreview.hide()
```

#### 12.3.6 Integration Points

**WindowCoordinator.updateMilkdropWindowSize():**
```swift
// MacAmpApp/ViewModels/WindowCoordinator.swift
/// Update MILKDROP window frame to match new size (top-left anchoring)
func updateMilkdropWindowSize(to pixelSize: CGSize) {
    guard let milkdrop = milkdropWindow else { return }

    var frame = milkdrop.frame
    guard frame.size != pixelSize else { return }

    // Use integer coordinates to prevent blurry rendering
    let roundedSize = CGSize(
        width: round(pixelSize.width),
        height: round(pixelSize.height)
    )

    // Top-left anchoring: preserve top-left corner position
    // macOS uses bottom-left origin, so calculate new origin from top-left
    let topLeft = NSPoint(
        x: round(frame.origin.x),
        y: round(frame.origin.y + frame.size.height)
    )
    frame.size = roundedSize
    frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - roundedSize.height)

    milkdrop.setFrame(frame, display: true)
}
```

**ButterchurnBridge.setSize():**
```swift
// MacAmpApp/ViewModels/ButterchurnBridge.swift
/// Resize the Butterchurn canvas to match window content area
func setSize(width: CGFloat, height: CGFloat) {
    guard isReady, let webView = webView else { return }
    let js = "window.macampButterchurn?.setSize(\(Int(width)), \(Int(height)));"
    webView.evaluateJavaScript(js, completionHandler: nil)
}
```

#### 12.3.7 Persistence

**UserDefaults with didSet Pattern:**
```swift
// MilkdropWindowSizeState.swift
private static let sizeKey = "milkdropWindowSize"

private func saveSize() {
    let data = ["width": size.width, "height": size.height]
    UserDefaults.standard.set(data, forKey: Self.sizeKey)
}

func loadSize() {
    guard let data = UserDefaults.standard.dictionary(forKey: Self.sizeKey),
          let width = data["width"] as? Int,
          let height = data["height"] as? Int else {
        size = .milkdropDefault
        return
    }
    size = Size2D(width: width, height: height).clamped(min: .milkdropMinimum)
}
```

#### 12.3.8 Bug Fix: Titlebar Tile Gap (commit `099705f`)

**Problem:** At certain window widths (e.g., 300px), a visible gap appeared between the gold tiles and center section.

**Root Cause:** The `goldFillerTilesPerSide` calculation used floor division:
```swift
// WRONG: Floor division leaves gaps
Int(perSide / 25)  // At 62.5px, returns 2 tiles (gap!)
```

**Solution:** Apply Pattern 9 from BUILDING_RETRO_MACOS_APPS_SKILL.md - use `ceil()`:
```swift
// CORRECT: Ceiling ensures full coverage
Int(ceil(perSide / 25.0))  // At 62.5px, returns 3 tiles (full coverage)
```

**Visual Example:**
```
Width 300px, goldSpace = 125px, perSide = 62.5px

With floor (Int(62.5/25) = 2):
[CAP][GOLD][GOLD][END] ← 100px   [CENTER 75px]   [END][GOLD][GOLD][CAP] ← 100px
                         ↑ GAP! (275px total, 25px missing)

With ceil (Int(ceil(62.5/25)) = 3):
[CAP][GOLD][GOLD][GOLD][END][CENTER 75px][END][GOLD][GOLD][GOLD][CAP]
                         ↑ Full coverage (tiles overlap slightly, no gap)
```

#### 12.3.9 Implementation Summary

| Phase | Commit | Description |
|-------|--------|-------------|
| 1 | `655c5d3` | Foundation: Size2D presets + MilkdropWindowSizeState |
| 2 | `39bc227` | Size state wiring + WindowCoordinator + ButterchurnBridge |
| 3 | `104db69` | Dynamic chrome layout (7-section titlebar) |
| 4 | `34c9c87` | Resize gesture with AppKit preview overlay |
| 5 | (bundled) | WindowCoordinator.updateMilkdropWindowSize() |
| 6 | (bundled) | ButterchurnBridge.setSize() initial sync |
| 7 | `099705f` | Fix titlebar tile gap using ceil() (Pattern 9) |

**Files Changed:**
- `MacAmpApp/Models/Size2D.swift` - MILKDROP presets
- `MacAmpApp/Models/MilkdropWindowSizeState.swift` - NEW: Observable size state
- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift` - Dynamic layout + resize gesture
- `MacAmpApp/ViewModels/WindowCoordinator.swift` - updateMilkdropWindowSize()
- `MacAmpApp/ViewModels/ButterchurnBridge.swift` - setSize() canvas sync

### 12.4 Advanced Audio Analysis

Current: 1024-sample FFT via AVAudioEngine tap
Future: Enhanced visualization features
- Beat detection (BPM)
- Multi-band frequency analysis
- Smooth transitions between presets
- Audio-reactive preset selection

---

## Code References

### Primary Implementation Files

```swift
// Window Controller
MacAmpApp/Windows/WinampMilkdropWindowController.swift

// Main View
MacAmpApp/Views/WinampMilkdropWindow.swift

// Chrome Implementation (dynamic titlebar + resize gesture)
MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift

// Size State (quantized segments + titlebar computed properties)
MacAmpApp/Models/MilkdropWindowSizeState.swift

// Size Model (MILKDROP presets + pixel conversion)
MacAmpApp/Models/Size2D.swift

// Sprite Definitions
MacAmpApp/Models/SkinSprites.swift (GEN section)

// Focus State
MacAmpApp/Models/WindowFocusState.swift

// Settings Persistence
MacAmpApp/Models/AppSettings.swift

// Window Coordination (updateMilkdropWindowSize)
MacAmpApp/ViewModels/WindowCoordinator.swift

// Butterchurn Canvas Resize (setSize)
MacAmpApp/ViewModels/ButterchurnBridge.swift
```

### Research & Documentation

```
// Implementation research
tasks/milk-drop-video-support/research.md
tasks/milk-drop-video-support/plan.md
tasks/milk-drop-video-support/state.md

// Day summaries
tasks/milk-drop-video-support/DAY_7_8_SUMMARY.md

// Technical blockers
tasks/milk-drop-video-support/BUTTERCHURN_BLOCKERS.md

// Resize specification (future)
tasks/milk-drop-video-support/MILKDROP_RESIZE_SPEC.md
```

### Related Documentation

```
// Architecture patterns
docs/MACAMP_ARCHITECTURE_GUIDE.md

// Sprite system
docs/SPRITE_SYSTEM_COMPLETE.md

// Window patterns
docs/IMPLEMENTATION_PATTERNS.md
```

---

## Summary

The Milkdrop window implementation demonstrates several key MacAmp patterns:

1. **Pixel-perfect sprite rendering** using GEN.bmp chrome
2. **Two-piece sprite discovery** for BOTTOM_FILL and letter components
3. **Seven-section dynamic titlebar** with gold filler expansion
4. **Focus state integration** with _SELECTED sprite switching
5. **NSWindowController pattern** with environment injection
6. **WKUserScript injection** for JavaScript library loading
7. **Swift→JS audio bridge** at 30 FPS with callAsyncJavaScript
8. **Preset management** with cycling, randomization, and history
9. **Context menu** using NSMenu with closure-to-selector bridge
10. **Track title overlay** with configurable interval display
11. **WASM rendering mode** - Hybrid mode with security option (`onlyUseWASM: true`)
12. **Segment-based resizing** with Size2D quantized model
13. **ceil() pattern** for titlebar tile coverage (Pattern 9)

The Milkdrop window is complete with Butterchurn.js visualization and full resize support, providing real-time audio-reactive psychedelic visuals. The implementation follows MacAmp's three-layer architecture, maintains Winamp compatibility, and integrates seamlessly with the existing window management system.

### Implementation Metrics

- **7 Phases** of Butterchurn integration + **7 Phases** of resize implementation
- **6 Oracle A-grade bug fixes** for production stability (including ceil() pattern)
- **30 FPS** Swift→JS audio data pipeline
- **60 FPS** WebGL render loop
- **100+ presets** from butterchurnPresets library
- **5 persisted settings** (randomize, cycling, cycle interval, title interval, window size)
- **Hybrid WASM mode** (WASM with JS fallback, `onlyUseWASM: true` available)
- **275×116** minimum size to **unlimited** maximum (segment-based)
- **25×29px** resize segments matching Winamp behavior

### Key Files

| File | Purpose |
|------|---------|
| `ButterchurnBridge.swift` | Swift→JS communication bridge + canvas resize |
| `ButterchurnPresetManager.swift` | Preset cycling, history, persistence |
| `ButterchurnWebView.swift` | WKWebView wrapper with script injection |
| `WinampMilkdropWindow.swift` | Main view with context menu |
| `WinampMilkdropWindowController.swift` | NSWindowController owning bridge + manager |
| `MilkdropWindowChromeView.swift` | GEN.bmp chrome + dynamic titlebar + resize gesture |
| `MilkdropWindowSizeState.swift` | Observable size state with titlebar computed properties |
| `Size2D.swift` | Quantized segment model with MILKDROP presets |
| `WindowCoordinator.swift` | updateMilkdropWindowSize() for NSWindow sync |

---

**End of Document**