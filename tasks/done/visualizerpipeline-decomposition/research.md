# Research: VisualizerPipeline Decomposition

> **Description:** Responsibility map for decomposing `VisualizerPipeline.swift` into smaller, focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## File Overview

**File:** `MacAmpApp/Audio/VisualizerPipeline.swift`
**Lines:** 645 (down from 699 — Phase 2a/2.5 extracted resample/copyFloatBuffer helpers, removed dead guards + onDataUpdate)
**Contains:** 2 public structs, 1 private class (shared buffer), 1 private struct (Goertzel), 1 private class (scratch buffers), 1 public class (pipeline)

## Imports

| Import | Usage |
|--------|-------|
| `AVFoundation` | `AVAudioMixerNode`, `AVAudioPCMBuffer`, `AVAudioTime` |
| `Accelerate` | vDSP functions for FFT, Hann window, buffer ops |
| `Observation` | `@Observable`, `@ObservationIgnored` |
| `os` | `os_unfair_lock` |

---

## Section-by-Section Responsibility Map

### Section 1: Data Transfer Types (lines 6-27) — 22 lines
- **Responsibility:** Public value types for cross-boundary data transfer
- **Key symbols:** `ButterchurnFrame` (Sendable struct), `VisualizerData` (Sendable struct)
- **Internal coupling:** Produced by SharedBuffer.consume() and Pipeline.snapshotButterchurnFrame()
- **External coupling:** Consumed by ButterchurnBridge, AudioPlayer
- **Extractability:** **Safe** — pure value types

### Section 2: Lock-Free Shared Buffer (lines 29-128) — 100 lines
- **Responsibility:** Thread-safe audio-to-main data transfer using `os_unfair_lock`
- **Key symbols:** `VisualizerSharedBuffer` (private final class, @unchecked Sendable), `tryPublish(from:oscilloscopeSamples:validFrameCount:)`, `consume()`
- **Threading:** `tryPublish` on audio render thread (non-blocking trylock), `consume` on main thread (blocking lock)
- **Internal coupling:** Reads from VisualizerScratchBuffers via tryPublish parameter; returns VisualizerData
- **Extractability:** **Moderate** — currently `private`, needs `internal` if extracted

### Section 3: Goertzel Coefficients (lines 130-164) — 35 lines
- **Responsibility:** Pre-computed frequency analysis coefficients for spectrum bars
- **Key symbols:** `GoertzelCoefficients` (private struct), `updateIfNeeded(bars:sampleRate:)`
- **Internal coupling:** Owned by VisualizerScratchBuffers.goertzel
- **Extractability:** **Safe** — pure computation

### Section 4: Scratch Buffers (lines 166-310) — 145 lines
- **Responsibility:** Pre-allocated audio-thread working memory and Butterchurn FFT processing
- **Key symbols:** `VisualizerScratchBuffers` (private final class, @unchecked Sendable), `prepare(frameCount:bars:sampleRate:)`, `processButterchurnFFT(samples:validCount:)`, buffer accessor closures
- **Threading:** All called exclusively on audio render thread (confined to tap closure)
- **Internal coupling:** Contains GoertzelCoefficients; read by SharedBuffer.tryPublish
- **Phase 2.5:** Dead guards removed from `prepare()` (can never trigger)
- **Extractability:** **Safe** — self-contained buffer management

### Section 5: Pipeline Tap Lifecycle (lines 312-437) — 126 lines
- **Responsibility:** Tap installation/removal on AVAudioEngine mixer, poll timer management
- **Key symbols:** `VisualizerPipeline` class declaration, `installTap(on:)`, `removeTap()`, `clearData()`, `isTapInstalled`, `startPollTimer()`, `pollVisualizerData()`
- **Internal coupling:** Creates ScratchBuffers, calls makeTapHandler, stores SharedBuffer, calls updateLevels
- **External coupling:** AVAudioMixerNode, called by AudioEngineController
- **Extractability:** **Moderate** — glue between audio thread and main thread; stays as pipeline core

### Section 6a: Data Storage and Configuration (lines 326-366) — 41 lines
- **Responsibility:** Cached visualizer data, configuration properties
- **Key symbols:** `peaks`, `latestRMS/Spectrum/Waveform`, `butterchurnSpectrum/Waveform`, `smoothing`, `peakFalloff`, `useSpectrum`, `levels`
- **Phase 2.5:** `onDataUpdate` callback removed (never set)
- **Extractability:** **Risky** — shared state tying everything together, stays with pipeline

