# Phase 3: NSMenuDelegate Pattern - TODO

**Branch:** feature/phase3-nsmenu-delegate
**Status:** ✅ COMPLETE
**Started:** 2025-10-29
**Completed:** 2025-10-29
**Actual Time:** ~2 hours

---

## Implementation Checklist

### Step 1: Create PlaylistMenuDelegate (30 min) ✅

- [x] Create new file: `MacAmpApp/Views/Components/PlaylistMenuDelegate.swift`
- [x] Implement NSMenuDelegate protocol
- [x] Implement `menu(_:willHighlight:)` method
- [x] Add @MainActor annotation
- [x] Handle sprite menu item highlighting
- [x] Build and verify no errors

---

### Step 2: Refactor SpriteMenuItem (45 min) ✅

**Current File:** `MacAmpApp/Views/Components/SpriteMenuItem.swift`

- [x] Rename `isHovered` → `spriteHighlighted` (property)
- [x] Make `spriteHighlighted` public (was private)
- [x] Delete HoverTrackingView class (lines 12-45)
- [x] Add ClickForwardingView (minimal, 15 lines)
- [x] Remove `hoverTrackingView` property from SpriteMenuItem
- [x] Simplify `setupView()` with ClickForwardingView container
- [x] Update `updateView()` to use `spriteHighlighted`
- [x] Update SpriteMenuItemView struct to use `isHighlighted`
- [x] Build and verify no errors

**Code Reduction:** Net -19 lines (cleaner)

---

### Step 3: Update WinampPlaylistWindow (30 min) ✅

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

- [x] Add `@State private var menuDelegate = PlaylistMenuDelegate()`
- [x] Find all menu creation functions (4 menus: ADD, REM, SEL/MISC, LIST)
- [x] Add `menu.delegate = menuDelegate` to each menu creation
- [x] Fix SEL button position (x: 68 → 78)
- [x] Fix MISC button position (x: 94 → 105)
- [x] Fix button widths (SEL/MISC: 22 → 18px)
- [x] Build and verify no errors

**Menus Updated:**
- [x] ADD button menu creation
- [x] REM button menu creation
- [x] MISC button menu creation (was SEL in plan)
- [x] LIST button menu creation

---

### Step 4: Testing (30-45 min) ✅

**Keyboard Navigation:**
- [x] Click ADD button
- [x] Press ↓ arrow key - item highlights ✅
- [x] Press ↓ again - next item highlights ✅
- [x] Press ↑ arrow key - previous item highlights ✅
- [x] Press Enter - item activates ⚠️ (doesn't work - AppKit limitation)
- [x] Press Escape - menu dismisses ✅
- [x] Repeat for REM, MISC, LIST menus ✅

**Mouse Hover (Regression Test):**
- [x] Click ADD button
- [x] Hover over items - highlights on hover ✅
- [x] Click item - activates correctly ✅
- [x] Verify no visual changes from before ✅

**VoiceOver:**
- [x] Delegate pattern supports VoiceOver (not tested but ready)

**All 4 Menus:**
- [x] ADD menu works ✅
- [x] REM menu works ✅
- [x] MISC menu works ✅ (was SEL in plan)
- [x] LIST menu works ✅

---

### Step 5: Commit & PR (15 min) ✅

- [x] Stage changes (5 files)
- [x] Commit Phase 3 (commit a2e21b6)
- [x] Commit Timer.publish warning fixes (commit 152c052)
- [x] Commit Enter key attempt (commit 7ac2491)
- [x] Push branch
- [x] Create PR #25 to main
- [ ] Merge PR (pending review)

---

## Files Modified

1. **NEW:** `MacAmpApp/Views/Components/PlaylistMenuDelegate.swift` (~20 lines)
2. **EDIT:** `MacAmpApp/Views/Components/SpriteMenuItem.swift` (-30 lines, +10 lines)
3. **EDIT:** `MacAmpApp/Views/WinampPlaylistWindow.swift` (+4 lines)

**Total:** 3 files, net -16 lines

---

## Success Criteria

- [x] HoverTrackingView removed
- [ ] PlaylistMenuDelegate created
- [ ] Keyboard navigation works
- [ ] VoiceOver announces items
- [ ] Mouse hover still works
- [ ] No visual regressions
- [ ] Build succeeds
- [ ] All tests pass

---

## Rollback Plan

If anything breaks:

```bash
git revert HEAD  # Revert Phase 3 commit
# Or
git reset --hard main  # Reset to before Phase 3
```

---

**Status:** ✅ Ready to implement
**Complexity:** Low (standard AppKit pattern)
**Risk:** Low (only affects menu behavior)
