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
5. **LIST OPTS** - List operations

### PLEDIT.BMP File Structure

**File Details:**
- **Dimensions:** 280 × 186 pixels
- **Format:** 8-bit paletted BMP
- **Button Area:** Y-coordinates 111-186 (bottom 75 pixels)
- **Organization:** 5 button sections in columns, separated by 3px grey dividers

**Layout Pattern:**
```
[ADD Section] | [REM Section] | [SEL Section] | [MISC Section] | [LIST Section]
X: 0-45      48 X: 54-99    100 X: 104-149  150 X: 154-199  200 X: 204-249
   |  48px divider  |  50px divider  |  4px divider   |  4px divider   |
```

**Row Structure:**
- **Row 1 (Y:111):** First menu item for each button
- **Row 2 (Y:130):** Second menu item (19px spacing)
- **Row 3 (Y:149):** Third menu item (19px spacing)
- **Row 4 (Y:168):** Fourth menu item (REM menu only)

**State Pattern:**
- **Normal State:** Lighter grey sprites
- **Selected State:** Darker grey sprites (+23px X-offset)

### Menu Item Sprites (Complete Coordinates)

Each button has 3-4 menu items, each with normal/selected states:

#### ADD Menu (Column X:0, Normal / X:23, Selected)

| Menu Item | Normal | Selected | Description |
|-----------|---------|----------|-------------|
| **ADD URL** | (0, 111, 22, 18) | (23, 111, 22, 18) | Add track from URL |
| **ADD DIR** | (0, 130, 22, 18) | (23, 130, 22, 18) | Add directory of tracks |
| **ADD FILE** | (0, 149, 22, 18) | (23, 149, 22, 18) | Add file(s) via file picker |

#### REM Menu (Column X:54, Normal / X:77, Selected)

| Menu Item | Normal | Selected | Description |
|-----------|---------|----------|-------------|
| **REM MISC** | (54, 111, 22, 18) | (77, 111, 22, 18) | Remove misc (not implemented) |
| **REM ALL** | (54, 130, 22, 18) | (77, 130, 22, 18) | Remove all tracks |
| **CROP** | (54, 149, 22, 18) | (77, 149, 22, 18) | Keep only selected tracks |
| **REM SEL** | (54, 168, 22, 18) | (77, 168, 22, 18) | Remove selected tracks |

**Note:** REM menu has 4 items (only menu with row 4)

#### SEL Menu (Column X:104, Normal / X:127, Selected)

| Menu Item | Normal | Selected | Description |
|-----------|---------|----------|-------------|
| **INVERT SELECTION** | (104, 111, 22, 18) | (127, 111, 22, 18) | Invert track selection |
| **SELECT ZERO** | (104, 130, 22, 18) | (127, 130, 22, 18) | Deselect all tracks |
| **SELECT ALL** | (104, 149, 22, 18) | (127, 149, 22, 18) | Select all tracks |

#### MISC Menu (Column X:154, Normal / X:177, Selected)

| Menu Item | Normal | Selected | Description |
|-----------|---------|----------|-------------|
| **SORT LIST** | (154, 111, 22, 18) | (177, 111, 22, 18) | Sort playlist (submenu) |
| **FILE INFO** | (154, 130, 22, 18) | (177, 130, 22, 18) | Show file information |
| **MISC OPTIONS** | (154, 149, 22, 18) | (177, 149, 22, 18) | Misc options (submenu) |

#### LIST Menu (Column X:204, Normal / X:227, Selected)

| Menu Item | Normal | Selected | Description |
|-----------|---------|----------|-------------|
| **NEW LIST** | (204, 111, 22, 18) | (227, 111, 22, 18) | Clear and start new playlist |
| **SAVE LIST** | (204, 130, 22, 18) | (227, 130, 22, 18) | Save playlist to file |
| **LOAD LIST** | (204, 149, 22, 18) | (227, 149, 22, 18) | Load playlist from file |

### Vertical Divider Bars

| Divider | X-Position | Width | Height | Between |
|---------|-----------|-------|--------|---------|
| Divider 1 | 48 | 3px | 54px | ADD - REM |
| Divider 2 | 100 | 3px | 72px | REM - SEL (taller for 4 items) |
| Divider 3 | 150 | 3px | 54px | SEL - MISC |
| Divider 4 | 200 | 3px | 54px | MISC - LIST |

**All sprites: 22 × 18 pixels**

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

## ✅ Webamp Implementation Details (COMPREHENSIVE)

### File Locations

