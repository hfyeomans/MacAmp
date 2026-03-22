# State: StreamDecodePipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `StreamDecodePipeline.swift` decomposition task.
> **Purpose:** Keep this task clearly positioned as post-S2 / pre-S3 streaming cleanup rather than active sprint churn.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S2 stabilizes.
- Treat this as pre-S3 architecture cleanup, not as part of the lower-priority S3 edge-case queue.
- **S2 dependency:** `os-workgroup-integration` (S2) may add workgroup code to the audio render path that interacts with this pipeline. Decompose after that S2 task lands so the extraction map reflects the final shape.

## Key Decision

- This task owns the structural cleanup of `StreamDecodePipeline.swift`.
- **Decompose in place:** Split the file into smaller pieces within `Audio/Streaming/` (its current location). This file is already in its target directory, so no post-S3 move is needed.
- It should preserve the unified audio pipeline semantics and focus on ownership clarity inside `Audio/Streaming/`.
