# State: Milkdrop Feature Consolidation

> **Description:** Tracks readiness, boundaries, and sequencing for the Milkdrop / Butterchurn feature consolidation task.
> **Purpose:** Ensure the consolidation happens after the urgent Xcode runtime issue and remains a bounded feature-ownership move.

---

## Status

Planned. Not started.

## Scheduling

- Start after Sprint S1 stabilizes.
- Prefer to start only after `xcode-butterchurn-webcontent-diagnosis` is merged unless that task already required the same file moves.

## Key Decision

- This task owns the broad `Features/Milkdrop/` move.
- The runtime-fix task should stay scoped unless forced otherwise by implementation.
