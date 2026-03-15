# MacAmp Sprite System Complete Documentation

**Version:** 2.1.0 (Synced with SpriteResolver.swift)
**Date:** 2026-03-14
**Status:** Production - Fully Implemented
**Purpose:** Complete reference for MacAmp's semantic sprite resolution system

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Design](#architecture-design)
3. [Semantic Sprite Enum](#semantic-sprite-enum)
4. [SpriteResolver Implementation](#spriteresolver-implementation)
5. [Resolution Algorithm](#resolution-algorithm)
6. [Fallback Generation](#fallback-generation)
7. [Skin File Structure](#skin-file-structure)
8. [Integration with Views](#integration-with-views)
9. [Visual Examples](#visual-examples)
10. [Testing & Validation](#testing--validation)
11. [Migration Guide](#migration-guide)
12. [Quick Reference](#quick-reference)

---

## System Overview

The MacAmp sprite system enables complete skin compatibility by decoupling UI components from specific sprite names. Instead of hardcoding sprite names, components request semantic identifiers that are resolved to actual sprites at runtime.

### The Problem It Solves

```swift
// ❌ OLD: Breaks with different skins
SimpleSpriteImage("DIGIT_0", width: 9, height: 13)  // Assumes "DIGIT_0" exists

// ✅ NEW: Works with any skin
SimpleSpriteImage(sprite: resolver.resolve(.digit(0)))  // Finds best match
```

### Key Benefits

- **100% Skin Compatibility**: Works with all Winamp 2.x skins
- **Graceful Fallbacks**: Never crashes, generates sprites if missing
- **Hot Swapping**: Change skins without restart
- **Type Safety**: Compile-time verification of sprite requests
- **Performance**: Cached resolution, no repeated lookups

---

## Architecture Design

The sprite system follows webamp's three-layer architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                     MECHANISM LAYER                             │
│                   "What is happening"                           │
│                                                                  │
│  • Timer updates currentTime (seconds)                         │
│  • Volume changes from 0-100                                   │
│  • Track title updates                                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BRIDGE LAYER                               │
│                "Semantic representation"                        │
│                                                                  │
│  • Component requests: .digit(5)                               │
│  • Component requests: .volumeThumb                            │
│  • Component requests: .playButton                             │
│                                                                  │
│  SpriteResolver maps semantic → actual sprite name             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                            │
│                   "What user sees"                              │
│                                                                  │
│  • Skin provides: "DIGIT_5" or "DIGIT_5_EX"                   │
│  • Skin provides: "VOLUME_THUMB" or "VOL_SLIDER"              │
│  • Skin provides: "CBUTTONS_PLAY_NORM"                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Semantic Sprite Enum

Complete enumeration of all semantic sprites from actual implementation:

```swift
// File: MacAmpApp/Models/SpriteResolver.swift
// Purpose: Semantic sprite identifiers that decouple UI from skin presentation
// Context: Following webamp's architecture: mechanism → bridge → presentation

enum SemanticSprite {
    // MARK: - Time Display
    case digit(Int)              // 0-9 for time display
    case minusSign               // For negative time / remaining time
    case noMinusSign             // Placeholder for minus sign space
    case character(UInt8)        // ASCII character for text display

    // MARK: - Transport Controls
    case playButton
    case pauseButton
    case stopButton
    case nextButton
    case previousButton
    case ejectButton

    // MARK: - Window Controls
    case closeButton
    case minimizeButton
    case shadeButton

    // MARK: - Sliders
    case volumeBackground
    case volumeThumb
    case volumeThumbSelected
    case balanceBackground
    case balanceThumb
    case balanceThumbActive
    case positionSliderBackground
    case positionSliderThumb
    case positionSliderThumbSelected

    // MARK: - Indicators
    case playingIndicator
    case pausedIndicator
    case stoppedIndicator
    case monoIndicator
    case monoIndicatorSelected
    case stereoIndicator
    case stereoIndicatorSelected

    // MARK: - Equalizer
    case eqWindowBackground
    case eqTitleBar
    case eqTitleBarSelected
    case eqSliderBackground
    case eqSliderThumb
    case eqSliderThumbSelected
    case eqOnButton
    case eqAutoButton

    // MARK: - Playlist
    case playlistTopTile
    case playlistTopLeftCorner
    case playlistTitleBar
    case playlistTopRightCorner

    // MARK: - Main Window
    case mainWindowBackground
    case mainTitleBar
    case mainTitleBarSelected
    case mainShadeBackground
    case mainShadeBackgroundSelected
    case eqButton
    case playlistButton
}
```

---

## SpriteResolver Implementation

The core resolution engine from actual codebase:

```swift
// File: MacAmpApp/Models/SpriteResolver.swift
// Purpose: Resolves semantic sprite requests to actual sprite names
// Context: Decouples UI mechanism from skin presentation

struct SpriteResolver: Sendable {
    private let skin: Skin

    init(skin: Skin) {
        self.skin = skin
    }

    /// Resolve a semantic sprite to an actual sprite name from the current skin.
    /// Returns nil if the sprite doesn't exist in the skin (caller should handle fallback).
    func resolve(_ semantic: SemanticSprite) -> String? {
        let candidates = candidates(for: semantic)

        // Try each candidate in priority order
        for candidate in candidates {
            if skin.images[candidate] != nil {
                return candidate
            }
        }

        // No sprite found - caller should handle fallback
        return nil
    }

    /// Get the list of candidate sprite names for a semantic sprite, in priority order.
    /// Priority rules:
    /// 1. Prefer _EX variants over standard (extended/enhanced sprites)
    /// 2. Prefer _SELECTED over _ACTIVE over base (for buttons/thumbs)
    /// 3. Fall back to base variants
    private func candidates(for semantic: SemanticSprite) -> [String] {
        switch semantic {
        case .digit(let n):
            guard (0...9).contains(n) else { return [] }
            return ["DIGIT_\(n)_EX", "DIGIT_\(n)"]
        case .minusSign:
            return ["MINUS_SIGN_EX", "MINUS_SIGN"]
        case .noMinusSign:
            return ["NO_MINUS_SIGN_EX", "NO_MINUS_SIGN"]
        case .character(let ascii):
            return ["CHARACTER_\(ascii)"]

        // Transport Controls
        case .playButton:
            return ["MAIN_PLAY_BUTTON_ACTIVE", "MAIN_PLAY_BUTTON"]
        case .pauseButton:
            return ["MAIN_PAUSE_BUTTON_ACTIVE", "MAIN_PAUSE_BUTTON"]
        case .stopButton:
            return ["MAIN_STOP_BUTTON_ACTIVE", "MAIN_STOP_BUTTON"]
        case .nextButton:
            return ["MAIN_NEXT_BUTTON_ACTIVE", "MAIN_NEXT_BUTTON"]
        case .previousButton:
            return ["MAIN_PREVIOUS_BUTTON_ACTIVE", "MAIN_PREVIOUS_BUTTON"]
        case .ejectButton:
            return ["MAIN_EJECT_BUTTON_ACTIVE", "MAIN_EJECT_BUTTON"]

        // Window Controls
        case .closeButton:
            return ["MAIN_CLOSE_BUTTON_DEPRESSED", "MAIN_CLOSE_BUTTON"]
        case .minimizeButton:
            return ["MAIN_MINIMIZE_BUTTON_DEPRESSED", "MAIN_MINIMIZE_BUTTON"]
        case .shadeButton:
            return ["MAIN_SHADE_BUTTON_DEPRESSED", "MAIN_SHADE_BUTTON"]

        // Sliders
        case .volumeBackground:
            return ["MAIN_VOLUME_BACKGROUND"]
        case .volumeThumb:
            return ["MAIN_VOLUME_THUMB_SELECTED", "MAIN_VOLUME_THUMB"]
        case .volumeThumbSelected:
            return ["MAIN_VOLUME_THUMB_SELECTED", "MAIN_VOLUME_THUMB"]
        case .balanceBackground:
            return ["MAIN_BALANCE_BACKGROUND"]
        case .balanceThumb:
            return ["MAIN_BALANCE_THUMB_ACTIVE", "MAIN_BALANCE_THUMB"]
        case .balanceThumbActive:
            return ["MAIN_BALANCE_THUMB_ACTIVE", "MAIN_BALANCE_THUMB"]
        case .positionSliderBackground:
            return ["MAIN_POSITION_SLIDER_BACKGROUND"]
        case .positionSliderThumb:
            return ["MAIN_POSITION_SLIDER_THUMB_SELECTED", "MAIN_POSITION_SLIDER_THUMB"]
        case .positionSliderThumbSelected:
            return ["MAIN_POSITION_SLIDER_THUMB_SELECTED", "MAIN_POSITION_SLIDER_THUMB"]

        // Indicators
        case .playingIndicator:  return ["MAIN_PLAYING_INDICATOR"]
        case .pausedIndicator:   return ["MAIN_PAUSED_INDICATOR"]
        case .stoppedIndicator:  return ["MAIN_STOPPED_INDICATOR"]
        case .monoIndicator:     return ["MAIN_MONO"]
        case .monoIndicatorSelected:   return ["MAIN_MONO_SELECTED", "MAIN_MONO"]
        case .stereoIndicator:         return ["MAIN_STEREO"]
        case .stereoIndicatorSelected: return ["MAIN_STEREO_SELECTED", "MAIN_STEREO"]

        // Equalizer
        case .eqWindowBackground:  return ["EQ_WINDOW_BACKGROUND"]
        case .eqTitleBar:          return ["EQ_TITLE_BAR"]
        case .eqTitleBarSelected:  return ["EQ_TITLE_BAR_SELECTED", "EQ_TITLE_BAR"]
        case .eqSliderBackground:  return ["EQ_SLIDER_BACKGROUND"]
        case .eqSliderThumb:       return ["EQ_SLIDER_THUMB_SELECTED", "EQ_SLIDER_THUMB"]
        case .eqSliderThumbSelected: return ["EQ_SLIDER_THUMB_SELECTED", "EQ_SLIDER_THUMB"]
        case .eqOnButton:          return ["EQ_ON_BUTTON_SELECTED", "EQ_ON_BUTTON"]
        case .eqAutoButton:        return ["EQ_AUTO_BUTTON_SELECTED", "EQ_AUTO_BUTTON"]

        // Playlist
        case .playlistTopTile:        return ["PLAYLIST_TOP_TILE"]
        case .playlistTopLeftCorner:  return ["PLAYLIST_TOP_LEFT_CORNER"]
        case .playlistTitleBar:       return ["PLAYLIST_TITLE_BAR"]
        case .playlistTopRightCorner: return ["PLAYLIST_TOP_RIGHT_CORNER"]

        // Main Window
        case .mainWindowBackground:        return ["MAIN_WINDOW_BACKGROUND"]
        case .mainTitleBar:                return ["MAIN_TITLE_BAR"]
        case .mainTitleBarSelected:        return ["MAIN_TITLE_BAR_SELECTED", "MAIN_TITLE_BAR"]
        case .mainShadeBackground:         return ["MAIN_SHADE_BACKGROUND"]
        case .mainShadeBackgroundSelected: return ["MAIN_SHADE_BACKGROUND_SELECTED", "MAIN_SHADE_BACKGROUND"]
        case .eqButton:       return ["MAIN_EQ_BUTTON_SELECTED", "MAIN_EQ_BUTTON"]
        case .playlistButton: return ["MAIN_PLAYLIST_BUTTON_SELECTED", "MAIN_PLAYLIST_BUTTON"]
        }
    }

    /// Convenience method to get the actual NSImage for a semantic sprite.
    func image(for semantic: SemanticSprite) -> NSImage? {
        guard let spriteName = resolve(semantic) else { return nil }
        return skin.images[spriteName]
    }

    /// Get dimensions for a semantic sprite without loading the image.
    func dimensions(for semantic: SemanticSprite) -> CGSize? {
        guard let spriteName = resolve(semantic),
              let image = skin.images[spriteName] else {
            return nil
        }
        return image.size
    }
}
```

---

## Resolution Algorithm

The resolution flow is straightforward -- no caching or derived mappings.
`candidates(for:)` returns an ordered list of sprite names, and `resolve(_:)`
picks the first one that exists in the skin. If none match, it returns `nil`
and the caller (typically `SkinManager`) handles the fallback.

```
resolve(.playButton)
         │
         ▼
┌───────────────────────────┐
│ candidates(for:) returns  │
│ priority-ordered names:   │
│  1. MAIN_PLAY_BUTTON_ACTIVE
│  2. MAIN_PLAY_BUTTON      │
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ Iterate candidates        │
│ Check skin.images[name]   │──▶ Found? Return sprite name
└───────────────────────────┘
         │ None found
         ▼
    Return nil
    (caller generates transparent fallback)
```

---

## Fallback Generation

Actual fallback sprite generation from the codebase:

```swift
// File: MacAmpApp/ViewModels/SkinManager.swift:417-461
// Purpose: Generate transparent fallback sprites for missing elements
// Context: Ensures app never crashes due to missing sprites

/// Create a transparent fallback image for a missing sprite
private func createFallbackSprite(named spriteName: String) -> NSImage {
    // Try to get dimensions from sprite definitions
    let size: CGSize
    if let definedSize = SkinSprites.defaultSprites.dimensions(forSprite: spriteName) {
        size = definedSize
        NSLog("⚠️ Creating fallback for '\(spriteName)' with defined size: \(definedSize.width)x\(definedSize.height)")
    } else {
        // Use a reasonable default size for unknown sprites
        size = CGSize(width: 16, height: 16)
        NSLog("⚠️ Creating fallback for '\(spriteName)' with default size: 16x16 (no definition found)")
    }

    // Create a transparent image
    let image = NSImage(size: size)
    image.lockFocus()

    // Fill with transparent color
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    image.unlockFocus()

    return image
}

/// Generate fallback sprites for all missing sprites from a sheet
private func createFallbackSprites(forSheet sheetName: String, sprites: [Sprite]) -> [String: NSImage] {
    var fallbacks: [String: NSImage] = [:]

    NSLog("⚠️ Sheet '\(sheetName)' is missing - generating \(sprites.count) fallback sprites")

    for sprite in sprites {
        let fallbackImage = createFallbackSprite(named: sprite.name)
        fallbacks[sprite.name] = fallbackImage
    }

    return fallbacks
}

// Usage during skin loading:
// File: MacAmpApp/ViewModels/SkinManager.swift (loading pattern)
private func loadSkinImages(from directory: URL) -> [String: NSImage] {
    var images: [String: NSImage] = [:]

    // Try to load each required sheet
    for (sheetName, sprites) in SkinSprites.defaultSprites.sheets {
        let sheetPath = directory.appendingPathComponent(sheetName)

        if let sheetImage = NSImage(contentsOf: sheetPath) {
            // Extract sprites from sheet
            let extracted = extractSprites(from: sheetImage, sprites: sprites)
            images.merge(extracted) { _, new in new }
        } else {
            // Generate fallbacks for missing sheet
            let fallbacks = createFallbackSprites(forSheet: sheetName, sprites: sprites)
            images.merge(fallbacks) { _, new in new }
        }
    }

    return images
}
```

---

## Skin File Structure

How skins organize their sprites:

```
MySkin.wsz (ZIP archive)
│
├── main.bmp          # Main window sprites
├── cbuttons.bmp      # Transport control buttons
├── titlebar.bmp      # Title bar graphics
├── shufrep.bmp       # Shuffle/repeat buttons
├── monoster.bmp      # Mono/stereo indicators
├── playpaus.bmp      # Play/pause indicators
├── posbar.bmp        # Position slider
├── volume.bmp        # Volume slider (28 frames, 15px each, green→red gradient)
├── balance.bmp       # Balance slider (28 frames, 15px each, green→red gradient)
├── numbers.bmp       # Standard digits (9x13)
├── nums_ex.bmp       # Extended digits (optional)
├── text.bmp          # Bitmap font
├── eqmain.bmp        # Equalizer window
├── eq_ex.bmp         # Extended EQ graphics
├── pledit.bmp        # Playlist editor
├── pledit.txt        # Playlist colors
├── viscolor.txt      # Visualization colors
└── region.txt        # Window regions (optional)
```

### Sprite Extraction Coordinates

```swift
// Standard Winamp sprite locations
struct WinampSpriteCoordinates {
    // CBUTTONS.BMP layout (each button 23x18)
    static let playNormal = NSRect(x: 0, y: 0, width: 23, height: 18)
    static let playPressed = NSRect(x: 0, y: 18, width: 23, height: 18)
    static let pauseNormal = NSRect(x: 23, y: 0, width: 23, height: 18)
    static let pausePressed = NSRect(x: 23, y: 18, width: 23, height: 18)
    static let stopNormal = NSRect(x: 46, y: 0, width: 23, height: 18)
    static let stopPressed = NSRect(x: 46, y: 18, width: 23, height: 18)
    static let nextNormal = NSRect(x: 69, y: 0, width: 22, height: 18)
    static let nextPressed = NSRect(x: 69, y: 18, width: 22, height: 18)
    static let prevNormal = NSRect(x: 91, y: 0, width: 22, height: 18)
    static let prevPressed = NSRect(x: 91, y: 18, width: 22, height: 18)
    static let ejectNormal = NSRect(x: 113, y: 0, width: 22, height: 16)
    static let ejectPressed = NSRect(x: 113, y: 16, width: 22, height: 16)

    // NUMBERS.BMP layout (each digit 9x13)
    static func digit(_ n: Int) -> NSRect {
        NSRect(x: n * 9, y: 0, width: 9, height: 13)
    }

    // VOLUME.BMP layout (28 frames stacked vertically, 15px each)
    // Frame 0 (y:0) = green (mute), Frame 27 (y:405) = red (max)
    static let volumeBackground = NSRect(x: 0, y: 0, width: 68, height: 420)
    static let volumeThumb = NSRect(x: 15, y: 422, width: 14, height: 11)
    static let volumeThumbPressed = NSRect(x: 0, y: 422, width: 14, height: 11)

    // BALANCE.BMP layout (28 frames stacked vertically, 15px each)
    // Frame 0 (y:0) = green (center/neutral), Frame 27 (y:405) = red (full L/R)
    // Webamp-compatible: offset = floor(abs(balance) * 27) * 15
    static let balanceBackground = NSRect(x: 9, y: 0, width: 38, height: 420)
    static let balanceThumb = NSRect(x: 15, y: 422, width: 14, height: 11)
    static let balanceThumbActive = NSRect(x: 0, y: 422, width: 14, height: 11)
}
```

---

## Integration with Views

How views use the sprite system:

```swift
// MacAmpApp/Views/MainWindow/WinampMainWindow.swift
struct WinampMainWindow: View {
    @Environment(SkinManager.self) private var skinManager

    var body: some View {
        ZStack {
            // Background (always resolved)
            SimpleSpriteImage(
                sprite: skinManager.resolvedSprites.mainBackground
            )

            // Play button with pressed state
            SkinButton(
                normal: skinManager.resolvedSprites.playButton,
                pressed: skinManager.resolvedSprites.playButtonPressed,
                action: { playbackCoordinator.play() }
            )
            .at(x: 39, y: 88)

            // Time display using digits
            TimeDisplay(
                time: audioPlayer.currentTime,
                resolver: skinManager.spriteResolver
            )
            .at(x: 48, y: 26)
        }
    }
}

// TimeDisplay component
struct TimeDisplay: View {
    let time: TimeInterval
    let resolver: SpriteResolver

    var body: some View {
        HStack(spacing: 0) {
            ForEach(timeDigits, id: \.offset) { digit in
                SimpleSpriteImage(
                    sprite: resolver.resolve(.digit(digit.value))
                )
            }
        }
    }

    private var timeDigits: [(offset: Int, value: Int)] {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60

        return [
            (0, minutes / 10),
            (1, minutes % 10),
            (2, 10), // Colon (special digit)
            (3, seconds / 10),
            (4, seconds % 10)
        ]
    }
}
```

---

## Visual Examples

### Resolution in Action

```
User clicks play button:

1. Component requests: .playButton
                            │
2. Resolver calls            ▼
   candidates(for: .playButton):
   ┌──────────────────────────────────┐
   │ "MAIN_PLAY_BUTTON_ACTIVE"? Yes! │
   └──────────────────────────────────┘
                            │
3. Returns:                 ▼
   "MAIN_PLAY_BUTTON_ACTIVE"  (String?)
   Caller uses skin.images[name] to get NSImage
```

### Fallback Generation Example

```
Missing sprite: .eqSliderThumb

Generator creates:
┌─────────────┐
│             │  ← Gray background
│    ╔═╗      │  ← White thumb
│    ╚═╝      │
│             │
└─────────────┘
    11x11 px
```

---

## Testing & Validation

### Unit Tests

```swift
// Tests/SpriteResolverTests.swift
func testDigitResolution() {
    let skin = loadTestSkin("standard.wsz")
    let resolver = SpriteResolver(skin: skin)

    // Test standard digit -- returns sprite name string or nil
    let digit5 = resolver.resolve(.digit(5))
    XCTAssertEqual(digit5, "DIGIT_5")

    // Test extended digit skin (has NUMS_EX.BMP)
    let extendedSkin = loadTestSkin("extended.wsz")
    let extResolver = SpriteResolver(skin: extendedSkin)
    let extDigit5 = extResolver.resolve(.digit(5))
    XCTAssertEqual(extDigit5, "DIGIT_5_EX")
}

func testMissingSpriteReturnsNil() {
    let emptySkin = Skin(images: [:])
    let resolver = SpriteResolver(skin: emptySkin)

    let playButton = resolver.resolve(.playButton)
    XCTAssertNil(playButton)
}

func testImageConvenience() {
    let skin = loadTestSkin("standard.wsz")
    let resolver = SpriteResolver(skin: skin)

    let image = resolver.image(for: .volumeThumb)
    XCTAssertNotNil(image)
}
```

---

## Migration Guide

### Converting from Hard-Coded Sprites

**Step 1**: Identify hard-coded sprite usage
```swift
// Find all SimpleSpriteImage with string literals
SimpleSpriteImage("MAIN_PLAY_BUTTON_NORMAL", width: 23, height: 18)
```

**Step 2**: Map to semantic enum
```swift
// Replace with semantic identifier
SimpleSpriteImage(sprite: resolver.resolve(.playButton))
```

**Step 3**: Remove size parameters
```swift
// Size comes from resolved sprite
// No need for width/height
```

### Common Mappings

| Old Hard-Coded | Semantic Enum | Notes |
|----------------|---------------|-------|
| "DIGIT_0" | `.digit(0)` | Auto-detects extended |
| "MAIN_PLAY_BUTTON" | `.playButton` | |
| "MAIN_VOLUME_THUMB" | `.volumeThumb` | |
| "MAIN_VOLUME_THUMB_SELECTED" | `.volumeThumbSelected` | |
| "EQ_SLIDER_THUMB" | `.eqSliderThumb` | |
| "MAIN_TITLE_BAR" | `.mainTitleBar` | |
| "MAIN_TITLE_BAR_SELECTED" | `.mainTitleBarSelected` | |
| "MAIN_EQ_BUTTON" | `.eqButton` | |
| "MAIN_PLAYLIST_BUTTON" | `.playlistButton` | |

---

## Quick Reference

### Most Common Resolutions

```swift
// Transport controls
resolver.resolve(.playButton)
resolver.resolve(.pauseButton)
resolver.resolve(.stopButton)
resolver.resolve(.nextButton)
resolver.resolve(.previousButton)

// Digits for time
(0...9).map { resolver.resolve(.digit($0)) }

// Sliders (static thumb images; dynamic frame selection via calculateBalanceFrameOffset())
resolver.resolve(.volumeThumb)
resolver.resolve(.balanceThumb)
resolver.resolve(.positionSliderThumb)

// Window backgrounds
resolver.resolve(.mainWindowBackground)
resolver.resolve(.eqWindowBackground)
resolver.resolve(.playlistBackground)

// Indicators
resolver.resolve(.stereoIndicator)
resolver.resolve(.playingIndicator)
```

### Adding New Semantic Sprites

1. Add a new case to the `SemanticSprite` enum
2. Add a corresponding case in `candidates(for:)` returning priority-ordered sprite names
3. Ensure `SkinManager` generates a transparent fallback for the new sprite if missing
4. Update tests

### Design Notes

- Resolution is stateless -- no caching layer; `resolve(_:)` iterates candidates each call
- The `Skin.images` dictionary lookup is O(1), so repeated resolution is cheap
- `SpriteResolver` is `Sendable` and safe to share across concurrency domains
- Fallback generation lives in `SkinManager`, not in the resolver itself

---

## Conclusion

The sprite system is the foundation of MacAmp's skin compatibility. By separating semantic meaning from visual presentation, we achieve:

- **Universal compatibility** with all Winamp skins
- **Graceful degradation** when sprites are missing
- **Clean component code** without hard-coded names
- **Type safety** through Swift enums
- **Sendable** and safe across concurrency domains

The system embodies the principle: "The skin is not the app, the app is not the skin."

---

*Document Version: 2.1.0 | Last Updated: 2026-03-14*