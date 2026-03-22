# State: Network Auto-Reconnect

> **Purpose:** Implement automatic reconnection for dropped internet radio streams in the unified audio pipeline
> **Created:** 2026-03-14
> **Sprint:** S1 (HIGH)
> **Status:** ✅ COMPLETE — PR #61 merged (2026-03-22)

---

## Current Status

**Phase:** Complete
**Status:** ✅ COMPLETE
**Last Updated:** 2026-03-22
**Branch:** `feature/network-auto-reconnect` (merged)

---

## Final Results

| Metric | Value |
|--------|-------|
| Files modified | 3 (StreamPlayer.swift, StreamDecodePipeline.swift, PlaybackCoordinator.swift) |
| Lines added | ~205 (StreamPlayer), ~73 (StreamDecodePipeline), ~16 (PlaybackCoordinator) |
| Tests | 53 (no new tests — feature is network-dependent; characterization via manual testing) |
| PR reviews | Oracle x2 (strategy + post-impl), CodeRabbit x1, Gemini x1 |
| PR comment findings | 5 (3 ACTIONABLE fixed, 2 NITPICK addressed) |

## Changes

### StreamDecodePipeline.swift
- Added `StreamTerminationReason` enum (8 typed cases) for reconnect policy
- Added `onTermination` callback (fired alongside existing `onStateChange`)
- Added `userRequestedStop` flag to distinguish user stop from server close
- All 5 error paths + stop() + server-close fire typed termination
- HTTP 429 routed to `httpServerError` (reconnectable)

### StreamPlayer.swift
- Added reconnect state machine with exponential backoff (1s→16s cap, max 10 attempts)
- Error classification: transient network errors → reconnect; DNS/decode/client errors → terminal
- Bridge tears down between attempts (fresh ring buffer per attempt)
- `onFormatReady` fires naturally on successful reconnect → bridge re-activates
- Reconnect counter resets after 5s stable playback
- User stop/pause cancels reconnect immediately
- `resume()` restarts stream if pipeline was stopped during connecting/buffering
- `.userStopped` no longer sets blank error string
- ringBuffer cleared on both terminal failure and max-attempts-exhausted paths
- New observable: `isReconnecting`
- Added `StreamTerminationReason.userMessage` extension with user-friendly error messages

### PlaybackCoordinator.swift
- `displayTitle` now shows actual error message instead of hardcoded "buffer 0%"
- Stream display combines station name + track title: "80s80s - Never Gonna Give You Up"

---

## Architecture After Implementation

### Reconnect Flow Diagram

```
User plays internet radio stream
    │
    ▼
PlaybackCoordinator.play(station:)
    ├── streamPlayer.play(station:)
    │       ├── Creates fresh LockFreeRingBuffer
    │       └── pipeline.start(url:, ringBuffer:)
    │               ├── URLSession → ICYFramer → Parser → Decoder → RingBuffer
    │               └── onFormatReady(sampleRate) → PlaybackCoordinator
    │                       └── audioPlayer.activateStreamBridge(ringBuffer:, sampleRate:)
    │
    ▼ (network drops)
URLSession didCompleteWithError
    │
    ▼
StreamDecodePipeline.handleStreamComplete()
    ├── stopInternal() — tears down URLSession, decode context
    ├── setState(.error(message))
    └── onTermination(.networkError(message, code))
            │
            ▼
StreamPlayer.handleTermination(reason)
    ├── isReconnectable(reason)?
    │       ├── YES (transient: connection lost, timeout, server closed, HTTP 5xx/429)
    │       │       │
    │       │       ▼
    │       │   attemptReconnect()
    │       │       ├── reconnectAttempt += 1
    │       │       ├── guard <= 10 max attempts
    │       │       ├── isReconnecting = true, isBuffering = true
    │       │       ├── onStreamTerminated() → bridge tears down
    │       │       ├── Task.sleep(backoff: 1s, 2s, 4s, 8s, 16s cap)
    │       │       ├── Create fresh LockFreeRingBuffer
    │       │       └── pipeline.start(url:, ringBuffer:)
    │       │               │
    │       │               ▼ (success)
    │       │           onFormatReady → bridge re-activates
    │       │           .playing state → 5s stable → reset counter
    │       │
    │       └── NO (terminal: DNS not found, HTTP 4xx, decode error, bad URL)
    │               ├── error = reason.userMessage ("Host not found", etc.)
    │               ├── ringBuffer = nil
    │               └── onStreamTerminated() → bridge tears down (final)
    │
    ▼ (max attempts exhausted)
    error = "Connection lost after 10 attempts"
    onStreamTerminated() → bridge tears down (final)
```

### Error Classification Table

```
┌──────────────────────────────┬──────────────┬────────────────────────────┐
│ Error Type                   │ Reconnect?   │ User Message               │
├──────────────────────────────┼──────────────┼────────────────────────────┤
│ NSURLErrorNetworkConnLost    │ YES          │ "Connection lost"          │
│ NSURLErrorTimedOut           │ YES          │ "Connection timed out"     │
│ NSURLErrorNotConnectedToNet  │ YES          │ "No internet connection"   │
│ Server closed connection     │ YES          │ "Stream ended"             │
│ HTTP 5xx                     │ YES          │ "Server error 503"         │
│ HTTP 429                     │ YES          │ "Server error 429"         │
│ Playlist resolution failed   │ YES          │ "Playlist not found"       │
├──────────────────────────────┼──────────────┼────────────────────────────┤
│ NSURLErrorCannotFindHost     │ NO           │ "Host not found"           │
│ NSURLErrorBadURL             │ NO           │ "Network error"            │
│ HTTP 4xx (except 429)        │ NO           │ "HTTP error 404"           │
│ Decode error                 │ NO           │ "Unsupported audio format" │
│ Invalid HTTP response        │ NO           │ "Invalid server response"  │
│ User stopped                 │ NO           │ (no error shown)           │
└──────────────────────────────┴──────────────┴────────────────────────────┘
```

### Display Title Flow

```
PlaybackCoordinator.displayTitle (for .radioStation source):
    │
    ├── isBuffering? → "Connecting..."
    ├── error? → user-friendly message (e.g., "Host not found")
    ├── ICY metadata? → "Station Name - Track Title"
    └── fallback → station name or "Internet Radio"
```

---

## Docs That Need Updating

| Doc File | Section | What to Update |
|----------|---------|----------------|
| `docs/MACAMP_ARCHITECTURE_GUIDE.md` | §4 Streaming / §9 Error handling | Add reconnect state machine, StreamTerminationReason enum, backoff strategy |
| `docs/IMPLEMENTATION_PATTERNS.md` | Stream bridge lifecycle | Add reconnect flow, error classification pattern, bridge teardown/re-create cycle |

---

## Context

The unified audio pipeline (merged PR #57) handles stream errors gracefully but did not attempt reconnection. Radio listeners lost their stream permanently on network blips. This task adds retry with exponential backoff, typed error classification, and user-friendly error display.

## Architecture Alignment

- All new code scoped under `Audio/Streaming` ownership boundary (StreamPlayer, StreamDecodePipeline)
- PlaybackCoordinator change was display-only (1 computed property)
- No new utility files, no broad restructure
- Per D-STRUCTURE decision: no file moves during S1
