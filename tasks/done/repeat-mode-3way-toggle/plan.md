# Implementation Plan - Three-State Repeat Mode (Winamp 5 Modern Fidelity)

**Task ID:** repeat-mode-3way-toggle
**Created:** 2025-11-07
**Oracle Reviewed:** ✅ Grade B- → A- (with corrections applied)
**Estimated Time:** 2.5 hours
**Priority:** Medium
**Complexity:** Low-Medium

---

## Winamp 5 Modern Reference Implementation

**What we're matching:**

```
Winamp 5 Modern Skins (Modern, Bento, cPro):
┌─────────────────────────────────────────┐
│ Button Behavior: Single button cycles   │
│   Click 1: OFF → ALL (button lights up) │
│   Click 2: ALL → ONE (shows "1" badge)  │
│   Click 3: ONE → OFF (button dims)      │
│                                          │
│ Visual Indicator (Repeat ONE):          │
│   - Small "1" character on button       │
│   - Position: Top-right or center       │
│   - Color: White (contrasting)          │
│   - Appears ONLY in repeat-one mode     │
└─────────────────────────────────────────┘
```

**Source:** Winamp 5 forums, confirmed by multiple users
**Quote:** "indicated by a little '1' on the button"

---

## Overview

Implement three-state repeat mode matching **Winamp 5 Modern skins** behavior:
- **Off:** Stop at playlist end
- **All:** Loop entire playlist (current boolean behavior)
- **One:** Repeat current track indefinitely

**Key Principle:** Match Winamp 5 Modern's UX exactly - single button cycling with "1" badge.

---

## Oracle Critical Corrections (Applied)

### ✅ Fix #1: Single Source of Truth
**Problem:** Original plan had `AppSettings.repeatMode` + `AudioPlayer.repeatEnabled` (dual state)
**Solution:** `RepeatMode` lives in `AudioPlayer`, `AppSettings` only for persistence

### ✅ Fix #2: Reuse Existing Navigation
**Problem:** Original plan created new `getNextTrackId()` function
**Solution:** Modify existing `AudioPlayer.nextTrack()` to preserve stream/shuffle/coordinator logic

