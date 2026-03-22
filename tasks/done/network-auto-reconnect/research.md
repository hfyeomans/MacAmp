# Research: Network Auto-Reconnect

> **Purpose:** Document findings on reconnection strategies, exponential backoff patterns, and audio pipeline integration points.
> **Date:** 2026-03-22
> **Status:** COMPLETE

---

## 1. Current Error Handling

### StreamDecodePipeline (mechanism layer)

Five error paths, all terminal — no retry:

| Error Path | Trigger | Action |
|------------|---------|--------|
| Playlist resolution failure | M3U/PLS fetch fails | `setState(.error("Failed to resolve playlist: ..."))` |
| Decode error | AudioConverter/AudioFileStream failure | `stopInternal()` + `setState(.error(message))` |
| Invalid HTTP response | Non-HTTPURLResponse | `stopInternal()` + `setState(.error("Invalid HTTP response"))` |
| HTTP error status | Status outside 200-299 | `stopInternal()` + `setState(.error("HTTP \(status)"))` |
| URLSession completion with error | Network drop, timeout, etc. | `stopInternal()` + `setState(.error("Stream error: ..."))` |
| Server closes connection (no error) | Natural stream end | `stopInternal()` + `setState(.idle)` |

All errors call `stopInternal()` which tears down the URLSession task and decoder. The pipeline is fully stopped after any error.

### StreamPlayer (bridge layer)

StreamPlayer.setupPipelineCallbacks() handles state changes:

```swift
case .error(let message):
    self.isPlaying = false
    self.isBuffering = false
    self.error = message
    self.onStreamTerminated?()  // → PlaybackCoordinator deactivates bridge
```

No reconnection attempt. Error is surfaced to UI and bridge is torn down.

### PlaybackCoordinator (presentation bridge)

When `onStreamTerminated` fires:
- `audioPlayer.deactivateStreamBridge()` — tears down AVAudioSourceNode graph
- Stream is fully dead — user must manually restart

## 2. Reconnect Integration Point

**StreamPlayer is the right place** for reconnect logic because:
- It owns the pipeline lifecycle (`pipeline.start`/`pipeline.stop`)
- It has access to the current station URL
- It can create fresh ring buffers for each attempt
- PlaybackCoordinator doesn't need to change — `onFormatReady` fires again on successful reconnect

**StreamDecodePipeline should NOT be modified** — it's a mechanism layer. Reconnect is a policy decision that belongs in the bridge layer (StreamPlayer).

## 3. Reconnectable vs Non-Reconnectable Errors

| Error Type | Reconnectable? | Reason |
|------------|---------------|--------|
| Network drop (URLSession error) | YES | Transient — network will likely return |
| Server closed connection (idle) | YES | Server-side disconnect, stream may still be live |
| HTTP 5xx | YES | Server error, may recover |
| HTTP 4xx | NO | Client error (bad URL, auth required) — won't change on retry |
| Decode error | NO | Format issue — same data will fail again |
| Invalid HTTP response | NO | Not a real HTTP server |
| Playlist resolution failure | MAYBE | DNS/network issue → yes; malformed URL → no |
| User-initiated stop | NO | User explicitly stopped |

## 4. Exponential Backoff Strategy

Standard pattern for stream reconnection:

```
Attempt 1: wait 1s
Attempt 2: wait 2s
Attempt 3: wait 4s
Attempt 4: wait 8s
Attempt 5: wait 16s (cap)
... continue at 16s intervals
Max attempts: 10 (or ~2.5 minutes total)
```

**Reset conditions:**
- Successful reconnect (stream plays for > 5 seconds) → reset counter to 0
- User manually restarts → reset counter to 0
- User stops → cancel reconnect entirely

## 5. State Machine for Reconnect

```
                      ┌──────────┐
                      │  Playing  │
                      └────┬─────┘
                           │ error/idle (reconnectable)
                           ▼
                    ┌──────────────┐
                    │ Reconnecting │ ← shows "Reconnecting..." in UI
                    │  (attempt N) │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         wait backoff   user stops   max attempts
              │            │            │
              ▼            ▼            ▼
         retry start    Stopped     Error (final)
              │
     ┌────────┼────────┐
     ▼                  ▼
  success            failure
     │                  │
     ▼                  ▼
  Playing          Reconnecting
  (reset count)    (attempt N+1)
```

## 6. UI Considerations

StreamPlayer already has observable state (`isPlaying`, `isBuffering`, `error`). For reconnect:
- During reconnect: `isBuffering = true`, `error = nil` (or `error = "Reconnecting (attempt 2/10)..."`)
- On final failure: `isBuffering = false`, `error = "Connection lost after 10 attempts"`
- UI already handles these states — main window dims EQ/balance when stream is not playing

## 7. Files to Modify

| File | Change | Lines |
|------|--------|-------|
| `MacAmpApp/Audio/StreamPlayer.swift` | Add reconnect state machine, backoff timer, retry logic | +60-80 |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | Expose error classification (reconnectable vs not) | +10-15 |

**No changes needed to:**
- PlaybackCoordinator — `onFormatReady`/`onStreamTerminated` callbacks work as-is
- AudioPlayer — bridge activation/deactivation unchanged
- AudioEngineController — engine graph management unchanged
- UI views — already observe StreamPlayer state

## 8. Architecture Constraint

Per `swift-project-structure-research` policy:
- New code stays under `Audio/Streaming/` (StreamPlayer is in `Audio/`, StreamDecodePipeline in `Audio/Streaming/`)
- No new utility files
- No broad restructure
