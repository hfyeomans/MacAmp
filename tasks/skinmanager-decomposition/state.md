# State: SkinManager Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `SkinManager.swift` decomposition task.
> **Purpose:** Keep this task clearly positioned as post-S2 / pre-S3 architecture work rather than immediate sprint churn.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S2 stabilizes.
- Treat this as pre-S3 architecture cleanup, not as part of the lower-priority S3 edge-case queue.

## Key Decision

- This task owns the decomposition of `SkinManager.swift`.
- **Decompose in place:** Split the file into smaller pieces within `ViewModels/` (its current location). Do not move files to `Features/Skins/` as part of this task — all folder-level consolidation is deferred to the post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
- The target `Features/Skins/` ownership model remains the long-term goal, but the actual file moves happen in a separate, dedicated pass after all sprints complete.
