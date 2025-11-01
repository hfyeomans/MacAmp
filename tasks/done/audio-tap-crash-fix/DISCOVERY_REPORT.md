# MacAmp Double-Size Button Implementation - Discovery Report

**Date:** 2025-10-30
**Project:** MacAmp (Winamp Classic Recreation for macOS)
**Target:** Locate and document all components required for double-size button implementation

---

## EXECUTIVE SUMMARY

Successfully discovered all required components for implementing double-size button mode in MacAmp. The codebase follows a clean architecture with:

- **State Management:** @Observable SkinManager, AudioPlayer, DockingController
- **Sprite System:** SpriteResolver pattern for semantic-to-actual sprite mapping
- **Window Sizing:** Fixed sizes defined in WinampSizes constants
- **Button Infrastructure:** Existing button system using SimpleSpriteImage with semantic sprites
- **AppKit Bridge:** WindowAccessor for NSWindow access
- **Commands:** Keyboard shortcut infrastructure ready for new commands

All components are in place to implement a double-size feature. No scaffolding or stub code exists currently.

---

## 1. STATE MANAGEMENT

### Location: `MacAmpApp/ViewModels/SkinManager.swift` (Lines 102-621)

**Class:** `SkinManager`
- **Type:** `@Observable`, `@MainActor`
- **Status:** Active state management for skin loading and caching
- **Key Properties:**
  - `currentSkin: Skin?` - Currently loaded skin
  - `isLoading: Bool` - Skin loading state
  - `availableSkins: [SkinMetadata]` - Available skins list

**Usage in Views:**
```swift
@Environment(SkinManager.self) var skinManager
```

**Pattern:** Already uses modern Swift 6 @Observable pattern.

**Finding:** Ready to extend with additional state for double-size mode.

---

### Secondary State: `AudioPlayer.swift` (Lines 94-96)

**Class:** `AudioPlayer`
- **Type:** `@Observable`, `@MainActor`
- **Status:** Controls playback and provides audio properties
- **Key Properties:**
  - `isPlaying: Bool`
  - `currentTime: Double`
  - `volume: Double`

**Finding:** No existing double-size state here. Could add scale factor property.

---

### Tertiary State: `DockingController.swift` (Lines 31-118)

**Class:** `DockingController`
- **Type:** `@Observable`, `@MainActor`
- **Manages:** Window visibility and shade state
- **Key Properties:**
  - `panes: [DockPaneState]` - Window visibility state
  - Persists to UserDefaults via `persistKey`

**Finding:** Good pattern for persisting UI state. Could add double-size mode persistence here.

---

### Tertiary State: `AppSettings.swift`

**Class:** `AppSettings`
- **Type:** @Observable singleton
- **Status:** Stores user preferences
- **Key Properties:**
  - `selectedSkinIdentifier`
  - `materialIntegration`
  - `enableLiquidGlass`

**Finding:** Perfect location to add `isDoubleSizeMode: Bool` property with UserDefaults persistence.

---

## 2. SKINENGINE / SPRITE SYSTEM

### Main Component: `SkinManager.swift` - Sprite Loading (Lines 454-610)

**Method:** `applySkinPayload(_:sourceURL:)`

**Capabilities:**
- Extracts sprites from skin archives (BMP/PNG)
- Preprocesses background images
- Creates fallback sprites
- Handles sprite aliasing
- Supports extended sprites (NUMS_EX)

**Key Features:**
```swift
// Extracts BMP/PNG data from ZIP archives
guard let sheetImage = NSImage(data: data) else { ... }

// Crops individual sprites from sheets
if let croppedImage = sheetImage.cropped(to: rect) { ... }

// Preprocesses (e.g., masking static digits)
finalImage = preprocessMainBackground(croppedImage)
```

**Finding:** System is built to handle image manipulation. Scaling sprites would be straightforward.

---

### Sprite Resolution: `SpriteResolver.swift` (Lines 97-402)

**Struct:** `SpriteResolver`
- **Type:** `Sendable`
- **Purpose:** Maps semantic sprite requests to actual sprite names

**Example Usage:**
```swift
resolver.resolve(.digit(0))
// Returns: "DIGIT_0_EX" OR "DIGIT_0" (tries variants in priority)
```

**Methods:**
- `resolve(_: SemanticSprite) -> String?` - Get sprite name
- `image(for: SemanticSprite) -> NSImage?` - Get sprite image
- `dimensions(for: SemanticSprite) -> CGSize?` - Get sprite size

**Finding:** Perfect abstraction for handling double-size variants. Could add 2x sprites.

---

### Sprite Definitions: `SkinSprites.swift` (Lines 46-275+)

**Struct:** `SkinSprites`

