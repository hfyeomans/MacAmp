# Plan

1. **Confirm scaling inputs**
   - Keep existing `scale` logic derived from `settings.isDoubleSizeMode` and `WinampSizes` for main/equalizer base sizes.
   - Continue anchoring the main window title bar by adjusting `origin.y` by the delta between new and old heights.

2. **Reposition equalizer relative to main**
   - After main frame is updated, compute the equalizer's new size and set its origin so its top edge equals the main window's bottom edge (i.e., `eqFrame.origin.y = mainFrame.origin.y - eqFrame.size.height`).
   - This mirrors `VStack` stacking (no spacing) while preserving left alignment (x) unchanged.

3. **Maintain playlist docking behavior**
   - Keep existing docking detection but base the target position on the updated equalizer frame so that a docked playlist always sits directly beneath EQ, regardless of double-size state.
   - Leave undocked playlists untouched.

4. **Verification**
   - Exercise `resizeMainAndEQWindows` in both doubled/non-doubled scenarios (manual reasoning or logging through debugger) to confirm heights/positions cascade correctly.
   - Ensure no regressions for playlist behavior and no additional animations are introduced.
