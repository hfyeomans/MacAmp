# Magnetic Window Docking - State

**Date:** 2025-10-23
**Status:** 📋 DEFERRED - Research complete
**Priority:** P3 (Post-1.0 enhancement)
**Estimated:** 10-16 hours

---

## ✅ Research Complete

### Analyzed:
- ✅ Webamp implementation (via Gemini)
- ✅ Video demonstration (10 frames extracted)
- ✅ Current MacAmp architecture (UnifiedDockView)
- ✅ macOS APIs and patterns

### Key Findings:
- **Webamp:** Positioned divs with transform, Redux state, 15px snap threshold
- **Algorithm:** snap() function checks 8 edge combinations with overlap detection
- **Group Movement:** traceConnection() BFS finds all connected windows
- **State:** Dynamically computed from positions, not persisted

---

## 📋 Decision: Defer to P3

**Reasons:**
1. **Major Refactor** - Complete architectural change (10-16 hours)
2. **High Complexity** - NSWindow coordination, custom drag handling
3. **Current Works** - Unified window functional and stable
4. **Not Critical** - Can ship v1.0 without separate windows
5. **Risk** - Could introduce bugs in working system

**When to Implement:**
- After v1.0 release
- When core features stable
- With dedicated QA time for edge cases

---

## 📂 Deliverables

### Documentation Created:
- `RESEARCH_PROMPT.md` - Reusable comprehensive prompt for AI research
- `WEBAMP_ANALYSIS.md` - Complete Gemini findings on webamp implementation
- `research.md` - Current architecture analysis
- `plan.md` - Phase-by-phase implementation roadmap
- `state.md` - This file

### Video Analysis:
- `frame-001.png` through `frame-010.png` - Extracted key frames
- Shows 3 windows vertically stacked, perfectly aligned
- Demonstrates docking behavior

---

## 🔮 Future Implementation

**Task ID:** `magnetic-window-docking`
**Branch:** Create new branch when ready
**Prerequisites:**
- macOS window management expertise
- NSWindowController experience
- Complex state management comfort

**Key Files to Implement:**
- `WindowSnapManager.swift` - Snap detection algorithm
- `MagneticWindowController.swift` - Custom drag handling
- Updated `DockingController.swift` - Multi-window state
- Window lifecycle management

---

**Current Decision:** ✅ DEFER
**Rationale:** Maximize value, minimize risk for v1.0
**Future Priority:** P3 (v1.1 or v2.0 feature)
