# Plan

1. Run deterministic `rg` and `ast-grep` scans for target symbols and relevant lifecycle/concurrency contexts.
2. Trace ownership boundaries across `PlaybackCoordinator`, `AudioPlayer`, and `StreamDecodePipeline`.
3. Separate:
   - confirmed duplicate execution paths
   - likely duplicate-path risks
   - intentional repetition / false positives
4. Recommend one safest choke point or single owner per real issue.
5. Return findings only; do not modify production code.
