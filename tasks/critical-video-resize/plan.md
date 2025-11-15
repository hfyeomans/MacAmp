# Plan: Critical Video Window Resize Bugs

## Goal
Ensure the VIDEO window titlebar keeps the "WINAMP VIDEO" center sprite perfectly centered across widths and make resize drag gestures smooth, predictable, and compatible with snap/quantization behaviors.

## Steps
1. **Survey Existing Patterns**
   - Inspect other windows (main/playlist/equalizer) for centered titlebar implementations and drag handles to reuse formulas.
   - Locate any helpers (e.g., `WindowSnapManager`, `WindowCoordinator`, `WindowResizer`) to guide drag gesture structure.

2. **Rework Titlebar Layout**
   - Compute `pixelSize.width` and derive `usableWidth = pixelSize.width - 50` (exclude caps) then subtract 100 for center text to get total stretchy width.
   - Split stretchy count evenly for left/right of center; if odd, let left side floor and right side ceil (or vice versa) to keep text at `pixelSize.width / 2`.
   - Position sprites using absolute pixel offsets so left caps and left tiles anchor from x=0 while center text is placed at `pixelSize.width / 2`.
   - Ensure right-side tiles fill the space up to the right cap; confirm `sizeState.stretchyTitleTileCount` can represent total tiles after removing center area.

3. **Refactor Resize Gesture State**
   - Move `@State private var dragStartSize: Size2D?` (or similar) to `VideoWindowChromeView` struct scope since multiple builder calls share gesture.
   - Initialize start size during `.onChanged` when gesture begins using `value.startLocation` or `.onChanged` first invocation; optionally use `.onChanged` with guard to set start size when nil, resetting on `.onEnded`.
   - Consider using `.updating` to store translation and convert to segments without reinitializing state each render.

4. **Quantization Strategy**
   - Instead of rounding each `onChanged`, track raw pixel translation in gesture `value.translation` per update, convert to segments via floor or round without clamping to ints too early.
   - Option A: apply quantized updates continuously but base them on captured start size rather than mutated `sizeState` so UI doesn't fight.
   - Option B: update `sizeState` with raw computed `Size2D.fromVideoPixels` but only persist/quantize on `.onEnded` for smoothness; need to test whichever matches other windows.

5. **Snap/Coordinator Integration**
   - Search for `beginProgrammaticAdjustment` or similar functions; follow same pattern to temporarily suspend window snapping/resizing constraints while drag updates are in-flight.
   - Wrap `sizeState.size = ...` updates with this guard if necessary.

6. **Verification**
   - Build/test by running the app and manually resizing to confirm title text remains centered and drag is smooth.
   - Check `VideoWindowSizeState` persistence still works.
   - Ensure no warnings (unused states, etc.) and obey single quotes/explicit types for any JS/TS touches (not applicable here).
