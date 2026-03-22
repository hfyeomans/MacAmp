# State: Windowing Structure Consolidation

> **Description:** Tracks readiness, boundaries, and sequencing for the windowing consolidation follow-on task.
> **Purpose:** Ensure this cleanup starts only after Sprint S1 and does not collide with higher-priority runtime work.

---

## Status

DEFERRED to post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).

## Scheduling

- ~~Start after Sprint S1 stabilizes.~~ Deferred to post-S3 Structure Sprint.
- All file-move consolidation is now batched into one dedicated pass after S3 completes.
- Decomposition tasks (S1-S3) will make files smaller before this task runs, reducing move risk.
- Do not run in parallel with broad window-behavior feature work unless the overlap is explicitly reviewed.

## Key Decision

- This is a source-ownership cleanup task, not a feature task and not a behavior-redesign task.
