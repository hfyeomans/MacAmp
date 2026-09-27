# Task State: Window Docking, Minimize, Persistence & Sleep/Wake (#78)

> **Purpose:** Fix issue #78 (join/clamp, minimize, window-state persistence) and the owner's sleep/wake off-screen windows problem.
> **Created:** 2026-09-26 — pulled ahead of the Structure Sprint (D-WIN78, user).
> **Branch:** `fix/window-docking-78` (from `main` `0d6e258`).
> **Status:** 📝 PLAN DRAFT — research done (`research.md`); `plan.md` awaiting owner decisions D1–D4, then one Codex plan review, then Phase 0 experiments.

## Root causes (summary — details in research.md §1)

1. **Join:** docking is recomputed from proximity among *visible* windows only; closing the EQ breaks the Main→Playlist chain; child drags detach by design (as in Winamp/Webamp).
2. **Minimize:** no `.miniaturizable` on any borderless window; minimize targets only the key window.
3. **Persistence:** frames persist; EQ/Playlist visibility and EQ/Playlist shade don't; `showAllWindows` forces EQ/Playlist open; two visibility models disagree.
4. **Sleep/wake:** no screen-change/wake handling, no clamp, off-screen frames persisted as-is, no recovery command.
