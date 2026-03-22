# Phase 3: NSMenuDelegate Pattern Implementation

**Date Started:** 2025-10-29
**Branch:** feature/phase3-nsmenu-delegate
**Status:** Ready to implement
**Estimated Time:** 2-3 hours

---

## Objective

Replace manual HoverTrackingView with NSMenuDelegate pattern to enable keyboard navigation and VoiceOver support in sprite-based menus.

---

## Current State

**File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

**Current Architecture:**
- HoverTrackingView class (lines 12-45) - Custom NSView for hover detection
- SpriteMenuItem wraps sprites in HoverTrackingView
- Only supports mouse hover, NO keyboard navigation
- NO VoiceOver support

**Menu Locations:**
- **WinampPlaylistWindow.swift** - 13 sprite menu items:
  - ADD menu: Add URL, Add Directory, Add Files
  - REM menu: Remove Misc, Remove All, Crop, Remove Selected
  - SEL menu: Sort, File Info, Misc Options
  - LIST menu: New List, Save List, Load List

---

## Implementation Plan

### Step 1: Create PlaylistMenuDelegate

**New File:** `MacAmpApp/Views/Components/PlaylistMenuDelegate.swift`

```swift
import AppKit

/// Delegate that manages highlighting for sprite-based menu items
/// Handles both mouse hover and keyboard navigation (arrow keys)
@MainActor
final class PlaylistMenuDelegate: NSObject, NSMenuDelegate {
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        // Update all sprite menu items in the menu
        for menuItem in menu.items {
            if let sprite = menuItem as? SpriteMenuItem {
                sprite.isHighlighted = (menuItem === item)
            }
        }
    }
}
```

**Why This Works:**
- `menu(_:willHighlight:)` called by NSMenu for BOTH mouse and keyboard
- Arrow keys automatically trigger highlighting via AppKit
- Enter key activates highlighted item
- Escape dismisses menu

---

### Step 2: Refactor SpriteMenuItem

**File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

**Changes:**
1. **Delete** HoverTrackingView class (lines 12-45) - ~34 lines removed
2. **Rename** `isHovered` → `isHighlighted` (semantic clarity)
3. **Make** `isHighlighted` **public** (delegate sets it)
4. **Remove** HoverTrackingView container
5. **Simplify** setupView() to create NSHostingView directly

**Before (Current):**
```swift
final class SpriteMenuItem: NSMenuItem {
    private var hoverTrackingView: HoverTrackingView?
    private var isHovered: Bool = false

    private func setupView() {
        let container = HoverTrackingView(...)  // ❌ Complex
        container.onHoverChanged = { [weak self] in ... }
        let hosting = NSHostingView(...)
        container.addSubview(hosting)
        self.view = container
    }
}
```

**After (Phase 3):**
```swift
@MainActor
final class SpriteMenuItem: NSMenuItem {
    // Public property for delegate to set
    var isHighlighted: Bool = false {
        didSet { updateView() }
    }

    private func setupView() {
        let spriteView = SpriteMenuItemView(...)  // ✅ Simple
        let hosting = NSHostingView(rootView: spriteView)
        self.view = hosting  // Direct assignment
    }
}
```

**Net Change:** ~30 lines removed (cleaner code)

---

### Step 3: Update WinampPlaylistWindow

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Add Delegate to Struct:**
```swift
struct WinampPlaylistWindow: View {
    // ...existing properties

    @State private var menuDelegate = PlaylistMenuDelegate()  // NEW
```

**Update Menu Creation (13 locations):**
```swift
// Example for ADD button menu
private func createAddMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = menuDelegate  // ✅ ADD THIS LINE

    // Create menu items (unchanged)
    let addURLItem = SpriteMenuItem(...)
    let addDirItem = SpriteMenuItem(...)
    let addFileItem = SpriteMenuItem(...)

    menu.addItem(addURLItem)
    menu.addItem(addDirItem)
    menu.addItem(addFileItem)

    return menu
}
```

