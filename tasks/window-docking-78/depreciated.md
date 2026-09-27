# Deprecated/Legacy Code: Window Docking, Minimize, Persistence, Windowshade & Sleep/Wake (#78)

> **Purpose:** Track deprecated or legacy code removed during this task

## Removed in Phase 1 (2026-09-27)

| Removed | Why | Replacement |
|---|---|---|
| `MacAmpApp/ViewModels/DockingController.swift` (`DockingController`, `DockPaneType`, `DockPaneState`) | A second visibility/shade model that was never read at launch and was out of sync with the real windows. "Show/Hide Main" flipped a flag without touching the window; "Shade/Unshade EQ/Playlist" flipped flags nothing read, so the EQ couldn't be unshaded from the menu. Its `snapDistance` was unused. | Visibility and shade live in `AppSettings` (`showEqualizerWindow`, `showPlaylistWindow`, `isEqualizerWindowShaded`, `isPlaylistWindowShaded`); `WindowVisibilityController` reads/writes them and gains `isMainWindowVisible` / `toggleMain()`; the Options menu calls `WindowCoordinator` directly. |
| `Tests/MacAmpTests/DockingControllerTests.swift` | Tested the `DockLayoutV1` round-trip of the removed type. | — |
| `WinampEqualizerWindow` `@State isShadeMode`; `PlaylistWindowInteractionState.isShadeMode` | Local, unpersisted shade state that the menu couldn't reach. | `AppSettings.isEqualizerWindowShaded` / `isPlaylistWindowShaded`. |

The orphaned `DockLayoutV1` UserDefaults key is left in place. Nothing reads it, and it's harmless.
