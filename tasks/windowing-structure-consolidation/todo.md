# Todo: Windowing Structure Consolidation

Updated: 2026-10-02

Derived from `plan.md`. Item numbers match the plan's follow-up list.

## Any time

- [ ] (7) Docs fixes: `docs/context/xcode-testing-context.md` `.audio`/`.concurrency`/`.parsing` tag rows; `MACAMP_ARCHITECTURE_GUIDE.md:1095` (Main's visibility is not persisted); `VIDEO_WINDOW.md:391` and `MILKDROP_WINDOW.md:556` (only a Main drag moves the group)

## Prepare (after SS-0)

- [ ] Dependency analysis of `WindowCoordinator` and `WindowRegistry`; reject circular dependencies
- [ ] Classify every candidate in `plan.md` (move as-is / move after a small abstraction / leave)
- [ ] Decide whether `WindowCoordinator` moves whole into `Windowing/Coordination/` or is split first
- [ ] Write the source-to-target map for this task from SS-0's `mapping.md`

## Follow-ups

- [ ] (1) Inject minimize into `BorderlessWindow` (`onPerformMiniaturize`, `canMinimize`), wired in `configureWindows()`
- [ ] (2) `ScreenClamp.restore(...)` restore policy, plus 2-3 `ScreenClampTests`
- [ ] (3) `PlaylistWindowSizeState.pixelSize(for:shaded:)` at all shaded-size sites
- [ ] (8) `Size2D.quantizedDelta(base:translation:)` at the 6 resize sites, with item 3
- [ ] (9) `WindowSizeState` protocol for `Playlist`/`Video`/`MilkdropWindowSizeState`, with item 8
- [ ] (4) Shared `topAnchoredOrigin(keepingTopOf:height:)` for `WindowFramePersistence` and `WindowScreenGuard.settle`
- [ ] (5) Check Option+Cmd+M on a running app; if needed, make Main's `.willMiniaturize` the single hide path
- [ ] (6) `SkinSprites.characterSpriteName(for:)` replacing all 10 `CHARACTER_` sites in 8 files

## Execute

- [ ] Move the agreed files into `Windowing/` (pure-move commit), then `xcodegen generate`
- [ ] TSan build and test; manual multi-window checks per `plan.md` §Verification
- [ ] Record deferrals in `tasks/_context/deferred.md`; ambiguous-file notes in `placeholder.md`
- [ ] One `/codex:review --base main`, then open the PR
