# Plan: Structure Sprint

Updated: 2026-10-02

Target layout, SS-0 planning work, and the scopes of the Structure Sprint steps that have no folder yet (SS-5 to SS-9). Step order and predecessors live in `tasks/_context/plan.md`; SS-1 to SS-4 have their own folders.

## Target layout

```text
MacAmpApp/
  App/         MacAmpApp.swift, AppCommands, SkinsCommands, composition-root wiring
  Core/        truly global, generic code only; stays small (it must not become the new Utilities/)
  Shared/      cross-feature UI and primitives (today's Views/Shared/ and Views/Components/)
  Features/    MainWindow/ Playlist/ Equalizer/ Milkdrop/ Video/ Preferences/ Skins/ Radio/
  Audio/       Playback/ Streaming/ Equalizer/ Visualization/ VideoDSP/ Persistence/ ObjCBridge/ HLS/ Vorbis/
  Windowing/   Controllers/ Coordination/ Geometry/ Persistence/
  Resources/   only resources no feature owns; feature resources live with the feature
```

- **Proximity rule:** a file that mostly serves one feature lives in that feature, including its state, window controller and resources.
- **`Models/` shrinks** to shared domain models only (e.g. `Track`, `RadioStation`, `Skin`, `AppSettings`, `EQPreset`); feature-local state moves to its feature and windowing types to `Windowing/`. SS-0's mapping decides whether the remainder stays in `Models/` or moves under `Core/` or `Shared/`.
- **Audio/ names follow what exists:** `Streaming/` (since PR #57), `VideoDSP/` (not the originally planned `Video/`), `ObjCBridge/`, plus `HLS/` (S3-3) and `Vorbis/` (S3-4).
- **File conventions:** one primary type per file, with adjacent responsibility-specific extensions; split by responsibility, not line count; name types by role (coordinator, bridge, store) instead of a global "ViewModels" category; tests mirror source ownership.

## SS-0: planning (this folder)

Starts after S3-4 merges. Output: `mapping.md` in this folder, one row per file in `MacAmpApp/` and `Tests/`, giving its target path and the step that moves it.

1. **Mapping covers every file**, including the 8 placement-rule breaches listed in `state.md` and the S3 additions under `Audio/HLS/` and `Audio/Vorbis/`.
2. **Audio/ reconciliation.** The original map omitted `AudioEngineController`, `AudioEngineConfigurationObserver`, `MetadataLoader`, `RenderThreadSafe`, `StreamPlayer`, `VisualizerFeed`, `VisualizerScratchBuffers`, `Streaming/QueueConfined` and the 5 `VideoDSP/` files. Place all of them.
3. **Ambiguous files:** `Models/*WindowSizeState` and `WindowFocusState` (windowing type or feature state), `Size2D`, `SnapUtils`, `WeakBox`, `MetadataLoader`, `RenderThreadSafe`, and `VideoTapVisualizerRender` (`VideoDSP/` or `Visualization/`). Also decide where the shared domain models left in `Models/` end up: stay there, or move under `Core/` or `Shared/`.
4. **project.yml migration.** Its `sources` entry globs `MacAmpApp/`, so moves inside it need no `project.yml` edit. The Butterchurn folder reference at `project.yml:25` changes, plus an `excludes:` entry for the moved folder in the `MacAmpApp` sources entry, so XcodeGen does not add it twice (SS-4). Root `Package.swift` is gone by then (S3-4 commit C1, fallback S4-1), so there are no SwiftPM paths to update.
5. **Execution order.** Run the SS-1 and SS-2 go/no-go decisions first (both decompose in place in `Audio/`), then the moves. Record shared-file overlaps, e.g. SS-3 and SS-4 both edit `MilkdropWindowChromeView.swift`, and SS-3's follow-ups edit `Views/` files that SS-5 later moves.
6. **Create the SS-5, SS-6 and SS-7 task folders** (state, research, plan, todo, placeholder, depreciated; `plan.md` once planning starts), seeded from the mapping.
7. **Audit leftover early-project preprocessing workarounds** (`SkinBackgroundPreprocessor` was already removed in PR #75) and record any survivors in the mapping.

## SS-5: Features/ consolidation

Folder to create: `tasks/features-consolidation/`. After SS-0, SS-3 and SS-4.

- Move feature-local views, state and window controllers into `Features/<Feature>/` for MainWindow, Playlist, Equalizer, Video, Preferences, Skins and Radio. `Views/MainWindow/` and `Views/PlaylistWindow/` are already subfolders; the EQ, Video and `Views/Windows/*` files are flat.
- Feature-local `Models/` state (e.g. `PlaylistWindowSizeState`, `VideoWindowSizeState`) moves with its feature.
- Optional: a small `tileRow` helper for the tiled title-bar chrome, repeated in 4 files (`WinampPlaylistWindow`, `WinampVideoWindow`, `VideoWindowChromeView`, `MilkdropWindowChromeView`; 20 `.position(…, y: 10)` sites). It is past the Principle 4 threshold.

## SS-6: Audio/ consolidation

Folder to create: `tasks/audio-consolidation/`. After SS-0, SS-1 and SS-2.

- `Playback/`: `AudioPlayer`, `PlaybackCoordinator`, `PlaylistController`, `AudioEngineController`, `AudioEngineConfigurationObserver`, plus `SeekController` if SS-1 goes ahead.
- `Streaming/` (exists): add `StreamPlayer`, `LockFreeRingBuffer` and any SS-2 extractions.
- `Equalizer/`: `EqualizerController`, `EQPresetStore`.
- `Visualization/`: `VisualizerPipeline`, `VisualizerFeed`, `VisualizerScratchBuffers`, possibly `VideoTapVisualizerRender`.
- `VideoDSP/` (exists): add `VideoPlaybackController`.
- `Persistence/`, `ObjCBridge/`, `HLS/`, `Vorbis/`: contents per the mapping.
- Smoke: local file, stream, video and Butterchurn playback.

## SS-7: App/, Core/, Shared/ and composition root

Folder to create: `tasks/app-core-shared-consolidation/`, seeded with the `PlaylistWindowActions` rows from `tasks/done/playlistwindow-layer-decomposition/depreciated.md` sections 3-4. After SS-0, SS-5 and SS-6.

- `App/`: `MacAmpApp.swift`, `AppCommands`, `SkinsCommands` and the composition root.
- `Core/`: candidates `AppLogger`, `TimeFormatting`, `WeakBox`. `Shared/`: today's `Views/Shared/` and `Views/Components/`.
- Delete the top-level `ViewModels/` and `Utilities/` once empty.
- **Composition root:** inject `WindowCoordinator` and `AppSettings` through the environment and retire the parallel paths: `WindowCoordinator.shared` (24 references, 21 in `Views/`) and `AppSettings.instance()` (14).
- **Replace the `PlaylistWindowActions` singleton** (`NSMenuItem` target with mutable `selectedIndices`) and drop the manual selection-state sync that it forces. Its 3 `Task.detached` calls are also an S4-1 strict-concurrency item.
- **One shared init** for the 5 window controllers, which repeat the same setup today.

## SS-8: mirror tests

After SS-3 to SS-7. Move the flat `Tests/MacAmpTests/` (21 files) into folders that mirror the new layout (e.g. `Audio/Streaming/`, `Windowing/`, `Features/Milkdrop/`). Pure moves, no test changes, same test count. Update `docs/context/xcode-testing-context.md`. Then one follow-up commit for the SS-8 rows in `tasks/_context/deferred.md` (`Task.sleep` determinism, Swift Testing follow-ups).

## SS-9: local packages (optional)

After SS-8, and only where a boundary has proven itself: evaluate `Windowing`, `AudioStreamingCore` and `SkinEngine` as local packages. Not scheduled.

## Rules for every step

- One branch and PR per step; no umbrella restructure branch. Do not run a move while a feature branch touches the same files.
- Commit pure moves separately from refactors, so git rename detection keeps file history readable.
- Verify each PR: `xcodegen generate`, TSan build and test (baseline 137 tests in 21 suites), manual smoke of the moved area, then one `/codex:review --base main` before the PR.
- Close-out after the last move: update path references in `docs/` (~150 `MacAmpApp/<folder>/` references across 11 top-level docs at b3894d9) and the architecture tree in the local `CLAUDE.md`.
- `_context` docs are committed directly to main, and only when the owner asks.
