# Implementation Plan: MacAmp V Button (Video/Visualization)

**Task ID**: milk-drop-video-support
**Strategy**: Hybrid (AVPlayerView + Butterchurn/WKWebView)
**Architecture**: Single-Window Container (Option A)
**Timeline**: 6 days
**Approved**: 2025-11-08

---

## Overview

Implement the V button in MacAmp's clutter bar to provide:
1. **Video Playback**: Native AVPlayerView for video files (MP4, MOV, M4V)
2. **Audio Visualization**: Butterchurn (Milkdrop) via WKWebView for audio files
3. **Smart Detection**: Auto-switch between video/visualization based on file type

**Key Constraint**: Keep visualization within existing `WinampMainWindow` for v1. Can extract to independent window later when magnetic-docking lands.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ WinampMainWindow (Existing Single NSWindow)            │
├─────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌──────┐ ┌──────────┐ ┌──────────────────┐ │
│ │  Main   │ │  EQ  │ │ Playlist │ │ Visualization    │ │
│ │ Window  │ │      │ │          │ │ (NEW - V Button) │ │
│ └─────────┘ └──────┘ └──────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
         ┌────▼─────┐            ┌─────▼──────┐
         │  VIDEO   │            │   AUDIO    │
         │ .mp4/.mov│            │ .mp3/.flac │
         └────┬─────┘            └─────┬──────┘
              │                        │
    ┌─────────▼──────────┐   ┌────────▼──────────────┐
    │  AVPlayerView      │   │  WKWebView            │
    │  (NSViewRep)       │   │  + Butterchurn        │
    │  - Native playback │   │  - WebGL visualization│
    │  - HW accelerated  │   │  - 5-8 presets        │
    └────────────────────┘   │  - Auto-cycle 30s     │
                             └───────┬───────────────┘
                                     │
                             ┌───────▼────────────┐
                             │ AVAudioEngine      │
                             │ + Accelerate FFT   │
                             │ → JS Bridge        │
                             └────────────────────┘
```

---

## Phase Breakdown (6 Days)

### Day 1: State + Plumbing (Foundation)

**Goal**: Set up state management, keyboard shortcuts, and placeholder UI

#### 1.1 Extend AppSettings
**File**: `MacAmpApp/Models/AppSettings.swift`

Add properties:
```swift
@Observable @MainActor
final class AppSettings {
    // V Button state
    var showVisualizerPanel: Bool = false {
        didSet { UserDefaults.standard.set(showVisualizerPanel, forKey: "showVisualizerPanel") }
    }
    
    var visualizerMode: VisualizerMode = .butterchurn {
        didSet { UserDefaults.standard.set(visualizerMode.rawValue, forKey: "visualizerMode") }
    }
    
    var lastUsedPresetIndex: Int = 0 {
        didSet { UserDefaults.standard.set(lastUsedPresetIndex, forKey: "lastUsedPresetIndex") }
    }
    
    var visualizerWindowFrame: CGRect? {
        didSet {
            if let frame = visualizerWindowFrame {
                UserDefaults.standard.set(NSStringFromRect(frame), forKey: "visualizerWindowFrame")
            }
        }
    }
}

enum VisualizerMode: String, Codable {
    case butterchurn  // Audio visualization
    case video        // Video playback
    case none         // Hidden
}
```

**Pattern Reference**: Mirrors `isDoubleSizeMode`, `timeDisplayMode` (lines 160-224)

#### 1.2 Add AppCommands
**File**: `MacAmpApp/AppCommands.swift`

Add command:
```swift
CommandGroup(after: .windowArrangement) {
    Button("Toggle Visualization") {
        appSettings.showVisualizerPanel.toggle()
    }
    .keyboardShortcut("v", modifiers: [.control])
}
```

**Pattern Reference**: Matches Ctrl+D, Ctrl+O, Ctrl+I shortcuts (lines 32-56)

#### 1.3 Stub Placeholder View
**File**: `MacAmpApp/Views/WinampMainWindow.swift`

Add to body:
```swift
if appSettings.showVisualizerPanel {
    VisualizationContainerView()
        .environment(appSettings)
        .environment(skinManager)
        .environment(audioPlayer)
}
```

**Create**: `MacAmpApp/Views/Components/VisualizationContainerView.swift`
```swift
import SwiftUI

