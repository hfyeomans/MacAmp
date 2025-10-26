# Playlist Menu System - Task State

**Date:** 2025-10-25
**Status:** 🔄 IN PROGRESS - ADD Menu POC Complete
**Branch:** `feature/playlist-menu-system`
**Priority:** P2 (Enhancement)

---

## 📊 Phase Progress: 4 of 7 Complete

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Research & Planning | ✅ COMPLETE |
| 1 | Sprite Audit & Fixes | ✅ COMPLETE |
| 2 | Menu Components | ✅ COMPLETE |
| 3 | ADD Menu POC | ✅ COMPLETE |
| 4 | REM Menu | ✅ COMPLETE |
| 5 | SEL Menu | ⏳ NEXT |
| 6 | MISC Menu | ⏳ PENDING |
| 7 | LIST Menu | ⏳ PENDING |

---

## ✅ Completed Phases

### **Phase 0: Research & Planning**

- Analyzed PLEDIT.BMP structure (280×186px, 5 button sections)
- Read complete webamp_clone implementation
- Documented all 5 menus with 12+ menu items
- Mapped sprite coordinates for all states
- Created comprehensive todo.md

### **Phase 1: Sprite Audit & Fixes**

**Fixed REM Menu:**
- Sprites had wrong Y-coordinates (off by one row)
- Added PLAYLIST_REMOVE_MISC (54, 111)
- Fixed REMOVE_ALL to (54, 130)
- Fixed CROP to (54, 149)
- Fixed REMOVE_SELECTED to (54, 168)

**Added SEL Menu:**
- PLAYLIST_INVERT_SELECTION (104, 111) + _SELECTED
- PLAYLIST_SELECT_ZERO (104, 130) + _SELECTED
- PLAYLIST_SELECT_ALL (104, 149) + _SELECTED

**Result:** 32 menu sprites correctly mapped to PLEDIT.BMP

### **Phase 2: Menu Components**

**Created SpriteMenuItem.swift:**
- Custom NSMenuItem with sprite rendering
- HoverTrackingView for hover detection
- mouseDown() override forwards clicks (critical!)
- Sprite swaps on hover (light ↔ dark grey)

**Created PlaylistMenuButton.swift:**
- Stub component (not currently used)
- Menu logic implemented directly in WinampPlaylistWindow

**Key Discovery:**
NSMenuItem with custom NSView blocks clicks.
Solution: Override mouseDown() and use NSApp.sendAction()

### **Phase 3: ADD Menu POC**

**Integration:**
- showAddMenu() creates NSMenu with 3 sprite items
- PlaylistWindowActions handles menu actions
- Position tuned: (x: 10, y: 400)

**Actions:**
- ADD URL: Deferred to P5 (shows placeholder)
- ADD DIR: Opens file picker (same as ADD FILE)
- ADD FILE: Opens file picker ✅

**Critical Fixes:**
- Eject button: x: 188 → 183 (3px left)
- NSMenu positioning: Discovered flipped coordinate system
- Click forwarding: HoverTrackingView.mouseDown()

### **Phase 4: REM Menu**

**Integration:**
- showRemMenu() creates NSMenu with 4 sprite items
- Position: (x: 39, y: 346) - 29px right of ADD, bottom aligns at y:400
- Uses same SpriteMenuItem pattern

**Actions:**
- REM SEL: Removes selected track from playlist ✅
- CROP: Shows "Not supported yet" alert ✅
- REM ALL: Clears entire playlist ✅
- REM MISC: Shows "Not supported yet" alert ✅

**Critical Issue Discovered - Sprite Coordinate Mapping:**
- AI hallucinated sprite coordinates instead of reading from bitmap
- Variable names in WinampPlaylistWindow.swift didn't match actual sprite visuals
- SkinSprites.swift coordinates were incorrect/duplicated
- **Solution:** User manually verified coordinates from PLEDIT.BMP using Preview Inspector
- **Correct coordinates:**
  - REMOVE_MISC: x:54, y:168
  - REMOVE_ALL: x:54, y:111
  - CROP: x:54, y:130
  - REMOVE_SELECTED: x:54, y:149

**Lessons Learned:**
- NEVER trust AI to know bitmap coordinates - must be verified from source
- Use image editor (Preview Inspector on macOS) to measure pixel coordinates
- Annotated PNG files (like PLEDIT_ANNOTATED.png) are helpful but still need verification
- Consider using Gemini CLI or separate agent for sprite sheet analysis
- Variable names must match visual sprites, not just coordinate references

---

## 🔧 Technical Decisions

