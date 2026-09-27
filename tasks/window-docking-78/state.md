# Task State: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Purpose:** Fix issue #78 (join/clamp, minimize, window-state persistence) and the owner's sleep/wake off-screen windows problem.
> **Created:** 2026-09-26 — pulled ahead of the Structure Sprint (D-WIN78, user).
> **Branch:** `fix/window-docking-78` (from `main` `0d6e258`).
> **Status:** 📝 PLAN APPROVED (decisions D1–D5, 2026-09-27) — **Phase 0 ✅ + Phase 1 ✅** (2026-09-27; `verification.md`). Next: Phase 2 (docking graph, snap 10 px, Shift-drag, shade re-anchoring).
> **Files:** `research.md`, `plan.md`, `todo.md`, `verification.md`, `placeholder.md`, `depreciated.md`.

## Root causes (summary — details in research.md §1)

1. **Join:** docking is recomputed from proximity among *visible* windows only; closing the EQ breaks the Main→Playlist chain; child drags detach by design (as in Winamp/Webamp).
2. **Minimize:** no `.miniaturizable` on any borderless window; minimize targets only the key window.
3. **Persistence:** frames persist; EQ/Playlist visibility and EQ/Playlist shade don't; `showAllWindows` forces EQ/Playlist open; two visibility models disagree.
4. **Sleep/wake:** no screen-change/wake handling, no clamp, off-screen frames persisted as-is, no recovery command.

5. **Titlebars and windowshade:** the EQ and Playlist draw the Main window's titlebar sprites and add minimize buttons that aren't in Winamp; the shade strips draw sprites where Winamp has invisible hit areas, and some shade controls may not work (owner).
