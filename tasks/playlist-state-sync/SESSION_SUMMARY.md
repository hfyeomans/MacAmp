# Playlist State Sync - Session Summary

**Date:** 2025-10-22/23
**Branch:** `fix/playlist-state-sync`
**Status:** In Progress - Partial Success

---

## What Was Accomplished ✅

### 1. Track Selection Fix - COMPLETE
- Fixed Bug B by changing from ID-based to URL-based track comparison
- Tracks now play correctly when selected from playlist
- Currently playing track properly highlighted (white text, blue background)
- Build: Working, tested, committed

### 2. State Synchronization - COMPLETE
- AudioPlayer properly shared between windows via @EnvironmentObject
- Track selection reflects in both windows
- Time displays update in real-time
- Build: Working

### 3. Time Displays - IMPLEMENTED (needs positioning fix)
- Track time display: `MM:SS / MM:SS` format implemented
- Remaining time display: `-MM:SS` format implemented
- Shows `:` when idle
- Build: Working, but position needs adjustment

---

## Current Issues ❌

### Issue 1: Bottom Corner Sprites Not Rendering Correctly
**Problem:** PLAYLIST_BOTTOM_RIGHT_CORNER doesn't show the 6 gold button icons

**Evidence:**
- Green debug border shows sprite IS rendering at correct position (X:200)
- But the content inside doesn't match expected (no clear gold buttons visible)
- Currently loading: Winamp3_Classified_v5.5 skin

**Possible Causes:**
1. Sprite coordinates (126, 72, 150x38) incorrect for this skin
2. Winamp3 skin has different PLEDIT.BMP layout than Classic
3. Sprite extraction failing silently
4. SimpleSpriteImage rendering issue

### Issue 2: Buttons Being Overlaid When They're Baked In
**Problem:** Individual menu buttons (ADD, REM, SEL, MISC) are overlays, but they're already in BOTTOM_LEFT_CORNER sprite

**Evidence:**
- Extracted tmp/bottom_left_corner.png shows 4 buttons baked into sprite
- Current code renders these buttons separately with SimpleSpriteImage
- Creates gap/spacing issues

**Solution Needed:**
- Remove individual button SimpleSpriteImages
- Add transparent click targets over buttons baked into left corner sprite
- Only render the two corner sprites, nothing else

### Issue 3: Missing 6th Transport Button
**Status:** Eject button added to code but not visible due to Issue #1

---

## Code Changes Made (13 commits)

1. Research and planning documentation
2. PLEDIT sprite definitions added
3. Transport buttons implemented (transparent click targets)
4. Time displays implemented
5. Track selection fix (URL-based matching)
6. Multiple positioning attempts (X:195, X:187.5, X:200)
7. SORT_LIST button removed (it's a menu item, not standalone)
8. Debug borders added for diagnosis

**Files Modified:**
- `MacAmpApp/Models/SkinSprites.swift`
- `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Lines Changed:** ~200 lines

---

## Key Insights Learned

### PLEDIT.BMP Structure
1. **Bottom corners contain baked-in graphics:**
   - BOTTOM_LEFT: 4 menu buttons (ADD, REM, SEL, MISC)
   - BOTTOM_RIGHT: 6 transport buttons, time display area, LIST OPTS area

2. **No overlap needed:**
   - Left: 125px wide, positioned at left edge
   - Right: 150px wide, positioned at right edge
   - Total: 125 + 150 = 275px (exact window width)
   - Meet edge-to-edge at X:125

3. **Buttons are baked into sprites:**
   - Don't render buttons separately
   - Only add transparent click targets over existing graphics

### SimpleSpriteImage Behavior
- Shows purple "?" for missing sprites
- Shows actual sprite if found in skin
- Position uses CENTER point, not top-left
- Width/height parameters set frame size

---

## Next Steps (When Resuming)

### Priority 1: Fix Bottom Corner Rendering
1. Extract PLEDIT.BMP from Winamp3_Classified skin
2. Verify sprite coordinates (126, 72) are correct for this skin
3. Check if sheet is being processed (look for PLEDIT in logs)
4. If not processing, add PLEDIT to sheets list
5. If extracting wrong region, correct coordinates

### Priority 2: Remove Overlaid Buttons
1. Remove buildBottomControls() individual button rendering
2. Add transparent click targets over BOTTOM_LEFT_CORNER buttons
3. Positions: ADD (25, 206), REM (54, 206), SEL (83, 206), MISC (112, 206)

### Priority 3: Verify Transport Button Click Targets
1. Once BOTTOM_RIGHT_CORNER renders correctly with 6 gold icons
2. Test if transparent click targets at X: 133,144,155,166,177,188 work
3. Adjust positions if needed based on actual icon locations

### Priority 4: Position Time Displays
1. Move Text() displays to correct location in info bar
2. May need to use PLEDIT digit sprites instead of Text() for pixel-perfect match
3. Verify against working Winamp reference

---

## Debug Information

**Current Skin:** Winamp3_Classified_v5.5 (user skin)
**Sprite Processing:** Shows "🔍 Looking for sheet: PLEDIT" in logs
**Available Files:** pledit.bmp confirmed in archive

**Debug Borders Added:**
- Red: PLAYLIST_BOTTOM_LEFT_CORNER
- Green: PLAYLIST_BOTTOM_RIGHT_CORNER

**Current Positions:**
- Left corner: X:62.5 (center), spans 0-125
- Right corner: X:200 (center), spans 125-275
- Transport buttons: X: 133,144,155,166,177,188, Y:220
- Time displays: X:191, Y:217/205

---

## Rollback Plan

If needed to start fresh:
```bash
git checkout feature/phase4-polish-bugfixes
git branch -D fix/playlist-state-sync
```

Or cherry-pick working parts:
```bash
git checkout feature/phase4-polish-bugfixes
git cherry-pick 404e6b0  # Track selection fix only
```

---

## Testing Checklist (For Next Session)

- [ ] Extract Winamp3 PLEDIT.BMP and verify sprite locations
- [ ] Confirm PLEDIT sheet is being processed by SkinManager
- [ ] Verify PLAYLIST_BOTTOM_RIGHT_CORNER sprite renders with 6 gold icons
- [ ] Remove buildBottomControls() overlays
- [ ] Test transparent click targets work over baked-in buttons
- [ ] Fine-tune time display positions
- [ ] Test with Classic Winamp and Internet Archive skins
- [ ] Verify state synchronization between windows

---

**Session Status:** Productive - Track selection fixed, learned PLEDIT structure
**Next Session Goal:** Fix sprite rendering and complete button positioning
**Estimated Time Remaining:** 2-3 hours for positioning refinement