**Menus to Update:**
1. ADD button menu (lines ~567-605)
2. REM button menu (lines ~610-665)
3. SEL button menu (lines ~670-705)
4. LIST button menu (lines ~711-745)

---

### Step 4: Update SpriteMenuItemView

**File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

**Rename for Semantic Clarity:**
```swift
struct SpriteMenuItemView: View {
    let normalSprite: String
    let selectedSprite: String
    let isHighlighted: Bool  // ← Rename from isHovered
    let skinManager: SkinManager

    var body: some View {
        if let image = skinManager.currentSkin?.images[isHighlighted ? selectedSprite : normalSprite] {
            Image(nsImage: image)
                .interpolation(.none)
                .antialiased(false)
                .resizable()
                .frame(width: 22, height: 18)
        } else {
            Color.gray.frame(width: 22, height: 18)
        }
    }
}
```

---

## Testing Plan

### Keyboard Navigation Test
```
1. Click ADD button (menu appears)
2. Press ↓ Arrow - menu item should highlight
3. Press ↓ Arrow again - next item highlights
4. Press ↑ Arrow - previous item highlights
5. Press Enter - selected item activates
6. Press Escape - menu dismisses
```

### VoiceOver Test
```
1. Enable VoiceOver (⌘F5)
2. Click ADD button
3. Press ↓ Arrow
4. VoiceOver should announce: "Add URL, menu item"
5. Press ↓ Arrow
6. VoiceOver should announce: "Add Directory, menu item"
```

### Mouse Test (Still Works)
```
1. Click ADD button
2. Hover over items - should highlight
3. Click item - should activate
4. Verify no regression from current behavior
```

---

## Success Criteria

- [ ] Keyboard navigation works (arrow keys)
- [ ] Enter activates highlighted item
- [ ] Escape dismisses menu
- [ ] VoiceOver reads menu items
- [ ] Mouse hover still works
- [ ] No visual regressions
- [ ] Code is cleaner (HoverTrackingView removed)
- [ ] All 4 menus work (ADD, REM, SEL, LIST)

---

## Files to Modify

1. **NEW:** `MacAmpApp/Views/Components/PlaylistMenuDelegate.swift` (~20 lines)
2. **MODIFY:** `MacAmpApp/Views/Components/SpriteMenuItem.swift` (-30 lines, +10 lines)
3. **MODIFY:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (~4 lines added for delegate)

**Total Changes:** ~3 files, net -20 lines (cleaner code)

---

## Commit Message

```
feat: Add NSMenuDelegate for keyboard navigation and VoiceOver

Phase 3: Accessibility and Keyboard Navigation
- Create PlaylistMenuDelegate (NSMenuDelegate pattern)
- Replace HoverTrackingView with delegate pattern
- Enable keyboard navigation (arrow keys, Enter, Escape)
- Add VoiceOver support for menu items
- Simplify SpriteMenuItem (remove 30 lines)

Benefits:
- Keyboard navigation in sprite menus
- VoiceOver accessibility
- Cleaner code (removed HoverTrackingView)
- Better AppKit integration

Testing:
- Keyboard: Arrow keys navigate, Enter activates
- VoiceOver: Announces menu items correctly
- Mouse: Hover and click still work

Files:
- NEW: PlaylistMenuDelegate.swift
- MacAmpApp/Views/Components/SpriteMenuItem.swift (-20 lines)
- MacAmpApp/Views/WinampPlaylistWindow.swift (+4 lines)
```

---

## Risk Assessment

**Risk Level:** LOW

**Why:**
- NSMenuDelegate is standard AppKit pattern
- Only affects menu behavior (not core playback)
- Easy to rollback (delete delegate, restore HoverTrackingView)
- Well-documented pattern

---

## Next After Phase 3

**Optional Polish:**
- Async file panel wrappers (if needed)
- Code cleanup
- Documentation updates

**Or Done!** - All planned phases complete

---

**Status:** ✅ Phase 2 merged | ⏳ Phase 3 ready to implement
**Branch:** feature/phase3-nsmenu-delegate
**Time:** ~2-3 hours
