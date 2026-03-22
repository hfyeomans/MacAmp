# Todo: Network Auto-Reconnect

> **Purpose:** Track actionable work items for implementing automatic stream reconnection.

---

## Prerequisites
- [x] Research current error handling in StreamPlayer + StreamDecodePipeline
- [x] Oracle review of reconnect strategy (gpt-5.3-codex xhigh)
- [x] Write implementation plan incorporating Oracle findings

## Step 1: Add StreamTerminationReason to StreamDecodePipeline — COMPLETE
- [x] Add `StreamTerminationReason` enum (8 cases)
- [x] Add `userRequestedStop` flag, set in `stop()`, reset in `start()`
- [x] Add `onTermination` callback
- [x] Modify all 5 error paths + stop() + server-close to fire `onTermination` with typed reason
- [x] Distinguish server-close from user-stop in URLSession completion
- [x] XcodeBuildMCP build — PASSES
- [x] Commit: `72c3cb6`

## Step 2: Add Reconnect State Machine to StreamPlayer — COMPLETE
- [x] Add reconnect state: reconnectTask, reconnectAttempt, wasActivelyPlaying, isReconnecting, playbackStableTask
- [x] Add `isReconnectable(_:)` classification (4 reconnectable, 4 terminal)
- [x] Add `attemptReconnect()` with exponential backoff (1s→16s cap, max 10)
- [x] Add `cancelReconnect()` — cancel tasks, clear state
- [x] Add `startPlaybackStableTimer()` — reset counter after 5s stable playback
- [x] Wire `pipeline.onTermination` to `handleTermination()` decision logic
- [x] Removed direct `onStreamTerminated` calls from `.error`/`.idle` in onStateChange
- [x] Cancel reconnect in `stop()` and `pause()`
- [x] Reset `wasActivelyPlaying` in `play(station:)` and `stop()`
- [x] Added `StreamTerminationReason.userMessage` extension
- [x] XcodeBuildMCP build + test — 53 tests PASS
- [x] Commit: `ef081c1`

## Step 3: Oracle Review — COMPLETE
- [x] Oracle review (gpt-5.3-codex xhigh) — 3 findings
- [x] [HIGH] Fix pause during reconnect — stop pipeline if mid-connect/buffer, clear isBuffering
- [x] [MEDIUM] Reset wasActivelyPlaying in play(station:) — prevent stale reconnect eligibility
- [x] [LOW] Clear ringBuffer on terminal failure — free memory immediately
- [x] XcodeBuildMCP build + test — 53 tests PASS
- [x] Commit: `b3991e5`

## Step 4: Verification + PR — COMPLETE
- [x] XcodeBuildMCP build with Thread Sanitizer — PASSES
- [x] XcodeBuildMCP test with Thread Sanitizer — 53/53 PASS
- [x] Update state.md
- [x] Update todo.md
- [ ] Push branch → create PR for user review

## Architecture Constraints
- [x] Keep implementation scoped under `Audio/Streaming` ownership boundary
- [x] Avoid introducing new top-level `Utilities`/`Helpers` files
- [ ] No changes to PlaybackCoordinator (bridge lifecycle works via existing callbacks)
- [ ] No changes to AudioPlayer/AudioEngineController
