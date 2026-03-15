# State

> **Description:** Status and decision log for the Swift project-structure research and backlog-shaping task.
> **Purpose:** Record what was approved, what was intentionally deferred, and how this work should influence active sprints.

## Status

Research complete. Policy approved. Backlog shaping in progress.

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
- Full architecture improvement over 2-3 follow-on tasks: Medium-Large, but tractable

## Approved Decisions

- The target ownership model is approved.
- This task is the structure policy reference for Sprint S1.
- Two focused follow-on tasks will carry the first real source-tree consolidations after Sprint S1:
  - `windowing-structure-consolidation`
  - `milkdrop-feature-consolidation`
- Large-file decomposition follow-ons remain a post-S2 planning gate, not an immediate restructure track.
