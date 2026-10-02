# State: Windowing Structure Consolidation

Updated: 2026-10-02

SS-3: move generic window infrastructure into `MacAmpApp/Windowing/` and land the #78 and amp-review follow-ups in the same pass.

## Status

DEFERRED to the Structure Sprint (D-STRUCTURE). Starts after SS-0's mapping, which itself starts after S3-4 merges.

## Current position

- `MacAmpApp/Windowing/` does not exist yet; the candidate files are spread across `Windows/`, `Utilities/`, `ViewModels/` and `Models/` (`research.md`).
- #78 and the sleep/wake off-screen fix landed in PR #90 (88ba342) under D-WIN78. No other window feature work is queued before the sprint.
- The follow-ups deferred from #78 and the 2026-10-02 amp review wait in `todo.md`. The docs fixes among them may land any time.

## Decisions

- This is a source-ownership move. Behavior changes are limited to the follow-ups listed in `plan.md`.
- Do not run it alongside feature branches that touch window code unless the overlap is reviewed.
- The moves must preserve the window invariants in `docs/MULTI_WINDOW_ARCHITECTURE.md` §Docking, Recovery, Minimize & Windowshade: `DockGraph` is the single docking model, `WindowScreenGuard` owns sleep/wake/display recovery, and group minimize lives in `WindowVisibilityController`.
