# Placeholders: StreamDecodePipeline Decomposition

Updated: 2026-10-02

Duplication and cleanup targets flagged for this task (flag, don't fix).

## Duplication to watch

| Item | Note |
|---|---|
| `SessionDelegateProxy` | S3-3 adds a second fileprivate copy in `HLSSegmentFeeder`. Two copies; share only when a third appears (Principle 4). |

## Cleanup targets

| Target | Fix and condition |
|---|---|
| `DecodeContext` doc comment (:524) says it uses "the same pattern as VisualizerScratchBuffers in VisualizerPipeline.swift" | `VisualizerScratchBuffers` moved to its own file in `146a8b4` and now follows the render-thread contract. Replace the comment when `plan.md` step 3 writes the contract header. |

## Intentional non-duplication

| Pattern | Why it is not a duplication |
|---|---|
| `extractICYMetaInt` plus `configureFramer` | Called once, from the `onResponse` proxy callback on the delegate queue (:199-200), so the framer is configured before data arrives. `handleHTTPResponse` deliberately does not configure it again; the comment at :337-340 explains why. |
