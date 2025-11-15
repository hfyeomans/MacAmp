# Implementation Plan: Video & Milkdrop Windows (Two-Window Architecture)

**Task ID**: milk-drop-video-support
**Architecture**: TWO Independent NSWindows (Video + Milkdrop)
**Priority**: Video Window FIRST, then Milkdrop Window
**Timeline**: 8-10 days (Phased implementation)
**Approved**: 2025-11-08 (Initial), 2025-11-09 (Corrected with TASK 1 learnings)
**Prerequisite**: TASK 1 (magnetic-docking-foundation) ✅ COMPLETE

---

## TASK 2 Decisions (2025-11-09)

**User Decisions**:
1. **V Button**: Opens Video window ✅
2. **Milkdrop**: Options menu checkbox + Ctrl+Shift+K ✅
3. **Resize**: Defer to TASK 3 (focus, no scope creep) ✅

**Principle**: "Make it exist, then make it better"

**Keyboard Shortcuts**:
- Ctrl+K: Available ✅
- Ctrl+M: Available ✅
- **Using**: Ctrl+Shift+K (Winamp standard for visualizations)

**Scope**:
- ✅ Video + Milkdrop windows (5 total windows)
- ✅ VIDEO.BMP parsing (new)
- ✅ GEN.BMP reuse (existing)
- ✅ NSWindowController pattern (TASK 1)
- ✅ Single audio tap extension
- ❌ Window resize (deferred to TASK 3)

**Architecture Updates from TASK 1**:
- Use NSWindowController pattern (not inline views)
- WindowCoordinator integration
- WindowSnapManager registration
- Extend existing audio tap (not new AudioAnalyzer)
- Delegate multiplexer integration
- WindowFrameStore persistence

---

## Overview

Implement TWO separate, independent windows matching original Winamp Classic:

1. **Video Window** (Days 1-6) - PRIORITY 1
   - Native video playback (AVPlayerView)
   - VIDEO.bmp skin chrome
   - Playback controls from VIDEO.bmp sprites
   - Tied to "V" button (Ctrl+V)

2. **Milkdrop Window** (Days 7-10) - PRIORITY 2
   - Butterchurn audio visualization
   - FFT audio analysis
   - Preset system
   - Independent from video window

**Key Principle**: Each window is completely independent - can be opened/closed/positioned separately, can coexist simultaneously.

---

## Architecture Overview

```
User Presses "V" (Ctrl+V)
         ↓
   Video Window Opens
         ↓
┌──────────────────────────────┐
│  VideoWindowView             │
│  (VIDEO.bmp skinned chrome)  │
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │  AVPlayerView          │  │
│  │  (MP4, MOV, M4V)       │  │
│  │                        │  │
│  └────────────────────────┘  │
│  [■] [▶] [■] [◼] |========|  │ ← VIDEO.bmp controls
└──────────────────────────────┘

User Opens Milkdrop (Options Menu or Ctrl+Shift+K)
         ↓
   Milkdrop Window Opens
         ↓
┌──────────────────────────────┐
│  MilkdropWindowView          │
│  (Skinnable chrome)          │
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │  WKWebView             │  │
│  │  + Butterchurn         │  │
│  │  (Audio Visualization) │  │
│  └────────────────────────┘  │
│  [Presets ▼] [Fullscreen]    │
└──────────────────────────────┘

Both windows coexist independently!
```

---

## Phase Breakdown (10 Days)

### Days 1-2: NSWindowController Setup (Following TASK 1 Pattern)

**Goal**: Create Video and Milkdrop NSWindowControllers using proven foundation pattern

#### Day 1: Video Window Controller

**File**: `MacAmpApp/Windows/WinampVideoWindowController.swift`

```swift
import AppKit
import SwiftUI

class WinampVideoWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer,
                    dockingController: DockingController, settings: AppSettings,
                    radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator) {
        // Create borderless window (follows TASK 1 pattern)
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 275, height: 116),  // Video window base size
            styleMask: [.borderless],  // Borderless only
            backing: .buffered,
            defer: false
        )

        // Apply standard Winamp window configuration
        WinampWindowConfigurator.apply(to: window)

        // Borderless visual configuration
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        // Create view with environment injection
        let rootView = WinampVideoWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)

        let hostingController = NSHostingController(rootView: rootView)
        let hostingView = hostingController.view
        hostingView.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
        hostingView.autoresizingMask = [.width, .height]

        window.contentViewController = hostingController
        window.contentView = hostingView
        window.makeFirstResponder(hostingView)

        // Install hit surface
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window)
    }
}
```

**Tasks**:
- [ ] Create WinampVideoWindowController.swift
- [ ] Follow BorderlessWindow pattern (like Main/EQ/Playlist)
- [ ] Set base size 275×116 (matches Main/EQ)
- [ ] Apply WinampWindowConfigurator
- [ ] Create placeholder WinampVideoWindow SwiftUI view
- [ ] Test window compiles

#### Day 1: Milkdrop Window Controller

**File**: `MacAmpApp/Windows/WinampMilkdropWindowController.swift`

```swift
class WinampMilkdropWindowController: NSWindowController {
    convenience init(skinManager: SkinManager, audioPlayer: AudioPlayer,
                    dockingController: DockingController, settings: AppSettings,
                    radioLibrary: RadioStationLibrary, playbackCoordinator: PlaybackCoordinator) {
        // Same pattern as Video window
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),  // Milkdrop larger default
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WinampWindowConfigurator.apply(to: window)
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear

        let rootView = WinampMilkdropWindow()
            .environment(skinManager)
            .environment(audioPlayer)
            .environment(dockingController)
            .environment(settings)
            .environment(radioLibrary)
            .environment(playbackCoordinator)

        let hostingController = NSHostingController(rootView: rootView)
        window.contentViewController = hostingController
        window.contentView = hostingController.view
        WinampWindowConfigurator.installHitSurface(on: window)

        self.init(window: window)
    }
}
```

**Tasks**:
- [ ] Create WinampMilkdropWindowController.swift
- [ ] Same pattern as Video controller
- [ ] Larger default size 400×300
- [ ] Create placeholder WinampMilkdropWindow SwiftUI view
- [ ] Test window compiles

#### Day 2: WindowCoordinator Integration

