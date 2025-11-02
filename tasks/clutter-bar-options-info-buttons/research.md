# Clutter Bar O and I Buttons - Research

**Date:** 2025-11-02
**Feature:** Options Menu (O Button) and Track Info Dialog (I Button)
**Reference Task:** tasks/done/double-size-button/
**Status:** Research Complete

---

## 🎯 Objective

Implement the remaining non-functional clutter bar buttons (O and I) following the proven pattern from the double-size-button implementation.

**Current State:**
- ✅ D button (Double-size mode) - FUNCTIONAL
- ✅ A button (Always on top) - FUNCTIONAL
- ❌ O button (Options menu) - SCAFFOLDED, NOT FUNCTIONAL
- ❌ I button (Track info dialog) - SCAFFOLDED, NOT FUNCTIONAL
- ❌ V button (Visualization) - SCAFFOLDED, NOT FUNCTIONAL (out of scope)

---

## 📚 Double-Size Button Pattern Review

### Implementation Pattern (Proven)

From `tasks/done/double-size-button/COMPLETION_SUMMARY.md`, the successful pattern:

1. **State Management** (AppSettings.swift)
   - Add `@Observable` property with `didSet` persistence
   - Use UserDefaults for persistence (not `@AppStorage`)
   - Maintain reactivity with manual didSet

2. **Sprite System** (SkinSprites.swift)
   - Normal and selected sprites MUST have different coordinates
   - Extract from TITLEBAR.BMP at specific offsets
   - Already defined: O/O_SELECTED, I/I_SELECTED sprites

3. **Button Integration** (WinampMainWindow.swift)
   - Use existing `buildClutterBarButtons()` scaffolding
   - Replace `.disabled(true)` with functional Button logic
   - Connect to AppSettings state with `spriteImage()`

4. **Visual Feedback**
   - `isActive` parameter drives sprite selection
   - Normal sprite for inactive state
   - Selected sprite for active/pressed state

**Time:** Original estimate 3-5 days, actual 4 hours (infrastructure existed)

---

## 🔍 Webamp Implementation Analysis

### Source Files Reviewed

1. **webamp_clone/packages/webamp/js/components/MainWindow/ClutterBar.tsx**
2. **webamp_clone/packages/webamp/js/components/OptionsContextMenu.tsx**
3. **webamp_clone/packages/webamp/css/main-window.css**
4. **webamp_clone/packages/webamp/js/skinSelectors.ts**

---

### O Button (Options Menu) - Webamp Implementation

**File:** `ClutterBar.tsx:28-30`

```tsx
<ContextMenuTarget bottom renderMenu={() => <OptionsContextMenu />}>
  <div id="button-o" />
</ContextMenuTarget>
```

**Functionality:**
- Opens context menu on click
- Menu positioned below button (`bottom` prop)
- No toggle state (menu-driven, not stateful)

**Menu Contents** (`OptionsContextMenu.tsx:19-52`):
```
- Skins submenu
- ───────────────
- ☑ Time elapsed (Ctrl+T toggles)
- ☐ Time remaining (Ctrl+T toggles)
- ☑ Double Size (Ctrl+D)
- ───────────────
- ☑ Repeat (R)
- ☑ Shuffle (S)
```

**Key Insight:** O button is **menu-driven**, not toggle-based like D/A buttons

---

### I Button (Track Info Dialog) - Webamp Implementation

**File:** `ClutterBar.tsx:32`

```tsx
<div id="button-i" />
```

**Webamp Status:** ❌ NOT IMPLEMENTED
- No onClick handler
- No functionality
- Just sprite placeholder

**Expected Functionality (Classic Winamp):**
- Opens "File Info" dialog showing track metadata
- Title, artist, album, duration, bitrate, sample rate
- Edit ID3 tags (if writable)
- View technical details

**Design Decision for MacAmp:**
- Show read-only track info dialog/popover
- Display currently playing track metadata
- Clean SwiftUI sheet or popover presentation
- Edit functionality deferred (P3 feature)

---

## 🎨 Sprite Coordinates

**Source:** MacAmpApp/Models/SkinSprites.swift (already defined)

