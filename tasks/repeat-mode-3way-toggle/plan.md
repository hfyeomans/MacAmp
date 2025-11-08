# Implementation Plan - Three-State Repeat Mode (Off/All/One)

**Task ID:** repeat-mode-3way-toggle
**Created:** 2025-11-07
**Estimated Time:** 2-3 hours
**Priority:** Medium
**Complexity:** Low-Medium

---

## Overview

Upgrade MacAmp's repeat functionality from boolean (on/off) to three-state enum (off/all/one), matching classic Winamp 5 behavior and exceeding Webamp's functionality.

**Current State:** Boolean repeat (on = loop playlist, off = stop at end)
**Target State:** Enum with three modes:
- **Off:** Stop at playlist end
- **All:** Loop entire playlist
- **One:** Repeat current track indefinitely

---

## Research Summary

### Key Findings (from research.md)

1. **Webamp Implementation:** Boolean only (no repeat-one mode)
2. **Winamp 5 Modern Skins:** Three-state with "1" badge overlay on button
3. **Visual Indicator:** Small white "1" appears on repeat button in one-mode
4. **User Expectation:** Industry standard (iTunes, Spotify, etc. all have repeat-one)
5. **Skin Compatibility:** Classic skins only have 2 button states (normal/selected)

### Validated Approach (from winamp-repeat-mode-history.md)

**Visual Solution:** Option B1 - White "1" badge with shadow overlay
- Matches Winamp 5 Modern skins
- Works across all skin color schemes
- Shadow ensures legibility on light/dark buttons

---

## Implementation Strategy

### Phase 1: Data Model (15 minutes)

**File:** `MacAmpApp/Models/AppSettings.swift`

```swift
// NEW: RepeatMode enum
enum RepeatMode: String, Codable {
    case off = "off"
    case all = "all"
    case one = "one"

    func next() -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }
}

// REPLACE: var repeatMode: Bool
// WITH:
var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}

// UPDATE: init() loader
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    self.repeatMode = .off
}
```

**Migration Strategy:**
- Existing boolean users default to `.off`
- No data loss (clean migration)

### Phase 2: Playlist Navigation Logic (30 minutes)

**File:** `MacAmpApp/Audio/PlaylistManager.swift` (or similar)

**Current getNextTrackId() logic:**
```swift
// Simplified current pattern
if repeatMode {
    nextIndex = (currentIndex + 1) % trackCount  // Wrap around
} else {
    if currentIndex == trackCount - 1 {
        return nil  // Stop at end
    }
    nextIndex = currentIndex + 1
}
```

**NEW three-state logic:**
```swift
func getNextTrackId(offset: Int = 1) -> Track? {
    guard !playlist.isEmpty else { return nil }

    switch appSettings.repeatMode {
    case .off:
        // Stop at playlist boundaries
        let nextIndex = currentIndex + offset
        guard nextIndex >= 0 && nextIndex < playlist.count else {
            return nil
        }
        return playlist[nextIndex]

    case .all:
        // Wrap around using modulo
        let nextIndex = (currentIndex + offset) % playlist.count
        let wrappedIndex = nextIndex < 0 ? nextIndex + playlist.count : nextIndex
        return playlist[wrappedIndex]

    case .one:
        // Always return current track (ignore offset)
        return currentTrack
    }
}
```

**Edge Cases to Handle:**
- Empty playlist → return nil for all modes
- Single track → off/all behave identically, one replays
- Shuffle + Repeat One → Disable shuffle when in repeat-one? (TBD)

### Phase 3: UI - Button Visual (30 minutes)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Current repeat button (approx line 431-438):**
```swift
Button(action: {
    audioPlayer.repeatEnabled.toggle()
}) {
    let spriteKey = audioPlayer.repeatEnabled ? "MAIN_REPEAT_BUTTON_SELECTED" : "MAIN_REPEAT_BUTTON"
    SimpleSpriteImage(spriteKey, width: 28, height: 15)
}
```

**NEW three-state button with badge:**
```swift
Button(action: {
    settings.repeatMode = settings.repeatMode.next()
}) {
    // Base sprite (lit when all or one)
    let isActive = settings.repeatMode != .off
    let spriteKey = isActive ? "MAIN_REPEAT_BUTTON_SELECTED" : "MAIN_REPEAT_BUTTON"

    ZStack {
        SimpleSpriteImage(spriteKey, width: 28, height: 15)

        // "1" badge overlay for repeat-one mode
        if settings.repeatMode == .one {
            Text("1")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
                .offset(x: 8, y: 0)  // Position in button bounds
        }
    }
}
.buttonStyle(.plain)
.help(settings.repeatMode.label)  // Dynamic tooltip
```

**Visual States:**
- Off: Unlit button, no badge
- All: Lit button, no badge
- One: Lit button + "1" badge

