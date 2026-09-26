# Phase 7 Watchdog Gate v2 Re-review Research

## Files Reviewed
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/Audio/VideoAudioTap.swift`
- `Tests/MacAmpTests/VideoTapFallbackTests.swift`
- Supporting lifecycle context in `AudioEngineConfigurationObserver.swift` and `AudioEngineController.swift`

## Key Findings
- `videoReconfigureGateUntilHost` is now independent of `pendingReconfigureSnapshot`.
- `handleEngineWillReconfigure` opens the gate with `UInt64.max`.
- `handleEngineDidReconfigure` currently returns early when `pendingReconfigureSnapshot` is nil, before converting the gate into a finite settle deadline.
- `cancelPendingReconfigure()` clears the snapshot but intentionally does not clear the gate.
- The fallback flag is used for both transient process/source-pull failures and persistent converter setup failures.

## Verification Attempt
- Tried `xcodebuildmcp swift-package test --package-path . --filter VideoTapFallbackTests --configuration debug`.
- First attempt failed because module caches under `/Users/hank/.cache` were not writable in the sandbox.
- Retried with `CLANG_MODULE_CACHE_PATH` and `SWIFT_MODULE_CACHE_PATH` redirected to `/tmp`; SwiftPM then failed at `sandbox-exec: sandbox_apply: Operation not permitted`.
