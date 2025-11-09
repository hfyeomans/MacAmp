## Status

- Research complete (see `research.md`).
- Plan drafted (see `plan.md`).
- Awaiting implementation: no code changes made yet for migration.

## Pending Decisions

1. Which observation mechanism to adopt in `WindowCoordinator` for propagating `AppSettings` changes.
2. Whether we need extended behavior in `BorderlessWindow` (e.g., `acceptsFirstMouse`).

## Next Recommended Steps

1. Implement Day-1 critical fixes: skin auto-load + borderless activation validation.
2. Add `AppSettings` observation pipeline for always-on-top handling.
