# Research

> **Description:** Research task evaluating MacAmp’s Swift file and folder organization against current best practices from Apple and respected Swift practitioners.
> **Purpose:** Establish an evidence-based structure policy and backlog strategy before any wide-ranging source-tree reorganization.

## Goal

Evaluate the current Swift file and folder structure in MacAmp, research high-signal Swift project-organization guidance, and recommend a better structure if the current one is too loose or inconsistent.

## Current Repo Layout

- MacAmp is currently a single executable target with tests:
  - `Package.swift` defines one executable target: `MacAmp`
  - `project.yml` defines one app target: `MacAmp`
- The source tree is primarily organized by type buckets:
  - `MacAmpApp/Views`
  - `MacAmpApp/ViewModels`
  - `MacAmpApp/Models`
  - `MacAmpApp/Utilities`
  - `MacAmpApp/Audio`
  - `MacAmpApp/Windows`
- Swift file counts by top-level source folder:
  - `Views`: 44
  - `Models`: 22
  - `Windows`: 15
  - `Audio`: 14
  - `Utilities`: 7
  - `ViewModels`: 6
- The largest files are significant:
  - `AudioPlayer.swift`: 1143 lines
  - `SkinManager.swift`: 783 lines
  - `VisualizerPipeline.swift`: 699 lines
  - `StreamDecodePipeline.swift`: 631 lines
  - `WinampEqualizerWindow.swift`: 626 lines

## Structural Smells In MacAmp

### 1. Type-bucket top-level folders

- `Views`, `Models`, `ViewModels`, and `Utilities` are broad enough to become dumping grounds.
- This makes feature work cross-cutting by default: touching one feature often means jumping across 3-5 top-level folders.

### 2. Feature scattering

- Milkdrop / Butterchurn is split across:
  - `Models/MilkdropWindowSizeState.swift`
  - `ViewModels/ButterchurnBridge.swift`
  - `ViewModels/ButterchurnPresetManager.swift`
  - `Views/WinampMilkdropWindow.swift`
  - `Views/Windows/ButterchurnWebView.swift`
  - `Views/Windows/MilkdropWindowChromeView.swift`
  - `Windows/WinampMilkdropWindowController.swift`
- Window management is also scattered across:
  - `Models/*Window*`
  - `Utilities/Window*`
  - `ViewModels/WindowCoordinator*`
  - `Views/MainWindow`, `Views/PlaylistWindow`, `Views/Windows`
  - `Windows/*`

### 3. “Utilities” and “Models” are overloaded

- `Utilities` contains generic helpers, but also window-specific infrastructure.
- `Models` contains genuine domain models, but also feature-local state and geometry that belong closer to their owning subsystem or feature.

### 4. Inconsistent UI organization

- Some screens have feature subfolders, such as `Views/MainWindow` and `Views/PlaylistWindow`.
- Other screens are flat or partly nested, such as `WinampMilkdropWindow.swift`, `WinampVideoWindow.swift`, and `Views/Windows/*`.
- That inconsistency makes the tree harder to navigate than either a strict feature-first or strict subsystem-first layout would be.

### 5. Large cross-cutting classes

- `AudioPlayer.swift`, `SkinManager.swift`, `VisualizerPipeline.swift`, and `StreamDecodePipeline.swift` are large enough to suggest multiple responsibilities are living in one file.
- This is not automatically wrong, but it usually means responsibility boundaries are not first-class in the source tree.

### 6. Resource placement is not aligned with feature ownership

- `Butterchurn/` lives at the repo root instead of under a feature-owned resources path.
- That is manageable today, but it weakens discoverability and makes ownership less obvious.

## External Research

### John Sundell: avoid dumping grounds, organize by feature, use the Rule of Threes

Source:
- https://www.swiftbysundell.com/articles/structuring-swift-code/

Relevant takeaways:
- broad folders like `Utilities`, `Helpers`, or `Base*` often become dumping grounds
- structure should evolve with the project rather than stay frozen
- when a type/folder/file clearly contains several groupable parts, split by responsibility
- feature-oriented organization scales better than top-level folders for `Views`, `Models`, and similar role buckets

