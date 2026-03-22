# Playlist Menu System - Review Checklist

**Branch:** `feature/playlist-menu-system`
**Commit:** `bd2ce7a`
**Status:** Phase 1-2 Complete - Ready for Review

---

## 📋 What to Review

### 1. **Sprite Coordinate Fixes** (Critical!)

**File:** `MacAmpApp/Models/SkinSprites.swift` (Lines 236-275)

**Review the REM menu fix:**
```swift
// OLD (Lines were offset by one row):
PLAYLIST_REMOVE_ALL at (54, 111)     // ❌ Wrong position
PLAYLIST_CROP at (54, 130)            // ❌ Wrong position
PLAYLIST_REMOVE_SELECTED at (54, 149) // ❌ Wrong position

// NEW (Corrected to match PLEDIT.BMP):
PLAYLIST_REMOVE_MISC (54, 111)       // ✅ Row 1 - Added
PLAYLIST_REMOVE_ALL (54, 130)        // ✅ Row 2 - Fixed
PLAYLIST_CROP (54, 149)              // ✅ Row 3 - Fixed
PLAYLIST_REMOVE_SELECTED (54, 168)   // ✅ Row 4 - Fixed
```

**Question:** Do these coordinates look correct based on PLEDIT.BMP structure?

---

### 2. **New SEL Menu Sprites**

**File:** `MacAmpApp/Models/SkinSprites.swift` (Lines 253-259)

**Added 6 sprites:**
```swift
PLAYLIST_INVERT_SELECTION (104, 111) + _SELECTED (127, 111)
PLAYLIST_SELECT_ZERO (104, 130) + _SELECTED (127, 130)
PLAYLIST_SELECT_ALL (104, 149) + _SELECTED (127, 149)
```

**Question:** Are these the correct selection operations for MacAmp?

---

### 3. **Component Architecture**

**Review:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

**Key Design:**
- NSMenuItem subclass with custom SwiftUI view
- Uses NSTrackingArea for hover detection
- Swaps sprites on mouseEntered/mouseExited

**Questions:**
- Is NSMenuItem + NSHostingView the right approach?
- Any concerns about hover detection reliability?
- Should we use a different hover mechanism?

---

**Review:** `MacAmpApp/Views/Components/PlaylistMenuButton.swift`

**Key Design:**
- NSViewRepresentable wrapper for SwiftUI
- Uses NSMenu for native macOS popup
- Coordinator pattern for NSMenuDelegate
- Click to toggle, click-away to dismiss

**Questions:**
- Is NSMenu preferred over SwiftUI overlay?
- Is the Coordinator pattern appropriate here?
- Any architectural concerns?

---

### 4. **Visual Testing** (Optional but Recommended)

**Steps:**
1. MacAmp is currently running from Phase 2 build
2. Open the playlist window
3. Look at the bottom area where the buttons are

**What to Check:**
- Are there 5 button sections visible in the bottom corners?
- Do the sprites look correct for ADD, REM, SEL, MISC, LIST?
- Is the layout matching the Winamp aesthetic?

**Note:** Menu buttons are NOT functional yet - they're just sprites at this point. Phase 3+ will make them interactive.

---

### 5. **Scope & Planning Review**

**Review:** `tasks/playlist-menu-system/todo.md`

**Remaining Work (Phases 3-7):**
- Phase 3: Menu Actions (1-2 hours) - 12+ menu item implementations
- Phase 4: Selection State (1 hour) - Multi-select with Cmd/Shift+Click
- Phase 5: M3U File I/O (1 hour) - Playlist import/export
- Phase 6: UI Integration (30 min) - Wire up all 5 menus
- Phase 7: Testing (30 min) - Comprehensive testing

**Total Remaining:** 4-6 hours

**Questions:**
- Is this the right scope for one PR?
- Should we split into multiple PRs (MVP first, then full features)?
- Which menu actions are must-have vs nice-to-have?

---

## 🎯 Specific Review Questions

### **Architecture:**
1. NSMenu approach vs SwiftUI overlay - comfortable with this choice?
2. SpriteMenuItem hover detection - should we test this approach first?
3. Any SwiftUI/AppKit bridging concerns?

### **Sprites:**
1. REM menu coordinate fix - does the reordering make sense?
2. SEL menu addition - are Invert/Zero/All the right operations?
3. Any other sprites needed?

### **Scope:**
1. Should we implement all 5 menus in one PR?
2. MVP approach: Just ADD + LIST menus first?
3. Defer complex features (multi-select, submenus)?

---

## 📸 Visual Verification

**If you want to see the sprites:**

1. MacAmp should be running now
2. Open Playlist window (double-click playlist button on main window)
3. Look at bottom-left and bottom-right corners
4. The button sprites are baked into `PLAYLIST_BOTTOM_LEFT_CORNER` and `PLAYLIST_BOTTOM_RIGHT_CORNER`

**You should see:** The 5 button areas in the corners (though not yet interactive)

---

## ✅ What to Approve Before Continuing

- [ ] Architecture approach (NSMenu + SpriteMenuItem)
- [ ] Sprite coordinate fixes (REM menu)
- [ ] New SEL menu sprites
- [ ] Scope for remaining phases (full vs MVP)

**Let me know your thoughts and I'll adjust the plan accordingly!**