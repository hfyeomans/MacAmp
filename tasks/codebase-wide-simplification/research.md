# Research: Codebase-Wide Simplification

> **Description:** Synthesized findings from 5-agent team sweep of all 112 .swift files.
> **Updated:** 2026-03-24 (agent sweep complete, findings prioritized)

---

## Agent Team Results

| Agent | Files | Findings | Est. Lines |
|-------|-------|----------|------------|
| audio-agent | 15 | 18 | ~102 |
| views-agent | 44 | 18 | ~683 |
| models-agent | 22 | 18 | ~455 |
| viewmodels-agent | 6 | 14 | ~96 |
| infra-agent | 25 | 12 | ~200 |
| **Total** | **112** | **80** | **~1,536** |

---

## Batch 1: Dead Files (delete entire files, ~393 lines, ZERO risk)

| File | Lines | Reason |
|------|-------|--------|
| `Models/WindowSpec.swift` | 101 | Superseded by per-window size states. 1 external ref (`SimpleSpriteImage.snapDistance`) → replace with inline `15` or `SnapUtils.SNAP_DISTANCE` |
| `Models/SpritePositions.swift` | 98 | Superseded by SpriteResolver + SkinSprites. Zero callers. |
| `Views/VisualizerOptions.swift` | 39 | Never instantiated by any view. |
| `Views/EqGraphView.swift` | 101 | Superseded by inline `buildEQCurve()` in WinampEqualizerWindow. Zero callers. |
| `Views/SkinnedBanner.swift` | 31 | Never instantiated. |
| `Utilities/WindowAccessor.swift` | 23 | Superseded by NSWindowController approach. Zero callers. |

## Batch 2: Dead Functions/Properties (~180 lines, ZERO-LOW risk)

### Audio/
| File | Symbol | Lines | Callers |
|------|--------|-------|---------|
| `PlaylistController.swift` | `markEnded()` | 4 | 0 |
| `PlaylistController.swift` | `selectTrack(at:)` | 6 | 0 |
| `PlaylistController.swift` | `isEmpty` | 1 | 0 |
| `AudioPlayer.swift` | `getRMSData(bands:)` forwarding | 3 | 0 |
| `VisualizerPipeline.swift` | `onDataUpdate` callback | 3 | never set |
| `LockFreeRingBuffer.swift` | `write(_ bufferList:frameCount:)` | 15 | 0 production |
| `LockFreeRingBuffer.swift` | `read(into bufferList:frameCount:)` | 13 | 0 production |
| `MetadataLoader.swift` | `AudioProperties.default` | 1 | 0 |
| `EQPresetStore.swift` | `perTrackPresetsLoaded` flag | 3 | written but never read |
| `PlaybackCoordinator.swift` | `supportsVisualizer` | 2 | 0 |
| `StreamDecodePipeline.swift` | unused `metaInt` computation block | 8 | value computed, logged, discarded |

### Models/
| File | Symbol | Lines | Callers |
|------|--------|-------|---------|
| `Size2D.swift` | `fromVideoPixels(_:)` | 5 | 0 |
| `SnapUtils.swift` | 6 dead functions (`snapDiff`, `snapDiffManyToMany`, `snapWithinDiff`, `applyMultipleDiffs`, `traceConnection`, `applyDiff`) | ~50 | 0 |
| `M3UParser.swift` | `.invalidFormat` enum case | 4 | 0 |
| `SpriteResolver.swift` | `dimensions(for:)` | 12 | 0 |
| `AppSettings.swift` | `fallbackSkinsDirectory()` | 7 | 0 |

### ViewModels/
| File | Symbol | Lines | Callers |
|------|--------|-------|---------|
| `WindowCoordinator+Layout.swift` | `resetToDefaultStack()` | 33 | 0 |
| `DockingController.swift` | `isEqualizerBetweenMainAndPlaylist()` | 5 | 0 |
| `DockingController.swift` | `getVisibleWindowsInOrder()` | 3 | only dead callers |
| `DockingController.swift` | `sortedVisiblePanes` | 5 | only dead callers |
| `ButterchurnPresetManager.swift` | `selectPreset(byName:)` | 4 | 0 |

### Views/
| File | Symbol | Lines | Callers |
|------|--------|-------|---------|
| `PreferencesView.swift` | 2 dead @State vars + 2 dead methods | 22 | 0 |

