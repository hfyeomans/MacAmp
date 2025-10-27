# Ready for Next Session - MacAmp Development

**Last Updated:** 2025-10-26
**Current Branch:** `feature/playlist-menu-system`
**Build Status:** ✅ Successful - All 5 Menu Buttons Complete

---

## 🎯 Active Tasks

### **Task 1: Playlist Menu System (P2) - MENUS COMPLETE ✅**

**Branch:** `feature/playlist-menu-system`
**Task Name:** Playlist Menu System
**Task Folder:** `tasks/playlist-menu-system/`
**Status:** All 5 menu buttons implemented and functional
**Completion:** 7 of 7 phases complete (menus done)

**Next Steps - Multi-Select Implementation:**
1. **Shift+Click** - Toggle individual track selection
2. **Shift+Drag** - Range select multiple tracks
3. **Command+A** - Select all tracks
4. **Visual highlight** - Show selected tracks with different background
5. **Update REM SEL/CROP** - Work with multi-selection Set<Int>

**Implementation Details:**
- Change `@State var selectedTrackIndex: Int?` to `@State var selectedIndices: Set<Int>`
- Add event modifiers detection to track row onTapGesture
- Update track background color for selected state
- Update PlaylistWindowActions to work with selection set

**Estimated Time:** 1-2 hours

## ✅ What's Currently Working

**All 5 Playlist Menu Buttons:**
- ADD menu: File picker opens for ADD FILE and ADD DIR
- REM menu: REM ALL clears playlist, REM SEL removes selected track
- SEL button: Shows alert about upcoming multi-select feature
- MISC menu: All 3 items show "Not supported yet" alerts
- LIST OPTS menu: All 3 items show "Not supported yet" alerts

**Menu Architecture:**
- Using NSMenu with SpriteMenuItem pattern (proven, tight width)
- Sprite-based hover states working correctly
- Proper positioning over each button
- No width inconsistency issues (ADD, REM, MISC, LIST all tight)

---

## 🎯 Next Step: Multi-Select Implementation

**Goal:** Add macOS-native multi-selection to playlist tracks

**Features to Implement:**
1. **Shift+Click** - Toggle individual track selection
2. **Shift+Drag** - Range select multiple tracks
3. **Command+A** - Select all tracks
4. **Visual Feedback** - Highlight selected tracks differently

**State Management:**
- Change from `@State var selectedTrackIndex: Int?` to `@State var selectedIndices: Set<Int>`
- Update track row rendering to show multi-select state
- Update REM SEL, CROP actions to work with selection set

**Estimated Time:** 1-2 hours

---

### **Task 2: Playlist Text Rendering Fix (P2) - READY**

**Branch:** TBD (`fix/playlist-text-rendering`)
**Task Folder:** `tasks/playlist-text-rendering-fix/`
**Status:** Research Complete - Ready to implement
**Time:** 30-60 minutes
**Issue:** Track listings use TEXT.BMP bitmap fonts (should use real text)

### **Progress: 3 of 7 Phases Complete**

| Phase | Status |
|-------|--------|
| 1. Sprite Audit | ✅ COMPLETE |
| 2. Menu Components | ✅ COMPLETE |
| 3. ADD Menu POC | ✅ COMPLETE |
| 4. REM Menu | ⏳ NEXT |
| 5. SEL Menu | ⏳ PENDING |
| 6. MISC Menu | ⏳ PENDING |
| 7. LIST Menu | ⏳ PENDING |

### **What's Working:**

✅ **ADD Menu:**
- Click ADD button → sprite-based popup menu
- 3 menu items with hover states (light ↔ dark grey)
- ADD FILE opens file picker ✅
- ADD DIR opens file picker ✅
- ADD URL shows deferral message (→ P5)

✅ **Critical Fixes:**
- Fixed eject button (x: 183)
- Fixed REM sprite coordinates
- Added SEL menu sprites (6 sprites)
- NSMenu positioning (x: 10, y: 400)

### **Key Files:**

**Modified:**
- `MacAmpApp/Models/SkinSprites.swift` - 32 menu sprites
- `MacAmpApp/Views/Components/SpriteMenuItem.swift` - Hover + click forwarding
- `MacAmpApp/Views/WinampPlaylistWindow.swift` - ADD menu integration
- `BUILDING_RETRO_MACOS_APPS_SKILL.md` - NSMenu coordinates gotcha

**Documentation:**
- `tasks/playlist-menu-system/state.md` - Progress tracking
- `tasks/playlist-menu-system/SESSION_SUMMARY.md` - Session recap
- `tasks/playlist-menu-system/research.md` - Webamp analysis
- `tasks/playlist-menu-system/todo.md` - Implementation plan

### **Commits:**
- `bd2ce7a` - Phase 1-2: Sprites + components
- `03ad60b` - ADD menu working
- `0720c04` - Documentation updates

### **Next Steps:**

1. Test ADD menu thoroughly
2. Implement REM menu (4 items, x: ~53, y: 400)
3. Implement SEL menu (3 items, x: ~82, y: 400)
4. Implement MISC menu (3 items, x: ~111, y: 400)
5. Implement LIST menu (3 items, x: ~460, y: 400)

**Estimated Time Remaining:** 2-4 hours