```swift
// O Button (Options) - 8×8 pixels
MAIN_CLUTTER_BAR_BUTTON_O: (x: 304, y: 3, width: 8, height: 8)
MAIN_CLUTTER_BAR_BUTTON_O_SELECTED: (x: 304, y: 47, width: 8, height: 8)

// I Button (Info) - 8×7 pixels
MAIN_CLUTTER_BAR_BUTTON_I: (x: 304, y: 18, width: 8, height: 7)
MAIN_CLUTTER_BAR_BUTTON_I_SELECTED: (x: 304, y: 62, width: 8, height: 7)
```

**Critical Discovery:** Sprites already correctly defined with DIFFERENT coordinates for normal vs selected states (learned from D/A button bug fix)

---

## 🏗️ Current MacAmp Architecture

### File Structure

**Scaffolding Already Exists** (`WinampMainWindow.swift:520-607`):

```swift
// O button (Options) - Placeholder
Button {} label: {
    spriteImage(
        isActive: false,
        normal: .optionsOff,
        selected: .optionsOn
    )
}
.disabled(true)
.accessibilityHidden(true)

// I button (Info) - Placeholder
Button {} label: {
    spriteImage(
        isActive: false,
        normal: .infoOff,
        selected: .infoOn
    )
}
.disabled(true)
.accessibilityHidden(true)
```

**What Needs to Change:**
1. Remove `.disabled(true)` and `.accessibilityHidden(true)`
2. Add action closures
3. Connect to state (O button: menu state, I button: dialog state)
4. Implement UI components (menu and dialog)

---

## 📋 Requirements Analysis

### O Button (Options Menu) Requirements

**Must Have (P0):**
- [x] Context menu appears on click
- [x] Menu positioned below button
- [x] Menu items:
  - Time display mode toggle (elapsed/remaining)
  - Double-size mode toggle (already exists)
  - Repeat toggle (already exists)
  - Shuffle toggle (already exists)
- [x] Checkmarks show current state
- [x] Keyboard shortcuts work (Ctrl+T, Ctrl+D, R, S)

**Should Have (P1):**
- Visual feedback on button press (selected sprite)
- Menu auto-closes after selection
- Click outside menu to dismiss

**Nice to Have (P2):**
- Skins submenu (deferred)
- EQ preset submenu (deferred)
- Preferences dialog option (deferred)

---

### I Button (Track Info) Requirements

- **Must Have (P0):**
  - Dialog shows current track metadata
  - Display fields:
    - Title
    - Artist
    - Duration (MM:SS)
    - Bitrate (if available)
    - Sample rate (if available)
    - Channel layout (Mono/Stereo)
- Close button works
- Dialog dismisses on background click

**Should Have (P1):**
- Visual feedback on button press (selected sprite)
- File path display
- Keyboard shortcut (Ctrl+I)

**Nice to Have (P2):**
- ID3 tag editing (deferred to P3)
- Album artwork thumbnail
- Lyrics display (if available)
- Next/Previous track navigation in dialog

---

## 🎯 Comparison: O vs I Buttons

| Aspect | O Button (Options) | I Button (Info) |
|--------|-------------------|----------------|
| **Type** | Context menu | Modal dialog/sheet |
| **State** | Transient (menu open/closed) | Transient (dialog visible/hidden) |
| **Persistence** | None (menu actions persist their own state) | None (dialog just displays data) |
| **Complexity** | Low (menu structure) | Medium (data binding + UI) |
| **Dependencies** | AppSettings (existing toggles) + AudioPlayer flags | AudioPlayer (current track + telemetry) |
| **Time Estimate** | 1-2 hours | 2-3 hours |

---

## 🔗 Dependencies & Integration Points

### O Button Dependencies

**Existing Components:**
- `AppSettings.isDoubleSizeMode` ✅
- `AudioPlayer.repeatEnabled` ✅
- `AudioPlayer.shuffleEnabled` ✅

**New Components Needed:**
- `AppSettings.timeDisplayMode` (enum: elapsed/remaining)
- NSMenu helper bridged from SwiftUI button
- Keyboard shortcut for Ctrl+T (Control modifier to match clutter bar pattern)

**Integration Point:** WinampMainWindow.swift

---

### I Button Dependencies

