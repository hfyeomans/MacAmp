# MacAmp - Ready for Next Session

**Last Updated**: 2025-11-08  
**Current Branch**: main (about to create foundation branch)  
**Current Task**: magnetic-docking-foundation (Task 1 of 2)  
**Phase**: Implementation ready (Oracle approved B+)

---

## 🎯 Task Execution Order

### TASK 1: magnetic-docking-foundation (CURRENT)
**Timeline**: 10-15 days  
**Status**: Oracle approved (B+ grade), ready to begin  
**Branch**: Will create `feature/magnetic-docking-foundation`

**Goal**: Build NSWindowController infrastructure for Main/EQ/Playlist
- 3 independent NSWindows with magnetic snapping
- Custom drag regions (borderless windows)
- Foundation for Video/Milkdrop to follow

### TASK 2: milk-drop-video-support (BLOCKED - Resume After Task 1)
**Timeline**: 8-10 days (AFTER Task 1 complete)  
**Status**: Research complete, waiting for foundation  
**Branch**: Will create after Task 1 merges

**Goal**: Add Video + Milkdrop windows using foundation

---

## 📋 What Just Happened (Session Summary)

### Research Marathon (~13 hours total)

**Started With**: User request to research V button (video/milkdrop)

**Discovered**:
1. ✅ Webamp uses Butterchurn (not Milkdrop v2/v3)
2. ✅ VIDEO.bmp reveals TWO separate windows (Video + Milkdrop)
3. ✅ Oracle flagged B- grade: NO NSWindow infrastructure
4. ✅ Strategic decision: Build foundation FIRST

**Created 2 Tasks**:
1. `magnetic-docking-foundation` - NSWindow infrastructure
2. `milk-drop-video-support` - Video/Milkdrop windows

### Oracle Consultations (4 sessions, gpt-5-codex, high reasoning)

1. **Consultation #1**: Hybrid strategy for Video/Milkdrop (AVPlayerView + Butterchurn)
2. **Consultation #2**: Single-window vs independent window decision
3. **Consultation #3**: Two-window architecture confirmed (Video + Milkdrop separate)
4. **Consultation #4**: Magnetic docking foundation FIRST, then Video/Milkdrop
5. **Consultation #5**: Foundation plan validation (B+ grade, GO)

### Artifacts Created

