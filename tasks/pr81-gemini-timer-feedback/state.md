# PR 81 Gemini Timer Feedback State

## Status

Implementation in progress on branch `fix/pr81-butterchurn-timer-callbacks`.

## Decision

Both Gemini comments are still real and actionable, but they are low-risk cleanup/performance consistency items rather than regressions.

## Current Blockers

None.

## Progress

- Replaced the cycling timer `Task { @MainActor in ... }` hop with `dispatchPrecondition` plus `MainActor.assumeIsolated`.
- Replaced the track-title timer `Task { @MainActor in ... }` hop with `dispatchPrecondition` plus `MainActor.assumeIsolated`.
- Verified with `xcodebuildmcp macos test --project-path MacAmpApp.xcodeproj --scheme MacAmpApp --derived-data-path /tmp/MacAmpDerivedData-pr81-timers`.

## Next Step

Commit the follow-up and open a small PR. Replying to and resolving PR #81 review threads #2 and #3 remains a separate GitHub write action.
