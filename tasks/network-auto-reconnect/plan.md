# Plan: Network Auto-Reconnect

> **Description:** Implementation plan for automatic internet radio stream reconnection with exponential backoff.
> **Oracle reviewed:** 2026-03-22 (gpt-5.3-codex xhigh). Critical findings incorporated.

---

## Overview

| Metric | Value |
|--------|-------|
| Files modified | 2 (StreamPlayer.swift, StreamDecodePipeline.swift) |
| Files created | 0 |
| Estimated lines added | ~100-120 |
| Risk | Medium — stream lifecycle is well-contained |

---

## Design Decisions (Oracle-Informed)

### D1: Error Classification — Typed Enum in Pipeline

Add `StreamTerminationReason` enum to StreamDecodePipeline instead of pattern-matching error strings.

```swift
enum StreamTerminationReason: Sendable {
    case networkError(String, Int)     // URLSession error (message + NSURLError code)
    case serverClosed                  // Server closed connection — reconnectable
    case httpClientError(Int)          // 4xx (except 429) — NOT reconnectable
    case httpServerError(Int)          // 5xx + 429 — reconnectable
    case decodeError(String)           // Format/codec error — NOT reconnectable
    case invalidResponse               // Not HTTP — NOT reconnectable
    case playlistResolutionFailed(String) // M3U/PLS failure — reconnectable (may be DNS)
    case userStopped                   // Explicit stop() — NOT reconnectable
}
```

### D2: Bridge Lifecycle During Reconnect — Tear Down + Re-Create

Per Oracle critical finding: `AVAudioSourceNode` render block captures the ring buffer at activation time. New ring buffer = must tear down and re-activate bridge.

Flow:
1. Stream error → pipeline fires `.error` state
2. StreamPlayer: fire `onStreamTerminated` to tear down bridge
3. Wait backoff interval
4. Create fresh ring buffer
5. Call `pipeline.start(url:, ringBuffer:)`
6. Pipeline fires `onFormatReady` → PlaybackCoordinator re-activates bridge naturally

### D3: Distinguish Server-Close from User-Stop

Currently `.idle` is overloaded. The pipeline's `urlSession(_:task:didCompleteWithError:)` uses:
- `error != nil` → `.error(...)`
- `error == nil && !cancelled` → `.idle` (server closed)
- `error is NSURLErrorCancelled` → no state change (our stop)

Solution: When pipeline stop is user-initiated, set a `userRequestedStop` flag. In completion handler, check flag to distinguish user stop from server close.

### D4: Backoff with Task.sleep + Cancellation

Use `Task` + `Task.sleep(for:)` with cancellation support. Reconnect task is cancelled on user stop/pause.

```swift
// Backoff sequence: 1s, 2s, 4s, 8s, 16s, 16s, 16s, 16s, 16s, 16s (10 max)
let delay = min(16.0, pow(2.0, Double(attempt - 1)))
try await Task.sleep(for: .seconds(delay))
```

### D5: Reconnect Lives in StreamPlayer

StreamPlayer owns the reconnect state machine. StreamDecodePipeline remains mechanism-only. No new files needed.

---

## Implementation Steps

