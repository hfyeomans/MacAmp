# Placeholder: Unified Audio Pipeline

> **Purpose:** Documents intentional placeholder/scaffolding/diagnostic code in the codebase.
> Items here MUST be removed before the PR is created.

---

## Active Diagnostic Code — ✅ ALL REMOVED

All diagnostic code (PCM dump, MP3 dump, sine wave generator, telemetry timer) has been removed.

## Temporary Architectural Code (tracked in T8 PR 2)

| File | Code | Purpose | Remove When |
|------|------|---------|-------------|
| `AudioPlayer.swift:185` | `MainActor.assumeIsolated` bridge in deinit | Temporary bridge for `removeTap()` call from nonisolated deinit | T8 PR 2: replaced by `isolated deinit` |

## Defensive Fallbacks (acceptable)

| File | Code | Purpose |
|------|------|---------|
| `AudioConverterDecoder.swift:81` | `inputFormat.mSampleRate > 0 ? inputFormat.mSampleRate : 44100.0` | Fallback if stream reports 0 sample rate (shouldn't happen, guards against it) |