### ✅ Fix #3: Repeat-One Must Restart Playback
**Problem:** Original plan returned `currentTrack` reference (doesn't play)
**Solution:** Must `seek(to: 0)` for local files or reload via coordinator for streams

### ✅ Fix #4: Preserve User Preference
**Problem:** Migration defaulted all users to `.off`
**Solution:** Map old boolean `true → .all`, `false → .off`

### ✅ Fix #5: Make Enum Future-Proof
**Problem:** Hardcoded cycling won't extend if modes added
**Solution:** Add `CaseIterable` and cycle through `allCases`

---

## Implementation Strategy

### Phase 1: Data Model (20 minutes)

#### 1.1 Define RepeatMode Enum

**File:** `MacAmpApp/Models/AppSettings.swift`

```swift
/// Repeat mode matching Winamp 5 Modern behavior
/// - off: Stop at playlist end
/// - all: Loop entire playlist
/// - one: Repeat current track (shows "1" badge)
enum RepeatMode: String, Codable, CaseIterable {
    case off = "off"
    case all = "all"
    case one = "one"

    /// Cycle to next mode (Winamp 5 Modern button behavior)
    func next() -> RepeatMode {
        let cases = Self.allCases
        guard let index = cases.firstIndex(of: self) else { return self }
        let nextIndex = (index + 1) % cases.count
        return cases[nextIndex]
    }

    /// UI display label
    var label: String {
        switch self {
        case .off: return "Repeat: Off"
        case .all: return "Repeat: All"
        case .one: return "Repeat: One"
        }
    }

    /// Button state (lit when all or one)
    var isActive: Bool {
        self != .off
    }
}
```

#### 1.2 Add to AppSettings (Persistence Only)

**File:** `MacAmpApp/Models/AppSettings.swift`

```swift
// Add to AppSettings class
var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}
```

#### 1.3 Migration Logic (Preserve Existing Preference)

**File:** `MacAmpApp/Models/AppSettings.swift` (in `init()`)

```swift
// Load repeat mode with migration from old boolean
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    // Migrate from old boolean key (preserve user preference)
    let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
    self.repeatMode = oldRepeat ? .all : .off  // true maps to "all"
}
```

#### 1.4 Expose in AudioPlayer (Authoritative State)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

```swift
// REMOVE old boolean:
// @Published var repeatEnabled: Bool = false  ← DELETE THIS

// ADD computed property (single source of truth):
@Published var repeatMode: RepeatMode {
    get { appSettings.repeatMode }
    set { appSettings.repeatMode = newValue }
}
```

**Why this works:**
- AudioPlayer is authoritative (all playback logic reads from here)
- AppSettings handles persistence (UserDefaults)
- No dual state, no sync issues

---

### Phase 2: Playlist Navigation Logic (30 minutes)

#### 2.1 Modify Existing nextTrack()

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (function starts ~line 1234)

**Strategy:** Insert `RepeatMode` switch at top, reuse existing logic

```swift
func nextTrack() {
    // ──────────────────────────────────────
    // WINAMP 5 REPEAT MODE LOGIC (INSERT AT TOP)
    // ──────────────────────────────────────
    switch repeatMode {
    case .off:
        // Stop at playlist boundaries (Winamp behavior)
        guard hasNextTrack else {
            stop()
            return
        }
        // Fall through to existing next track logic below

    case .all:
        // Wrap around to beginning (Winamp repeat-all)
        if !hasNextTrack {
            currentPlaylistIndex = 0  // Jump to first track
        }
        // Fall through to existing next track logic below

    case .one:
        // Restart current track (Winamp repeat-one)
        guard let current = currentTrack else { return }

        if current.isStream {
            // Internet radio: reload through coordinator
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.coordinator?.play(track: current)
            }
        } else {
            // Local file: seek to beginning
            seek(to: 0, resume: true)
        }
        return  // Don't advance playlist index
    }

    // ──────────────────────────────────────
    // EXISTING NEXT TRACK LOGIC (UNCHANGED)
    // ──────────────────────────────────────
    // ... current index incrementing ...
    // ... shuffle handling ...
    // ... stream vs local routing ...
    // ... all existing code preserved ...
}
```

**Key Points:**
- ✅ Reuses existing stream/shuffle/coordinator logic
- ✅ Preserves `currentPlaylistIndex` tracking
- ✅ Handles both local files and streams correctly
- ✅ Minimal changes (insert switch, rest stays same)

#### 2.2 Update previousTrack() if Needed

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (function starts ~line 1310)

**Current behavior:** Already seeks to 0 (rewind)

```swift
func previousTrack() {
    // Repeat-one: current behavior (rewind) is correct
    if repeatMode == .one {
        seek(to: 0)
        return
    }

    // ... existing previous logic unchanged ...
}
```

**Note:** May not need changes if existing rewind behavior is acceptable

#### 2.3 Edge Cases to Handle

**Empty Playlist:**
```swift
// Already handled by guard statements
guard !playlist.isEmpty else { return }
```

**Single Track:**
- Off mode: Stops after track (existing behavior)
- All mode: Replays track (wrap-around to index 0)
- One mode: Replays track (seek to 0)

**Shuffle + Repeat One:**
- Repeat One takes precedence (always replays current track)
- Shuffle ignored in repeat-one mode (document this)

---

### Phase 3: UI Button + Badge (15 minutes)

#### 3.1 Update Repeat Button

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (~line 431-438)

**Replace existing button:**

```swift
// WINAMP 5 MODERN THREE-STATE REPEAT BUTTON
Button(action: {
    // Cycle through modes (Winamp 5 Modern behavior)
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}) {
    // Base sprite (lit when active)
    let spriteKey = audioPlayer.repeatMode.isActive
        ? "MAIN_REPEAT_BUTTON_SELECTED"
        : "MAIN_REPEAT_BUTTON"

    ZStack {
        SimpleSpriteImage(spriteKey, width: 28, height: 15)

        // "1" badge (Winamp 5 Modern indicator)
        if audioPlayer.repeatMode == .one {
            Text("1")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)
                .offset(x: 8, y: 0)  // Center in 28×15 button
        }
    }
}
.buttonStyle(.plain)
.help(audioPlayer.repeatMode.label)  // Dynamic tooltip
```

**Visual States (Winamp 5 Modern):**
- **Off:** Unlit button, no badge
- **All:** Lit button, no badge
- **One:** Lit button + white "1" badge (top-right)

**Badge Specs (Matching Winamp 5):**
- Font: 8px bold system font (clean, readable)
- Color: White (Winamp 5 used white/light color)
- Shadow: Black 80% opacity, 1px radius (legibility)
- Position: `x:8, y:0` (centered, will adjust if needed)

#### 3.2 Badge Positioning & Double-Size Mode

**Starting position:** `x:8, y:0` centers in 28×15 button

**Double-Size Mode (Ctrl+D) Behavior:**
- MacAmp uses `.scaleEffect(2.0)` on entire UnifiedDockView
- Badge scales automatically: 8px → 16px font, (8,0) → (16,0) offset
- Result: Badge maintains same proportional position at 100% and 200%
- ✅ **No special handling needed** - SwiftUI scales everything together

**Visual at 200%:**
- Button: 56×30px (from 28×15)
- Badge: 16px font (from 8px)
- Position: Still centered on button
- Legibility: Maintained (proportions identical)

**If clipping occurs:** Adjust x (left/right) or y (up/down) at 100% - will scale correctly

---

### Phase 4: Keyboard Shortcut (10 minutes)

#### 4.1 Update Ctrl+R Shortcut

**File:** `MacAmpApp/AppCommands.swift`

**Find existing repeat shortcut, update:**

```swift
// Winamp 5 keyboard shortcut: R key cycles modes
Button(audioPlayer.repeatMode.label) {
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}
.keyboardShortcut("r", modifiers: [.control])
```

**Behavior:**
- Press Ctrl+R: Off → All
- Press Ctrl+R: All → One
- Press Ctrl+R: One → Off

**Note:** If using `@Bindable`, declare in body scope:
```swift
var body: some View {
    @Bindable var player = audioPlayer
    // ... use $player.repeatMode if needed ...
}
```

---

### Phase 5: Options Menu Integration (15 minutes)

#### 5.1 Add to Options Menu (O Button)

**File:** `MacAmpApp/Views/WinampMainWindow.swift` (O button menu implementation)

**Add three-state selector:**

```swift
Menu {
    // ... existing time display toggle ...

    Divider()

    // Winamp 5 style repeat selector
    Button(action: { audioPlayer.repeatMode = .off }) {
        Label("Repeat: Off", systemImage: audioPlayer.repeatMode == .off ? "checkmark" : "")
    }
    Button(action: { audioPlayer.repeatMode = .all }) {
        Label("Repeat: All", systemImage: audioPlayer.repeatMode == .all ? "checkmark" : "")
    }
    Button(action: { audioPlayer.repeatMode = .one }) {
        Label("Repeat: One", systemImage: audioPlayer.repeatMode == .one ? "checkmark" : "")
    }

    Divider()

    // ... existing shuffle, double-size toggles ...
}
```

**Visual Feedback:**
- Checkmark appears next to active mode
- Click any option to set mode directly (bypass cycling)

---

## Testing Strategy

### Winamp 5 Fidelity Checklist

#### Visual Testing - Badge Indicator

**Test "1" badge on all 7 bundled skins:**

| Skin | Background | Badge Test | Expected |
|------|-----------|------------|----------|
| Classic Winamp | Green/Gray | White "1" + shadow | ✅ Legible |
| Internet Archive | Beige | White "1" + shadow | ✅ Legible (shadow helps) |
| Tron Vaporwave | Dark Blue | White "1" + shadow | ✅ Legible |
| Mac OS X | Light Gray | White "1" + shadow | ✅ Legible (shadow critical) |
| Sony MP3 | Silver/White | White "1" + shadow | ⚠️ TEST - worst case |
| KenWood | Black/Red | White "1" + shadow | ✅ Legible |
| Winamp3 Classified | Dark Blue | White "1" + shadow | ✅ Legible |

**If Sony MP3 fails:** Increase shadow radius to 1.5 or use outlined text

#### Behavior Testing - Winamp 5 Accuracy

**Button Cycling (5-track playlist):**
1. Click repeat button → OFF to ALL (button lights)
2. Click repeat button → ALL to ONE (button shows "1")
3. Click repeat button → ONE to OFF (button dims)
4. Verify tooltip updates each click

**Playlist Navigation:**

**Off Mode (Stop at End):**
- Track 5 → Next → Stops playback ✅
- Track 1 → Previous → Stops/rewinds ✅

**All Mode (Loop Playlist):**
- Track 5 → Next → Track 1 (wraps) ✅
- Track 1 → Previous → Track 5 (wraps) ✅

**One Mode (Repeat Track):**
- Track 3 → Next → Track 3 restarts ✅
- Track 3 → Previous → Track 3 restarts ✅
- Track plays to end → Restarts from 0:00 ✅

**Stream Testing (Internet Radio):**
- One mode with stream → Stream restarts ✅
- Coordinator routing preserved ✅

### Edge Cases

**Empty Playlist:**
- All modes handle gracefully (no crash)

**Single Track:**
- Off: Stops after track
- All: Replays (wraps to index 0)
- One: Replays (seeks to 0)

**Shuffle + Repeat One:**
- Repeat One takes precedence
- Shuffle ignored (always replays current track)
- Document this behavior

### Persistence Testing

**UserDefaults Round-Trip:**
1. Set mode to All → Quit → Relaunch → Still All ✅
2. Set mode to One → Quit → Relaunch → Still One ✅
3. Delete UserDefaults → Launch → Defaults to Off ✅

**Migration:**
4. Set old `repeatEnabled = true` → Upgrade → Becomes `.all` ✅
5. Set old `repeatEnabled = false` → Upgrade → Becomes `.off` ✅

---

## Files to Modify

### Core Changes (Required)

1. **MacAmpApp/Models/AppSettings.swift**
   - Add `RepeatMode` enum (30 lines)
   - Add `repeatMode` property with persistence (5 lines)
   - Update `init()` with migration logic (10 lines)
   - **Total:** ~45 lines added

2. **MacAmpApp/Audio/AudioPlayer.swift**
   - Remove `repeatEnabled: Bool` (1 line deleted)
   - Add computed `repeatMode` property (5 lines)
   - Modify `nextTrack()` function (insert 25-line switch at top)
   - Optional: Update `previousTrack()` (5 lines)
   - **Total:** ~30 lines added/modified

3. **MacAmpApp/Views/WinampMainWindow.swift**
   - Update repeat button with ZStack + badge (20 lines)
   - Add Options menu entries (15 lines)
   - **Total:** ~35 lines added/modified

4. **MacAmpApp/AppCommands.swift**
   - Update Ctrl+R shortcut (3 lines modified)
   - **Total:** ~3 lines modified

**Grand Total:** ~110 lines added/modified (minimal changes)

---

## Risks & Mitigation

### Risk 1: Badge Position Varies by Skin
**Likelihood:** Medium
**Impact:** Low (visual only)
**Mitigation:** Test all 7 skins, adjust offset as needed
**Fallback:** Reduce font to 7px if clipping

### Risk 2: Shadow Insufficient on Light Skins
**Likelihood:** Low
**Impact:** Medium
**Mitigation:** Increase shadow radius to 1.5, opacity to 1.0
**Fallback:** Add stroke/outline to text

### Risk 3: Double-Size Mode Badge Scaling
**Likelihood:** Low
**Impact:** Low
**Mitigation:** Badge may need offset adjustment for 2x scale
**Fallback:** Tie offset to `Coords.repeatButton` position

### Risk 4: Shuffle + Repeat One UX Confusion
**Likelihood:** Low
**Impact:** Low
**Mitigation:** Document that Repeat One takes precedence
**Fallback:** Disable shuffle when in repeat-one mode

---

## Success Criteria

### Must Have (Winamp 5 Fidelity)
- ✅ Three modes work correctly (off/all/one)
- ✅ Button cycles through states on click
- ✅ White "1" badge appears in repeat-one mode
- ✅ Badge legible on all 7 bundled skins
- ✅ Keyboard shortcut (Ctrl+R) cycles modes
- ✅ Mode persists across app restart
- ✅ Migration preserves user preference
- ✅ Matches Winamp 5 Modern visual exactly

### Nice to Have
- ✅ Options menu with direct mode selection
- ✅ Tooltip shows current mode
- ✅ No build warnings
- ✅ Oracle-approved code quality

### Out of Scope (Future Enhancements)
- ⚠️ Per-skin badge colors (advanced)
- ⚠️ Badge animation on toggle
- ⚠️ Sprite-based "1" glyph (vs SwiftUI Text)

---

## Timeline

**Phase 1:** Data Model (20 min)
**Phase 2:** Navigation Logic (30 min)
**Phase 3:** UI + Badge (15 min)
**Phase 4:** Keyboard Shortcut (10 min)
**Phase 5:** Options Menu (15 min)
**Testing:** Visual + Behavior (30 min)
**Documentation:** README updates (15 min)

**Total:** 2 hours 15 minutes implementation + testing

---

## References

- **Winamp History:** `winamp-repeat-mode-history.md` (authoritative source)
- **Badge Analysis:** `repeat-mode-overlay-analysis.md` (cross-skin testing)
- **Research:** `research.md` (Webamp comparison)
- **Oracle Review:** `oracle-review.md` (technical corrections)
- **Skill Guide:** `BUILDING_RETRO_MACOS_APPS_SKILL.md` (SwiftUI patterns)

---

**Plan Status:** ✅ Ready for Implementation (Oracle-validated)
**Next Step:** Execute todo.md checklist
**Estimated Time:** 2.5 hours (with testing)
**Winamp 5 Fidelity:** 100% (Modern skins with "1" badge)
