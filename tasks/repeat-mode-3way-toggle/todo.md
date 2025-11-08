# TODO - Three-State Repeat Mode (Winamp 5 Modern Fidelity) ✅ COMPLETE

**Task:** repeat-mode-3way-toggle
**Branch:** `repeat-mode-toggle` ✅
**Target:** Match Winamp 5 Modern skins exactly
**Oracle Grade:** A (final, after fixes)
**Status:** Implementation Complete, User Testing Successful

---

## Pre-Implementation ✅ COMPLETE

- [x] Research Webamp implementation
- [x] Research Winamp 5 Modern skins behavior
- [x] Analyze "1" badge visual indicator
- [x] Cross-skin compatibility analysis (7 skins)
- [x] Oracle validation of approach (Grade B- → A- with corrections)
- [x] Apply Oracle critical fixes to plan
- [x] Create task folder structure
- [x] Write research.md (with Winamp 5 reference)
- [x] Consolidate all research into 4 core files
- [x] Write plan.md (Oracle corrections applied)
- [x] Write state.md (Oracle quotes integrated)
- [x] Write todo.md (this file)
- [x] Verify classic skin + badge compatibility (overlay technique)
- [x] Verify double-size mode scaling (automatic)
- [x] Commit consolidated documentation ✅ (commit 6e6aeef)
- [x] Verify branch is `repeat-mode-toggle` ✅

---

## PHASE 1: Data Model ✅ COMPLETE (15 minutes)

- [x] Define RepeatMode enum in AppSettings.swift (lines 218-248)
  - Three cases: off, all, one
  - Conforms to: String, Codable, CaseIterable
  - next() method using allCases (Oracle pattern)
  - label computed property for UI
  - isActive computed property (lit when all or one)

- [x] Add persistence property (lines 250-256)
  - var repeatMode: RepeatMode = .off
  - didSet with UserDefaults persistence
  - Key: "repeatMode"

- [x] Add migration logic in init() (lines 66-74)
  - Load new enum key first
  - Fallback: Load old "audioPlayerRepeatEnabled" boolean
  - Map: true → .all, false → .off (preserves user preference)

- [x] Build verification ✅ (0.91s, zero warnings)

**Commit:** 5c23e53 - feat: Add RepeatMode enum (Winamp 5 Modern pattern)

---

## PHASE 2: AudioPlayer Integration ✅ COMPLETE (30 minutes)

- [x] Remove old repeatEnabled boolean (line 158 deleted)
- [x] Add computed repeatMode property (lines 159-164)
  - Uses AppSettings.instance() for persistence
  - Pattern matches useSpectrumVisualizer (existing pattern)
  - Oracle-recommended architecture

- [x] Find all repeatEnabled references
  - WinampMainWindow.swift (4 locations)
  - All updated to use repeatMode

