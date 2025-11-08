# Magnetic Docking Foundation - Task State

**Task ID**: magnetic-docking-foundation
**Created**: 2025-11-08
**Status**: ✅ Oracle A-grade approved, ready for implementation
**Priority**: P0 (BLOCKER for Video/Milkdrop)

---

## Current Phase
**Phase 1: Ready for Implementation** (Oracle A-grade approved)

## Task Sequencing (IMPORTANT!)

### This is Task 1 of 2

**TASK 1 (THIS): magnetic-docking-foundation** (10-14 days)
- Scope: Break out Main/EQ/Playlist + basic snapping
- Deliverable: 3-window foundation with magnetic docking
- Archive when complete: `tasks/done/magnetic-docking-foundation/`

**TASK 2 (NEXT): milk-drop-video-support** (8-10 days)
- Start AFTER Task 1 complete
- Scope: Add Video + Milkdrop windows
- Deliverable: Full 5-window architecture

**NOT Blended**: Each task is independent, sequential execution

**Total Timeline**: 18-24 days for both tasks

---

## Why This Task Exists

### Blocker Discovery
**From**: `tasks/milk-drop-video-support/` Oracle consultation  
**Finding**: Video/Milkdrop plan had NO NSWindow infrastructure  
**Grade**: B- (NO-GO until infrastructure fixed)

**Oracle's Verdict**:
> "Current plan mounts views inside WinampMainWindow. No actual NSWindow lifecycle. This is a showstopper."

**Strategic Decision**: Build multi-window foundation FIRST, then add Video/Milkdrop

### Task Dependency Chain

```
milk-drop-video-support (original plan)
         ↓
   Oracle review (B- grade)
         ↓
   BLOCKER: No NSWindow infrastructure
         ↓
   Create foundation task
         ↓
magnetic-docking-foundation (THIS TASK)
         ↓
   Complete 3-window foundation
         ↓
   Resume milk-drop-video-support
         ↓
   Add Video + Milkdrop windows
         ↓
   ALL DONE!
```

---

## Scope: Foundation vs Full Implementation

### Foundation (THIS TASK) - 10-14 Days

**Core Infrastructure**:
- ✅ NSWindowController architecture
- ✅ WindowCoordinator singleton
- ✅ 3 independent NSWindows (Main, EQ, Playlist)
- ✅ Custom drag regions (borderless windows)
- ✅ WindowSnapManager integration (15px snap)
- ✅ Basic cluster movement
- ✅ Delegate multiplexer
- ✅ Basic double-size coordination
- ✅ Basic persistence

**Deliverable**: Working 3-window magnetic docking

### Deferred Features (Add Later If Needed)

**Polish** (not blocking Video/Milkdrop):
- ⏳ Playlist resize-aware docking
- ⏳ Z-order cluster focus
- ⏳ Scaled snap threshold (30px at 2x)
- ⏳ Advanced persistence (off-screen detection)
- ⏳ Accessibility polish

**Rationale**: Get infrastructure working, add polish incrementally

---

## Progress Summary

### ✅ Research Phase (100% Complete)
- [x] Reviewed existing magnetic-window-docking research
- [x] Synthesized multi-window architecture research
- [x] Analyzed WindowSnapManager implementation
- [x] Studied Webamp magnetic snapping
- [x] Oracle architectural guidance received
- [x] Created consolidated research.md

### ✅ Planning Phase (100% Complete)
- [x] Created focused foundation plan.md
- [x] Defined clear scope (foundation only)
- [x] Created todo.md (100+ tasks)
- [x] Oracle validation (A-grade achieved!)

### 🎯 Ready for Implementation
- [x] Oracle approved foundation plan (A-grade)
- [x] Created foundation todo.md
- [ ] Begin Phase 1A (NSWindowController setup) ← START HERE

---

## Key Decisions

| Decision | Choice | Date | Source |
|----------|--------|------|--------|
| **Task Sequencing** | Foundation FIRST, then Video/Milkdrop | 2025-11-08 | Oracle + User |
| **Architecture** | NSWindowController (not WindowGroup) | 2025-11-08 | Oracle |
| **Scope** | Foundation only (defer polish) | 2025-11-08 | Strategic |
| **Timeline** | 10-14 days | 2025-11-08 | Estimate |
| **Drag Priority** | Phase 1B (immediately after setup) | 2025-11-08 | Oracle |

---

## Timeline

| Phase | Days | Deliverable |
|-------|------|-------------|
| **1A** | 2-3 | NSWindowControllers created |
| **1B** | 2-3 | Drag regions working |
| **2** | 3-4 | Magnetic snapping enabled |
| **3** | 1-2 | Delegate multiplexer |
| **4** | 2-3 | Double-size coordination |
| **5** | 1-2 | Basic persistence |
| **Total** | **10-14** | **Foundation complete** |

**Milestone**: Day 10-14 - Foundation complete, ready for Video/Milkdrop

---

## After Foundation Complete

### Resume Task 2: milk-drop-video-support

**What Foundation Enables**:
- ✅ Established NSWindowController pattern
- ✅ WindowSnapManager proven working
- ✅ Video window just follows pattern
- ✅ Milkdrop window just follows pattern
- ✅ All 5 windows snap together

**Task 2 Timeline**: 8-10 days (much easier after foundation)

**Task 2 Scope**:
- Add VideoWindowController
- Add MilkdropWindowController
- VIDEO.bmp sprite parsing
- Butterchurn integration
- Register with WindowSnapManager (1-line per window!)

---

## Artifacts

