# TODO: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Phases and designs: `plan.md`. Results: `verification.md`.

- [x] Research: MacAmp code audit, Webamp/Winamp behaviour, macOS 27 APIs (`research.md`)
- [x] Plan with owner decisions D1–D5 (2026-09-27)
- [x] **Phase 0:** runtime experiments 1–6 (`verification.md` §Phase 0) ✅ 2026-09-27; plan updated (Design C: sleep snapshot, transition mode, settle window; Design D: menu-validation override). Unplug-during-sleep deferred to Phase 3 verification, resize paths to Phase 2.
- [x] **Phase 1:** persist EQ/Playlist visibility and EQ/Playlist shade; `DockingController` removed (`depreciated.md`). ✅ 2026-09-27: TSan 118, only #86 fails; relaunch checks pass (`verification.md`).
- [x] **Phase 2:** `DockGraph` (closed windows keep the chain); snap distance 10 px; Shift-drag flips snapping; re-anchor neighbours on shade/unshade; guard the resize moves (nestable brackets). ✅ 2026-09-27: TSan 124 (+6 `DockGraphTests`), only #86 fails; owner checks pass.
- [x] **Phase 3:** `ScreenClamp` + `WindowScreenGuard` (sleep snapshot, transition mode, settle; rigid docked groups across display add/remove; per-display translation); top-anchored restores (Playlist drift fixed); top-edge/menu-bar drag fix; "Reset Window Positions". ✅ 2026-09-27: TSan 137, only #86 fails; owner checks (launch, Reset, top edge, sleep/wake, unplug, lid/re-plug) pass.
- [x] **Phase 4:** titlebar and windowshade strips are hit areas over the baked bitmaps with each window's own pressed sprites (18 sprites surfaced with the owner); Main shade transport/eject/position/mini time/mini visualizer/options; EQ shade volume/balance; Playlist shade title/length/width grip; every shade strip draggable; full Playlist top bar drags; EQ/Playlist minimize removed (D5); TEXT.BMP space fixed. ✅ 2026-09-28: TSan 137 all pass; owner checklist passes on several skins (`verification.md`).
- [x] **Phase 5:** group minimize (`WindowCoordinator.minimizeApp`, Main `.miniaturizable`, `BorderlessWindow` routes Window › Minimize); Cmd+M and Option+M from every window; Ctrl+W Main windowshade. ✅ 2026-09-28: TSan 137 all pass; owner checks 1–8 pass (incl. display change while minimized).
- [x] **Phase 5b:** Video/Milkdrop restore the whole saved frame (they came back higher by their own height); shade/unshade re-anchoring leaves a window hanging from a non-moving window in place (Milkdrop under Video no longer jumps over it). ✅ 2026-09-28: TSan 139 all pass (+2 `DockGraphTests`); owner checks pass (`verification.md`).
- [x] **Phase 6:** docs: `MULTI_WINDOW_ARCHITECTURE.md` (stale `DockingController`/`contentView` statements fixed; new Docking, Recovery, Minimize & Windowshade section with shortcuts); stale references fixed across the other docs; `docs/README.md` fully re-audited (inventory, topic lookup, common questions, statistics); triage note fixed. ✅ 2026-09-28: link/anchor check 0 broken.
- [x] **Phase 7:** release gate ✅ 2026-09-28
  - [x] one Codex review (`/codex:review --base main`) + ultracode Swift 6.4 design review; fixes guarded against the design invariants
  - [x] owner regression checks: resolution change (lid open); Dock on the left (drag to the left edge, Reset Window Positions)
  - [x] Normal/Double Size fixed with one resize rule (`DockGraph.followResize`); owner checks pass
  - [x] full TSan suite after the review fixes: 136 tests / 21 suites pass
  - [x] push, PR [#90](https://github.com/hfyeomans/MacAmp/pull/90) closing #78 (owner merges)
  - [x] close-out: task → `tasks/done/`, `_context` (`state.md`, `tasks_index.md` S4-2a) marked complete
