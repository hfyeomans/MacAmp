# TODO: Window Docking, Minimize, Persistence & Sleep/Wake (#78)

- [x] Research: MacAmp code audit, Webamp/Winamp behaviour, macOS 27 APIs → `research.md`
- [x] Draft `plan.md`
- [x] Owner decisions D1–D4 (2026-09-27): D1 closed windows keep the chain; D2 Winamp-model group minimize from every window; D3 move and keep; D4 Shift-drag + 10 px
- [ ] Phase 0 — runtime experiments 1–5 (research §4)
- [ ] Phase 1 — visibility + shade persistence; DockingController cleanup
- [ ] Phase 2 — DockGraph (closed windows keep the chain); bracket unguarded moves
- [ ] Phase 3 — ScreenClamp + WindowScreenGuard + Reset Window Positions
- [ ] Phase 4 — faithful titlebar/shade hit areas (EQ, Playlist; audit Main) + minimize (Winamp model) + shortcuts: Cmd+M / Option+M group minimize, Ctrl+W Main windowshade
- [ ] Phase 5 — Shift-drag snap toggle + snap distance 10 px
- [ ] Phase 6 — docs
- [ ] Phase 7 — TSan suite, Codex review, PR (closes #78)
