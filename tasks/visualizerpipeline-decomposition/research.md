# Research: VisualizerPipeline Decomposition

> **Description:** Research task for decomposing `VisualizerPipeline.swift` into clearer visualization ownership boundaries.
> **Purpose:** Define a safe post-S2 / pre-S3 plan for reducing `VisualizerPipeline.swift` without destabilizing the active audio path.

---

## Goal

Create a decomposition plan for `MacAmpApp/Audio/VisualizerPipeline.swift` that aligns the file with the target `Audio/Visualization/` ownership boundary.

## Current Context

- `VisualizerPipeline.swift` is currently `699` lines.
- The file combines:
  - shared buffer and scratch-buffer support types
  - Butterchurn frame data and FFT helpers
  - audio-tap lifecycle management
  - UI-facing waveform, RMS, spectrum, and smoothing accessors

## Initial Scope

In scope:
- separating support/data types from the pipeline facade
- identifying which visualization logic is pure data transformation versus runtime lifecycle control
- reducing `VisualizerPipeline.swift` to a clearer coordinator/facade role

Out of scope:
- changing spectrum math or visual behavior
- changing Butterchurn integration behavior
- changing audio-thread semantics beyond what is required for safe extraction

## Target Alignment

- This task should leave the visualization subsystem cleaner inside `Audio/Visualization/`
- Shared support types should only be split when they have a clear owner and safe API boundary

## Status

Planned. Post-S2 / pre-S3 architecture follow-on.
