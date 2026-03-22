# Plan: VisualizerPipeline Decomposition

> **Description:** Implementation plan for reducing `VisualizerPipeline.swift` and aligning it with the approved `Audio/Visualization` structure.
> **Purpose:** Keep the decomposition bounded, behavior-preserving, and safe for the audio/render path.

---

## Objective

Decompose `MacAmpApp/Audio/VisualizerPipeline.swift` so the top-level pipeline focuses on orchestration while support/data responsibilities move into clearer neighbors.

## Candidate Extraction Boundaries

- shared-buffer and scratch-buffer support types
- Butterchurn frame and FFT-specific support
- UI-facing waveform / RMS / spectrum mapping helpers
- tap-lifecycle coordination versus pure data-processing responsibilities

## Constraints

- Preserve current visualizer and Butterchurn behavior.
- Preserve audio-thread safety and existing confinement assumptions.
- **Decompose in place:** Create new files in `Audio/` (current location). Do not move files to `Audio/Visualization/` — all folder-level consolidation is deferred to the post-S3 Structure Sprint (D-STRUCTURE decision 2026-03-15).
- Avoid introducing churn into unrelated audio files during the split.

## Verification

- Visualizer bars still update correctly during playback
- Butterchurn still receives frame data correctly
- Tap install/remove behavior remains correct
- Project builds after any file moves and XcodeGen regeneration if needed
