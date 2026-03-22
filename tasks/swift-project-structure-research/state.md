# State

> **Description:** Status and decision log for the Swift project-structure research and backlog-shaping task.
> **Purpose:** Record what was approved, what was intentionally deferred, and how this work should influence active sprints.

## Status

Research complete. Policy approved. Backlog shaping complete.

## Current Position

- Current repo audit is complete.
- External research is complete.
- Recommended structure has been written into `plan.md`.
- Sprint conflict analysis is complete.
- The task has shifted from pure research into an architecture-governance plan.

## Key Conclusions

- MacAmp’s biggest structural issue is not “too few folders”; it is the wrong top-level boundary.
- `Views`, `Models`, `ViewModels`, and `Utilities` are too broad to remain the primary organization for a growing macOS app.
- The repo should move to feature-first and subsystem-first ownership boundaries before attempting serious modularization.
- Modularization is still worthwhile later, but only after folder-level ownership is cleaned up.

## Likely High-Value First Moves

- Create `Features/`, `Audio/`, `Windowing/`, `Core/`, and `Shared/` ownership boundaries.
- Consolidate Milkdrop / Butterchurn into one feature area.
- Consolidate generic window infrastructure into one `Windowing` subsystem.
- Break up the largest files by responsibility, starting with `AudioPlayer.swift`.

## Recommendation On Timing

- Do not launch a broad repo-wide structure refactor during Sprint S1.
- Use this task as the source of truth for placement rules during S1 implementation work.
- Schedule focused consolidation tasks after the current high-churn S1 items land.

## Difficulty

- Big-bang implementation now: High risk, high churn
- Policy + incremental adoption now: Medium and realistic
- Full architecture improvement over several follow-on tasks: Medium-Large, but tractable

## Approved Decisions

- The target ownership model is approved.
- This task is the structure policy reference for Sprint S1.
- Large-file decomposition follow-ons are now explicitly represented as post-S2 / pre-S3 tasks rather than a vague planning gate.
- `AudioPlayer.swift` remains covered by the existing `audioplayer-decomposition` task; the other large files now have their own task folders.

### D-STRUCTURE: All file-move consolidation deferred to post-S3 Structure Sprint (2026-03-15)

**Decision:** All folder-structure consolidation work (file moves into `Features/`, `Audio/`, `Windowing/`, `Core/`, `Shared/`, `App/`) is deferred to a single dedicated "Structure Sprint" after S3 completes. This replaces the previous plan of weaving consolidation incrementally through post-S1 and post-S2 phases.

**What stays in S1-S3:**

- Placement policy remains active — new files go to the right place, don't make things worse
- Decomposition tasks (split large files) remain in their current sprint slots (S1: AudioPlayer Ph4, post-S2: SkinManager, VisualizerPipeline, StreamDecodePipeline, WinampEqualizerWindow)

**What moves to post-S3:**

- `windowing-structure-consolidation` — deferred from post-S1 to post-S3
- `milkdrop-feature-consolidation` — deferred from post-S1 to post-S3
- Source-to-target mappings for all ownership boundaries
- Creation of remaining consolidation tasks (Features/ for Video/EQ/Playlist, Audio/ boundaries, App/Core/Shared/)

**Rationale:** The incremental weave through 5 sprint phases was over-engineered and already incomplete. File moves touch `project.yml`, imports, bundle resource paths, and test references — inherently a "stop the world" operation that conflicts with active feature branches. Decomposition first makes files smaller and easier to move. One focused post-S3 pass is lower risk and higher coherence than scattered moves interleaved with feature work.