- [x] Modify nextTrack() function (lines 1240-1256)
  - Insert repeat-one check at top (before shuffle)
  - Case .one: Restarts current track (seek or coordinator)
  - Returns early for .one (doesn't advance playlist)
  - Replace old `if repeatEnabled` with `if repeatMode == .all` (line 1298)
  - All existing shuffle/stream/index logic preserved

- [x] previousTrack() evaluation
  - Already seeks to 0 (rewind)
  - No changes needed

- [x] Build verification ✅ (1.59s, zero errors)

**Commit:** e1abd17 - feat: Implement three-state repeat navigation (Winamp 5)

---

## PHASE 3: UI Button + Badge ✅ COMPLETE (12 minutes)

- [x] Locate repeat button (WinampMainWindow.swift lines 430-453)
- [x] Replace with ZStack structure
  - Action: audioPlayer.repeatMode.next()
  - Sprite logic: Use repeatMode.isActive
  - ZStack with base sprite + conditional badge
  - "1" badge: 8px bold, white, shadow (radius:1, opacity:0.8)
  - Offset: x:8, y:0 (centered in 28×15 button)
  - Tooltip: audioPlayer.repeatMode.label

- [x] Visual test
  - Button cycles: Off (unlit) → All (lit) → One (lit + "1")
  - Badge appears in center
  - Badge is white and legible

**Commit:** 6173285 - feat: Add Winamp 5 "1" badge and 3-state UI controls

---

## PHASE 4: Keyboard Shortcut ✅ COMPLETE (5 minutes)

- [x] Added Ctrl+R to AppCommands.swift (lines 57-60)
  - Button label: audioPlayer.repeatMode.label (dynamic)
  - Action: audioPlayer.repeatMode.next()
  - Shortcut: Ctrl+R
  - Standalone menu item (direct access)

- [x] Test keyboard shortcut
  - Press Ctrl+R → Mode cycles
  - Button updates visually
  - Badge appears/disappears

**Commit:** 6173285 (same commit)

---

## PHASE 5: Options Menu ✅ COMPLETE (10 minutes + Oracle fix)

**Initial Implementation (commit 6173285):**
- [x] Single cycling menu item (incomplete per Oracle)

**Oracle Fix (commit 7b29edc):**
- [x] Three explicit menu items (WinampMainWindow.swift lines 884-913)
  - "Repeat: Off" - checkmark when .off
  - "Repeat: All" - checkmark when .all
  - "Repeat: One" - checkmark when .one, Ctrl+R shortcut
  - Direct mode selection (no cycling)
  - Matches plan.md Phase 5 spec

- [x] Test Options menu
  - Press Ctrl+O → Menu opens
  - Checkmark shows current mode
  - Click any option → Mode changes
  - Button updates immediately

**Commit:** 7b29edc - fix: Restore manual Next skip + complete Phase 5 menu

---

## ORACLE REVIEW FIXES ✅ COMPLETE

**First Review (Grade B-):**
- [x] Applied all 5 critical corrections to plan

**Final Review (Grade C → A):**

**CRITICAL Fix - Manual Next Skip:**
- [x] Problem: Next button blocked in repeat-one mode
- [x] Solution: Added isManualSkip parameter to nextTrack()
- [x] Auto-advance: false (repeats current)
- [x] Manual skip: true (advances playlist)
- [x] Winamp 5 accuracy restored

**MAJOR Fix - Phase 5 Options Menu:**
- [x] Problem: Single cycling menu item (couldn't select specific mode)
- [x] Solution: Three explicit menu items with checkmarks
- [x] Users can now jump directly to Off/All/One
- [x] Matches Winamp 5 UX

**Commit:** 7b29edc - fix: Restore manual Next skip in repeat-one mode (Winamp 5)

---

## TESTING PHASE ✅ USER CONFIRMED

### Visual Testing: Badge Legibility ✅ ALL PASSED

**User Feedback:** "All tests passed - '1' badge shows up well across skins"

- [x] Classic Winamp - Badge legible ✅
- [x] Internet Archive - Badge legible ✅
- [x] Tron Vaporwave - Badge legible ✅
- [x] Mac OS X - Badge legible ✅
- [x] Sony MP3 (worst case) - Badge legible ✅
- [x] KenWood - Badge legible ✅
- [x] Winamp3 Classified - Badge legible ✅

**Result:** Shadow technique works on 100% of skins

### Behavior Testing ✅ ALL PASSED

- [x] Button cycling: Off → All → One → Off ✅
- [x] "1" badge appears ONLY in repeat-one mode ✅
- [x] Ctrl+R cycles modes ✅
- [x] Options menu shows checkmarks ✅
- [x] Off mode: Stops at playlist end ✅
- [x] All mode: Wraps to first track ✅
- [x] One mode: Manual skip works, auto-restart works ✅

### Edge Cases ✅

- [x] Empty playlist: No crash
- [x] Single track: All modes work
- [x] Shuffle + Repeat One: Repeat takes precedence
- [x] Streams + Repeat One: Coordinator routing works
- [x] Persistence: Mode survives restart

---

## DOCUMENTATION ✅ COMPLETE

### README.md Updates ✅

- [x] Remove "Repeat One/All modes" from Known Limitations (line 452 removed)
- [x] Add "Three-State Repeat" to Key Features (line 25)
- [x] Add detailed "Repeat Modes" usage section (lines 151-174)
  - Three modes documented
  - Usage instructions (button, Ctrl+R, Options menu)
  - Behavior details (off/all/one)
  - Winamp compatibility notes
- [x] Add Ctrl+R to Keyboard Shortcuts table (line 334)

### Task Documentation ✅

- [x] plan.md - Implementation strategy with Oracle fixes
- [x] research.md - Winamp 5 reference + cross-skin analysis
- [x] state.md - Technical decisions + Oracle validation
- [x] todo.md - This file (complete checklist)
- [x] TESTING_GUIDE.md - User testing instructions

---

## COMMITS SUMMARY (4 total)

1. **6e6aeef** - docs: Consolidate repeat mode planning into 4 core files
2. **5c23e53** - feat: Add RepeatMode enum (Winamp 5 Modern pattern)
3. **e1abd17** - feat: Implement three-state repeat navigation (Winamp 5)
4. **6173285** - feat: Add Winamp 5 "1" badge and 3-state UI controls
5. **7b29edc** - fix: Restore manual Next skip + complete Phase 5 menu

**Branch:** `repeat-mode-toggle`
**Ready for:** Pull Request + Merge to main

---

## SUCCESS CRITERIA ✅ ALL MET

### Must Have (Winamp 5 Fidelity)
- [x] ✅ Three modes work correctly (off/all/one)
- [x] ✅ Button cycles through states on click
- [x] ✅ White "1" badge appears in repeat-one mode
- [x] ✅ Badge legible on all 7 bundled skins (USER CONFIRMED)
- [x] ✅ Keyboard shortcut (Ctrl+R) cycles modes
- [x] ✅ Mode persists across app restart
- [x] ✅ Migration preserves user preference (true → .all)
- [x] ✅ Matches Winamp 5 Modern visual exactly
- [x] ✅ Manual skip works in repeat-one mode (Oracle fix)
- [x] ✅ Options menu has three explicit choices (Oracle fix)

### Nice to Have
- [x] ✅ Options menu with direct mode selection
- [x] ✅ Tooltip shows current mode
- [x] ✅ No build warnings
- [x] ✅ Oracle-approved code quality (Grade A)

---

## ORACLE FINAL GRADE: A

**Fixes Applied:**
- ✅ Manual skip parameter (isManualSkip) separates auto-advance from user action
- ✅ Options menu completed with three explicit items + checkmarks
- ✅ Pattern consistency maintained with existing MacAmp code
- ✅ No code quality issues (no TODOs, no force unwraps, proper weak self)
- ✅ Winamp 5 fidelity confirmed

**Oracle Quote:**
> "Implementation meets the spec; I'd score it an A."

---

## TIME TRACKING - FINAL

| Phase | Estimated | Actual | Status |
|-------|-----------|--------|--------|
| Research | 2h | 2h | ✅ Complete |
| Oracle Validation | 15m | 30m | ✅ Complete (2 reviews) |
| Planning | 1h | 1h | ✅ Complete |
| Phase 1: Data Model | 20m | 15m | ✅ Complete |
| Phase 2: AudioPlayer | 30m | 30m | ✅ Complete |
| Phase 3: UI + Badge | 15m | 12m | ✅ Complete |
| Phase 4: Keyboard | 10m | 5m | ✅ Complete |
| Phase 5: Options Menu | 15m | 10m | ✅ Complete |
| Oracle Fixes | - | 15m | ✅ Complete |
| Testing (User) | 20m | 10m | ✅ Complete |
| Documentation | 15m | 15m | ✅ Complete |
| **TOTAL** | **6h** | **5h 42m** | **100% COMPLETE** |

---

## NEXT STEPS

- [x] All implementation complete
- [x] All testing passed
- [x] Oracle grade: A
- [x] README updated
- [x] Task docs updated
- [ ] **Commit README changes** ← NEXT
- [ ] **Update state.md final status**
- [ ] **Create Pull Request**
- [ ] **Merge to main**
- [ ] **Tag release v0.7.9 (or v0.8.0)**

---

**Status:** ✅ READY FOR PR
**Blocking:** None
**Confidence:** Very High (Oracle A, user testing passed, Winamp 5 fidelity confirmed)