**File**: `MacAmpApp/ViewModels/WindowCoordinator.swift`

```swift
@MainActor
@Observable
final class WindowCoordinator {
    // Existing controllers
    private let mainController: NSWindowController
    private let eqController: NSWindowController
    private let playlistController: NSWindowController

    // NEW: Video and Milkdrop controllers
    private let videoController: NSWindowController
    private let milkdropController: NSWindowController

    var videoWindow: NSWindow? { videoController.window }
    var milkdropWindow: NSWindow? { milkdropController.window }

    init(...) {
        // ... existing main/eq/playlist setup ...

        // Create Video window
        videoController = WinampVideoWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Create Milkdrop window
        milkdropController = WinampMilkdropWindowController(
            skinManager: skinManager,
            audioPlayer: audioPlayer,
            dockingController: dockingController,
            settings: settings,
            radioLibrary: radioLibrary,
            playbackCoordinator: playbackCoordinator
        )

        // Register with WindowSnapManager
        if let video = videoWindow {
            WindowSnapManager.shared.register(window: video, kind: .video)
        }
        if let milkdrop = milkdropWindow {
            WindowSnapManager.shared.register(window: milkdrop, kind: .milkdrop)
        }

        // Add to delegate multiplexers
        videoDelegateMultiplexer = WindowDelegateMultiplexer()
        videoDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        videoWindow?.delegate = videoDelegateMultiplexer

        milkdropDelegateMultiplexer = WindowDelegateMultiplexer()
        milkdropDelegateMultiplexer?.add(delegate: WindowSnapManager.shared)
        milkdropWindow?.delegate = milkdropDelegateMultiplexer
    }

    // Window show/hide methods
    func showVideo() { videoWindow?.makeKeyAndOrderFront(nil) }
    func hideVideo() { videoWindow?.orderOut(nil) }
    func showMilkdrop() { milkdropWindow?.makeKeyAndOrderFront(nil) }
    func hideMilkdrop() { milkdropWindow?.orderOut(nil) }
}
```

**Tasks**:
- [ ] Add videoController and milkdropController properties
- [ ] Add videoWindow/milkdropWindow computed properties
- [ ] Create both controllers in init()
- [ ] Register with WindowSnapManager (2 windows)
- [ ] Add delegate multiplexer properties
- [ ] Create and assign multiplexers
- [ ] Add showVideo/hideVideo/showMilkdrop/hideMilkdrop methods
- [ ] Test windows can be shown/hidden

#### Day 2: WindowKind Enum Extension

**File**: `MacAmpApp/Utilities/WindowSnapManager.swift`

```swift
enum WindowKind: Hashable {
    case main
    case playlist
    case equalizer
    case video      // NEW
    case milkdrop   // NEW
}
```

**Tasks**:
- [ ] Add .video case to WindowKind enum
- [ ] Add .milkdrop case to WindowKind enum
- [ ] Verify WindowSnapManager compiles

#### Day 2: Persistence Extension

**File**: `MacAmpApp/ViewModels/WindowCoordinator.swift` (WindowFrameStore)

```swift
// persistenceKey extension already handles new kinds automatically!
// Just works because WindowKind has persistenceKey computed property
```

**Tasks**:
- [ ] Verify WindowFrameStore handles .video kind
- [ ] Verify WindowFrameStore handles .milkdrop kind
- [ ] Test persistence save/restore

#### Day 2 Deliverables
- ✅ Both NSWindowControllers created
- ✅ WindowCoordinator manages both windows
- ✅ WindowSnapManager registered (5 windows total!)
- ✅ Delegate multiplexers integrated
- ✅ Persistence automatic (WindowFrameStore)
- ✅ Show/hide methods working
- ✅ Windows can be opened independently
- ✅ Both windows invisible on startup (closed by default)

---

### Days 3-6: Video Window Implementation (PRIORITY 1)

**Goal**: Complete, fully-functional video playback window with VIDEO.bmp skinning

#### Day 3: VIDEO.bmp Sprite Parsing

**Goal**: Parse VIDEO.bmp from .wsz skins and extract sprites

##### 3.1 SkinManager Extension
**File**: `MacAmpApp/Models/SkinManager.swift`

```swift
extension SkinManager {
    struct VideoWindowSprites {
        // Titlebar
        let titlebarActive: NSImage?
        let titlebarInactive: NSImage?
        
        // Borders
        let borderTop: NSImage?
        let borderLeft: NSImage?
        let borderRight: NSImage?
        let borderBottom: NSImage?
        
        // Corners
        let cornerTopLeft: NSImage?
        let cornerTopRight: NSImage?
        let cornerBottomLeft: NSImage?
        let cornerBottomRight: NSImage?
        
        // Buttons
        let closeButton: [NSImage]  // [normal, hover, pressed]
        let minimizeButton: [NSImage]
        let shadeButton: [NSImage]
        
        // Playback controls
        let playButton: [NSImage]
        let pauseButton: [NSImage]
        let stopButton: [NSImage]
        let prevButton: [NSImage]
        let nextButton: [NSImage]
        
        // Seek bar
        let seekTrack: NSImage?
        let seekThumb: NSImage?
    }
    
    func loadVideoWindowSprites(from skin: Skin) -> VideoWindowSprites? {
        guard let videoBmp = skin.loadImage(named: "VIDEO") else {
            return nil
        }
        
        // Parse sprite regions (based on Winamp Classic VIDEO.bmp layout)
        // Standard layout: 233x119 pixels
        return VideoWindowSprites(
            titlebarActive: videoBmp.cropping(to: CGRect(x: 0, y: 0, width: 233, height: 14)),
            // ... extract all sprite regions
        )
    }
}
```

##### 3.2 Sprite Region Mapping
**Reference**: Internet-Archive/VIDEO.bmp (233x119)

Typical sprite layout:
```
Row 1 (y=0-13):   Titlebar active
Row 2 (y=14-27):  Titlebar inactive
Row 3 (y=28-41):  Window frame pieces
Row 4 (y=42-55):  Buttons (normal state)
Row 5 (y=56-69):  Buttons (hover state)
Row 6 (y=70-83):  Buttons (pressed state)
Row 7 (y=84-97):  Playback controls
Row 8 (y=98-118): Seek bar components
```