**Badge Positioning:**
- `x: 8` centers horizontally in 28px button
- `y: 0` centers vertically in 15px button
- Adjust if needed after visual testing

### Phase 4: Keyboard Shortcut (15 minutes)

**File:** `MacAmpApp/AppCommands.swift`

**Current Ctrl+R shortcut (if exists):**
```swift
Button(settings.repeatMode ? "Disable Repeat" : "Enable Repeat") {
    settings.repeatMode.toggle()
}
.keyboardShortcut("r", modifiers: [.control])
```

**NEW three-state cycling:**
```swift
Button(settings.repeatMode.label) {
    settings.repeatMode = settings.repeatMode.next()
}
.keyboardShortcut("r", modifiers: [.control])
```

**Menu Label Updates:**
- Label changes dynamically: "Repeat: Off" → "Repeat: All" → "Repeat: One"
- Menu shows current mode, clicking advances to next

### Phase 5: Options Menu Integration (15 minutes)

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (O button menu)

**Add to Options menu (if not already present):**
```swift
Menu {
    // ... time display toggle ...

    Divider()

    // Three-state repeat selector
    Button(action: { settings.repeatMode = .off }) {
        Label("Repeat: Off", systemImage: settings.repeatMode == .off ? "checkmark" : "")
    }
    Button(action: { settings.repeatMode = .all }) {
        Label("Repeat: All", systemImage: settings.repeatMode == .all ? "checkmark" : "")
    }
    Button(action: { settings.repeatMode = .one }) {
        Label("Repeat: One", systemImage: settings.repeatMode == .one ? "checkmark" : "")
    }

    Divider()

    // ... shuffle, double-size ...
}
```

**Visual Feedback:**
- Checkmark next to active mode
- Three mutually exclusive options

---

## Testing Strategy

### Unit Tests (Optional - Time Permitting)

**Test Cases:**
```swift
// RepeatMode enum tests
func testRepeatModeNext() {
    XCTAssertEqual(RepeatMode.off.next(), .all)
    XCTAssertEqual(RepeatMode.all.next(), .one)
    XCTAssertEqual(RepeatMode.one.next(), .off)
}

// Playlist navigation tests
func testRepeatOffStopsAtEnd() {
    settings.repeatMode = .off
    // currentIndex = last track
    XCTAssertNil(playlistManager.getNextTrackId())
}

func testRepeatAllWrapsAround() {
    settings.repeatMode = .all
    // currentIndex = last track
    XCTAssertNotNil(playlistManager.getNextTrackId())
    // Should return first track
}

func testRepeatOneReplaysTrack() {
    settings.repeatMode = .one
    let current = playlistManager.currentTrack
    let next = playlistManager.getNextTrackId()
    XCTAssertEqual(current, next)
}
```

### Manual Testing Checklist

**Visual Testing:**
- [ ] Off mode: Button unlit, no badge
- [ ] All mode: Button lit, no badge
- [ ] One mode: Button lit + "1" badge visible
- [ ] Badge legible on Classic Winamp skin (green)
- [ ] Badge legible on Internet Archive skin (beige)
- [ ] Badge legible on Tron Vaporwave skin (dark blue)
- [ ] Badge legible on Mac OS X skin (light gray)
- [ ] Shadow makes "1" readable on all backgrounds

**Behavior Testing:**
- [ ] Off mode: Next button stops at playlist end
- [ ] Off mode: Previous button stops at playlist start
- [ ] All mode: Next button wraps to first track
- [ ] All mode: Previous button wraps to last track
- [ ] One mode: Next button replays current track
- [ ] One mode: Previous button replays current track
- [ ] Button click cycles: Off → All → One → Off
- [ ] Ctrl+R cycles modes correctly
- [ ] Options menu shows checkmark on active mode
- [ ] Options menu click sets mode directly
- [ ] Tooltip updates to show current mode

**Edge Cases:**
- [ ] Empty playlist: All modes return nil gracefully
- [ ] Single track: Off/All behave identically
- [ ] Single track: One mode replays correctly
- [ ] Track ends naturally in One mode → replays
- [ ] Mode persists across app restart
- [ ] Mode works with shuffle enabled (if applicable)

**Cross-Skin Testing:**
- [ ] Test all 7 bundled skins
- [ ] Verify "1" badge visible on each
- [ ] Adjust offset if badge clips button bounds

---

## Files to Modify

### Core Changes (Required)

1. **MacAmpApp/Models/AppSettings.swift**
   - Add `RepeatMode` enum
   - Change `repeatMode` from `Bool` to `RepeatMode`
   - Update persistence (didSet, init)
   - ~30 lines added, ~5 removed

2. **MacAmpApp/Audio/PlaylistManager.swift** (or wherever playlist navigation lives)
   - Update `getNextTrackId()` logic
   - Add three-state switch statement
   - ~20 lines modified

