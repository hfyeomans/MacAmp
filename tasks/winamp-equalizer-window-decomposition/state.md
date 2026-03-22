# State: Winamp Equalizer Window Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `WinampEqualizerWindow.swift` decomposition task.
> **Purpose:** Keep this task clearly positioned as post-S2 / pre-S3 equalizer UI cleanup rather than active sprint churn.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S2 stabilizes.
- Treat this as pre-S3 architecture cleanup, not as part of the lower-priority S3 edge-case queue.

## Key Decision

- This task owns the structural cleanup of `WinampEqualizerWindow.swift`.
- **Decompose in place:** Split the file into smaller pieces within `Views/` (its current location). Do not move files to `Features/Equalizer/` as part of this task — all folder-level consolidation is deferred to the post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
- It should reduce the root file without changing equalizer behavior.
