# Verification: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Results log for `plan.md`. Mark each row PASS, FAIL, FIXED or N/A, with the date and a short note.

## Phase 0: runtime experiments

**Live repro at probe start (2026-09-27):** one screen attached (LG, 3840×1600, `visibleFrame` 3840×1570). The **Playlist window is at (593, −21312), size 400×1566**, about 21,000 px below the screen and unreachable. Main and EQ are docked and on screen. This is a real instance of the off-screen problem, with nothing on launch or restore to catch it.

**Found during the experiments (owner, 2026-09-27):**
- **Playlist height.** The Playlist frame is **1566 px tall**, taller than the screen's 1570 px usable height minus its offset. It grew from 900 → 1566 during launch restore. That suggests a separate Playlist size persistence or restore problem; the clamp must handle a window taller than the screen (pin its top edge). → Phase 3 (investigate the size source).
- **EQ shade is one-way.** The EQ can be shaded but **not unshaded**, by button or by the Windows-menu item. The menu toggles `DockingController.toggleShade(.equalizer)`, while the EQ reads its own local `@State isShadeMode`, so the two models disagree (research §1). → Phases 1 and 4.
- **Main shade sprites.** Main windowshade works, but the normal-mode button images stay drawn in shade mode. → Phase 4 (E/F).


| # | Experiment | How | Result |
|---|---|---|---|
| 1 | Borderless Main with `.miniaturizable`: does `miniaturize(_:)` animate to the Dock and restore cleanly? Does `performMiniaturize` beep? Does the chrome, shadow or key behaviour change? | Debug build with a temporary style-mask change; Claude checks over LLDB; owner watches | ✅ **PASS** (2026-09-27, owner): Main minimizes into the Dock with no beep and restores looking normal. |
| 2 | Cmd+M menu validation: is Window › Minimize enabled when the key window is a non-miniaturizable MacAmp window? Does a `performMiniaturize` override get called? | Temporary logging; owner presses Cmd+M on each window | **Confirmed problem** (2026-09-27): with the EQ key, Window › Minimize is **greyed out** and Cmd+M **beeps**. The probe logged `validate Minimize on Equalizer -> false` 4×, and the `performMiniaturize` override was **never called**. → Design D must override the validation (`validateUserInterfaceItem` returns true for `performMiniaturize`) so the action reaches `minimizeApp()` from every window. |
| 3 | Sleep/wake with an external display unplugged during sleep: order of `didWake`, `screensDidWake`, `didChangeScreenParameters` and `windowDidMove`, and the contents of `NSScreen.screens` at each | Temporary logging; owner sleeps the Mac, unplugs, wakes | **Plain sleep/wake done** (2026-09-27, LG only, lid closed, 54 s sleep). Timeline: <br>• t0 `willSleep`, +0.1 s `screensDidSleep` (3840×1600)<br>• +54.4 s **`didChangeScreenParameters` before wake**, reporting a **temporary 1920×1080 screen**<br>• +55.1 s `screensDidWake`, then `didWake`<br>• +56.4 s and +56.8 s `didChangeScreenParameters` with the real 3840×1600<br>The transition lasts **about 2.4 s** from the first screen change and **1.7 s after `didWake`**. The **unplug-during-sleep** variant is deferred to Phase 3 manual verification; the mechanism is the same. |
| 4 | Does AppKit move borderless windows when their display disappears or the resolution changes? | Same session as 3, plus a forced resolution change | **Yes, per window, and it splits groups** (2026-09-27).<br>• On the temporary 1080p screen, AppKit moved Main → (20,744), EQ → (0,997), which is no longer aligned, and the Playlist from (593,−21312) → (593,−486). That is why the owner saw the Playlist reappear.<br>• When the real screen returned they moved again. Our `windowDidMove` cluster logic reacted, and **Main jumped 1124 → 1223 → 1709 → 1338**.<br>• End state: Main (40,1338), EQ (20,1096), 20 px out of line with a **214 px gap**, so **the dock was lost**. The Playlist ended at (593,−341), partly on screen. **The owner confirmed by eye: the EQ separated from Main and the Playlist became visible.** |
| 5 | Is `windowDidMove` from `setFrameOrigin` delivered synchronously, inside the `isAdjusting` bracket? | LLDB breakpoint | ✅ **Yes** (2026-09-27): the probe logged `windowDidMove Main adjusting=true` for cluster moves, so programmatic moves are reported inside the bracket and the `isAdjusting` guard works as the plan assumes. |
| 6 | Do the Video, Milkdrop and Playlist resize paths move the cluster by accident? Does Main's shade collapse leave a gap that breaks the chain? | Owner toggles shade and resizes with the EQ/Playlist docked; Claude logs clusters | **Shade gap confirmed** (2026-09-27): shading Main shrinks its frame 550×232 → **550×28, top edge fixed** (y 1181 → 1385), but the docked EQ **does not move**, leaving a **204 px gap** at double size, so the EQ is no longer docked. The EQ frame also shrinks when shaded (550×28). → Phase 2 re-anchoring on shade is required. The resize-path half is deferred to Phase 2 verification. |

**Phase 0 conclusion (2026-09-27):** experiments 1, 2, 4 and 5 answered; 3 answered for plain sleep/wake; 6 answered for shade, with the resize paths deferred to Phase 2. Plan updated (Design C: sleep snapshot, transition suppression, settle window; Design D: menu validation override).

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