### Section 6b: Data Access Methods (lines 438-507) — 70 lines
- **Responsibility:** Public query API for visualizer consumers
- **Key symbols:** `resample(_:to:)`, `snapshotButterchurnFrame()`, `getRMSData(bands:)`, `getWaveformSamples(count:)`, `getFrequencyData(bands:isPlaying:)`
- **Phase 2a:** Near-duplicate resampling consolidated into shared `resample(_:to:)` helper (line 452)
- **External coupling:** Called via AudioPlayer facade by ButterchurnBridge, VisualizerView
- **Extractability:** **Safe** — pure query methods

### Section 6c: Level Smoothing (lines 509-542) — 34 lines
- **Responsibility:** Temporal smoothing and peak decay for raw data
- **Key symbols:** `updateLevels(with:useSpectrum:)`
- **Internal coupling:** Heavily reads/writes pipeline state
- **Extractability:** **Moderate**

### Section 7: Tap Handler (lines 544-645) — 101 lines
- **Responsibility:** Audio render thread callback — mono mixing, RMS, Goertzel spectrum, Butterchurn FFT, publish
- **Key symbols:** `makeTapHandler(sharedBuffer:scratch:)` — `private nonisolated static`
- **Threading:** Already static and nonisolated. Closure is @Sendable. Zero allocations.
- **Internal coupling:** Uses ScratchBuffers and SharedBuffer via parameters
- **swiftlint:** Disabled for `function_body_length` and `closure_body_length`
- **Extractability:** **Safe** — most natural extraction candidate

---

## Concurrency / Threading Summary

| Context | Mechanism | Symbols |
|---------|-----------|---------|
| Audio render thread | `nonisolated static` + `@Sendable` | makeTapHandler, tap closure, ScratchBuffers (confined), SharedBuffer.tryPublish |
| Main thread | `@MainActor` + Timer | All Pipeline instance methods, SharedBuffer.consume |
| Lock | `os_unfair_lock` (trylock audio, lock main) | VisualizerSharedBuffer |
| Sendable | `@unchecked Sendable` | SharedBuffer, ScratchBuffers |
| Sendable | value types | ButterchurnFrame, VisualizerData |

## Dependency Graph

```
VisualizerTapHandler (S7)
  |-- reads --> ScratchBuffers (S3+S4)
  |               |-- contains --> GoertzelCoefficients (S3)
  |-- writes --> SharedBuffer (S2)
                   |-- produces --> VisualizerData (S1)

VisualizerPipeline (S5+S6)
  |-- owns --> SharedBuffer (S2)
  |-- creates --> ScratchBuffers (S3+S4)
  |-- calls --> makeTapHandler (S7)
  |-- consumes --> VisualizerData (S1)
  |-- produces --> ButterchurnFrame (S1)
```

---

## Recommended Extraction Units

| # | Target File | Sections | Est. Lines | Risk |
|---|-------------|----------|------------|------|
| 1 | `VisualizerTypes.swift` | Section 1 (data types) | ~22 | Safe |
| 2 | `VisualizerSharedBuffer.swift` | Section 2 (shared buffer) | ~100 | Moderate |
| 3 | `VisualizerScratchBuffers.swift` | Sections 3+4 (coefficients + scratch) | ~181 | Safe |
| 4 | `VisualizerTapHandler.swift` | Section 7 (tap handler) | ~101 | Safe |
| 5 | `VisualizerPipeline.swift` (slimmed) | Sections 5+6 (pipeline class) | ~231 | Core — stays |

**Visibility changes required:** SharedBuffer, ScratchBuffers, GoertzelCoefficients change from `private` to `internal`.

## Near-Duplicate Code — RESOLVED in Phase 2a

- ~~`getRMSData` and `getWaveformSamples` share identical resampling~~ → `resample(_:to:)` helper extracted
- ~~`tryPublish` has 4 nearly identical memcpy blocks~~ → `copyFloatBuffer(from:to:count:)` extracted

## Dead Code — RESOLVED in Phase 2.5

- ~~Lines 255-261: dead guards in `prepare()`~~ → removed
- ~~`onDataUpdate` callback~~ → removed (never set)
