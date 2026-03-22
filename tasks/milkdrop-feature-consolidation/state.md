# State: Milkdrop Feature Consolidation

> **Description:** Tracks readiness, boundaries, and sequencing for the Milkdrop / Butterchurn feature consolidation task.
> **Purpose:** Ensure the consolidation happens after the urgent Xcode runtime issue and remains a bounded feature-ownership move.

---

## Status

DEFERRED to post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).

## Scheduling

- ~~Start after Sprint S1 stabilizes.~~ Deferred to post-S3 Structure Sprint.
- All file-move consolidation is now batched into one dedicated pass after S3 completes.
- Decomposition tasks (S1-S3) will make files smaller before this task runs, reducing move risk.
- Prefer to start only after `xcode-butterchurn-webcontent-diagnosis` is merged unless that task already required the same file moves.

## Key Decision

- This task owns the broad `Features/Milkdrop/` move.
- The runtime-fix task should stay scoped unless forced otherwise by implementation.