3. **MacAmpApp/Views/WinampMainWindow.swift**
   - Update repeat button rendering
   - Add ZStack with badge overlay
   - ~15 lines modified

4. **MacAmpApp/AppCommands.swift**
   - Update Ctrl+R keyboard shortcut
   - Dynamic label
   - ~5 lines modified

### Optional Enhancements

5. **MacAmpApp/Views/Components/OptionsMenu.swift** (if separate file)
   - Add three-state repeat selector
   - Checkmarks for active mode
   - ~15 lines added

---

## Risks & Mitigation

### Risk 1: Badge Position Varies by Skin
**Impact:** Badge may clip button edges on some skins
**Likelihood:** Medium
**Mitigation:** Test all 7 bundled skins, adjust offset as needed
**Fallback:** Use smaller font size (7px instead of 8px)

### Risk 2: Shadow Not Legible on Extreme Colors
**Impact:** "1" invisible on certain skin backgrounds
**Likelihood:** Low (shadow technique proven in subtitles/games)
**Mitigation:** Increase shadow radius from 1 to 1.5 if needed
**Fallback:** Option B2 (badge circle) or B3 (outlined text)

### Risk 3: Shuffle + Repeat One Interaction
**Impact:** Unclear UX when both enabled
**Likelihood:** Low (edge case)
**Mitigation:** Document behavior: Repeat One takes precedence
**Fallback:** Disable shuffle when in repeat-one mode

### Risk 4: Persistence Migration
**Impact:** Users with boolean `true` lose state
**Likelihood:** Low (graceful fallback to `.off`)
**Mitigation:** Default to `.off` for unrecognized values
**Note:** Acceptable - repeat state is non-critical

---

## Rollout Plan

### Step 1: Implementation (1.5-2 hours)
1. Update AppSettings enum (15 min)
2. Update playlist navigation logic (30 min)
3. Update UI button with badge (30 min)
4. Update keyboard shortcut (15 min)
5. Add Options menu integration (15 min)

### Step 2: Testing (30-45 minutes)
1. Visual testing across 7 skins (20 min)
2. Behavior testing (playlist boundaries, cycling) (15 min)
3. Edge case testing (empty playlist, single track) (10 min)

### Step 3: Documentation (15 minutes)
1. Update README.md with repeat mode documentation
2. Add screenshots if helpful
3. Update CHANGELOG/release notes

### Step 4: Code Review (Optional)
1. Self-review commit diff
2. Oracle review (if desired)
3. Address feedback

### Step 5: Merge
1. Create PR from `repeat-mode-toggle` branch
2. Merge to main
3. Tag release (e.g., v0.7.9)

---

## Success Criteria

**Must Have:**
- ✅ Three modes work correctly (off/all/one)
- ✅ "1" badge visible in repeat-one mode
- ✅ Badge legible on all 7 bundled skins
- ✅ Button cycles through all three states
- ✅ Keyboard shortcut cycles modes
- ✅ Mode persists across app restart

**Nice to Have:**
- ✅ Options menu with three-state selector
- ✅ Tooltip shows current mode
- ✅ Smooth visual transitions

**Stretch Goals:**
- ⚠️ Unit tests for repeat logic
- ⚠️ Animation when mode changes
- ⚠️ Per-skin badge color (advanced)

---

## Open Questions

1. **Q:** Should shuffle be disabled when in repeat-one mode?
   **A:** TBD - Test UX, document behavior

2. **Q:** Should "1" badge animate in/out when toggling?
   **A:** Not in MVP - can add later if desired

3. **Q:** Badge offset universal or per-skin?
   **A:** Start universal, adjust if specific skin fails

4. **Q:** Should Options menu show radio buttons or checkmarks?
   **A:** Checkmarks (simpler, follows double-size pattern)

---

## Future Enhancements (Out of Scope)

1. **Per-skin badge colors** - Extract accent color from skin metadata
2. **Badge animation** - Fade in/out when toggling modes
3. **Repeat count** - "Repeat 3 times" mode (advanced)
4. **A-B repeat** - Loop between two time markers (complex)

---

## References

- Research: `tasks/repeat-mode-3way-toggle/research.md`
- Webamp analysis: `tasks/repeat-mode-3way-toggle/research.md` (lines 40-80)
- Winamp history: `tasks/repeat-mode-3way-toggle/winamp-repeat-mode-history.md`
- Visual analysis: `tasks/repeat-mode-3way-toggle/repeat-mode-overlay-analysis.md`
- Skill document: `BUILDING_RETRO_MACOS_APPS_SKILL.md` (SwiftUI patterns)

---

**Plan Status:** Ready for Implementation
**Next Step:** Create state.md and todo.md, validate with Oracle
**Estimated Total Time:** 2-3 hours (implementation + testing)
