# Task State: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Purpose:** Fix issue #78 (join/clamp, minimize, window-state persistence) and the owner's sleep/wake off-screen windows problem.
> **Created:** 2026-09-26 — pulled ahead of the Structure Sprint (D-WIN78, user).
> **Branch:** `fix/window-docking-78` (from `main` `0d6e258`).
> **Status:** ✅ **COMPLETE** (2026-09-28) — Phases 0–7 done (`verification.md`); **PR [#90](https://github.com/hfyeomans/MacAmp/pull/90)** open against `main`, closes #78, awaiting owner merge. Folder moved to `tasks/done/`.
> **Files:** `research.md`, `plan.md`, `todo.md`, `verification.md`, `placeholder.md`, `depreciated.md`.

## Root causes (summary — details in research.md §1)

1. **Join:** docking is recomputed from proximity among *visible* windows only; closing the EQ breaks the Main→Playlist chain; child drags detach by design (as in Winamp/Webamp).
2. **Minimize:** no `.miniaturizable` on any borderless window; minimize targets only the key window.
3. **Persistence:** frames persist; EQ/Playlist visibility and EQ/Playlist shade don't; `showAllWindows` forces EQ/Playlist open; two visibility models disagree.
4. **Sleep/wake:** no screen-change/wake handling, no clamp, off-screen frames persisted as-is, no recovery command.

5. **Titlebars and windowshade:** the EQ and Playlist draw the Main window's titlebar sprites and add minimize buttons that aren't in Winamp; the shade strips draw sprites where Winamp has invisible hit areas, and some shade controls may not work (owner).

## What changed (by root cause)

1. **Join:** `DockGraph` groups include closed windows, so a Main drag moves the whole chain; snap distance 10 px (Winamp); Shift at mouse-down turns snapping off; shade/unshade re-anchors windows docked below (a window hanging from a non-moving window stays).
2. **Minimize:** Main is `.miniaturizable`; `WindowCoordinator.minimizeApp()` minimizes the whole player to one Dock tile and restores the same windows; `BorderlessWindow` routes Cmd+M from every window; Option+M; Ctrl+W toggles Main windowshade.
3. **Persistence:** EQ/Playlist visibility and shade persist in `AppSettings`; `DockingController` removed; restores are top-anchored; Video/Milkdrop restore their whole saved frame.
4. **Sleep/wake and displays:** `WindowScreenGuard` (snapshot, settle window, rigid groups on display add, per-display translation, clamp) + `ScreenClamp`; Options › Reset Window Positions; drags stay out of the menu-bar strip.
5. **Titlebars and windowshade:** `SkinHitButton` hit areas with each window's own pressed sprites (18 sprites surfaced); working, draggable Main/EQ/Playlist shade strips (Main mini time and visualizer, EQ volume/balance, Playlist title/length/width grip); EQ/Playlist minimize removed (D5).

Commits: `757fc8d` (P1), `47b20de` (P2), `1c87531` `af980cd` (P3), `7523b6d` (P4), `88bff5a` (P5), `3fb7210` (P5b), `cd47d52` (P6 docs), `0cee8c8` (review fixes), `51e11e7` (one resize rule for double size and shade). Tests: 136 in 21 suites (TSan, all pass).

