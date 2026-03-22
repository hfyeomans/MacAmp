# Playlist Menu System - Implementation Notes

**Date:** 2025-10-25
**Branch:** `feature/playlist-menu-system`
**Status:** Phase 2 Complete

---

## Phase 1: Sprite Audit & Addition ✅

### Changes to SkinSprites.swift

**File:** `MacAmpApp/Models/SkinSprites.swift:242-259`

### Fixed: REM Menu Coordinates

**Problem:** REM menu sprites had incorrect Y-coordinates, didn't match PLEDIT.BMP layout

**Before:**
```swift
PLAYLIST_REMOVE_ALL at (54, 111)     // Wrong - this is REMOVE_MISC position
PLAYLIST_CROP at (54, 130)           // Wrong - this is REMOVE_ALL position
PLAYLIST_REMOVE_SELECTED at (54, 149) // Wrong - this is CROP position
// Missing 4th row at Y:168
```

**After (Corrected):**
```swift
PLAYLIST_REMOVE_MISC (54, 111)       // Added - Row 1
PLAYLIST_REMOVE_ALL (54, 130)        // Fixed - Row 2
PLAYLIST_CROP (54, 149)              // Fixed - Row 3
PLAYLIST_REMOVE_SELECTED (54, 168)   // Fixed - Row 4
```

### Added: SEL Menu Sprites

**Added 6 new sprites (Lines 253-259):**
```swift
PLAYLIST_INVERT_SELECTION (104, 111) + _SELECTED (127, 111)
PLAYLIST_SELECT_ZERO (104, 130) + _SELECTED (127, 130)
PLAYLIST_SELECT_ALL (104, 149) + _SELECTED (127, 149)
```

### Verification

**Total Menu Sprites:** 32 (16 normal + 16 selected)
- ADD: 6 sprites ✅
- REM: 8 sprites ✅
- SEL: 6 sprites ✅
- MISC: 6 sprites ✅
- LIST: 6 sprites ✅

All sprites correctly mapped to PLEDIT.BMP coordinates.

---

## Phase 2: Menu Components ✅

### Created: SpriteMenuItem.swift

**File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

**Purpose:** Custom NSMenuItem that displays sprites and tracks hover state

**Architecture:**
```
SpriteMenuItem (NSMenuItem subclass)
  ├── NSHostingView wrapper
  │   └── SpriteMenuItemView (SwiftUI)
  │       └── SimpleSpriteImage (sprite renderer)
  └── NSTrackingArea (hover detection)
```

**Key Features:**
- SwiftUI sprite rendering via NSHostingView
- Hover detection using NSTrackingArea
- Automatic sprite swap on mouseEntered/mouseExited
- Size: 22 × 18 pixels (matches PLEDIT.BMP)

**Implementation Details:**
- `mouseEntered()` sets `isHovered = true` → shows selected sprite
- `mouseExited()` sets `isHovered = false` → shows normal sprite
- `updateView()` refreshes SwiftUI view with new hover state

### Created: PlaylistMenuButton.swift

**File:** `MacAmpApp/Views/Components/PlaylistMenuButton.swift`

**Purpose:** Reusable menu button component with NSMenu popup

**Architecture:**
```
PlaylistMenuButton (NSViewRepresentable)
  ├── NSView container (22×18px)
  │   └── NSButton (transparent click target)
  └── Coordinator (NSObject, NSMenuDelegate)
      ├── Button click handler
      ├── Menu creation/dismissal
      └── Menu item action routing
```

**Key Features:**
- Click to toggle menu (matches Winamp behavior)
- NSMenu for native macOS popup behavior
- NSMenuDelegate for close detection
- Binds to @State for menu open/close tracking
- Action closure execution on menu item selection

