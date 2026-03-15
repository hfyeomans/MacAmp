# Research: Winamp Equalizer Window Decomposition

> **Description:** Research task for decomposing `WinampEqualizerWindow.swift` into clearer feature-owned UI boundaries.
> **Purpose:** Define a safe post-S2 / pre-S3 plan for reducing the equalizer window file without mixing UI cleanup into active feature work.

---

## Goal

Create a decomposition plan for `MacAmpApp/Views/WinampEqualizerWindow.swift` that aligns the file with the target feature-first structure.

## Current Context

- `WinampEqualizerWindow.swift` is currently `626` lines.
- The file combines:
  - the root equalizer window view
  - titlebar/control-button construction
  - slider and curve UI
  - shade-mode rendering
  - vertical slider support view
  - preset picker UI

## Initial Scope

In scope:
- separating reusable equalizer UI pieces from the root window shell
- clarifying which pieces belong under a future `Features/Equalizer/` area
- reducing the root file without changing the window's visible behavior

Out of scope:
- redesigning equalizer UX
- changing EQ behavior or preset semantics
- changing audio engine behavior as part of the UI split

## Target Alignment

- This task should move equalizer UI ownership toward a feature-first structure
- Reusable equalizer-specific subviews should live near the equalizer feature, not in generic global UI buckets

## Status

Planned. Post-S2 / pre-S3 architecture follow-on.