**Existing Components:**
- `AudioPlayer.currentTrack` ✅ (struct `Track` with `title`, `artist`, `duration`)
- `AudioPlayer.bitrate`, `sampleRate`, `channelCount` ✅
- `PlaybackCoordinator.currentTitle` (fallback for live stream metadata)

**New Components Needed:**
- `AppSettings.showTrackInfoDialog: Bool` (transient UI flag, no persistence)
- TrackInfoView.swift (new SwiftUI view)
- Sheet presentation logic

**Integration Point:** WinampMainWindow.swift

---

## 🚧 Technical Challenges & Solutions

### Challenge 1: Menu Positioning (O Button)

**Problem:** SwiftUI Menu doesn't support bottom-anchored positioning like webamp's ContextMenuTarget

**Solutions:**
1. **Use SwiftUI Menu** (simplest)
   - Native macOS look and feel
   - Auto-positioning
   - Keyboard navigation built-in
   - ❌ Can't position below button explicitly

2. **Use Custom Popover**
   - Full control over positioning
   - Can anchor below button
   - ❌ More complex implementation

3. **Use NSMenu via AppKit bridge** (recommended)
   - Native context menu behavior
   - Positioning control
   - Keyboard shortcuts work automatically
   - Matches macOS system menus

**Recommended:** NSMenu via AppKit bridge (matches system behavior)

---

### Challenge 2: Metadata Access (I Button)

**Problem:** Need current track details without relying on non-existent album/file-format fields

**Solution:** Use `AudioPlayer` as the source of truth:
- `audioPlayer.currentTrack?.title`
- `audioPlayer.currentTrack?.artist`
- `audioPlayer.currentTrack?.duration`
- `audioPlayer.bitrate` (Int, 0 when unknown)
- `audioPlayer.sampleRate` (Int in Hz, 0 when unknown)
- `audioPlayer.channelCount` (1 mono / 2 stereo)

For streams, fall back to `playbackCoordinator.currentTitle` for display only; no additional metadata is available today.

---

### Challenge 3: Reactivity Pattern

**Problem:** Persisted clutter bar settings require manual didSet persistence, but modal visibility should stay transient to avoid reopening sheets on launch.

**Solution:**
- Continue using didSet + UserDefaults for `timeDisplayMode`.
- Keep `showTrackInfoDialog` as a plain `Bool` without persistence so the dialog behaves like a normal modal.

---

## 📊 Time Estimates

Based on double-size-button actual time (4 hours) and complexity analysis:

### O Button (Options Menu)

| Phase | Task | Time |
|-------|------|------|
| 1 | Add timeDisplayMode to AppSettings | 15 min |
| 2 | Create NSMenu with menu items | 30 min |
| 3 | Wire up Button in WinampMainWindow | 15 min |
| 4 | Connect menu actions to AppSettings | 30 min |
| 5 | Add Ctrl+T keyboard shortcut | 15 min |
| 6 | Testing & visual feedback | 15 min |
| **Total** | | **2 hours** |

### I Button (Track Info Dialog)

| Phase | Task | Time |
|-------|------|------|
| 1 | Add showTrackInfoDialog to AppSettings | 15 min |
| 2 | Create TrackInfoView.swift | 1 hour |
| 3 | Wire up Button in WinampMainWindow | 15 min |
| 4 | Connect sheet presentation | 30 min |
| 5 | Bind track metadata | 30 min |
| 6 | Add Ctrl+I keyboard shortcut | 15 min |
| 7 | Testing & polish | 30 min |
| **Total** | | **3 hours 15 min** |

**Combined Total:** 5 hours 15 minutes

**With Contingency (+20%):** 6.5 hours

---

## 🎓 Lessons Learned from D/A Buttons

### Critical Patterns to Follow

1. **@Observable + didSet for Persistence**
   ```swift
   var someState: Bool = false {
       didSet {
           UserDefaults.standard.set(someState, forKey: "someState")
       }
   }
   ```

2. **Sprite Coordinates Must Differ**
   - Normal and selected sprites need different (x,y)
   - Already fixed in sprite definitions

3. **Button Scaffolding Pattern**
   ```swift
   Button {
       settings.someState.toggle()
   } label: {
       spriteImage(
           isActive: settings.someState,
           normal: .normalSprite,
           selected: .selectedSprite
       )
   }
   ```