**1. Menu System:** NSMenu with custom sprite views
- Native macOS popup behavior
- Proper shadows and positioning
- Built-in dismiss on click-away

**2. Hover Detection:** NSTrackingArea
- Reliable hover events
- No polling needed
- Matches webamp approach

**3. Click Handling:** mouseDown() forwarding
- Custom view forwards to NSMenuItem action
- NSApp.sendAction() triggers handler
- Menu closes automatically

**4. Coordinate System:** Flipped Y-axis
- Y=0 at top, increasing Y goes DOWN
- Counter-intuitive but documented
- Position: (x: 10, y: 400) for ADD button

---

## 📦 Files Modified

**Code:**
1. `MacAmpApp/Models/SkinSprites.swift` - Fixed REM, added SEL (32 sprites)
2. `MacAmpApp/Views/Components/SpriteMenuItem.swift` - Hover + click (141 lines)
3. `MacAmpApp/Views/Components/PlaylistMenuButton.swift` - Stub (21 lines)
4. `MacAmpApp/Views/WinampPlaylistWindow.swift` - ADD menu integration
5. `BUILDING_RETRO_MACOS_APPS_SKILL.md` - NSMenu gotcha docs
6. `tasks/internet-radio-file-types/README.md` - ADD URL TODO

**Documentation (gitignored):**
7. `state.md` - This file
8. `research.md` - Webamp + PLEDIT analysis
9. `todo.md` - 7-phase plan
10. `sprite_audit.md` - Sprite audit results
11. `implementation_notes.md` - Technical notes
12. `SESSION_SUMMARY.md` - Session recap

---

## 🎯 Next Phase: SEL Menu

**Button Position:** x: 68, y: 400 (58px right of ADD, or 29px right of REM)

**Menu Items (3 items):**
1. INVERT SELECTION - Invert selection state
2. SELECT ZERO - Clear all selections
3. SELECT ALL - Select all tracks

**Sprites Ready:**
- PLAYLIST_INVERT_SELECTION / _SELECTED ✅
- PLAYLIST_SELECT_ZERO / _SELECTED ✅
- PLAYLIST_SELECT_ALL / _SELECTED ✅

**Dependencies:**
- All actions need selection state management (Set<Int>)

**Estimated Time:** 30-45 min (pattern proven with ADD/REM)

---

## 📝 Implementation Notes

### **Proven Pattern (from ADD Menu):**

```swift
private func showAddMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false

    // Create sprite menu items
    let item = SpriteMenuItem(
        normalSprite: "PLAYLIST_ADD_FILE",
        selectedSprite: "PLAYLIST_ADD_FILE_SELECTED",
        skinManager: skinManager,
        action: #selector(PlaylistWindowActions.addFile),
        target: PlaylistWindowActions.shared
    )
    item.representedObject = audioPlayer
    item.isEnabled = true
    menu.addItem(item)

    // Position menu
    if let window = NSApp.keyWindow,
       let contentView = window.contentView {
        let location = NSPoint(x: 10, y: 400)
        menu.popUp(positioning: nil, at: location, in: contentView)
    }
}
```

**Reusable for all menus!** Just change:
- Sprite names
- X-position
- Actions

### **Known Limitations**

**Selection State:**
- Currently: Single track selection only
- Needed: Multi-track selection (Set<Int>)
- Required for: CROP, REMOVE SELECTED, SEL menu

**M3U Export:**
- Not yet implemented
- Required for: SAVE LIST action
- Estimated: 30 min to implement

---

## ⏰ Time Tracking

**Phase 1:** 30 min (sprite audit/fixes)
**Phase 2:** 1.5 hours (component creation + debugging)
**Phase 3:** 2 hours (ADD menu + positioning + click forwarding)

**Total So Far:** ~4 hours
**Estimated Remaining:** 2-4 hours (4 menus + selection state + M3U export)

---

## 🚦 Blockers & Dependencies

**No Blockers:** ADD menu pattern proven, ready to replicate

**Dependencies for Full Implementation:**
- Selection state: @State var selectedTrackIndices: Set<Int>
- M3U writer: For SAVE LIST action
- Sort methods: For SORT LIST action

**Can Implement Now:**
- REM: REMOVE ALL (no dependencies)
- MISC: FILE INFO placeholder
- LIST: NEW LIST, LOAD LIST (already have M3U parser)

---

**Status:** ✅ ADD Menu POC Working - Ready for Next Menu
**Next:** Implement REM menu following proven pattern
**Branch:** `feature/playlist-menu-system` (3 commits)
