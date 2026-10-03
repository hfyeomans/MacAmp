# State: Swift Project Structure

Updated: 2026-10-02

Placement-policy reference for the whole repo, and owner of Structure Sprint planning (SS-0).

## Status

- Policy: approved and in force.
- SS-0 (Structure Sprint planning): QUEUED. Starts after S3-4 merges (D-STRUCTURE). Scope and steps in `plan.md`; sprint order in `tasks/_context/plan.md`.

## Decisions in force

- **Target layout:** `MacAmpApp/{App, Core, Shared, Features, Audio, Windowing, Resources}`. No top-level `ViewModels/` or `Utilities/` once the sprint ends. Folder roles are in `plan.md`.
- **Ownership model:** feature-first for user-facing areas, subsystem-first for shared engines, small `Core/` and `Shared/`. Local packages come only after folder ownership is stable (SS-9).
- **D-STRUCTURE (2026-03-15):** all file moves happen in one Structure Sprint after S3-4 merges. Moves touch `project.yml`, imports, bundle resource paths and test references, so they stop the world and conflict with feature branches; one focused pass is lower risk than moves woven into feature work. Decomposition splits files in place before any move.
- **Placement rule (standing):** new files go to their target ownership location. No new top-level files in `Utilities/` or `ViewModels/` without a documented exception.
- Principles 1-7 and the pre-decomposition gate in `tasks/_context/principles.md` govern every refactor in the sprint.

## Placement-rule breaches since 2026-03-15

Every one gets a row in the SS-0 mapping.

| File | Added |
|------|-------|
| `Utilities/MenuActionTarget.swift` | 2026-03-24 (7daa60e) |
| `Utilities/TimeFormatting.swift` | 2026-03-24 (7daa60e) |
| `Utilities/WinampAlertHelper.swift` | 2026-03-24 (bbc2654) |
| `Utilities/WeakBox.swift` | 2026-05-28 (e1f8a4e) |
| `ViewModels/SkinArchiveLoader.swift` | 2026-03-25 (d88fa28, PR #75) |
| `ViewModels/SkinManager+Import.swift` | 2026-03-25 (d88fa28, PR #75) |
| `Models/DockGraph.swift` | 2026-09-27 (47b20de, PR #90) |
| `Models/ScreenClamp.swift` | 2026-09-27 (1c87531, PR #90) |

## Decomposition wave (closed)

- `AudioPlayer.swift`: Phases 1-4 shipped (PR #60, hotfix #62), but the file has regrown to 1,097 lines. Seek extraction is re-evaluated in SS-1 (`tasks/audioplayer-seek-extraction/`).
- `SkinManager.swift`: done in PR #75 (now 441 lines).
- `WinampEqualizerWindow.swift`: selective extraction done in PR #76 (now 365 lines).
- `VisualizerPipeline.swift`: superseded by S3-2 Phase 1 (146a8b4), which extracted `VisualizerFeed` and `VisualizerScratchBuffers` (now 416 lines).
- `StreamDecodePipeline.swift`: deferred; its 800-line trigger fired (825 lines). Re-evaluated in SS-2 (`tasks/streamdecodepipeline-decomposition/`).

## Definition of done

1. Target structure documented and approved: **met**.
2. New work stops adding files to dumping-ground folders: **not met** (see breaches above).
3. At least one feature area and one subsystem consolidated: **not met**.
4. Follow-on tasks exist for every remaining migration: **not met**. Windowing (SS-3) and Milkdrop (SS-4) have folders; Features/ (SS-5), Audio/ (SS-6) and App/Core/Shared (SS-7) do not.

Current measurements are in `research.md`.
