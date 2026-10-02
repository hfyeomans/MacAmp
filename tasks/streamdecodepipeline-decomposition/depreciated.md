# Depreciated: StreamDecodePipeline Decomposition

Updated: 2026-10-02

Superseded plans and any code this task removes.

## Superseded plan targets

- **697 down to ~380 lines** (DecodeContext ~199, SessionDelegateProxy ~34, PlaylistResolver ~87). Measured before `c6a5b23` and before S3-3/S3-4; replaced by the re-baseline in `plan.md` step 1.
- **Separate `StreamFormatHint.swift`**: dropped as too small for its own file. Whether the format hint folds into `PlaylistResolver.swift`, and where S3-4's fileprivate `StreamFormatHint` enum lives, is decided in `plan.md` step 2.

## Removed code

None. Task not started.
