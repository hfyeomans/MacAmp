# Research: Swift Project Structure

Updated: 2026-10-02

Evidence for the placement policy: how the tree is organized today, where it hurts, and what outside guidance says.

## Current layout (main @ b3894d9)

- One app target `MacAmp` plus `MacAmpTests` in `project.yml` (XcodeGen; it globs `MacAmpApp/`). Root `Package.swift` has been unbuildable since 80540c2 and is slated for deletion (S3-4 commit C1, fallback S4-1).
- 122 Swift files in `MacAmpApp/`, organized mostly by type bucket:

| Folder | Swift files | Notes |
|--------|------------:|-------|
| `Views/` | 41 | `MainWindow/`, `PlaylistWindow/`, `Components/`, `Shared/`, `Windows/` subfolders; EQ, Video, Milkdrop, Preferences views are flat |
| `Audio/` | 25 | subfolders `Streaming/` (5), `VideoDSP/` (5), `ObjCBridge/` (ObjC shim only) |
| `Models/` | 22 | domain models mixed with windowing geometry and feature-local size state |
| `Windows/` | 14 | 5 `Winamp*WindowController` plus generic window infrastructure |
| `Utilities/` | 10 | generic helpers mixed with AppKit window code |
| `ViewModels/` | 7 | Butterchurn, Skin and WindowCoordinator types |
| root | 3 | `MacAmpApp.swift`, `AppCommands.swift`, `SkinsCommands.swift` |

- Largest files: `AudioPlayer.swift` 1,097; `Streaming/StreamDecodePipeline.swift` 825; `StreamPlayer.swift` 714; `PlaybackCoordinator.swift` 587; `AudioEngineController.swift` 580.
- `Tests/MacAmpTests/` is flat: 21 files.
- Planned by S3: `Audio/HLS/` (S3-3) and `Audio/Vorbis/` (S3-4). Neither fits the original `Audio/` map.

## Structural smells

1. **Type-bucket top level.** `Views/`, `Models/`, `ViewModels/` and `Utilities/` are broad enough to become dumping grounds, and they did: 8 files landed there after the policy was approved (list in `state.md`).
2. **Feature scattering.** Milkdrop/Butterchurn spans 7 Swift files in 5 folders plus repo-root `Butterchurn/` (map in `tasks/milkdrop-feature-consolidation/research.md`). Window code spans `Windows/`, `Utilities/`, `ViewModels/` and `Models/` (map in `tasks/windowing-structure-consolidation/research.md`).
3. **Overloaded `Models/` and `Utilities/`.** `Models/` holds windowing geometry (`DockGraph`, `ScreenClamp`, `SnapUtils`, `Size2D`, `WindowFocusState`) and feature-local size state (`Playlist`/`Video`/`MilkdropWindowSizeState`). `Utilities/` holds `WindowSnapManager`, `WindowDelegateMultiplexer`, `WindowFocusDelegate`, `WinampWindowConfigurator` and `WindowResizePreviewOverlay`.
4. **Inconsistent UI organization.** `Views/MainWindow/` and `Views/PlaylistWindow/` are feature subfolders; `WinampEqualizerWindow`, `WinampVideoWindow`, `WinampMilkdropWindow` and `Views/Windows/*` are flat.
5. **Large cross-cutting classes.** The five files above carry several responsibilities each; SS-1 and SS-2 re-evaluate the two whose growth triggers fired.
6. **Resources away from their owner.** `Butterchurn/` sits at the repo root instead of under the Milkdrop feature.
7. **Two access paths to shared objects.** `WindowCoordinator.shared` has 24 references (21 in `Views/`) and `AppSettings.instance()` has 14, alongside environment injection. `PlaylistWindowActions.shared` is an `NSMenuItem` target singleton with mutable selection state and 3 `Task.detached` calls (`PlaylistWindowActions.swift:103/257/288`).

## External guidance

- John Sundell, [Structuring Swift code](https://www.swiftbysundell.com/articles/structuring-swift-code/): broad `Utilities`/`Helpers` folders become dumping grounds; organize by feature; split by responsibility; let structure evolve.
- objc.io, [Lighter View Controllers](https://www.objc.io/issues/1-view-controllers/lighter-view-controllers/): top-level screen types grow largest; move reusable or separately understandable responsibilities out.
- Point-Free, [isowords](https://github.com/pointfreeco/isowords): once boundaries are real, encode them as modules for build isolation and test/preview stability.
- Apple, [Organizing your code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages): local packages are the supported path once a boundary deserves its own module.

## Synthesis

- Stop using role-based buckets as the primary structure; group by feature or subsystem, with small role subfolders inside only where they help.
- Modularize second. Extracting packages from an inconsistent tree freezes bad boundaries.

## Difficulty

- Folder cleanup inside the single target: Medium-Large.
- Decomposition plus folder cleanup: Large.
- Local packages: Large-High.
- A big-bang restructure is high risk; one planned sprint of per-area PRs is tractable.
