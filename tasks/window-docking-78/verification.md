# Verification: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Results log for `plan.md`. Mark each row PASS, FAIL, FIXED or N/A, with the date and a short note.

## Phase 0: runtime experiments

**Live repro at probe start (2026-09-27):** one screen attached (LG, 3840×1600, `visibleFrame` 3840×1570). The **Playlist window is at (593, −21312), size 400×1566**, about 21,000 px below the screen and unreachable. Main and EQ are docked and on screen. This is a real instance of the off-screen problem, with nothing on launch or restore to catch it.

**Found during the experiments (owner, 2026-09-27):**
- **EQ shade is one-way.** The EQ can be shaded but **not unshaded**, by button or by the Windows-menu item. The menu toggles `DockingController.toggleShade(.equalizer)`, while the EQ reads its own local `@State isShadeMode`, so the two models disagree (research §1). → Phases 1 and 4.
- **Main shade sprites.** Main windowshade works, but the normal-mode button images stay drawn in shade mode. → Phase 4 (E/F).


| # | Experiment | How | Result |
|---|---|---|---|
| 1 | Borderless Main with `.miniaturizable`: does `miniaturize(_:)` animate to the Dock and restore cleanly? Does `performMiniaturize` beep? Does the chrome, shadow or key behaviour change? | Debug build with a temporary style-mask change; Claude checks over LLDB; owner watches | ✅ **PASS** (2026-09-27, owner): Main minimizes into the Dock with no beep and restores looking normal. |
| 2 | Cmd+M menu validation: is Window › Minimize enabled when the key window is a non-miniaturizable MacAmp window? Does a `performMiniaturize` override get called? | Temporary logging; owner presses Cmd+M on each window | **Confirmed problem** (2026-09-27): with the EQ key, Window › Minimize is **greyed out** and Cmd+M **beeps**. The probe logged `validate Minimize on Equalizer -> false` 4×, and the `performMiniaturize` override was **never called**. → Design D must override the validation (`validateUserInterfaceItem` returns true for `performMiniaturize`) so the action reaches `minimizeApp()` from every window. |
| 3 | Sleep/wake with an external display unplugged during sleep: order of `didWake`, `screensDidWake`, `didChangeScreenParameters` and `windowDidMove`, and the contents of `NSScreen.screens` at each | Temporary logging; owner sleeps the Mac, unplugs, wakes | |
| 4 | Does AppKit move borderless windows when their display disappears or the resolution changes? | Same session as 3, plus a forced resolution change | |
| 5 | Is `windowDidMove` from `setFrameOrigin` delivered synchronously, inside the `isAdjusting` bracket? | LLDB breakpoint | ✅ **Yes** (2026-09-27): the probe logged `windowDidMove Main adjusting=true` for cluster moves, so programmatic moves are reported inside the bracket and the `isAdjusting` guard works as the plan assumes. |
| 6 | Do the Video, Milkdrop and Playlist resize paths move the cluster by accident? Does Main's shade collapse leave a gap that breaks the chain? | Owner toggles shade and resizes with the EQ/Playlist docked; Claude logs clusters | **Shade gap confirmed** (2026-09-27): shading Main shrinks its frame 550×232 → **550×28, top edge fixed** (y 1181 → 1385), but the docked EQ **does not move**, leaving a **204 px gap** at double size, so the EQ is no longer docked. The EQ frame also shrinks when shaded (550×28). → Phase 2 re-anchoring on shade is required. The resize-path half is untested. |

## Phase 4: titlebar and windowshade checklist

Test with at least 3 skins (default plus 2 others). Each control must look like the skin, be clickable and do the right thing.

| Window | Mode | Control | Result |
|---|---|---|---|
| Main | normal | minimize (group), shade, close | |
| Main | shade | previous, play, pause, stop, next, eject | |
| Main | shade | position mini-slider (drag and seek) | |
| Main | shade | unshade, minimize, close | |
| EQ | normal | shade, close (no minimize, D5) | |
| EQ | shade | volume, balance sliders | |
| EQ | shade | unshade, close | |
| Playlist | normal | shade, close (no minimize, D5) | |
| Playlist | normal | bottom-right mini-transport (regression check) | |
| Playlist | shade | title and time display; unshade, close | |

## Phase 5: minimize and shortcuts

| Check | Result |
|---|---|
| Main's minimize button minimizes the group; restoring from the Dock brings back the same windows and layout | |
| Cmd+M from Main, EQ, Playlist, Video and Milkdrop minimizes the group | |
| Option+M does the same | |
| Ctrl+W toggles Main windowshade | |
| Restore after the display changed while minimized: the group comes back on screen | |

## Phases 1–3: behaviour

| Check | Result |
|---|---|
| EQ closed at quit stays closed at launch; the same for Playlist | |
| EQ and Playlist shade state survives relaunch | |
| #78: with the EQ closed, dragging Main brings the docked Playlist; reopening the EQ puts it back in place | |
| Dragging a docked EQ or Playlist detaches it; Shift-drag flips snapping | |
| Shade and unshade keep docked neighbours attached | |
| Sleep/wake (single display): nothing off-screen, groups intact | |
| Sleep/wake with the external display unplugged: windows on the main screen, groups intact | |
| Resolution change and Dock moved to the left: windows stay reachable | |
| Reset Window Positions restores the default stack | |
