# Day 1 Regressions (Expected & Documented)

**Date**: 2025-11-08  
**Status**: App launches successfully, feature regressions expected

---

## ✅ Day 1 Success

**3 Windows Launch**: Verified by user  
**Build**: No errors  
**Runtime**: No crashes

---

## ⚠️ Known Regressions (Expected After Removing UnifiedDockView)

### Regression #1: Skins Don't Auto-Load

**Symptom**: Skins didn't show up until user selected "Refresh Skins"

**Root Cause**: 
- UnifiedDockView likely had skin initialization logic
- WindowCoordinator doesn't trigger skin loading yet

**Fix Required** (Day 2):
- Ensure SkinManager.loadDefaultSkin() called on launch
- Or trigger skin loading in WindowCoordinator.init()

**Priority**: Medium (workaround: user can refresh skins)

---

### Regression #2: Always-On-Top (Ctrl+A / A Button) Broken

**Symptom**: Windows don't stay on top when toggled

**Root Cause**:
- UnifiedDockView likely handled window.level changes
- Individual NSWindows need window.level = .floating when toggled

**Fix Required** (Day 2-3):
- WindowCoordinator needs to observe AppSettings.isAlwaysOnTop
- Apply window.level to all 3 windows when toggled

**Code Pattern**:
```swift
// In WindowCoordinator
func updateAlwaysOnTop(_ enabled: Bool) {
    let level: NSWindow.Level = enabled ? .floating : .normal
    mainWindow?.level = level
    eqWindow?.level = level
    playlistWindow?.level = level
}
```

**Priority**: High (common user feature)

---

### Other Potential Regressions (To Test)

**Double-Size Mode (Ctrl+D)**:
- UnifiedDockView handled scaling
- Now each window needs individual scaling
- To test: Press D button, verify windows scale
- Fix: Phase 4 (Days 13-15) - already planned!

**Window Visibility Toggles** (Menu: Window > Show/Hide):
- Should still work (WindowCoordinator has show/hide methods)
- To test: Menu commands

**Playlist Resize**:
- May not work yet (resizing not implemented)
- Fix: Deferred feature (not in foundation scope)

---

## 📋 Day 2 Task List (Fix Regressions)

### High Priority
1. [ ] Fix Always-On-Top (window.level changes)
2. [ ] Wire AppSettings.isAlwaysOnTop to WindowCoordinator
3. [ ] Test Ctrl+A / A button works

### Medium Priority
4. [ ] Fix skin auto-loading on launch
5. [ ] Test skin changes apply to all windows

### Testing
6. [ ] Test Double-Size mode (may be broken, fix in Phase 4)
7. [ ] Test menu commands (Show/Hide windows)
8. [ ] Test other clutter bar features

---

## Expected vs Actual Behavior

**Expected (Day 1)**:
- 3 windows launch ✅
- Windows positioned in stack ✅
- Windows NOT draggable (Phase 1B) ✅
- Some features broken (expected) ✅

**Actual**:
- 3 windows launched ✅
- Skins need refresh (regression)
- Always-on-top broken (regression)

**Conclusion**: Day 1 architecture successful, feature regressions expected and fixable!

---

**Day 1 Assessment**: ✅ SUCCESSFUL (architecture works)  
**Regressions**: Expected (features to rewire)  
**Next**: Day 2 - Fix regressions, continue Phase 1A