**Contains all sprite definitions** for:
- MAIN.bmp
- CBUTTONS.bmp (transport controls)
- NUMBERS.bmp (digits)
- MONOSTER.bmp
- PLAYPAUS.bmp
- TITLEBAR.bmp
- POSBAR.bmp (position slider)
- VOLUME.bmp
- BALANCE.bmp
- SHUFREP.bmp (shuffle/repeat/EQ/playlist buttons)
- EQMAIN.bmp
- EQ_EX.bmp

**Example Entry:**
```swift
Sprite(name: "MAIN_PREVIOUS_BUTTON", x: 0, y: 0, width: 23, height: 18),
Sprite(name: "MAIN_PREVIOUS_BUTTON_ACTIVE", x: 0, y: 18, width: 23, height: 18),
```

**Finding:** All button definitions are here. For double-size, would double these coordinates and sizes (or create 2x variants).

---

### SimpleSpriteImage Component: `SimpleSpriteImage.swift` (Lines 27-82)

**Struct:** `SimpleSpriteImage: View`

**Initializers:**
```swift
// Semantic sprite (new architecture)
init(_ semantic: SemanticSprite, width: CGFloat? = nil, height: CGFloat? = nil)

// Legacy sprite name (backward compatible)
init(_ spriteKey: String, width: CGFloat? = nil, height: CGFloat? = nil)
```

**Rendering:**
```swift
Image(nsImage: image)
    .interpolation(.none)     // Pixel-perfect
    .antialiased(false)       // No smoothing
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: width, height: height)
    .clipped()
```

**Finding:** Ready to handle 2x-sized sprites. Frame sizes would just need to be doubled.

---

## 3. MAIN WINDOW VIEW

### Location: `WinampMainWindow.swift` (Lines 1-706)

**Struct:** `WinampMainWindow: View`

**Architecture:**
```
ZStack(alignment: .topLeading)
├── SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", 275x116)
├── SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED")
│   .gesture(WindowDragGesture())
├── buildFullWindow() OR buildShadeMode()
└── ... (all elements with absolute positioning)
```

**Layout System:**
- ZStack with `.topLeading` alignment
- Absolute positioning using `.at(CGPoint)` extension
- Fixed window size: 275×116

**Key Coordinate System (Lines 34-74):**
```swift
struct Coords {
    // Transport buttons (all at y: 88)
    static let prevButton = CGPoint(x: 16, y: 88)
    static let playButton = CGPoint(x: 39, y: 88)
    // ... etc
}
```

**Building Blocks:**
- `buildFullWindow()` - Full view mode
- `buildShadeMode()` - Collapsed titlebar only
- `buildTitlebarButtons()` - Min/Shade/Close buttons
- `buildTransportButtons()` - Prev/Play/Pause/Stop/Next/Eject
- `buildShuffleRepeatButtons()` - Shuffle/Repeat toggles
- `buildWindowToggleButtons()` - EQ/Playlist buttons
- `buildVolumeSlider()` - Volume control
- `buildBalanceSlider()` - Balance control
- `buildPositionSlider()` - Track position
- `buildTimeDisplay()` - Time digits
- `buildSpectrumAnalyzer()` - Visualizer

**Finding:** Clear organization with builder methods. Double-size would need:
1. Multiply all Coords values by 2
2. Multiply frame dimensions by 2
3. Update window size constant

---

## 4. BUTTON DEFINITIONS

### Transport Buttons
**Location:** `WinampMainWindow.swift` Lines 335-381

**Buttons:**
- Previous (23×18) at (16, 88)
- Play (23×18) at (39, 88)
- Pause (23×18) at (62, 88)
- Stop (23×18) at (85, 88)
- Next (23×18) at (108, 88) [actually 22×18]
- Eject (22×16) at (136, 89)

**Double-Size:** 46×36, positions x2

### Window Toggle Buttons
**Location:** `WinampMainWindow.swift` Lines 460-481

**Buttons:**
- EQ (23×12) at (219, 58)
- Playlist (23×12) at (242, 58)

**Double-Size:** 46×24, positions x2

### Shuffle/Repeat Buttons
**Location:** `WinampMainWindow.swift` Lines 383-406

**Buttons:**
- Shuffle (47×15) at (164, 89)
- Repeat (28×15) at (211, 89)

**Double-Size:** 94×30, 56×30, positions x2

### Titlebar Buttons
**Location:** `WinampMainWindow.swift` Lines 223-253

**Buttons:**
- Minimize (9×9) at (244, 3)
- Shade (9×9) at (254, 3)
- Close (9×9) at (264, 3)

**Double-Size:** 18×18, positions x2

---

## 5. WINDOW SIZING

