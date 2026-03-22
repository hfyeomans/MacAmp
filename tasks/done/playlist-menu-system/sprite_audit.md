# PLEDIT Sprite Audit - 2025-10-25

## Current Sprite Status in SkinSprites.swift

### ✅ ADD Menu (Complete)
- PLAYLIST_ADD_URL (0, 111) + _SELECTED (23, 111)
- PLAYLIST_ADD_DIR (0, 130) + _SELECTED (23, 130)
- PLAYLIST_ADD_FILE (0, 149) + _SELECTED (23, 149)

### ⚠️ REM Menu (INCORRECT COORDINATES)
**Current (Lines 242-247):**
- PLAYLIST_REMOVE_ALL at (54, 111) ❌ WRONG - This is REMOVE_MISC position
- PLAYLIST_CROP at (54, 130) ❌ WRONG - This is REMOVE_ALL position
- PLAYLIST_REMOVE_SELECTED at (54, 149) ❌ WRONG - This is CROP position
- Missing 4th item at (54, 168) ❌

**Should Be:**
- PLAYLIST_REMOVE_MISC (54, 111) + _SELECTED (77, 111)
- PLAYLIST_REMOVE_ALL (54, 130) + _SELECTED (77, 130)
- PLAYLIST_CROP (54, 149) + _SELECTED (77, 149)
- PLAYLIST_REMOVE_SELECTED (54, 168) + _SELECTED (77, 168)

### ❌ SEL Menu (MISSING ENTIRELY)
**Need to Add:**
- PLAYLIST_INVERT_SELECTION (104, 111) + _SELECTED (127, 111)
- PLAYLIST_SELECT_ZERO (104, 130) + _SELECTED (127, 130)
- PLAYLIST_SELECT_ALL (104, 149) + _SELECTED (127, 149)

### ✅ MISC Menu (Complete)
- PLAYLIST_SORT_LIST (154, 111) + _SELECTED (177, 111)
- PLAYLIST_FILE_INFO (154, 130) + _SELECTED (177, 130)
- PLAYLIST_MISC_OPTIONS (154, 149) + _SELECTED (177, 149)

### ✅ LIST Menu (Complete)
- PLAYLIST_NEW_LIST (204, 111) + _SELECTED (227, 111)
- PLAYLIST_SAVE_LIST (204, 130) + _SELECTED (227, 130)
- PLAYLIST_LOAD_LIST (204, 149) + _SELECTED (227, 149)

### ℹ️ Vertical Dividers (Reference Only)
The grey vertical lines in PLEDIT.BMP at X: 48, 100, 150, 200 are **visual reference guides** in the sprite sheet showing column boundaries. They are NOT sprites to extract - the actual buttons (baked into PLAYLIST_BOTTOM_LEFT_CORNER and PLAYLIST_BOTTOM_RIGHT_CORNER) already include any necessary visual separation.

## Action Required

1. Fix REM menu coordinates (shift all items down one row)
2. Add missing REMOVE_MISC at top of REM menu
3. Add complete SEL menu (6 sprites - currently missing)

**Total Sprites to Add:** 6 (SEL) + 2 (REM_MISC) = 8 new sprites
**Total Sprites to Fix:** 6 (REM menu Y-coordinates need correction)

---

## ✅ COMPLETED - 2025-10-25

### Sprites Added to SkinSprites.swift

**REM Menu (Fixed + Added):**
- ✅ Added PLAYLIST_REMOVE_MISC (54, 111) + _SELECTED (77, 111)
- ✅ Fixed PLAYLIST_REMOVE_ALL to (54, 130) + _SELECTED (77, 130)
- ✅ Fixed PLAYLIST_CROP to (54, 149) + _SELECTED (77, 149)
- ✅ Fixed PLAYLIST_REMOVE_SELECTED to (54, 168) + _SELECTED (77, 168)

**SEL Menu (Added):**
- ✅ Added PLAYLIST_INVERT_SELECTION (104, 111) + _SELECTED (127, 111)
- ✅ Added PLAYLIST_SELECT_ZERO (104, 130) + _SELECTED (127, 130)
- ✅ Added PLAYLIST_SELECT_ALL (104, 149) + _SELECTED (127, 149)

### Final Sprite Count

**PLEDIT.BMP Menu Sprites:**
- ADD: 6 sprites (3 items × 2 states) ✅
- REM: 8 sprites (4 items × 2 states) ✅
- SEL: 6 sprites (3 items × 2 states) ✅
- MISC: 6 sprites (3 items × 2 states) ✅
- LIST: 6 sprites (3 items × 2 states) ✅

**Total: 32 menu item sprites** - All present and correctly mapped!

**Status:** Ready for Phase 2 (Menu Components)