struct VisualizationContainerView: View {
    @Environment(AppSettings.self) private var appSettings
    
    var body: some View {
        Text("Visualization Placeholder")
            .frame(width: 275, height: 116) // Winamp viz size
            .background(.black)
    }
}
```

#### 1.4 Deliverables (Day 1)
- ✅ AppSettings extended with V button state
- ✅ Ctrl+V keyboard shortcut working
- ✅ Placeholder view toggles on/off
- ✅ State persists across app restarts

---

### Day 2: Video Path (AVPlayerView Integration)

**Goal**: Implement native video playback for MP4/MOV files

#### 2.1 Create AVPlayerView Wrapper
**File**: `MacAmpApp/Views/Components/AVPlayerViewRepresentable.swift`

```swift
import SwiftUI
import AVKit

struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none  // Winamp-style, no native controls
        view.videoGravity = .resizeAspect
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
```

#### 2.2 Add AudioPlayer Video Support
**File**: `MacAmpApp/Models/AudioPlayer.swift`

Extend existing `AudioPlayer`:
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
            loadAudioFile(url: url)  // Existing method
        case .video:
            loadVideoFile(url: url)
        }
    }
    
    private func loadVideoFile(url: URL) {
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.play()
    }
    
    private func detectMediaType(url: URL) -> MediaType {
        let videoExtensions = ["mp4", "mov", "m4v", "avi"]
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) ? .video : .audio
    }
}
```

#### 2.3 Update VisualizationContainerView
**File**: `MacAmpApp/Views/Components/VisualizationContainerView.swift`

```swift
struct VisualizationContainerView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(AudioPlayer.self) private var audioPlayer
    
    var body: some View {
        Group {
            switch audioPlayer.currentMediaType {
            case .video:
                if let player = audioPlayer.videoPlayer {
                    AVPlayerViewRepresentable(player: player)
                }
            case .audio:
                Text("Audio Visualization (Day 3-4)")
                    .foregroundColor(.green)
            }
        }
        .frame(width: 275, height: 116)
        .background(.black)
    }
}
```

#### 2.4 Update Playlist Integration
**Files**: 
- `MacAmpApp/Views/PlaylistView.swift`
- Wherever file loading happens

Ensure video files are:
1. Added to playlist with 🎬 icon
2. Trigger `audioPlayer.loadMedia()` on double-click
3. Display video metadata (duration, resolution)

#### 2.5 Deliverables (Day 2)
- ✅ AVPlayerView renders video files
- ✅ File type detection (video vs audio)
- ✅ Video files show in playlist
- ✅ Double-click plays video in V window
- ✅ Eject button supports video files

---

### Days 3-4: Butterchurn Host (Audio Visualization)

**Goal**: Integrate Butterchurn visualization via WKWebView

#### 3.1 Create Butterchurn HTML Bundle
**Directory**: `MacAmpApp/Resources/Butterchurn/`

**Files to create**:
- `index.html` - Main visualization page
- `butterchurn.min.js` - Core library (from NPM)
- `butterchurn-presets.min.js` - Preset library
- `bridge.js` - Swift ↔ JavaScript communication

**index.html**:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body, html { 
            margin: 0; 
            padding: 0; 
            overflow: hidden;
            background: #000;
        }
        canvas { 
            width: 100%; 
            height: 100%; 
            display: block;
        }
    </style>
</head>
<body>
    <canvas id="canvas"></canvas>
    <script src="butterchurn.min.js"></script>
    <script src="butterchurn-presets.min.js"></script>
    <script src="bridge.js"></script>
</body>
</html>
```

**bridge.js**:
```javascript
let visualizer;
let audioContext;
let presets = [];
let currentPresetIndex = 0;