**Core Components:**
1. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/PlaylistMenu.tsx` - Base menu container
2. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/PlaylistMenuEntry.tsx` - Menu item with hover
3. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/AddMenu.tsx` - ADD menu
4. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/RemoveMenu.tsx` - REM menu
5. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/SelectionMenu.tsx` - SEL menu
6. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/MiscMenu.tsx` - MISC menu
7. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/components/PlaylistWindow/ListMenu.tsx` - LIST menu
8. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/js/actionCreators/playlist.ts` - Actions
9. `/Users/hank/dev/src/MacAmp/webamp_clone/packages/webamp/css/playlist-window.css` - Button positioning

### Button Positioning (CSS-based)

```css
/* All buttons: 22px × 18px, positioned 12px from bottom */
#playlist-add-menu { left: 14px; }      /* ADD */
#playlist-remove-menu { left: 43px; }   /* REM - 29px spacing */
#playlist-selection-menu { left: 72px; } /* SEL - 29px spacing */
#playlist-misc-menu { left: 101px; }    /* MISC - 29px spacing */
#playlist-list-menu { right: 22px; }    /* LIST OPTS - right-aligned */
```

### Menu Display Behavior

**Click to Open:**
```tsx
onClick={() => setSelected((selected_) => !selected_)}
```

**Click-Away to Close:**
```tsx
useOnClickAway(ref, selected ? callback : null);
// setTimeout delay prevents premature close when clicking context menus
```

**Vertical Bar Indicator:**
```tsx
<div className="bar" />
/* Shows when menu is open */
/* Height: 54px (3 items) or 72px (4 items for REM) */
```

### Hover State Implementation

```tsx
// PlaylistMenuEntry.tsx
const { ref, hover } = useIsHovered();
<li ref={ref} className={classnames({ hover })}>
```

**Quote from code:** `"We implement hover ourselves, because we hate ourselves..."`
- CSS :hover unreliable in this context
- JavaScript hover tracking required
- Applies `.hover` class for sprite swap

### Sprite System

**All sprites embedded as base64 PNG data URLs in CSS:**

```css
/* Normal state */
.add-url { background-image: url(data:image/png;base64,...); }

/* Hover state */
.hover .add-url { background-image: url(data:image/png;base64,...); }
```

**Pattern:**
- Normal sprite: Default background-image
- Hover sprite: `.hover .class-name` selector
- Each menu item: 22 × 18 pixels

### Complete Menu Actions

**ADD Menu (3 items):**
1. **Add URL** → `addFilesFromUrl(nextIndex)` - URL input dialog
2. **Add Directory** → `addDirAtIndex(nextIndex)` - Directory picker
3. **Add File** → `addFilesAtIndex(nextIndex)` - File picker

**REM Menu (4 items):**
1. **Remove Misc** → `alert()` - Not implemented
2. **Remove All** → `removeAllTracks()` - Clear playlist
3. **Crop** → `cropPlaylist()` - Keep only selected
4. **Remove Selected** → `removeSelectedTracks()` - Remove selected

**SEL Menu (3 items):**
1. **Invert Selection** → `invertSelection()` - Toggle selection
2. **Select Zero** → `selectZero()` - Deselect all
3. **Select All** → `selectAll()` - Select all

**MISC Menu (3 items + submenus):**
1. **Sort List** → Opens context menu:
   - Sort by title
   - Reverse list
   - Randomize list
2. **File Info** → `alert()` - Not implemented
3. **Misc Options** → Opens context menu:
   - Generate HTML playlist

**LIST Menu (3 items):**
1. **New List** → `removeAllTracks()` - Clear playlist
2. **Save List** → `saveFilesToList()` - Export .m3u/.pls
3. **Load List** → `addFilesFromList()` - Import playlist

### Component Architecture (React)

```
PlaylistMenu (base component)
  - useState for open/closed state
  - useOnClickAway for dismiss behavior
  - Renders vertical bar when open
  - Wraps children in PlaylistMenuEntry

PlaylistMenuEntry (menu item wrapper)
  - useIsHovered hook for hover detection
  - Applies .hover class to swap sprites
  - Single <li> wrapper for each item

Individual Menus (AddMenu, RemoveMenu, etc.)
  - useTypedSelector for Redux state
  - useActionCreator for Redux dispatch
  - Click handlers call Redux actions
```

### Context Menu Pattern

For nested menus (Sort, Misc Options):
```tsx
<div className="sort-list" onClick={(e) => e.stopPropagation()}>
  <SortContextMenu />
</div>
```

**stopPropagation()** prevents parent menu from closing when context menu clicked.

---

**Research Status:** ✅ COMPREHENSIVE - Ready for implementation
**Next:** Create todo.md with implementation tasks
