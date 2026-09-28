# TODO: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Phases and designs: `plan.md`. Results: `verification.md`.

- [x] Research: MacAmp code audit, Webamp/Winamp behaviour, macOS 27 APIs (`research.md`)
- [x] Plan with owner decisions D1–D5 (2026-09-27)
- [x] **Phase 0:** runtime experiments 1–6 (`verification.md` §Phase 0) ✅ 2026-09-27; plan updated (Design C: sleep snapshot, transition mode, settle window; Design D: menu-validation override). Unplug-during-sleep deferred to Phase 3 verification, resize paths to Phase 2.
- [x] **Phase 1:** persist EQ/Playlist visibility and EQ/Playlist shade; `DockingController` removed (`depreciated.md`). ✅ 2026-09-27: TSan 118, only #86 fails; relaunch checks pass (`verification.md`).
- [x] **Phase 2:** `DockGraph` (closed windows keep the chain); snap distance 10 px; Shift-drag flips snapping; re-anchor neighbours on shade/unshade; guard the resize moves (nestable brackets). ✅ 2026-09-27: TSan 124 (+6 `DockGraphTests`), only #86 fails; owner checks pass.
- [x] **Phase 3:** `ScreenClamp` + `WindowScreenGuard` (sleep snapshot, transition mode, settle; rigid docked groups across display add/remove; per-display translation); top-anchored restores (Playlist drift fixed); top-edge/menu-bar drag fix; "Reset Window Positions". ✅ 2026-09-27: TSan 137, only #86 fails; owner checks (launch, Reset, top edge, sleep/wake, unplug, lid/re-plug) pass.
- [x] **Phase 4:** titlebar and windowshade strips are hit areas over the baked bitmaps with each window's own pressed sprites (18 sprites surfaced with the owner); Main shade transport/eject/position/mini time/mini visualizer/options; EQ shade volume/balance; Playlist shade title/length/width grip; every shade strip draggable; full Playlist top bar drags; EQ/Playlist minimize removed (D5); TEXT.BMP space fixed. ✅ 2026-09-28: TSan 137 all pass; owner checklist passes on several skins (`verification.md`).
- [ ] **Phase 5:** group minimize (`minimizeApp`); Cmd+M and Option+M from every window; Ctrl+W Main windowshade
- [ ] **Phase 5b:** Video and Milkdrop windowing, holistically (owner reports 2026-09-28):
  - they don't reopen where they were left after a relaunch; diagnose and fix with the other restores
  - shade/unshade re-anchoring: unshading jumps Video down and breaks its dock; shading Main jumps Video up and it only returns when the EQ is unshaded
- [ ] **Phase 6:** docs (`MULTI_WINDOW_ARCHITECTURE.md` fixes + docking/recovery/minimize/windowshade/shortcuts); triage-note fix
- [ ] **Phase 7:** full TSan suite, one Codex review, PR (closes #78)
