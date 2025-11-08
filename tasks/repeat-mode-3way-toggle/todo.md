# TODO - Three-State Repeat Mode Implementation

**Task:** repeat-mode-3way-toggle
**Branch:** `repeat-mode-toggle`
**Priority:** Medium
**Estimated Time:** 2-3 hours

---

## Pre-Implementation ✅

- [x] Research Webamp implementation
- [x] Research Winamp 5 history
- [x] Analyze visual indicator options
- [x] Cross-skin compatibility research
- [x] Create task folder structure
- [x] Write research.md
- [x] Write winamp-repeat-mode-history.md
- [x] Write repeat-mode-overlay-analysis.md
- [x] Write plan.md
- [x] Write state.md
- [x] Write todo.md (this file)
- [ ] **Oracle validation of approach**
- [ ] Create `repeat-mode-toggle` feature branch

---

## Phase 1: Data Model (15 minutes)

### AppSettings.swift Changes

- [ ] Add `RepeatMode` enum with three cases (off/all/one)
- [ ] Add `next()` method to enum for cycling
- [ ] Add `label` computed property for UI display
- [ ] Replace `var repeatMode: Bool` with `var repeatMode: RepeatMode`
- [ ] Update `didSet` to persist enum rawValue
- [ ] Update `init()` to load from UserDefaults with fallback
- [ ] Test: Verify persistence works (set mode, restart app)

**Files Modified:** `MacAmpApp/Models/AppSettings.swift`

**Verification:**
```bash
# Build succeeds
swift build

# No warnings about unused Bool property
```

---

## Phase 2: Playlist Navigation Logic (30 minutes)

### Find Playlist Manager

- [ ] Locate file with `getNextTrackId()` or equivalent logic
  - Likely: `PlaylistManager.swift`, `AudioPlayer.swift`, or `PlaybackCoordinator.swift`
- [ ] Identify current repeat logic (boolean check)

### Update Navigation Logic

- [ ] Replace boolean `if repeatMode` with `switch repeatMode`
- [ ] Implement `.off` case: Stop at boundaries
- [ ] Implement `.all` case: Wrap around (modulo)
- [ ] Implement `.one` case: Return current track
- [ ] Handle edge cases:
  - [ ] Empty playlist → return nil
  - [ ] Single track → off/all replay, one replays
  - [ ] Negative offset (previous button)

**Files Modified:** TBD (find during implementation)

**Verification:**
```swift
// Manual test cases
// 1. Off mode: Next at end → nil
// 2. All mode: Next at end → first track
// 3. One mode: Next → current track
```

---

## Phase 3: UI Button + Badge (30 minutes)

### WinampMainWindow.swift Changes

- [ ] Locate repeat button code (around line 431-438)
- [ ] Replace simple button with ZStack structure
- [ ] Add base sprite (changes with mode != .off)
- [ ] Add conditional "1" badge for `.one` mode
- [ ] Configure Text view:
  - [ ] Font: `.system(size: 8, weight: .bold)`
  - [ ] Color: `.white`
  - [ ] Shadow: `.shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)`
  - [ ] Offset: `x: 8, y: 0` (adjust after visual test)
- [ ] Update tooltip to show `settings.repeatMode.label`
- [ ] Update button action to cycle: `settings.repeatMode = settings.repeatMode.next()`

**Files Modified:** `MacAmpApp/Views/WinampMainWindow.swift`

**Verification:**
```
Visual checks:
- Off: Button unlit, no badge
- All: Button lit, no badge
- One: Button lit + "1" badge
```

---

## Phase 4: Keyboard Shortcut (15 minutes)

### AppCommands.swift Changes

- [ ] Locate existing Ctrl+R shortcut (if exists)
- [ ] Update button label to use `settings.repeatMode.label`
- [ ] Update button action to cycle modes
- [ ] Verify shortcut works with `@Bindable`

**Files Modified:** `MacAmpApp/AppCommands.swift`

**Verification:**
```
Manual test:
- Press Ctrl+R repeatedly
- Verify button state updates
- Verify mode cycles: Off → All → One → Off
```

