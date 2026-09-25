# MacAmp Sprite System

**Version:** 2.2.0
**Date:** 2026-09-25
**Purpose:** Reference for MacAmp's semantic sprite resolution system (`MacAmpApp/Models/SpriteResolver.swift`)

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
9. [Testing & Validation](#testing--validation)
10. [Migration Guide](#migration-guide)
11. [Quick Reference](#quick-reference)

---

## System Overview

Components request semantic identifiers instead of hard-coded sprite names; `SpriteResolver` maps each to the best sprite the current skin provides.

```swift
SimpleSpriteImage("DIGIT_0", width: 9, height: 13)   // legacy: assumes "DIGIT_0" exists
SimpleSpriteImage(.digit(0), width: 9, height: 13)   // semantic: prefers DIGIT_0_EX, falls back to DIGIT_0
```

- Works across Winamp 2.x skins, including optional extended sheets (e.g. `NUMS_EX.bmp`)
- Missing sheets/sprites never crash: `SkinManager` substitutes default-skin or transparent sprites
- Skins change without restart
- Semantic requests are compile-time checked enum cases

---

## Architecture Design

The sprite system follows webamp's three-layer architecture:

```
MECHANISM     "What is happening"     timer updates currentTime, volume 0-100, track title
    │
    ▼
BRIDGE        "Semantic request"      .digit(5), .volumeThumb, .playButton
    │                                 SpriteResolver maps semantic → sprite name
    ▼
PRESENTATION  "What the user sees"    skin provides DIGIT_5 or DIGIT_5_EX, MAIN_VOLUME_THUMB, ...
```

---

## Semantic Sprite Enum

`enum SemanticSprite` groups its cases as Time Display (`digit(Int)`, `minusSign`, `noMinusSign`, `character(UInt8)`), Transport Controls, Window Controls, Sliders, Indicators, Equalizer, Playlist, and Main Window. Every case and its candidate sprite names are listed in the `candidates(for:)` switch below.

---

## SpriteResolver Implementation

```swift
// MacAmpApp/Models/SpriteResolver.swift

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
}
```

An out-of-range `.digit(n)` logs a warning and returns no candidates. The same file defines an `EnvironmentValues.spriteResolver` key and a `View.spriteResolver(_:)` modifier for injecting a resolver.

---

## Resolution Algorithm

No caching or derived mappings: `candidates(for:)` returns an ordered list of sprite names, and `resolve(_:)` returns the first one present in `skin.images`, or `nil`.

```
resolve(.playButton)
  → candidates: MAIN_PLAY_BUTTON_ACTIVE, MAIN_PLAY_BUTTON
  → first name found in skin.images is returned
  → none found: nil (caller decides what to draw)
```

---

## Fallback Generation

Fallbacks are produced by `SkinManager.loadSkin(from:)` (`MacAmpApp/ViewModels/SkinManager.swift`), not by the resolver. For each sheet in `SkinSprites.defaultSprites.sheets` (plus `NUMS_EX` when the archive has `nums_ex`):

1. **Sheet missing from the skin** → use that sheet's sprites from the bundled default Winamp skin (`fallbackSpritesFromDefaultSkin`, cached per sheet); if that fails, generate transparent sprites (`createFallbackSprites(forSheet:sprites:)`). The sheet is not recorded in `loadedSheets`.
2. **Sheet data fails to decode** → transparent sprites for the whole sheet.
3. **Individual crop fails** → one transparent sprite (`createFallbackSprite(named:)`).

`createFallbackSprite(named:)` sizes the transparent image from `SkinSprites.defaultSprites.dimensions(forSprite:)`, or 16×16 if the sprite has no definition, and logs via `AppLog.debug(.skin, ...)`.

If a `SimpleSpriteImage` still can't find an image (no skin loaded, or `resolve` returned `nil`), it draws a purple placeholder rectangle with a "?".

---

## Skin File Structure

```
MySkin.wsz (ZIP archive)
├── main.bmp          # Main window background
├── cbuttons.bmp      # Transport control buttons
├── titlebar.bmp      # Title bar graphics
├── shufrep.bmp       # Shuffle/repeat/EQ/playlist buttons
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
├── gen.bmp           # Generic window chrome (Milkdrop)
├── video.bmp         # Video window chrome
├── pledit.txt        # Playlist colors
├── viscolor.txt      # Visualization colors
└── region.txt        # Window regions (optional)
```

### Sprite Extraction Coordinates

All sprite rectangles are defined in `MacAmpApp/Models/SkinSprites.swift` (`SkinSprites.defaultSprites`, keyed by sheet: `MAIN`, `CBUTTONS`, `NUMBERS`, `MONOSTER`, `PLAYPAUS`, `TITLEBAR`, `POSBAR`, `VOLUME`, `BALANCE`, `SHUFREP`, `EQMAIN`, `EQ_EX`, `GEN`, `PLEDIT`, `VIDEO`; `NUMS_EX` separately). Examples:

| Sprite | Rect (x, y, w, h) |
|--------|-------------------|
| `MAIN_PREVIOUS_BUTTON` / `_ACTIVE` | 0,0,23,18 / 0,18,23,18 |
| `MAIN_PLAY_BUTTON` / `_ACTIVE` | 23,0,23,18 / 23,18,23,18 |
| `MAIN_PAUSE_BUTTON` / `_ACTIVE` | 46,0,23,18 / 46,18,23,18 |
| `MAIN_STOP_BUTTON` / `_ACTIVE` | 69,0,23,18 / 69,18,23,18 |
| `MAIN_NEXT_BUTTON` / `_ACTIVE` | 92,0,23,18 / 92,18,22,18 |
| `MAIN_EJECT_BUTTON` / `_ACTIVE` | 114,0,22,16 / 114,16,22,16 |
| `DIGIT_n` | n×9,0,9,13 |
| `MAIN_VOLUME_BACKGROUND` | 0,0,68,420 |
| `MAIN_VOLUME_THUMB` / `_SELECTED` | 15,422,14,11 / 0,422,14,11 |
| `MAIN_BALANCE_BACKGROUND` | 9,0,38,420 |
| `MAIN_BALANCE_THUMB` / `_ACTIVE` | 15,422,14,11 / 0,422,14,11 |

Volume and balance backgrounds are 28 frames stacked vertically (15px each). Volume frame 0 is green (mute) and frame 27 red (max); balance frame 0 is green (center) and frame 27 red (full L/R), with the Webamp-compatible offset `floor(abs(balance) * 27) * 15` (`calculateBalanceFrameOffset()` in `WinampVolumeSlider.swift`).

---

## Integration with Views

Views use `SimpleSpriteImage` (`MacAmpApp/Views/Components/SimpleSpriteImage.swift`), which reads `SkinManager` from the environment and accepts either source:

```swift
init(_ semantic: SemanticSprite, width: CGFloat? = nil, height: CGFloat? = nil)  // resolved via SpriteResolver(skin:)
init(_ spriteKey: String, width: CGFloat? = nil, height: CGFloat? = nil)         // legacy name, used as-is
```

It resolves the name once per body evaluation and renders with `.interpolation(.none)`, no antialiasing, filling the given frame. Example (time digits, `MacAmpApp/Views/MainWindow/MainWindowFullLayer.swift`):

```swift
SimpleSpriteImage(.digit(digits[0]), width: 9, height: 13).offset(x: 8, y: 0)
SimpleSpriteImage(.digit(digits[1]), width: 9, height: 13).offset(x: 19, y: 0)
```

---

## Testing & Validation

`Tests/MacAmpTests/SpriteResolverTests.swift` (Swift Testing, `@Suite("SpriteResolver", .tags(.skin))`) builds `Skin` values directly (`Skin(visualizerColors:playlistStyle:images:cursors:loadedSheets:)`) and checks:

- out-of-range digits (`-1, 10, 99, -100`) resolve to `nil`
- a valid digit resolves to its name when the image is present (`DIGIT_3`)

---

## Migration Guide

To convert a hard-coded sprite:

```swift
SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)   // before
SimpleSpriteImage(.playButton, width: 23, height: 18)          // after
```

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

### Adding New Semantic Sprites

1. Add a case to `SemanticSprite`
2. Add it to `candidates(for:)`, returning priority-ordered sprite names
3. Make sure the sprite is defined in `SkinSprites` so `SkinManager` can size a fallback
4. Update tests

### Design Notes

- Resolution is stateless (no cache); `Skin.images` lookup is O(1), so repeated resolution is cheap
- `SpriteResolver` is `Sendable` and safe to share across concurrency domains
- Fallback generation lives in `SkinManager`, not in the resolver
- Slider thumbs are static images; background frame selection is computed in the slider views
