import Foundation
import AppKit
import CoreGraphics

// MARK: - Semantic Sprite Identifiers

/// Semantic sprite identifiers that decouple UI mechanisms from skin presentation.
/// Following webamp's architecture: mechanism → bridge → presentation.
///
/// Example:
/// - Timer updates state (mechanism: currentTime in seconds)
/// - Component renders semantic element (bridge: .digit(0))
/// - Skin CSS/resolver maps to actual sprite (presentation: "DIGIT_0" or "DIGIT_0_EX")
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

// MARK: - Sprite Resolver

/// Resolves semantic sprite requests to actual sprite names based on what the current skin provides.
/// This decouples UI mechanism from skin presentation, allowing skins to use different naming conventions.
///
/// Architecture:
/// 1. UI components request sprites using semantic identifiers (e.g., .digit(0))
/// 2. Resolver checks what the skin actually has (DIGIT_0_EX vs DIGIT_0)
/// 3. Returns the appropriate sprite name with fallback priority
/// 4. Falls back to transparent placeholder if sprite missing
///
/// Example:
/// ```swift
/// let resolver = SpriteResolver(skin: currentSkin)
/// let spriteName = resolver.resolve(.digit(0))
/// // Returns "DIGIT_0_EX" if skin has it, otherwise "DIGIT_0", otherwise nil
/// ```
struct SpriteResolver: Sendable {
    private let skin: Skin

    init(skin: Skin) {
        self.skin = skin
    }

    /// Resolve a semantic sprite to an actual sprite name from the current skin.
    /// Returns nil if the sprite doesn't exist in the skin (caller should handle fallback).
    ///
    /// - Parameter semantic: The semantic sprite identifier
    /// - Returns: The actual sprite name if found, nil otherwise
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
    /// The resolver will try each candidate until it finds one that exists in the skin.
    ///
    /// Priority rules:
    /// 1. Prefer _EX variants over standard (extended/enhanced sprites)
    /// 2. Prefer _SELECTED over _ACTIVE over base (for buttons/thumbs)
    /// 3. Fall back to base variants
    ///
    /// - Parameter semantic: The semantic sprite identifier
    /// - Returns: Array of sprite names to try, in priority order
    private func candidates(for semantic: SemanticSprite) -> [String] {
        switch semantic {
        // MARK: - Time Display
        case .digit(let n):
            guard (0...9).contains(n) else {
                AppLog.warn(.ui, "SpriteResolver: digit out of range (\(n)). Expected 0-9.")
                return []
            }
            return [
                "DIGIT_\(n)_EX",      // Prefer extended digits (NUMS_EX.BMP)
                "DIGIT_\(n)"          // Fall back to standard digits (NUMBERS.BMP)
            ]

        case .minusSign:
            return [
                "MINUS_SIGN_EX",
                "MINUS_SIGN"
            ]

        case .noMinusSign:
            return [
                "NO_MINUS_SIGN_EX",
                "NO_MINUS_SIGN"
            ]

        case .character(let ascii):
            return ["CHARACTER_\(ascii)"]

        // MARK: - Transport Controls
        case .playButton:
            return [
                "MAIN_PLAY_BUTTON_ACTIVE",
                "MAIN_PLAY_BUTTON"
            ]

        case .pauseButton:
            return [
                "MAIN_PAUSE_BUTTON_ACTIVE",
                "MAIN_PAUSE_BUTTON"
            ]

        case .stopButton:
            return [
                "MAIN_STOP_BUTTON_ACTIVE",
                "MAIN_STOP_BUTTON"
            ]

        case .nextButton:
            return [
                "MAIN_NEXT_BUTTON_ACTIVE",
                "MAIN_NEXT_BUTTON"
            ]

        case .previousButton:
            return [
                "MAIN_PREVIOUS_BUTTON_ACTIVE",
                "MAIN_PREVIOUS_BUTTON"
            ]

        case .ejectButton:
            return [
                "MAIN_EJECT_BUTTON_ACTIVE",
                "MAIN_EJECT_BUTTON"
            ]

        // MARK: - Window Controls
        case .closeButton:
            return [
                "MAIN_CLOSE_BUTTON_DEPRESSED",
                "MAIN_CLOSE_BUTTON"
            ]

        case .minimizeButton:
            return [
                "MAIN_MINIMIZE_BUTTON_DEPRESSED",
                "MAIN_MINIMIZE_BUTTON"
            ]

        case .shadeButton:
            return [
                "MAIN_SHADE_BUTTON_DEPRESSED",
                "MAIN_SHADE_BUTTON"
            ]

        // MARK: - Sliders
        case .volumeBackground:
            return ["MAIN_VOLUME_BACKGROUND"]

        case .volumeThumb:
            return [
                "MAIN_VOLUME_THUMB_SELECTED",  // Prefer selected for visual consistency
                "MAIN_VOLUME_THUMB"
            ]

        case .volumeThumbSelected:
            return [
                "MAIN_VOLUME_THUMB_SELECTED",
                "MAIN_VOLUME_THUMB"            // Fall back to normal if no selected variant
            ]

        case .balanceBackground:
            return ["MAIN_BALANCE_BACKGROUND"]

        case .balanceThumb:
            return [
                "MAIN_BALANCE_THUMB_ACTIVE",   // Prefer active for visual consistency
                "MAIN_BALANCE_THUMB"
            ]

        case .balanceThumbActive:
            return [
                "MAIN_BALANCE_THUMB_ACTIVE",
                "MAIN_BALANCE_THUMB"
            ]

        case .positionSliderBackground:
            return ["MAIN_POSITION_SLIDER_BACKGROUND"]

        case .positionSliderThumb:
            return [
                "MAIN_POSITION_SLIDER_THUMB_SELECTED",
                "MAIN_POSITION_SLIDER_THUMB"
            ]

        case .positionSliderThumbSelected:
            return [
                "MAIN_POSITION_SLIDER_THUMB_SELECTED",
                "MAIN_POSITION_SLIDER_THUMB"
            ]

        // MARK: - Indicators
        case .playingIndicator:
            return ["MAIN_PLAYING_INDICATOR"]

        case .pausedIndicator:
            return ["MAIN_PAUSED_INDICATOR"]

        case .stoppedIndicator:
            return ["MAIN_STOPPED_INDICATOR"]

        case .monoIndicator:
            return ["MAIN_MONO"]

        case .monoIndicatorSelected:
            return [
                "MAIN_MONO_SELECTED",
                "MAIN_MONO"
            ]

        case .stereoIndicator:
            return ["MAIN_STEREO"]

        case .stereoIndicatorSelected:
            return [
                "MAIN_STEREO_SELECTED",
                "MAIN_STEREO"
            ]

        // MARK: - Equalizer
        case .eqWindowBackground:
            return ["EQ_WINDOW_BACKGROUND"]

        case .eqTitleBar:
            return ["EQ_TITLE_BAR"]

        case .eqTitleBarSelected:
            return [
                "EQ_TITLE_BAR_SELECTED",
                "EQ_TITLE_BAR"
            ]

        case .eqSliderBackground:
            return ["EQ_SLIDER_BACKGROUND"]

        case .eqSliderThumb:
            return [
                "EQ_SLIDER_THUMB_SELECTED",
                "EQ_SLIDER_THUMB"
            ]

        case .eqSliderThumbSelected:
            return [
                "EQ_SLIDER_THUMB_SELECTED",
                "EQ_SLIDER_THUMB"
            ]

        case .eqOnButton:
            return [
                "EQ_ON_BUTTON_SELECTED",
                "EQ_ON_BUTTON"
            ]

        case .eqAutoButton:
            return [
                "EQ_AUTO_BUTTON_SELECTED",
                "EQ_AUTO_BUTTON"
            ]

        // MARK: - Playlist
        case .playlistTopTile:
            return ["PLAYLIST_TOP_TILE"]

        case .playlistTopLeftCorner:
            return ["PLAYLIST_TOP_LEFT_CORNER"]

        case .playlistTitleBar:
            return ["PLAYLIST_TITLE_BAR"]

        case .playlistTopRightCorner:
            return ["PLAYLIST_TOP_RIGHT_CORNER"]

        // MARK: - Main Window
        case .mainWindowBackground:
            return ["MAIN_WINDOW_BACKGROUND"]

        case .mainTitleBar:
            return ["MAIN_TITLE_BAR"]

        case .mainTitleBarSelected:
            return [
                "MAIN_TITLE_BAR_SELECTED",
                "MAIN_TITLE_BAR"
            ]

        case .mainShadeBackground:
            return ["MAIN_SHADE_BACKGROUND"]

        case .mainShadeBackgroundSelected:
            return [
                "MAIN_SHADE_BACKGROUND_SELECTED",
                "MAIN_SHADE_BACKGROUND"
            ]

        case .eqButton:
            return [
                "MAIN_EQ_BUTTON_SELECTED",
                "MAIN_EQ_BUTTON"
            ]

        case .playlistButton:
            return [
                "MAIN_PLAYLIST_BUTTON_SELECTED",
                "MAIN_PLAYLIST_BUTTON"
            ]
        }
    }

