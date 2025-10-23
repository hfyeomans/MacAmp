# Playlist Menu System - Implementation Plan

**Date:** 2025-10-23
**Scope:** Sprite-based popup menus for 4 playlist buttons
**Estimated Time:** 2-3 hours
**Priority:** P2 (enhancement, not critical)

---

## 🎯 Goals

Implement sprite-based popup menus for the 4 baked-in playlist buttons:
1. **ADD** - Add tracks (URL, Dir, File)
2. **REM** - Remove tracks (All, Selected, Crop)
3. **SEL** - Selection operations (All, None, Invert)
4. **MISC** - List management (New, Save, Load)

---

## 🏗️ Architecture Design

### Approach: NSMenu with Sprite-Based Items

**Why NSMenu:**
- Native macOS popup behavior
- Proper positioning and shadows
- Keyboard navigation built-in
- System dismiss handling

**Custom Sprite Rendering:**
- Use NSMenuItem with custom view
- SwiftUI sprite views bridged via NSHostingView
- Hover state via NSMenu delegate

### Component Structure
```
PlaylistMenuButton (reusable component)
  ├─ Button (transparent click target)
  ├─ NSMenu (popup on click)
  └─ MenuItem views (sprite-based with hover)
      ├─ Normal sprite (default)
      └─ Selected sprite (on hover)
```

---

## 📐 Implementation Phases

### Phase 1: Create SpriteMenuItem Component (45 min)

**File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

```swift
import SwiftUI
import AppKit

/// Sprite-based menu item view that swaps sprites on hover
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHovered: Bool

    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        SimpleSpriteImage(
            isHovered ? selectedSprite : normalSprite,
            width: 22,
            height: 18
        )
    }
}

/// NSMenuItem wrapper with sprite-based view and hover tracking
class SpriteMenuItem: NSMenuItem {
    private var isHovered = false
    private let normalSprite: String
    private let selectedSprite: String

    init(normalSprite: String, selectedSprite: String, action: Selector?) {
        self.normalSprite = normalSprite
        self.selectedSprite = selectedSprite
        super.init(title: "", action: action, keyEquivalent: "")

        // Create SwiftUI view
        let hostingView = NSHostingView(
            rootView: SpriteMenuItemView(
                normalSprite: normalSprite,
                selectedSprite: selectedSprite,
                isHovered: isHovered
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 22, height: 18)
        self.view = hostingView
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
```

### Phase 2: Create PlaylistMenuButton Component (1 hour)

**File:** `MacAmpApp/Views/Components/PlaylistMenuButton.swift`

```swift
struct PlaylistMenuButton: View {
    let position: CGPoint
    let menuItems: [(normal: String, selected: String, action: () -> Void)]

    @State private var showingMenu = false

    var body: some View {
        Button(action: { showMenu() }) {
            Color.clear
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: position.x, y: position.y)
    }

    private func showMenu() {
        let menu = NSMenu()

        for (normal, selected, action) in menuItems {
            let item = SpriteMenuItem(
                normalSprite: normal,
                selectedSprite: selected,
                action: #selector(handleAction)
            )
            item.target = self
            menu.addItem(item)
        }

        // Show menu at button position
        menu.popUp(positioning: nil, at: position, in: view)
    }

    @objc private func handleAction(_ sender: NSMenuItem) {
        // Execute corresponding action
    }
}
```

### Phase 3: Implement Menu Actions (1 hour)

**ADD Menu Actions:**
- ADD URL: Show NSAlert with text input, add via `audioPlayer.addTrack(url:)`
- ADD DIR: Use NSOpenPanel with `.canChooseDirectories`, add all audio files
- ADD FILE: Already implemented in `openFileDialog()` ✅

**REM Menu Actions:**
- REMOVE ALL: `audioPlayer.playlist.removeAll()`
- CROP: Keep only tracks in `selectedTrackIndices`, remove others
- REMOVE SELECTED: Remove tracks at `selectedTrackIndices`

**SEL Menu Actions:**
- INVERT: Toggle selection state for all tracks
- SELECT ZERO: Clear `selectedTrackIndices`
- SELECT ALL: Set `selectedTrackIndices` to all indices

**MISC Menu Actions:**
- NEW LIST: `audioPlayer.playlist.removeAll()`
- SAVE LIST: Export to .m3u format
- LOAD LIST: Parse .m3u and add tracks

### Phase 4: Update WinampPlaylistWindow (30 min)

Replace current button code with PlaylistMenuButton:

```swift
PlaylistMenuButton(
    position: CGPoint(x: 25, y: 206),
    menuItems: [
        ("PLAYLIST_ADD_URL", "PLAYLIST_ADD_URL_SELECTED", { addURL() }),
        ("PLAYLIST_ADD_DIR", "PLAYLIST_ADD_DIR_SELECTED", { addDirectory() }),
        ("PLAYLIST_ADD_FILE", "PLAYLIST_ADD_FILE_SELECTED", { openFileDialog() }),
    ]
)
```

---

## ⚠️ Complexity Assessment

### Required Features
1. ✅ Sprite definitions (already in SkinSprites.swift)
2. ❌ Custom NSMenuItem with sprite views
3. ❌ Hover state tracking
4. ❌ Menu positioning logic
5. ❌ 12+ menu action implementations
6. ❌ Selection state management (track multi-select)
7. ❌ .m3u playlist import/export

### Estimated Time
- **Simple version** (4 menus, basic actions): 2-3 hours
- **Full version** (with submenus, all actions): 4-5 hours

### Dependencies
- **New:** Multi-track selection state (@State var selectedTrackIndices)
- **New:** Playlist file I/O (.m3u parser/writer)
- **New:** URL input dialog
- **New:** Directory picker

---

## 🤔 Scope Decision

### Option A: Implement Now (2-3 hours)
- Full feature parity with Webamp
- Complete playlist functionality
- Delays merge by 1 session

### Option B: MVP Now, Full Later (1 hour)
- Implement ADD FILE menu only (already has logic)
- Defer other menus to future task
- Can merge sooner

### Option C: Defer Entirely (5 min)
- Document as future enhancement
- Merge current work as-is
- Tackle in separate "playlist-menus" task

---

**Research Status:** ✅ COMPLETE
**Decision Required:** Choose Option A, B, or C
**Recommendation:** Option C (defer) - current playlist sync is complete and functional
