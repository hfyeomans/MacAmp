# Playlist State Sync - Current State

**Date:** 2025-10-23
**Branch:** `fix/playlist-state-sync` (off `feature/phase4-polish-bugfixes`)
**Status:** ✅ MAJOR PROGRESS - Sprites Rendering Correctly

---

## ✅ COMPLETED - Working Features

### 1. Track Selection Fix (Bug B) - COMPLETE ✅
- Fixed track matching using URL comparison (not ID)
- Clicking tracks in playlist plays correct track
- Currently playing track highlighted properly
- No restart of same track when clicked again

### 2. State Synchronization - COMPLETE ✅
- AudioPlayer shared between all windows via @EnvironmentObject
- Playlist and main window stay in sync
- Playback state reflects correctly across windows

### 3. Bottom Sprite Rendering - FIXED ✅
**Major Breakthrough:** 
- PLAYLIST_BOTTOM_LEFT_CORNER (125px) renders correctly
- PLAYLIST_BOTTOM_RIGHT_CORNER (154px) renders correctly
- All 6 transport icons visible in right sprite
- Black info bar showing at proper width
- No gaps or clipping

**Key Fixes Applied:**
1. Removed Spacer() that was creating gap
2. Disabled PLAYLIST_BOTTOM_TILE overlay that was covering sprites
3. Reduced black track list height to avoid overlap
4. Used HStack for clean left-right layout
5. Set right sprite to 154px (full PLEDIT.BMP width, not 150px)

### 4. Time Display Logic - IMPLEMENTED ✅
- Track time calculation: `MM:SS / MM:SS` format
- Remaining time calculation: `-MM:SS` format
- Shows `:` when idle
- Updates in real-time from AudioPlayer

---

## 🔄 IN PROGRESS - Next Tasks

### Task 1: Implement Track Time Numbers in Black Bars
**Goal:** Display track timing info in the black bars using PLEDIT digit sprites

**Current:** Time displays use SwiftUI Text (green color, monospaced)
**Needed:**
- Use PLEDIT.BMP digit sprites for pixel-perfect rendering
- Position numbers in black info bar areas
- Follow PLEDIT.TXT for font/color configuration
- Format: Current time / Total playlist time above transport buttons
- Format: Remaining time (negative countdown)

**Files to Modify:**
- `WinampPlaylistWindow.swift` - Update buildTimeDisplays() method
- May need to add PLEDIT digit sprite definitions to SkinSprites.swift

**Estimated Time:** 1-2 hours

### Task 2: Make Transport Icons Clickable
**Goal:** Add transparent click targets over the 6 baked-in transport button icons

**Current:** buildPlaylistTransportButtons() has 6 transparent buttons at Y:220
**Status:** Code exists but positions may need adjustment

**Buttons:**
1. Previous (◄◄) → audioPlayer.previousTrack()
2. Play (►) → audioPlayer.play()
3. Pause (❚❚) → audioPlayer.pause()
4. Stop (■) → audioPlayer.stop()
5. Next (►►) → audioPlayer.nextTrack()
6. Eject (⏏) → openFileDialog()

**Testing Needed:**
- Verify click targets align with visible icons
- Test all 6 buttons trigger correct actions
- Verify state synchronization (button presses update both windows)

**Estimated Time:** 30 minutes (code already exists, just test/adjust)

---

## 🏗️ Architecture Notes

### Bottom Section Layout (CONFIRMED WORKING):
```
HStack(spacing: 0) {
  LEFT sprite (125px) + RIGHT sprite (154px)
}
Total: 279px
```

### Sprite Coordinates in PLEDIT.BMP:
- PLAYLIST_BOTTOM_LEFT_CORNER: x:0, y:72, 125x38
- PLAYLIST_BOTTOM_RIGHT_CORNER: x:126, y:72, 154x38

### Button Click Target Positions (current):
**Menu Buttons (in left section):**
- ADD: (25, 206)
- REM: (54, 206)
- SEL: (83, 206)
- MISC: (112, 206)

**Transport Buttons (in right section):**
- Previous: (133, 220)
- Play: (144, 220)
- Pause: (155, 220)
- Stop: (166, 220)
- Next: (177, 220)
- Eject: (188, 220)

---

## 📝 Session Summary

**Total Commits:** 25+
**Files Modified:** 3 main files
- WinampPlaylistWindow.swift
- SkinSprites.swift
- SimpleSpriteImage.swift
- ImageSlicing.swift

**Key Discoveries:**
1. Buttons are baked into corner sprites (not separate overlays)
2. Webamp uses 3-section layout but center is 0px in fixed window
3. Right sprite is 154px (not 150px as webamp docs suggested)
4. Y-coordinate flip breaks existing main window (reverted)
5. Overlapping elements were covering sprites

**Major Issues Resolved:**
- ✅ Track selection bug (Bug B from Phase 4)
- ✅ Sprite rendering (all 6 transport icons visible)
- ✅ Layout gaps eliminated
- ✅ State synchronization working

---

## 🔀 Branch Structure

```
main
  └─ feature/phase4-polish-bugfixes (parent branch)
      └─ fix/playlist-state-sync (current branch - THIS ONE)
```

**Merge Plan:**
1. Complete remaining tasks (time numbers, button testing)
2. Final testing with Classic Winamp and Internet Archive skins
3. Merge `fix/playlist-state-sync` → `feature/phase4-polish-bugfixes`
4. Test merged branch thoroughly
5. Merge `feature/phase4-polish-bugfixes` → `main`

---

## 🎯 Success Metrics

### Must Have (Before Merge):
- [x] Track selection works reliably
- [x] All 6 transport icons visible
- [ ] Track time numbers display in black bars
- [ ] Transport buttons clickable and functional
- [ ] State syncs between main and playlist windows
- [ ] Works with Classic Winamp skin
- [ ] Works with Internet Archive skin

### Nice to Have:
- [ ] Remaining time countdown working
- [ ] Button hover effects
- [ ] Smooth animations

---

**Current Status:** ✅ READY FOR NEXT TASKS
**Next Session:** Implement track time numbers, test button clicks
**Estimated Remaining Time:** 2-3 hours to completion
