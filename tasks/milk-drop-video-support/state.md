# Video & Milkdrop Windows - Task State

**Task ID**: milk-drop-video-support
**Created**: 2025-11-08
**Updated**: 2025-11-09
**Status**: ✅ READY TO BEGIN - Foundation Complete!
**Priority**: P1 (High)

---

## ✅ TASK STATUS: UNBLOCKED & READY

### Foundation Complete!
**Prerequisite**: `magnetic-docking-foundation` ✅ **COMPLETE**

**Date Unblocked**: 2025-11-09
**Foundation Merged**: PR #31 merged to main
**Current Branch**: `feature/video-milkdrop-windows`

**What Foundation Provides**:
- ✅ NSWindowController pattern (proven with 3 windows)
- ✅ WindowCoordinator singleton (window lifecycle management)
- ✅ WindowSnapManager integration (magnetic snapping working)
- ✅ Custom drag regions (borderless windows draggable)
- ✅ Delegate multiplexer (extensible delegate pattern)
- ✅ Double-size coordination (with docking preservation)
- ✅ Persistence system (WindowFrameStore)
- ✅ Oracle Grade A (production-ready architecture)

---

## Task Sequencing

### TASK 1: magnetic-docking-foundation ✅ **COMPLETE**
**Timeline**: 14 days actual
**Scope**: 3-window architecture + magnetic snapping + persistence
**Deliverable**: NSWindowController foundation (Oracle Grade A)

**Status**: ✅ Complete, merged to main (PR #31)
**Completion Date**: 2025-11-09

### TASK 2: milk-drop-video-support (THIS TASK) ⏳ **PLANNING**
**Timeline**: 8-10 days (corrected from initial 8-12)
**Scope**: Add Video + Milkdrop windows (5-window architecture, NO resize)
**Deliverable**: Video playback + audio visualization

**Status**: ⏳ Plan corrected, awaiting Oracle validation
**Current Branch**: `feature/video-milkdrop-windows`

---

## 🎯 TASK 2 READY TO BEGIN (2025-11-09)

### Sprite Sources Confirmed (Oracle + Gemini)

**Video Window**:
- **Sprite File**: VIDEO.BMP ✅ (exists in `tmp/Winamp/`)
- **Sprites**: 16 total (titlebar, borders, buttons, controls)
- **Parsing**: Need NEW parser for VIDEO.BMP
- **Size**: 275×116 minimum (matches Main/EQ)

**Milkdrop Window**:
- **Sprite File**: GEN.BMP ✅ (already parsed!)
- **Sprites**: Generic window chrome (reuses existing)
- **Parsing**: No new work needed (use existing GEN sprites)
- **Background**: AVSMAIN.BMP (optional, not required for chrome)

**CRITICAL**: Milkdrop is MUCH simpler - reuses existing sprite system!

### Window Resize Requirements

**Both Windows Are Resizable** (like Playlist):
- Resize pattern: WIDTH + HEIGHT (25×29 pixel segments)
- 3-section bottom: LEFT (125px) + CENTER (expandable) + RIGHT (150px)
- Complete spec: `tasks/playlist-resize-analysis/`

**Options**:
- Implement resize in TASK 2 (all 3 windows: Playlist/Video/Milkdrop)
- Defer to TASK 3 (dedicated resize task)

### V Button Assignment

**Research Findings**:
- Original plan: V button → Video window
- Webamp: Only has Milkdrop (no Video implemented)
- Winamp Classic: Has BOTH windows

**For MacAmp**:
- V button should open **Video window** (follows original Winamp)
- Milkdrop: Separate trigger (menu or Ctrl+Shift+M)

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

---

## Cross-Reference: Related Tasks

### Prerequisite Task (BLOCKING THIS)
**Task**: `tasks/magnetic-docking-foundation/`  
**Status**: Oracle A-grade approved, ready to begin  
**Timeline**: Quality-focused (10-15 days)  
**Branch**: `feature/magnetic-docking-foundation`

**What It Provides**:
- NSWindowController architecture (established pattern)
- WindowCoordinator singleton (window lifecycle)
- WindowSnapManager integration (magnetic snapping)
- Custom drag regions (borderless windows)
- Delegate multiplexer (extensibility)

**When Complete**: This task (milk-drop-video-support) can resume

### This Task Sequence
**Position**: Task 2 of 2  
**Depends On**: Task 1 (foundation)  
**Status**: Research complete, blocked on prerequisite  
**Resume When**: Foundation merged to main

---

**Task Relationship**: Task 1 → Task 2 (sequential, not parallel)  
**Last Updated**: 2025-11-08
