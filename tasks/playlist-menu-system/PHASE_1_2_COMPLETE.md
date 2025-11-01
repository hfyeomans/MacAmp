# Phase 1-2 Complete - Ready for Review

**Branch:** `feature/playlist-menu-system`
**Commit:** `bd2ce7a`
**Date:** 2025-10-25

---

## ✅ What Was Accomplished

### **Phase 1: Sprite Audit & Fixes**

**1. Fixed REM Menu Coordinates (Critical Bug Fix)**

The REM menu sprites were all off by one row. Fixed to match PLEDIT.BMP:

| Sprite | Old Y | New Y | Status |
|--------|-------|-------|--------|
| REMOVE_MISC | Missing | 111 | ✅ Added |
| REMOVE_ALL | 111 ❌ | 130 ✅ | Fixed |
| CROP | 130 ❌ | 149 ✅ | Fixed |
| REMOVE_SELECTED | 149 ❌ | 168 ✅ | Fixed |

**2. Added Complete SEL Menu (Was Missing)**

Added 6 new sprites for selection operations:
- INVERT_SELECTION (104, 111) + _SELECTED (127, 111)
- SELECT_ZERO (104, 130) + _SELECTED (127, 130)
- SELECT_ALL (104, 149) + _SELECTED (127, 149)

**Final Sprite Count:**
- ADD: 6 sprites ✅
- REM: 8 sprites ✅ (now correct!)
- SEL: 6 sprites ✅ (newly added!)
- MISC: 6 sprites ✅
- LIST: 6 sprites ✅
- **Total: 32 menu item sprites**

---

### **Phase 2: Menu Components**

**1. Created SpriteMenuItem.swift (96 lines)**

Custom NSMenuItem that displays sprites with hover detection:

**Features:**
- NSMenuItem subclass with custom view
- SwiftUI sprite rendering via NSHostingView
- NSTrackingArea for hover detection
- Automatic sprite swap on hover
- Size: 22 × 18 pixels

**How it works:**
```swift
// Normal state by default
SimpleSpriteImage(normalSprite)

// Hover detected → swap to selected sprite
mouseEntered() → isHovered = true → SimpleSpriteImage(selectedSprite)

// Mouse leaves → swap back
mouseExited() → isHovered = false → SimpleSpriteImage(normalSprite)
```

**2. Created PlaylistMenuButton.swift (117 lines)**

Reusable menu button with NSMenu popup:

**Features:**
- NSViewRepresentable for SwiftUI integration
- Click to toggle menu (Winamp behavior)
- NSMenu for native macOS popups
- NSMenuDelegate for close detection
- Coordinator pattern for action routing
- Binding for open/close state

**How it works:**
```swift
// Button clicked → show menu
buttonClicked() → create NSMenu → add SpriteMenuItems → popUp()

// User hovers menu item → sprite changes (via SpriteMenuItem)

// User clicks item → execute action → close menu
menuItemClicked() → execute closure → dismiss

// User clicks away → menu closes
NSMenuDelegate.menuDidClose() → isOpen = false
```

---

## 📊 Current Architecture

```
PlaylistMenuButton (SwiftUI/NSViewRepresentable)
  └── NSButton (transparent 22×18px click target)
      └── NSMenu (popup on click)
          └── SpriteMenuItem × N (custom NSMenuItem)
              └── NSHostingView
                  └── SpriteMenuItemView (SwiftUI)
                      └── SimpleSpriteImage
                          └── Sprite from SkinManager
```

**Event Flow:**
1. User clicks button → NSMenu pops up
2. User hovers menu item → NSTrackingArea fires → sprite swaps
3. User clicks menu item → action executes → menu closes
4. User clicks away → NSMenuDelegate.menuDidClose() → menu closes

---

## 🧪 What to Test/Review

### **Visual Inspection:**

1. **Open MacAmp** (currently running from build)
2. **Open Playlist Window** (if not already open)
3. **Look at bottom corners** of playlist window

