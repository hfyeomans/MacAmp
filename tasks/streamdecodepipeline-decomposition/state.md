# State: StreamDecodePipeline Decomposition

> **Description:** Tracks readiness, sequencing, and key boundaries for the `StreamDecodePipeline.swift` decomposition task.
> **Updated:** 2026-03-25 (DEFERRED per responsibility sweep + Principle 5)

---

## Status

DEFERRED. DecodeContext extraction requires `private → internal` (Principle 5: API Surface Minimization). File is 697 lines with one cohesive responsibility (HTTP stream decode lifecycle). Responsibility sweep confirmed architecturally sound (Justified classification).

Same principle applied to cancel SkinManager Step 4 and VisualizerPipeline decomposition.

## Re-evaluation Criteria

Revisit only if:
- File grows past 800 lines from new features
- A genuinely new responsibility is added (not just lifecycle complexity)
- DecodeContext gains external consumers beyond StreamDecodePipeline
