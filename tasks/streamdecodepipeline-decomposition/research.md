# Research: StreamDecodePipeline Decomposition

> **Description:** Research task for decomposing `StreamDecodePipeline.swift` into clearer streaming ownership boundaries.
> **Purpose:** Define a safe post-S2 / pre-S3 plan for reducing `StreamDecodePipeline.swift` after the unified audio pipeline has stabilized.

---

## Goal

Create a decomposition plan for `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` that aligns the file with the target `Audio/Streaming/` subsystem structure.

## Current Context

- `StreamDecodePipeline.swift` is currently `631` lines.
- The file combines:
  - `@MainActor` stream lifecycle and state management
  - playlist resolution and HTTP response handling
  - decode-queue orchestration
  - nested `DecodeContext` queue-confined machinery
  - `URLSession` delegate proxy behavior

## Initial Scope

In scope:
- clarifying the mechanism-layer ownership inside the streaming subsystem
- splitting clearly separable support types out of the top-level pipeline file
- reducing the file without regressing decode, buffering, or error behavior

Out of scope:
- redesigning stream playback semantics
- adding new streaming features as part of the split
- changing buffering thresholds or decode behavior unless required by extraction

## Target Alignment

- This task should leave stream orchestration inside `Audio/Streaming/`
- Extraction should make the pipeline file easier to reason about without scattering responsibilities across generic utility files

## Status

Planned. Post-S2 / pre-S3 architecture follow-on.
