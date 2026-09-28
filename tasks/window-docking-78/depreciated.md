# Deprecated/Legacy Code: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Purpose:** Track deprecated or legacy code removed during this task

## Removed in Phase 1 (2026-09-27)

| Removed | Why | Replacement |
|---|---|---|
| `MacAmpApp/ViewModels/DockingController.swift` (`DockingController`, `DockPaneType`, `DockPaneState`) | A second visibility/shade model that was never read at launch and was out of sync with the real windows. "Show/Hide Main" flipped a flag without touching the window; "Shade/Unshade EQ/Playlist" flipped flags nothing read, so the EQ couldn't be unshaded from the menu. Its `snapDistance` was unused. | Visibility and shade live in `AppSettings` (`showEqualizerWindow`, `showPlaylistWindow`, `isEqualizerWindowShaded`, `isPlaylistWindowShaded`); `WindowVisibilityController` reads/writes them and gains `isMainWindowVisible` / `toggleMain()`; the Options menu calls `WindowCoordinator` directly. |
| `Tests/MacAmpTests/DockingControllerTests.swift` | Tested the `DockLayoutV1` round-trip of the removed type. | — |
| `WinampEqualizerWindow` `@State isShadeMode`; `PlaylistWindowInteractionState.isShadeMode` | Local, unpersisted shade state that the menu couldn't reach. | `AppSettings.isEqualizerWindowShaded` / `isPlaylistWindowShaded`. |

The orphaned `DockLayoutV1` UserDefaults key is left in place. Nothing reads it, and it's harmless.

## Removed in Phase 4 (2026-09-28)

| Removed | Why | Replacement |
|---|---|---|
| EQ titlebar minimize button (`EQCoords.minimizeButton`) | Winamp's EQ has only shade and close (D5); the button drew Main's sprite. | — (group minimize from Main/Cmd+M/Option+M in Phase 5) |
| Playlist titlebar minimize button (`PlaylistTitleBarButtons.onMinimize`) | Same (D5). | — |
| Drawn normal-state titlebar/shade buttons on Main, EQ and Playlist (`Button { SimpleSpriteImage("MAIN_*") }`) | Winamp bakes these into the titlebar/shade bitmaps; drawing `MAIN_*` over EQ/Playlist was wrong and Main double-drew. | `SkinHitButton` (invisible hit area, pressed sprite only) with each window's own pressed sprites. |
| Main shade time display (big NUMBERS digits scaled 0.7, off-strip) | Not visible; Winamp uses TEXT.BMP characters there. | TEXT.BMP mini time at 127,4 (Webamp `MiniTime`). |
| `MacAmpApp/Views/SkinnedText.swift` | Unused since the initial commit. | — |
| TEXT.BMP space at column 28 | Webamp/Winamp use column 30; some skins draw a glyph at 28, so spaces showed as arrows. | `fontLookup` maps `" "` to (0, 30). |