// Initialize Butterchurn
function initButterchurn() {
    const canvas = document.getElementById('canvas');
    audioContext = new AudioContext();
    
    visualizer = butterchurn.createVisualizer(audioContext, canvas, {
        width: 275,
        height: 116
    });
    
    // Load curated presets (5-8)
    presets = [
        butterchurnPresets.getPresets()['Geiss - Spiral Artifact'],
        butterchurnPresets.getPresets()['martin - mandelbox explorer'],
        // ... 3-6 more presets
    ];
    
    loadPreset(0);
    startRenderLoop();
}

// Load preset by index
function loadPreset(index) {
    currentPresetIndex = index;
    visualizer.loadPreset(presets[index], 2.7);  // 2.7s transition
}

// Update with FFT data from Swift
function updateAudioData(fftData) {
    if (visualizer && fftData) {
        visualizer.render();
    }
}

// Auto-cycle presets every 30s
setInterval(() => {
    currentPresetIndex = (currentPresetIndex + 1) % presets.length;
    loadPreset(currentPresetIndex);
}, 30000);

// Initialize on load
window.addEventListener('load', initButterchurn);

// Expose to Swift
window.webkit.messageHandlers.ready.postMessage('initialized');
```

#### 3.2 Create WKWebView Wrapper
**File**: `MacAmpApp/Views/Components/ButterchurnWebView.swift`

```swift
import SwiftUI
import WebKit

struct ButterchurnWebView: NSViewRepresentable {
    @Environment(AppSettings.self) private var appSettings
    @Binding var fftData: [Float]
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "ready")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")  // Transparent
        
        // Load local HTML
        if let url = Bundle.main.url(forResource: "index", 
                                      withExtension: "html", 
                                      subdirectory: "Butterchurn") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Send FFT data to JavaScript
        if !fftData.isEmpty {
            let dataString = fftData.map { String($0) }.joined(separator: ",")
            webView.evaluateJavaScript("updateAudioData([\(dataString)])")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentCall(_ userContentController: WKUserContentController, 
                             didReceive message: WKScriptMessage) {
            if message.name == "ready" {
                print("Butterchurn initialized")
            }
        }
    }
}
```

#### 3.3 Implement FFT Audio Bridge
**File**: `MacAmpApp/Models/AudioAnalyzer.swift` (NEW)

```swift
import AVFoundation
import Accelerate

@Observable @MainActor
final class AudioAnalyzer {
    private var engine: AVAudioEngine
    private var fftSetup: vDSP_DFT_Setup?
    private(set) var fftData: [Float] = []
    
    private let bufferSize: Int = 1024
    private let fftSize: Int = 512
    
    init(engine: AVAudioEngine) {
        self.engine = engine
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            .FORWARD
        )
        