---

## Phase 5: Options Menu Integration (15 minutes)

### WinampMainWindow.swift (O Button Menu)

- [ ] Locate Options menu implementation
- [ ] Add Divider before repeat section
- [ ] Add three buttons for direct mode selection:
  - [ ] "Repeat: Off" with checkmark if `.off`
  - [ ] "Repeat: All" with checkmark if `.all`
  - [ ] "Repeat: One" with checkmark if `.one`
- [ ] Test: Click each option sets mode directly

**Files Modified:** `MacAmpApp/Views/WinampMainWindow.swift`

**Verification:**
```
Manual test:
- Open Options menu (Ctrl+O)
- Verify checkmark on active mode
- Click inactive mode → updates immediately
```

---

## Testing Phase (30-45 minutes)

### Visual Testing - Badge Visibility

Test "1" badge on all 7 bundled skins:

- [ ] **Classic Winamp (green/gray)** - Badge legible?
- [ ] **Internet Archive (beige)** - Badge legible with shadow?
- [ ] **Tron Vaporwave (dark blue)** - Badge legible?
- [ ] **Mac OS X (light gray)** - Badge legible with shadow?
- [ ] **Sony MP3 (silver/white)** - Badge legible? (CRITICAL TEST)
- [ ] **KenWood (black/red)** - Badge legible?
- [ ] **Winamp3 Classified (dark blue)** - Badge legible?

**If any skin fails:**
- [ ] Adjust offset (x, y)
- [ ] Increase shadow radius to 1.5
- [ ] Reduce font size to 7px
- [ ] Fallback: Implement Option B2 (badge circle)

### Behavior Testing - Playlist Navigation

**Setup:** Create test playlist with 5 tracks

- [ ] **Off mode - Forward:**
  - Track 5 → Next → Stops (no track)
- [ ] **Off mode - Backward:**
  - Track 1 → Previous → Stops (no track)
- [ ] **All mode - Forward:**
  - Track 5 → Next → Track 1 (wrap)
- [ ] **All mode - Backward:**
  - Track 1 → Previous → Track 5 (wrap)
- [ ] **One mode - Forward:**
  - Track 3 → Next → Track 3 (replay)
- [ ] **One mode - Backward:**
  - Track 3 → Previous → Track 3 (replay)
- [ ] **One mode - Natural End:**
  - Track plays to end → Replays from start

### Button Interaction Testing

- [ ] **Click cycling:**
  - Off → All → One → Off → All (cycles correctly)
- [ ] **Keyboard shortcut:**
  - Ctrl+R cycles modes (matches button)
- [ ] **Options menu:**
  - Direct selection works
  - Checkmark updates
- [ ] **Tooltip:**
  - Shows "Repeat: Off" when off
  - Shows "Repeat: All" when all
  - Shows "Repeat: One" when one

### Edge Case Testing

- [ ] **Empty playlist:**
  - All modes → No crash, returns nil
- [ ] **Single track:**
  - Off mode → Stops after track
  - All mode → Replays track
  - One mode → Replays track
- [ ] **Shuffle + Repeat One:**
  - Behavior documented (TBD: Disable shuffle?)

### Persistence Testing

- [ ] Set mode to All → Quit app → Relaunch → Still All
- [ ] Set mode to One → Quit app → Relaunch → Still One
- [ ] Delete UserDefaults → Launch → Defaults to Off
- [ ] Migrate from boolean `true` → Defaults to Off (graceful)

---

## Documentation Phase (15-30 minutes)

### README.md Updates

- [ ] Update "Repeat Mode" section under Controls
- [ ] Document three states (off/all/one)
- [ ] Add keyboard shortcut Ctrl+R
- [ ] Mention "1" badge indicator
- [ ] Add to Keyboard Shortcuts table
- [ ] Update feature list if needed

### CHANGELOG / Release Notes

- [ ] Add entry for v0.7.9 (or next version)
- [ ] List new feature: "Three-state repeat mode (Off/All/One)"
- [ ] Mention visual indicator ("1" badge)
- [ ] Note exceeds Webamp functionality