4. **Keyboard Shortcuts via AppCommands.swift**
   - Use `.keyboardShortcut()` modifier
   - Update menu items dynamically with @Bindable

5. **Test Thoroughly**
   - Visual feedback (sprite changes)
   - State persistence across launches
   - Keyboard shortcuts
   - All skins (sprite rendering)

---

## 🔬 MacAmp-Specific Considerations

### Unified Window Architecture

**Current:**
- Single NSWindow contains all 3 Winamp windows
- UnifiedDockView as container
- All modals/dialogs must be presented from this window

**Impact on Implementation:**
- O button menu: Attach to main window
- I button sheet: Present from WinampMainWindow
- Both work within unified window paradigm

**Future:** When magnetic-window-docking is implemented, dialogs will need to track which window to present from.

---

### Skin System Compatibility

**Requirement:** O and I buttons must work with ALL skins

**Testing Checklist:**
- [ ] Base skin (MAIN.BMP)
- [ ] Custom skins (different sprite coordinates)
- [ ] Missing sprites (graceful degradation)
- [ ] Double-size mode (buttons scale correctly)

**Sprite Resolution:**
- SpriteResolver handles missing sprites
- Falls back to base skin if custom skin lacks sprites
- Already tested with D/A buttons ✅

---

## 📖 Reference Documentation

### MacAmp Files to Study

1. **AppSettings.swift:139-156**
   - State management pattern with didSet
   - UserDefaults persistence
   - @Observable reactivity

2. **WinampMainWindow.swift:520-607**
   - Button scaffolding (O and I buttons)
   - spriteImage() helper
   - buildClutterBarButtons() structure

3. **AppCommands.swift**
   - Keyboard shortcut infrastructure
   - Dynamic menu labels with @Bindable
   - Window menu integration

4. **PlaybackCoordinator.swift**
   - currentTrack property
   - AudioTrack structure
   - AudioMetadata access

---

### Webamp Files Referenced

1. **ClutterBar.tsx**
   - O button context menu pattern
   - Button layout and structure

2. **OptionsContextMenu.tsx**
   - Menu item structure
   - Checkmark pattern for toggles
   - Hotkey display format

---

## ✅ Research Completion Checklist

- [x] Reviewed double-size-button implementation (all 6 docs)
- [x] Analyzed webamp O button (OptionsContextMenu)
- [x] Analyzed webamp I button (placeholder, not implemented)
- [x] Verified sprite coordinates in SkinSprites.swift
- [x] Identified scaffolding in WinampMainWindow.swift
- [x] Mapped dependencies (AppSettings, PlaybackCoordinator)
- [x] Identified technical challenges (menu positioning, metadata access)
- [x] Estimated implementation time (6.5 hours with contingency)
- [x] Documented lessons learned from D/A buttons
- [x] Created comprehensive requirements list

---

## 🚀 Next Steps

1. **Planning Phase**
   - Create detailed implementation plan (plan.md)
   - Define phases and milestones
   - Identify code changes per file

2. **State Management**
   - Extend AppSettings with new properties
   - Define TimeDisplayMode enum

3. **Implementation**
   - Start with O button (simpler, 2 hours)
   - Then I button (more complex, 3 hours)
   - Test both together

4. **Testing & Documentation**
   - Manual testing checklist
   - Feature documentation
   - User guide updates

---

## 📝 Open Questions

1. **Time Display Toggle:**
   - Q: Where is elapsed/remaining time currently displayed?
   - A: Main window time display (needs investigation)
   - **MIGRATION REQUIRED:** WinampMainWindow.swift currently uses @State private var showRemainingTime. Must migrate to AppSettings.timeDisplayMode and update onTapGesture at line 344

2. **Track Info Dialog Style:**
   - Q: Sheet or Popover presentation?
   - A: Sheet (matches macOS patterns for modal info)

3. **Keyboard Shortcuts:**
   - Q: Do Ctrl+T and Ctrl+I conflict with existing shortcuts?
   - A: Need to verify shortcut map - Note: AppCommands.swift uses .control modifier for clutter bar, not .command

---

**Research Status:** ✅ COMPLETE
**Confidence Level:** HIGH (9/10)
**Ready for Planning:** ✅ YES
**Estimated Implementation Time:** 6.5 hours
