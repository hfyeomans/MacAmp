# Plan: VisualizerPipeline Decomposition

> **Description:** Implementation plan for decomposing `VisualizerPipeline.swift` (645 lines) into focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup; Phase 2a items COMPLETE)

---

## Objective

Reduce `VisualizerPipeline.swift` from 645 to ~231 lines by extracting support types and the tap handler into neighboring files within `Audio/`.

## Phase 2a: Intra-File Dedup — COMPLETE (PR #71 + PR #72)

All Phase 2a items completed in prior sprints:
- **resample(_:to:)** helper extracted (line 452) — consolidates getRMSData + getWaveformSamples
- **copyFloatBuffer(from:to:count:)** extracted in VisualizerSharedBuffer (line 51) — consolidates 4 memcpy blocks
- **Dead guards removed** from ScratchBuffers.prepare() — can never trigger
- **onDataUpdate** callback removed (never set)

## Phase 2b: Structural Extraction

### Step 1: Extract `VisualizerTypes.swift` (Safe, ~22 lines)

Move `ButterchurnFrame` and `VisualizerData` structs (lines 6-27). Sendable value types consumed across file boundaries.

### Step 2: Extract `VisualizerScratchBuffers.swift` (Safe, ~181 lines)

Move `GoertzelCoefficients` (lines 130-164) + `VisualizerScratchBuffers` (lines 166-310) together. Change `private` to `internal`.

### Step 3: Extract `VisualizerSharedBuffer.swift` (Moderate, ~100 lines)

Move `VisualizerSharedBuffer` class (lines 29-128). Change `private` to `internal`. Includes the `copyFloatBuffer` helper from Phase 2a dedup.

### Step 4: Extract `VisualizerTapHandler.swift` (Safe, ~101 lines)

Move `makeTapHandler(sharedBuffer:scratch:)` (lines 544-645). Convert from `private static` to free function or enum namespace.

### Step 5: Slim residual pipeline

VisualizerPipeline retains: tap lifecycle, data storage/config, data access methods (with `resample` helper), level smoothing, poll timer. ~231 lines.

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `Audio/VisualizerTypes.swift` | ~22 | Public Sendable structs |
| `Audio/VisualizerScratchBuffers.swift` | ~181 | Goertzel + scratch buffers |
| `Audio/VisualizerSharedBuffer.swift` | ~100 | Thread-safe data bridge (with copyFloatBuffer helper) |
| `Audio/VisualizerTapHandler.swift` | ~101 | Tap callback (nonisolated static) |

**Total new files: 4**
**Residual VisualizerPipeline.swift: ~231 lines**

## Constraints

- Preserve audio-thread safety and confinement assumptions
- Preserve visualizer and Butterchurn rendering behavior
- Decompose in place within `Audio/` — no moves to `Audio/Visualization/` (deferred to post-S3)
- ~~Phase 2a dedup~~ — COMPLETE (resample, copyFloatBuffer, dead guards, onDataUpdate)
- Minimum visibility: `internal` only for types that must be visible across files

## Verification

- Visualizer bars update correctly during local + stream playback
- Butterchurn receives frame data correctly (spectrum + waveform)
- Tap install/remove behavior remains correct
- No frame drops or audio glitches during visualization
- `xcodegen generate` + XcodeBuildMCP build + test pass
- Thread Sanitizer clean