        installTap()
    }
    
    private func installTap() {
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        
        mainMixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { [weak self] buffer, _ in
            self?.processPCMBuffer(buffer)
        }
    }
    
    private func processPCMBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Perform FFT using Accelerate
        var realPart = [Float](repeating: 0, count: fftSize)
        var imagPart = [Float](repeating: 0, count: fftSize)
        
        // Copy samples
        for i in 0..<min(frameLength, fftSize) {
            realPart[i] = channelData[i]
        }
        
        // Execute FFT
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_DFT_Execute(fftSetup!, realPtr.baseAddress!, imagPtr.baseAddress!, splitComplex.realp, splitComplex.imagp)
            }
        }
        
        // Compute magnitudes (downsample to 64-128 bins)
        let outputSize = 64
        var magnitudes = [Float](repeating: 0, count: outputSize)
        
        for i in 0..<outputSize {
            let real = realPart[i]
            let imag = imagPart[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // Update on main thread
        Task { @MainActor in
            self.fftData = magnitudes
        }
    }
    
    deinit {
        engine.mainMixerNode.removeTap(onBus: 0)
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
}
```

#### 3.4 Wire AudioAnalyzer to AudioPlayer
**File**: `MacAmpApp/Models/AudioPlayer.swift`

```swift
@Observable @MainActor
final class AudioPlayer {
    // Existing...
    private var audioAnalyzer: AudioAnalyzer?
    
    init() {
        // Existing init...
        audioAnalyzer = AudioAnalyzer(engine: audioEngine)
    }
    
    var currentFFTData: [Float] {
        audioAnalyzer?.fftData ?? []
    }
}
```

#### 3.5 Update VisualizationContainerView
**File**: `MacAmpApp/Views/Components/VisualizationContainerView.swift`

```swift
struct VisualizationContainerView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var fftData: [Float] = []
    
    var body: some View {
        Group {
            switch audioPlayer.currentMediaType {
            case .video:
                if let player = audioPlayer.videoPlayer {
                    AVPlayerViewRepresentable(player: player)
                }
            case .audio:
                ButterchurnWebView(fftData: $fftData)
                    .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
                        fftData = audioPlayer.currentFFTData
                    }
            }
        }
        .frame(width: 275, height: 116)
        .background(.black)
    }
}
```

#### 3.6 Deliverables (Days 3-4)
- ✅ Butterchurn HTML bundle created
- ✅ WKWebView hosting visualization
- ✅ FFT audio analysis working (Accelerate)
- ✅ Audio data flowing to JavaScript
- ✅ 5-8 curated presets loaded
- ✅ Auto-cycle every 30 seconds
- ✅ Real-time visualization synced to audio

---

### Day 5: Skin Polish + Persistence

**Goal**: Theme visualization to match current skin, add preset selection UI

#### 5.1 Skin Integration
**File**: `MacAmpApp/Views/Components/ButterchurnWebView.swift`

Inject skin colors:
```swift
func makeNSView(context: Context) -> WKWebView {
    // ... existing setup ...
    
    // Inject skin colors
    let skinColors = context.environment.skinManager.currentSkin.colors
    let jsCode = """
    window.skinColors = {
        background: '\(skinColors.background.hex)',
        foreground: '\(skinColors.foreground.hex)',
        border: '\(skinColors.border.hex)'
    };
    """
    
    webView.evaluateJavaScript(jsCode)
    return webView
}
```

**Update bridge.js**:
```javascript
// Apply skin colors if available
if (window.skinColors) {
    document.body.style.backgroundColor = window.skinColors.background;
    canvas.style.borderColor = window.skinColors.border;
}
```

#### 5.2 Window Frame Persistence
**File**: `MacAmpApp/Views/Components/VisualizationContainerView.swift`

```swift
struct VisualizationContainerView: View {
    @Environment(AppSettings.self) private var appSettings
    
    var body: some View {
        // ... existing content ...
        .frame(
            width: appSettings.visualizerWindowFrame?.width ?? 275,
            height: appSettings.visualizerWindowFrame?.height ?? 116
        )
        .onAppear {
            // Restore saved frame
        }
        .onChange(of: /* frame */) {
            // Save frame to AppSettings
        }
    }
}
```

#### 5.3 Preset Selection UI
**File**: `MacAmpApp/Views/Components/PresetSelectorMenu.swift` (NEW)

```swift
import SwiftUI

struct PresetSelectorMenu: View {
    @Environment(AppSettings.self) private var appSettings
    let presetNames = [
        "Geiss - Spiral Artifact",
        "Martin - Mandelbox Explorer",
        // ... more presets
    ]
    
    var body: some View {
        Menu("Presets") {
            ForEach(presetNames.indices, id: \.self) { index in
                Button(presetNames[index]) {
                    appSettings.lastUsedPresetIndex = index
                    // Notify WebView to change preset
                }
            }
        }
    }
}
```

Add to V button context menu or Options menu.

#### 5.4 Keyboard Shortcuts
**File**: `MacAmpApp/AppCommands.swift`

Add:
```swift
// Cycle presets
Button("Next Preset") {
    // Cycle to next preset
}
.keyboardShortcut("]", modifiers: [.control])

