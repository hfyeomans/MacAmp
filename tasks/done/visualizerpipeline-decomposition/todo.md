# Todo: VisualizerPipeline Decomposition

> **Description:** Checklist for executing the `VisualizerPipeline.swift` decomposition.
> **Updated:** 2026-03-24 (Oracle review v2 — Phase 2a dedup + dead code removal added)

---

## Phase 2a: Intra-File Dedup — COMPLETE (PR #71 + PR #72)

- [x] Produce a responsibility map for `VisualizerPipeline.swift`
- [x] Extract shared `resample(_:to:)` helper — done in Phase 2a (line 452)
- [x] Extract `copyFloatBuffer(from:to:count:)` helper in VisualizerSharedBuffer — done in Phase 2a (line 51)
- [x] Remove dead guards in ScratchBuffers.prepare() — done in Phase 2a
- [x] Remove dead `onDataUpdate` callback — done in Phase 2.5

## Phase 2b: Structural Extraction

- [ ] Create branch `refactor/visualizerpipeline-decomposition`
- [ ] Update state.md to IN PROGRESS

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