### Step 1: Add StreamTerminationReason to StreamDecodePipeline

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`

- Add `StreamTerminationReason` enum
- Modify `setState(.error(...))` calls to also capture the reason
- Add `onTermination` callback: `(@MainActor @Sendable (StreamTerminationReason) -> Void)?`
- Add `userRequestedStop` flag, set in `stop()`, checked in URLSession completion
- Keep existing `onStateChange` for UI state — `onTermination` is for reconnect policy

### Step 2: Add Reconnect State Machine to StreamPlayer

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

Add private state:

```swift
@ObservationIgnored private var reconnectTask: Task<Void, Never>?
@ObservationIgnored private var reconnectAttempt: Int = 0
@ObservationIgnored private var wasActivelyPlaying: Bool = false
private(set) var isReconnecting: Bool = false
private static let maxReconnectAttempts = 10
private static let maxBackoffSeconds: Double = 16.0
```

Add reconnect methods:

```swift
private func isReconnectable(_ reason: StreamDecodePipeline.StreamTerminationReason) -> Bool
private func attemptReconnect()
private func cancelReconnect()
private func resetReconnectState()
```

### Step 3: Wire Pipeline Termination to Reconnect

In `setupPipelineCallbacks()`:

```swift
pipeline.onTermination = { [weak self] reason in
    guard let self else { return }
    if self.wasActivelyPlaying && self.isReconnectable(reason) {
        self.attemptReconnect()
    } else {
        // Final termination — no reconnect
        self.error = reason.userMessage
        self.onStreamTerminated?()
    }
}
```

Modify existing `.error` and `.idle` handling: don't fire `onStreamTerminated` directly — let `onTermination` handle it.

### Step 4: Implement Backoff Logic

```swift
private func attemptReconnect() {
    reconnectAttempt += 1
    guard reconnectAttempt <= Self.maxReconnectAttempts else {
        // Max attempts exhausted
        isReconnecting = false
        error = "Connection lost after \(Self.maxReconnectAttempts) attempts"
        onStreamTerminated?()
        return
    }

    isReconnecting = true
    isBuffering = true
    error = nil

    // Tear down bridge (critical — new ring buffer needs new bridge)
    onStreamTerminated?()

    let attempt = reconnectAttempt
    reconnectTask = Task { @MainActor [weak self] in
        guard let self else { return }

        let delay = min(Self.maxBackoffSeconds, pow(2.0, Double(attempt - 1)))
        AppLog.info(.audio, "StreamPlayer: Reconnect attempt \(attempt)/\(Self.maxReconnectAttempts) in \(delay)s")

        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            return // Cancelled
        }

        guard !Task.isCancelled, let station = self.currentStation else { return }

        // Fresh ring buffer for new attempt
        let rb = LockFreeRingBuffer(capacity: 32768, channelCount: 2)
        self.ringBuffer = rb
        self.pipeline.start(url: station.streamURL, ringBuffer: rb)
    }
}
```

### Step 5: Reset on Success + Cancel on User Stop

- In pipeline `onStateChange` `.playing` handler: start a 5-second timer. If still playing after 5s, call `resetReconnectState()` (set attempt = 0).
- In `stop()` and `pause()`: call `cancelReconnect()`

### Step 6: Add isReconnectable Classification

```swift
private func isReconnectable(_ reason: StreamDecodePipeline.StreamTerminationReason) -> Bool {
    switch reason {
    case .networkError, .serverClosed, .httpServerError, .httpTooManyRequests, .playlistResolutionFailed:
        return true
    case .httpClientError, .decodeError, .invalidResponse, .userStopped:
        return false
    }
}
```

---

## Verification Plan

### Automated Tests
- Existing 53 tests must pass (no regressions)
- Consider adding StreamPlayer unit test for reconnect state transitions if feasible

### Manual Testing
- [ ] Play internet radio → kill WiFi → verify reconnect attempts (buffering indicator)
- [ ] Restore WiFi → verify stream resumes automatically
- [ ] Kill WiFi → wait for max attempts → verify final error message
- [ ] User stops during reconnect → verify clean stop (no lingering tasks)
- [ ] User pauses during reconnect → verify reconnect cancels
- [ ] Play a stream with bad URL (HTTP 404) → verify NO reconnect attempts
- [ ] Play a stream → server sends malformed data → verify NO reconnect (decode error)

### XcodeBuildMCP
- Build with Thread Sanitizer after each step
- Test with Thread Sanitizer after final step

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Bridge not torn down between attempts | Low | HIGH | Oracle finding addressed — tear down + re-create per attempt |
| Reconnect fires after user stop | Medium | Medium | `userRequestedStop` flag + `cancelReconnect()` in stop/pause |
| Ring buffer leak during reconnect | Low | Medium | Old buffer released when ringBuffer property reassigned |
| Infinite reconnect loop | Low | HIGH | Max 10 attempts + non-reconnectable error classification |
| Backoff task not cancelled | Low | Medium | Cancel in stop/pause + Task.isCancelled check |
