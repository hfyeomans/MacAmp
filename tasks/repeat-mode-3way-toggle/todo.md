# TODO - Three-State Repeat Mode (Winamp 5 Modern Fidelity)

**Task:** repeat-mode-3way-toggle
**Branch:** `repeat-mode-toggle` ✅
**Target:** Match Winamp 5 Modern skins exactly
**Estimated Time:** 2.5 hours
**Oracle Grade:** A- (with corrections applied)

---

## Pre-Implementation ✅ COMPLETE

- [x] Research Webamp implementation
- [x] Research Winamp 5 Modern skins behavior
- [x] Analyze "1" badge visual indicator
- [x] Cross-skin compatibility analysis (7 skins)
- [x] Oracle validation of approach
- [x] Apply Oracle critical fixes to plan
- [x] Create task folder structure
- [x] Write research.md (with Winamp 5 reference)
- [x] Write winamp-repeat-mode-history.md
- [x] Write repeat-mode-overlay-analysis.md
- [x] Write plan.md (Oracle corrections applied)
- [x] Write state.md (Oracle quotes integrated)
- [x] Write todo.md (this file)
- [ ] **Commit consolidated documentation** ← NEXT
- [ ] **Verify branch is `repeat-mode-toggle`** ← THEN START

---

## PHASE 1: Data Model (20 minutes)

### Step 1.1: Define RepeatMode Enum (5 min)

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Add enum definition **before** AppSettings class
- [ ] Include three cases: `off`, `all`, `one`
- [ ] Conform to: `String`, `Codable`, `CaseIterable`
- [ ] Add `next()` method using `allCases` (Oracle pattern)
- [ ] Add `label` computed property for UI
- [ ] Add `isActive` computed property (true when all or one)

**Verification:**
```swift
// Quick test in init or debug:
// let test = RepeatMode.off.next()  // Should be .all
// print(test.label)  // Should print "Repeat: All"
```

### Step 1.2: Add Persistence Property (5 min)

**File:** `MacAmpApp/Models/AppSettings.swift`

- [ ] Add `var repeatMode: RepeatMode = .off` to AppSettings class
- [ ] Add `didSet` block with UserDefaults persistence
- [ ] Use key: `"repeatMode"` (String)
- [ ] Save using: `repeatMode.rawValue`

**Code:**
```swift
var repeatMode: RepeatMode = .off {
    didSet {
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }
}
```

### Step 1.3: Add Migration Logic (10 min)

**File:** `MacAmpApp/Models/AppSettings.swift` (in `init()`)

- [ ] Find the init() method
- [ ] Add enum loading with migration from old boolean
- [ ] Try loading new enum key first
- [ ] Fallback: Load old "audioPlayerRepeatEnabled" boolean
- [ ] Map: `true → .all`, `false → .off`
- [ ] Delete old boolean key after migration (optional cleanup)

**Code:**
```swift
// In init(), after other property loading:
if let savedMode = UserDefaults.standard.string(forKey: "repeatMode"),
   let mode = RepeatMode(rawValue: savedMode) {
    self.repeatMode = mode
} else {
    // Migrate from old boolean key
    let oldRepeat = UserDefaults.standard.bool(forKey: "audioPlayerRepeatEnabled")
    self.repeatMode = oldRepeat ? .all : .off
}
```

**Verification:**
- [ ] Build succeeds (no errors)
- [ ] AppSettings initializes without crash

---

## PHASE 2: AudioPlayer Integration (30 minutes)

### Step 2.1: Remove Old Boolean (2 min)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

- [ ] Find `@Published var repeatEnabled: Bool` (around line 153-159)
- [ ] Delete or comment out entire property
- [ ] Note: Will cause compiler errors (expected, fix in next step)

### Step 2.2: Add Computed RepeatMode Property (5 min)

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

- [ ] Add new computed property after shuffle property
- [ ] Use Oracle pattern: get from appSettings, set to appSettings
- [ ] Keep @Published annotation

**Code:**
```swift
/// Repeat mode (Winamp 5 Modern: off/all/one with "1" badge)
@Published var repeatMode: RepeatMode {
    get { appSettings.repeatMode }
    set { appSettings.repeatMode = newValue }
}
```