**Usage Pattern:**
```swift
@State private var addMenuOpen = false

PlaylistMenuButton(
    position: CGPoint(x: 14, y: 12),
    menuItems: [
        PlaylistMenuItem(
            normalSprite: "PLAYLIST_ADD_URL",
            selectedSprite: "PLAYLIST_ADD_URL_SELECTED",
            action: { /* add URL logic */ }
        ),
        // ... more items
    ],
    isOpen: $addMenuOpen
)
```

---

## Technical Decisions

### Why NSMenu Instead of SwiftUI Overlay?

**Chosen: NSMenu with custom views**

**Pros:**
✅ Native macOS popup positioning and behavior
✅ Automatic shadows and system integration
✅ Built-in dismiss on click-away
✅ Keyboard navigation support
✅ Window z-ordering handled by system

**Cons:**
⚠️ Requires NSViewRepresentable bridging
⚠️ SwiftUI sprites need NSHostingView wrapper
⚠️ Hover tracking needs NSTrackingArea

**Alternative (Not Chosen): Pure SwiftUI Overlay**

**Pros:**
✅ No AppKit bridging
✅ Pure SwiftUI code

**Cons:**
❌ Manual popup positioning
❌ Manual click-away detection
❌ Manual z-ordering
❌ No keyboard navigation
❌ More complex implementation

**Decision:** NSMenu approach provides better UX with native macOS behavior.

### Hover Detection Approach

**Chosen: NSTrackingArea in SpriteMenuItem**

**Why:**
- Direct hover events via mouseEntered/mouseExited
- No polling or timers needed
- Matches webamp's "we implement hover ourselves" approach
- Reliable hover state updates

**Alternative (Not Chosen): SwiftUI .onHover**

**Why Not:**
- Doesn't work reliably in NSMenuItem custom views
- NSMenu owns event handling
- Would need complex event forwarding

---

## Known Limitations & TODOs

### Phase 2 Limitations

**TODO: SkinManager Environment**
- SpriteMenuItemView needs @EnvironmentObject var skinManager
- Must ensure SkinManager is in environment when creating menu
- May need to pass SkinManager explicitly instead

**TODO: Testing Hover**
- Hover sprite swap not yet tested with actual NSMenu
- May need adjustments to tracking area setup
- Verify mouseEntered/Exited fire correctly in menu context

**TODO: Menu Positioning**
- Current: Menu pops up above button
- May need adjustment based on screen position
- Should verify doesn't go off-screen

### Future Phase TODOs

**Phase 3: Menu Actions**
- Need to implement 12+ action closures
- Some actions need dialogs (URL input, file pickers)
- Some need new AudioPlayer methods

**Phase 4: Selection State**
- Need @State var selectedTrackIndices: Set<Int>
- Need multi-select UI (Cmd+Click, Shift+Click)
- Need visual selection indicator

**Phase 5: M3U I/O**
- Need M3U parser (simple text format)
- Need M3U writer
- Need file save/open dialogs

---

## Build Status

**Compilation:** ✅ SUCCESS
- SpriteMenuItem.swift compiles cleanly
- PlaylistMenuButton.swift compiles cleanly
- No compiler errors or warnings

**Not Yet Integrated:** Components created but not used in WinampPlaylistWindow yet

**Next:** Integrate one menu button as proof-of-concept before implementing all 5

---

## Files Modified/Created

**Modified:**
1. `MacAmpApp/Models/SkinSprites.swift` - Fixed REM coordinates, added SEL menu

**Created:**
2. `MacAmpApp/Views/Components/SpriteMenuItem.swift` - Hover-sensitive menu items
3. `MacAmpApp/Views/Components/PlaylistMenuButton.swift` - Menu button with NSMenu

**Documentation:**
4. `tasks/playlist-menu-system/sprite_audit.md` - Audit report
5. `tasks/playlist-menu-system/implementation_notes.md` - This file

---

**Status:** Ready for Phase 3 (Menu Actions) or integration testing
**Next Decision:** Implement one full menu as POC, or implement all actions first?
