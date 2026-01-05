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

---

## Gap Analysis: SwiftUI vs CSS Flexbox (2026-01-04)

### The Gap Problem

**MacAmp (current):** 13px gap on each side of MILKDROP text
**Webamp:** 3-4px gap on each side of MILKDROP text

### How Webamp Achieves Tighter Gaps

Webamp uses CSS flexbox with `flex-grow: 1` on gold fill sections:

```css
.gen-top-left-fill {
  flex-grow: 1;
  height: 20px;
  background-position: left;  /* Tiles from left edge */
}

.gen-top-right-fill {
  flex-grow: 1;
  height: 20px;
  background-position: right;  /* Tiles from right edge */
}

.gen-top-title {
  padding: 0 3px 0 4px;  /* Only 7px total around text */
}
```

**Key features:**
1. Gold fills expand to consume ALL remaining space
2. Title section is intrinsic width (text + 7px padding)
3. CSS `background-repeat` tiles automatically
4. `background-position` aligns tiles to outer edges

**Webamp layout (275px):**
- Fixed sections: 25 + 25 + 25 + 25 = 100px (corners + ends)
- Text + padding: 49 + 7 = 56px
- Gold fills: (275 - 100 - 56) / 2 = **59.5px each** (flex)

### Why SwiftUI Can't Match This Exactly

**SwiftUI Limitations:**

1. **No native `background-position: right`**
   - SwiftUI's `.resizable(resizingMode: .tile)` always tiles from top-left
   - CSS can align tiles to right edge; SwiftUI cannot natively
   - Would need custom drawing to mask/clip tiles from right edge

2. **No intrinsic width for sprite-based content**
   - CSS flexbox auto-sizes `.gen-top-title` to content width
   - SwiftUI requires explicit frame widths for sprites

3. **Integer pixel preference**
   - SwiftUI prefers integer pixels for crisp rendering
   - 59.5px gold fills would round to 59 or 60px
   - Sub-pixel CSS rendering allows exact 59.5px

4. **Discrete tile constraint**
   - Our sprites are 25px tiles from GEN.bmp
   - Stretching distorts pixel art
   - Tiling requires clipping partial tiles

### Possible SwiftUI Solutions (Complexity Analysis)

**Option A: Custom Tiling View with Alignment**
```swift
struct AlignedTilingSprite: View {
    let spriteName: String
    let alignment: Alignment  // .leading or .trailing

    var body: some View {
        GeometryReader { geo in
            let tileCount = Int(ceil(geo.size.width / 25))
            HStack(spacing: 0) {
                ForEach(0..<tileCount, id: \.self) { _ in
                    SimpleSpriteImage(spriteName, width: 25, height: 20)
                }
            }
            .frame(width: CGFloat(tileCount) * 25, alignment: alignment)
            .frame(width: geo.size.width)
            .clipped()
        }
    }
}
```
**Complexity:** Medium. Achieves tiling but may have sub-pixel alignment issues.

**Option B: Flex-like HStack Layout**
```swift
HStack(spacing: 0) {
    SimpleSpriteImage("GEN_TOP_LEFT")  // 25px
    AlignedTilingSprite("GEN_TOP_FILL", alignment: .leading)
        .frame(maxWidth: .infinity)
    SimpleSpriteImage("GEN_TOP_LEFT_END")  // 25px
    milkdropLetters.padding(.horizontal, 4)  // ~57px
    SimpleSpriteImage("GEN_TOP_RIGHT_END")  // 25px
    AlignedTilingSprite("GEN_TOP_FILL", alignment: .trailing)
        .frame(maxWidth: .infinity)
    SimpleSpriteImage("GEN_TOP_RIGHT")  // 25px
}
```
**Complexity:** High. Requires rewriting titlebar layout, testing edge cases.

**Option C: Accept 13px Gap (Current)**
- Uses discrete 25px tiles (3 center, 2 gold each side)
- Historically accurate (original Win32 Winamp likely used similar approach)
- Simple, maintainable, pixel-perfect

### Gemini Research Findings (2026-01-04)

From Winamp skin SDK research:

1. **Original Winamp used tiling**, not fixed tiles
2. Gold fills were flexible, expanding to fit window width
3. Text section sized to content, not fixed width
4. The 7 titlebar sections: corner, fill, end, title, end, fill, corner

**Key quote from research:**
> "The 'Gold Fill' Logic: The space between the Corners and the Text Box is filled by tiling the Top Left/Right Fill sprite (104,0)."