**NOTE**: Layout varies by skin. Parse dynamically or use standard dimensions with fallbacks.

##### 3.3 Classic Chrome Fallback
**File**: `MacAmpApp/Resources/DefaultVideoChrome/`

If VIDEO.bmp missing from skin:
- Use default "Winamp Classic" style chrome
- Neutral gray window frame
- Standard macOS-style buttons
- Ensures video window always works

##### Day 3 Deliverables
- ✅ VIDEO.bmp sprite parsing implemented
- ✅ VideoWindowSprites struct with all sprite regions
- ✅ Fallback to classic chrome if VIDEO.bmp missing
- ✅ Test with Internet-Archive skin

#### Day 4: Video Window Chrome & Layout

**Goal**: Build skinnable window chrome using VIDEO.bmp sprites

##### 4.1 VideoWindowChromeView
**File**: `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`

```swift
struct VideoWindowChromeView: View {
    @Environment(SkinManager.self) private var skinManager
    let sprites: SkinManager.VideoWindowSprites
    
    var body: some View {
        VStack(spacing: 0) {
            // Titlebar
            VideoWindowTitlebar(sprites: sprites)
                .frame(height: 14)
            
            // Content area
            // (AVPlayerView will go here)
            
            // Control bar
            VideoWindowControlBar(sprites: sprites)
                .frame(height: 40)
        }
        .overlay(
            // Window borders
            VideoWindowBorders(sprites: sprites)
        )
    }
}
```

##### 4.2 Titlebar Component
```swift
struct VideoWindowTitlebar: View {
    let sprites: SkinManager.VideoWindowSprites
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Title text
            Text("Video Window")
                .font(.system(size: 8))
                .foregroundColor(.white)
            
            Spacer()
            
            // Window buttons
            Button(action: { /* minimize */ }) {
                Image(nsImage: sprites.minimizeButton[0])
            }
            
            Button(action: { /* shade */ }) {
                Image(nsImage: sprites.shadeButton[0])
            }
            
            Button(action: { /* close */ }) {
                Image(nsImage: sprites.closeButton[0])
            }
        }
        .background(
            Image(nsImage: sprites.titlebarActive)
                .resizable()
        )
        .gesture(
            DragGesture()
                .onChanged { /* handle window drag */ }
        )
    }
}
```

##### 4.3 Control Bar Component
```swift
struct VideoWindowControlBar: View {
    let sprites: SkinManager.VideoWindowSprites
    @Environment(AudioPlayer.self) private var audioPlayer
    
    var body: some View {
        HStack(spacing: 4) {
            // Playback buttons
            Button(action: { audioPlayer.playPause() }) {
                Image(nsImage: audioPlayer.isPlaying 
                    ? sprites.pauseButton[0] 
                    : sprites.playButton[0])
            }
            
            Button(action: { audioPlayer.stop() }) {
                Image(nsImage: sprites.stopButton[0])
            }
            
            Button(action: { audioPlayer.previous() }) {
                Image(nsImage: sprites.prevButton[0])
            }
            
            Button(action: { audioPlayer.next() }) {
                Image(nsImage: sprites.nextButton[0])
            }
            
            // Seek bar
            VideoSeekBar(sprites: sprites)
        }
        .padding(4)
    }
}
```

##### Day 4 Deliverables
- ✅ VideoWindowChromeView with skinnable frame
- ✅ Titlebar with drag support
- ✅ Control bar with playback buttons
- ✅ All sprites rendering correctly
- ✅ Window looks like Winamp Classic video window

#### Day 5: AVPlayerView Integration

**Goal**: Embed native video playback in window

##### 5.1 AVPlayerViewRepresentable
**File**: `MacAmpApp/Views/Windows/AVPlayerViewRepresentable.swift`

```swift
import SwiftUI
import AVKit

struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none  // Use our VIDEO.bmp controls
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
```

##### 5.2 AudioPlayer Video Support
**File**: `MacAmpApp/Models/AudioPlayer.swift`

```swift
@Observable @MainActor
final class AudioPlayer {
    // Existing audio properties...
    
    // NEW: Video support
    var videoPlayer: AVPlayer?
    var currentMediaType: MediaType = .audio
    
    enum MediaType {
        case audio
        case video
    }
    
    func loadMedia(url: URL) {
        let mediaType = detectMediaType(url: url)
        currentMediaType = mediaType
        
        switch mediaType {
        case .audio:
            loadAudioFile(url: url)  // Existing
        case .video:
            loadVideoFile(url: url)
        }
    }
    
    private func loadVideoFile(url: URL) {
        // Stop audio if playing
        stop()
        
        // Create video player
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.play()
        
        // Update state
        isPlaying = true
        currentMediaType = .video
    }
    
    private func detectMediaType(url: URL) -> MediaType {
        let videoExtensions = ["mp4", "mov", "m4v", "avi"]
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) ? .video : .audio
    }
}
```

##### 5.3 Complete VideoWindowView
**File**: `MacAmpApp/Views/Windows/VideoWindowView.swift`

```swift
struct VideoWindowView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(SkinManager.self) private var skinManager
    @Environment(AudioPlayer.self) private var audioPlayer
    
    var body: some View {
        Group {
            if let sprites = skinManager.currentSkin.videoSprites {
                VideoWindowChromeView(sprites: sprites) {
                    // Content area
                    if audioPlayer.currentMediaType == .video,
                       let player = audioPlayer.videoPlayer {
                        AVPlayerViewRepresentable(player: player)
                    } else {
                        // No video loaded state
                        Text("No video loaded")
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // Fallback: classic chrome
                VideoWindowFallbackView {
                    if audioPlayer.currentMediaType == .video,
                       let player = audioPlayer.videoPlayer {
                        AVPlayerViewRepresentable(player: player)
                    }
                }
            }
        }
        .frame(
            width: appSettings.videoWindowFrame?.width ?? 275,
            height: appSettings.videoWindowFrame?.height ?? 116
        )
        .background(.black)
    }
}
```

##### Day 5 Deliverables
- ✅ AVPlayerView rendering video
- ✅ Video files play when loaded
- ✅ Playback controls work (play, pause, stop)
- ✅ Seek bar functional
- ✅ Video window fully operational

#### Day 6: Video Window Polish & Integration

**Goal**: Complete video window with all features working

