# MacAmp - Ready for Next Session

**Last Updated**: 2025-11-08 (Day 1 Complete + Regressions Analyzed)  
**Current Branch**: `feature/magnetic-docking-foundation` ✅  
**Current Task**: Task 1 - Magnetic Docking Foundation  
**Phase**: Day 2 Next - Fix Regressions (~45 min)  
**Oracle Grade**: **A** 🏆

---

## 🎯 IMMEDIATE NEXT SESSION ACTIONS

### 1. Add BorderlessWindow.swift to Xcode (2 min)
**File**: `MacAmpApp/Windows/BorderlessWindow.swift`  
**Action**: Right-click "Windows" group → Add Files  
**Critical**: Fixes windows falling behind on click

### 2. Fix 3 Critical Regressions (~45 min total)

**Regression #1**: Skin Auto-Loading (10 min)
- Add ensureSkin() call to WindowCoordinator
- See: `tasks/magnetic-docking-foundation/MIGRATION_ANALYSIS.md` Line 15-30

**Regression #2**: Always-On-Top Broken (30 min)
- Observe AppSettings.isAlwaysOnTop in WindowCoordinator
- Update all 3 window levels when toggled
- See: MIGRATION_ANALYSIS.md Lines 34-60

**Regression #3**: Windows Fall Behind on Click (DONE ✅)
- BorderlessWindow.swift created
- Just needs Xcode integration

### 3. Test & Continue Day 2-3

After fixes:
- Test: Ctrl+A works (windows stay on top)
- Test: Skins auto-load
- Test: Clicking buttons keeps window active
- Continue Phase 1A

---

## 📋 Day 1 Summary

### ✅ Achieved
- WindowCoordinator architecture (Oracle A-grade)
- 3 NSWindowControllers (borderless windows)
- UnifiedDockView removed
- App builds and launches ✅
- 3 independent windows created ✅

### ⚠️ Regressions Found (Expected & Analyzed)
1. Skins need manual refresh → Fix identified ✅
2. Always-on-top broken → Fix identified ✅
3. Windows fall behind on click → Fix created ✅

**Analysis Complete**: `tasks/magnetic-docking-foundation/MIGRATION_ANALYSIS.md`

---

## 🎯 Task Sequence

**TASK 1** (IN PROGRESS - Day 1 ✅, Day 2 Next):
- Day 1: Architecture created (complete)
- Day 2: Fix regressions (~45 min)
- Days 2-3: Continue Phase 1A
- Days 4-6: Phase 1B (Drag Regions)
- Days 7-15: Phases 2-5 (Snap, Multiplexer, Double-Size, Persistence)

**TASK 2** (BLOCKED):
- Resume after Task 1 complete
- Add Video + Milkdrop windows

---

## 📊 Progress

**Overall**: Day 1 of 10-15 complete (~7%)  
**Phase 1A**: Day 1 done, Day 2-3 next  
**Oracle Grade**: A (maintained)  
**Build**: ✅ Working (after adding BorderlessWindow.swift)

---

**Latest Commit**: `167bd2c` (migration analysis)  
**Total Session Commits**: 18  
**Next**: Day 2 regression fixes (~45 min)  
**See**: MIGRATION_ANALYSIS.md for detailed fix guide
