# Placeholder Tracking: Winamp Equalizer Window Decomposition

> **Description:** Tracks deferred cleanup, dead code, and deduplication targets discovered during decomposition.
> **Purpose:** Checklist for the future simplification/dedup pass (Phase 2.5, after file moves).

---

## Dead Code (Remove during decomposition)

| Symbol | File:Line | Issue |
|--------|-----------|-------|
| `thumbWidth` | WinampEqualizerWindow.swift:65 | `private let thumbWidth: CGFloat = 11` — declared but never referenced. WinampVerticalSlider takes `thumbHeight` only. **Remove during extraction** (safe, zero callers). |

## Deduplication Targets (For future Phase 2.5 simplification pass)

| Location 1 | Location 2 | Pattern | Suggested Fix |
|---|---|---|---|
| `buildPreampSlider()` | `buildEQSliders()` | Identical WinampVerticalSlider config (same width, height, thumbHeight, sprite names) | Already combined into `EQSlidersLayer` during this decomposition — dedup resolved by extraction |

## Shade Mode Placeholders (Pre-existing, not introduced by this task)

| Symbol | File | Issue |
|--------|------|-------|
| Shade volume/balance sliders | EQShadeLayer.swift | Static placeholder sprites with no interactivity. These are visual-only renders — no drag behavior. Pre-existing limitation, not introduced by decomposition. |