**Verification:**
- [ ] Compiler errors from step 2.1 should reduce
- [ ] Any remaining `repeatEnabled` references show as errors

### Step 2.3: Find All repeatEnabled References (3 min)

- [ ] Use Xcode Find: Search for `repeatEnabled` in project
- [ ] List all locations (likely: WinampMainWindow, AppCommands)
- [ ] Prepare to update each to use `repeatMode`

### Step 2.4: Modify nextTrack() Function (15 min)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (~line 1234)

- [ ] Find `func nextTrack()` definition
- [ ] **INSERT** repeat mode switch at **very top** of function (before existing logic)
- [ ] Case `.off`: Guard hasNextTrack, stop if false, else fall through
- [ ] Case `.all`: If !hasNextTrack, set `currentPlaylistIndex = 0`, then fall through
- [ ] Case `.one`: Restart current track (see code below), then **return** (don't fall through)
- [ ] Leave all existing logic after switch **unchanged**

**Code to INSERT at top:**
```swift
func nextTrack() {
    // ──────────────────────────────────────
    // WINAMP 5 REPEAT MODE LOGIC
    // ──────────────────────────────────────
    switch repeatMode {
    case .off:
        // Stop at playlist end (Winamp 5 off mode)
        guard hasNextTrack else {
            stop()
            return
        }
        // Fall through to existing logic

    case .all:
        // Wrap to first track (Winamp 5 repeat-all)
        if !hasNextTrack {
            currentPlaylistIndex = 0
        }
        // Fall through to existing logic

    case .one:
        // Restart current track (Winamp 5 repeat-one)
        guard let current = currentTrack else { return }

        if current.isStream {
            // Internet radio: reload via coordinator
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.coordinator?.play(track: current)
            }
        } else {
            // Local file: seek to beginning
            seek(to: 0, resume: true)
        }
        return  // ← IMPORTANT: Don't advance playlist
    }

    // ──────────────────────────────────────
    // EXISTING LOGIC (unchanged below this line)
    // ──────────────────────────────────────
    // ... existing index increment ...
    // ... existing shuffle handling ...
    // ... existing stream/local routing ...
}
```

**Verification:**
- [ ] Build succeeds
- [ ] No logic errors
- [ ] All existing nextTrack behavior preserved for .off and .all

### Step 2.5: Update previousTrack() if Needed (5 min)

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (~line 1310)

- [ ] Find `func previousTrack()` definition
- [ ] Check if it already seeks to 0 (rewind behavior)
- [ ] If yes: Add early return for repeat-one mode
- [ ] If no: Skip this step

**Code (if needed):**
```swift
func previousTrack() {
    // Repeat-one: rewind (existing seek behavior is correct)
    if repeatMode == .one {
        seek(to: 0)
        return
    }

    // ... existing previous logic unchanged ...
}
```

**Verification:**
- [ ] Build succeeds
- [ ] Previous button behavior makes sense in all modes

---

## PHASE 3: UI Button + Badge (15 minutes)

### Step 3.1: Locate Repeat Button (2 min)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Search for "MAIN_REPEAT_BUTTON" in file
- [ ] Find button definition (around line 431-438)
- [ ] Note current button structure

### Step 3.2: Replace with Three-State Button (10 min)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Replace entire button block with new code below
- [ ] Update action: `audioPlayer.repeatMode.next()`
- [ ] Update sprite logic: Use `repeatMode.isActive`
- [ ] Add ZStack with base sprite + conditional badge
- [ ] Configure "1" badge: font 8px bold, white, shadow
- [ ] Set offset: `x: 8, y: 0` (starting position)
- [ ] Update tooltip: `audioPlayer.repeatMode.label`

**Code:**
```swift
// WINAMP 5 MODERN THREE-STATE REPEAT BUTTON
Button(action: {
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}) {
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
                .offset(x: 8, y: 0)
        }
    }
}
.buttonStyle(.plain)
.help(audioPlayer.repeatMode.label)
```

### Step 3.3: Quick Visual Test (3 min)

- [ ] Build and run app
- [ ] Click repeat button multiple times
- [ ] Verify: Off (unlit) → All (lit) → One (lit + "1") → Off
- [ ] Check badge appears in center of button
- [ ] Check badge is white and legible

**If badge not visible:**
- [ ] Increase shadow radius to 1.5
- [ ] Try different offset values

---

## PHASE 4: Keyboard Shortcut (10 minutes)

### Step 4.1: Locate Existing Shortcut (3 min)

**File:** `MacAmpApp/AppCommands.swift`

- [ ] Search for "repeatEnabled" or ".control.*r" in file
- [ ] Find existing Ctrl+R shortcut (if exists)
- [ ] Note current implementation

### Step 4.2: Update to Cycle Modes (5 min)

**File:** `MacAmpApp/AppCommands.swift`

- [ ] Update button label to use `audioPlayer.repeatMode.label`
- [ ] Update action to call `audioPlayer.repeatMode.next()`
- [ ] Ensure `.keyboardShortcut("r", modifiers: [.control])`
- [ ] If using @Bindable, ensure it's in body scope

**Code:**
```swift
// In commands body (with @Bindable if needed)
Button(audioPlayer.repeatMode.label) {
    audioPlayer.repeatMode = audioPlayer.repeatMode.next()
}
.keyboardShortcut("r", modifiers: [.control])
```

### Step 4.3: Test Keyboard Shortcut (2 min)

- [ ] Build and run
- [ ] Press Ctrl+R multiple times
- [ ] Verify mode cycles: Off → All → One → Off
- [ ] Verify button updates visually
- [ ] Verify badge appears/disappears

---

## PHASE 5: Options Menu (15 minutes)

### Step 5.1: Locate Options Menu (3 min)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Search for O button menu implementation
- [ ] Find Menu { } block with time display toggle
- [ ] Note current menu structure

### Step 5.2: Add Three-State Selector (10 min)

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

- [ ] Add Divider before repeat section
- [ ] Add three Button items for off/all/one
- [ ] Use checkmark systemImage when mode matches
- [ ] Direct action: Set mode (no cycling)
- [ ] Add Divider after repeat section

**Code:**
```swift
// In Options Menu block:
Divider()

// Winamp 5 repeat mode selector
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
```

### Step 5.3: Test Options Menu (2 min)

- [ ] Build and run
- [ ] Press Ctrl+O to open Options menu
- [ ] Verify checkmark next to current mode
- [ ] Click each option
- [ ] Verify mode changes immediately
- [ ] Verify button updates

---

## TESTING PHASE (30-45 minutes)

### Visual Testing: Badge Legibility (20 min)

**Test "1" badge on all 7 bundled skins:**

- [ ] **Classic Winamp (Cmd+Shift+1)**
  - Set repeat to One mode
  - Verify "1" badge visible on green button
  - Rate legibility: Excellent / Good / Poor / Invisible

- [ ] **Internet Archive (Cmd+Shift+2)**
  - Set repeat to One mode
  - Verify "1" badge visible on beige button
  - Shadow should make it readable
  - Rate legibility: Excellent / Good / Poor / Invisible

- [ ] **Tron Vaporwave (Cmd+Shift+3)**
  - Set repeat to One mode
  - Verify "1" badge visible on dark blue button
  - Rate legibility: Excellent / Good / Poor / Invisible

- [ ] **Mac OS X (Cmd+Shift+4)**
  - Set repeat to One mode
  - Verify "1" badge visible on light gray button
  - Shadow critical here
  - Rate legibility: Excellent / Good / Poor / Invisible

- [ ] **Sony MP3 (Cmd+Shift+5)**
  - Set repeat to One mode
  - Verify "1" badge visible on silver/white button
  - **CRITICAL TEST** - worst case scenario
  - Rate legibility: Excellent / Good / Poor / Invisible
  - **If Poor/Invisible:** Increase shadow to radius: 1.5, opacity: 1.0

- [ ] **KenWood (Cmd+Shift+6)**
  - Set repeat to One mode
  - Verify "1" badge visible on black button
  - Rate legibility: Excellent / Good / Poor / Invisible

- [ ] **Winamp3 Classified (Cmd+Shift+7)**
  - Set repeat to One mode
  - Verify "1" badge visible on dark blue button
  - Rate legibility: Excellent / Good / Poor / Invisible

**Badge Adjustment (if needed):**
- [ ] If clipping right edge: Reduce x offset to 6 or 7
- [ ] If clipping bottom: Adjust y offset to -1 or -2
- [ ] If too faint: Increase shadow radius to 1.5
- [ ] If still issues: Reduce font to 7px

### Behavior Testing: Playlist Navigation (15 min)

**Setup:** Create test playlist with 5 tracks

**Off Mode (Stop at End):**
- [ ] Start at track 1
- [ ] Set repeat to Off (button unlit)
- [ ] Play through to track 5
- [ ] Press Next button → Should STOP (no track 6)
- [ ] Start at track 1, press Previous → Should STOP or rewind

**All Mode (Loop Playlist):**
- [ ] Start at track 1
- [ ] Set repeat to All (button lit, no badge)
- [ ] Play through to track 5
- [ ] Press Next button → Should jump to track 1 (wrap)
- [ ] Set to track 1, press Previous → Should jump to track 5 (wrap)

**One Mode (Repeat Current Track):**
- [ ] Start at track 3
- [ ] Set repeat to One (button lit + "1" badge)
- [ ] Press Next button → Should restart track 3 from 0:00
- [ ] Press Previous button → Should restart track 3 from 0:00
- [ ] Let track 3 play to end → Should restart automatically
- [ ] Verify playback restarts (not just stops)

**Button Cycling:**
- [ ] Click repeat button → Off to All (button lights)
- [ ] Click repeat button → All to One (badge appears)
- [ ] Click repeat button → One to Off (button dims, badge disappears)
- [ ] Click repeat button → Off to All (cycles)

**Keyboard Shortcut:**
- [ ] Press Ctrl+R → Mode cycles
- [ ] Verify matches button clicking behavior
- [ ] Verify menu label updates

**Options Menu:**
- [ ] Press Ctrl+O to open menu
- [ ] Verify checkmark next to active mode
- [ ] Click "Repeat: Off" → Button updates
- [ ] Click "Repeat: All" → Button lights up
- [ ] Click "Repeat: One" → Badge appears

### Edge Case Testing (10 min)

**Empty Playlist:**
- [ ] Clear entire playlist
- [ ] Set repeat to One mode
- [ ] Press Next → No crash, graceful handling

**Single Track:**
- [ ] Load only 1 track
- [ ] **Off mode:** Play to end → Stops
- [ ] **All mode:** Play to end → Replays same track
- [ ] **One mode:** Play to end → Replays same track
- [ ] Note: All and One behave identically (acceptable)

**Internet Radio Stream:**
- [ ] Load a stream (e.g., SomaFM)
- [ ] Set repeat to One mode
- [ ] Press Next button → Stream restarts (buffering, reconnects)
- [ ] Verify coordinator routing works

**Shuffle + Repeat One:**
- [ ] Enable shuffle
- [ ] Set repeat to One
- [ ] Press Next → Should replay current (NOT random track)
- [ ] Document: Repeat One takes precedence over shuffle

**Persistence:**
- [ ] Set mode to All → Quit app → Relaunch → Still All ✅
- [ ] Set mode to One → Quit app → Relaunch → Still One ✅
- [ ] Verify badge appears on relaunch if mode = One

**Double-Size Mode:**
- [ ] Set repeat to One
- [ ] Enable double-size (Ctrl+D)
- [ ] Verify badge still visible and positioned correctly
- [ ] If offset wrong, adjust in code

---

## DOCUMENTATION PHASE (15 minutes)

### README.md Updates (10 min)

**File:** `README.md`

- [ ] Find "Advanced Controls" or "Repeat" section
- [ ] Update to document three modes (off/all/one)
- [ ] Mention "1" badge visual indicator
- [ ] Add to Keyboard Shortcuts table: Ctrl+R cycles modes
- [ ] Update feature list if "repeat one" not mentioned

**Example text:**
```markdown
### Repeat Modes

MacAmp supports three repeat modes matching Winamp 5 Modern skins:

1. **Repeat: Off** - Stops at playlist end (button unlit)
2. **Repeat: All** - Loops entire playlist (button lit)
3. **Repeat: One** - Repeats current track (button lit + "1" badge)

**Usage:**
- Click repeat button to cycle: Off → All → One → Off
- Keyboard shortcut: Ctrl+R
- Options menu: Direct mode selection (Ctrl+O)

**Visual Indicator:** White "1" badge appears on button in Repeat One mode (Winamp 5 pattern)
```

### CHANGELOG / Release Notes (5 min)

- [ ] Add entry for v0.7.9 (or next version number)
- [ ] Title: "Three-State Repeat Mode (Winamp 5 Fidelity)"
- [ ] List: Off/All/One modes
- [ ] Mention: "1" badge indicator matching Winamp 5 Modern
- [ ] Note: Exceeds Webamp functionality

---

## PRE-COMMIT CHECKS (5 minutes)

### Code Quality

- [ ] Build succeeds with zero warnings
- [ ] No force unwraps (`!`) added to new code
- [ ] No `print()` statements (use `NSLog` if needed)
- [ ] Comments added for Winamp 5 references
- [ ] Enum follows Swift naming conventions (lowerCamelCase cases)
- [ ] All @MainActor annotations correct

### Compiler Checks

- [ ] Search project for "repeatEnabled" → Should find zero results
- [ ] All references updated to "repeatMode"
- [ ] No orphaned boolean logic remaining

### Git Checks

- [ ] On branch: `repeat-mode-toggle`
- [ ] No unrelated changes in diff
- [ ] Ready to commit

---

## COMMIT STRATEGY (Atomic Commits)

### Commit 1: Data Model
- [ ] Stage: AppSettings.swift changes only
- [ ] Commit: "feat: Add RepeatMode enum (Winamp 5 Modern pattern)"
- [ ] Message mentions: Three states, CaseIterable, migration logic

### Commit 2: AudioPlayer Integration
- [ ] Stage: AudioPlayer.swift changes
- [ ] Commit: "feat: Integrate RepeatMode into AudioPlayer"
- [ ] Message mentions: Remove boolean, add computed property

### Commit 3: Navigation Logic
- [ ] Stage: AudioPlayer.swift nextTrack() modification
- [ ] Commit: "feat: Implement three-state repeat navigation"
- [ ] Message mentions: Off/All/One behaviors, stream handling

### Commit 4: UI Button + Badge
- [ ] Stage: WinampMainWindow.swift button changes
- [ ] Commit: "feat: Add Winamp 5 '1' badge to repeat button"
- [ ] Message mentions: ZStack overlay, shadow, three visual states

### Commit 5: Keyboard Shortcut
- [ ] Stage: AppCommands.swift changes
- [ ] Commit: "feat: Update Ctrl+R to cycle repeat modes"
- [ ] Message mentions: Dynamic label, mode cycling

### Commit 6: Options Menu
- [ ] Stage: WinampMainWindow.swift menu changes
- [ ] Commit: "feat: Add repeat mode selector to Options menu"
- [ ] Message mentions: Three checkmarked options, direct selection

### Commit 7: Documentation
- [ ] Stage: README.md changes
- [ ] Commit: "docs: Document three-state repeat mode (Winamp 5)"
- [ ] Message mentions: User guide, visual indicator, keyboard shortcuts

---

## POST-IMPLEMENTATION

### Create Pull Request

- [ ] Push branch: `git push origin repeat-mode-toggle`
- [ ] Create PR with title: "Three-State Repeat Mode (Winamp 5 Modern Fidelity)"
- [ ] Description includes:
  - Summary of changes
  - Screenshot of "1" badge on button
  - Testing performed (7 skins tested)
  - Winamp 5 Modern reference
  - Link to task folder
- [ ] Self-review diff on GitHub

### Final Verification

- [ ] All 7 skins tested ✅
- [ ] All behavior tests passed ✅
- [ ] Edge cases handled ✅
- [ ] Persistence works ✅
- [ ] No crashes ✅
- [ ] Documentation complete ✅

### Merge & Cleanup

- [ ] Merge PR to main
- [ ] Delete feature branch (locally and remote)
- [ ] Tag release: `git tag -a v0.7.9 -m "Three-state repeat mode"`
- [ ] Update READY_FOR_NEXT_SESSION.md
- [ ] Move task to `tasks/done/repeat-mode-3way-toggle/`

---

## FALLBACK: If Visual Issues Found

### If "1" Badge Not Legible on Sony MP3

**Try these fixes in order:**

1. **Increase shadow:**
   ```swift
   .shadow(color: .black.opacity(1.0), radius: 1.5, x: 0, y: 0)
   ```

2. **Add stroke (outlined text):**
   ```swift
   ZStack {
       // Black outline
       Text("1").offset(x: 7.5, y: 0).foregroundColor(.black)
       Text("1").offset(x: 8.5, y: 0).foregroundColor(.black)
       Text("1").offset(x: 8, y: -0.5).foregroundColor(.black)
       Text("1").offset(x: 8, y: 0.5).foregroundColor(.black)

       // White fill
       Text("1").offset(x: 8, y: 0).foregroundColor(.white)
   }
   ```

3. **Use badge circle (Option B2):**
   ```swift
   ZStack {
       Circle()
           .fill(Color.black.opacity(0.7))
           .frame(width: 10, height: 10)
       Text("1")
           .font(.system(size: 7, weight: .bold))
           .foregroundColor(.white)
   }
   .offset(x: 8, y: -3)
   ```

### If Badge Clips Button Edges

- [ ] Adjust x: 8 → Try 6, 7, 9, 10
- [ ] Adjust y: 0 → Try -1, -2, 1, 2
- [ ] Reduce font: 8 → Try 7 or 6

---

## SUCCESS CRITERIA

### Must Pass Before Merge (Winamp 5 Fidelity)

- [ ] ✅ Button cycles: Off → All → One → Off
- [ ] ✅ "1" badge appears ONLY in repeat-one mode
- [ ] ✅ Badge legible on ALL 7 skins (minimum: Good rating)
- [ ] ✅ Off mode stops at playlist end
- [ ] ✅ All mode wraps to first track
- [ ] ✅ One mode replays current track
- [ ] ✅ Ctrl+R cycles modes
- [ ] ✅ Options menu shows checkmarks
- [ ] ✅ Mode persists across restarts
- [ ] ✅ Migration preserves user preference
- [ ] ✅ No crashes on edge cases
- [ ] ✅ No build warnings

### Nice to Have

- [ ] Badge looks pixel-perfect
- [ ] Smooth animations
- [ ] Unit tests for repeat logic

---

## TIME TRACKING

| Phase | Estimated | Actual | Status |
|-------|-----------|--------|--------|
| Research | 2h | 2h | ✅ Complete |
| Oracle Validation | 15m | 15m | ✅ Complete |
| Planning | 1h | 1h | ✅ Complete |
| Phase 1: Data Model | 20m | - | Pending |
| Phase 2: AudioPlayer | 30m | - | Pending |
| Phase 3: UI + Badge | 15m | - | Pending |
| Phase 4: Keyboard | 10m | - | Pending |
| Phase 5: Options Menu | 15m | - | Pending |
| Testing | 45m | - | Pending |
| Documentation | 15m | - | Pending |
| **TOTAL** | **6h** | **3.25h** | **54% complete** |

---

## NEXT IMMEDIATE ACTION

✅ All planning complete
✅ Oracle validated (Grade A- with fixes)
✅ Branch ready: `repeat-mode-toggle`

**START HERE:**
1. Commit consolidated documentation (current changes)
2. Begin Phase 1: Data Model (AppSettings.swift)
3. Follow checklist step-by-step

**Reference:** See plan.md for detailed code examples for each phase

---

**Status:** ✅ Ready to Code
**Blocking:** None
**Confidence:** High (Winamp 5 Modern pattern confirmed, Oracle-validated)
**Target:** Pixel-perfect match to Winamp 5 Modern skins with "1" badge
