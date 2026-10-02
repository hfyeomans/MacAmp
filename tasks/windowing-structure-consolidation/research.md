# Research: Windowing Structure Consolidation

Updated: 2026-10-02

Where window code lives today (main @ b3894d9) and the facts behind each follow-up.

## Current spread

| Folder | Window files |
|--------|--------------|
| `Windows/` | `BorderlessWindow`, `WindowDelegateWiring`, `WindowFramePersistence`, `WindowFrameStore`, `WindowRegistry` (73 lines), `WindowResizeController`, `WindowScreenGuard`, `WindowSettingsObserver`, `WindowVisibilityController`; plus 5 feature-local `Winamp*WindowController` |
| `Utilities/` | `WindowSnapManager`, `WindowDelegateMultiplexer`, `WindowFocusDelegate`, `WinampWindowConfigurator`, `WindowResizePreviewOverlay` |
| `ViewModels/` | `WindowCoordinator` (239 lines), `WindowCoordinator+Layout` (129 lines) |
| `Models/` | geometry and focus: `DockGraph`, `ScreenClamp`, `SnapUtils`, `Size2D`, `WindowFocusState`; feature size state: `PlaylistWindowSizeState`, `VideoWindowSizeState`, `MilkdropWindowSizeState` |

## Coupling

- `WindowCoordinator` and `WindowRegistry` may carry feature-specific knowledge. Before any move, decide per type whether it is generic, generic after a small seam or split, or feature-coupled and left in place. Reject any plan that creates circular dependencies or forces broad API reshaping.
- `BorderlessWindow` reads `WindowCoordinator.shared` for minimize (`BorderlessWindow.swift:10`, `:15`). App-wide there are 24 `WindowCoordinator.shared` references; retiring them is SS-7's composition-root work, not this task's.

## Follow-up evidence

- #78 design-review follow-ups: `tasks/done/window-docking-78/verification.md` (Phase 7) and `docs/MULTI_WINDOW_ARCHITECTURE.md` §Docking, Recovery, Minimize & Windowshade.
- `ScreenClamp` has `clamp`, `translate` and `rigid` but no restore policy; `WindowScreenGuard.settle()` picks between them inline. `ScreenClampTests.swift` exists.
- Top-anchored origin math: a private `topAnchoredOrigin` in `WindowFramePersistence.swift:133` and inline math in `WindowScreenGuard.swift:151`. `WindowResizeController.topLeftAnchoredFrame` (:18) rounds, so it stays separate.
- Shaded Playlist size: `WinampPlaylistWindow.windowPixelSize` (:18) and literal `14` heights at :66 and :68; `PlaylistResizeHandle` derives the shaded size itself at :39 (preview) and :57.
- Quantized 25x29 resize math at 6 sites: `PlaylistResizeHandle.swift:29/:46` (named segment constants), `VideoWindowChromeView.swift:304/:322` and `MilkdropWindowChromeView.swift:173/:190` (literal 25 and 29). `Size2D` has `toPixels()` and `clamped` but no quantize helper.
- Size persistence is duplicated across the three `*WindowSizeState` types.
- TEXT.BMP glyph names are built by hand in 10 `CHARACTER_` occurrences across 8 files: `VideoWindowChromeView:196`, `MainWindowTrackInfoLayer:44`, `PlaylistBitmapText:31`, `PlaylistShadeView:72` (x2), `MainWindowIndicatorsLayer:60/:75`, `MainWindowShadeLayer:102`, `SkinSprites:482`, `SpriteResolver:159`.
- Docs errors found during #78: the `.audio`, `.concurrency` and `.parsing` tag rows in `docs/context/xcode-testing-context.md` are incomplete; `docs/MACAMP_ARCHITECTURE_GUIDE.md:1095` says every window persists visibility (Main does not); `docs/VIDEO_WINDOW.md:391` and `docs/MILKDROP_WINDOW.md:556` say those windows move with a cluster (only a Main drag moves the group).
