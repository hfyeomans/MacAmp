# State: StreamDecodePipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `StreamDecodePipeline.swift` decomposition task.
> **Updated:** 2026-03-24 (S2 complete, responsibility map done, plan implementation-ready)

---

## Status

READY TO START. Responsibility map and implementation plan complete.

## Scheduling

- S2 dependency resolved: `os-workgroup-integration` merged (PR #66). File is at final shape (713 lines).
- `video-audio-engine-routing` deferred to S3 — no further changes expected.
- Execution order: **Task 1 of 5** (safest, all extractions rated Safe)

## Current Line Count

713 lines (grew from 631 at planning time due to S2 os-workgroup integration)

## Key Decision

- Decompose in place within `Audio/Streaming/` (already at target location)
- Extract 4 new files: DecodeContext, SessionDelegateProxy, PlaylistResolver, StreamFormatHint
- Residual pipeline: ~345 lines
- StreamState/StreamTerminationReason enums stay in pipeline file (too small for own file)
- Flag-but-don't-fix dead code and dedup targets in placeholder.md
