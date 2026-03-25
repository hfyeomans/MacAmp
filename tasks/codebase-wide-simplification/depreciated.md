# Deprecated/Legacy Code: Codebase-Wide Simplification

> **Description:** Track all code removed or restructured during Phase 2.5.
> **Purpose:** Reference for decomposition tasks (Tasks 1-5) when plans need refreshing.

---

## Dead Files Deleted (Batch 1, 393 lines)

| File | Lines | Reason | Impact on Decomposition Tasks |
|------|-------|--------|-------------------------------|
| `Models/WindowSpec.swift` | 101 | Superseded by per-window size states. `snapDistance` already in DockingController. | None — not a decomposition target |
| `Models/SpritePositions.swift` | 98 | Superseded by SpriteResolver + SkinSprites. Zero callers. | None |
| `Views/VisualizerOptions.swift` | 39 | Never instantiated by any view. | None |
| `Views/EqGraphView.swift` | 101 | Superseded by inline buildEQCurve() in WinampEqualizerWindow. | Task 3 (EQ Window): one less file to consider |
| `Views/SkinnedBanner.swift` | 31 | Never instantiated. | None |
| `Utilities/WindowAccessor.swift` | 23 | Superseded by NSWindowController approach. | None |

## Dead Functions/Properties Removed (Batch 2, ~270 lines)

### Affects decomposition targets:

| File | Symbol | Lines | Impact |
|------|--------|-------|--------|
| `Audio/AudioPlayer.swift` | `getRMSData(bands:)` forwarding | 4 | **Task 5 (seek extraction):** AudioPlayer now 4 lines shorter |
| `Audio/VisualizerPipeline.swift` | `onDataUpdate` callback + invocation | 8 | **Task 3 (visualizer decomp):** fewer lines to extract, `onDataUpdate` no longer exists |
| `Audio/Streaming/StreamDecodePipeline.swift` | unused `metaInt` computation block | 10 | **Task 1 (StreamDecode decomp):** lines 301-309 gone |
| `Audio/PlaybackCoordinator.swift` | `supportsVisualizer` | 4 | **Task 5:** one fewer public property |

### Does NOT affect decomposition targets:

| File | Symbol | Lines |
|------|--------|-------|
| `Audio/PlaylistController.swift` | `markEnded()`, `selectTrack(at:)`, `isEmpty` | 17 |
| `Audio/LockFreeRingBuffer.swift` | 2 AudioBufferList overloads | 32 |
| `Audio/MetadataLoader.swift` | `AudioProperties.default` | 2 |
| `Audio/EQPresetStore.swift` | `perTrackPresetsLoaded` flag + assignments | 6 |
| `Models/Size2D.swift` | `fromVideoPixels(_:)` | 7 |
| `Models/SnapUtils.swift` | 6 dead functions | ~59 |
| `Models/M3UParser.swift` | `.invalidFormat` enum case | 3 |
| `Models/SpriteResolver.swift` | `dimensions(for:)` | 12 |
| `Models/AppSettings.swift` | `fallbackSkinsDirectory()` | 8 |
| `ViewModels/WindowCoordinator+Layout.swift` | `resetToDefaultStack()` | 35 |
| `ViewModels/DockingController.swift` | 3 dead methods/properties | 20 |
| `ViewModels/ButterchurnPresetManager.swift` | `selectPreset(byName:)` | 9 |
| `Views/PreferencesView.swift` | 2 @State vars + 2 methods | 29 |
| `Windows/WindowVisibilityController.swift` | `closeKeyWindow()` | 4 |
| `ViewModels/WindowCoordinator.swift` | `closeKeyWindow()` forwarder | 1 |

## Dead/Redundant Imports Removed (Batch 3, 8 imports)

| File | Import Removed | Impact |
|------|---------------|--------|
| `ViewModels/DockingController.swift` | `import Combine`, `import SwiftUI` | None |
| `ViewModels/SkinManager.swift` | `import CoreGraphics` | **Task 4 (SkinManager decomp):** one fewer import line |
| `Views/VisualizerView.swift` | `import Accelerate` | None |
| `Views/WinampPlaylistWindow.swift` | `import AppKit` | None |
| `Utilities/WindowFocusDelegate.swift` | `import Foundation` | None |
| `Utilities/WindowSnapManager.swift` | `import Foundation` | None |
| `Windows/WindowSettingsObserver.swift` | `import Foundation` | None |

## DRY Consolidations (Batch 4, ~96 lines saved)

### Renames affecting decomposition targets:

| Old Symbol | New Symbol | Files Changed | Impact |
|-----------|-----------|---------------|--------|
| `supportsEQ` / `supportsBalance` | `supportsAudioProcessing` | PlaybackCoordinator + 2 views | **Task 3 (EQ Window):** WinampEqualizerWindow now uses `supportsAudioProcessing` |

### New shared utilities created:

| File | What | Replaces |
|------|------|----------|
| `Audio/Streaming/QueueConfined.swift` | Protocol + default `assertConfinement()` | Duplicate implementations in AudioFileStreamParser + AudioConverterDecoder |
| `Utilities/TimeFormatting.swift` | `TimeFormatting.formatDuration(_:)` | 3 duplicate implementations in TrackInfoView, PlaylistBottomControlsView, PlaylistTrackListView |
| `Utilities/MenuActionTarget.swift` | `MenuActionTarget` + `MenuItemFactory` | Duplicate NSObject subclasses in MainWindowOptionsMenuPresenter + WinampMilkdropWindow |

### Other consolidations:

| What | File | Change |
|------|------|--------|
| 3 identical `toXxxPixels()` | `Size2D.swift` | Unified to single `toPixels()` — 8 call sites updated |
| Duplicate video seek callback | `AudioPlayer.swift` | Extracted `videoSeekCompletion` computed property |

## Summary for Plan Refresh

When refreshing decomposition task plans after this PR merges:

1. **Task 1 (StreamDecodePipeline):** 10 fewer lines (metaInt block removed). `QueueConfined.swift` is a new file in `Audio/Streaming/`.
2. **Task 2 (EQ Window):** `EqGraphView.swift` deleted (was never referenced). `supportsEQ` → `supportsAudioProcessing`.
3. **Task 3 (VisualizerPipeline):** 8 fewer lines (`onDataUpdate` removed).
4. **Task 4 (SkinManager):** `import CoreGraphics` removed.
5. **Task 5 (AudioPlayer seek):** 4 fewer lines (`getRMSData` forwarding removed). `supportsVisualizer` removed. `videoSeekCompletion` is now a computed property (was inline duplicated closures).