### Windows/
| File | Symbol | Lines | Callers |
|------|--------|-------|---------|
| `WindowVisibilityController.swift` | `closeKeyWindow()` | 4 | 0 (+ forwarding in WindowCoordinator) |

## Batch 3: Dead Imports (~15 lines, ZERO risk)

| File | Import |
|------|--------|
| `DockingController.swift` | `import Combine` |
| `SkinManager.swift` | `import CoreGraphics` (AppKit re-exports it) |
| `DockingController.swift` | `import SwiftUI` (no SwiftUI types used) |
| `VisualizerView.swift` | `import Accelerate` |
| `WinampPlaylistWindow.swift` | `import AppKit` (no NS* types used) |
| `WindowFocusDelegate.swift` | `import Foundation` (AppKit re-exports) |
| `WindowSnapManager.swift` | `import Foundation` (AppKit re-exports) |
| `WindowSettingsObserver.swift` | `import Foundation` (not used directly) |

## Batch 4: DRY Consolidation — Simple (~100 lines, LOW risk)

| What | Files | Fix |
|------|-------|-----|
| 3 identical `toXxxPixels()` methods | `Size2D.swift` | Unify to single `toPixels()` method |
| 3 identical `supportsEQ/Balance/Visualizer` | `PlaybackCoordinator.swift` | Consolidate (also remove dead `supportsVisualizer`) |
| Duplicate video seek callback | `AudioPlayer.swift` (2 locations) | Extract `syncVideoSeekState()` helper |
| Duplicate `assertConfinement()` | `AudioFileStreamParser.swift` + `AudioConverterDecoder.swift` | Extract shared protocol or mixin |
| `formatDuration` / `formatTime` (3 files) | `TrackInfoView`, `PlaylistBottomControlsView`, `PlaylistTrackListView` | Extract shared `TimeFormatter` utility |
| Duplicate `MenuItemActionTarget` / `MilkdropMenuTarget` | `MainWindowOptionsMenuPresenter` + `WinampMilkdropWindow` | Extract shared `MenuActionTarget` utility |

## Batch 5: DRY Consolidation — Moderate (~250 lines, LOW-MEDIUM risk)

| What | Files | Fix |
|------|-------|-----|
| Duplicate alert/dialog patterns (5 sites) | `PlaylistWindowActions`, `PlaylistMenuPresenter`, `WinampEqualizerWindow` | Extract `WinampAlertHelper` utility |
| Duplicate EQ/Playlist visibility methods | `WindowVisibilityController` | Consolidate with `makeKey: Bool` parameter |
| Window controller boilerplate (5 controllers) | All 5 `WinampXxxWindowController` files | Factory method in `WinampWindowConfigurator` |
| Duplicate `isOpaque`/`backgroundColor` | 5 controllers + `installHitSurface` | Remove redundant sets from controllers |
| Duplicate window config (`titleVisibility` etc.) | `WinampWindowConfigurator` + `WindowSnapManager.register()` | Consolidate into `WinampWindowConfigurator.apply()` |
| Top-left anchor resize pattern (5 sites) | `WindowResizeController` + `WindowResizePreviewOverlay` | Extract `topLeftAnchoredFrame()` helper |
| Duplicate observation boilerplate (4 methods) | `WindowSettingsObserver` | Extract generic observation helper |

## Deferred (not fixing now)

| What | Why Deferred |
|------|-------------|
| `PresetsButton.swift` (146 lines, LIKELY dead) | Needs verification — may have EQF folder scanning feature worth preserving |
| `WinampButtonStyle` adoption (47 modifier sites) | Too many call sites for this PR — separate task |
| Titlebar buttons (4 files) | Couples to decomposition Task 2 (EQ Window) — do during extraction |
| Resize handle dedup (3 files) | Complex — parameterization needs careful testing |
| Scrolling text timer dedup (2 files) | Moderate coupling — defer to post-decomposition |
| Character sprite text (4 files) | Multiple subtle rendering differences — defer |
| Window size state duplication (3 files) | @Observable class refactoring — higher risk |
| EQPreset vs EqfPreset overlap | Different dB conversion formulas — needs audio verification |
| `PlaybackStopReason` dead enum | Used in AudioPlayer state machine — defer to seek extraction (Task 5) |
