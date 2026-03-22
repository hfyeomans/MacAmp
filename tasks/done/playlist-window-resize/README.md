# Playlist Window Resize Task

**Priority:** P4 (Deferred)
**Status:** Research Complete, Ready for User Deep-Dive
**Created:** 2025-10-23

---

## Quick Summary

During the `playlist-state-sync` task, we discovered that MacAmp's playlist window uses a **two-section workaround** (LEFT + RIGHT only) instead of the proper **three-section layout** (LEFT + CENTER + RIGHT) that classic Winamp uses. This prevents the playlist window from being resizable.

**Current State:** Fixed-size playlist window (~275px wide)
**Goal:** Resizable playlist window (275px-1000px wide) with expandable center section

---

## What's in This Folder

### 📄 research.md
Complete analysis of webamp_clone's playlist resize implementation, including:
- Three-section layout structure (left/center/right)
- Top, middle, and bottom section strategies
- CSS positioning techniques (absolute vs flexbox)
- Sprite sheet analysis
- Connection to playlist-state-sync task

### 📋 state.md
Current task status including:
- Problem statement
- Technical architecture comparison (MacAmp vs webamp_clone)
- Implementation requirements
- Success criteria
- Timeline estimates (10 hours total)
- File modification list

### 🔍 gemini-research-prompt.md
**Six comprehensive Gemini CLI prompts** for deep research:

1. **Prompt 1:** Analyze webamp_clone resize implementation
2. **Prompt 2:** Compare MacAmp vs webamp_clone layouts
3. **Prompt 3:** Deep dive into PLEDIT.BMP sprite structure
4. **Prompt 4:** SwiftUI window resizing best practices
5. **Prompt 5:** Verify current playlist-state-sync implementation
6. **Prompt 6:** End-to-end resize implementation plan

### 📖 README.md (this file)
Quick navigation and usage guide

---

## How to Use This Task

### For Immediate Research (You):

1. **Review the files:**
   ```bash
   cd /Users/hank/dev/src/MacAmp/tasks/playlist-window-resize
   cat research.md    # Understand the problem
   cat state.md       # See current status
   ```

2. **Run Gemini research prompts:**
   ```bash
   # Open gemini-research-prompt.md
   # Copy/paste each prompt into your terminal
   # Save outputs to this folder

   # Example:
   cd /Users/hank/dev/src/MacAmp
   gemini -p "@webamp_clone/packages/webamp/..." > tasks/playlist-window-resize/gemini-1-webamp-analysis.md
   ```

3. **Save your findings:**
   Create markdown files in this folder with Gemini's analysis:
   - `gemini-1-webamp-analysis.md`
   - `gemini-2-comparison.md`
   - `gemini-3-sprites.md`
   - `gemini-4-swiftui-resize.md`
   - `gemini-5-current-impl.md`
   - `gemini-6-implementation-plan.md`

### For Future Implementation (P4):

1. **Review all research files**
2. **Create plan.md** (based on Gemini findings)
3. **Create implementation branch:** `feature/playlist-window-resize`
4. **Implement phase-by-phase** (see state.md timeline)
5. **Test with multiple skins**
6. **Create PR**

---

## Key Insights

### The Problem
```
Current MacAmp (WRONG):
┌─────────┬──────────┐
│  LEFT   │  RIGHT   │  ← Only 2 sections
│ 125px   │  154px   │  ← Total: 279px (fixed)
└─────────┴──────────┘
```

```
Classic Winamp (CORRECT):
┌─────────┬─────────────────┬──────────┐
│  LEFT   │     CENTER      │  RIGHT   │  ← 3 sections
│ 125px   │   EXPANDABLE    │  150px   │  ← Total: 275px - 1000px
└─────────┴─────────────────┴──────────┘
         ↑
         This section tiles background sprite
         and grows/shrinks with window width
```

### Why It Matters
- Users expect Winamp playlist to be resizable (classic behavior)
- Current workaround disables PLAYLIST_BOTTOM_TILE sprite
- Cannot show more tracks horizontally at wider sizes
- Technical debt that should be fixed eventually

### Why It's P4 (Low Priority)
- Works fine at fixed size
- Nice-to-have, not critical
- Requires significant layout refactoring
- Other features more important for 1.0 release

---

## Connection to Other Tasks

### ✅ tasks/playlist-state-sync/ (Completed)
This task **revealed** the three-section issue when we tried to implement the playlist transport buttons and encountered sprite overlap problems. See:
- `tasks/playlist-state-sync/CODEX_RENDERING_SUGGESTION.md`
- `tasks/playlist-state-sync/KNOWN_LIMITATIONS.md`

The "fix" was to disable PLAYLIST_BOTTOM_TILE, but the **real solution** is this task (implementing proper three-section layout and resize support).

---

## Quick Reference

### Files to Eventually Modify
1. `MacAmpApp/Views/WinampPlaylistWindow.swift` - Bottom section layout
2. `MacAmpApp/Parsers/SkinSprites.swift` - Add PLAYLIST_BOTTOM_CENTER_TILE
3. Window configuration - Add resize support
4. (Optional) `MacAmpApp/Views/PlaylistResizeHandle.swift` - Custom resize handle

### Estimated Time
**Total:** 10 hours
- Sprites: 1 hour
- Layout: 2 hours
- Resize: 2 hours
- State: 1 hour
- Testing: 2 hours
- Polish: 2 hours

---

## Questions?

Review the research files, run the Gemini prompts, and investigate further. This task is well-documented and ready for implementation when prioritized.

---

**Last Updated:** 2025-10-23
**Next Action:** User runs Gemini research prompts
**Implementation:** Deferred to P4 milestone
