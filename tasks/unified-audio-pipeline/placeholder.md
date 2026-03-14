# Placeholder: Unified Audio Pipeline

> **Purpose:** Documents intentional placeholder/scaffolding/diagnostic code in the codebase.
> Items here MUST be removed before the PR is created.

---

## Active Diagnostic Code (REMOVE before PR)

| File | Code | Purpose | Remove When |
|------|------|---------|-------------|
| `StreamDecodePipeline.swift` DecodeContext | `startPCMDump()`, `pcmDumpFile`, `pcmDumpFrames`, PCM write in `handlePackets` | Captures first 10s of decoder PCM to `~/Desktop/stream_pcm_dump.raw` | After sputtering root cause found |
| `StreamDecodePipeline.swift` DecodeContext | `startMP3Dump()`, `mp3DumpFile`, `mp3DumpBytes`, MP3 write in `handleIncomingData` | Captures raw MP3 from ICYFramer to `~/Desktop/stream_raw_audio.mp3` | After sputtering root cause found |
| `StreamDecodePipeline.swift` | `// MARK: - Telemetry (placeholder)` comment | Placeholder for ring buffer telemetry | Replace with real telemetry or remove |

## Temporary Architectural Code (tracked in T8 PR 2)

| File | Code | Purpose | Remove When |
|------|------|---------|-------------|
| `AudioPlayer.swift:185` | `MainActor.assumeIsolated` bridge in deinit | Temporary bridge for `removeTap()` call from nonisolated deinit | T8 PR 2: replaced by `isolated deinit` |
