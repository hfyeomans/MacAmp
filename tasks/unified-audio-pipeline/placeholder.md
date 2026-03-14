# Placeholder: Unified Audio Pipeline

> **Purpose:** Documents intentional placeholder/scaffolding/diagnostic code in the codebase.

---

## Active Diagnostic Code — ✅ ALL REMOVED

All diagnostic code (PCM dump, MP3 dump, sine wave generator, telemetry timer) has been removed.

## Temporary Architectural Code — ✅ ALL RESOLVED

| Item | Status | Resolution |
|------|--------|------------|
| `AudioPlayer.swift` `MainActor.assumeIsolated` bridge | ✅ RESOLVED | Replaced with `isolated deinit` in T8 PR 2 (PR #58) |

## Defensive Fallbacks (acceptable)

| File | Code | Purpose |
|------|------|---------|
| `AudioConverterDecoder.swift:81` | `inputFormat.mSampleRate > 0 ? inputFormat.mSampleRate : 44100.0` | Fallback if stream reports 0 sample rate (shouldn't happen, guards against it) |
