# Phase 3 Branching Strategy

**Date:** 2025-10-12, 7:50 PM EDT
**Context:** 644K tokens remaining (~64%)

---

## 🌳 Branch Structure

```
main
  └─ feature/sprite-resolver-architecture (Phase 1 & 2 COMPLETE ✅)
       ├─ phase3-base-mechanism-layer (Option A - YOU ARE HERE)
       └─ [future] phase3-semantic-migration (Option B - if needed)
```

---

## ✅ Safe Experimentation Setup

### Current Branch: phase3-base-mechanism-layer

**Purpose:** Implement base mechanism layer (Option A)
**Based on:** feature/sprite-resolver-architecture @ d9262df
**Can switch to:** Option B without losing Phase 1 & 2 work

### Easy Rollback Options

**Option 1: Switch to Option B**
```bash
git checkout feature/sprite-resolver-architecture
git checkout -b phase3-semantic-migration
# Start fresh with Option B approach
```

**Option 2: Merge both approaches**
```bash
# After completing Option A:
git checkout feature/sprite-resolver-architecture
git merge phase3-base-mechanism-layer

# Then do Option B:
git checkout -b phase3-semantic-migration
```

**Option 3: Abandon and restart**
```bash
git checkout feature/sprite-resolver-architecture
git branch -D phase3-base-mechanism-layer
# Phase 1 & 2 work is safe!
```

---

## 📋 Phase 3 Option A Plan

### Goal: Separate Mechanism from Presentation

**Per WinampandWebampFunctionalityResearch.md:**
> "State Management and Playback Control primitives should form the foundational core.
> Skin rendering should be a separate dependent module that consumes state via
> accessor functions."

### Implementation Steps

**1. Create BaseSliderControl**
- Pure GeometryReader with DragGesture
- No sprite dependencies
- Returns value (0.0-1.0)
- Works without ANY skin loaded

**2. Render Center Channel Indicators**
- Always visible (functional, not decorative)
- Your discovery: These don't change across skins
- Examples: Volume center line, Balance center marker, EQ/Preamp zero line

**3. Make Skin Backgrounds OPTIONAL**
- Current: VolumeSliderView(background:, thumb:, value:) REQUIRES sprites
- Target: VolumeSliderView(value:) works alone, skin overlay is optional

**4. Test Skinless Mode**
- Launch app
- Don't load any skin
- Sliders should work (plain rectangles/lines)
- Can still control volume, balance, etc.

---

## 🎯 Success Criteria

### Must Work:
- ✅ Sliders functional without any skin
- ✅ Center channels always visible
- ✅ Skin backgrounds enhance but aren't required
- ✅ All existing skins still work

### Nice to Have:
- Plain visual feedback (colored rectangles)
- Smooth drag interaction
- Accessibility improvements

---

## 🔄 Switching to Option B

If at any point we decide Option A isn't the right approach:

```bash
# Save current work
git add .
git commit -m "wip: Phase 3 Option A exploration"

# Switch back to stable base
git checkout feature/sprite-resolver-architecture

# Start Option B
git checkout -b phase3-semantic-migration

# Now do semantic sprite migration instead
```

Phase 1 & 2 work (commit 05c3eba + d9262df) is **safe and immutable**!

---

## 📊 Current State

**Branch:** phase3-base-mechanism-layer (NEW)
**Based on:** All Phase 1 & 2 work
**Status:** Clean working directory
**Next:** Implement BaseSliderControl

**Ready to begin Phase 3 Option A!** 🚀