This confirms Webamp's approach matches original Winamp. MacAmp's discrete-tile approach is a simplification.

### Recommendation

**For now:** Keep the 13px gap (current implementation)

**Rationale:**
1. Implementation complexity vs visual benefit tradeoff
2. 13px gap is visually acceptable
3. Original Win32 API likely had similar constraints to SwiftUI
4. Focus on other features; revisit if users complain

**Future enhancement (if desired):**
Create `AlignedTilingSprite` component and flex-like HStack layout as described in Option B. This would reduce gaps to ~4px matching Webamp.

### Technical Debt Tracking

If we decide to implement tighter gaps later, the approach is:
1. Create `AlignedTilingSprite` view with left/right alignment
2. Replace fixed-position titlebar with HStack layout
3. Use `.frame(maxWidth: .infinity)` for gold fill spacers
4. Test with various window widths and skins

---

## Complete Webamp CSS Reference (gen-window.css)

For future reference, here is the complete relevant CSS from webamp:

```css
#webamp .gen-window {
  width: 275px;
  height: 116px;
  display: flex;
  flex-direction: column;
}

#webamp .gen-top {
  height: 20px;
  display: flex;
  flex-direction: row;
}

#webamp .gen-top-left {
  width: 25px;
  height: 20px;
}

#webamp .gen-top-title {
  line-height: 7px;
  margin-top: 2px;
  /* TODO: This should be a consequence of the repeating tiles, not hard coded */
  padding: 0 3px 0 4px;
}

#webamp .gen-top-left-fill {
  flex-grow: 1;
  height: 20px;
  background-position: left;
}

#webamp .gen-top-right-fill {
  flex-grow: 1;
  height: 20px;
  background-position: right;
}

#webamp .gen-top-left-end {
  width: 25px;
  height: 20px;
}

#webamp .gen-top-right {
  width: 25px;
  height: 20px;
}

#webamp .gen-top-right-end {
  width: 25px;
  height: 20px;
}

#webamp .gen-text-letter {
  height: 7px;
  display: inline-block;
}

#webamp .gen-text-space {
  width: 5px;
}
```

**Note the critical `background-position` property:**
- `left` - tiles start from left edge, overflow clips on right
- `right` - tiles start from right edge, overflow clips on left

This allows symmetrical appearance even with non-integer tile counts.

---

## SimpleSpriteImage Current Implementation

The current `SimpleSpriteImage` component uses `.resizable()` with `.aspectRatio(contentMode: .fill)`:

```swift
Image(nsImage: image)
    .interpolation(.none)
    .antialiased(false)
    .resizable()  // Force image to fill frame completely
    .aspectRatio(contentMode: .fill)  // Fill frame, ignore aspect ratio
    .frame(width: width, height: height)
    .clipped()  // Clip overflow from .fill mode
```

This **stretches** sprites to fit, which works for fixed-size sprites but would distort pixel art if used for flexible widths.

**To tile instead of stretch:**
```swift
Image(nsImage: image)
    .resizable(resizingMode: .tile)  // Tile instead of stretch
    .frame(width: flexibleWidth, height: 20)
```

However, SwiftUI's `.tile` mode has no alignment option - it always tiles from top-left origin.

---

## GEN.BMP Sprite Coordinates (from Gemini Research)

**Titlebar Structure (Top 20px):**

| Section | Selected (y=0) | Inactive (y=21) | Width | Behavior |
|---------|----------------|-----------------|-------|----------|
| Top Left Corner | 0,0 | 0,21 | 25px | Fixed |
| Left/Right Fill | 104,0 | 104,21 | 25px | Tiles |
| Title Start Cap | 26,0 | 26,21 | 25px | Fixed |
| Title Center Fill | 52,0 | 52,21 | 25px | Tiles |
| Title End Cap | 78,0 | 78,21 | 25px | Fixed |
| Top Right Corner | 130,0 | 130,21 | 25px | Fixed |

