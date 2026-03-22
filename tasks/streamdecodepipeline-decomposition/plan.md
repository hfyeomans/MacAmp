# Plan: StreamDecodePipeline Decomposition

> **Description:** Implementation plan for reducing `StreamDecodePipeline.swift` and aligning it with the approved `Audio/Streaming` structure.
> **Purpose:** Keep the decomposition bounded, behavior-preserving, and safe for the unified audio pipeline.

---

## Objective

Decompose `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` so the top-level pipeline file focuses on lifecycle/orchestration while internal support pieces move into clearer neighbors.

## Candidate Extraction Boundaries

- playlist and HTTP-resolution helpers
- decode-context support types and queue-confined helpers
- `URLSession` delegate proxy
- state/lifecycle helpers that can safely leave the main pipeline file without obscuring generation or shutdown behavior

## Constraints

- Preserve current generation-token, shutdown, and callback semantics.
- Do not destabilize the decode queue / audio-thread handoff.
- **Decompose in place:** Create new files in `Audio/Streaming/` (current location, already at target). No folder-level moves needed for this task.
- Do not mix new stream features into this cleanup task.

## Verification

- Stream startup, buffering, pause/resume, and stop still work
- Metadata and format-ready callbacks still fire correctly
- Error paths still surface cleanly
- Project builds after any file moves and XcodeGen regeneration if needed
