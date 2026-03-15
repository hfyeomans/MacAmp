# Todo

> **Description:** Action checklist for converting the structure research into approved policy and bounded follow-on tasks.
> **Purpose:** Track what has been ratified now, what must guide Sprint S1, and what is intentionally deferred to later architecture work.

## Immediate

- [x] Approve the target top-level structure: `App`, `Core`, `Shared`, `Features`, `Audio`, `Windowing`, `Resources`
- [x] Approve the rule that new files should default to feature/subsystem ownership instead of global `Views` / `Models` / `ViewModels` / `Utilities`
- [x] Use this task as a standing architecture policy reference for upcoming work

## During Sprint S1

- [x] For `xcode-butterchurn-webcontent-diagnosis`, decide whether to only fix behavior or also begin `Features/Milkdrop` consolidation
- [x] For `audioplayer-decomposition` Phase 4, ensure extracted transport code lands under the intended `Audio/Playback` ownership model
- [x] For `network-auto-reconnect`, keep new work scoped under `Audio/Streaming` and avoid adding new cross-cutting utility files
- [ ] Avoid introducing new top-level files into `ViewModels` or `Utilities` unless there is a documented exception

## After Sprint S1

- [x] Create a focused implementation task: `windowing-structure-consolidation`
- [x] Create a focused implementation task: `milkdrop-feature-consolidation`
- [ ] Create a source-to-target mapping for current files that should move into `Windowing/`
- [ ] Create a source-to-target mapping for current files that should move into `Features/Milkdrop/`

## After Sprint S2

- [ ] Plan a dedicated decomposition task for `AudioPlayer.swift`
- [ ] Plan a dedicated decomposition task for `SkinManager.swift`
- [ ] Plan a dedicated decomposition task for `VisualizerPipeline.swift`
- [ ] Plan a dedicated decomposition task for `StreamDecodePipeline.swift`
- [ ] Plan a dedicated decomposition task for `WinampEqualizerWindow.swift`

## Later / Optional

- [ ] Reorganize tests to mirror source ownership boundaries
- [ ] Evaluate whether `Windowing` should become a local package
- [ ] Evaluate whether `AudioStreamingCore` should become a local package
- [ ] Evaluate whether `SkinEngine` should become a local package