### objc.io / Chris Eidhof: keep screen-level types lighter and move code to more appropriate places

Source:
- https://www.objc.io/issues/1-view-controllers/lighter-view-controllers/

Relevant takeaways:
- top-level screen/controller types are often the largest files in a project
- protocol/data-source/delegate responsibilities should move out when they are reusable or independently understandable
- lighter top-level UI types make the project easier to navigate and reason about

### Point-Free / isowords: modularize stable subsystems and features aggressively when boundaries are clear

Source:
- https://github.com/pointfreeco/isowords

Relevant takeaways:
- their app is intentionally “hyper-modularized”
- module boundaries are used to improve compile times, feature isolation, and preview/test stability
- the key lesson is not “make 86 modules”; it is “once boundaries are real, encode them structurally”

### Apple: local packages are the supported path when code boundaries deserve modularization

Source:
- https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages

Relevant takeaway:
- Apple’s tooling supports evolving a large app into multiple local packages when boundaries are stable enough to benefit from separate ownership and build isolation

## Synthesis

- The strongest external consensus is to stop using broad role-based dumping grounds as the primary structure.
- The next level up is to group by feature or subsystem, with a small amount of internal role-based structure inside each feature if needed.
- Modularization should be a second step, not the first step. If the current tree is still inconsistent, extracting packages too early will just freeze bad boundaries in place.

## Difficulty Assessment

- **Research and design only:** Small-Medium
- **Folder cleanup inside the current single target:** Medium-Large
- **Large-file decomposition plus folder cleanup:** Large
- **True modularization into local packages:** Large-High

Why this is not a trivial cleanup:
- top-level moves touch many files, paths, tests, resources, and generated project inputs
- the highest-value cleanup areas overlap current and upcoming sprint work
- a “rename everything now” pass would create merge churn without delivering immediate product value

## Conflict Analysis With Current Sprint Plan

Current sprint context from `tasks/_context/state.md` and `tasks/_context/tasks_index.md`:
- Sprint S1 is already loaded with:
  - `spm-multiple-producers-fix`
  - `audioplayer-decomposition` Phase 4
  - `network-auto-reconnect`
  - `xcode-butterchurn-webcontent-diagnosis`
- Sprint S2 and S3 contain additional work in the same broad areas:
  - streaming
  - video audio routing
  - Milkdrop/visualizer behavior
  - playlist and main window behavior

### Direct conflict surfaces

- `audioplayer-decomposition` Phase 4:
  - high overlap with any `Audio/Playback` restructure
  - should not race a broad audio folder move
- `network-auto-reconnect`:
  - high overlap with `Audio/Streaming`
  - avoid moving streaming files while changing reconnect behavior
- `xcode-butterchurn-webcontent-diagnosis`:
  - moderate overlap with a proposed `Features/Milkdrop` consolidation
  - avoid moving Butterchurn files while fixing signing/runtime issues
- `video-audio-engine-routing`:
  - future overlap with `Audio/Video`
- `mainwindow-visualizer-isolation` and playlist/window tasks:
  - moderate overlap with UI feature-folder reorganization

### Practical conclusion

- A big-bang structure refactor should **not** be its own immediate sprint.
- The best use of this work is as a **governing structure plan** applied incrementally:
  - first as conventions
  - then as opportunistic moves during already-planned task work
  - finally as targeted cleanup after the high-churn S1 tasks land

## Approved Direction

The following steps are now approved for this task:

1. Approve the top-level ownership model:
   - `App`
   - `Core`
   - `Shared`
   - `Features`
   - `Audio`
   - `Windowing`
   - `Resources`
2. Treat this task as the structure policy reference during Sprint S1, not as a standalone implementation sprint.
3. Create two focused post-S1 follow-on tasks:
   - `windowing-structure-consolidation`
   - `milkdrop-feature-consolidation`
4. After Sprint S2, plan decomposition follow-ons for:
   - `AudioPlayer.swift`
   - `SkinManager.swift`
   - `VisualizerPipeline.swift`
   - `StreamDecodePipeline.swift`
   - `WinampEqualizerWindow.swift`

## Status

Research complete. Recommendation ready.
