# Plan

> **Description:** Execution plan for turning the Swift project-structure research into a safe backlog and rollout strategy.
> **Purpose:** Prevent repo-structure churn while still letting the new ownership model guide active and future tasks.

## Recommended Direction

MacAmp should move away from top-level type buckets and toward a hybrid structure:

- feature-first for user-facing areas
- subsystem-first for shared technical engines
- very small `Shared` / `Core` areas for truly cross-cutting code

## Recommended Top-Level Structure

```text
MacAmpApp/
  App/
  Core/
  Shared/
  Features/
  Audio/
  Windowing/
  Resources/
```

### `App/`

Keep app entry and bootstrap wiring here:
- `MacAmpApp.swift`
- app commands
- app-level composition/root dependency wiring

### `Core/`

Only code that is truly global and generic:
- logging
- narrow cross-cutting extensions
- tiny support utilities with no feature ownership

This should stay small. It must not become the new `Utilities`.

### `Shared/`

UI and primitives that are reused across multiple features but are not app-global infrastructure:
- reusable skinned controls
- small value types genuinely used across multiple areas
- presentation primitives

### `Features/`

All user-facing areas should live here, each with their own nearby state, views, coordinators, and resources:

```text
Features/
  MainWindow/
  Playlist/
  Equalizer/
  Milkdrop/
  Video/
  Preferences/
  Skins/
  Radio/
```

Each feature can have internal subfolders only if they help:

```text
Features/Milkdrop/
  MilkdropWindow.swift
  MilkdropWindowController.swift
  MilkdropWindowSizeState.swift
  ButterchurnBridge.swift
  ButterchurnPresetManager.swift
  ButterchurnWebView.swift
  Chrome/
  Resources/
```

The main rule is proximity: if a file mostly exists for one feature, keep it in that feature.

### `Audio/`

Treat audio as a technical subsystem, but break it down internally by responsibility:

```text
Audio/
  Playback/
  Streaming/
  Equalizer/
  Visualization/
  Video/
  Persistence/
```

Suggested mapping:
- `AudioPlayer.swift`, `PlaybackCoordinator.swift`, `PlaylistController.swift` → `Audio/Playback/`
- `AudioConverterDecoder.swift`, `AudioFileStreamParser.swift`, `ICYFramer.swift`, `StreamDecodePipeline.swift`, `LockFreeRingBuffer.swift` → `Audio/Streaming/`
- `EqualizerController.swift`, `EQPresetStore.swift` → `Audio/Equalizer/`
- `VisualizerPipeline.swift` → `Audio/Visualization/`
- `VideoPlaybackController.swift` → `Audio/Video/`

### `Windowing/`

Create one shared subsystem for generic window infrastructure:

```text
Windowing/
  Controllers/
  Geometry/
  Persistence/
  Coordination/
```

This is where generic window mechanics live:
- `WindowSnapManager`
- `WindowResizeController`
- `WindowFrameStore`
- `WindowDockingGeometry`
- `WindowRegistry`
- `WindowCoordinator`

Feature-specific windows stay in `Features/*`, while reusable window mechanics move here.

### `Resources/`

Move feature-owned raw resources closer to the code that owns them when practical.

High-priority example:
- move repo-root `Butterchurn/` into a feature-owned resources location such as:
  - `MacAmpApp/Features/Milkdrop/Resources/Butterchurn/`
  - or a future local package resource bundle if Milkdrop becomes a package

## File-Level Conventions

### 1. One primary type per file

- Keep one main type per file whenever practical.
- Helper extensions are fine, but they should be adjacent and responsibility-specific.

### 2. Split by responsibility, not by arbitrary line count

For large files, split when there are clearly separate concerns:
- `AudioPlayer+EngineLifecycle.swift`
- `AudioPlayer+LocalPlayback.swift`
- `AudioPlayer+StreamingBridge.swift`
- `AudioPlayer+State.swift`

That is better than a blind “every 300 lines” rule.

### 3. Avoid top-level `ViewModels` as a global category

