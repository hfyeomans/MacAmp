## Goal
Answer the Phase 4 regression questions by extracting the required patterns from the codebase and proposing concrete fixes for:

1. SwiftUI modifier ordering / background sizing in Main & EQ windows
2. Docking adjustments when double-size mode toggles
3. Updated `resizeMainAndEQWindows` logic that repositions windows in lockstep
4. Playlist minimum-size expectations sourced from `webamp_clone`

## Plan

1. **Document correct SwiftUI sizing chain**
   - Compare `WinampMainWindow` / `WinampEqualizerWindow` body modifiers with the proven `UnifiedDockView` stack.
   - Identify the exact order (content → base frame → `scaleEffect` → scaled frame → `.fixedSize()` → `.background`) that preserves background coverage.

2. **Derive docking math for double-size transitions**
   - Use `WindowCoordinator.setDefaultPositions` to capture canonical offsets (Main ↔ EQ: 116 px, EQ ↔ Playlist: playlist height).
   - Decide how to detect “currently docked” playlist (e.g., y-distance within snap threshold and aligned x). Reuse `WindowSpec.snapDistance` or `WindowSnapManager.shared.snapDistance`.

3. **Author revised `resizeMainAndEQWindows` sketch**
   - Compute deltaHeight when toggling (116 px).
   - Resize Main/EQ NSWindows, adjust origins so their top edges stay anchored.
   - When playlist is docked, translate it by the same delta to keep attachment.
   - Surface pseudo-code / Swift snippet for inclusion in coordinator.

4. **Validate playlist constraints**
   - Cross-reference `WinampPlaylistWindowController` and `WindowSpec`.
   - Cite `webamp_clone` sources showing `extraHeight: 4`, `WINDOW_RESIZE_SEGMENT_HEIGHT = 29`, and quantized resize logic to justify 232 px minimum (and 29 px increments to a max height).

5. **Assemble response**
   - Answer each numbered question with references to the supporting files/lines.
   - Provide explicit modifier chains and sample coordinator code per plan above.