### state.md Updates

- [ ] Mark all phases as completed
- [ ] Document any deviations from plan
- [ ] Record final badge offset (x, y)
- [ ] Note any skin-specific adjustments
- [ ] Record total implementation time

---

## Code Quality Checks

### Pre-Commit Checklist

- [ ] Build succeeds with no warnings
- [ ] No force unwraps (`!`) added
- [ ] No `print()` statements (use `NSLog` or remove)
- [ ] Comments added for complex logic
- [ ] Enum conforms to Swift naming conventions
- [ ] Thread safety verified (@MainActor where needed)

### Code Review (Self)

- [ ] Read diff of all changes
- [ ] Verify no unrelated changes included
- [ ] Check for code duplication
- [ ] Ensure error handling for edge cases
- [ ] Validate UserDefaults key names unique

### Optional: Oracle Review

- [ ] Submit changes to Oracle for review
- [ ] Address any feedback
- [ ] Request final approval

---

## Git Workflow

### Branch Management

- [ ] Create branch: `git checkout -b repeat-mode-toggle`
- [ ] Commit after each phase:
  - [ ] Commit 1: "feat: Add RepeatMode enum to AppSettings"
  - [ ] Commit 2: "feat: Update playlist navigation for 3-state repeat"
  - [ ] Commit 3: "feat: Add visual indicator for repeat-one mode"
  - [ ] Commit 4: "feat: Update keyboard shortcut to cycle repeat modes"
  - [ ] Commit 5: "feat: Add repeat mode options to menu"
  - [ ] Commit 6: "docs: Update README with repeat mode documentation"
  - [ ] Commit 7: "test: Verify repeat mode across all skins" (if needed)

### Pull Request

- [ ] Push branch to origin
- [ ] Create PR with description:
  - Summary of changes
  - Screenshot of "1" badge
  - Testing performed
  - Link to task folder
- [ ] Self-review on GitHub
- [ ] Merge to main
- [ ] Delete feature branch

---

## Post-Merge

### Release Tagging

- [ ] Tag release: `git tag -a v0.7.9 -m "Add three-state repeat mode"`
- [ ] Push tag: `git push origin v0.7.9`

### Task Cleanup

- [ ] Move `tasks/repeat-mode-3way-toggle/` to `tasks/done/`
- [ ] Update `READY_FOR_NEXT_SESSION.md` if applicable
- [ ] Archive research documents

---

## Rollback Plan

If critical issues found after merge:

1. **Revert merge commit:**
   ```bash
   git revert <merge-commit-sha>
   ```

2. **Fix forward:**
   - Create hotfix branch
   - Address issue
   - Fast-track merge

3. **Known safe revert:**
   - Only 1 file (AppSettings) has breaking change
   - Other changes are additive (safe to revert)

---

## Success Criteria

**Functional:**
- ✅ All three modes work correctly
- ✅ Playlist navigation respects mode
- ✅ Mode persists across restarts
- ✅ No crashes on edge cases

**Visual:**
- ✅ Badge visible and legible on all 7 skins
- ✅ Button states match expected behavior
- ✅ Tooltip shows current mode

**Code Quality:**
- ✅ Type-safe enum implementation
- ✅ Clean state transitions
- ✅ Oracle-approved (if requested)
- ✅ No build warnings

---

## Time Tracking

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Research | 2h | 2h | ✅ Complete |
| Planning | 1h | 1h | ✅ Complete |
| Oracle Validation | 15m | - | Pending |
| Phase 1: Data Model | 15m | - | |
| Phase 2: Navigation Logic | 30m | - | |
| Phase 3: UI + Badge | 30m | - | |
| Phase 4: Keyboard Shortcut | 15m | - | |
| Phase 5: Options Menu | 15m | - | |
| Testing | 45m | - | |
| Documentation | 15m | - | |
| **TOTAL** | **6h** | **3h** | 50% complete |

---

**Status:** Ready for Oracle validation and implementation
**Next Action:** Submit to Oracle for review
**Blocking:** None
