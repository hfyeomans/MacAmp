# Research: Milkdrop Feature Consolidation

Updated: 2026-10-02

Where the Milkdrop feature lives today (main @ b3894d9) and how its resources reach the bundle.

## Swift files (7, in 5 folders)

- `Models/MilkdropWindowSizeState.swift`
- `ViewModels/ButterchurnBridge.swift`
- `ViewModels/ButterchurnPresetManager.swift`
- `Views/WinampMilkdropWindow.swift`
- `Views/Windows/ButterchurnWebView.swift`
- `Views/Windows/MilkdropWindowChromeView.swift`
- `Windows/WinampMilkdropWindowController.swift`

## Resources

- Repo-root `Butterchurn/`: `bridge.js`, `butterchurn.min.js`, `butterchurnPresets.min.js`, `butterchurnPresetsExtra.min.js`, `index.html`, `test.html`.
- Bundled as a folder reference by `project.yml:25` (`path: Butterchurn`, `type: folder`, `buildPhase: resources`), so it lands as a `Butterchurn/` subfolder of the app bundle.
- `ButterchurnWebView` loads it with `Bundle.main.url(..., subdirectory: "Butterchurn")` at :112 (`index.html`) and :157 (the `.js` files). These lookups change only if the bundled folder name changes.
- `test.html` is referenced nowhere in the code but ships with the folder.
- Root `Package.swift` never declared Butterchurn (its resources are only `Skins` and `Assets.xcassets`), and it is being deleted (S3-4 commit C1, fallback S4-1).
- The `project.yml` `sources` entry for `MacAmpApp` is recursive. A `Butterchurn/` folder moved under `MacAmpApp/` would also be picked up as individual files unless that entry excludes it.

## Naming

- `CLAUDE.md` naming conventions use the `Winamp` prefix (`WinampMainWindow.swift`), and all five windows and controllers follow it (`WinampMainWindow`, `WinampPlaylistWindow`, `WinampEqualizerWindow`, `WinampVideoWindow`, `WinampMilkdropWindow` and their `*WindowController`s). The original proposal renamed only the Milkdrop pair to `MilkdropWindow`/`MilkdropWindowController`.

## Scope

- In: feature-local Swift files, feature-owned resources, feature-local state types and bridges.
- Out: generic window infrastructure (SS-3) and visualizer pipeline changes.
