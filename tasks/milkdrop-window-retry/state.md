# Milkdrop Window Retry - State

**Task ID:** milkdrop-window-retry
**Created:** 2026-01-04
**Last Updated:** 2026-01-05

---

## Current State

**Phase:** COMPLETE - "MILKDROP HD" Letters Implemented and Committed

---

## Window Status

| Component | Status | Notes |
|-----------|--------|-------|
| Window Chrome | ✅ Working | GEN.bmp titlebar, borders, bottom bar |
| Focus States | ✅ Working | Active/inactive sprite switching |
| Magnetic Docking | ✅ Working | Integrated with WindowSnapManager |
| Position Persistence | ✅ Working | Saves/restores via UserDefaults |
| Menu Toggle | ✅ Working | View → Show Milkdrop |
| **MILKDROP HD Letters** | ✅ Implemented | Two-piece sprites, H+D with 1px gap |
| Butterchurn Viz | ⏸️ Deferred | Resource bundled, engine not connected |

---

## Sprite Status

| Sprites | Defined | Rendered | Notes |
|---------|---------|----------|-------|
| Titlebar chrome | ✅ 14 | ✅ Yes | All sections rendering |
| Side borders | ✅ 4 | ✅ Yes | Left/right, active/inactive |
| Bottom bar | ✅ 6 | ✅ Yes | Left, fill, right pieces |
| Letter sprites | ✅ 40 | ✅ Yes | M,I,L,K,D,R,O,P,H,V × 2 pieces × 2 states |

---

## Files Modified This Session

- `MacAmpApp/Models/SkinSprites.swift`
  - Added H letter sprites (x=53, width=6) - 4 sprites (selected/normal × TOP/BOTTOM)
  - Added V letter sprites (x=152, width=6) - 4 sprites (for potential future use)

- `MacAmpApp/Views/Windows/MilkdropWindowChromeView.swift`
  - Updated `milkdropLetters` to render "MILKDROP HD"
  - Added 1px Color.clear spacer between H and D
  - Total width: 67px (MILKDROP:49 + space:5 + H:6 + gap:1 + D:6)

- `tasks/milkdrop-window-retry/research.md`
  - Documented H sprite debugging process
  - Added "MILKDROP V2" failed attempt (GEN.bmp lacks numbers)
  - Final "MILKDROP HD" implementation details

---

## Commit History

| Commit | Description |
|--------|-------------|
| fe12e6d | feat: Add MILKDROP HD titlebar letters with H and V sprites |

---

## Branch Status

- **Current branch:** feature/milkdrop-titlebar-letters
- **Base commit:** 181c1cd (chore: Remove review files from repo)
- **Latest commit:** fe12e6d (feat: Add MILKDROP HD titlebar letters)

---

## Decisions Made

1. Focus on letter rendering only (not Butterchurn)
2. Use hardcoded positions for base skin initially
3. Dynamic pixel-scanning algorithm deferred
4. Two-piece sprite pattern confirmed
5. Changed from "MILKDROP" to "MILKDROP HD" for tighter gaps (4px vs 13px)
6. GEN.bmp lacks numbers - "MILKDROP V2" not possible without TEXT.bmp mixing
7. H and D need 1px explicit spacer (no built-in margin in H sprite)

---

## Gap Analysis Summary

| Text | Width | Gap Each Side |
|------|-------|---------------|
| MILKDROP | 49px | 13px |
| MILKDROP HD | 67px | 4px |

**Solution:** Extended text to "MILKDROP HD" fills center section better than complex SwiftUI flexbox workarounds.

---

## H Sprite Debugging Summary

| Attempt | X Coord | Issue | Fix |
|---------|---------|-------|-----|
| Initial | x=52 | Green line on LEFT | Move right |
| Fix 1 | x=53, w=7 | Green line on RIGHT | Reduce width |
| Fix 2 | x=53, w=6 | Working | ✅ Final |
| Normal offset | x=52 | Green line on LEFT | Back to x=53 |

**Final H coordinates:** x=53, width=6 (both selected and normal)

---

## Next Action

Ready for Oracle code review, PR creation, and merge.