### Location: `SimpleSpriteImage.swift` Lines 98-105

**Constants:**
```swift
struct WinampSizes {
    static let main = CGSize(width: 275, height: 116)
    static let mainShade = CGSize(width: 275, height: 14)
    static let equalizer = CGSize(width: 275, height: 116)
    static let equalizerShade = CGSize(width: 275, height: 14)
    static let playlistBase = CGSize(width: 275, height: 232)
    static let playlistShade = CGSize(width: 275, height: 14)
}
```

**For Double-Size:**
```swift
static let mainDouble = CGSize(width: 550, height: 232)
static let mainDoubleShade = CGSize(width: 550, height: 28)
// ... etc
```

**Finding:** Simple constants to extend.

---

### Secondary Size Constants: `WindowSpec.swift` (Lines 4-58)

**Struct:** `WindowSpec`

**Contains:**
- Standard window size specs
- Playlist sizing rules
- Snap distance (15px)

**Finding:** Not directly used for main window, but good pattern for consistency.

---

## 6. KEYBOARD SHORTCUT INFRASTRUCTURE

### Location: `AppCommands.swift` (Lines 1-62)

**Struct:** `AppCommands: Commands`

**Existing Shortcuts:**
- ⌘⇧1: Show/Hide Main
- ⌘⇧2: Show/Hide Playlist
- ⌘⇧3: Show/Hide Equalizer
- ⌘⌥1: Shade/Unshade Main
- ⌘⌥2: Shade/Unshade Playlist
- ⌘⌥3: Shade/Unshade Equalizer
- ⌘O: Open Files
- ⌘,: Preferences

**Pattern:**
```swift
Button("Shade/Unshade Main") { dockingController.toggleShade(.main) }
    .keyboardShortcut("1", modifiers: [.command, .option])
```

**For Double-Size:** Could use something like:
- ⌘⌃1: Toggle Double-Size Mode

**Finding:** Infrastructure is ready. Just need to add new command and handler.

---

## 7. WINDOW ACCESSOR PATTERN

### Location: `WindowAccessor.swift` (Lines 1-23)

**Struct:** `WindowAccessor: NSViewRepresentable`

**Purpose:** Capture NSWindow reference in SwiftUI

**Code:**
```swift
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            onWindow(window)
        }
    }
}
```

**Usage in UnifiedDockView:**
```swift
.background(
    WindowAccessor { window in
        configureWindow(window)
    }
)
```

**Finding:** Perfect pattern for accessing NSWindow to adjust window size when toggling double-size.

---

## 8. APPKIT BRIDGE (Window Configuration)

### Location: `UnifiedDockView.swift` Lines 77-105

**Method:** `configureWindow(_:)`

**Current Configuration:**
```swift
window.styleMask.insert(.borderless)
window.styleMask.remove(.titled)
window.isMovableByWindowBackground = false
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.level = .normal
```

**For Double-Size:** Would call:
```swift
window.setContentSize(NSSize(width: 550, height: 232))
```

**Finding:** Window configuration point is ready to handle size changes.

---

## 9. ASSET FILES

### Bundled Skin Location
`webamp_clone/packages/webamp/assets/skins/base-2.91/`

**Files:**
- CBUTTONS.BMP (transport buttons)
- MAIN.BMP (main window background)
- MONOSTER.BMP (mono/stereo indicators)
- PLAYPAUS.BMP (play/pause indicators)
- TITLEBAR.BMP (title bar and window buttons)
- POSBAR.BMP (position slider)
- VOLUME.BMP (volume slider)
- BALANCE.BMP (balance slider)
- SHUFREP.BMP (shuffle/repeat/EQ/playlist buttons)
- EQMAIN.BMP (equalizer background)
- NUMBERS.BMP (time digits)
- ... and more

**Finding:** All sprite sheets are available. For double-size, would need 2x versions of these (or runtime scaling).

---

## 10. EXISTING SCALE IMPLEMENTATIONS

### Shade Mode Scaling
**Location:** `WinampMainWindow.swift` Lines 179-187

**Pattern:**
```swift
SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
    .scaleEffect(0.6) // Scale down for shade mode
```

**Finding:** Already using `.scaleEffect()` for scaling. Same pattern could work for double-size (but using 2.0 instead of 0.6).

---

### Window Scaling
**Location:** `UnifiedDockView.swift` Line 47

**Pattern:**
```swift
.scaleEffect(dockGlow)
```

**Finding:** Entire dock view can be scaled. Could be alternative approach.

---

## 11. DOCKING CONTROLLER STATE

### Location: `DockingController.swift` (Lines 31-118)

**Key Aspect:** Persists pane visibility state via UserDefaults

