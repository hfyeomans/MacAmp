# Black Mask Rendering Analysis - Task Summary

**Created:** 2025-10-12
**Status:** Analysis Complete, Solution Ready
**Estimated Fix Time:** 15-30 minutes

---

## Problem Statement

Black masks intended to hide static UI elements baked into `MAIN_WINDOW_BACKGROUND` are not working. User reports seeing:
- Static "00:00" in time display
- Static volume slider thumb
- Static balance slider center marker
- Static EQ slider thumbs
- Static preamp slider thumb

---

## Root Cause

**The masks are rendering at the wrong z-index level in SwiftUI's view hierarchy.**

Current architecture has masks INSIDE `buildTimeDisplay()` at z-level 2 (same as dynamic digits), when they need to be at z-level 1 (between background at z:0 and UI at z:2+).

SwiftUI's ZStack renders views in order:
1. First declared = bottom layer (z:0)
2. Last declared = top layer (highest z-index)
3. `.offset()` transforms position but doesn't change z-order
4. `Group` containers don't create z-levels - children render at parent's level

**Result:** Masks don't properly cover background static elements.

---

## Solution

Move black mask rectangles from component builders (`buildTimeDisplay()`, etc.) into the root ZStack at an explicit z-level between the background and UI layers.

### Quick Fix (Immediate)

**File:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift`

**Step 1:** Add mask layer in `body` property (between background and title bar):

```swift
var body: some View {
    ZStack(alignment: .topLeading) {
        // Z:0 - Background
        SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", ...)

        // Z:1 - STATIC UI MASKS (ADD THIS)
        Group {
            Color.black.frame(width: 48, height: 13).at(Coords.timeDisplay)
            Color.black.frame(width: 68, height: 13).at(Coords.volumeSlider)
            Color.black.frame(width: 38, height: 13).at(Coords.balanceSlider)
        }

        // Z:2 - Title bar
        SimpleSpriteImage("MAIN_TITLE_BAR_SELECTED", ...)

        // Z:3 - Dynamic UI
        if !isShadeMode { buildFullWindow() }
    }
}
```

**Step 2:** Remove mask from `buildTimeDisplay()`:

```swift
@ViewBuilder
private func buildTimeDisplay() -> some View {
    ZStack(alignment: .leading) {
        // ❌ DELETE: Color.black.frame(width: 48, height: 13)

        // ✅ KEEP: All digit rendering code
        // ...
    }
}
```

---

## Files in This Task

- **`README.md`** (this file) - Task overview and quick reference
- **`REPORT.md`** - Comprehensive technical analysis and solution
- **`analysis.md`** - Detailed root cause investigation
- **`solution.md`** - Implementation guide with code examples
- **`quick-reference.md`** - TL;DR fix with minimal explanation
- **`visual-diagram.md`** - Visual explanation of z-ordering problem

---

## Testing

1. Build and run MacAmp
2. Load a track
3. Verify:
   - ✅ No static "00:00" in time display
   - ✅ No ghost volume thumb
   - ✅ No ghost balance center marker
   - ✅ Dynamic digits update correctly
   - ✅ Pause blink works without revealing static digits

If issues persist, see `solution.md` debugging section.

---

## Affected UI Elements

| Element | Position | Size | Status |
|---------|----------|------|--------|
| Time Display | (39, 26) | 48×13 | ✅ Fix ready |
| Volume Slider | (107, 57) | 68×13 | ✅ Fix ready |
| Balance Slider | (177, 57) | 38×13 | ✅ Fix ready |
| EQ Sliders | TBD | TBD | ⚠️ Coords unknown |
| Preamp Slider | TBD | TBD | ⚠️ Coords unknown |

---

## Next Steps

1. **Implement fix** - Follow `quick-reference.md` or `solution.md`
2. **Test** - Verify time/volume/balance work correctly
3. **Identify EQ coords** - Find static EQ slider positions in EQ_WINDOW_BACKGROUND
4. **Add EQ masks** - Extend mask Group with EQ/preamp rectangles
5. **Consider preprocessing** - Long-term solution in `REPORT.md`

---

## Key Insights

### Why This Happened

SwiftUI's `.offset()` is a **visual transform**, not a layout position. When you nest views with offsets inside Groups and ZStacks, the z-ordering can become unintuitive:

```swift
// Broken architecture
ZStack {
    Background  // z:0
    Group {     // z:1
        buildTimeDisplay() {
            ZStack {
                Color.black  // Still at z:1, not z:0.5
                Digits
            }.offset(...)
        }
    }
}
```

The Color.black inside the nested ZStack is at z:1 (same level as digits), not between z:0 (background) and z:1 (UI).

### Why the Fix Works

By moving masks to an explicit layer in the root ZStack:

```swift
ZStack {
    Background           // z:0
    Group { masks }      // z:1 ← EXPLICIT LAYER
    TitleBar            // z:2
    Group { UI }        // z:3
}
```

We guarantee proper z-ordering: background → masks → title → UI.

---

## Architecture Lessons

1. **Explicit z-ordering** - Don't rely on nested ZStacks for z-order control
2. **Flat hierarchies** - Keep critical z-levels in root ZStack
3. **Visual transforms** - `.offset()` doesn't change layout or z-order
4. **Group transparency** - Groups don't create z-levels, they're transparent containers

---

## Long-term Solution

Instead of runtime masks, preprocess background sprites during skin loading to remove static UI elements:

```swift
// SkinManager.swift
private func preprocessMainBackground(_ image: NSImage) -> NSImage {
    // Paint black rectangles over static UI regions
    // Return modified image
}
```

**Pros:**
- Cleaner UI code
- Guaranteed to work
- Better performance

**Cons:**
- Modifies assets at runtime
- Need to track all static regions

See `REPORT.md` for full implementation details.

---

## References

- **Winamp Coordinates:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/WinampMainWindow.swift` (Coords struct)
- **Sprite Rendering:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/SimpleSpriteImage.swift`
- **Skin Loading:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Models/SkinManager.swift`
- **Slider Components:** `/Users/hank/dev/src/MacAmp/MacAmpApp/Views/Components/WinampVolumeSlider.swift`

---

## Related Tasks

- `sprite-resolver-architecture` - Semantic sprite resolution system
- `sprite-fallback-system` - Sprite fallback and aliasing
- `skin-switching-plan` - Dynamic skin switching architecture

---

**Author:** Claude Code Analysis
**Last Updated:** 2025-10-12
**Complexity:** Low (view hierarchy restructuring)
**Risk:** Low (localized changes, easily testable)
