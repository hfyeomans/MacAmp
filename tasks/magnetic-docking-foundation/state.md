# Magnetic Docking Foundation - Task State

**Task ID**: magnetic-docking-foundation  
**Created**: 2025-11-08  
**Status**: 🔨 IN PROGRESS - Day 1 (80% complete)  
**Priority**: P0 (BLOCKER for Video/Milkdrop)

---

## Current Phase
**Phase 1A: NSWindowController Setup - Day 1** (80% complete)

### Progress: Day 1

**Completed** ✅:
- [x] WindowCoordinator.swift created (81 lines, Oracle A-grade pattern)
- [x] WinampMainWindowController.swift created (36 lines)
- [x] WinampEqualizerWindowController.swift created (36 lines)
- [x] WinampPlaylistWindowController.swift created (36 lines)
- [x] MacAmpApp.swift updated (WindowCoordinator initialization)
- [x] All files committed to git

**Remaining** ⏳:
- [ ] Add 4 new files to Xcode project (requires Xcode IDE)
- [ ] Build and verify compilation
- [ ] Delete UnifiedDockView.swift
- [ ] Test: 3 windows launch
- [ ] Verify: Windows positioned in default stack
- [ ] Commit: Day 1 complete

### Blocker
**Files created but not in Xcode project** - Need to add via Xcode IDE:
1. WindowCoordinator.swift
2. WinampMainWindowController.swift
3. WinampEqualizerWindowController.swift
4. WinampPlaylistWindowController.swift

**Next Action**: Open MacAmpApp.xcodeproj, add 4 files to target

---

## Task Sequencing (IMPORTANT!)

### This is Task 1 of 2

**TASK 1 (THIS): magnetic-docking-foundation** (10-15 days, Day 1 in progress)
- Scope: Break out Main/EQ/Playlist + basic snapping
- Current: Day 1 ~80% complete
- Next: Xcode project integration
- Deliverable: 3-window foundation with magnetic docking

**TASK 2 (NEXT): milk-drop-video-support** (8-10 days)
- Start AFTER Task 1 complete
- Scope: Add Video + Milkdrop windows
- Status: Blocked on Task 1
- Deliverable: Full 5-window architecture

**NOT Blended**: Each task is independent, sequential execution

---

## Day 1 Implementation Details

### Files Created (Commit: 645d88a)

**WindowCoordinator.swift** (81 lines):
```swift
@MainActor @Observable
final class WindowCoordinator {
    static var shared: WindowCoordinator!
    // Manages 3 NSWindowControllers
    // Environment injection via init parameters
    // Oracle A-grade fixes applied
}
```

**NSWindowController Pattern** (all 3 files):
```swift
class Winamp[Main|Equalizer|Playlist]WindowController: NSWindowController {
    convenience init(dependencies...) {
        let window = NSWindow(
            styleMask: [.borderless],  // Oracle fix: ONLY borderless
            ...
        )
        let contentView = Winamp[Type]Window()
            .environment(...)  // All 6 environments injected
        window.contentView = NSHostingView(rootView: contentView)
    }
}
```

**MacAmpApp.swift** (modified):
- WindowCoordinator.shared initialized with all dependencies
- UnifiedDockView WindowGroup removed
- Settings{EmptyView()} placeholder for manual window creation

### Oracle Compliance ✅

All Oracle A-grade fixes applied:
1. ✅ Style mask: [.borderless] ONLY (lines 10-11 in controllers)
2. ✅ Delegate multiplexers: Stored as properties (WindowCoordinator lines 14-18)
3. ✅ Environment injection: Proper dependency passing (lines 24-53)
4. ✅ Observation import: Added (WindowCoordinator line 3)
5. ✅ AppSettings.instance(): Pattern ready for Phase 5

---

## Next Session Actions

### 1. Add Files to Xcode Project (5-10 minutes)

**Via Xcode IDE**:
```
1. Open MacAmpApp.xcodeproj in Xcode
2. In Project Navigator:
   - Right-click "ViewModels" group
   - Add Files to "MacAmp"...
   - Select: MacAmpApp/ViewModels/WindowCoordinator.swift
   - Check: "MacAmp" target
   
3. In Project Navigator:
   - Right-click "MacAmpApp" group
   - Create "Windows" group (if needed)
   - Add Files to "MacAmp"...
   - Select all 3 *WindowController.swift files
   - Check: "MacAmp" target

4. Build (⌘B) - should compile now
```

### 2. Delete UnifiedDockView.swift

**After successful build**:
```bash
git rm MacAmpApp/Views/UnifiedDockView.swift
git commit -m "refactor: Remove UnifiedDockView (replaced by 3 NSWindows)"
```

### 3. Test Launch

- Run app (⌘R)
- Verify: 3 windows appear
- Verify: Positioned in vertical stack
- Expected: Windows NOT draggable yet (Phase 1B)

### 4. Complete Day 1

```bash
git commit -m "test: Verify 3 NSWindows launch in default stack

Day 1 Complete:
- 3 independent NSWindowControllers created
- Windows launch on app start
- Positioned in default vertical stack
- Not draggable yet (expected - Phase 1B)

Next: Day 4-6, Phase 1B - Add drag regions"
```

---

## Commit History (Day 1)

**Commit 645d88a**: Phase 1A code created
- 4 new Swift files (Oracle A-grade pattern)
- MacAmpApp.swift updated
- Environment injection properly set up

**Next Commit** (after Xcode integration):
- Add files to Xcode project
- Delete UnifiedDockView.swift
- Test 3 windows launch

---

## Oracle A-Grade Checklist

Day 1 Implementation:
- ✅ Borderless windows ([.borderless] ONLY)
- ✅ Delegate multiplexers (stored as properties)
- ✅ Environment injection (all 6 dependencies)
- ✅ Import Observation
- ✅ Proper init pattern

Code Quality:
- ✅ Follows Oracle A-grade plan exactly
- ✅ No deviations from approved architecture
- ✅ Clean, commented code
- ✅ Ready for integration

---

**Day 1 Status**: 80% complete (code ready, needs Xcode project integration)  
**Next**: Add files to Xcode project, build, test  
**Timeline**: On track for 10-15 day foundation delivery
