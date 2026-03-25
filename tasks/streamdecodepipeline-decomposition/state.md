# State: StreamDecodePipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `StreamDecodePipeline.swift` decomposition task.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## Status

READY TO START. Plans refreshed with current line numbers.

## Scheduling

- S2 dependency resolved: `os-workgroup-integration` merged (PR #66).
- Phase 2.5 cleanup landed (PR #72): `formatHint(forContentType:)` removed, `metaInt` block removed.
- `video-audio-engine-routing` deferred to S3 — no further changes expected.
- Execution order: **Task 1 of 5** (safest, all extractions rated Safe)

## Current Line Count

697 lines (down from 713 — Phase 2.5 removed dead code)

## Key Decision

- Decompose in place within `Audio/Streaming/` (already at target location)
- Extract 3 new files: DecodeContext, SessionDelegateProxy, PlaylistResolver (includes format hint — too small for own file)
- Residual pipeline: ~380 lines
- StreamState/StreamTerminationReason enums stay in pipeline file (too small for own file)
- DecodeContext should adopt `QueueConfined` protocol for consistency with AudioFileStreamParser + AudioConverterDecoder
