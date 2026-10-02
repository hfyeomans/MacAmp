# Todo: Structure Sprint

Updated: 2026-10-02

Derived from `plan.md`. The placement rule is a standing decision in `state.md`, not a checkbox. SS-1 to SS-4 are tracked in their own folders.

## SS-0: planning (after S3-4 merges)

- [ ] Write `mapping.md`: every file in `MacAmpApp/` and `Tests/`, including the 8 breaches in `state.md` and the S3 `Audio/HLS/` and `Audio/Vorbis/` files
- [ ] Reconcile `Audio/` subfolders with what exists (`Streaming/`, `VideoDSP/`, `ObjCBridge/`, `HLS/`, `Vorbis/`) and place the 13 files the old map omitted
- [ ] Decide the ambiguous files: `Models/*WindowSizeState`, `WindowFocusState`, `Size2D`, `SnapUtils`, `WeakBox`, `MetadataLoader`, `RenderThreadSafe`, `VideoTapVisualizerRender`, and where the remaining shared domain models in `Models/` go
- [ ] `project.yml` migration analysis (the Butterchurn path at `project.yml:25` plus an `excludes:` entry for the moved folder)
- [ ] Audit leftover early-project preprocessing workarounds
- [ ] Settle the order: SS-1 and SS-2 go/no-go first, then the moves; list shared-file overlaps between steps
- [ ] Create `tasks/features-consolidation/`, `tasks/audio-consolidation/` and `tasks/app-core-shared-consolidation/` (6-file layout; `plan.md` once planning starts)

## Moves

- [ ] SS-3 `windowing-structure-consolidation` (see its `todo.md`)
- [ ] SS-4 `milkdrop-feature-consolidation` (see its `todo.md`)
- [ ] SS-5 `Features/` consolidation, including the optional `tileRow` helper
- [ ] SS-6 `Audio/` consolidation
- [ ] SS-7 `App/`, `Core/`, `Shared/`: composition root (retire `WindowCoordinator.shared` and `AppSettings.instance()`), replace the `PlaylistWindowActions` singleton, shared window-controller init, delete the empty `ViewModels/` and `Utilities/`
- [ ] SS-8 mirror `Tests/MacAmpTests/` to the new layout; update `docs/context/xcode-testing-context.md`; 137 tests / 21 suites stay green under TSan; then a follow-up commit for the SS-8 rows in `tasks/_context/deferred.md`
- [ ] Close-out: update `docs/` path references and the local `CLAUDE.md` architecture tree

## Later / optional (SS-9)

- [ ] Evaluate `Windowing` as a local package
- [ ] Evaluate `AudioStreamingCore` as a local package
- [ ] Evaluate `SkinEngine` as a local package