##### 6.1 Playlist Integration
**Files**: Playlist loading code

- Add video file extensions to supported formats
- Display video files with 🎬 icon
- Double-click loads video in video player
- Video metadata displayed (duration, resolution)

##### 6.2 Window Positioning & Persistence
```swift
extension VideoWindowView {
    func onAppear() {
        // Restore saved position
        if let savedFrame = appSettings.videoWindowFrame {
            // Position window
        } else {
            // Default position (below main window)
            let defaultFrame = CGRect(x: 0, y: 232, width: 275, height: 116)
            appSettings.videoWindowFrame = defaultFrame
        }
    }
    
    func onFrameChange(_ newFrame: CGRect) {
        // Save position
        appSettings.videoWindowFrame = newFrame
    }
}
```

##### 6.3 Shade Mode
```swift
// When shade button clicked
appSettings.videoWindowShaded.toggle()

// Collapsed view shows only titlebar
if appSettings.videoWindowShaded {
    VideoWindowTitlebar(sprites: sprites)
        .frame(height: 14)
} else {
    // Full window
}
```

##### 6.4 V Button Preparation
**File**: `MacAmpApp/Views/WinampMainWindow.swift` (buildClutterBarButtons)

**Note**: Full V button wiring happens in Day 10.1 (after WindowCoordinator has show/hide methods)

**Day 6 Prep**:
- [ ] Identify V button location in clutter bar (line ~589-597)
- [ ] Verify V button sprite exists (MAIN_CLUTTER_BAR_BUTTON_V)
- [ ] Document current state (disabled/stub)
- [ ] Plan integration point for Day 10.1

**Actual wiring**: Deferred to Day 10.1 (WindowCoordinator.showVideo() approach)

##### Day 6 Deliverables
- ✅ Video files appear in playlist
- ✅ Double-click plays video
- ✅ Window positioning works
- ✅ State persists across restarts
- ✅ Shade mode functional
- ✅ V button location identified (wiring in Day 10.1)
- ✅ VIDEO WINDOW COMPLETE (UI trigger wiring pending Day 10)

---

### Days 7-10: Milkdrop Window Implementation (PRIORITY 2)

**Goal**: Complete, fully-functional Milkdrop visualization window

#### Day 7: Milkdrop Foundation

**Goal**: Set up Milkdrop window structure

##### 7.1 MilkdropWindowView Stub
**File**: `MacAmpApp/Views/Windows/MilkdropWindowView.swift`

```swift
struct MilkdropWindowView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(SkinManager.self) private var skinManager
    @Environment(AudioPlayer.self) private var audioPlayer
    
    var body: some View {
        VStack {
            // Titlebar (simple for now, no MILKDROP.bmp skinning in v1)
            Text("Milkdrop")
                .frame(maxWidth: .infinity)
                .background(.gray)
            
            // Content area (placeholder)
            Text("Butterchurn visualization here")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
        }
        .frame(
            width: appSettings.milkdropWindowFrame?.width ?? 400,
            height: appSettings.milkdropWindowFrame?.height ?? 300
        )
    }
}
```

##### Day 7 Deliverables
- ✅ MilkdropWindowView placeholder
- ✅ Window can open/close independently
- ✅ Positioning works
- ✅ Both windows can be open simultaneously

#### Day 8: Butterchurn Integration

**Goal**: Embed Butterchurn visualization

##### 8.1 Butterchurn HTML Bundle
**Directory**: `MacAmpApp/Resources/Butterchurn/`

**Files** (same as original plan):
- `index.html` - Main visualization page
- `butterchurn.min.js` - Core library
- `butterchurn-presets.min.js` - Preset library
- `bridge.js` - Swift ↔ JS communication

##### 8.2 ButterchurnWebView
**File**: `MacAmpApp/Views/Windows/ButterchurnWebView.swift`

(Same implementation as original plan)

##### Day 8 Deliverables
- ✅ Butterchurn HTML bundle created
- ✅ WKWebView loads Butterchurn
- ✅ 5-8 presets loaded
- ✅ Canvas renders (no audio data yet)

#### Day 9: Audio Tap Extension for Milkdrop

