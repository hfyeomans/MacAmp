# Playlist Menu System - Research

**Date:** 2025-10-23
**Task:** Implement sprite-based popup menus for playlist bottom buttons
**Status:** Research in progress

---

## 🎯 Requirements

### Baked-In Buttons (in PLAYLIST_BOTTOM_LEFT_CORNER sprite)
5 visible buttons at bottom of playlist window:
1. **ADD** - Add tracks to playlist
2. **REM** - Remove tracks from playlist
3. **SEL** - Selection operations
4. **MISC** - Miscellaneous options
5. **LIST OPTS** - List operations (may be same as MISC?)

### Menu Item Sprites (PLEDIT.BMP)

Each button has 3 menu items (12 total), each with normal/selected states:

#### ADD Menu (Column X:0, Selected at X:23)
- **ADD URL** (0,111 / 23,111) - Add track from URL
- **ADD DIR** (0,130 / 23,130) - Add directory of tracks
- **ADD FILE** (0,149 / 23,149) - Add file(s) via file picker

#### REM Menu (Column X:54, Selected at X:77)
- **REM ALL** (54,111 / 77,111) - Remove all tracks
- **CROP** (54,130 / 77,130) - Keep only selected tracks
- **REM SEL** (54,149 / 77,149) - Remove selected tracks

#### SEL Menu (Column X:154, Selected at X:177)
- **SORT LIST** (154,111 / 177,111) - Sort playlist
- **FILE INFO** (154,130 / 177,130) - Show file information
- **MISC OPTIONS** (154,149 / 177,149) - Miscellaneous options

#### MISC Menu (Column X:204, Selected at X:227)
- **NEW LIST** (204,111 / 227,111) - Clear and start new playlist
- **SAVE LIST** (204,130 / 227,130) - Save playlist to file
- **LOAD LIST** (204,149 / 227,149) - Load playlist from file

All menu items: 22×18px

---

## 🏗️ Architecture Requirements

### 1. Hover State Management
- Mouse over menu item → show SELECTED sprite
- Mouse away → show normal sprite
- Requires mouse tracking in SwiftUI or NSMenu customization

### 2. Menu Display
- Click baked-in button → show popup menu
- Menu positioned above button
- Menu contains 3 sprite-based items

### 3. Sprite-Based Menu Items
- Not standard NSMenuItem text
- Each item renders its sprite (22×18px)
- Sprite switches on hover

### 4. Multi-Skin Compatibility
- Uses PLEDIT.BMP sprites from current skin
- Menu appearance adapts per skin automatically

---

## 🔍 Webamp Reference (Analysis Pending)

**Files to check:**
- `webamp_clone/packages/webamp/js/playlistHtml.tsx`
- `webamp_clone/packages/webamp/js/actionCreators/playlist.ts`
- `webamp_clone/packages/webamp/js/reducers/playlist.ts`

**Questions:**
1. Are menus shown on click or hover?
2. How are hover states managed?
3. What does each menu action do?
4. How are sprite-based menu items rendered in React?

---

## 💡 Implementation Approaches

### Approach 1: NSMenu with Custom Views (macOS Native)
**Pros:**
- Native macOS popup behavior
- Proper keyboard navigation
- System integration (shadows, animations)

**Cons:**
- Complex to add custom sprite views to NSMenuItem
- May need NSHostingView to bridge SwiftUI sprites
- Hover tracking requires NSMenu delegate methods

### Approach 2: Custom SwiftUI Overlay Menu
**Pros:**
- Full control over sprite rendering
- Easy hover state with .onHover modifier
- Can match Winamp appearance exactly

**Cons:**
- Must implement popup positioning manually
- Must handle dismiss on click-outside
- No native keyboard navigation
- More code to maintain

### Approach 3: Hybrid (NSMenu structure, sprite labels)
**Pros:**
- Best of both worlds
- Native menu behavior
- Sprite-based appearance

**Cons:**
- Most complex implementation
- Requires bridging layer

---

## 📋 Menu Action Specifications (✅ CONFIRMED via Gemini + Webamp)

### ADD Menu
- **ADD URL:** Input dialog for URL, download and add track (`addFilesFromUrl` action)
- **ADD DIR:** Directory picker, add all audio files (`addDirAtIndex` action)
- **ADD FILE:** File picker, add selected files (`addFilesAtIndex` action) ← **Already implemented!**

### REM Menu
- **REMOVE ALL:** Clear entire playlist (`removeAllTracks` action)
- **CROP:** Keep only selected tracks, remove others (`crop` action)
- **REMOVE SELECTED:** Remove currently selected tracks (`removeSelectedTracks` action)
- ~~**REMOVE MISC:** Not implemented in Webamp (shows alert)~~

### SEL Menu
- **INVERT SELECTION:** Deselect selected, select unselected (`invertSelection` action)
- **SELECT ZERO:** Clear all selections (`selectZero` action)
- **SELECT ALL:** Select all tracks (`selectAll` action)
- ~~**SORT LIST:** Shows at position but has submenu~~
- ~~**FILE INFO:** Not implemented in Webamp (shows alert)~~
- ~~**MISC OPTIONS:** Has submenu with advanced options~~

### MISC Menu
- **NEW LIST:** Clear playlist and start fresh (same as REMOVE ALL?)
- **SAVE LIST:** Export playlist to .m3u/.pls file (file save dialog)
- **LOAD LIST:** Import playlist from file (file open dialog)
- **SORT LIST:** Submenu with sort options (by title, filename, path, random)
- **FILE INFO:** Show track metadata (not implemented in Webamp)
- **MISC OPTIONS:** Submenu with advanced options

---

## ✅ Webamp Implementation Details

### Menu Display Behavior
- **Trigger:** Click on button (not hover)
- **Positioning:** Dropdown appears above/below button
- **Dismiss:** Click outside menu or select item

### Hover State Implementation
- **Method:** JavaScript adds/removes `.hover` class
- **Comment:** `"We implement hover ourselves, because we hate ourselves..."`
- **Sprite Swap:** `.hover` class shows SELECTED sprite variant

### Component Architecture (React)
```
PlaylistMenu (generic container)
  ├─ AddMenu (3 items)
  ├─ RemoveMenu (3-4 items)
  ├─ SelectionMenu (3 items)
  └─ MiscMenu (3+ items with submenus)
```

---

**Research Status:** ✅ COMPLETE
**Next:** Design SwiftUI implementation plan
