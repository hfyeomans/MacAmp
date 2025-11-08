# State - Three-State Repeat Mode Implementation

**Task:** repeat-mode-3way-toggle
**Status:** Planning Complete, Oracle-Validated, Ready for Implementation
**Branch:** `repeat-mode-toggle` ✅
**Last Updated:** 2025-11-07

---

## Current Status: Pre-Implementation (Planning Complete)

### Completed ✅

1. **Research Phase** (2 hours)
   - Analyzed Webamp implementation (boolean only)
   - Researched Winamp 5 history (2.x → 5.x evolution)
   - Confirmed Winamp 5 Modern skins used "1" badge
   - Cross-skin compatibility analysis (7 bundled skins)
   - Selected visual approach: White "1" + shadow (Winamp 5 pattern)

2. **Oracle Validation** (15 minutes) - Grade: B- → A- after corrections
   - ✅ Enum design approved
   - ✅ Visual approach matches Winamp 5 Modern
   - ✅ Badge + shadow strategy works cross-skin
   - ⚠️ Critical fixes identified:
     1. Single source of truth (AudioPlayer, not AppSettings)
     2. Reuse existing nextTrack() (don't create new function)
     3. Repeat-one must restart playback (seek or reload)
     4. Migration should preserve user preference (true → .all)
     5. Add CaseIterable to enum (future-proof)

3. **Documentation Complete**
   - research.md: Webamp analysis + Winamp 5 history
   - winamp-repeat-mode-history.md: How Winamp actually worked
   - repeat-mode-overlay-analysis.md: Cross-skin legibility validation
   - plan.md: Complete implementation strategy (Oracle corrections applied)
   - state.md: This file
   - todo.md: Ready for final update

4. **Branch Setup**
   - Created `repeat-mode-toggle` branch
   - Documentation committed to main (commit a32ed91)

### In Progress 🔄

- Consolidating Oracle findings into planning docs

### Pending ⏳

1. **Implementation** (2.5 hours)
   - Phase 1: Data model (RepeatMode enum)
   - Phase 2: Navigation logic (modify nextTrack)
   - Phase 3: UI + badge
   - Phase 4: Keyboard shortcut
   - Phase 5: Options menu

2. **Testing** (30 minutes)
   - Visual: Badge on all 7 skins
   - Behavior: Playlist navigation
   - Edge cases: Empty, single track
   - Persistence: Migration + round-trip

3. **Documentation** (15 minutes)
   - Update README.md
   - Add release notes

---

## Technical Decisions (Oracle-Validated)

### 1. State Architecture: AudioPlayer is Authoritative ✅

**Decision:** `repeatMode` property lives in `AudioPlayer`, backed by `AppSettings` for persistence

**Pattern:**
```swift
// AudioPlayer.swift - Authoritative state
@Published var repeatMode: RepeatMode {
    get { appSettings.repeatMode }
    set { appSettings.repeatMode = newValue }
}

// AppSettings.swift - Persistence only
var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}
```

**Why:** Avoids dual sources of truth, all playback logic reads from AudioPlayer

**Oracle Quote:**
> "Keep repeat logic inside AudioPlayer so it sits next to shuffle, trackHasEnded, and coordinator hooks."

---

### 2. RepeatMode Enum Design ✅

**Decision:** Three-state enum with `CaseIterable` for future-proof cycling

```swift
enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one

    func next() -> RepeatMode {
        let cases = Self.allCases
        let index = cases.firstIndex(of: self) ?? 0
        return cases[(index + 1) % cases.count]
    }

    var isActive: Bool { self != .off }
}
```

**Benefits:**
- Type-safe state transitions
- Extensible (add `.count` mode later, `next()` still works)
- Clean intent (off/all/one vs confusing dual flags)

**Oracle Approval:**
> "Enum itself is fine; consider adding CaseIterable... stays correct if another mode ever appears."

---

### 3. Navigation: Modify Existing nextTrack() ✅

**Decision:** Insert `RepeatMode` switch at top of existing `nextTrack()`, preserve all current logic

**Why NOT create new function:**
- Existing nextTrack() handles:
  - Stream vs local file routing (PlaybackCoordinator)
  - Shuffle integration
  - `currentPlaylistIndex` tracking
  - Edge cases (empty playlist, boundaries)
- Creating new function would duplicate 50+ lines
- Risk breaking internet radio streams

**Oracle Quote:**
> "Reuse the existing nextTrack()/previousTrack() scaffolding instead of inventing PlaylistManager."

---

### 4. Visual Indicator: White "1" Badge + Shadow ✅

**Decision:** ZStack overlay with SwiftUI Text + shadow (Winamp 5 Modern pattern)

```swift
if audioPlayer.repeatMode == .one {
    Text("1")
        .font(.system(size: 8, weight: .bold))
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
        .offset(x: 8, y: 0)
}
```

**Winamp 5 Accuracy:**
- ✅ Small "1" character (matches Winamp)
- ✅ White color (Winamp used white/light)
- ✅ Top-right or center position (ours: centered)
- ✅ Only appears in repeat-one mode

**Cross-Skin Compatibility:**
- Shadow ensures legibility on all backgrounds
- Validated across 7 bundled skins (see repeat-mode-overlay-analysis.md)
- Worst case: Sony MP3 (light button) - shadow provides contrast

**Oracle Approval:**
> "ZStack + Text is acceptable for MVP... shadow technique proven in subtitles/games."

**Production Note:** Could upgrade to sprite later for pixel-perfection, but Text + shadow matches Winamp 5 functionally.

---

### 5. Migration: Preserve User Preference ✅

**Decision:** Map old boolean to equivalent enum value

```swift
// Migration logic
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode") {
    self.repeatMode = RepeatMode(rawValue: savedMode) ?? .off
} else {
    // Migrate from old boolean
    let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
    self.repeatMode = oldRepeat ? .all : .off
}
```

**Mapping:**
- `true` → `.all` (user had repeat on, wants playlist loop)
- `false` → `.off` (user had repeat off, wants stop at end)

**Oracle Fix:**
> "Map true → .all, false → .off to preserve user expectations."

---

## Implementation Approach

### Data Flow (Winamp 5 Pattern)

```
User Clicks Button / Presses Ctrl+R
    ↓
audioPlayer.repeatMode = repeatMode.next()
    ↓
(setter) appSettings.repeatMode = newValue
    ↓
(didSet) UserDefaults.standard.set(...)
    ↓
SwiftUI observes AudioPlayer.repeatMode change
    ↓
Button sprite updates (lit/unlit)
Badge visibility updates (show/hide "1")
Tooltip updates (Off/All/One)
    ↓
Next track uses repeatMode in nextTrack() switch
```

### Code Location Summary

**State:**
- Persistent: `AppSettings.repeatMode` (UserDefaults)
- Authoritative: `AudioPlayer.repeatMode` (computed from AppSettings)

**Logic:**
- Navigation: `AudioPlayer.nextTrack()` (modified)
- Playback restart: `AudioPlayer.seek()` or `coordinator.play()`

**UI:**
- Button: `WinampMainWindow.swift` (ZStack with badge)
- Menu: `WinampMainWindow.swift` (O button menu)
- Shortcut: `AppCommands.swift` (Ctrl+R)

---

## Known Constraints & Solutions

### Constraint 1: Classic Skins Only Have 2 Sprites
**Fact:** `MAIN_REPEAT_BUTTON` and `MAIN_REPEAT_BUTTON_SELECTED` only
**Winamp 5 Solution:** Used overlay for "1" badge (plugins did same)
**Our Solution:** SwiftUI Text overlay (matches Winamp 5)

### Constraint 2: Badge Must Work on Any Color
**Fact:** Skins have vastly different button colors (black, white, green, beige, blue)
**Winamp 5 Solution:** White badge (worked most places)
**Our Solution:** White badge + shadow (works everywhere)

### Constraint 3: Double-Size Mode
**Fact:** Button scales 2x in double-size mode
**Concern:** Badge offset may need adjustment
**Solution:** Test in double-size, adjust offset if needed

---

## Edge Cases & Behavior

### Shuffle + Repeat One Interaction

**Winamp 5 Behavior:** Unknown (research didn't find this)
**Our Approach:** Repeat One takes precedence
- Shuffle=On, Repeat=One → Always replays current track (shuffle ignored)
- This is user-intuitive: "repeat one" means ONE track

**Alternative:** Auto-disable shuffle when entering repeat-one
**Decision:** Keep independent, document precedence

### Empty Playlist

All modes return gracefully (no crash):
```swift
guard !playlist.isEmpty else { return }
```

### Single Track

- **Off:** Track ends → stops
- **All:** Track ends → replays (wraps to index 0)
- **One:** Track ends → replays (seeks to 0)

**Note:** All and One behave identically for single track (acceptable)

### Internet Radio + Repeat One

**Behavior:** Stream restarts via `coordinator.play()`
**Edge case:** Infinite duration streams (24/7 radio)
- Track never "ends" naturally
- Repeat One only triggers on manual Next button
- Acceptable behavior

---

## Testing Requirements (Winamp 5 Validation)

### Must Pass Before Merge

**Visual (All 7 Skins):**
- [ ] Classic Winamp: "1" badge legible
- [ ] Internet Archive: "1" badge legible
- [ ] Tron Vaporwave: "1" badge legible
- [ ] Mac OS X: "1" badge legible
- [ ] Sony MP3: "1" badge legible (CRITICAL - lightest skin)
- [ ] KenWood: "1" badge legible
- [ ] Winamp3: "1" badge legible

**Behavior:**
- [ ] Off: Stops at playlist end
- [ ] All: Wraps to first track
- [ ] One: Replays current track
- [ ] Button cycling: Off → All → One → Off
- [ ] Ctrl+R cycling matches button
- [ ] Persistence works

**Edge Cases:**
- [ ] Empty playlist: No crash
- [ ] Single track: All modes work
- [ ] Stream + Repeat One: Reloads stream

---

## Files Affected Summary

| File | Changes | Lines | Type |
|------|---------|-------|------|
| AppSettings.swift | RepeatMode enum + persistence | +45 | Data model |
| AudioPlayer.swift | Computed property + navigation | +30 | Logic |
| WinampMainWindow.swift | Button + badge + menu | +35 | UI |
| AppCommands.swift | Keyboard shortcut | +3 | Commands |
| **TOTAL** | | **~113** | |

**Low risk:** Small, focused changes, no architectural shifts

---

## Success Metrics

**Functional:**
- ✅ All three modes work correctly
- ✅ Playlist navigation respects mode
- ✅ Mode persists across restarts
- ✅ Migration preserves user preference

**Visual (Winamp 5 Fidelity):**
- ✅ Badge appears ONLY in repeat-one mode
- ✅ Badge legible on all skins
- ✅ Button states match Winamp 5 Modern

**Code Quality:**
- ✅ Type-safe enum (no boolean flags)
- ✅ Single source of truth (AudioPlayer)
- ✅ Clean state transitions
- ✅ Oracle-approved (Grade A- with fixes)

---

## Next Steps

1. ✅ **Consolidate Oracle findings** into plan.md (DONE)
2. ⏳ **Update state.md** with corrections (IN PROGRESS)
3. ⏳ **Create definitive todo.md** breakdown
4. ⏳ **Begin implementation** following todo.md

---

## Oracle Grade Progression

**Initial Plan:** B- (solid direction, structural gaps)
**After Corrections:** A- (production-ready)

**Remaining for A+:**
- Sprite-based "1" badge (pixel-perfect, vs SwiftUI Text)
- Unit tests for repeat logic
- Animation on mode toggle

**Acceptable for MVP:** Current A- plan ships Winamp 5 Modern fidelity

---

**Status:** ✅ Ready for Implementation
**Blocking:** None
**Confidence:** High (Oracle-validated, Winamp 5 pattern confirmed)
**Estimated Time:** 2.5 hours to complete
