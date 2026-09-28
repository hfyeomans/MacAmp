# TODO: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Phases and designs: `plan.md`. Results: `verification.md`.

- [x] Research: MacAmp code audit, Webamp/Winamp behaviour, macOS 27 APIs (`research.md`)
- [x] Plan with owner decisions D1–D5 (2026-09-27)
- [x] **Phase 0:** runtime experiments 1–6 (`verification.md` §Phase 0) ✅ 2026-09-27; plan updated (Design C: sleep snapshot, transition mode, settle window; Design D: menu-validation override). Unplug-during-sleep deferred to Phase 3 verification, resize paths to Phase 2.
- [x] **Phase 1:** persist EQ/Playlist visibility and EQ/Playlist shade; `DockingController` removed (`depreciated.md`). ✅ 2026-09-27: TSan 118, only #86 fails; relaunch checks pass (`verification.md`).
- [x] **Phase 2:** `DockGraph` (closed windows keep the chain); snap distance 10 px; Shift-drag flips snapping; re-anchor neighbours on shade/unshade; guard the resize moves (nestable brackets). ✅ 2026-09-27: TSan 124 (+6 `DockGraphTests`), only #86 fails; owner checks pass.
- [x] **Phase 3:** `ScreenClamp` + `WindowScreenGuard` (sleep snapshot, transition mode, settle; rigid docked groups across display add/remove; per-display translation); top-anchored restores (Playlist drift fixed); top-edge/menu-bar drag fix; "Reset Window Positions". ✅ 2026-09-27: TSan 137, only #86 fails; owner checks (launch, Reset, top edge, sleep/wake, unplug, lid/re-plug) pass.
- [ ] **Phase 4:** (first) surface the missing EQ/Main sprites and settle coordinates with the owner (Design G, 11 candidates); then titlebar and windowshade strips as hit areas with each window's own sprites; working shade controls (Main transport/eject/position, EQ volume/balance, Playlist title/time); make the Main/EQ/Playlist shade strips draggable (no drag handle today; a shaded Main drags its group); remove the EQ/Playlist minimize buttons (D5); per-button checklist
- [ ] **Phase 5:** group minimize (`minimizeApp`); Cmd+M and Option+M from every window; Ctrl+W Main windowshade
- [ ] **Phase 6:** docs (`MULTI_WINDOW_ARCHITECTURE.md` fixes + docking/recovery/minimize/windowshade/shortcuts); triage-note fix
- [ ] **Phase 7:** full TSan suite, one Codex review, PR (closes #78)
