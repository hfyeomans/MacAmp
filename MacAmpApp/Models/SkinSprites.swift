
import Foundation
import CoreGraphics

// Represents the coordinates and dimensions of a single UI sprite within a skin bitmap.
struct Sprite {
    let name: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var rect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}

// Aggregates all sprite sheets defined by a classic Winamp skin.
// Ported (subset) from Webamp's skinSprites.ts.
struct SkinSprites {
    // Map of sheet name (e.g., MAIN, CBUTTONS) to its sprites
    let sheets: [String: [Sprite]]

    // Quick lookup by sprite name
    private var allSpritesByName: [String: Sprite]

    init(sheets: [String: [Sprite]]) {
        self.sheets = sheets
        var map: [String: Sprite] = [:]
        for (_, arr) in sheets {
            for s in arr { map[s.name] = s }
        }
        self.allSpritesByName = map
    }

    func sprite(named name: String) -> Sprite? {
        allSpritesByName[name]
    }

    /// Get the dimensions for a sprite by name
    func dimensions(forSprite name: String) -> CGSize? {
        guard let sprite = sprite(named: name) else { return nil }
        return CGSize(width: sprite.width, height: sprite.height)
    }

    static let defaultSprites = SkinSprites(sheets: [
        // MAIN.bmp
        "MAIN": [
            Sprite(name: "MAIN_WINDOW_BACKGROUND", x: 0, y: 0, width: 275, height: 116),
        ],

        // CBUTTONS.bmp (transport controls)
        "CBUTTONS": [
            Sprite(name: "MAIN_PREVIOUS_BUTTON", x: 0, y: 0, width: 23, height: 18),
            Sprite(name: "MAIN_PREVIOUS_BUTTON_ACTIVE", x: 0, y: 18, width: 23, height: 18),
            Sprite(name: "MAIN_PLAY_BUTTON", x: 23, y: 0, width: 23, height: 18),
            Sprite(name: "MAIN_PLAY_BUTTON_ACTIVE", x: 23, y: 18, width: 23, height: 18),
            Sprite(name: "MAIN_PAUSE_BUTTON", x: 46, y: 0, width: 23, height: 18),
            Sprite(name: "MAIN_PAUSE_BUTTON_ACTIVE", x: 46, y: 18, width: 23, height: 18),
            Sprite(name: "MAIN_STOP_BUTTON", x: 69, y: 0, width: 23, height: 18),
            Sprite(name: "MAIN_STOP_BUTTON_ACTIVE", x: 69, y: 18, width: 23, height: 18),
            Sprite(name: "MAIN_NEXT_BUTTON", x: 92, y: 0, width: 23, height: 18),
            Sprite(name: "MAIN_NEXT_BUTTON_ACTIVE", x: 92, y: 18, width: 22, height: 18),
            Sprite(name: "MAIN_EJECT_BUTTON", x: 114, y: 0, width: 22, height: 16),
            Sprite(name: "MAIN_EJECT_BUTTON_ACTIVE", x: 114, y: 16, width: 22, height: 16),
        ],

        // NUMBERS.bmp (time digits and minus sign)
        "NUMBERS": [
            Sprite(name: "NO_MINUS_SIGN", x: 9, y: 6, width: 5, height: 1),
            Sprite(name: "MINUS_SIGN", x: 20, y: 6, width: 5, height: 1),
            Sprite(name: "DIGIT_0", x: 0, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_1", x: 9, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_2", x: 18, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_3", x: 27, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_4", x: 36, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_5", x: 45, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_6", x: 54, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_7", x: 63, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_8", x: 72, y: 0, width: 9, height: 13),
            Sprite(name: "DIGIT_9", x: 81, y: 0, width: 9, height: 13),
        ],
        // NUMS_EX.bmp (extended digits) - OPTIONAL: Not all skins have this
        // Only include this if the skin has NUMS_EX.BMP file
        // Note: This will be conditionally loaded based on skin contents

        // MONOSTER.bmp (mono/stereo indicators)
        "MONOSTER": [
            Sprite(name: "MAIN_STEREO", x: 0, y: 12, width: 29, height: 12),
            Sprite(name: "MAIN_STEREO_SELECTED", x: 0, y: 0, width: 29, height: 12),
            Sprite(name: "MAIN_MONO", x: 29, y: 12, width: 27, height: 12),
            Sprite(name: "MAIN_MONO_SELECTED", x: 29, y: 0, width: 27, height: 12),
        ],

        // PLAYPAUS.bmp (play/pause indicators)
        "PLAYPAUS": [
            Sprite(name: "MAIN_PLAYING_INDICATOR", x: 0, y: 0, width: 9, height: 9),
            Sprite(name: "MAIN_PAUSED_INDICATOR", x: 9, y: 0, width: 9, height: 9),
            Sprite(name: "MAIN_STOPPED_INDICATOR", x: 18, y: 0, width: 9, height: 9),
        ],

        // TITLEBAR.bmp (title bar + window buttons)
        "TITLEBAR": [
            Sprite(name: "MAIN_TITLE_BAR", x: 27, y: 15, width: 275, height: 14),
            Sprite(name: "MAIN_TITLE_BAR_SELECTED", x: 27, y: 0, width: 275, height: 14),
            Sprite(name: "MAIN_MINIMIZE_BUTTON", x: 9, y: 0, width: 9, height: 9),
            Sprite(name: "MAIN_MINIMIZE_BUTTON_DEPRESSED", x: 9, y: 9, width: 9, height: 9),
            Sprite(name: "MAIN_SHADE_BUTTON", x: 0, y: 18, width: 9, height: 9),
            Sprite(name: "MAIN_SHADE_BUTTON_DEPRESSED", x: 9, y: 18, width: 9, height: 9),
            Sprite(name: "MAIN_CLOSE_BUTTON", x: 18, y: 0, width: 9, height: 9),
            Sprite(name: "MAIN_CLOSE_BUTTON_DEPRESSED", x: 18, y: 9, width: 9, height: 9),
            // Clutter bar buttons - normal state from BACKGROUND (x:304, y:0-43)
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_O", x: 304, y: 3, width: 8, height: 8),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_O_SELECTED", x: 304, y: 47, width: 8, height: 8),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_A", x: 304, y: 11, width: 8, height: 7),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_A_SELECTED", x: 312, y: 55, width: 8, height: 7),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_I", x: 304, y: 18, width: 8, height: 7),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_I_SELECTED", x: 320, y: 62, width: 8, height: 7),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_D", x: 304, y: 25, width: 8, height: 8),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_D_SELECTED", x: 328, y: 69, width: 8, height: 8),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_V", x: 304, y: 33, width: 8, height: 7),
            Sprite(name: "MAIN_CLUTTER_BAR_BUTTON_V_SELECTED", x: 336, y: 77, width: 8, height: 7),
            Sprite(name: "MAIN_SHADE_BACKGROUND", x: 27, y: 42, width: 275, height: 14),
            Sprite(name: "MAIN_SHADE_BACKGROUND_SELECTED", x: 27, y: 29, width: 275, height: 14),
        ],

        // POSBAR.bmp (position slider)
        "POSBAR": [
            Sprite(name: "MAIN_POSITION_SLIDER_BACKGROUND", x: 0, y: 0, width: 248, height: 10),
            Sprite(name: "MAIN_POSITION_SLIDER_THUMB", x: 248, y: 0, width: 29, height: 10),
            Sprite(name: "MAIN_POSITION_SLIDER_THUMB_SELECTED", x: 278, y: 0, width: 29, height: 10),
        ],

        // VOLUME.bmp
        "VOLUME": [
            Sprite(name: "MAIN_VOLUME_BACKGROUND", x: 0, y: 0, width: 68, height: 420),
            Sprite(name: "MAIN_VOLUME_THUMB", x: 15, y: 422, width: 14, height: 11),
            Sprite(name: "MAIN_VOLUME_THUMB_SELECTED", x: 0, y: 422, width: 14, height: 11),
        ],

        // BALANCE.bmp
        "BALANCE": [
            Sprite(name: "MAIN_BALANCE_BACKGROUND", x: 9, y: 0, width: 38, height: 420),
            Sprite(name: "MAIN_BALANCE_THUMB", x: 15, y: 422, width: 14, height: 11),
            Sprite(name: "MAIN_BALANCE_THUMB_ACTIVE", x: 0, y: 422, width: 14, height: 11),
        ],

        // SHUFREP.bmp (Shuffle/Repeat/EQ/Playlist buttons)
        "SHUFREP": [
            // Shuffle button (left side of button pair)
            Sprite(name: "MAIN_SHUFFLE_BUTTON", x: 28, y: 0, width: 47, height: 15),
            Sprite(name: "MAIN_SHUFFLE_BUTTON_DEPRESSED", x: 28, y: 15, width: 47, height: 15),
            Sprite(name: "MAIN_SHUFFLE_BUTTON_SELECTED", x: 28, y: 30, width: 47, height: 15),
            Sprite(name: "MAIN_SHUFFLE_BUTTON_SELECTED_DEPRESSED", x: 28, y: 45, width: 47, height: 15),
            // Repeat button (right side of button pair)
            Sprite(name: "MAIN_REPEAT_BUTTON", x: 0, y: 0, width: 28, height: 15),
            Sprite(name: "MAIN_REPEAT_BUTTON_DEPRESSED", x: 0, y: 15, width: 28, height: 15),
            Sprite(name: "MAIN_REPEAT_BUTTON_SELECTED", x: 0, y: 30, width: 28, height: 15),
            Sprite(name: "MAIN_REPEAT_BUTTON_SELECTED_DEPRESSED", x: 0, y: 45, width: 28, height: 15),
            // EQ/Playlist buttons
            Sprite(name: "MAIN_EQ_BUTTON", x: 0, y: 61, width: 23, height: 12),
            Sprite(name: "MAIN_EQ_BUTTON_SELECTED", x: 0, y: 73, width: 23, height: 12),
            Sprite(name: "MAIN_EQ_BUTTON_DEPRESSED", x: 46, y: 61, width: 23, height: 12),
            Sprite(name: "MAIN_EQ_BUTTON_DEPRESSED_SELECTED", x: 46, y: 73, width: 23, height: 12),
            Sprite(name: "MAIN_PLAYLIST_BUTTON", x: 23, y: 61, width: 23, height: 12),
            Sprite(name: "MAIN_PLAYLIST_BUTTON_SELECTED", x: 23, y: 73, width: 23, height: 12),
            Sprite(name: "MAIN_PLAYLIST_BUTTON_DEPRESSED", x: 69, y: 61, width: 23, height: 12),
            Sprite(name: "MAIN_PLAYLIST_BUTTON_DEPRESSED_SELECTED", x: 69, y: 73, width: 23, height: 12),
        ],

        // EQMAIN.bmp (Equalizer screen)
        "EQMAIN": [
            Sprite(name: "EQ_WINDOW_BACKGROUND", x: 0, y: 0, width: 275, height: 116),
            Sprite(name: "EQ_TITLE_BAR", x: 0, y: 149, width: 275, height: 14),
            Sprite(name: "EQ_TITLE_BAR_SELECTED", x: 0, y: 134, width: 275, height: 14),
            Sprite(name: "EQ_SLIDER_BACKGROUND", x: 13, y: 164, width: 209, height: 129),
            Sprite(name: "EQ_SLIDER_THUMB", x: 0, y: 164, width: 11, height: 11),
            Sprite(name: "EQ_SLIDER_THUMB_SELECTED", x: 0, y: 176, width: 11, height: 11),
            Sprite(name: "EQ_ON_BUTTON", x: 10, y: 119, width: 26, height: 12),
            Sprite(name: "EQ_ON_BUTTON_DEPRESSED", x: 128, y: 119, width: 26, height: 12),
            Sprite(name: "EQ_ON_BUTTON_SELECTED", x: 69, y: 119, width: 26, height: 12),
            Sprite(name: "EQ_ON_BUTTON_SELECTED_DEPRESSED", x: 187, y: 119, width: 26, height: 12),
            Sprite(name: "EQ_AUTO_BUTTON", x: 36, y: 119, width: 32, height: 12),
            Sprite(name: "EQ_AUTO_BUTTON_DEPRESSED", x: 154, y: 119, width: 32, height: 12),
            Sprite(name: "EQ_AUTO_BUTTON_SELECTED", x: 95, y: 119, width: 32, height: 12),
            Sprite(name: "EQ_AUTO_BUTTON_SELECTED_DEPRESSED", x: 213, y: 119, width: 32, height: 12),
            Sprite(name: "EQ_GRAPH_BACKGROUND", x: 0, y: 294, width: 113, height: 19),
            Sprite(name: "EQ_GRAPH_LINE_COLORS", x: 115, y: 294, width: 1, height: 19),
            Sprite(name: "EQ_PRESETS_BUTTON", x: 224, y: 164, width: 44, height: 12),
            Sprite(name: "EQ_PRESETS_BUTTON_SELECTED", x: 224, y: 176, width: 44, height: 12),
            Sprite(name: "EQ_PREAMP_LINE", x: 0, y: 314, width: 113, height: 1),
        ],

        // EQ_EX.bmp (extra EQ sprites)
        "EQ_EX": [
            Sprite(name: "EQ_SHADE_BACKGROUND_SELECTED", x: 0, y: 0, width: 275, height: 14),
            Sprite(name: "EQ_SHADE_BACKGROUND", x: 0, y: 15, width: 275, height: 14),
            Sprite(name: "EQ_SHADE_VOLUME_SLIDER_LEFT", x: 1, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_SHADE_VOLUME_SLIDER_CENTER", x: 4, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_SHADE_VOLUME_SLIDER_RIGHT", x: 7, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_SHADE_BALANCE_SLIDER_LEFT", x: 11, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_SHADE_BALANCE_SLIDER_CENTER", x: 14, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_SHADE_BALANCE_SLIDER_RIGHT", x: 17, y: 30, width: 3, height: 7),
            Sprite(name: "EQ_MAXIMIZE_BUTTON_ACTIVE", x: 1, y: 38, width: 9, height: 9),
            Sprite(name: "EQ_MINIMIZE_BUTTON_ACTIVE", x: 1, y: 47, width: 9, height: 9),
            Sprite(name: "EQ_SHADE_CLOSE_BUTTON", x: 11, y: 38, width: 9, height: 9),
            Sprite(name: "EQ_SHADE_CLOSE_BUTTON_ACTIVE", x: 11, y: 47, width: 9, height: 9),
        ],

        // GEN.bmp (generic window pieces) - 194×109 pixels
        // NOTE: Using top-down Y coordinates (same as Webamp)
        // CENTER_FILL is TWO-PIECE sprite like letters (excludes cyan delimiter)
        "GEN": [
            // Active titlebar (row 1) - Full height sprites (20px)
            Sprite(name: "GEN_TOP_LEFT_SELECTED", x: 0, y: 0, width: 25, height: 20),
            Sprite(name: "GEN_TOP_LEFT_END_SELECTED", x: 26, y: 0, width: 25, height: 20),
            Sprite(name: "GEN_TOP_RIGHT_END_SELECTED", x: 78, y: 0, width: 25, height: 20),
            Sprite(name: "GEN_TOP_LEFT_RIGHT_FILL_SELECTED", x: 104, y: 0, width: 25, height: 20),
            Sprite(name: "GEN_TOP_RIGHT_SELECTED", x: 130, y: 0, width: 25, height: 20),

            // Active titlebar CENTER_FILL (grey section for text)
            Sprite(name: "GEN_TOP_CENTER_FILL_SELECTED", x: 52, y: 0, width: 25, height: 20),

            // Inactive titlebar (row 2) - Full height sprites (20px)
            Sprite(name: "GEN_TOP_LEFT", x: 0, y: 21, width: 25, height: 20),
            Sprite(name: "GEN_TOP_LEFT_END", x: 26, y: 21, width: 25, height: 20),
            Sprite(name: "GEN_TOP_CENTER_FILL", x: 52, y: 21, width: 25, height: 20),
            Sprite(name: "GEN_TOP_RIGHT_END", x: 78, y: 21, width: 25, height: 20),
            Sprite(name: "GEN_TOP_LEFT_RIGHT_FILL", x: 104, y: 21, width: 25, height: 20),
            Sprite(name: "GEN_TOP_RIGHT", x: 130, y: 21, width: 25, height: 20),

            // Bottom sections - Webamp coordinates
            Sprite(name: "GEN_BOTTOM_LEFT", x: 0, y: 42, width: 125, height: 14),
            Sprite(name: "GEN_BOTTOM_RIGHT", x: 0, y: 57, width: 125, height: 14),

            // Bottom fill - TWO PIECES (verified: y=72-84 top + y=87 bottom, no cyan)
            Sprite(name: "GEN_BOTTOM_FILL_TOP", x: 127, y: 72, width: 25, height: 13),
            Sprite(name: "GEN_BOTTOM_FILL_BOTTOM", x: 127, y: 87, width: 25, height: 1),

            // Side walls - Webamp coordinates
            Sprite(name: "GEN_MIDDLE_LEFT", x: 127, y: 42, width: 11, height: 29),
            Sprite(name: "GEN_MIDDLE_LEFT_BOTTOM", x: 158, y: 42, width: 11, height: 24),
            Sprite(name: "GEN_MIDDLE_RIGHT", x: 139, y: 42, width: 8, height: 29),
            Sprite(name: "GEN_MIDDLE_RIGHT_BOTTOM", x: 170, y: 42, width: 8, height: 24),

            // Close button - Webamp coordinates
            Sprite(name: "GEN_CLOSE_SELECTED", x: 148, y: 42, width: 9, height: 9),

            // Letter sprites for titlebar text (GEN.BMP 194×109)
            // CRITICAL: Letters are TWO DISCONTIGUOUS pieces separated by cyan boundaries
            // Selected: TOP Y=88 H=6, BOTTOM Y=95 H=2 (1px cyan gap at Y=94)
            // Normal: TOP Y=96 H=6, BOTTOM Y=108 H=1 (6px cyan gap at Y=102-107)

            // Selected (focused) letter TOPS - Y=88, H=6
            Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 88, width: 8, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_I_TOP", x: 60, y: 88, width: 4, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_L_TOP", x: 80, y: 88, width: 5, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_K_TOP", x: 72, y: 88, width: 7, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_D_TOP", x: 24, y: 88, width: 6, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_R_TOP", x: 124, y: 88, width: 7, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_O_TOP", x: 102, y: 88, width: 6, height: 6),
            Sprite(name: "GEN_TEXT_SELECTED_P_TOP", x: 109, y: 88, width: 6, height: 6),

            // Selected (focused) letter BOTTOMS - Y=95, H=2
            Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 95, width: 8, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_I_BOTTOM", x: 60, y: 95, width: 4, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_L_BOTTOM", x: 80, y: 95, width: 5, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_K_BOTTOM", x: 72, y: 95, width: 7, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_D_BOTTOM", x: 24, y: 95, width: 6, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_R_BOTTOM", x: 124, y: 95, width: 7, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_O_BOTTOM", x: 102, y: 95, width: 6, height: 2),
            Sprite(name: "GEN_TEXT_SELECTED_P_BOTTOM", x: 109, y: 95, width: 6, height: 2),

            // Normal (unfocused) letter TOPS - Y=96, H=6
            Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 6),
            Sprite(name: "GEN_TEXT_I_TOP", x: 60, y: 96, width: 4, height: 6),
            Sprite(name: "GEN_TEXT_L_TOP", x: 80, y: 96, width: 5, height: 6),
            Sprite(name: "GEN_TEXT_K_TOP", x: 72, y: 96, width: 7, height: 6),
            Sprite(name: "GEN_TEXT_D_TOP", x: 24, y: 96, width: 6, height: 6),
            Sprite(name: "GEN_TEXT_R_TOP", x: 124, y: 96, width: 7, height: 6),
            Sprite(name: "GEN_TEXT_O_TOP", x: 102, y: 96, width: 6, height: 6),
            Sprite(name: "GEN_TEXT_P_TOP", x: 109, y: 96, width: 6, height: 6),

            // Normal (unfocused) letter BOTTOMS - Y=108, H=1
            Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 108, width: 8, height: 1),
            Sprite(name: "GEN_TEXT_I_BOTTOM", x: 60, y: 108, width: 4, height: 1),
            Sprite(name: "GEN_TEXT_L_BOTTOM", x: 80, y: 108, width: 5, height: 1),
            Sprite(name: "GEN_TEXT_K_BOTTOM", x: 72, y: 108, width: 7, height: 1),
            Sprite(name: "GEN_TEXT_D_BOTTOM", x: 24, y: 108, width: 6, height: 1),
            Sprite(name: "GEN_TEXT_R_BOTTOM", x: 124, y: 108, width: 7, height: 1),
            Sprite(name: "GEN_TEXT_O_BOTTOM", x: 102, y: 108, width: 6, height: 1),
            Sprite(name: "GEN_TEXT_P_BOTTOM", x: 109, y: 108, width: 6, height: 1),
        ],

        // PLEDIT.bmp (Playlist window chrome/buttons)
        "PLEDIT": [
            // Selected/Focused titlebar (row 1: y=0)
            Sprite(name: "PLAYLIST_TOP_LEFT_SELECTED", x: 0, y: 0, width: 25, height: 20),
            Sprite(name: "PLAYLIST_TITLE_BAR_SELECTED", x: 26, y: 0, width: 100, height: 20),
            Sprite(name: "PLAYLIST_TOP_TILE_SELECTED", x: 127, y: 0, width: 25, height: 20),
            Sprite(name: "PLAYLIST_TOP_RIGHT_CORNER_SELECTED", x: 153, y: 0, width: 25, height: 20),

            // Unselected/Unfocused titlebar (row 2: y=21)
            Sprite(name: "PLAYLIST_TOP_TILE", x: 127, y: 21, width: 25, height: 20),
            Sprite(name: "PLAYLIST_TOP_LEFT_CORNER", x: 0, y: 21, width: 25, height: 20),
            Sprite(name: "PLAYLIST_TITLE_BAR", x: 26, y: 21, width: 100, height: 20),
            Sprite(name: "PLAYLIST_TOP_RIGHT_CORNER", x: 153, y: 21, width: 25, height: 20),
            Sprite(name: "PLAYLIST_LEFT_TILE", x: 0, y: 42, width: 12, height: 29),
            Sprite(name: "PLAYLIST_RIGHT_TILE", x: 31, y: 42, width: 20, height: 29),
            Sprite(name: "PLAYLIST_BOTTOM_TILE", x: 179, y: 0, width: 25, height: 38),
            Sprite(name: "PLAYLIST_BOTTOM_LEFT_CORNER", x: 0, y: 72, width: 125, height: 38),
            Sprite(name: "PLAYLIST_BOTTOM_RIGHT_CORNER", x: 126, y: 72, width: 154, height: 38),
            Sprite(name: "PLAYLIST_SCROLL_HANDLE", x: 52, y: 53, width: 8, height: 18),
            Sprite(name: "PLAYLIST_SCROLL_HANDLE_SELECTED", x: 61, y: 53, width: 8, height: 18),
            Sprite(name: "PLAYLIST_ADD_URL", x: 0, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_ADD_URL_SELECTED", x: 23, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_ADD_DIR", x: 0, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_ADD_DIR_SELECTED", x: 23, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_ADD_FILE", x: 0, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_ADD_FILE_SELECTED", x: 23, y: 149, width: 22, height: 18),

            // REM Menu (4 items - only menu with 4th row)
            Sprite(name: "PLAYLIST_REMOVE_MISC", x: 54, y: 168, width: 22, height: 18),
            Sprite(name: "PLAYLIST_REMOVE_MISC_SELECTED", x: 77, y: 168, width: 22, height: 18),
            Sprite(name: "PLAYLIST_REMOVE_ALL", x: 54, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_REMOVE_ALL_SELECTED", x: 77, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_CROP", x: 54, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_CROP_SELECTED", x: 77, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_REMOVE_SELECTED", x: 54, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_REMOVE_SELECTED_SELECTED", x: 77, y: 149, width: 22, height: 18),

            // SEL Menu (3 items)
            Sprite(name: "PLAYLIST_INVERT_SELECTION", x: 104, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_INVERT_SELECTION_SELECTED", x: 127, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SELECT_ZERO", x: 104, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SELECT_ZERO_SELECTED", x: 127, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SELECT_ALL", x: 104, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SELECT_ALL_SELECTED", x: 127, y: 149, width: 22, height: 18),

            // MISC Menu (3 items)
            Sprite(name: "PLAYLIST_SORT_LIST", x: 154, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SORT_LIST_SELECTED", x: 177, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_FILE_INFO", x: 154, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_FILE_INFO_SELECTED", x: 177, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_MISC_OPTIONS", x: 154, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_MISC_OPTIONS_SELECTED", x: 177, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_NEW_LIST", x: 204, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_NEW_LIST_SELECTED", x: 227, y: 111, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SAVE_LIST", x: 204, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_SAVE_LIST_SELECTED", x: 227, y: 130, width: 22, height: 18),
            Sprite(name: "PLAYLIST_LOAD_LIST", x: 204, y: 149, width: 22, height: 18),
            Sprite(name: "PLAYLIST_LOAD_LIST_SELECTED", x: 227, y: 149, width: 22, height: 18),

            // Transport control buttons (tiny gold buttons in info bar) - 6 buttons total
            // Located in dark horizontal bar of PLEDIT.BMP sprite sheet (Y:62 normal, Y:72 active)
            Sprite(name: "PLAYLIST_PREV_BUTTON", x: 136, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_PREV_BUTTON_ACTIVE", x: 136, y: 72, width: 10, height: 9),
            Sprite(name: "PLAYLIST_PLAY_BUTTON", x: 147, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_PLAY_BUTTON_ACTIVE", x: 147, y: 72, width: 10, height: 9),
            Sprite(name: "PLAYLIST_PAUSE_BUTTON", x: 158, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_PAUSE_BUTTON_ACTIVE", x: 158, y: 72, width: 10, height: 9),
            Sprite(name: "PLAYLIST_STOP_BUTTON", x: 169, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_STOP_BUTTON_ACTIVE", x: 169, y: 72, width: 10, height: 9),
            Sprite(name: "PLAYLIST_NEXT_BUTTON", x: 180, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_NEXT_BUTTON_ACTIVE", x: 180, y: 72, width: 10, height: 9),
            Sprite(name: "PLAYLIST_EJECT_BUTTON", x: 191, y: 62, width: 10, height: 9),
            Sprite(name: "PLAYLIST_EJECT_BUTTON_ACTIVE", x: 191, y: 72, width: 10, height: 9),
        ],

        // TEXT.bmp (font characters) – indices computed dynamically similar to Webamp
        "TEXT": SkinSprites.generateTextSprites(),

        // VIDEO.bmp (Video window chrome)
        "VIDEO": [
            // Titlebar active (row 1: y=0-19)
            Sprite(name: "VIDEO_TITLEBAR_TOP_LEFT_ACTIVE", x: 0, y: 0, width: 25, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_TOP_CENTER_ACTIVE", x: 26, y: 0, width: 100, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_STRETCHY_ACTIVE", x: 127, y: 0, width: 25, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_TOP_RIGHT_ACTIVE", x: 153, y: 0, width: 25, height: 20),

            // Titlebar inactive (row 2: y=21-40)
            Sprite(name: "VIDEO_TITLEBAR_TOP_LEFT_INACTIVE", x: 0, y: 21, width: 25, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_TOP_CENTER_INACTIVE", x: 26, y: 21, width: 100, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_STRETCHY_INACTIVE", x: 127, y: 21, width: 25, height: 20),
            Sprite(name: "VIDEO_TITLEBAR_TOP_RIGHT_INACTIVE", x: 153, y: 21, width: 25, height: 20),

            // Side borders (vertical tiles)
            Sprite(name: "VIDEO_BORDER_LEFT", x: 127, y: 42, width: 11, height: 29),
            Sprite(name: "VIDEO_BORDER_RIGHT", x: 139, y: 42, width: 8, height: 29),

            // Bottom bar (row 3-4: y=42-119)
            // Row 3: Left corner with buttons (x=0-124)
            Sprite(name: "VIDEO_BOTTOM_LEFT", x: 0, y: 42, width: 125, height: 38),
            // Row 4: Right corner with resize + tile for stretching (x=0-124 is right corner, x=127+ is tile)
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
            Sprite(name: "VIDEO_MISC_BUTTON_PRESSED", x: 218, y: 42, width: 15, height: 18),
        ]
    ])
}

extension SkinSprites {
    private static let fontLookup: [Character: (Int, Int)] = {
        var map: [Character: (Int, Int)] = [:]
        func set(_ ch: Character, _ r: Int, _ c: Int) { map[ch] = (r, c) }
        let row0 = "abcdefghijklmnopqrstuvwxyz\"@ "
        for (i, ch) in row0.enumerated() { set(ch, 0, i) }
        let row1 = "0123456789….:()-'!_+\\/[]^&%,=$#"
        for (i, ch) in row1.enumerated() { set(ch, 1, i) }
        let row2: [(Character, Int)] = [("Å",0),("Ö",1),("Ä",2),("?",3),("*",4)]
        for (ch, col) in row2 { set(ch, 2, col) }
        return map
    }()

    static func generateTextSprites() -> [Sprite] {
        let charW = 5
        let charH = 6
        var sprites: [Sprite] = []
        for (ch, pos) in fontLookup {
            let (r, c) = pos
            let name = "CHARACTER_\(String(ch).utf16.first ?? 0)"
            sprites.append(Sprite(name: name, x: c * charW, y: r * charH, width: charW, height: charH))
        }
        return sprites
    }
}
