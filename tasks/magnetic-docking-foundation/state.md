# Magnetic Docking Foundation - Task State

**Task ID**: magnetic-docking-foundation  
**Created**: 2025-11-08  
**Status**: Planning complete, ready for Oracle validation  
**Priority**: P0 (BLOCKER for Video/Milkdrop)

---

## Current Phase
**Phase 0: Final Planning & Oracle Validation**

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

### ✅ Planning Phase (95% Complete)
- [x] Created focused foundation plan.md
- [x] Defined clear scope (foundation only)
- [ ] Create todo.md (in progress)
- [ ] Oracle validation (pending)

### 🎯 Ready for Implementation
- [ ] Oracle approves foundation plan
- [ ] Create foundation todo.md
- [ ] Begin Phase 1A (NSWindowController setup)

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
