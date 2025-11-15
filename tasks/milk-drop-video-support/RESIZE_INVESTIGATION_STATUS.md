# VIDEO Window Resize Investigation - Current Status

**Date:** 2025-11-14
**Status:** Partial Implementation - Jitter Investigation Ongoing

---

## What's Implemented ✅

### Core Functionality
- ✅ Size2D segment-based model (25×29px quantization)
- ✅ VideoWindowSizeState observable with persistence
- ✅ Dynamic chrome sizing (titlebar, borders, bottom bar)
- ✅ 20×20px resize handle in bottom-right corner
- ✅ 1x/2x buttons as Size2D presets
- ✅ Titlebar "WINAMP VIDEO" perfectly centered
- ✅ Three-section bottom bar with center tiling
- ✅ NSWindow frame sync (removed from onChange)

### What Works Perfectly
- ✅ **1x button click** → Instant, smooth resize to 275×232 (no jitter)
- ✅ **2x button click** → Instant, smooth resize to 550×464 (no jitter)
- ✅ **Titlebar centering** → WINAMP VIDEO stays centered at all sizes
- ✅ **Chrome tiling** → Components render at correct positions

---

## Critical Issues Remaining ❌

### Issue 1: Severe Jitter During Drag Resize
**Symptom:** Incredible jitter when dragging resize handle

**User Insight:** "The snap to 25×29 segments is forcing the jittering as it tries to snap up from a previous segment and size."

**Root Cause Analysis:**
Every segment boundary crossing triggers:
1. `sizeState.size` update
2. Full `VideoWindowChromeView.body` re-evaluation
3. All @ViewBuilder functions re-execute
4. All computed properties recalculate
5. All ForEach loops re-render
6. All SimpleSpriteImage sprites re-lookup
7. Complex ZStack layout recalculation

**Result:** Expensive layout recalculation on every 25px or 29px boundary = jitter

**Why Buttons Work:** Single jump → chrome rebuilds once → smooth
**Why Drag is Jittery:** Many boundary crosses → many rebuilds → jitter

### Issue 2: Blank Gap on Left Edge
**Symptom:** Persistent blank/gap visible on left edge at multiple sizes

**Screenshot Evidence:**
- Visible at [0,4] = 275×232 (default size)
- Visible at [0,0] = 275×116 (minimum size)
- Visible at various other sizes

**Theories:**
1. NSWindow.frame.origin at fractional coordinates (e.g., x=100.5)
2. NSHostingView adding implicit padding
3. ZStack alignment issue
4. Sprite positioning calculation off by 1px

---

## Fixes Attempted

### Attempt 1: Oracle Titlebar Centering ✅ WORKED
- Split stretchy tiles symmetrically
- Center text at pixelSize.width / 2
- **Result:** Titlebar perfectly centered

### Attempt 2: Remove onChange NSWindow Sync ⚠️ PARTIALLY WORKED
- Removed `.onChange(of: sizeState.size)` calling `syncVideoWindowFrame()`
- Sync only on drag end and button clicks
- **Result:** Buttons smooth, drag still jittery

### Attempt 3: Content Positioning for Left Gap ❌ DID NOT FIX
- Changed content position to `contentCenterX = leftBorderWidth + width/2`
- **Result:** Gap still visible

### Attempt 4: WindowSnapManager Suppression ⚠️ UNCLEAR
- Added begin/endProgrammaticAdjustment() during drag
- **Result:** May have helped slightly, still jittery

### Attempt 5: withAnimation(.none) ⏳ TESTING NOW
- Wrapped all `sizeState.size` mutations in `withAnimation(.none)`
- **Theory:** SwiftUI animation system fighting with quantization
- **Result:** Awaiting user testing

---

## Research Completed

### Webamp Pattern (From ResizeTarget.tsx)
```typescript
// Key pattern: Frozen starting size, calculate from total delta
const handleMove = (ee: MouseEvent) => {
  const x = Utils.getX(ee) - mouseStart.x;  // Total delta from start
  const y = Utils.getY(ee) - mouseStart.y;
  
  const newWidth = Math.max(0, width + Math.round(x / SEGMENT_WIDTH));
  const newHeight = Math.max(0, height + Math.round(y / SEGMENT_HEIGHT));
  
  props.setWindowSize([newWidth, newHeight]);  // React batches updates
};
```

**Why Webamp is Smooth:**
- CSS updates are cheap (`div.style.width = "300px"`)
- React batches state updates automatically
- Browser handles layout efficiently
- No complex sprite recalculation on every update

**Why MacAmp is Jittery:**
- SwiftUI body re-evaluation is expensive
- Complex chrome with many components
- Every segment cross = full rebuild
- No automatic batching like React

---

## Next Steps

### Option A: Test Animation Disable (Current Attempt)
**Commit:** `a3f369c` - withAnimation(.none) on all size updates

**If Works:** Jitter caused by SwiftUI animation interpolation
**If Still Jittery:** Need different approach

### Option B: Throttle Size Updates to 60fps
```swift
@State private var updateTask: Task<Void, Never>?

// In onChanged:
updateTask?.cancel()
updateTask = Task {
    try? await Task.sleep(nanoseconds: 16_666_667)  // ~60fps
    withAnimation(.none) {
        sizeState.size = candidate
    }
}
```

### Option C: Preview Pattern (Don't Update Size During Drag)
```swift
@State private var dragPreviewSize: Size2D?

// During drag: Show preview overlay only
// On drag end: Commit to sizeState.size
// Chrome only rebuilds once at end
```

### Option D: Canvas Optimization
- Render chrome to Canvas/NSImage
- During drag: Only update frame (cheap)
- After drag: Rebuild sprite components

### Option E: Oracle Consultation
Use saved prompt at: `tasks/milk-drop-video-support/ORACLE_PROMPT_RESIZE_JITTER.md`

---

## Oracle Prompt Available

**Location:** `tasks/milk-drop-video-support/ORACLE_PROMPT_RESIZE_JITTER.md`

**Usage:** Copy entire file content and paste to Oracle (Codex) in separate session

**Contains:**
- Complete problem description
- Current implementation details
- Screenshot evidence context
- Specific questions for Oracle
- All relevant file references
- Success criteria

---

## Metrics

**Implementation Time:** ~4 hours total
**Commits:** 12 commits
**Status:** 80% complete (works for buttons, broken for drag)
**Blocking:** Jitter makes drag resize unusable
**Priority:** Critical - needs Oracle consultation or alternative approach

---

**Next Action:** User tests `withAnimation(.none)` fix, then uses Oracle prompt if still jittery