Button("Previous Preset") {
    // Cycle to previous preset
}
.keyboardShortcut("[", modifiers: [.control])
```

#### 5.5 Deliverables (Day 5)
- ✅ Visualization themed to match current skin
- ✅ Window frame persists across restarts
- ✅ Preset selection menu working
- ✅ Keyboard shortcuts: Ctrl+[ / Ctrl+] for presets
- ✅ Optional chromeless toggle in settings

---

### Day 6: Verification + Documentation

**Goal**: Test thoroughly, document feature, polish edge cases

#### 6.1 Testing Checklist

**Video Playback**:
- [ ] MP4 files play correctly
- [ ] MOV files play correctly
- [ ] M4V files play correctly
- [ ] Video playback stops when switching tracks
- [ ] Video window respects skin theming
- [ ] Video scales correctly in double-size mode

**Audio Visualization**:
- [ ] FFT data updates in real-time
- [ ] Visualization syncs to audio playback
- [ ] Preset cycling works (30s auto)
- [ ] Manual preset selection works
- [ ] Visualization pauses when audio paused
- [ ] No memory leaks after 1 hour playback

**Integration**:
- [ ] Playlist shows video files with 🎬 icon
- [ ] Eject button accepts video files
- [ ] File drag-and-drop supports video
- [ ] State persists across app restarts
- [ ] Ctrl+V toggles visualization window
- [ ] Ctrl+[ / Ctrl+] cycle presets
- [ ] Works in normal and double-size modes

**Skins**:
- [ ] Visualization themed to active skin
- [ ] Theme updates when skin changes
- [ ] Chromeless mode works (if implemented)

**Performance**:
- [ ] No dropped frames in visualization
- [ ] No audio glitches during FFT processing
- [ ] CPU usage acceptable (<20% on modern Mac)
- [ ] GPU usage acceptable (WebGL optimized)

#### 6.2 Regression Tests
**File**: `MacAmpTests/VisualizationTests.swift` (NEW)

```swift
import XCTest
@testable import MacAmp

final class VisualizationTests: XCTestCase {
    func testMediaTypeDetection() {
        let mp4URL = URL(fileURLWithPath: "/test.mp4")
        let mp3URL = URL(fileURLWithPath: "/test.mp3")
        
        // Test file type detection logic
        XCTAssertEqual(detectMediaType(mp4URL), .video)
        XCTAssertEqual(detectMediaType(mp3URL), .audio)
    }
    
    func testFFTDataGeneration() {
        // Test AudioAnalyzer produces valid FFT data
    }
    
    func testPresetPersistence() {
        // Test lastUsedPresetIndex saves/loads correctly
    }
}
```

#### 6.3 Documentation
**File**: `docs/features/v-button-visualization.md` (NEW)

```markdown
# V Button: Video & Visualization

## Overview
The V button in MacAmp's clutter bar provides two modes:
1. **Video Playback** - For video files (MP4, MOV, M4V)
2. **Audio Visualization** - Milkdrop-style visualization for audio

## Usage

### Toggle Visualization Window
- **Click V button** - Shows/hides visualization
- **Keyboard**: Ctrl+V

### Preset Control
- **Auto-cycle**: Presets change every 30 seconds
- **Manual**: Use preset menu or Ctrl+[ / Ctrl+]

### Supported Formats
- **Video**: MP4, MOV, M4V (via AVFoundation)
- **Audio**: All existing formats (MP3, FLAC, WAV, etc.)

## Technical Details
- Video: Native AVPlayerView (hardware-accelerated)
- Visualization: Butterchurn (WebGL Milkdrop port)
- Audio Analysis: AVAudioEngine + Accelerate FFT

## Future Enhancements
- Independent window (post magnetic-docking)
- More video formats (FFmpeg integration)
- Metal-native visualization renderer
- Custom preset upload/sharing
```

#### 6.4 Update Main README
**File**: `README.md`

Add to features list:
```markdown
- ✅ V Button (Video & Visualization)
  - Native video playback (MP4, MOV)
  - Milkdrop-style audio visualization
  - Auto-cycling presets
  - Skin-aware theming
