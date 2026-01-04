# Milkdrop Window Retry - State

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04
**Last Updated:** 2026-01-04

---

## Current State

**Phase:** RESEARCH COMPLETE - Ready for Implementation

---

## Window Status

| Component | Status | Notes |
|-----------|--------|-------|
| Window Chrome | ✅ Working | GEN.bmp titlebar, borders, bottom bar |
| Focus States | ✅ Working | Active/inactive sprite switching |
| Magnetic Docking | ✅ Working | Integrated with WindowSnapManager |
| Position Persistence | ✅ Working | Saves/restores via UserDefaults |
| Menu Toggle | ✅ Working | View → Show Milkdrop |
| **MILKDROP Letters** | ❌ Missing | Two-piece sprites not rendered |
| Butterchurn Viz | ⏸️ Deferred | Resource bundled, engine not connected |

---

## Sprite Status

| Sprites | Defined | Rendered | Notes |
|---------|---------|----------|-------|
| Titlebar chrome | ✅ 14 | ✅ Yes | All sections rendering |
| Side borders | ✅ 4 | ✅ Yes | Left/right, active/inactive |
| Bottom bar | ✅ 6 | ✅ Yes | Left, fill, right pieces |
| Letter sprites | ✅ 32 | ❌ No | Defined but not used in view |

---

## Files Modified This Session

None yet - research phase only.

---

## Blocking Issues

1. **Coordinate Verification Needed**
   - Must verify SkinSprites.swift coordinates against actual GEN.bmp
   - May need to apply Y-flip formula

2. **Letter Sprite Rendering**
   - Sprites defined in SkinSprites.swift but not used in MilkdropWindowChromeView.swift
   - Need to add makeLetter helper and HStack in titlebar

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

1. Are the letter sprite coordinates in SkinSprites.swift already flipped?
2. What are the exact Y positions for TOP and BOTTOM pieces?
3. Are letter heights consistent (6px TOP, 2px BOTTOM for selected)?

---

## Next Action

Verify sprite coordinates in SkinSprites.swift against GEN.bmp extraction.