**Letter Extraction:**
- Selected text: Scanned from y=88 (Height: 7px)
- Normal text: Scanned from y=96 (Height: 7px)
- Delimiter: First pixel at x=0 of text row (typically cyan #00FFFF)

**MacAmp's Two-Piece Approach:**
Due to cyan gap line at y=94, MacAmp splits letters:
- TOP piece: 6px height (y=88 to y=93)
- BOTTOM piece: 1-2px height (y=95 to y=96/97)

This avoids rendering the cyan delimiter line.

---

## Summary of Gap Limitation

| Aspect | Webamp (CSS) | MacAmp (SwiftUI) | Difference |
|--------|--------------|------------------|------------|
| Layout model | Flexbox | Fixed position | Fundamental |
| Gold fill sizing | `flex-grow: 1` | 2 × 25px tiles | 50px vs ~60px |
| Center section | Intrinsic (56px) | 3 × 25px tiles (75px) | 19px larger |
| Gap around text | 3-4px | 13px | ~10px larger |
| Tile alignment | `background-position` | None (origin only) | Can't match |
| Sub-pixel | Supported | Integer preferred | Minor |

**Conclusion:** The 13px gap is a consequence of SwiftUI's layout model and our discrete-tile approach. Matching Webamp exactly would require significant refactoring with custom tiling components. The current implementation is acceptable and historically plausible for Win32-era Winamp.

---

## Alternative Approach: Longer Text for Tighter Gaps (2026-01-04)

### The Insight

Instead of complex SwiftUI tiling, we can reduce gaps by using **longer text** that better fills the center section. The optimal text width for 3 center tiles (75px) is ~63-67px, leaving only 4-6px gaps.

### Mathematical Analysis

**Current:** MILKDROP = 49px in 75px center = 13px gaps each side
**Optimal:** ~67px text in 75px center = 4px gaps each side

**The 25px tile constraint creates discrete options:**

| Config | Left Gold | Center | Right Gold | Optimal Text Width |
|--------|-----------|--------|------------|-------------------|
| 2+3+2 | 50px | 75px | 50px | 63-67px |
| 1+5+1 | 25px | 125px | 25px | 113-117px |

### Text Length Options Analyzed

| Text | Width | Gap Each Side | Notes |
|------|-------|---------------|-------|
| MILKDROP | 49px | 13px | Current |
| MILKDROP 2 | ~60px | 7.5px | Simple, only need "2" sprite |
| MILKDROP V2 | ~67px | 4px | Optimal fit |
| MILKDROP 2K | ~67px | 4px | Optimal fit |
| **MILKDROP HD** | ~67px | **4px** | **Chosen - optimal fit** |
| MILKDROP VIS | ~71px | 2px | Very tight |
| MILKDROP PRO | ~73px | 1px | Too tight |
| MILKDROP VIDEO | 83px | 21px | Requires 5 center tiles |

### Why "MILKDROP HD" Was Chosen

1. **Optimal width:** ~67px fills 75px center with minimal gaps
2. **Meaningful:** "HD" suggests high-definition visuals
3. **Sprite efficiency:** D already exists; only need H sprite
4. **No layout changes:** Still uses 2+3+2 tile configuration

### Implementation Requirements for "MILKDROP HD"

**New sprites needed (8 total):**
- `GEN_TEXT_SELECTED_H_TOP` (x: TBD, y: 88, w: ~7, h: 6)
- `GEN_TEXT_SELECTED_H_BOTTOM` (x: TBD, y: 95, w: ~7, h: 2)
- `GEN_TEXT_H_TOP` (x: TBD, y: 96, w: ~7, h: 6)
- `GEN_TEXT_H_BOTTOM` (x: TBD, y: 103, w: ~7, h: 1)
- Space handling (5px gap, no sprite needed)

**D sprites already exist** (reused from MILKDROP).

### Letter Width Verification

Need to extract H from GEN.bmp to confirm width:
- Expected: ~7px (similar to K, R)
- Position: 8th letter in alphabet (after G)

### Expected Result

```
Before (MILKDROP):
[CAP][GOLD][GOLD][END][---MILKDROP---][END][GOLD][GOLD][CAP]
                      |--49px--|
                      |----75px----|
                         13px gaps

After (MILKDROP HD):
[CAP][GOLD][GOLD][END][-MILKDROP HD-][END][GOLD][GOLD][CAP]
                      |----~67px----|
                      |----75px----|
                          4px gaps
```

### Rollback Plan

Committed current MILKDROP implementation before adding HD. If visual result is unsatisfactory:
```bash
git revert HEAD  # or git checkout HEAD~1 -- MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift
```

---

## H Letter Sprite Debugging (2026-01-04)

### Problem Description

When implementing "MILKDROP HD", the H letter has rendering issues:

**Attempt 1: x=52, width=7**
- Result: Green (cyan) 1px vertical line on LEFT of H
- H appeared lighter/brighter than other letters
- Diagnosis: Starting 1px too early, including G-H delimiter

**Attempt 2: x=53, width=7**
- Result: Green 1px vertical line on RIGHT of H
- H still brighter than other letters
- H touching D (no gap)
- Diagnosis: Width too large, including H-I delimiter on right

### Analysis

The cyan delimiter is 1px wide between each letter in GEN.bmp.

**Known letter positions for reference:**
- D: x=24, width=6 → spans x=24-29, delimiter at x=30
- I: x=60, width=4 → spans x=60-63, delimiter at x=64
- K: x=72, width=7 → spans x=72-78, delimiter at x=79
- L: x=80, width=5 → spans x=80-84, delimiter at x=85

**Calculating H position:**
Between D (4th letter, ends ~x=30) and I (9th letter, starts x=60):
- E, F, G, H span approximately 30px (x=31 to x=59)
- 4 letters + 4 delimiters = ~7.5px average per letter+delimiter

**If H has green on RIGHT at x=53, width=7:**
- H spans x=53-59
- The green at x=59 suggests the actual H ends at x=58
- H should be width=6 (like D), not width=7

### Proposed Fix

Change H from:
- x=53, width=7 (current, wrong)

To:
- x=53, width=6 (proposed fix)

This would make H span x=53-58, leaving x=59 as the delimiter before I (which starts at x=60).

### Letter Width Pattern

Looking at existing letters:
- M=8 (widest, has serifs)
- K=7, R=7 (medium-wide with diagonal strokes)
- D=6, O=6, P=6 (round letters)
- L=5 (narrow)
- I=4 (narrowest)

H is similar to D structurally (two verticals with horizontal bar), so width=6 makes sense.

---

## "MILKDROP V2" Implementation (2026-01-04)

### Change from "HD" to "V2"

User requested changing "MILKDROP HD" to "MILKDROP V2".

### V Letter Sprite Coordinates

Based on ultrathink analysis of GEN.bmp letter positions:

| Letter | X Position | Width | Notes |
|--------|------------|-------|-------|
| V | 152 | 6 | 22nd letter, after U |

**Sprite definitions added:**
```swift
Sprite(name: "GEN_TEXT_SELECTED_V_TOP", x: 152, y: 88, width: 6, height: 6),
Sprite(name: "GEN_TEXT_SELECTED_V_BOTTOM", x: 152, y: 95, width: 6, height: 2),
Sprite(name: "GEN_TEXT_V_TOP", x: 152, y: 96, width: 6, height: 6),
Sprite(name: "GEN_TEXT_V_BOTTOM", x: 152, y: 108, width: 6, height: 1),
```

### Number "2" - Critical Finding

**GEN.bmp does NOT contain number sprites (0-9)**. The GEN.bmp text rows only contain letters A-Z.

**Solution:** Use TEXT.bmp for number "2".

| Source | Character | Sprite Name | Dimensions |
|--------|-----------|-------------|------------|
| TEXT.bmp | "2" | CHARACTER_50 | 5×6 pixels |

**Height comparison:**
- GEN letters: 7-8px (6px TOP + 1-2px BOTTOM)
- TEXT digits: 6px (single piece)

**Alignment solution:** Added 1-2px top padding to align digit baseline with GEN letter baselines.

### Implementation Details

**New `makeDigit` function:**
```swift
@ViewBuilder
private func makeDigit(_ digit: String, width: CGFloat) -> some View {
    let charCode = digit.utf16.first ?? 48
    let spriteName = "CHARACTER_\(charCode)"
    let totalHeight: CGFloat = isWindowActive ? 8 : 7

    VStack(spacing: 0) {
        Color.clear.frame(width: width, height: isWindowActive ? 2 : 1)
        SimpleSpriteImage(spriteName, width: width, height: 6)
    }
    .frame(height: totalHeight)
}
```

### Total Text Width Calculation

| Component | Width |
|-----------|-------|
| MILKDROP | 49px |
| Space | 5px |
| V | 6px |
| 2 | 5px |
| **Total** | **65px** |

**Gap calculation:** (75px center - 65px text) / 2 = **5px each side**

This is slightly better than HD (66px, 4.5px gaps) and much better than original MILKDROP (49px, 13px gaps).

### Known Limitation

The "2" character is from TEXT.bmp (5x6) while letters are from GEN.bmp (variable width, 7-8px tall). There may be a slight visual difference in font style. The height is matched via padding, but the rendering style may differ.
