# Playlist Menu System - Task State

**Date:** 2025-10-26
**Status:** ✅ MENUS COMPLETE - Multi-Select Next
**Branch:** `feature/playlist-menu-system`
**Priority:** P2 (Enhancement)

---

## Current Status

### ✅ All Menu Buttons Implemented (Phases 0-7 Complete)

**ADD Menu** (3 items):
- ADD FILE: File picker opens, adds tracks ✓
- ADD DIR: File picker opens, adds audio files ✓
- ADD URL: Shows "Not supported yet" (deferred to P5)

**REM Menu** (4 items):
- REM SEL: Removes selected track ✓
- CROP: Shows "Not supported yet"
- REM ALL: Clears playlist ✓
- REM MISC: Shows "Not supported yet"

**SEL Button**:
- Shows alert: "Not supported yet. Use Shift+click for multi-select (planned)"
- Design decision: Eliminated SEL menu, will use native macOS selection instead

**MISC Menu** (3 items):
- SORT LIST, FILE INFO, MISC OPTIONS: All show "Not supported yet"

**LIST OPTS Menu** (3 items):
- NEW LIST, SAVE LIST, LOAD LIST: All show "Not supported yet"

### Architecture

**Pattern:** NSMenu with SpriteMenuItem
- Sprite-based hover states (normal ↔ selected)
- Tight width, no padding issues (ADD, REM, MISC, LIST all consistent)
- Custom HoverTrackingView for hover detection
- mouseDown() forwarding for click handling

**Menu Positions:**
- ADD: x:10, y:396
- REM: x:39, y:346 (4 items)
- MISC: x:112, y:364
- LIST OPTS: x:220, y:364

---

## 🎯 Next Phase: Multi-Select Implementation

**Goal:** Add macOS-native multi-selection to enable CROP and multi-track removal

### Implementation Plan (1.5 hours)

**Phase 1: State Management (15 min)**
- Change `@State var selectedTrackIndex: Int?` → `@State var selectedIndices: Set<Int>`
- Update trackBackground() to highlight selected tracks
- Update trackTextColor() to check Set membership

**Phase 2: Normal Click (15 min)**
- No modifiers: Clear selection, select clicked track
- Maintains current single-select behavior

**Phase 3: Shift+Click Toggle (15 min)**
- Detect NSEvent.modifierFlags.contains(.shift)
- Toggle track in/out of selectedIndices Set

**Phase 4: Command+A Select All (20 min)**
- Add keyboard event handling
- Cmd+A: Select all tracks
- Cmd+D: Deselect all

**Phase 5: Update Menu Actions (30 min)**
- REM SEL: Remove all selected tracks (handles Set<Int>)
- CROP: Keep only selected tracks
- Update PlaylistWindowActions.shared interface

---

## Critical Lessons Learned

### Sprite Coordinate Extraction
- **Issue:** AI hallucinated sprite coordinates, causing visual/functional mismatches
- **Solution:** Manual verification using Preview Inspector (⌘I)
- **Documented:** BUILDING_RETRO_MACOS_APPS_SKILL.md Section 6
- **Coordinates verified:** REM menu sprites corrected by user

### NSHostingMenu Investigation
- **Attempted:** Migration to modern NSHostingMenu (macOS 15+)
- **Result:** Achieved width consistency but unavoidable AppKit padding (8-12px)
- **Decision:** Reverted to NSMenu pattern (tight width, proven)
- **Research:** Fully documented in NSMenu_Research.md, nshostingmenu_analysis.md, gemini_research_button_constraints.md

---

## Files Modified

**Core Implementation:**
- `MacAmpApp/Models/SkinSprites.swift` - All menu sprites (corrected coordinates)
- `MacAmpApp/Views/Components/SpriteMenuItem.swift` - Custom NSMenuItem with hover states
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - All 5 menu implementations
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` - Sprite extraction best practices

**Task Documentation:**
- `state.md` - This file
- `plan.md` - Implementation plan with multi-select next steps
- `todo.md` - Phase tracking (Phases 1-3 complete, Phase 4 next)
- Research documents (NSHostingMenu investigation)

---

## Known Limitations

**Multi-Select:**
- Currently single-track selection only
- Next phase will implement Set<Int> for multi-selection
- Required for CROP and REM SEL with multiple tracks

**Multi-Select Implementation** ✅ COMPLETE (2025-10-26)
- Changed to Set<Int> selection state
- Single-click selects, double-click plays
- Shift+Click toggles multi-selection
- Command+A selects all, Escape deselects all
- REM SEL removes all selected tracks
- CROP keeps only selected tracks
- All features tested and working

**Deferred Features:**
- Shift+Drag range select (polish)
- M3U export/import (SAVE LIST, LOAD LIST - separate task)
- Sort operations (SORT LIST - future)
- File info dialog (FILE INFO - future)
- URL/Internet radio support (ADD URL - separate P5 task)

---

**Status:** ✅ TASK COMPLETE - Ready to merge to main
**Branch:** `feature/playlist-menu-system`
**Commits:** 8 commits on this branch
**Total Time:** ~8 hours (menu system + multi-select)
