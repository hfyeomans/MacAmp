# Todo: Network Auto-Reconnect

> **Purpose:** Track actionable work items for implementing automatic stream reconnection.

---

## Prerequisites
- [x] Research current error handling in StreamPlayer + StreamDecodePipeline
- [x] Oracle review of reconnect strategy (gpt-5.3-codex xhigh)
- [x] Write implementation plan incorporating Oracle findings

## Step 1: Add StreamTerminationReason to StreamDecodePipeline
- [ ] Add `StreamTerminationReason` enum (8 cases)
- [ ] Add `userRequestedStop` flag, set in `stop()`
- [ ] Add `onTermination` callback
- [ ] Modify error paths to fire `onTermination` with typed reason
- [ ] Distinguish server-close from user-stop in URLSession completion
- [ ] Build with XcodeBuildMCP — PASSES
- [ ] Commit

## Step 2: Add Reconnect State Machine to StreamPlayer
- [ ] Add reconnect state: reconnectTask, reconnectAttempt, wasActivelyPlaying, isReconnecting
- [ ] Add `isReconnectable(_:)` classification method
- [ ] Add `attemptReconnect()` with exponential backoff (1s→2s→4s→8s→16s cap, max 10)
- [ ] Add `cancelReconnect()` — cancel task, clear state
- [ ] Add `resetReconnectState()` — reset counter on successful playback (5s threshold)
- [ ] Wire `pipeline.onTermination` to reconnect decision logic
- [ ] Modify `.error`/`.idle` handling: delegate to onTermination, don't fire onStreamTerminated directly
- [ ] Cancel reconnect in `stop()` and `pause()`
- [ ] Set `wasActivelyPlaying = true` when stream enters `.playing` state
- [ ] Build with XcodeBuildMCP — PASSES
- [ ] Test with XcodeBuildMCP — 53+ tests pass
- [ ] Commit

## Step 3: Oracle Review
- [ ] Run `/codex-oracle-workflow` review on changes
- [ ] Address all ACTIONABLE findings
- [ ] Commit fixes

## Step 4: Verification
- [ ] XcodeBuildMCP build with Thread Sanitizer
- [ ] XcodeBuildMCP test with Thread Sanitizer
- [ ] Update state.md with final metrics
- [ ] Update task todo (check off items)
- [ ] Push branch → create PR for user review

## Architecture Constraints
- [x] Keep implementation scoped under `Audio/Streaming` ownership boundary
- [x] Avoid introducing new top-level `Utilities`/`Helpers` files
- [ ] No changes to PlaybackCoordinator (bridge lifecycle works via existing callbacks)
- [ ] No changes to AudioPlayer/AudioEngineController