---

## 📊 Today's Accomplishments (2025-10-25)

### **Session 1: Spectrum Analyzer Improvements**

**PR #19: Frequency-Dependent Gain Compensation** ✅ MERGED
- Implemented pinking filter (dB-based equalization)
- Fixed bass dominance (bass reduced 60%, treble boosted 250%)
- Vocals now prominent in mid-range bars
- Sensitivity: 15.0x (tuned for visibility)
- Architecture verified: Spectrum taps AFTER EQ (correct!)

**Hotfix: Hard-coded Path** ✅ MERGED
- Fixed `scripts/verify-dist-signature.sh`
- Dynamic path resolution (works on all environments)
- 3 flexible methods: CLI arg, env var, auto-detect

**Development Workflow:** ✅ MERGED
- Created `scripts/quick-install.sh` (30-40 sec builds)
- Automated build → sign → install → launch
- 10x faster iteration

### **Session 2: Playlist Menu System (WIP)**

**Phase 1-3 Complete:**
- Fixed sprite coordinates, added SEL menu
- Created SpriteMenuItem with hover + click forwarding
- ADD menu fully functional with 3 actions

**Technical Breakthroughs:**
- NSMenu flipped coordinate system solved
- Custom NSView click forwarding implemented
- Sprite hover states working perfectly

---

## 🏗️ Architecture Patterns Learned

### **NSMenu Coordinate System (CRITICAL)**

```swift
// Flipped coordinates: Y=0 at top, increasing Y goes DOWN
// Counter-intuitive but correct!

// ❌ WRONG: Subtracting moves menu UP
let location = NSPoint(x: 10, y: 206 - 54)  // Menu too high

// ✅ CORRECT: Adding moves menu DOWN
let location = NSPoint(x: 10, y: 400)  // Menu at bottom
```

**Debugging:**
- Menu too HIGH → INCREASE Y
- Menu too LOW → DECREASE Y

### **NSMenuItem Click Forwarding**

```swift
// Custom NSView blocks NSMenuItem clicks
override func mouseDown(with event: NSEvent) {
    if let menuItem = menuItem,
       let action = menuItem.action,
       let target = menuItem.target {
        NSApp.sendAction(action, to: target, from: menuItem)
    }
    menuItem?.menu?.cancelTracking()  // Close menu
}
```

---

## 🧪 What to Test

### **ADD Menu (Current Session):**
1. Open playlist window
2. Click ADD button
3. Test all 3 menu items:
   - ADD URL (shows deferral message)
   - ADD DIR (opens file picker)
   - ADD FILE (opens file picker)
4. Verify hover sprites change
5. Add files and verify they appear in playlist

### **Transport Buttons:**
- All 6 buttons working (prev, play, pause, stop, next, eject)
- Eject button fixed (x: 183)

### **Edge Cases:**
- Rapid clicking
- Different skins
- Multiple file selection
- Menu dismiss on click-away

---

## 🚀 Next Session Plan

### **Option A: Complete Playlist Menus (2-4 hours)**

Continue `feature/playlist-menu-system` branch:

1. **REM Menu** (30 min)
   - 4 items: REMOVE MISC, REMOVE ALL, CROP, REMOVE SELECTED
   - Position: x: 53, y: 400
   - Actions: Clear playlist, remove operations

2. **SEL Menu** (30 min)
   - 3 items: INVERT, SELECT ZERO, SELECT ALL
   - Position: x: 82, y: 400
   - Requires: Selection state management

3. **MISC Menu** (45 min)
   - 3 items: SORT LIST, FILE INFO, MISC OPTIONS
   - Position: x: 111, y: 400
   - Defer submenus if complex

4. **LIST Menu** (45 min)
   - 3 items: NEW LIST, SAVE LIST, LOAD LIST
   - Position: x: 460, y: 400
   - Requires: M3U export functionality

**Total:** ~2.5-3.5 hours to complete all menus

### **Option B: Switch to Different Task**

If you want to tackle something else:
- P1: Async audio loading (UX critical)
- P5: Internet radio (depends on P2 for ADD URL)

---

## 📦 Recent Commits

**Main Branch:**
- `dadf9d9` - Development workflow scripts
- `780128c` - Merged PR #19 (spectrum pinking filter)
- `e0cde08` - Fixed verify-dist-signature.sh path

**Feature Branch (playlist-menu-system):**
- `bd2ce7a` - Phase 1-2 foundation
- `03ad60b` - ADD menu working
- `0720c04` - Documentation

---

## 🎯 Immediate Next Steps

**When you resume:**

1. **Test ADD menu thoroughly**
2. **If good, continue with REM menu:**
   ```bash
   # Already on feature/playlist-menu-system branch
   # Implement showRemMenu() following ADD pattern
   ```
3. **Or switch tasks if preferred**

**Quick Reference:**
- Current task docs: `tasks/playlist-menu-system/`
- Session summary: `tasks/playlist-menu-system/SESSION_SUMMARY.md`
- Implementation notes: `tasks/playlist-menu-system/implementation_notes.md`

---

**Status:** ✅ Ready for next session
**Branch:** `feature/playlist-menu-system`
**Next:** Implement REM/SEL/MISC/LIST menus OR switch to different priority
