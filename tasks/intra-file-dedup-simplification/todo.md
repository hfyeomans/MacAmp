# Todo: Intra-File Deduplication & Simplification

> **Description:** Checklist for the first-pass cleanup before structural extraction.
> **Purpose:** Each item is behavior-preserving. Checked off as completed.

---

- [x] Create branch `refactor/intra-file-dedup-simplification`
- [x] Update state.md to IN PROGRESS

## SkinManager.swift — Dedup + Dead Code

- [x] Add characterization test for playlist style defaults (default skin path vs custom skin path)
- [x] Investigate color inconsistency: which defaults match Winamp 2.x?
- [x] Extract shared `parsePlaylistStyle(from:)` private static method
- [x] Resolve color defaults — created `PlaylistStyle.winampDefault` with correct Winamp 2.x colors
- [x] Extract shared `parseVisualizerColors(from:fallback:)` private static method
- [x] Preserve distinct fallbacks: default skin gets 24 greens, custom skins get empty array
- [x] Remove dead `import Combine`
- [x] Replace 3 for-in merge loops with `.merge()` (found by duplicate-code-investigator)
- [x] Remove duplicated MARK header (found by duplicate-code-investigator)
- [x] Build + test (verify no behavior change in skin loading)

## VisualizerPipeline.swift — Dedup + Dead Code

- [x] Extract shared `resample(_:to:)` private method (consolidate getRMSData + getWaveformSamples)
- [x] Extract `copyFloatBuffer(from:to:count:)` private method (consolidate 4 memcpy blocks)
- [x] Add bounds clamp to copyFloatBuffer explicit count path (simplify review)
- [x] Remove dead guards in ScratchBuffers.prepare()
- [x] Build + test (verify no behavior change in visualizer)

## StreamDecodePipeline.swift — Dead Code Only

- [x] Remove dead `formatHint(forContentType:)` function (zero callers)
- [x] Build + test

## WinampEqualizerWindow.swift — Dead Code Only

- [x] Remove dead `thumbWidth` constant (zero callers)
- [x] Extract `normalizedValue` computed property (found by duplicate-code-investigator)
- [x] Build + test

## Final Verification

- [x] XcodeBuildMCP build (Thread Sanitizer enabled) — PASS
- [x] XcodeBuildMCP test — 55/55 pass
- [x] Duplicate-code-investigator scan — 3 additional items fixed, rest deferred to Phase 2c
- [x] Simplify review — 2 nits fixed (unused param, bounds clamp)
- [x] Oracle review — caught viscolor fallback regression, fixed
- [ ] Push branch -> create PR for user review
- [ ] Update state.md and shared _context/ on completion
- [ ] NOTE: After merge, refresh all 5 decomposition plan line numbers