**Task 1: magnetic-docking-foundation/**
- research.md (14 parts, synthesized from 3 sources)
- plan.md (5-phase foundation plan, Oracle B+)
- todo.md (100+ tasks for foundation)
- state.md (task tracking, sequencing)
- COMMIT_STRATEGY.md (15-20 atomic commits)

**Task 2: milk-drop-video-support/**
- research.md (14 parts, VIDEO.bmp discovery)
- plan.md (10-day two-window plan - ON HOLD)
- todo.md (150+ tasks - ON HOLD)
- state.md (BLOCKED status)

**Root Documentation**:
- READY_FOR_NEXT_SESSION.md (this file)
- Updated from previous session

---

## 🚀 Next Steps (When You Start Next Session)

### 1. Create Foundation Branch
```bash
git checkout -b feature/magnetic-docking-foundation
```

### 2. Begin Phase 1A (Day 1)
**First Task**: Create WindowCoordinator.swift

**Location**: `tasks/magnetic-docking-foundation/todo.md` (Lines 11-46)

**Deliverable**: WindowCoordinator singleton managing 3 NSWindowControllers

### 3. Follow Todo Checklist
**Path**: `tasks/magnetic-docking-foundation/todo.md`
- 100+ granular checkboxes
- Day-by-day breakdown
- Self-contained work units

### 4. Commit Atomically
**Pattern**: Small, logical commits at each checkpoint
- See `tasks/magnetic-docking-foundation/COMMIT_STRATEGY.md`
- ~15-20 commits across 10-15 days
- 3 milestone tags

### 5. After Foundation Complete
- Merge to main
- Delete foundation branch
- Archive task to `tasks/done/magnetic-docking-foundation/`
- Create `feature/video-milkdrop-windows` branch
- Resume Task 2

---

## 📚 Key Decisions Made

| Decision | Choice | Approved By | Date |
|----------|--------|-------------|------|
| **Task Sequencing** | Foundation first, then Video/Milkdrop | Oracle + User | 2025-11-08 |
| **Architecture** | NSWindowController (not WindowGroup) | Oracle | 2025-11-08 |
| **Foundation Scope** | Basic infra only (defer polish) | Oracle | 2025-11-08 |
| **Timeline** | 10-15 days foundation | Oracle | 2025-11-08 |
| **Branch Strategy** | One branch per task | User | 2025-11-08 |
| **Task Execution** | Sequential, NOT blended | User | 2025-11-08 |

---

## 📁 File Locations

### Foundation Task (Task 1)
**Directory**: `tasks/magnetic-docking-foundation/`
- research.md (comprehensive)
- plan.md (5-phase, Oracle B+)
- todo.md (100+ tasks)
- state.md (tracking)
- COMMIT_STRATEGY.md (atomic commits)

### Video/Milkdrop Task (Task 2 - ON HOLD)
**Directory**: `tasks/milk-drop-video-support/`
- research.md (VIDEO.bmp discovery)
- plan.md (two-window plan)
- todo.md (150+ tasks)
- state.md (BLOCKED status)

### Reference Materials
- `tasks/magnetic-window-docking/` (original research)
- `docs/MULTI_WINDOW_ARCHITECTURE.md` (patterns)
- `tmp/Internet-Archive/VIDEO.bmp` (sprite reference)

---

## ⚠️ Critical Context

### WindowSnapManager Already Exists!
**Location**: `MacAmpApp/Utilities/WindowSnapManager.swift`

**Already Implemented**:
- 15px snap threshold (SnapUtils.SNAP_DISTANCE)
- Cluster detection (connectedCluster method)
- Screen edge snapping
- Multi-monitor support
- Group movement

**What's Missing**: Registration! Just need to:
```swift
WindowSnapManager.shared.register(window: mainWindow, kind: .main)
// Repeat for EQ and Playlist
```

### VIDEO.bmp Discovery
**File**: `tmp/Internet-Archive/VIDEO.bmp` (233x119 pixels)

**Revealed**: Original Winamp has SEPARATE windows for Video and Milkdrop
- Video window uses VIDEO.bmp sprites
- Milkdrop window is separate
- Both can coexist simultaneously

### Oracle's B- Grade (Initial Video/Milkdrop Plan)
**Issues Found**:
1. No NSWindow infrastructure (views still in WinampMainWindow)
2. VIDEO.bmp parsing too rigid
3. AppSettings loading logic missing

**Resolution**: Create foundation task FIRST to fix infrastructure

### Oracle's B+ Grade (Foundation Plan)
**Issues**: None (showstopper-free!)  
**Recommendations**: 3 minor improvements (documented in plan.md)  
**Verdict**: ✅ GO FOR IMPLEMENTATION

---

## 🧠 Oracle Guidance (gpt-5-codex)

**Key Recommendations**:
1. NSWindowController architecture (not WindowGroup) - for singleton control
2. Drag regions IMMEDIATELY after window creation - critical for borderless windows
3. Delegate multiplexer - for extensibility
4. Foundation scope focused - defer polish features
5. Sequential task execution - no blending

**Timeline**: 12-15 days realistic (conservative)

---

## 📊 Timeline Overview

### Complete Journey

| Task | Timeline | Status |
|------|----------|--------|
| **Research** | ~13 hours | ✅ Complete |
| **Task 1: Foundation** | 10-15 days | ⏳ Ready to start |
| **Task 2: Video/Milkdrop** | 8-10 days | 🚧 Blocked (waiting) |
| **Total** | **~23-28 days** | **~45% research done** |

### What's Done
- ✅ Comprehensive research (webamp, MilkDrop3, VIDEO.bmp)
- ✅ Oracle consultations (5 sessions)
- ✅ Task 1 planning complete (foundation)
- ✅ Task 2 planning complete (Video/Milkdrop)
- ✅ Task sequencing decided
- ✅ Branch strategy defined

### What's Next
- ⏳ Create foundation branch
- ⏳ Begin Day 1: WindowCoordinator
- ⏳ Complete foundation (10-15 days)
- ⏳ Archive Task 1
- ⏳ Resume Task 2

---

## 🎯 Quick Start (Next Session)

### Commands to Run
```bash
# Create foundation branch
git checkout -b feature/magnetic-docking-foundation

# See first task
cat tasks/magnetic-docking-foundation/todo.md | head -50

# Begin Day 1
# Open: MacAmpApp/ViewModels/WindowCoordinator.swift (create file)
```

### First File to Create
**Path**: `MacAmpApp/ViewModels/WindowCoordinator.swift`  
**Pattern**: See `tasks/magnetic-docking-foundation/plan.md` lines 61-133  
**Checklist**: See `tasks/magnetic-docking-foundation/todo.md` lines 11-46

---

## 💡 Important Notes

### Task Isolation
- **DO NOT** blend Task 1 and Task 2
- Complete foundation FULLY before Video/Milkdrop
- Each task has own branch, own commits, own lifecycle

### Oracle Sessions (Remember!)
- **Model**: gpt-5-codex
- **Reasoning**: high
- **SessionID**: Use if multi-turn needed

### Commit Strategy
- Atomic commits at logical checkpoints
- ~15-20 commits for foundation
- See `tasks/magnetic-docking-foundation/COMMIT_STRATEGY.md`

### Thread Sanitizer
Remember to build with: `-enableThreadSanitizer YES`

---

**Status**: ✅ READY TO BEGIN TASK 1 (Foundation)  
**Confidence**: High (Oracle B+ approved)  
**Next Session**: Create branch, start Day 1  
**Estimated Completion**: 10-15 days for foundation
