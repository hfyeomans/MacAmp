# Milkdrop Window Retry - Research

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04
**Objective:** Restore MILKDROP lettering to the Milkdrop window titlebar using two-piece sprite extraction

---

## Executive Summary

The Milkdrop window chrome exists and renders correctly, but the "MILKDROP" text in the titlebar is missing. The letters must be extracted from GEN.bmp as two-piece sprites (TOP + BOTTOM) and stacked vertically. This was previously attempted but the lettering was not fully implemented.

---

## Files to Review for Re-attempt

### Primary Implementation Files

| File | Path | Purpose |
|------|------|---------|
| **MilkdropWindowChromeView.swift** | `MacAmpApp/Views/Windows/` | Chrome rendering - ADD letter sprites here |
| **SkinSprites.swift** | `MacAmpApp/Skins/` | Sprite definitions - GEN letter coords (lines 215-292) |
| **WinampMilkdropWindow.swift** | `MacAmpApp/Views/` | Root SwiftUI view |
| **WinampMilkdropWindowController.swift** | `MacAmpApp/Windows/` | NSWindowController setup |

### Reference Files

| File | Path | Purpose |
|------|------|---------|
| **BUILDING_RETRO_MACOS_APPS_SKILL.md** | Project root | Pattern 1: Two-Piece Sprite Extraction |
| **docs/MILKDROP_WINDOW.md** | `docs/` | Full Milkdrop window specification |
| **docs/SPRITE_SYSTEM_COMPLETE.md** | `docs/` | Sprite resolution system |
| **tasks/milkdrop-gen-sprites/** | `tasks/` | Coordinate flip research |
| **tasks/milkdrop-titlebar/** | `tasks/` | Titlebar gap fix |

### Webamp Reference (for pixel-scanning algorithm)

| File | Purpose |
|------|---------|
| `webamp_clone/js/skinParser.js` | `genGenTextSprites()` function for dynamic letter detection |
| `webamp_clone/js/skinParserUtils.ts` | Coordinate system documentation |

---

## Current State Analysis

### What Exists (Active in Codebase)

The Milkdrop window was implemented in commit `744d5ec` (Nov 15, 2025) and is **NOT reverted**:

```
MacAmpApp/Views/WinampMilkdropWindow.swift           # Root view - ACTIVE
MacAmpApp/Windows/WinampMilkdropWindowController.swift  # Controller - ACTIVE
MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift  # Chrome - ACTIVE
```

**Window Features Working:**
- GEN.bmp chrome rendering (titlebar, borders, bottom bar)
- Active/inactive focus states
- Magnetic docking integration
- Window visibility toggle (View menu)
- Position persistence

**What's Missing:**
- "MILKDROP" text in center titlebar section
- Letters need two-piece extraction (TOP + BOTTOM)

### Sprite Definitions in SkinSprites.swift

**Currently defined GEN letter sprites (lines ~250-292):**

```swift
// Selected state letters (16 sprites: 8 letters × 2 pieces)
GEN_TEXT_SELECTED_M_TOP, GEN_TEXT_SELECTED_M_BOTTOM
GEN_TEXT_SELECTED_I_TOP, GEN_TEXT_SELECTED_I_BOTTOM
GEN_TEXT_SELECTED_L_TOP, GEN_TEXT_SELECTED_L_BOTTOM
GEN_TEXT_SELECTED_K_TOP, GEN_TEXT_SELECTED_K_BOTTOM
GEN_TEXT_SELECTED_D_TOP, GEN_TEXT_SELECTED_D_BOTTOM
GEN_TEXT_SELECTED_R_TOP, GEN_TEXT_SELECTED_R_BOTTOM
GEN_TEXT_SELECTED_O_TOP, GEN_TEXT_SELECTED_O_BOTTOM
GEN_TEXT_SELECTED_P_TOP, GEN_TEXT_SELECTED_P_BOTTOM

// Unselected state letters (16 sprites: 8 letters × 2 pieces)
GEN_TEXT_M_TOP, GEN_TEXT_M_BOTTOM
GEN_TEXT_I_TOP, GEN_TEXT_I_BOTTOM
// ... etc for L, K, D, R, O, P
```

**Total: 32 letter sprites (8 letters × 2 pieces × 2 states)**

---

## Two-Piece Sprite Pattern (Critical)

### Discovery from Part 21 Development

GEN.bmp letters are **TWO SEPARATE SPRITES** stacked vertically:
- **Top portion:** 4-6 pixels (main letter body)
- **Cyan delimiter:** 1 pixel (#00C6FF) - NOT part of sprite
- **Bottom portion:** 1-3 pixels (serifs/feet)

### Verification Method (ImageMagick)

```bash
# Extract different Y positions to find correct coordinates
magick /tmp/GEN.png -crop 8x7+86+86 /tmp/M_Y86.png  # Complete (correct)
magick /tmp/GEN.png -crop 8x7+86+88 /tmp/M_Y88.png  # Top cut off (wrong)

# Two-piece extraction (correct approach):
magick /tmp/GEN.png -crop 8x6+86+88 /tmp/M_top.png     # Top 6px
magick /tmp/GEN.png -crop 8x2+86+95 /tmp/M_bottom.png  # Bottom 2px
magick /tmp/M_top.png /tmp/M_bottom.png -append /tmp/M_complete.png
```

### Implementation Pattern

```swift
// SkinSprites.swift - Define both pieces (32 sprites: 8 letters × 2 pieces × 2 states)
Sprite(name: "GEN_TEXT_SELECTED_M_TOP", x: 86, y: 88, width: 8, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM", x: 86, y: 95, width: 8, height: 2),
Sprite(name: "GEN_TEXT_M_TOP", x: 86, y: 96, width: 8, height: 6),
Sprite(name: "GEN_TEXT_M_BOTTOM", x: 86, y: 108, width: 8, height: 1),

// MilkdropWindowChromeView.swift - Stack pieces vertically
@ViewBuilder
func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 6)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: isActive ? 2 : 1)
    }
}
```

### Key Insight

**Never trust documentation blindly.** Always verify sprite coordinates with actual bitmap extraction using ImageMagick before updating code.

---

## Coordinate System Issue

### Problem (from milkdrop-gen-sprites task)

Webamp uses HTML canvas coordinates (top-down, origin at top-left, +Y downward).
macOS CGImage uses bottom-up coordinates (origin at bottom-left, +Y upward).

**SkinSprites.swift may be using Webamp's top-down coordinates directly without flipping.**

### Flip Formula

```
flippedY = imageHeight - spriteHeight - documentedY
```

For GEN.bmp (194×109 pixels):
```
flippedY = 109 - height - y
```

### Example Conversion

| Sprite | Webamp Y | Height | Flipped Y |
|--------|----------|--------|-----------|
| M_TOP | 88 | 6 | 109 - 6 - 88 = 15 |
| M_BOTTOM | 95 | 2 | 109 - 2 - 95 = 12 |

**Action Required:** Verify if SkinSprites.swift already applies this flip or if we need to add it.

---

## GEN.bmp Letter Positions

### Documented Letter Widths (from Webamp)

| Letter | Width | Notes |
|--------|-------|-------|
| M | 8px | Widest letter |
| I | 5px | Narrowest |
| L | 6px | |
| K | 7px | |
| D | 7px | |
| R | 7px | |
| O | 7px | |
| P | 7px | |

**Total text width:** 8+5+6+7+7+7+7+7 = **54px**

### Letter X Positions (approximate)

Starting X for center section: ~100px (after left cap + fills)
Letter spacing: 0-1px between letters

| Letter | X Position |
|--------|------------|
| M | 100 |
| I | 109 |
| L | 115 |
| K | 122 |
| D | 130 |
| R | 138 |
| O | 146 |
| P | 154 |

**Note:** These positions may vary by skin. Consider using semantic sprite resolution.

---

## Titlebar Layout Reference

### 6-Section Composition (275px total)

```
Section 1: LEFT cap (25px)         - x: 0-25
Section 2: LEFT_RIGHT_FILL (50px)  - x: 25-75 (2 tiles @ 25px)
Section 3: LEFT_END (25px)         - x: 75-100
Section 4: CENTER_FILL (75px)      - x: 100-175 (3 tiles @ 25px) ← LETTERS GO HERE
Section 5: RIGHT_END (25px)        - x: 175-200
Section 6: RIGHT_FILL (50px)       - x: 200-250 (2 tiles @ 25px)
Section 7: RIGHT cap (25px)        - x: 250-275
```

### Letter Placement in Center Section

The CENTER_FILL section (x: 100-175, width: 75px) contains the "MILKDROP" text.
Total text width: 54px
Centering offset: (75 - 54) / 2 = 10.5px
**Letters start at x: 110.5** (relative to window)

---

## Previous Issues Encountered

### 1. Butterchurn Visualization Blockers

**Issue:** WKWebView loading test.html silently failed
**Root Cause:** test.html not included in Xcode bundle resources
**Fix Applied:** Added test.html to MacAmpApp/Resources/Butterchurn and PBXResourcesBuildPhase
**Current Status:** Resource bundled, but visualization engine not connected

**Remaining Butterchurn Work (Deferred):**
- WKWebView ↔ Swift bridge for audio data
- Real-time preset rendering
- Audio spectrum analysis passthrough

### 2. Coordinate Flip Issue

**Issue:** Sprites rendered from wrong region of bitmap
**Root Cause:** Webamp coords are top-down, CGImage is bottom-up
**Status:** Research complete (milkdrop-gen-sprites task), awaiting implementation

### 3. Titlebar Gap Issue

**Issue:** 25px gap in titlebar coverage (only 250px vs 275px needed)
**Root Cause:** Insufficient center tiles
**Fix Applied:** 5 center + 2 stretch tiles with recalculated positions
**Status:** FIXED (milkdrop-titlebar task)

### 4. Dynamic Text Extraction (Complex)

**Issue:** Letter X positions vary by skin
**Solution Required:** Pixel-scanning algorithm from webamp (genGenTextSprites)
**Status:** DEFERRED - Using hardcoded positions for base skin initially

---

## Reference Implementation: makeLetter Helper

From BUILDING_RETRO_MACOS_APPS_SKILL.md:

```swift
@ViewBuilder
func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: 6)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: isActive ? 2 : 1)
    }
}
```

### Usage in Titlebar

```swift
// In center section of titlebar
HStack(spacing: 0) {
    makeLetter("M", width: 8, isActive: isWindowActive)
    makeLetter("I", width: 5, isActive: isWindowActive)
    makeLetter("L", width: 6, isActive: isWindowActive)
    makeLetter("K", width: 7, isActive: isWindowActive)
    makeLetter("D", width: 7, isActive: isWindowActive)
    makeLetter("R", width: 7, isActive: isWindowActive)
    makeLetter("O", width: 7, isActive: isWindowActive)
    makeLetter("P", width: 7, isActive: isWindowActive)
}
.position(x: 137.5, y: 10) // Centered in 275px titlebar
```

---

## Checklist from Part 21 Patterns

When implementing the lettering:

- [ ] Verify sprite coordinates with ImageMagick extraction
- [ ] Check for two-piece sprites (TOP + BOTTOM with cyan delimiter)
- [ ] Confirm coordinate flip applied (if needed)
- [ ] Use VStack(spacing: 0) to stack pieces
- [ ] Handle active/inactive states (different sprite prefixes)
- [ ] Test with multiple skins
- [ ] Thread Sanitizer clean build
- [ ] Oracle validation before merge

---

## Related Tasks

| Task | Status | Relevance |
|------|--------|-----------|
| milkdrop-gen-sprites | Completed/Awaiting | Coordinate flip formula |
| milkdrop-titlebar | Completed | Tile coverage fix |
| milkdrop-rendering-bug | Completed | test.html bundling |
| milkdrop-chrome-alignment | Unknown | May have related fixes |
| milkdrop-window-layout | Unknown | Layout calculations |
| milkdrop-window-precision-fixes | Unknown | Precision adjustments |

---

## Success Criteria

1. "MILKDROP" text renders in center titlebar section
2. Letters use two-piece sprites (TOP + BOTTOM)
3. Active/inactive states show correct sprite variants
4. Text is properly centered (x: ~110.5 from window left)
5. No gaps or overlaps between letters
6. Works with base Winamp skin
7. Graceful fallback if letter sprites missing

---

## Next Steps

1. Verify current sprite definitions in SkinSprites.swift
2. Check if coordinate flip is already applied
3. Extract letter sprites from GEN.bmp with ImageMagick to verify coordinates
4. Implement makeLetter helper in MilkdropWindowChromeView.swift
5. Add letter HStack to center titlebar section
6. Test with base skin
7. Verify active/inactive state switching
