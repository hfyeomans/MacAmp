# State: StreamDecodePipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `StreamDecodePipeline.swift` decomposition task.
> **Purpose:** Keep this task clearly positioned as post-S2 / pre-S3 streaming cleanup rather than active sprint churn.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S2 stabilizes.
- Treat this as pre-S3 architecture cleanup, not as part of the lower-priority S3 edge-case queue.

## Key Decision

- This task owns the structural cleanup of `StreamDecodePipeline.swift`.
- It should preserve the unified audio pipeline semantics and focus on ownership clarity inside `Audio/Streaming/`.
