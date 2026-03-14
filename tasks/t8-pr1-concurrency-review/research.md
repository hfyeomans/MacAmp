# Research

## Scope
Review Swift 6.2 concurrency cleanup PR 1 changes in:
- MacAmpApp/ViewModels/SkinManager.swift
- MacAmpApp/Audio/LockFreeRingBuffer.swift
- MacAmpApp/Audio/VideoPlaybackController.swift
- MacAmpApp/Audio/VisualizerPipeline.swift
- MacAmpApp/ViewModels/WindowCoordinator.swift
- MacAmpApp/Audio/AudioPlayer.swift
- MacAmpApp/Utilities/WindowAccessor.swift
- MacAmpApp/Views/PreferencesView.swift
- project.yml

## Evidence Collected
- Reviewed commit diffs:
  - db9d4a3 (Swift 6.2 upgrade + ZIPFoundation preconcurrency + ring buffer suppressions)
  - afef573 (DispatchQueue -> Task replacements)
  - 4f4bcce (isolated deinit partial conversions)
- Reviewed current file state with line-numbered source snapshots.
- Verified call sites for `VisualizerPipeline.removeTap()` and `isTapInstalled`.
- Built and tested current tree with XcodeBuildMCP:
  - macOS build: pass
  - macOS tests: 40/40 pass

## Initial Observations
- `isolated deinit` adoption in `VideoPlaybackController` and `WindowCoordinator` is coherent with `@MainActor` class isolation.
- `AudioPlayer.deinit` bridge uses `MainActor.assumeIsolated` when `Thread.isMainThread`, else main-queue async fallback.
- `PreferencesView` async-after replacements use unstructured `Task` + `Task.sleep` without explicit `@MainActor` annotation.
