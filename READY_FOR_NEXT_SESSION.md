# MacAmp - Ready for Next Session

**Last Updated**: 2025-11-09
**Current Branch**: `feature/video-milkdrop-windows`
**Current Task**: TASK 2 (milk-drop-video-support)
**Status**: ✅ Planning Complete - Oracle GO (A- grade, High confidence)

---

## 🎯 START NEXT SESSION WITH THIS EXACT MESSAGE

Copy and paste exactly:

```
Begin TASK 2 (milk-drop-video-support) - Video + Milkdrop Windows

Context:
- Branch: feature/video-milkdrop-windows ✅
- TASK 1 (magnetic-docking-foundation): COMPLETE, merged to main (PR #31) ✅
- TASK 2 Planning: COMPLETE with Oracle GO (A- grade) ✅

Oracle Approved:
- 8-10 day plan
- NSWindowController pattern (following TASK 1)
- Single audio tap extension
- V button → Video window
- Options menu → Milkdrop window
- NO window resize (deferred to TASK 3)

Ready to implement Day 1:
1. Create WinampVideoWindowController.swift
2. Create WinampMilkdropWindowController.swift
3. Follow plan in: tasks/milk-drop-video-support/plan.md

Start with: Day 1, line 110 in plan.md
```

---

## 📋 TASK 2 QUICK REFERENCE

**What We're Building**:
- Video window (VIDEO.BMP skinning, AVPlayer playback)
- Milkdrop window (GEN.BMP chrome, Butterchurn visualization)
- Total: 5 windows (Main, EQ, Playlist, Video, Milkdrop)

**Architecture**:
- NSWindowController pattern (proven in TASK 1)
- WindowCoordinator integration
- WindowSnapManager registration
- Single audio tap extension (no new analyzer)

**Timeline**: 8-10 days
**Current Day**: Starting Day 1

**Plan Location**: `tasks/milk-drop-video-support/plan.md`

---

## ✅ TASK 1 COMPLETE (Foundation Available)

**Status**: ✅ Merged to main (PR #31)
**Grade**: Oracle A (Production-Ready)

**What TASK 1 Provides**:
- NSWindowController pattern for borderless windows
- WindowCoordinator singleton (manages all windows)
- WindowSnapManager (magnetic snapping)
- Delegate multiplexer (extensible)
- WindowFrameStore (automatic persistence)

**TASK 2 follows this exact pattern!**

---

## 🚀 DAY 1 FIRST TASK

**Create**: `MacAmpApp/Windows/WinampVideoWindowController.swift`

**Pattern** (see plan.md lines 112-161):
```swift
class WinampVideoWindowController: NSWindowController {
    convenience init(...) {
        let window = BorderlessWindow(...)
        // Follow TASK 1 pattern exactly
    }
}
```

**Checklist**: tasks/milk-drop-video-support/plan.md lines 165-170

---

## 📊 ORACLE STATUS

**Final Validation**: A- Grade, GO ✅
**Confidence**: HIGH
**Blockers**: NONE

---

That's it! Ready to start TASK 2 implementation. 🚀