**Pattern:**
```swift
@Observable @MainActor final class DockingController {
    var panes: [DockPaneState] {
        didSet {
            persistTask?.cancel()
            persistTask = Task { @MainActor [weak self, panes] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self?.persist(panes: panes)
            }
        }
    }
}
```

**Finding:** Good pattern for double-size mode persistence. Could add similar state for scale mode.

---

## 12. EXISTING SCALE REFERENCES

**Found in codebase:**
1. `WindowSpec.swift` - "double width" comment for playlist max size
2. `WinampMainWindow.swift` - Multiple `.scaleEffect()` calls
3. `UnifiedDockView.swift` - Glow animation scale effect

**No existing double-size mode code found** - opportunity to implement cleanly from scratch.

---

## 13. APPLE DOCUMENTATION AVAILABLE

**Location:** `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/`

**Available for reference:**
- SwiftUI documentation
- Swift Concurrency updates
- Modern toolbar features
- AppKit implementation patterns

---

## 14. BUILD & TESTING INFRASTRUCTURE

### Build Command
```bash
xcodebuild -scheme MacAmpApp -configuration Debug -enableThreadSanitizer YES clean build
```

### Test Files Available
- Mono test: `mono_test.wav`
- Standard audio: `llama.mp3`

### Recent Task Example
`tasks/audio-tap-crash-fix/` - Shows pattern for:
- Complex feature implementation
- Comprehensive documentation
- Testing verification
- Thread safety validation

---

## IMPLEMENTATION CHECKLIST

### Components to Modify

- [ ] **AppSettings.swift**
  - Add `isDoubleSizeMode: Bool` property
  - Add persistence logic

- [ ] **WinampMainWindow.swift**
  - Add double-size constant values
  - Create double-size coordinate variants
  - Adapt builder methods to use double-size coords when active

- [ ] **SimpleSpriteImage.swift**
  - Extend WinampSizes struct with double-size constants

- [ ] **SpriteResolver.swift** (Optional)
  - Support 2x sprite variants if creating separate sprite sheets

- [ ] **DockingController.swift** (Optional)
  - Add scale mode to persisted state

- [ ] **AppCommands.swift**
  - Add keyboard shortcut for double-size toggle (e.g., ⌘⌃1)

- [ ] **UnifiedDockView.swift**
  - React to double-size mode changes
  - Update window size via WindowAccessor

### Components Ready to Use (No Changes Needed)

- ✅ SkinManager - Already handles sprite scaling
- ✅ WindowAccessor - Ready to resize window
- ✅ SimpleSpriteImage - Ready to display 2x sprites
- ✅ SpriteResolver - Ready for 2x sprite variants
- ✅ Button infrastructure - All buttons present
- ✅ Coordinate system - Clear enough to double values
- ✅ State management - All @Observable ready

---

## KEY FINDINGS SUMMARY

1. **Architecture is Clean:** Clear separation between state, sprites, and views
2. **Sprite System is Flexible:** SpriteResolver pattern makes it easy to handle variants
3. **State Management is Modern:** @Observable pattern throughout
4. **Window Sizing:** Handled via constants and can be toggled via NSWindow.setContentSize()
5. **Button System:** All buttons properly defined with coordinates and sizes
6. **Keyboard Shortcuts:** Infrastructure ready for new command
7. **No Scaffolding:** No stub code or deprecation warnings found
8. **Thread Safety:** Recent work shows Swift 6 concurrency is priority
9. **Persistence:** UserDefaults pattern established for UI state
10. **Testing Pattern:** Task documentation shows expected structure

---

## FILE PATHS REFERENCE

### State Management Files
- `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/SkinManager.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/ViewModels/DockingController.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Audio/AudioPlayer.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/AppSettings.swift`

### Sprite System Files
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SpriteResolver.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SkinSprites.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SimpleSpriteImage.swift`

### Main Window Files
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/UnifiedDockView.swift`

### Infrastructure Files
- `/Users/hank/dev/src/MacAmp/MacAmpApp/AppCommands.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Utilities/WindowAccessor.swift`
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/WindowSpec.swift`

### Asset Files
- `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/assets/skins/base-2.91/CBUTTONS.BMP`
- `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/assets/skins/base-2.91/MAIN.BMP`
- (and others listed in section 9)

---

## CONCLUSION

The MacAmp codebase is well-structured and ready for double-size button implementation. All required components are in place with no critical gaps. The implementation would involve:

1. Adding a boolean state flag for double-size mode
2. Creating or scaling sprite variants to 2x resolution
3. Multiplying coordinate and size constants by 2
4. Wiring up keyboard shortcuts to toggle the mode
5. Adapting window sizing through NSWindow API

The existing architecture makes this straightforward with minimal risk of breaking changes.