### Created (Foundation Task)
1. **research.md** - Synthesized from 3 sources
2. **plan.md** - Focused foundation plan (this file)
3. **todo.md** - To be created
4. **state.md** - This file

### Source Material Referenced
1. `tasks/magnetic-window-docking/` - Original research (10-23 to 11-02)
2. `tasks/milk-drop-video-support/` - Oracle feedback (11-08)
3. `docs/MULTI_WINDOW_ARCHITECTURE.md` - SwiftUI patterns (11-08)

---

## Next Actions

1. ⏳ Create foundation todo.md
2. ⏳ Consult Oracle to validate foundation plan
3. ⏳ Get user approval
4. ⏳ Begin Phase 1A implementation
5. ⏳ Complete foundation (10-14 days)
6. ⏳ Archive this task to `tasks/done/`
7. ⏳ Resume `milk-drop-video-support` task

---

**Task Relationship**: PREREQUISITE for milk-drop-video-support  
**Execution**: Sequential, not blended  
**Status**: 🎯 READY FOR ORACLE VALIDATION  
**Last Updated**: 2025-11-08

---

## Commit Strategy (Foundation Task)

**Branch**: `feature/magnetic-docking-foundation`  
**Pattern**: Atomic commits at logical checkpoints  
**Total**: ~15-20 commits

### Phase 1A: NSWindowController Setup (4-5 commits)

1. `feat: Create WindowCoordinator singleton for multi-window management`
2. `feat: Create WinampMainWindowController (NSWindowController)`
3. `feat: Create Equalizer and Playlist NSWindowControllers`
4. `refactor: Replace UnifiedDockView with WindowCoordinator`
5. `refactor: Remove UnifiedDockView (replaced by 3 NSWindows)`

### Phase 1B: Drag Regions (3-4 commits)

1. `feat: Add WindowAccessor for SwiftUI → NSWindow bridge`
2. `feat: Add custom titlebar drag region to Main window`
3. `feat: Add titlebar drag regions to Equalizer and Playlist`
4. `fix: Improve drag region performance and smoothness`

### Phase 2: WindowSnapManager Integration (2-3 commits)

1. `feat: Register 3 windows with WindowSnapManager`
2. `feat: Enable 15px magnetic snapping for all windows`
3. `fix: Adjust cluster movement for edge cases`

### Phase 3: Delegate Multiplexer (1-2 commits)

1. `feat: Create WindowDelegateMultiplexer for delegate conflicts`
2. `feat: Integrate delegate multiplexer with all windows`

### Phase 4: Double-Size Coordination (2-3 commits)

1. `feat: Migrate double-size scaling to individual window views`
2. `feat: Synchronize NSWindow frame resizing for double-size mode`
3. `fix: Maintain docked alignment during double-size toggle`

### Phase 5: Basic Persistence (1-2 commits)

1. `feat: Add window position persistence to AppSettings`
2. `feat: Implement window position save/restore`

### Milestone Tags

**Day 6**: `v0.8.0-three-windows-draggable`
- 3 independent NSWindows with custom drag regions

**Day 10**: `v0.8.0-magnetic-snapping`
- WindowSnapManager integrated, 15px magnetic snapping functional

**Day 14-15**: `v0.8.0-foundation-complete`
- 3-window magnetic docking complete
- Infrastructure ready for Video/Milkdrop

### Merge Strategy (After Foundation Complete)

```bash
# Final commit
git commit -m "docs: Foundation task completion summary"

# Merge to main
git checkout main
git merge feature/magnetic-docking-foundation --no-ff
git push origin main --tags

# Delete branch
git branch -d feature/magnetic-docking-foundation

# Archive task
mv tasks/magnetic-docking-foundation tasks/done/

# Create Task 2 branch
git checkout -b feature/video-milkdrop-windows
```

---

## Oracle Review History

### Review #1: B+ Grade
**Date**: 2025-11-08  
**Issues**: 3 clarification recommendations
1. Align window style masks
2. Document delegate superseding
3. AppSettings thread safety notes

### Review #2: B Grade
**Date**: 2025-11-08  
**Issues**: 2 blocking issues
1. Delegate multiplexer retention (loop locals deallocate)
2. AppSettings API (.shared vs .instance())

### Review #3: A Grade ✅
**Date**: 2025-11-08  
**Issues**: NONE  
**Status**: Production-ready, approved for implementation

**Oracle's Final Assessment**:
> "Grade: A. Remaining issues: none. Ready for implementation: YES."

---

**Last Updated**: 2025-11-08 (Oracle A-grade achieved)  
**Status**: ✅ READY TO BEGIN IMPLEMENTATION  
**Next**: Day 1, Phase 1A - Create WindowCoordinator.swift

---

## Cross-Reference: Dependent Tasks

### This Task Enables
**Task**: `tasks/milk-drop-video-support/`  
**Status**: Research complete, blocked on this foundation  
**Timeline**: 8-10 days (AFTER this task complete)  
**Branch**: Will be `feature/video-milkdrop-windows` (after Task 1 merges)

**What It Needs from Foundation**:
- NSWindowController pattern (to follow for Video/Milkdrop)
- WindowSnapManager integration (to register new windows)
- Proven multi-window architecture (working reference)

**When This Complete**: Task 2 can begin

### Task Sequence
**Position**: Task 1 of 2  
**Enables**: Task 2 (Video/Milkdrop windows)  
**Status**: Oracle A-grade approved, ready to implement  
**Next**: Resume milk-drop-video-support after completion

---

**Task Relationship**: Task 1 (THIS) → Task 2 (dependent)  
**Last Updated**: 2025-11-08 (Oracle A-grade achieved)