    /// Convenience method to get the actual NSImage for a semantic sprite.
    /// Returns nil if the sprite doesn't exist in the skin.
    ///
    /// - Parameter semantic: The semantic sprite identifier
    /// - Returns: The sprite image if found, nil otherwise
    func image(for semantic: SemanticSprite) -> NSImage? {
        guard let spriteName = resolve(semantic) else { return nil }
        return skin.images[spriteName]
    }

    /// Get dimensions for a semantic sprite without loading the image.
    /// Useful for layout calculations.
    ///
    /// - Parameter semantic: The semantic sprite identifier
    /// - Returns: The sprite dimensions if found, nil otherwise
    func dimensions(for semantic: SemanticSprite) -> CGSize? {
        guard let spriteName = resolve(semantic),
              let image = skin.images[spriteName] else {
            return nil
        }
        return image.size
    }
}

// MARK: - SpriteResolver Extension for Environment

import SwiftUI

/// Environment key for accessing the sprite resolver
private struct SpriteResolverKey: EnvironmentKey {
    static let defaultValue: SpriteResolver? = nil
}

extension EnvironmentValues {
    /// The current sprite resolver (derived from current skin)
    var spriteResolver: SpriteResolver? {
        get { self[SpriteResolverKey.self] }
        set { self[SpriteResolverKey.self] = newValue }
    }
}

extension View {
    /// Inject a sprite resolver into the environment.
    /// Typically called once at the root level when skin changes.
    ///
    /// Example:
    /// ```swift
    /// ContentView()
    ///     .spriteResolver(SpriteResolver(skin: currentSkin))
    /// ```
    func spriteResolver(_ resolver: SpriteResolver?) -> some View {
        environment(\.spriteResolver, resolver)
    }
}