```

#### 6.5 Deliverables (Day 6)
- ✅ All tests passing
- ✅ Regression test suite created
- ✅ Feature documented in docs/
- ✅ README updated
- ✅ Known issues documented
- ✅ Performance profiled and optimized

---

## File Structure (New Files)

```
MacAmpApp/
├── Models/
│   ├── AudioAnalyzer.swift              [NEW - FFT analysis]
│   └── AudioPlayer.swift                 [MODIFIED - video support]
├── Views/
│   └── Components/
│       ├── VisualizationContainerView.swift  [NEW - main container]
│       ├── AVPlayerViewRepresentable.swift   [NEW - video player]
│       ├── ButterchurnWebView.swift          [NEW - visualization]
│       └── PresetSelectorMenu.swift          [NEW - preset UI]
├── Resources/
│   └── Butterchurn/                     [NEW - HTML bundle]
│       ├── index.html
│       ├── butterchurn.min.js
│       ├── butterchurn-presets.min.js
│       └── bridge.js
└── AppCommands.swift                     [MODIFIED - Ctrl+V shortcut]

MacAmpTests/
└── VisualizationTests.swift             [NEW - test suite]

docs/
└── features/
    └── v-button-visualization.md        [NEW - feature docs]
```

---

## Success Criteria

### MVP (v1.0)
✅ V button toggles visualization window  
✅ Video files (MP4, MOV) play natively  
✅ Audio files show Butterchurn visualization  
✅ 5-8 curated presets auto-cycle  
✅ Skin-aware theming  
✅ Keyboard shortcuts (Ctrl+V, Ctrl+[, Ctrl+])  
✅ State persists across restarts  
✅ No memory leaks or performance issues  

### Future Enhancements (Post-v1)
⏳ Independent window (requires magnetic-docking)  
⏳ FFmpeg integration (AVI, MKV, FLV)  
⏳ Full preset browser with favorites  
⏳ Metal-native visualization renderer  
⏳ Custom preset upload/sharing  

---

## Risk Mitigation

| Risk | Mitigation | Status |
|------|------------|--------|
| WKWebView feels "un-native" | Hide scrollbars, skin theming, local cache | ✅ Designed |
| FFT bridge performance | Cap payloads (256 floats), throttle updates | ✅ Designed |
| Video/audio sync issues | Proper mode switching, single audio source | ✅ Designed |
| Preset quality variance | Curate 5-8 high-quality presets manually | ⏳ To Do |
| Memory leaks in WebView | Proper cleanup, test 1hr+ playback | ⏳ Day 6 |

---

## Swift 6 Compliance

All code follows Swift 6 patterns:
- ✅ `@Observable @MainActor` for state
- ✅ `@Environment` injection  
- ✅ Strict concurrency (async/await)
- ✅ Lock-free audio threading  
- ✅ `didSet + UserDefaults` persistence

---

## Dependencies

### Swift Packages (None Required)
All functionality uses built-in frameworks:
- AVFoundation (video playback)
- AVKit (AVPlayerView)
- WebKit (WKWebView for Butterchurn)
- Accelerate (FFT computation)

### External Resources
- Butterchurn JS library (bundled in Resources/)
- Butterchurn presets (bundled in Resources/)

---

## Rollout Strategy

### Alpha (Internal Testing)
- Day 6: Internal testing with curated files
- Verify video/visualization on multiple Macs
- Test with various skins

### Beta (External Testing)
- Week 2: Release to beta testers
- Gather feedback on preset selection
- Monitor performance metrics

### Production (v1.0 Release)
- Week 3: Public release
- Document known limitations
- Plan v2.0 enhancements based on feedback

---

## Maintenance Plan

### Bug Fixes (Immediate)
- Video playback issues
- Visualization sync problems
- Memory leaks
- Skin theming bugs

### Enhancements (v2.0)
- Independent window support
- More video formats (FFmpeg)
- Preset browser UI
- Metal renderer

### Long-term (v3.0+)
- Custom preset creation
- Preset sharing platform
- Advanced visualization effects
- Multi-monitor support

---

**Plan Approved**: 2025-11-08  
**Implementation Start**: Upon user approval  
**Target Completion**: Day 6 (6-day cycle)  
**Next Review**: End of Day 3 (Butterchurn milestone)