**What to look for:**
- Bottom-left corner: Should show button area (baked into PLAYLIST_BOTTOM_LEFT_CORNER)
- Bottom-right corner: Should show button area (baked into PLAYLIST_BOTTOM_RIGHT_CORNER)
- The 5 button sprites are within these corner sprites

**Note:** Buttons are NOT yet interactive (Phase 3+ will wire them up)

### **Code Review:**

**SpriteMenuItem.swift:**
- Review hover detection approach (NSTrackingArea)
- Verify SwiftUI/AppKit bridging makes sense
- Check if sprite size is correct (22×18px)

**PlaylistMenuButton.swift:**
- Review NSMenu approach vs alternatives
- Verify Coordinator pattern is appropriate
- Check action routing logic

**SkinSprites.swift:**
- Verify REM menu coordinate fixes
- Verify SEL menu additions
- Confirm all coordinates match PLEDIT.BMP

---

## 🚦 Decision Points for Next Phase

### **Scope:**

**Full Implementation (6-8 hours):**
- ✅ All 5 menus fully functional
- ✅ All menu actions (12+ items)
- ✅ Multi-track selection (Cmd+Click, Shift+Click)
- ✅ M3U playlist import/export
- ✅ Sort submenu
- ❌ File Info dialog (complex - defer?)
- ❌ Misc Options submenu (defer?)

**MVP Implementation (3-4 hours):**
- ✅ Basic actions only (no submenus)
- ✅ Simple selection (single-click only)
- ✅ Basic M3U support
- ❌ Defer: Submenus, multi-select, advanced features

**Recommended:** Start with MVP, iterate based on testing

### **Integration Strategy:**

**Option A: One Menu at a Time**
- Implement ADD menu completely
- Test thoroughly
- Then implement next menu
- Slower but safer

**Option B: All Actions First**
- Implement all menu action methods
- Then integrate all 5 menus
- Faster but riskier

**Recommended:** Option A (incremental integration)

---

## 📝 Next Steps

### **If Approved - Continue to Phase 3:**

1. Choose scope (Full vs MVP)
2. Choose integration strategy (Incremental vs All-at-once)
3. Start implementing menu actions
4. Begin with ADD menu (simplest - has file picker already)

### **If Changes Needed:**

1. Architectural feedback on components?
2. Different hover detection approach?
3. Scope adjustments?
4. Other concerns?

---

## 📦 Files Changed

**Modified:**
- `MacAmpApp/Models/SkinSprites.swift` - Fixed REM, added SEL sprites

**Created:**
- `MacAmpApp/Views/Components/SpriteMenuItem.swift` - Hover menu items
- `MacAmpApp/Views/Components/PlaylistMenuButton.swift` - Menu button

**Documentation (local, gitignored):**
- `tasks/playlist-menu-system/research.md` - Updated
- `tasks/playlist-menu-system/state.md` - Updated
- `tasks/playlist-menu-system/todo.md` - Created
- `tasks/playlist-menu-system/sprite_audit.md` - Created
- `tasks/playlist-menu-system/implementation_notes.md` - Created
- `tasks/playlist-menu-system/REVIEW_CHECKLIST.md` - Created
- `tasks/playlist-menu-system/PHASE_1_2_COMPLETE.md` - This file

---

## 🎯 Review Checklist

**Code Review:**
- [ ] SpriteMenuItem.swift - Architecture OK?
- [ ] PlaylistMenuButton.swift - Approach sound?
- [ ] SkinSprites.swift - Coordinate fixes correct?

**Scope Review:**
- [ ] Full implementation or MVP?
- [ ] Which features are must-have?
- [ ] Timeline acceptable (6-8 hours)?

**Architecture Review:**
- [ ] NSMenu + NSMenuItem approach approved?
- [ ] SwiftUI/AppKit bridging acceptable?
- [ ] Any alternative approaches to consider?

---

**Ready for your feedback!**

Please review and let me know:
1. Are the sprite fixes correct?
2. Is the component architecture acceptable?
3. Should we continue with full or MVP implementation?
4. Any concerns or changes needed?
