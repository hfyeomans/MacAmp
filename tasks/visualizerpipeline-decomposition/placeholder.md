# Placeholder Tracking: VisualizerPipeline Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead / Defensive Code (Flag for cleanup in dedup pass)

| Symbol | File:Line | Issue | Status |
|--------|-----------|-------|--------|
| ~~`prepare()` guards~~ | ~~VisualizerScratchBuffers.swift (lines 255-261)~~ | ~~can never trigger~~ | **REMOVED in Phase 2a** |
| ~~`onDataUpdate` callback~~ | ~~VisualizerPipeline.swift~~ | ~~never set~~ | **REMOVED in Phase 2.5** |

## Deduplication Targets (For future Phase 2.5 simplification pass)

| Location 1 | Location 2 | Pattern | Suggested Fix |
|---|---|---|---|
| `getRMSData(bands:)` (was lines 493-500) | `getWaveformSamples(count:)` (was lines 514-521) | Identical nearest-neighbor resampling: `(i * sourceCount) / targetCount` | Extract shared `resample(_:to:)` helper | **COMPLETED in Phase 2a** — `resample(_:to:)` extracted |
| `tryPublish` memcpy block 1 (was lines 58-64) | `tryPublish` memcpy blocks 2-4 (was lines 69-75, 95-102, 105-112) | Nearly identical `withUnsafeBufferPointer`/`memcpy` pattern | Extract `copyBuffer(from:to:count:)` helper | **COMPLETED in Phase 2a** — `copyFloatBuffer(from:to:count:)` extracted |
