# Todo: VisualizerPipeline Decomposition

> **Description:** Checklist for executing the `VisualizerPipeline.swift` decomposition.
> **Updated:** 2026-03-24 (Oracle review v2 — Phase 2a dedup + dead code removal added)

---

## Phase 2a: Intra-File Dedup (before extraction)

- [x] Produce a responsibility map for `VisualizerPipeline.swift`
- [ ] Create branch `refactor/visualizerpipeline-decomposition`
- [ ] Update state.md to IN PROGRESS
- [ ] Extract shared `resample(_:to:)` helper (consolidate getRMSData + getWaveformSamples)
- [ ] Extract `copyBuffer(from:to:count:)` helper in VisualizerSharedBuffer (consolidate 4 memcpy blocks)
- [ ] Remove dead guards in ScratchBuffers.prepare() (lines 255-261)
- [ ] Build + test after dedup (verify no behavior change)

## Phase 2b: Structural Extraction

- [ ] Extract `ButterchurnFrame` + `VisualizerData` to `Audio/VisualizerTypes.swift`
- [ ] Extract `GoertzelCoefficients` + `VisualizerScratchBuffers` to `Audio/VisualizerScratchBuffers.swift` (private -> internal)
- [ ] Extract `VisualizerSharedBuffer` to `Audio/VisualizerSharedBuffer.swift` (private -> internal)
- [ ] Extract `makeTapHandler` to `Audio/VisualizerTapHandler.swift` (static -> free function or enum)
- [ ] Run `xcodegen generate`
- [ ] XcodeBuildMCP build (Thread Sanitizer enabled)
- [ ] XcodeBuildMCP test
- [ ] Oracle review on extraction
- [ ] Manual test: play local file + stream, verify visualizer + Butterchurn
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
