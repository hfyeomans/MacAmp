## Context

- Files under review: `MacAmpApp/Views/WinampMainWindow.swift`, `MacAmpApp/Views/WinampEqualizerWindow.swift`, `MacAmpApp/ViewModels/WindowCoordinator.swift`, `MacAmpApp/Windows/WinampPlaylistWindowController.swift`, and `webamp_clone/packages/webamp/js/*`.
- Regression symptoms reported in Phase 4 revolve around double-size mode scaling (background drawing, dock spacing, playlist constraints).

## Findings

1. **Main/EQ SwiftUI modifier chain**
   - Current layout (`WinampMainWindow.swift:86-125` and `WinampEqualizerWindow.swift:40-88`) draws base content, clamps it to the 1x Winamp frame, applies `.scaleEffect`, then adds a second `.frame` to the doubled size, and finally a `.background(Color.black)`.
   - Because `.scaleEffect` runs after the first `.frame`, the layout system keeps reporting the 1x metrics to later modifiers. The explicit second `.frame` sets visual size, but there is no `.fixedSize()` to keep AppKit from recomputing intrinsic metrics, and the background never participates in the scaled layout pass.
   - Reference implementation (`/tmp/UnifiedDockView.swift:20-78`) instead applies `.scaleEffect` before constraining to the scaled rectangle, calls `.fixedSize()` on the stack container, then appends `.background(backgroundView)`. This ensures the background sees the final doubled size.

2. **Window resizing logic ignores origins**
   - `WindowCoordinator.resizeMainAndEQWindows` (`MacAmpApp/ViewModels/WindowCoordinator.swift:181-208`) only adjusts `frame.size` on each NSWindow; the origin stays untouched.
   - NSWindow coordinates are bottom-left anchored (`setDefaultPositions` comment at lines 266-271). When height doubles from 116 → 232, AppKit keeps the bottom edge fixed and pushes the title bar upward—opposite of the SwiftUI `.topLeading` anchor we present.
   - Because the top edge moves instead of the bottom, the playlist window (whose origin remains at 152) no longer lines up vertically with the Equalizer when double-size toggles. No docking compensation exists, so the playlist does not track the taller stack.

3. **Need to move downstream windows during double-size**
   - Docking is currently handled by `WindowSnapManager`, but `WindowCoordinator` already has deterministic stacking offsets: EQ sits 116 px under Main, Playlist sits 232 px under EQ (lines 266-271).
   - During double-size activation, we need to preserve those deltas by:
     - Recording each window’s top-left prior to resizing (derived from `frame.origin` + `frame.size.height`).
     - After resizing (550×232), shifting `mainWindow` origin downward by the delta height if `settings.isDoubleSizeMode` is true, so the title bar stays put visually.
     - Translating the EQ window origin to always be `(mainOrigin.y - eqHeight)`.
     - Translating Playlist window origin to stay `(eqOrigin.y - playlistHeight)` whenever it is currently docked (i.e., its top is within snap-distance of the EQ bottom). Without this, playlist detaches when double-size changes.

4. **Playlist min/max constraints**
   - Native controller enforces 275×232 ≤ size ≤ 275×900 (`MacAmpApp/Windows/WinampPlaylistWindowController.swift:9-24`), matching `WindowSpec.playlist` (`MacAmpApp/Models/WindowSpec.swift:28-46`).
   - In `webamp_clone`, the default layout seeds playlist with `size: { extraHeight: 4, extraWidth: 0 }` (`webamp_clone/packages/webamp/js/webampWithButterchurn.ts:9-18`). Using `WINDOW_HEIGHT = 116` and `WINDOW_RESIZE_SEGMENT_HEIGHT = 29` (`webamp_clone/packages/webamp/js/constants.ts:32-45`), the initial height is `116 + 4*29 = 232 px`.
   - `ResizeTarget` (`webamp_clone/packages/webamp/js/components/ResizeTarget.tsx:1-58`) quantizes height changes in 29 px steps and clamps the segment count to ≥0. Therefore, Webamp’s playlist cannot shrink below its base layout (232 px) without components overlapping, validating the current minimum.

5. **Background sizing requirement**
   - UnifiedDockView’s outer container (`/tmp/UnifiedDockView.swift:49-67`) sets `.fixedSize()` on the stacked windows before `.background(backgroundView)`. This ensures the hosting NSView’s backing layer matches the computed frame and avoids the “black background” clipping that users reported once double-size is enabled.
   - Matching this ordering on `WinampMainWindow`/`WinampEqualizerWindow` will make the black background grow with scale instead of staying at 275×116.

## Open Questions

- Need to confirm exact detection criteria for “playlist is docked” (e.g., within 2 px of EQ bottom or share same `x`). Likely should reuse `WindowSnapManager`’s snap distance (15 px) so manual undocking is respected.
- Should we animate origin shifts during the double-size transition to match SwiftUI `.easeInOut(0.2)`?
