# TODO: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> Phases and designs: `plan.md`. Results: `verification.md`.

- [x] Research: MacAmp code audit, Webamp/Winamp behaviour, macOS 27 APIs (`research.md`)
- [x] Plan with owner decisions D1–D5 (2026-09-27)
- [ ] **Phase 0:** runtime experiments 1–6 (`verification.md` §Phase 0); adjust the plan if the findings require it
- [ ] **Phase 1:** persist EQ/Playlist visibility and EQ/Playlist shade; remove or trim `DockingController`/`DockLayoutV1` (`depreciated.md`)
- [ ] **Phase 2:** `DockGraph` (closed windows keep the chain); snap distance 10 px; Shift-drag flips snapping; re-anchor neighbours on shade/unshade; guard the resize moves with `isAdjusting`
- [ ] **Phase 3:** `ScreenClamp` + `WindowScreenGuard` (launch, screen-parameter change, wake; debounced); "Reset Window Positions" command
- [ ] **Phase 4:** titlebar and windowshade strips as hit areas with each window's own sprites; working shade controls (Main transport/eject/position, EQ volume/balance, Playlist title/time); remove the EQ/Playlist minimize buttons (D5); per-button checklist
- [ ] **Phase 5:** group minimize (`minimizeApp`); Cmd+M and Option+M from every window; Ctrl+W Main windowshade
- [ ] **Phase 6:** docs (`MULTI_WINDOW_ARCHITECTURE.md` fixes + docking/recovery/minimize/windowshade/shortcuts); triage-note fix
- [ ] **Phase 7:** full TSan suite, one Codex review, PR (closes #78)
