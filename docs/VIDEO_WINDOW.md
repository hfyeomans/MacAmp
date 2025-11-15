# MacAmp Video Window Documentation

**Version:** 1.0.0
**Last Updated:** November 2025
**Status:** Production Ready (TASK 2 Days 1-6)
**Author:** MacAmp Development Team

---

## Table of Contents

1. [Introduction](#introduction)
2. [Window Specifications](#window-specifications)
3. [Architecture Overview](#architecture-overview)
4. [Chrome Components](#chrome-components)
5. [Video Playback System](#video-playback-system)
6. [Window Focus Integration](#window-focus-integration)
7. [Window Resizing (1x/2x)](#window-resizing-1x2x)
8. [Persistence & Window Docking](#persistence--window-docking)
9. [Fallback Chrome System](#fallback-chrome-system)
10. [Implementation Patterns](#implementation-patterns)
11. [Testing Guidelines](#testing-guidelines)
12. [Future Enhancements](#future-enhancements)
13. [Appendix: Sprite Definitions](#appendix-sprite-definitions)

---

## Introduction

The Video Window is a core component of MacAmp's media playback system, providing native video playback with authentic Winamp skinning. Implemented during TASK 2 (Days 1-6), it establishes MacAmp as a complete multimedia player matching Winamp's capabilities.

### Purpose

- **Video Playback:** Native macOS video rendering via AVPlayer
- **Skinned Chrome:** Pixel-perfect VIDEO.bmp sprite rendering
- **Seamless Integration:** Works with MacAmp's 5-window system
- **Format Support:** MP4, MOV, M4V, and other QuickTime-compatible formats

### Activation Methods

1. **V Button:** Click the "V" button on the main window (toggles visibility)
2. **Keyboard:** Press `Ctrl+V` to toggle window visibility
3. **Menu:** Windows → Show/Hide Video Window
4. **Automatic:** Opens when playing video files

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

1. **Mechanism Layer:** AVPlayer, AVPlayerView (AVKit framework)
2. **Bridge Layer:** AVPlayerViewRepresentable, AudioPlayer
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
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
```

### Format Support

**Supported Video Formats:**
- MP4 (H.264, H.265/HEVC)
- MOV (QuickTime)
- M4V (iTunes Video)
- AVI (limited codecs)
- Any format supported by AVFoundation

**Audio Track Handling:**
- Embedded audio plays through standard audio pipeline
- Volume control synchronized with main window
- EQ not available for video playback (AVPlayer limitation)

### Media Type Switching

```swift
// AudioPlayer.swift
enum MediaType {
    case audio
    case video
    case internetRadio
}

// Automatic detection on file load
private func detectMediaType(for url: URL) -> MediaType {
    let videoExtensions = ["mp4", "mov", "m4v", "avi"]
    if videoExtensions.contains(url.pathExtension.lowercased()) {
        return .video
    }
    return .audio
}

// Window visibility management
if audioPlayer.currentMediaType == .video {
    settings.showVideoWindow = true  // Auto-show for video
}
```

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

## Window Resizing (1x/2x)

### Size Modes

```swift
// AppSettings.swift
enum VideoWindowSizeMode: String, Codable {
    case oneX = "1x"  // 275×232 (native)
    case twoX = "2x"  // 550×464 (doubled)
}
```

### Keyboard Shortcuts

```swift
// AppCommands.swift
Button("Video Window 1x") {
    settings.videoWindowSizeMode = .oneX
}
.keyboardShortcut("1", modifiers: [.control])

Button("Video Window 2x") {
    settings.videoWindowSizeMode = .twoX
}
.keyboardShortcut("2", modifiers: [.control])
```

### Resize Implementation

```swift
// WindowCoordinator.swift
private func resizeVideoWindow(mode: VideoWindowSizeMode) {
    guard let video = videoWindow else { return }

    let baseSize = CGSize(width: 275, height: 232)
    let newSize: CGSize

    switch mode {
    case .oneX:
        newSize = baseSize
    case .twoX:
        newSize = CGSize(
            width: baseSize.width * 2,
            height: baseSize.height * 2
        )
    }

    // Resize window maintaining top-left position
    var frame = video.frame
    frame.size = newSize
    video.setFrame(frame, display: true, animate: true)
}
```

### Current Limitations

**TODO (Future Enhancement):**
- Chrome sprites don't scale in 2x mode (remain 1x)
- Need sprite scaling system similar to main window
- Buttons remain at 1x size/position in 2x mode

**Workaround:**
- Content area (video) scales properly
- Chrome remains functional but visually 1x

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
// Example test structure
func testVideoWindowCreation() {
    let coordinator = WindowCoordinator(...)

    // Show video window
    coordinator.settings.showVideoWindow = true

    // Verify window exists
    XCTAssertNotNil(coordinator.videoWindow)
    XCTAssertTrue(coordinator.videoWindow!.isVisible)
}

func testVideoSizeMode() {
    let settings = AppSettings()

    // Test persistence
    settings.videoWindowSizeMode = .twoX
    XCTAssertEqual(
        UserDefaults.standard.string(forKey: "videoWindowSizeMode"),
        "2x"
    )
}
```

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

---

## Future Enhancements

### Planned Features

**Chrome Scaling (Priority: High)**
- Scale VIDEO.bmp sprites in 2x mode
- Implement sprite scaling pipeline
- Match main window scaling behavior

**Interactive Buttons (Priority: Medium)**
- Wire up fullscreen button to AVPlayerView
- Implement 1x/2x buttons in chrome
- Add context menu for video options

**Advanced Playback (Priority: Low)**
- Subtitle support (.srt, .vtt)
- Audio track selection
- Playback speed controls
- Frame-by-frame stepping

### Technical Debt

**Current Issues:**
- Chrome remains 1x in 2x mode
- Buttons are visual-only (not interactive)
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
- ✅ Pixel-perfect VIDEO.bmp skinning
- ✅ Native video format support
- ✅ Focus-aware chrome states
- ✅ Magnetic window docking
- ✅ Fallback for missing sprites
- ✅ 1x/2x size modes (partial)

Future work focuses on completing the 2x chrome scaling, implementing interactive buttons, and adding advanced playback features. The architecture is designed for extensibility while maintaining the authentic Winamp experience that defines MacAmp.

---

**Document Version History:**
- v1.0.0 (2025-11-14): Initial comprehensive documentation
- Based on TASK 2 Days 1-6 implementation
- Incorporates fixes from video-window-focus and video-window-1x-2x tasks