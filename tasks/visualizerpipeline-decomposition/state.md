# State: VisualizerPipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `VisualizerPipeline.swift` decomposition task.
> **Purpose:** Keep this task clearly positioned as post-S2 / pre-S3 visualization cleanup rather than active sprint churn.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S2 stabilizes.
- Treat this as pre-S3 architecture cleanup, not as part of the lower-priority S3 edge-case queue.
- **S2 dependency:** `video-audio-engine-routing` (S2) may add video visualization support that touches this file. Decompose after that S2 task lands so the extraction map reflects the final shape.

## Key Decision

- This task owns the structural cleanup of `VisualizerPipeline.swift`.
- **Decompose in place:** Split the file into smaller pieces within `Audio/` (its current location). Do not move files to `Audio/Visualization/` as part of this task — all folder-level consolidation is deferred to the post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
- It should preserve the existing runtime behavior and focus on internal ownership boundaries.