- In SwiftUI/macOS apps, many “view models” are actually coordinators, bridges, stores, or managers.
- Name them by role and colocate them with their feature or subsystem.

### 4. Mirror tests to source ownership

Test files should follow the same conceptual boundaries:
- `Tests/MacAmpTests/Audio/Streaming/...`
- `Tests/MacAmpTests/Windowing/...`
- `Tests/MacAmpTests/Features/Milkdrop/...`

## Migration Plan

## Recommended Delivery Strategy

Do **not** try to solve this as one giant “restructure the repo” PR.

Use a 3-track approach:
- `Track A: structure policy` — define and approve the target layout and movement rules
- `Track B: opportunistic adoption` — apply the structure in files already being touched by active sprint tasks
- `Track C: targeted cleanup` — after S1 stabilizes, run focused refactors for areas still scattered

### Phase 1: Folder and group cleanup within the existing target

- No modules yet
- Move files into `Features`, `Audio`, `Windowing`, `Core`, `Shared`
- Update XcodeGen and SwiftPM paths/resources as needed
- Keep behavior unchanged

### Phase 2: Decompose the worst oversized files

Start with:
- `AudioPlayer.swift`
- `SkinManager.swift`
- `VisualizerPipeline.swift`
- `StreamDecodePipeline.swift`

### Phase 3: Normalize naming and ownership

- Eliminate the top-level `Utilities` and `ViewModels` buckets
- Reduce `Models` to true shared/domain models only
- Move feature-local state next to its owning feature

### Phase 4: Extract local packages only where boundaries are already proven

Best candidates after cleanup:
- `Windowing`
- `AudioStreamingCore`
- `SkinEngine`

Do not package everything just to look “clean”. Package the areas that already behave like separate subsystems.

## Recommended Sequencing Against Current Sprints

### Step 0: Ratify the structure rules now

Do this immediately:
- approve the top-level ownership model
- define file-placement rules
- define what counts as `Core`, `Shared`, `Feature`, `Windowing`, and `Audio`

This is low-risk and unblocks consistent future work.

**Status:** Approved.

### Step 1: Apply the rules to S1 tasks only where they already touch files

Use current tasks as adoption points instead of creating a separate churn-heavy refactor:
- `xcode-butterchurn-webcontent-diagnosis`
  - if files must move anyway, consolidate Butterchurn under a `Features/Milkdrop` path
  - if not, defer moves and only document intended ownership
- `audioplayer-decomposition` Phase 4
  - use the target `Audio/Playback` ownership model when extracting transport pieces
- `network-auto-reconnect`
  - keep all new reconnect code under `Audio/Streaming`

### Step 2: After S1, run two focused structure tasks

Recommended follow-on implementation tasks:
- `windowing-structure-consolidation`
  - move generic window infrastructure into `Windowing/`
- `milkdrop-feature-consolidation`
  - move Butterchurn and Milkdrop files plus resources into `Features/Milkdrop/`

These are bounded and much safer than a repo-wide move.

**Status:** Task folders created; not yet sprinted for implementation.

### Step 3: After S2, decompose remaining oversized files

Target files:
- `AudioPlayer.swift`
- `SkinManager.swift`
- `VisualizerPipeline.swift`
- `StreamDecodePipeline.swift`
- `WinampEqualizerWindow.swift`

### Step 4: Re-evaluate package extraction

Only after the folder ownership is stable should local packages be considered.

## Definition of Done For This Architecture Task

- The target structure is documented and approved.
- New work stops adding files to global dumping-ground categories by default.
- At least one feature area and one subsystem area are consolidated using the new pattern.
- Follow-on tasks exist for the remaining high-value migrations.

## Version-Control Recommendation

- Use a dedicated documentation/planning branch and PR for shared `_context` and task-governance updates when possible.
- Do **not** bundle these planning updates into unrelated feature branches.
- For implementation:
  - keep active Sprint S1 fixes in their own task branches
  - keep post-S1 consolidation tasks in their own focused branches
  - avoid a single umbrella “restructure” branch
