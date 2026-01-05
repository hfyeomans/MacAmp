# Milkdrop Window Retry - State

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04
**Last Updated:** 2026-01-04

---

## Current State

**Phase:** COMPLETE - Letters Centered, Gap Limitation Documented

---

## Window Status

| Component | Status | Notes |
|-----------|--------|-------|
| Window Chrome | ✅ Working | GEN.bmp titlebar, borders, bottom bar |
| Focus States | ✅ Working | Active/inactive sprite switching |
| Magnetic Docking | ✅ Working | Integrated with WindowSnapManager |
| Position Persistence | ✅ Working | Saves/restores via UserDefaults |
| Menu Toggle | ✅ Working | View → Show Milkdrop |
| **MILKDROP Letters** | ✅ Implemented | Two-piece sprites (TOP+BOTTOM) rendered |
| Butterchurn Viz | ⏸️ Deferred | Resource bundled, engine not connected |

---

## Sprite Status

| Sprites | Defined | Rendered | Notes |
|---------|---------|----------|-------|
| Titlebar chrome | ✅ 14 | ✅ Yes | All sections rendering |
| Side borders | ✅ 4 | ✅ Yes | Left/right, active/inactive |
| Bottom bar | ✅ 6 | ✅ Yes | Left, fill, right pieces |
| Letter sprites | ✅ 32 | ✅ Yes | Rendered with makeLetter helper |

---

## Files Modified This Session

- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
  - Added `milkdropLetters` computed property (HStack of 8 letters)
  - Added `makeLetter(_:width:)` helper function (two-piece sprite stacking)
  - Positioned letters in titlebar ZStack at x: 137.5, y: 10
  - Letter widths from SkinSprites.swift: M=8, I=4, L=5, K=7, D=6, R=7, O=6, P=6 (total: 49px)

---

## Blocking Issues

1. ~~**Coordinate Verification Needed**~~ ✅ RESOLVED
   - Verified SkinSprites.swift coordinates match GEN.bmp (194×109)
   - Extracted M letter with sips+ImageMagick at x:86, y:88 - correct

2. ~~**Letter Sprite Rendering**~~ ✅ RESOLVED
   - Added makeLetter helper with VStack(spacing: 0) for TOP+BOTTOM pieces
   - Added milkdropLetters HStack inside titlebar ZStack
   - Active/inactive states use GEN_TEXT_SELECTED_ vs GEN_TEXT_ prefixes

---

## Dependencies

| Dependency | Status |
|------------|--------|
| SimpleSpriteImage | ✅ Available |
| SkinManager | ✅ Available |
| WindowFocusState | ✅ Available |
| GEN.bmp in base skin | ✅ Available |

---

## Branch Status

- **Current branch:** main
- **Task branch:** Not created yet
- **Base commit:** dc27293 (Add Xcode test target and documentation updates)

---

## Decisions Made

1. Focus on letter rendering only (not Butterchurn)
2. Use hardcoded positions for base skin initially
3. Dynamic pixel-scanning algorithm deferred
4. Two-piece sprite pattern confirmed

---

## Open Questions

1. ~~Are the letter sprite coordinates in SkinSprites.swift already flipped?~~ ✅ Yes, coords are correct
2. ~~What are the exact Y positions for TOP and BOTTOM pieces?~~ ✅ Selected: Y=88 (TOP), Y=95 (BOTTOM)
3. ~~Are letter heights consistent (6px TOP, 2px BOTTOM for selected)?~~ ✅ Yes, confirmed

---

## Gap Analysis Summary (2026-01-04)

**Current MacAmp:** 13px gap on each side of MILKDROP text
**Webamp reference:** 3-4px gap on each side

**Root Cause:** SwiftUI uses fixed-position discrete 25px tiles, while CSS flexbox allows:
- `flex-grow: 1` for flexible gold fills
- `background-position: right` for right-aligned tiling
- Intrinsic sizing for text container

**Decision:** Keep current 13px gap. Matching Webamp exactly would require:
1. Custom `AlignedTilingSprite` component
2. Complete titlebar layout rewrite to HStack with flexbox-like behavior
3. Significant testing across skins

See `research.md` for complete analysis and future implementation path.

---

## Next Action

Task complete. Ready for commit and PR.
