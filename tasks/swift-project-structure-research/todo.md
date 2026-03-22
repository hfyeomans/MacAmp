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

## After Sprint S1 (task folders created, implementation deferred)

- [x] Create a focused implementation task: `windowing-structure-consolidation`
- [x] Create a focused implementation task: `milkdrop-feature-consolidation`

## During Sprints S1-S3 (decomposition only, no file moves)

- [x] Keep `AudioPlayer.swift` follow-on work under the existing `audioplayer-decomposition` Phase 4 task
- [x] Create a dedicated decomposition task: `skinmanager-decomposition`
- [x] Create a dedicated decomposition task: `visualizerpipeline-decomposition`
- [x] Create a dedicated decomposition task: `streamdecodepipeline-decomposition`
- [x] Create a dedicated decomposition task: `winamp-equalizer-window-decomposition`

## Post-S3 Structure Sprint (all consolidation deferred here per D-STRUCTURE decision 2026-03-15)

- [ ] Create a source-to-target mapping for ALL ownership boundaries (single document)
- [ ] Execute `windowing-structure-consolidation` — move files into `Windowing/`
- [ ] Execute `milkdrop-feature-consolidation` — move files into `Features/Milkdrop/`
- [ ] Create and execute `Features/` consolidation (Video, EQ, Playlist)
- [ ] Create and execute `Audio/` consolidation (existing files → ownership boundaries)
- [ ] Create and execute `App/`, `Core/`, `Shared/` consolidation
- [ ] Update `project.yml`, imports, bundle resource paths, test references
- [ ] Reorganize tests to mirror source ownership boundaries

## Later / Optional

- [ ] Evaluate whether `Windowing` should become a local package
- [ ] Evaluate whether `AudioStreamingCore` should become a local package
- [ ] Evaluate whether `SkinEngine` should become a local package
