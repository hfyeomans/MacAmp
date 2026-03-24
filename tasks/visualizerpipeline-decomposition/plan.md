# Plan: VisualizerPipeline Decomposition

> **Description:** Implementation plan for decomposing `VisualizerPipeline.swift` (699 lines) into focused files.
> **Updated:** 2026-03-24 (Oracle review v2 — added Phase 2a dedup, dead code removal)

---

## Objective

Reduce `VisualizerPipeline.swift` from 699 to ~258 lines by first deduplicating intra-file logic, then extracting support types and the tap handler into neighboring files within `Audio/`.

## Phase 2a: Intra-File Dedup BEFORE Extraction

Per Oracle + Gemini hybrid guidance: deduplicate while code is visible side-by-side.

### Dedup 1: Nearest-Neighbor Resampling Helper

`getRMSData(bands:)` (lines 493-500) and `getWaveformSamples(count:)` (lines 514-521) share identical resampling: `(i * sourceCount) / targetCount`.

**Action:** Extract `private func resample(_ source: [Float], to targetCount: Int) -> [Float]` helper. Both methods call it.

### Dedup 2: tryPublish memcpy Helper

`tryPublish` has 4 nearly identical `withUnsafeBufferPointer`/`memcpy` blocks (lines 58-64, 69-75, 95-102, 105-112).

**Action:** Extract `private func copyBuffer(from source: [Float], to destination: inout [Float], count: Int)` helper inside VisualizerSharedBuffer. All 4 blocks call it.

### Dead Code Removal (during decomposition, per Oracle)

- Remove dead guards in `ScratchBuffers.prepare()` (lines 255-261) — `if rms.count < bars` and `if spectrum.count < bars` can never trigger (pre-allocated at maxBars=20).

## Phase 2b: Structural Extraction

### Step 1: Extract `VisualizerTypes.swift` (Safe, ~22 lines)

Move `ButterchurnFrame` and `VisualizerData` structs (lines 6-27). Sendable value types consumed across file boundaries.

### Step 2: Extract `VisualizerScratchBuffers.swift` (Safe, ~185 lines)

Move `GoertzelCoefficients` + `VisualizerScratchBuffers` together. Change `private` to `internal`.

### Step 3: Extract `VisualizerSharedBuffer.swift` (Moderate, ~115 lines)

Move `VisualizerSharedBuffer` class. Change `private` to `internal`. Includes the new `copyBuffer` helper from dedup.

### Step 4: Extract `VisualizerTapHandler.swift` (Safe, ~102 lines)

Move `makeTapHandler(sharedBuffer:scratch:)`. Convert from `private static` to free function or enum namespace.

### Step 5: Slim residual pipeline

VisualizerPipeline retains: tap lifecycle, data storage/config, data access methods (with shared `resample` helper), level smoothing, poll timer. ~258 lines.

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `Audio/VisualizerTypes.swift` | ~22 | Public Sendable structs |
| `Audio/VisualizerScratchBuffers.swift` | ~185 | Goertzel + scratch buffers (dead guards removed) |
| `Audio/VisualizerSharedBuffer.swift` | ~115 | Thread-safe data bridge (with copyBuffer helper) |
| `Audio/VisualizerTapHandler.swift` | ~102 | Tap callback (nonisolated static) |

**Total new files: 4**
**Residual VisualizerPipeline.swift: ~258 lines**

## Constraints

- Preserve audio-thread safety and confinement assumptions
- Preserve visualizer and Butterchurn rendering behavior
- Decompose in place within `Audio/` — no moves to `Audio/Visualization/` (deferred to post-S3)
- Phase 2a dedup: consolidate intra-file duplicates before splitting
- Remove trivially dead code during decomposition (dead guards)
- Minimum visibility: `internal` only for types that must be visible across files

## Verification

- Visualizer bars update correctly during local + stream playback
- Butterchurn receives frame data correctly (spectrum + waveform)
- Tap install/remove behavior remains correct
- No frame drops or audio glitches during visualization
- `xcodegen generate` + XcodeBuildMCP build + test pass
- Thread Sanitizer clean
