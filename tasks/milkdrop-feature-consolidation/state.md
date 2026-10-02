# State: Milkdrop Feature Consolidation

Updated: 2026-10-02

SS-4: move the Milkdrop/Butterchurn Swift files and the repo-root `Butterchurn/` resources into `MacAmpApp/Features/Milkdrop/`.

## Status

DEFERRED to the Structure Sprint (D-STRUCTURE). Starts after SS-0's mapping, which itself starts after S3-4 merges.

## Current position

- `MacAmpApp/Features/` does not exist yet. The 7 Swift files sit in 5 folders and the resources at the repo root (`research.md`).
- Nothing blocks the move.

## Decisions

- This task owns the `Features/Milkdrop/` move. Generic window code stays out of it and goes to `Windowing/` (SS-3).
- Behavior stays unchanged, and Butterchurn must load in both Debug and packaged (Release/DMG) builds.
