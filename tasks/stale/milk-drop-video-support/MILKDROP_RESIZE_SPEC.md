# Milkdrop Window Resize Specification

**Date**: 2025-11-11
**Status**: DEFERRED to later implementation (after Day 7 foundation complete)

## Resize Behavior

**Type**: Smooth/continuous resize (NOT quantized segments like Playlist)
**Min Size**: 275×116 (matches Main/EQ, minimum GEN sprite layout)
**Max Size**: 464×464 (large square for visualization)
**Default**: 275×116 (start at minimum)

## Sprite Scaling Rules

### What SCALES with Window Size:

1. **Titlebar horizontal fills** (gold bars on sides):
   - `GEN_TOP_LEFT_RIGHT_FILL` tiles multiply as width increases
   - Left side: Add more tiles from X=50 onwards
   - Right side: Add more tiles before RIGHT_END

2. **Side borders** (vertical):
   - `GEN_MIDDLE_LEFT` and `GEN_MIDDLE_RIGHT` tiles multiply as height increases
   - Tile vertically to fill content area height

3. **Bottom bar horizontal fills**:
   - `GEN_BOTTOM_FILL` tiles multiply as width increases
   - Fill between GEN_BOTTOM_LEFT and GEN_BOTTOM_RIGHT

### What STAYS CONSTANT:

1. **GEN_TOP_CENTER_FILL** (grey under "MILKDROP"):
   - Always exactly **2 tiles** (50px)
   - Covers "MILKDROP" text which never changes
   - Does NOT scale with window width

2. **Corner and end pieces**:
   - GEN_TOP_LEFT, GEN_TOP_RIGHT (corners) - always 1 each
   - GEN_TOP_LEFT_END, GEN_TOP_RIGHT_END (transitions) - always 1 each
   - GEN_BOTTOM_LEFT, GEN_BOTTOM_RIGHT - always 1 each

3. **Letters**:
   - "MILKDROP" text always same size (49px wide, 8px tall)
   - Always centered in titlebar

## Tile Count Formula (for later implementation)

At **275×116** (1×, minimum):
- Titlebar: LEFT(25) + LEFT_END(25) + LEFT_RIGHT_FILL(×1=25) + CENTER(×2=50) + LEFT_RIGHT_FILL(×1=25) + RIGHT_END(25) + RIGHT(25) = 200px (need adjustment)
- Side borders: ~3 tiles each (height 82px ÷ 29px)
- Bottom: LEFT(125) + no fills + RIGHT(125) = 250px (25px gap in center)

At **464×464** (max):
- Titlebar: More LEFT_RIGHT_FILL tiles (~6 left + 2 CENTER + ~6 right)
- Side borders: ~14 tiles each (height 430px ÷ 29px)
- Bottom: LEFT(125) + fills(×7-8) + RIGHT(125)

**Dynamic calculation needed**: Compute tile counts based on current window.frame size

## Implementation Notes

- This will be MacAmp's FIRST resizable window
- Playlist resize was deferred - Milkdrop will pioneer the pattern
- GEN sprites designed for 275px width (optimal at minimum size)
- Larger sizes will show repeated tiles (intentional, matches Winamp behavior)

---

**Next Steps** (when implementing resize):
1. Add `.resizable` to window styleMask
2. Observe window.frame changes
3. Calculate tile counts dynamically based on width/height
4. Redraw chrome with new tile counts
5. Test smooth resizing with no visual glitches
