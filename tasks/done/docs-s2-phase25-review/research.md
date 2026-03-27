# Research

## Scope

- Reviewed:
  - `docs/MACAMP_ARCHITECTURE_GUIDE.md`
  - `docs/IMPLEMENTATION_PATTERNS.md`
  - `docs/PLAYLIST_WINDOW.md`
  - `docs/README.md`
  - `BUILDING_RETRO_MACOS_APPS_SKILL.md`
- Cross-checked against current source in `MacAmpApp/` and recent docs/code commits:
  - `abccc1f` architecture guide trim/update
  - `b6748f6` implementation patterns trim/update
  - `73add66` playlist window + README update
  - `4121f17` lessons #32-#38

## Verification Steps

- Verified current APIs/files with `fd`, `rg`, and direct source reads.
- Verified file line counts with `wc -l`.
- Ran a repository-wide check for impossible `.swift:line` references inside the 5 target docs.

## Key Findings

1. `docs/README.md` search index is partially stale:
   - Still references deleted `WindowAccessor`.
   - Claims S2 topics (`Now Playing`, `Remote commands`, `os_workgroup`, `TimeFormatting`, `WinampAlertHelper`, `PlaylistStyle.winampDefault`, `QueueConfined`, stream elapsed time) are documented in core docs where they are absent or only barely mentioned.

2. `docs/PLAYLIST_WINDOW.md` is the stalest of the five:
   - Still teaches removed `toPlaylistPixels()` instead of unified `Size2D.toPixels()`.
   - Says SAVE LIST defaults to `.m3u8`, but code saves `.m3u`.
   - Contains multiple impossible line references to pre-decomposition `WinampPlaylistWindow.swift` / `WindowCoordinator.swift`.

3. `docs/IMPLEMENTATION_PATTERNS.md` has one major stale narrative:
   - Says `PlaylistWindowActions.swift` was removed, but it is the live implementation.
   - Uses `PlaylistInteractionState` as if implemented; current type is `PlaylistWindowInteractionState`.

4. `docs/MACAMP_ARCHITECTURE_GUIDE.md` has internal contradictions:
   - Early sections still use pre-S2 audio file line counts (705 / 413) while later quick-reference tables use current counts (734 / 424 / 414 / 697).
   - Footer still says `Lines: ~5,500` while actual count is 5,249.
   - Capability-flag prose says controls dim "on error state" even though error state re-enables them.
   - Core S2 architecture topics (Now Playing / remote commands / audio workgroup flow) are not actually documented beyond file listings.

5. `BUILDING_RETRO_MACOS_APPS_SKILL.md` lessons #32-#38 are mostly solid structurally, but the document still has broader stale content:
   - Header metadata still says `Last Updated: 2026-03-22` despite March 25 additions.
   - Older sections still teach `toVideoPixels()` / `toMilkdropPixels()` / `toPlaylistPixels()`.
   - One section incorrectly claims zero `nonisolated(unsafe)` usages remain.
   - One older section still says playlist-window decomposition is only a future candidate.

## Impossible File:Line References Found

- `docs/MACAMP_ARCHITECTURE_GUIDE.md`: 5
- `docs/IMPLEMENTATION_PATTERNS.md`: 1
- `docs/PLAYLIST_WINDOW.md`: 8
- `BUILDING_RETRO_MACOS_APPS_SKILL.md`: 1
- Total: 15
