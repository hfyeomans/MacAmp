# Plan: Windowing Structure Consolidation

Updated: 2026-10-02

Move generic window infrastructure into `MacAmpApp/Windowing/` and land the listed follow-ups in the same pass. Predecessor: SS-0.

## Target layout

```text
MacAmpApp/Windowing/
  Controllers/
  Coordination/
  Geometry/
  Persistence/
```

Feature-specific windows, chrome and window controllers stay with their features (SS-4, SS-5).

## Candidates to classify

Classify each as **move as-is**, **move after a small abstraction**, or **leave in place**, after the dependency analysis in `research.md`.

- `Windows/`: `WindowRegistry`, `WindowVisibilityController`, `WindowResizeController`, `WindowFrameStore`, `WindowFramePersistence`, `WindowSettingsObserver`, `WindowScreenGuard`, `WindowDelegateWiring`, `BorderlessWindow`
- `Utilities/`: `WindowSnapManager`, `WindowDelegateMultiplexer`, `WindowFocusDelegate`, `WinampWindowConfigurator`, `WindowResizePreviewOverlay`
- `ViewModels/`: `WindowCoordinator`, `WindowCoordinator+Layout` (move whole, or split generic from feature-coupled parts first)
- `Models/`: `DockGraph`, `ScreenClamp`, `SnapUtils`, `Size2D`, `WindowFocusState`. The three `*WindowSizeState` types follow SS-0's ambiguous-file decision.

## Follow-ups (the only behavior-touching changes allowed)

From the #78 design review:

1. **Inject minimize into `BorderlessWindow`:** `var onPerformMiniaturize: (() -> Void)?` and a `canMinimize` hook, wired once in `WindowCoordinator+Layout.configureWindows()`, instead of reading `WindowCoordinator.shared`. Keep the `validateUserInterfaceItem` override (not OR'd with super).
2. **Restore policy in `ScreenClamp`:** a pure `restore(snapshot:current:visible:oldDisplays:newDisplays:anchorOrder:)` (rigid when a display was added, otherwise translate). `WindowScreenGuard.settle()` keeps the live-height `setFrameOrigin` and its clamp, end, displays, persist order. Add 2-3 `ScreenClampTests`.
3. **Shaded Playlist pixel size:** `PlaylistWindowSizeState.pixelSize(for:shaded:)`, used by `WinampPlaylistWindow.windowPixelSize`, both `PlaylistResizeHandle` sites (the preview uses the candidate size) and the literal 14s. Do not store shade state in the size model.
4. **Top-anchored origin:** one nonisolated `topAnchoredOrigin(keepingTopOf:height:)` on `DockGraph` or `ScreenClamp` for `WindowFramePersistence` and `WindowScreenGuard.settle` (live height). Leave `WindowResizeController.topLeftAnchoredFrame`, which rounds.
5. **Option+Cmd+M check:** run `NSApp.miniaturizeAll` on a live app. If Main minimizes without hiding the group, make Main's typed `.willMiniaturize` message the single hide path.
6. **TEXT.BMP glyph names:** one `SkinSprites.characterSpriteName(for:)` with the missing-glyph-to-space rule, replacing all 10 hand-built `CHARACTER_` names (8 files, list in `research.md`).
7. **Docs fixes** (any time, no need to wait for the sprint): the `xcode-testing-context.md` tag rows, `MACAMP_ARCHITECTURE_GUIDE.md:1095`, `VIDEO_WINDOW.md:391`, `MILKDROP_WINDOW.md:556`.

From the 2026-10-02 amp review:

8. **Quantized resize helper:** `Size2D.quantizedDelta(base:translation:)` backed by shared 25x29 segment constants, replacing the 6 sites in the Playlist, Video and Milkdrop resize handles. Do it together with item 3.
9. **`WindowSizeState` protocol** to remove the duplicated size persistence in `Playlist`/`Video`/`MilkdropWindowSizeState`. Do it together with item 8.

## Constraints

- No feature-specific window redesign.
- Not alongside feature branches that touch window code.
- SS-4 also edits `MilkdropWindowChromeView.swift` (item 8 touches :173/:190): land one before branching the other.
- Commit the pure file moves separately from the follow-ups so rename detection stays clean.

## Verification

- `xcodegen generate`; TSan build and test (baseline 137 tests in 21 suites, plus the new `ScreenClampTests`).
- Manual: Main, EQ, Playlist, Video and Milkdrop open and coordinate; docking, visibility, frame persistence, resize, shade and double size behave as before; sleep/wake and display changes keep windows on screen; group minimize from Main and from Option+Cmd+M.
- One `/codex:review --base main` before the PR.
