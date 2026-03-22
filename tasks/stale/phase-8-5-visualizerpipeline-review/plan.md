# Plan: VisualizerPipeline Extraction Review

1. Inspect VisualizerPipeline tap lifecycle, Unmanaged usage, and audio-thread processing.
2. Verify AudioPlayer integration points and lifecycle guarantees for tap removal.
3. Check architecture layer boundaries against MACAMP_ARCHITECTURE_GUIDE.md.
4. Assess Swift 6 concurrency and Sendable correctness for tap callback data.
5. Summarize findings with priority and Phase 9 remediation targets.