**Goal**: Extend EXISTING AudioPlayer tap to provide Milkdrop FFT data (Oracle's guidance - single tap!)

##### 9.1 Extend AudioPlayer Tap (NOT new AudioAnalyzer)
**File**: `MacAmpApp/Models/AudioPlayer.swift`

```swift
@Observable @MainActor
final class AudioPlayer {
    // Existing tap infrastructure...

    // NEW: Milkdrop FFT data (higher resolution than 20-band spectrum)
    private var milkdropFFTData: [Float] = Array(repeating: 0, count: 512)  // 512 bins for Milkdrop
    private var milkdropWaveform: [Float] = Array(repeating: 0, count: 576)  // 576 samples

    // Public accessors for Milkdrop
    func getMilkdropSpectrum() -> [Float] {
        return milkdropFFTData
    }

    func getMilkdropWaveform() -> [Float] {
        return milkdropWaveform
    }

    // In EXISTING makeVisualizerTapHandler() callback:
    // - Extract PCM buffer (already doing this)
    // - Run 512-bin FFT for Milkdrop (in addition to 20-band for spectrum)
    // - Generate 576-sample waveform for Milkdrop
    // - Update milkdropFFTData and milkdropWaveform
    // - All from SAME audio buffer (single tap, no duplicate processing!)
}
```

**Tasks**:
- [ ] Add milkdropFFTData property (512 bins)
- [ ] Add milkdropWaveform property (576 samples)
- [ ] Add getMilkdropSpectrum() method
- [ ] Add getMilkdropWaveform() method
- [ ] Modify makeVisualizerTapHandler() to compute Milkdrop data
- [ ] Use vDSP for 512-bin FFT (Accelerate framework)
- [ ] Extract 576 PCM samples for waveform
- [ ] Test FFT data generation during playback

##### 9.2 Wire to WinampMilkdropWindow
**File**: `MacAmpApp/Views/WinampMilkdropWindow.swift`

```swift
struct WinampMilkdropWindow: View {
    @Environment(AudioPlayer.self) var audioPlayer
    @State private var spectrum: [Float] = []
    @State private var waveform: [Float] = []

    var body: some View {
        ButterchurnWebView(spectrum: $spectrum, waveform: $waveform)
            .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                // Read from EXISTING AudioPlayer tap
                spectrum = audioPlayer.getMilkdropSpectrum()
                waveform = audioPlayer.getMilkdropWaveform()
            }
    }
}
```

**Tasks**:
- [ ] Add spectrum and waveform state properties
- [ ] Add Timer publisher for 60fps updates
- [ ] Call getMilkdropSpectrum() / getMilkdropWaveform()
- [ ] Pass data to ButterchurnWebView
- [ ] Test data flows correctly

##### 9.3 Update ButterchurnWebView
**File**: `MacAmpApp/Views/ButterchurnWebView.swift`

```swift
struct ButterchurnWebView: NSViewRepresentable {
    @Binding var spectrum: [Float]   // 512 bins
    @Binding var waveform: [Float]   // 576 samples

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Send both spectrum and waveform to Butterchurn
        let spectrumJSON = spectrum.map { "\($0)" }.joined(separator: ",")
        let waveformJSON = waveform.map { "\($0)" }.joined(separator: ",")

        let script = "updateAudioData([\(spectrumJSON)], [\(waveformJSON)])"
        webView.evaluateJavaScript(script)
    }
}
```

**Tasks**:
- [ ] Update ButterchurnWebView to accept spectrum AND waveform
- [ ] Serialize both arrays to JavaScript
- [ ] Update bridge.js to accept both parameters
- [ ] Test data arrives in Butterchurn correctly

##### Day 9 Deliverables
- ✅ EXTENDED existing AudioPlayer tap (no new analyzer!)
- ✅ 512-bin FFT for Milkdrop generated
- ✅ 576-sample waveform generated
- ✅ Single tap serves both spectrum and Milkdrop
- ✅ Audio data flows to Butterchurn
- ✅ Visualization syncs to audio playback
- ✅ 60fps rendering
- ✅ No duplicate audio processing

#### Day 10: UI Integration & Testing

**Goal**: Wire Video and Milkdrop to UI triggers, then test both windows

##### 10.1 V Button Integration (Video Window)
**File**: `MacAmpApp/Views/WinampMainWindow.swift`

```swift
// In buildClutterBarButtons():
Button(action: {
    WindowCoordinator.shared.showVideo()  // or hideVideo() if open
}) {
    SimpleSpriteImage("MAIN_CLUTTER_BAR_BUTTON_V", width: 8, height: 7)
}
.buttonStyle(.plain)
.help("Video Window (Ctrl+V)")
.at(Coords.clutterButtonV)
```

**Tasks**:
- [ ] Update V button action (currently disabled)
- [ ] Call WindowCoordinator.shared.showVideo() / hideVideo()
- [ ] Add selected state sprite when window open
- [ ] Test V button toggles video window
- [ ] Verify Ctrl+V keyboard shortcut works

##### 10.2 Options Menu Integration (Milkdrop)
**File**: `MacAmpApp/Views/WinampMainWindow.swift` (showOptionsMenu)

```swift
// Add to Options menu after existing items:
menu.addItem(.separator())

menu.addItem(createMenuItem(
    title: "Milkdrop",
    isChecked: settings.showMilkdropWindow,  // Checkbox on/off
    keyEquivalent: "k",
    modifiers: [.control, .shift],
    action: { [weak settings] in
        if let show = settings?.showMilkdropWindow {
            if show {
                WindowCoordinator.shared.hideMilkdrop()
                settings?.showMilkdropWindow = false
            } else {
                WindowCoordinator.shared.showMilkdrop()
                settings?.showMilkdropWindow = true
            }
        }
    }
))
```

**Tasks**:
- [ ] Add Milkdrop checkbox to Options menu
- [ ] Show checkmark when window open
- [ ] Wire to WindowCoordinator.showMilkdrop() / hideMilkdrop()
- [ ] Add Ctrl+Shift+K keyboard shortcut
- [ ] Test menu checkbox toggles window
- [ ] Test keyboard shortcut works
- [ ] Verify state persists

##### 10.3 Preset Selection System
**File**: `MacAmpApp/Views/WinampMilkdropWindow.swift`

**Tasks**:
- [ ] Add preset selection menu
- [ ] Implement Ctrl+[ / Ctrl+] shortcuts (next/prev preset)
- [ ] Add auto-cycle timer (30s)
- [ ] Wire preset changes to Butterchurn
- [ ] Test preset switching

##### 10.4 Skin Integration
**File**: `MacAmpApp/Views/ButterchurnWebView.swift`

**Tasks**:
- [ ] Extract skin colors from SkinManager
- [ ] Pass to Butterchurn via JavaScript bridge
- [ ] Test colors update with skin changes

##### 10.5 Comprehensive Testing
**Both Windows**:
- [ ] Video window plays MP4/MOV
- [ ] Milkdrop window shows visualization
- [ ] Both windows can be open simultaneously
- [ ] Video playback + audio visualization at same time
- [ ] State persists across restarts
- [ ] Ctrl+V toggles video window
- [ ] Ctrl+Shift+K toggles milkdrop window
- [ ] Windows can be positioned independently
- [ ] Shade mode works for video window
- [ ] No memory leaks (1hr+ test)

##### Day 10 Deliverables
- ✅ Milkdrop window complete
- ✅ Both windows fully functional
- ✅ All integration tests passing
- ✅ Documentation updated
- ✅ FEATURE COMPLETE!

---

## File Structure (New Files)

```
MacAmpApp/
├── Models/
│   ├── AudioPlayer.swift                 [MODIFIED - video support + Milkdrop FFT extension]
│   ├── AppSettings.swift                 [MODIFIED - 2 window states]
│   └── SkinManager.swift                 [MODIFIED - VIDEO.bmp parsing]
├── Windows/
│   ├── WinampVideoWindowController.swift [NEW - Video NSWindowController]
│   └── WinampMilkdropWindowController.swift [NEW - Milkdrop NSWindowController]
├── ViewModels/
│   └── WindowCoordinator.swift           [MODIFIED - Add video + milkdrop controllers]
├── Utilities/
│   └── WindowSnapManager.swift           [MODIFIED - Add .video and .milkdrop kinds]
├── Views/
│   └── Windows/                          [NEW DIRECTORY]
│       ├── VideoWindowView.swift         [NEW - video window container]
│       ├── VideoWindowChromeView.swift   [NEW - VIDEO.bmp chrome]
│       ├── VideoWindowTitlebar.swift     [NEW - titlebar component]
│       ├── VideoWindowControlBar.swift   [NEW - playback controls]
│       ├── VideoWindowBorders.swift      [NEW - window frame]
│       ├── VideoSeekBar.swift            [NEW - seek control]
│       ├── AVPlayerViewRepresentable.swift [NEW - video player]
│       ├── MilkdropWindowView.swift      [NEW - milkdrop container]
│       └── ButterchurnWebView.swift      [NEW - visualization]
├── Resources/
│   ├── Butterchurn/                     [NEW - HTML bundle]
│   │   ├── index.html
│   │   ├── butterchurn.min.js
│   │   ├── butterchurn-presets.min.js
│   │   └── bridge.js
│   └── DefaultVideoChrome/              [NEW - fallback sprites]
│       └── classic-video-chrome.png
└── AppCommands.swift                     [MODIFIED - 2 shortcuts]

MacAmpTests/
└── VideoMilkdropTests.swift             [NEW - test suite]

docs/
└── features/
    ├── video-window.md                   [NEW - video docs]
    └── milkdrop-window.md                [NEW - milkdrop docs]
```

---

## Success Criteria (V1.0 MVP)

### Video Window (Must-Have)
- ✅ V button (Ctrl+V) toggles video window
- ✅ VIDEO.bmp skinning works
- ✅ MP4, MOV, M4V playback
- ✅ Playback controls functional (play, pause, stop, seek)
- ✅ Window positioning persists
- ✅ Shade mode works
- ✅ Playlist integration (video files show with 🎬)

### Milkdrop Window (Must-Have)
- ✅ Ctrl+Shift+K toggles milkdrop window
- ✅ Butterchurn visualization syncs to audio
- ✅ 5-8 presets auto-cycle
- ✅ Manual preset selection works
- ✅ Window positioning persists
- ✅ Real-time FFT analysis

### Integration (Must-Have)
- ✅ Both windows can be open simultaneously
- ✅ Independent lifecycles
- ✅ State persists across restarts
- ✅ No memory leaks
- ✅ Performance acceptable (<20% CPU)

### Future Enhancements (V2.0+)
- ⏳ MILKDROP.bmp skinning (if exists in skins)
- ⏳ Fullscreen mode for milkdrop
- ⏳ Desktop mode for milkdrop
- ⏳ FFmpeg for more video formats
- ⏳ .milk2 preset support (Metal renderer)
- ⏳ Custom preset creation

---

## Risk Mitigation

| Risk | Mitigation | Status |
|------|------------|--------|
| **AVPlayer Integration Complexity** | Use AVPlayerView (native controls disabled), test codec support, handle errors gracefully | ⏳ Day 5 |
| **AVPlayer Format Support** | Focus on H.264/AAC (MP4, MOV, M4V), document unsupported formats, consider FFmpeg later | ⏳ Day 5-6 |
| **AVPlayer Audio Routing** | Ensure video audio routes through AudioPlayer for consistency, test audio/video switching | ⏳ Day 5 |
| **Butterchurn Bridge Security** | WKWebView sandbox, validate FFT data, rate-limit evaluateJavaScript calls, handle script errors | ⏳ Day 8-9 |
| **WKWebView Content Security** | Use file:// URLs for local HTML, no external resources, Content Security Policy headers | ⏳ Day 8 |
| **JavaScript Bridge Errors** | Try/catch in bridge.js, graceful degradation, log errors to Swift console | ⏳ Day 9 |
| VIDEO.bmp parsing complexity | Fallback to classic chrome if VIDEO.bmp missing or malformed | ✅ Designed |
| Sprite layout varies by skin | Use standard dimensions + auto-detection, test with 3+ skins | ✅ Designed |
| Both windows open = resource usage | Profile CPU/GPU during simultaneous playback, optimize if >30% CPU | ⏳ Day 10 |
| Video + audio mode switching | Proper AudioPlayer state machine, stop video when audio plays | ✅ Designed |
| WKWebView FFT update overhead | Throttle to 60fps max, batch updates, monitor frame drops | ✅ Designed |
| Memory leaks (5 windows total) | Proper NSWindowController cleanup, weak references, test 1hr+ playback | ⏳ Day 10 |
| WindowSnapManager with 5 windows | Test cluster detection, verify snapping with all windows, edge case testing | ⏳ Day 2 |
| Delegate multiplexer scaling | Verify 5 windows don't cause delegate forwarding issues | ⏳ Day 2 |

---

## Timeline Summary

| Days | Phase | Deliverables |
|------|-------|--------------|
| **1-2** | NSWindowController Setup | Video + Milkdrop controllers, WindowCoordinator integration, WindowSnapManager registration |
| **3** | VIDEO.bmp Parsing | Sprite extraction, SkinManager extension, fallback chrome |
| **4** | Video Chrome | Skinnable window frame, controls, borders |
| **5** | AVPlayer Integration | Video playback, AVPlayerView, codec support |
| **6** | Video Polish | Playlist integration, V button wiring |
| **7** | Milkdrop Foundation | GEN.BMP chrome (reuse existing), window structure |
| **8** | Butterchurn | HTML bundle, WKWebView, preset system |
| **9** | Audio Tap Extension | Extend existing tap, 512-bin FFT, 576-sample waveform |
| **10** | UI Integration & Testing | Options menu, presets, comprehensive testing |

**Total**: 8-10 working days
**Milestone**: Day 6 (Video window complete)
**Completion**: Day 8-10 (Both windows complete)
**Architecture**: NSWindowController pattern (TASK 1 foundation)

---

---

## ADDENDUM: VIDEO Window Full Resize (Post-MVP)

**Date Added**: 2025-11-14
**Priority**: Post-MVP enhancement
**Research**: Complete (Oracle + Webamp analysis)
**Status**: Specification ready, implementation deferred

### Overview

Implement full drag-resize for VIDEO window using the same quantized segment pattern as Playlist window (25×29px grid). This replaces the current 1x/2x scaleEffect approach with true window resizing.

### Oracle Guidance Summary

**Key Decisions (Oracle-validated):**
1. **Use identical 25×29px segmented resize as Playlist** - keeps windows aligned with docking grid
2. **Minimum size:** 275×116px (matches Main/EQ windows exactly) - absolute minimum
3. **Default size:** 275×232px (current VIDEO window size) - [0,4] segments
4. **Maximum size:** Unbounded, screen-constrained at runtime
5. **Aspect ratio:** Freeform window resize, video content uses aspectFit internally
6. **Chrome layout:** Three-section pattern (LEFT 125px + CENTER tiles + RIGHT 125px)
7. **Resize handle:** 20×20px bottom-right corner (matches Playlist)
8. **1x/2x buttons:** KEEP as "preset size" shortcuts (1x=[0,4] default, 2x=[11,12] double)
9. **Resize type:** Quantized to segments (not continuous pixels)
10. **Base dimensions:** 275×116px matching Main/EQ windows

### Size Model (Reuse Playlist Pattern)

```swift
// From tasks/playlist-resize-analysis/QUICK_REFERENCE.md
// Adapted for VIDEO window dimensions
struct Size2D: Equatable, Codable {
    var width: Int   // Number of 25px segments (beyond 275px base)
    var height: Int  // Number of 29px segments (beyond 116px base)

    // VIDEO window base dimensions (matches Main/EQ)
    static let videoBase = CGSize(width: 275, height: 116)

    func toPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }

    // Video-specific presets
    static let videoMinimum = Size2D(width: 0, height: 0)   // 275×116 (same as Main/EQ)
    static let videoDefault = Size2D(width: 0, height: 4)   // 275×232 (current default)
    static let video2x = Size2D(width: 11, height: 12)      // 550×464 (2x of default)
}
```

**Note:**
- Minimum: 275×116 (identical to Main/EQ windows)
- Default: 275×232 (current VIDEO window size, [0,4] segments)
- 2x Default: 550×464 (exactly 2× the default size, [11,12] segments)
- Base dimensions: 275×116px matching WinampSizes.main and WinampSizes.equalizer

### Chrome Architecture Changes

**Current (scaleEffect-based):**
```swift
.frame(width: 275, height: 232)
.scaleEffect(videoWindowSizeMode == .twoX ? 2.0 : 1.0)
.frame(width: 275 * scale, height: 232 * scale)
```

**Target (segment-based):**
```swift
let pixelSize = videoSize.toPixels()  // e.g., 275×232 or 300×261 or 550×464

// Chrome components calculate from pixelSize
let contentWidth = pixelSize.width - 11 - 8   // Minus borders
let contentHeight = pixelSize.height - 20 - 38  // Minus top/bottom

VideoWindowChromeView(size: videoSize) {
    AVPlayerView()
        .frame(width: contentWidth, height: contentHeight)
}
.frame(width: pixelSize.width, height: pixelSize.height)
// NO scaleEffect - true window sizing
```

### Bottom Bar Three-Section Pattern

**Current:**
- LEFT (125px) + TILE (25px fixed) + RIGHT (125px)
- Total: 275px fixed

**Target (resizable):**
```swift
HStack(spacing: 0) {
    // LEFT section (125px fixed) - baked-on buttons (fullscreen, 1x, 2x, TV)
    SimpleSpriteImage("VIDEO_BOTTOM_LEFT", width: 125, height: 38)

    // CENTER section (dynamic) - tiles VIDEO_BOTTOM_TILE
    let centerWidth = pixelSize.width - 250  // Can be 0 at minimum
    if centerWidth > 0 {
        ForEach(0..<Int(centerWidth / 25), id: \.self) { _ in
            SimpleSpriteImage("VIDEO_BOTTOM_TILE", width: 25, height: 38)
        }
    }

    // RIGHT section (125px fixed) - metadata display area
    SimpleSpriteImage("VIDEO_BOTTOM_RIGHT", width: 125, height: 38)
}
```

### Titlebar Stretchy Tiles

**Oracle Note:** VIDEO.bmp already has VIDEO_TITLEBAR_STRETCHY sprites for width expansion

**Pattern:**
```swift
// Base titlebar: LEFT (25px) + CENTER (100px) + RIGHT (25px) = 150px fixed
// Stretchy section: Tiles VIDEO_TITLEBAR_STRETCHY (25px) to fill gap

let stretchyTileCount = Int((pixelSize.width - 150) / 25)  // Number of stretch tiles

ForEach(0..<stretchyTileCount, id: \.self) { i in
    SimpleSpriteImage("VIDEO_TITLEBAR_STRETCHY_\(suffix)", width: 25, height: 20)
        .position(x: 25 + 12.5 + CGFloat(i) * 25, y: 10)
}
```

### Resize Handle Implementation

**Location:** Bottom-right corner of VIDEO_BOTTOM_RIGHT sprite
**Size:** 20×20px (invisible drag area)
**Pattern:** Reuse Playlist resize gesture (quantized drag)

```swift
@ViewBuilder
private func buildVideoResizeHandle() -> some View {
    Rectangle()
        .fill(Color.clear)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
        .cursor(.resizeNorthWestSouthEast)  // macOS resize cursor
        .gesture(videoResizeGesture)
        .position(x: pixelSize.width - 10, y: pixelSize.height - 10)  // Bottom-right
}

private var videoResizeGesture: some Gesture {
    DragGesture()
        .onChanged { value in
            let deltaW = Int(round(value.translation.width / 25))
            let deltaH = Int(round(value.translation.height / 29))

            videoSize = Size2D(
                width: max(0, startSize.width + deltaW),
                height: max(0, startSize.height + deltaH)
            )
        }
}
```

### 1x/2x Button Behavior Change

**Current:** Sets scaleEffect multiplier
**Target:** Sets Size2D segments as presets

```swift
// 1x button action
Button(action: {
    videoSize = .video1x  // [0,0] = 275×232
}) { /* invisible overlay */ }

// 2x button action
Button(action: {
    videoSize = .video2x  // [11,8] = 550×464
}) { /* invisible overlay */ }
```

### Implementation Phases

**Phase 1: Size2D Integration** (2 hours)
- Create VideoWindowSizeState observable wrapping Size2D
- Replace scaleEffect with segment-based sizing
- Update chrome layout to calculate from pixelSize
- Test at sizes [0,0], [1,0], [0,1]

**Phase 2: Chrome Tiling** (2 hours)
- Implement three-section bottom bar (LEFT + CENTER tiles + RIGHT)
- Add titlebar stretchy tile rendering
- Add vertical border tiling for height changes
- Test chrome aligns perfectly at all sizes

**Phase 3: Resize Handle** (1 hour)
- Add 20×20px drag area in bottom-right
- Implement quantized drag gesture
- Wire to VideoWindowSizeState
- Test drag resizing works

**Phase 4: Button Migration** (1 hour)
- Change 1x/2x buttons to set Size2D presets
- Remove videoWindowSizeMode enum (no longer needed)
- Remove scaleEffect logic
- Test buttons set correct sizes

**Phase 5: Integration & Testing** (2 hours)
- Update WindowCoordinator.resizeVideoWindow()
- Test docking with resized VIDEO window
- Test persistence (save/restore Size2D)
- Verify no regressions

**Total:** ~8 hours

### Files to Modify

1. `MacAmpApp/Models/VideoWindowSizeState.swift` [NEW]
   - Wraps Size2D for VIDEO window
   - Persists to UserDefaults
   - Observable for reactive updates

2. `MacAmpApp/Views/Windows/VideoWindowChromeView.swift`
   - Accept Size2D parameter
   - Calculate dimensions from segments
   - Implement three-section bottom bar
   - Add titlebar stretchy tiles
   - Add resize handle

3. `MacAmpApp/Views/WinampVideoWindow.swift`
   - Remove scaleEffect logic
   - Pass Size2D to chrome view
   - Use segment-based frame sizing

4. `MacAmpApp/ViewModels/WindowCoordinator.swift`
   - Update resizeVideoWindow() to use Size2D
   - Update docking context for segment-based sizing
   - Update persistence to save Size2D

5. `MacAmpApp/Models/AppSettings.swift`
   - Replace videoWindowSizeMode with videoWindowSize: Size2D
   - Update UserDefaults persistence

### Success Criteria

- [ ] VIDEO window can be drag-resized from bottom-right corner
- [ ] Resizes in 25×29px increments (quantized)
- [ ] Minimum size: 275×232px (no smaller)
- [ ] Maximum size: Screen bounds minus margins
- [ ] Chrome tiles correctly at all sizes (no gaps or overlaps)
- [ ] Video content maintains aspect ratio (letterbox/pillarbox)
- [ ] 1x/2x buttons set preset sizes [0,0] and [11,8]
- [ ] Docking preserved during resize
- [ ] Size persists across app restarts
- [ ] No scaleEffect used (true window sizing)

---

---

## ADDENDUM: Video Volume Control Integration (Post-MVP)

**Date Added**: 2025-11-14
**Priority**: Post-MVP enhancement
**Estimated Effort**: 1-2 hours
**Status**: Specification ready, implementation deferred

### Overview

Sync main window volume control with video playback. Currently, the volume slider only affects audio playback through AVAudioEngine - video played through AVPlayer has independent volume.

### Current Behavior (Bug)

**Audio Playback:**
- Main window volume slider → `audioPlayer.volume` → AVAudioEngine.mainMixerNode.volume
- Works correctly ✅

**Video Playback:**
- Main window volume slider → `audioPlayer.volume` → NO EFFECT on AVPlayer ❌
- Video plays at system volume (100%)
- User expectation: Volume slider should control video audio

### Implementation Specification

**Sync Pattern:**
```swift
// In AudioPlayer.swift
var volume: Float = 0.75 {
    didSet {
        // Existing: Update audio engine
        audioEngine.mainMixerNode.volume = volume

        // NEW: Update video player
        videoPlayer?.volume = volume
    }
}
```

**Initialization:**
```swift
// In loadVideoFile()
func loadVideoFile(url: URL) {
    videoPlayer = AVPlayer(url: url)
    videoPlayer?.volume = volume  // Apply current volume immediately
    videoPlayer?.play()
}
```

**Mute Button:**
```swift
// In toggleMute() or similar
func setMuted(_ muted: Bool) {
    isMuted = muted

    // Existing: Mute audio engine
    audioEngine.mainMixerNode.volume = muted ? 0.0 : volume

    // NEW: Mute video player
    videoPlayer?.isMuted = muted
}
```

### Files to Modify

1. **MacAmpApp/Audio/AudioPlayer.swift**
   - Update `volume` didSet to sync with videoPlayer
   - Update `loadVideoFile()` to apply initial volume
   - Update mute functionality to affect video

### Success Criteria

- [ ] Main window volume slider controls video audio level
- [ ] Mute button mutes video audio
- [ ] Volume changes during video playback apply immediately
- [ ] Switching from audio to video preserves volume level
- [ ] Switching from video to audio preserves volume level
- [ ] Volume persists across app restarts (already working for audio)

### Testing

**Test Cases:**
1. Load video file, adjust volume slider → video audio changes
2. Mute button while video playing → video audio mutes
3. Change volume during video playback → immediate effect
4. Load audio file, change volume, load video → video uses same volume
5. Video at 50% volume, quit/relaunch, play video → still 50%

**Estimated Time:** 1-2 hours (simple sync logic)

---

**Plan Created**: 2025-11-08 (Initial two-window architecture)
**Plan Corrected**: 2025-11-09 (NSWindowController pattern, single audio tap, corrected triggers)
**Plan Updated**: 2025-11-14 (Added VIDEO resize + volume control specs - Oracle validated)
**Oracle Review**: A- grade (High confidence), Resize spec A grade
**Implementation Start**: Upon user approval
**Target Completion**: Days 8-10 + 8 hours resize + 2 hours volume
**Next Review**: Post VIDEO 2x chrome scaling completion

---

## LESSONS LEARNED: VIDEO Window Resize

For applying to Playlist window later.

**Key Insights:**
1. Calculate tile counts with ceil() for full coverage
2. Use OLD positioning formulas that worked
3. Exclude invisible windows from snap (window.isVisible)
4. Preview pattern reduces jitter (commit at end only)
5. Don't sync NSWindow during drag
6. Preview needs AppKit overlay to extend beyond bounds

**Pattern:**
- Size2D quantization
- Dynamic tile calculation
- Preview during drag, commit at end
- isVisible filtering critical
