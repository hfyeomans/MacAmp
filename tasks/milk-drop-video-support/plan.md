# Implementation Plan: Video & Milkdrop Windows (Two-Window Architecture)

**Task ID**: milk-drop-video-support  
**Architecture**: TWO Independent Windows (Video + Milkdrop)  
**Priority**: Video Window FIRST, then Milkdrop Window  
**Timeline**: 10 days (Phased implementation)  
**Approved**: 2025-11-08 (Option A)

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

User Opens Milkdrop (Menu or Ctrl+Shift+M)
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

### Days 1-2: Foundation (Shared Infrastructure)

**Goal**: Set up state management and shared infrastructure for BOTH windows

#### AppSettings Extension
**File**: `MacAmpApp/Models/AppSettings.swift`

```swift
@Observable @MainActor
final class AppSettings {
    // VIDEO WINDOW STATE
    var showVideoWindow: Bool = false {
        didSet { UserDefaults.standard.set(showVideoWindow, forKey: "showVideoWindow") }
    }
    
    var videoWindowFrame: CGRect? {
        didSet {
            if let frame = videoWindowFrame {
                UserDefaults.standard.set(NSStringFromRect(frame), forKey: "videoWindowFrame")
            }
        }
    }
    
    var videoWindowShaded: Bool = false {
        didSet { UserDefaults.standard.set(videoWindowShaded, forKey: "videoWindowShaded") }
    }
    
    // MILKDROP WINDOW STATE
    var showMilkdropWindow: Bool = false {
        didSet { UserDefaults.standard.set(showMilkdropWindow, forKey: "showMilkdropWindow") }
    }
    
    var milkdropWindowFrame: CGRect? {
        didSet {
            if let frame = milkdropWindowFrame {
                UserDefaults.standard.set(NSStringFromRect(frame), forKey: "milkdropWindowFrame")
            }
        }
    }
    
    var milkdropMode: MilkdropMode = .butterchurn {
        didSet { UserDefaults.standard.set(milkdropMode.rawValue, forKey: "milkdropMode") }
    }
    
    var lastUsedPresetIndex: Int = 0 {
        didSet { UserDefaults.standard.set(lastUsedPresetIndex, forKey: "lastUsedPresetIndex") }
    }
}

enum MilkdropMode: String, Codable {
    case butterchurn
    case fullscreen
    case desktop
}
```

#### AppCommands Extension
**File**: `MacAmpApp/AppCommands.swift`

```swift
CommandGroup(after: .windowArrangement) {
    Button("Toggle Video Window") {
        appSettings.showVideoWindow.toggle()
    }
    .keyboardShortcut("v", modifiers: [.control])
    
    Button("Toggle Milkdrop Window") {
        appSettings.showMilkdropWindow.toggle()
    }
    .keyboardShortcut("m", modifiers: [.control, .shift])
}
```

#### Window Stubs
**File**: `MacAmpApp/Views/WinampMainWindow.swift`

```swift
// Add to body
if appSettings.showVideoWindow {
    VideoWindowView()
        .environment(appSettings)
        .environment(skinManager)
        .environment(audioPlayer)
}

if appSettings.showMilkdropWindow {
    MilkdropWindowView()
        .environment(appSettings)
        .environment(skinManager)
        .environment(audioPlayer)
}
```

**Create Placeholder Views**:
- `MacAmpApp/Views/Windows/VideoWindowView.swift`
- `MacAmpApp/Views/Windows/MilkdropWindowView.swift`

#### Day 1-2 Deliverables
- ✅ AppSettings extended with both window states
- ✅ Keyboard shortcuts (Ctrl+V, Ctrl+Shift+M)
- ✅ Placeholder views for both windows
- ✅ State persists across restarts
- ✅ Both windows can toggle independently

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

##### 6.4 V Button Final Wiring
**File**: `MacAmpApp/Views/ClutterBar.swift` (or wherever V button is)

