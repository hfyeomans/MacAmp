# Milkdrop Window Implementation Guide

**Document Version**: 1.0.0
**Last Updated**: 2025-11-14
**Implementation**: Days 7-8 of TASK 2 (milk-drop-video-support)
**Status**: Core window chrome complete, visualization deferred

---

## 1. Introduction

The Milkdrop window provides audio visualization capabilities in MacAmp, faithfully recreating the Winamp visualization window using GEN.bmp sprites. Originally designed for the legendary Milkdrop visualizer (psychedelic music visualization), this window serves as a container for future visualization implementations.

### 1.1 Purpose

- **Primary**: Display audio visualizations synchronized with music playback
- **Secondary**: Future integration point for Butterchurn.js, projectM, or native Metal visualizers
- **Current State**: Window chrome complete with placeholder content

### 1.2 User Interaction

- **Open/Close**: Ctrl+K keyboard shortcut (matches Winamp)
- **Focus**: Click to focus, shows selected chrome state
- **Position**: Persisted across sessions in UserDefaults
- **Docking**: Magnetic snapping to other MacAmp windows and screen edges

### 1.3 Implementation Timeline

- **Days 1-6**: Video window implementation (complete)
- **Day 7**: GEN sprite research and two-piece discovery
- **Day 8**: Milkdrop window chrome implementation
- **Future**: Visualization engine integration (deferred)

---

## 2. Window Specifications

### 2.1 Dimensions

```swift
// Fixed size (matches Video/Playlist windows)
static let windowSize = CGSize(width: 275, height: 232)

// Component dimensions
static let titlebarHeight: CGFloat = 20   // GEN titlebar sprites
static let bottomBarHeight: CGFloat = 14  // GEN bottom bar sprites
static let leftBorderWidth: CGFloat = 11  // GEN_MIDDLE_LEFT width
static let rightBorderWidth: CGFloat = 8  // GEN_MIDDLE_RIGHT width

// Content area (for visualization)
static let contentX: CGFloat = 11         // Left border width
static let contentY: CGFloat = 20         // Titlebar height
static let contentWidth: CGFloat = 256    // 275 - 11 - 8
static let contentHeight: CGFloat = 198   // 232 - 20 - 14
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

### 4.1 Titlebar Composition (6 Sections)

The titlebar uses a sophisticated 6-section layout with both decorative and functional elements:

```swift
// Section layout for 275px width (11 columns of 25px each)
Section 1: LEFT cap         (col 0)    - Close button
Section 2: LEFT_RIGHT_FILL  (cols 1-2) - Gold decorative
Section 3: LEFT_END         (col 3)    - Transition piece
Section 4: CENTER_FILL      (cols 4-6) - Grey text area
Section 5: RIGHT_END        (col 7)    - Transition piece
Section 6: LEFT_RIGHT_FILL  (cols 8-9) - Gold decorative
Section 7: RIGHT cap        (col 10)   - End piece
```

Implementation in `MilkdropWindowChromeView.swift`:

```swift
ZStack(alignment: .topLeading) {
    let suffix = isWindowActive ? "_SELECTED" : ""

    // Section 1: Left cap with close button
    SimpleSpriteImage("GEN_TOP_LEFT\(suffix)", width: 25, height: 20)
        .position(x: 12.5, y: 10)

    // Section 2: Left gold bar tiles
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

## 9. Butterchurn Deferral

### 9.1 Initial Attempt

Days 7-8 included an attempt to integrate Butterchurn.js for Milkdrop visualization:

```
Attempt: Embed Butterchurn in WKWebView
Result: External JavaScript files wouldn't load
Issue: WKWebView security restrictions on file:// URLs
```

### 9.2 Technical Blockers

From `BUTTERCHURN_BLOCKERS.md`:

**What Worked**:
- WKWebView lifecycle fixed
- HTML loads successfully
- Inline JavaScript executes
- JIT entitlements enabled

**What Failed**:
- External .js files don't load (`butterchurn.min.js`, `butterchurnPresets.min.js`)
- `<script src="...">` tags fail silently
- Files ARE in bundle but WKWebView won't load them

### 9.3 Alternative Approaches

**Option A: Inline All JavaScript**
- Embed 470KB of JavaScript directly in HTML
- Avoids external file loading
- Might work but inelegant

**Option B: Bundle Injection**
```swift
// Load JS as string from bundle
let jsContent = Bundle.main.url(forResource: "butterchurn.min",
                                withExtension: "js")
    .flatMap { try? String(contentsOf: $0) }

// Inject before loading HTML
webView.evaluateJavaScript(jsContent)
```

**Option C: Native Metal Renderer**
- Best performance
- Most work (4-8 weeks)
- Would need to port preset system

**Option D: Use projectM**
- Open-source C++ Milkdrop clone
- Can compile for macOS
- Bridge via Objective-C++

### 9.4 Decision

Visualization deferred to future session. Window chrome complete and ready for any visualization approach.

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

### 12.1 Visualization Implementation

**Priority Order**:
1. **Simple waveform/spectrum** - Quick win, native implementation
2. **Butterchurn.js** - If Bundle injection works (Option B)
3. **projectM** - Most compatible with existing presets
4. **Native Metal** - Best performance, most work

### 12.2 Dynamic Text Rendering

Implement GEN letter extraction for titlebar text:
- Pixel-scanning algorithm for letter boundaries
- Runtime coordinate map generation
- Support for "MILKDROP" and preset names
- Variable-width letter support

### 12.3 Window Resizing

Current: Fixed 275×232 size
Future: User-resizable with constraints
- Minimum: 275×116 (matches Main/EQ)
- Maximum: Screen size
- Maintain aspect ratio option
- Scale visualization accordingly

### 12.4 Preset Management

- Load .milk preset files
- Preset browser/selector
- Auto-cycle timer
- Transition effects between presets
- User preset creation

### 12.5 Audio Analysis Enhancement

Current: Basic FFT via AVAudioEngine tap
Future: Advanced analysis for visualization
- Multi-band frequency analysis
- Beat detection
- Peak/RMS tracking
- Configurable FFT size
- Windowing functions

---

## Code References

### Primary Implementation Files

```swift
// Window Controller
MacAmpApp/Windows/WinampMilkdropWindowController.swift

// Main View
MacAmpApp/Views/WinampMilkdropWindow.swift

// Chrome Implementation
MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift

// Sprite Definitions
MacAmpApp/Models/SkinSprites.swift (GEN section)

// Focus State
MacAmpApp/Models/WindowFocusState.swift

// Settings Persistence
MacAmpApp/Models/AppSettings.swift
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
2. **Two-piece sprite discovery** for BOTTOM_FILL components
3. **Six-section titlebar** composition for visual variety
4. **Focus state integration** with _SELECTED sprite switching
5. **NSWindowController pattern** with environment injection
6. **Deferred complexity** - window ready, visualization pending

The window chrome is complete and production-ready, providing a solid foundation for future visualization implementations. Whether using Butterchurn.js, projectM, or native Metal rendering, the 256×198px content area is ready to display stunning audio visualizations.

The implementation follows MacAmp's three-layer architecture, maintains Winamp compatibility, and integrates seamlessly with the existing window management system. While dynamic text rendering and visualization are deferred, the core window functionality matches the quality and attention to detail of the Main, Equalizer, Playlist, and Video windows.

---

**End of Document**