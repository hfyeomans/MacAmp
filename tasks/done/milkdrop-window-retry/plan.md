# Milkdrop Window Retry - Implementation Plan

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04
**Objective:** Restore MILKDROP lettering to titlebar using two-piece sprite extraction

---

## Overview

The Milkdrop window chrome is fully functional, but the "MILKDROP" text in the center titlebar section is missing. Each letter must be rendered as two vertically-stacked sprites (TOP + BOTTOM pieces) to match the GEN.bmp format.

---

## Phase 1: Coordinate Verification

### Step 1.1: Extract GEN.bmp from Base Skin

```bash
# Extract base skin to temp directory
unzip -o ~/path/to/base.wsz -d /tmp/base-skin/
# or use existing skin in app resources

# Get GEN.bmp dimensions
sips -g pixelHeight -g pixelWidth /tmp/base-skin/GEN.bmp
# Expected: 194×109 pixels
```

### Step 1.2: Verify Letter Coordinates with ImageMagick

```bash
# Convert BMP to PNG for ImageMagick
magick /tmp/base-skin/GEN.bmp /tmp/GEN.png

# Test M letter extraction at documented coordinates
magick /tmp/GEN.png -crop 8x6+86+88 /tmp/M_TOP_test.png
magick /tmp/GEN.png -crop 8x2+86+95 /tmp/M_BOTTOM_test.png

# Visually verify the extracted pieces are correct
open /tmp/M_TOP_test.png /tmp/M_BOTTOM_test.png
```

### Step 1.3: Compare with SkinSprites.swift

Read current definitions in `MacAmpApp/Skins/SkinSprites.swift` (lines 250-292).
Confirm coordinates match the verified extractions.
If not, document the correct coordinates.

---

## Phase 2: Implement Letter Rendering

### Step 2.1: Add makeLetter Helper to MilkdropWindowChromeView.swift

```swift
// Add to MilkdropWindowChromeView struct

/// Renders a single GEN letter as two stacked sprites (TOP + BOTTOM)
@ViewBuilder
private func makeLetter(_ letter: String, width: CGFloat, isActive: Bool) -> some View {
    let prefix = isActive ? "GEN_TEXT_SELECTED_" : "GEN_TEXT_"
    let topHeight: CGFloat = 6
    let bottomHeight: CGFloat = isActive ? 2 : 1

    VStack(spacing: 0) {
        SimpleSpriteImage("\(prefix)\(letter)_TOP", width: width, height: topHeight)
        SimpleSpriteImage("\(prefix)\(letter)_BOTTOM", width: width, height: bottomHeight)
    }
}
```

### Step 2.2: Add Letter HStack to Titlebar

```swift
// In the titlebar section, add to center area

private var milkdropLetters: some View {
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
}
```

### Step 2.3: Position Letters in Titlebar

Calculate center position:
- Titlebar width: 275px
- Center section: x 100-175 (75px wide)
- Text width: 54px
- Center X: 137.5 (center of titlebar)

```swift
// In titlebar ZStack
milkdropLetters
    .position(x: 137.5, y: 10) // Vertically centered in 20px titlebar
```

---

## Phase 3: Coordinate Fix (If Needed)

### Step 3.1: Apply Y-Flip if Required

If verification shows coordinates are wrong, update SkinSprites.swift:

```swift
// Formula: flippedY = 109 - height - documentedY

// Example for M letter (selected)
Sprite(name: "GEN_TEXT_SELECTED_M_TOP",
       x: 86,
       y: 109 - 6 - 88,  // = 15 (flipped from 88)
       width: 8,
       height: 6),
Sprite(name: "GEN_TEXT_SELECTED_M_BOTTOM",
       x: 86,
       y: 109 - 2 - 95,  // = 12 (flipped from 95)
       width: 8,
       height: 2),
```

### Step 3.2: Alternative - Flip in SimpleSpriteImage

If many sprites need flipping, consider adding flip logic to SimpleSpriteImage:

```swift
// In SimpleSpriteImage or SkinManager
func sprite(named: String, flipY: Bool = false) -> NSImage? {
    guard var image = skin.images[named] else { return nil }
    if flipY {
        image = image.flippedVertically()
    }
    return image
}
```

---

## Phase 4: Testing

### Step 4.1: Visual Verification

1. Build and run with Thread Sanitizer enabled
2. Open Milkdrop window (View → Show Milkdrop)
3. Verify "MILKDROP" text appears in titlebar
4. Click another window - verify inactive state (dimmer text)
5. Click Milkdrop window - verify active state (brighter text)

### Step 4.2: Multi-Skin Testing

Test with 3-5 different Winamp skins:
- Base Winamp skin (primary)
- A dark theme skin
- A light theme skin
- A skin with custom GEN.bmp
- A skin WITHOUT GEN.bmp (verify fallback)

### Step 4.3: Edge Cases

- [ ] Window starts inactive (first open)
- [ ] Rapid focus switching
- [ ] Double-size mode (if applicable)
- [ ] Skin hot-swap while window open

---

## Phase 5: Code Review & Merge

### Step 5.1: Oracle Validation

```bash
codex "@MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift
       @MacAmpApp/Skins/SkinSprites.swift
       Review the MILKDROP letter implementation for:
       - Two-piece sprite pattern correctness
       - Active/inactive state handling
       - Coordinate accuracy
       - Memory management"
```

### Step 5.2: Commit & PR

```bash
git checkout -b feature/milkdrop-titlebar-letters
git add MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift
git add MacAmpApp/Skins/SkinSprites.swift  # If modified
git commit -m "feat: Add MILKDROP titlebar letters with two-piece sprites"
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift` | Add makeLetter helper, milkdropLetters computed property, position in titlebar |
| `MacAmpApp/Skins/SkinSprites.swift` | Fix coordinates if verification fails |

---

## Success Criteria

1. ✅ "MILKDROP" text visible in center titlebar
2. ✅ Letters use two-piece sprites (TOP + BOTTOM stacked)
3. ✅ Active state shows GEN_TEXT_SELECTED_* sprites
4. ✅ Inactive state shows GEN_TEXT_* sprites
5. ✅ Text properly centered (x: 137.5)
6. ✅ No gaps between letters (spacing: 0)
7. ✅ Thread Sanitizer clean
8. ✅ Works with base Winamp skin
9. ✅ Graceful handling if sprites missing

---

## Rollback Plan

If issues arise:
1. Revert MilkdropWindowChromeView.swift changes
2. Letters simply won't render (window still functional)
3. No risk to other windows or audio playback

---

## Time Estimate

- Phase 1 (Verification): 30 minutes
- Phase 2 (Implementation): 1 hour
- Phase 3 (Coord Fix): 30 minutes (if needed)
- Phase 4 (Testing): 30 minutes
- Phase 5 (Review/Merge): 30 minutes

**Total: 2-3 hours**
