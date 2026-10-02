# Plan: Milkdrop Feature Consolidation

Updated: 2026-10-02

Move the Milkdrop/Butterchurn code and resources into `MacAmpApp/Features/Milkdrop/` with no behavior change. Predecessor: SS-0.

## Target layout

```text
MacAmpApp/Features/Milkdrop/
  WinampMilkdropWindow.swift
  WinampMilkdropWindowController.swift
  MilkdropWindowChromeView.swift
  MilkdropWindowSizeState.swift
  ButterchurnBridge.swift
  ButterchurnPresetManager.swift
  ButterchurnWebView.swift
  Resources/Butterchurn/
```

| Source | Target |
|--------|--------|
| `Models/MilkdropWindowSizeState.swift` | `Features/Milkdrop/` (unless SS-0 decides otherwise for the `*WindowSizeState` types) |
| `ViewModels/ButterchurnBridge.swift` | `Features/Milkdrop/` |
| `ViewModels/ButterchurnPresetManager.swift` | `Features/Milkdrop/` |
| `Views/WinampMilkdropWindow.swift` | `Features/Milkdrop/` |
| `Views/Windows/ButterchurnWebView.swift` | `Features/Milkdrop/` |
| `Views/Windows/MilkdropWindowChromeView.swift` | `Features/Milkdrop/` |
| `Windows/WinampMilkdropWindowController.swift` | `Features/Milkdrop/` |
| repo-root `Butterchurn/` | `MacAmpApp/Features/Milkdrop/Resources/Butterchurn/` |

## Decisions to make

- **Naming:** keep the `Winamp` prefix (recommended) or rename to `MilkdropWindow`/`MilkdropWindowController`. Keeping it matches the other four windows and the `CLAUDE.md` naming conventions, and keeps the commit a pure move.
- **Chrome subfolder:** keep `MilkdropWindowChromeView` flat (recommended) unless more chrome files appear; a `Chrome/` folder for one file adds nothing.
- **`test.html`:** delete it in the move (recommended). It is a red "WebView is loading" debug page from PR #32 that nothing references, yet it ships in the bundle.

## Resource move

- Update the folder reference at `project.yml:25` to the new path and keep `type: folder`, so the bundle still contains a `Butterchurn/` subfolder.
- Exclude the moved folder from the recursive `MacAmpApp` source entry, so XcodeGen does not add its files a second time.
- Keep the folder name `Butterchurn`; then the `subdirectory: "Butterchurn"` lookups in `ButterchurnWebView` (:112, :157) need no change.

## Constraints

- No generic window code in this folder.
- SS-3 also edits `MilkdropWindowChromeView.swift` (resize helper at :173/:190): land one before branching the other.
- Commit the pure moves before any rename or deletion.

## Verification

- `xcodegen generate`; inspect the generated project for a single `Butterchurn` folder reference.
- TSan build and test (baseline 137 tests in 21 suites).
- Debug run: the Milkdrop window opens, renders and cycles presets.
- Packaged build per `docs/RELEASE_BUILD_GUIDE.md`: the bundle contains `Contents/Resources/Butterchurn/` and Butterchurn loads in the Release app.
- One `/codex:review --base main` before the PR.
