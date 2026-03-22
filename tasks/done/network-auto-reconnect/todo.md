# Todo: Network Auto-Reconnect

> **Purpose:** Track actionable work items for implementing automatic stream reconnection.

---

## Prerequisites — COMPLETE
- [x] Research current error handling in StreamPlayer + StreamDecodePipeline
- [x] Oracle review of reconnect strategy (gpt-5.3-codex xhigh)
- [x] Write implementation plan incorporating Oracle findings

## Step 1: Add StreamTerminationReason to StreamDecodePipeline — COMPLETE
- [x] Add `StreamTerminationReason` enum (8 cases)
- [x] Add `userRequestedStop` flag, set in `stop()`, reset in `start()`
- [x] Add `onTermination` callback
- [x] Modify all error paths to fire `onTermination` with typed reason
- [x] Distinguish server-close from user-stop in URLSession completion
- [x] HTTP 429 routed to `httpServerError` (reconnectable)
- [x] XcodeBuildMCP build — PASSES
- [x] Commit: `72c3cb6`

## Step 2: Add Reconnect State Machine to StreamPlayer — COMPLETE
- [x] Add reconnect state: reconnectTask, reconnectAttempt, wasActivelyPlaying, isReconnecting
- [x] Add `isReconnectable(_:)` with NSURLError code classification
- [x] Add `attemptReconnect()` with exponential backoff (1s→16s cap, max 10)
- [x] Add `cancelReconnect()` — cancel tasks, clear state
- [x] Add `startPlaybackStableTimer()` — reset counter after 5s stable playback
- [x] Wire `pipeline.onTermination` to `handleTermination()` decision logic
- [x] Removed direct `onStreamTerminated` from `.error`/`.idle` in onStateChange
- [x] Cancel reconnect in `stop()` and `pause()`
- [x] Reset `wasActivelyPlaying` in `play(station:)` and `stop()`
- [x] XcodeBuildMCP build + test — 53 tests PASS
- [x] Commit: `ef081c1`

## Step 3: Oracle Review — COMPLETE
- [x] Oracle review (gpt-5.3-codex xhigh) — 3 findings
- [x] [HIGH] Fix pause during reconnect — stop pipeline if mid-connect/buffer, clear isBuffering
- [x] [MEDIUM] Reset wasActivelyPlaying in play(station:)
- [x] [LOW] Clear ringBuffer on terminal failure
- [x] Commit: `b3991e5`

## Step 4: Manual Testing Fixes — COMPLETE
- [x] DNS classification: NSURLErrorCannotFindHost (-1003) now terminal (not reconnectable)
- [x] User-friendly error display: "Host not found" instead of "buffer 0%"
- [x] Combined display: "Station Name - Track Title" in main window
- [x] NSMenu inconsistency warnings logged as pre-existing (shared _context/)
- [x] Commits: `acef86f`, `513aa01`, `7734d7e`, `dcc01e0`

## Step 5: PR Review Fixes (CodeRabbit + Gemini) — COMPLETE
- [x] #0 [gemini] HTTP 429 reconnectable — routed to httpServerError
- [x] #1 [coderabbit] resume() restarts stream if pipeline stopped during connect/buffer
- [x] #2 [coderabbit] .userStopped no longer sets blank error
- [x] #3 [coderabbit] ringBuffer cleared on max-attempts-exhausted path
- [x] #4 [coderabbit] plan.md updated to match shipped enum
- [x] All 5 comments replied + resolved
- [x] Commit: `788f2f7`

## Step 6: PR Merged — COMPLETE
- [x] PR #61 merged by user (2026-03-22)
- [x] Branch deleted
- [x] Task state.md updated with architecture diagrams and doc inventory
- [x] Shared _context/ updated

## Architecture Constraints — VERIFIED
- [x] All code scoped under `Audio/Streaming` ownership boundary
- [x] No new top-level `Utilities`/`Helpers` files
- [x] No changes to AudioPlayer/AudioEngineController
- [x] PlaybackCoordinator change was display-only (1 computed property)
