# Video & Milkdrop Windows - Task State

**Task ID**: milk-drop-video-support  
**Created**: 2025-11-08  
**Status**: 🚧 BLOCKED - Waiting for Foundation Task  
**Priority**: P1 (High - but blocked on P0)

---

## ⚠️ TASK STATUS: BLOCKED

### Blocking Dependency
**This task is BLOCKED by**: `magnetic-docking-foundation`

**Why**: Oracle identified that Video/Milkdrop windows require NSWindow infrastructure that doesn't exist yet.

**Resolution**: Complete `magnetic-docking-foundation` task FIRST, then resume this task.

---

## Task Sequencing

### TASK 1 (In Progress): magnetic-docking-foundation
**Timeline**: 10-14 days  
**Scope**: Break out Main/EQ/Playlist + basic magnetic snapping  
**Deliverable**: 3-window NSWindowController foundation

**Status**: Planning complete, ready for Oracle validation & implementation

### TASK 2 (This Task - BLOCKED): milk-drop-video-support
**Timeline**: 8-10 days (AFTER Task 1 complete)  
**Scope**: Add Video + Milkdrop windows using foundation  
**Deliverable**: Full 5-window architecture with video/visualization

**Status**: Research complete, waiting for foundation

---

## Why We're Blocked

### Oracle's Critical Feedback (B- Grade)

**Issue #1**: No actual NSWindow infrastructure
> "Plan says 'two independent windows' but still mounts views inside WinampMainWindow. NO actual NSWindow lifecycle exists."

**Issue #2**: Missing window management architecture
> "Need NSWindowController or WindowGroup infrastructure before adding auxiliary windows."

**Strategic Decision**: Build foundation FIRST (Task 1), then add Video/Milkdrop (Task 2)

---

## When This Task Resumes

### After Foundation Complete

**Foundation Provides**:
- ✅ NSWindowController architecture (established pattern)
- ✅ WindowCoordinator singleton (proven working)
- ✅ WindowSnapManager integration (3 windows snapping)
- ✅ Custom drag regions (borderless windows)
- ✅ Delegate multiplexer (extensible)
- ✅ Double-size coordination (working)

**Task 2 Becomes Easy**:
- Add VideoWindowController (follow pattern)
- Add MilkdropWindowController (follow pattern)
- Register with WindowSnapManager (1 line each!)
- VIDEO.bmp parsing (isolated work)
- Butterchurn integration (isolated work)

**Estimated Timeline**: 8-10 days (vs 10-12 without foundation)

---

## Research Status

### ✅ Research Complete (100%)
- [x] Webamp implementation (Butterchurn, no video)
- [x] MilkDrop3 analysis (Windows/DirectX only)
- [x] VIDEO.bmp discovery (separate window chrome)
- [x] Two-window architecture confirmed (Video + Milkdrop)
- [x] Multi-window patterns researched
- [x] Oracle consultations (3 sessions)

### ✅ Planning Status
- [x] 10-day two-window plan created
- [x] 150+ task checklist created
- ⚠️ **PLAN ON HOLD** (needs foundation first)
- ⏳ Will revise after foundation complete

---

## What We Learned

### Critical Discovery: Two Separate Windows Required

**Evidence**: VIDEO.bmp in Internet-Archive.wsz skin (233x119 pixels)

**Original Winamp Architecture**:
```
┌──────────────┐    ┌──────────────┐
│ Video Window │    │Milkdrop Window│
│ (VIDEO.bmp)  │    │ (separate)   │
└──────────────┘    └──────────────┘
  Independent          Independent
  Can coexist          Can coexist
```

**Implications**:
- Must implement TWO windows, not one
- VIDEO.bmp provides sprites for video window chrome
- Both windows must snap magnetically (requires foundation)

---

## Revised Approach (After Foundation)

### Task 2 Implementation (8-10 Days)

**Day 1-2**: Video Window Setup
- Create VideoWindowController (follows NSWindowController pattern)
- Add drag region (follows established pattern)
- Register with WindowSnapManager
- Basic window working

**Day 3-4**: VIDEO.bmp Parsing
- Extend SkinManager for VIDEO.bmp sprites
- Parse titlebar, borders, buttons, controls
- Fallback chrome if VIDEO.bmp missing

**Day 5-6**: Video Playback
- AVPlayerViewRepresentable
- AudioPlayer video support
- Playlist integration
- V button wiring

**Day 7-8**: Milkdrop Window Setup
- Create MilkdropWindowController
- Butterchurn HTML bundle
- WKWebView integration

**Day 9-10**: Milkdrop Visualization
- FFT audio analysis (Accelerate)
- JavaScript bridge
- Preset system
- Final testing

---

## Artifacts

### Created (Research Phase)
1. **research.md** (14 parts) - Comprehensive findings
2. **plan.md** (10 days) - Two-window implementation plan
3. **todo.md** (150+ tasks) - Detailed checklist
4. **state.md** (this file) - Task status
5. **ORACLE_FEEDBACK.md** - B- grade, critical issues

### Source Material
- webamp_clone/ exploration
- MilkDrop3/ analysis
- VIDEO.bmp discovery
- Multi-window architecture research

---

## Next Steps

### When Foundation Complete

1. Resume this task
2. Review foundation NSWindowController pattern
3. Update plan.md for foundation-based architecture
4. Begin Day 1: Video window setup
5. Complete 8-10 day implementation
6. Archive both tasks when done

---

## Task Organization

**Execution**: Sequential, NOT blended
- Task 1: `magnetic-docking-foundation` (complete it fully)
- Task 2: `milk-drop-video-support` (then resume)

**No Task Blending**: Each task is independent, self-contained work unit

---

**Task Status**: 🚧 BLOCKED (waiting for foundation)  
**Blocking Task**: magnetic-docking-foundation  
**Resume When**: Foundation complete (Est. 10-14 days)  
**Timeline for This Task**: 8-10 days (after unblock)  
**Last Updated**: 2025-11-08
