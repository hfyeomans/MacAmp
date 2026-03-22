# Playlist Menu System - Implementation Tasks

**Branch:** `feature/playlist-menu-system`
**Priority:** P2
**Status:** ✅ COMPLETE - Ready to Merge

---

## ✅ ALL PHASES COMPLETE

### Phase 1: Sprite Audit & Addition ✅
- [x] Audit missing sprites
- [x] Add SEL, MISC, LIST menu sprites
- [x] Manually verify REM coordinates (user corrected AI hallucinations)

### Phase 2: Menu Components ✅
- [x] Create SpriteMenuItem.swift with hover/click handling
- [x] NSMenu integration working

### Phase 3: Menu Implementation ✅
- [x] ADD menu (3 items) - File pickers working
- [x] REM menu (4 items) - Remove actions working
- [x] SEL button alert (eliminated menu, multi-select via keyboard)
- [x] MISC menu (3 items) - All "Not supported yet"
- [x] LIST OPTS menu (3 items) - All "Not supported yet"

### Phase 4: Multi-Select Functionality ✅
- [x] Change `selectedTrackIndex: Int?` → `selectedIndices: Set<Int>`
- [x] Update trackBackground() for Set membership
- [x] Single-Click: Select only (no playback)
- [x] Double-Click: Play track
- [x] Shift+Click: Toggle track in/out of Set
- [x] Command+A: Select all tracks
- [x] Escape/Cmd+D: Deselect all
- [x] REM SEL: Remove all selected tracks
- [x] CROP: Keep only selected tracks
- [x] Clear selection after actions

**All features tested and working!**

---

## Deferred Features (Future Tasks)

- Shift+Drag range select (polish)
- M3U export/import (SAVE LIST, LOAD LIST)
- Sort operations (SORT LIST submenu)
- File info dialog (FILE INFO)
- Misc options submenu
- New list confirmation dialog

---

## Success Criteria - ALL MET ✅

- [x] All 5 menu buttons functional
- [x] Sprite hover states working
- [x] Multi-track selection working
- [x] REM SEL/CROP work with multi-selection
- [x] Keyboard shortcuts (Cmd+A, Escape)
- [x] Matches macOS native selection behavior
- [x] Works with Thread Sanitizer enabled

---

**Status:** ✅ COMPLETE - Ready to merge to main
**Total Time:** ~8 hours (menu system + multi-select)
**Commits:** 8 commits on feature/playlist-menu-system branch