```swift
Button(action: {
    appSettings.showVideoWindow.toggle()
}) {
    // V button sprite from skin
}
.help("Video Window (Ctrl+V)")
```

##### Day 6 Deliverables
- ✅ Video files appear in playlist
- ✅ Double-click plays video
- ✅ Window positioning works
- ✅ State persists across restarts
- ✅ Shade mode functional
- ✅ V button opens/closes video window
- ✅ VIDEO WINDOW COMPLETE!

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

#### Day 9: FFT Audio Bridge

**Goal**: Connect audio analysis to Butterchurn

##### 9.1 AudioAnalyzer
**File**: `MacAmpApp/Models/AudioAnalyzer.swift`

(Same implementation as original plan - Accelerate FFT)

##### 9.2 Wire to MilkdropWindowView
```swift
struct MilkdropWindowView: View {
    @State private var fftData: [Float] = []
    
    var body: some View {
        ButterchurnWebView(fftData: $fftData)
            .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                fftData = audioPlayer.currentFFTData
            }
    }
}
```

##### Day 9 Deliverables
- ✅ FFT audio analysis working
- ✅ Audio data flows to Butterchurn
- ✅ Visualization syncs to audio playback
- ✅ 60fps rendering

#### Day 10: Milkdrop Polish & Testing

**Goal**: Complete Milkdrop window and test both windows

##### 10.1 Preset Selection
- Menu for preset selection
- Ctrl+[ / Ctrl+] keyboard shortcuts
- Auto-cycle every 30s

##### 10.2 Skin Integration
- Apply skin colors to Butterchurn canvas
- Border colors from SkinManager

##### 10.3 Comprehensive Testing
**Both Windows**:
- [ ] Video window plays MP4/MOV
- [ ] Milkdrop window shows visualization
- [ ] Both windows can be open simultaneously
- [ ] Video playback + audio visualization at same time
- [ ] State persists across restarts
- [ ] Ctrl+V toggles video window
- [ ] Ctrl+Shift+M toggles milkdrop window
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
│   ├── AudioAnalyzer.swift              [NEW - FFT analysis]
│   ├── AudioPlayer.swift                 [MODIFIED - video support]
│   ├── AppSettings.swift                 [MODIFIED - 2 window states]
│   └── SkinManager.swift                 [MODIFIED - VIDEO.bmp parsing]
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
- ✅ Ctrl+Shift+M toggles milkdrop window
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
| VIDEO.bmp parsing complexity | Fallback to classic chrome | ✅ Designed |
| Sprite layout varies by skin | Use standard dimensions + detection | ✅ Designed |
| Both windows open = resource usage | Profile CPU/GPU, optimize if needed | ⏳ Day 10 |
| Video + audio sync issues | Proper mode switching | ✅ Designed |
| WKWebView overhead | Throttle FFT updates, cap payloads | ✅ Designed |
| Memory leaks (2 windows) | Proper cleanup, test 1hr+ | ⏳ Day 10 |

---

## Timeline Summary

| Days | Phase | Deliverables |
|------|-------|--------------|
| **1-2** | Foundation | AppSettings, shortcuts, window stubs |
| **3** | VIDEO.bmp | Sprite parsing, SkinManager extension |
| **4** | Video Chrome | Skinnable window frame, controls |
| **5** | AVPlayer | Video playback integration |
| **6** | Video Polish | Playlist, persistence, V button |
| **7** | Milkdrop Foundation | Window structure, placeholder |
| **8** | Butterchurn | HTML bundle, WKWebView |
| **9** | FFT Bridge | Audio analysis, real-time viz |
| **10** | Final Polish | Presets, testing, docs |

**Total**: 10 working days  
**Milestone**: Day 6 (Video window complete)  
**Completion**: Day 10 (Both windows complete)

---

**Plan Approved**: 2025-11-08 (Two-Window Architecture)  
**Implementation Start**: Upon final approval  
**Target Completion**: Day 10  
**Next Review**: End of Day 6 (Video window milestone)
