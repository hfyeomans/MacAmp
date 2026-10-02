# A+B Implementation Review Research

## Scope

Reviewed commit `617622b` for the video route-change watchdog changes in:

- `MacAmpApp/Audio/AudioPlayer.swift`
- `Tests/MacAmpTests/VideoTapFallbackTests.swift`

## Evidence

- `AudioPlayer` is `@MainActor`; the HAL listener block runs on a dedicated queue and hops back via `Task { @MainActor [weak self] ... }`.
- The listener is installed once in `init` and removed in isolated `deinit` before `tearDownVideoBridge()` and `engine.shutdown()`.
- `AudioObjectAddPropertyListenerBlock` and `AudioObjectRemovePropertyListenerBlock` are each used once with matching system-object/default-output/global/main-element address values and the stored queue/block pair.
- `armVideoRouteChangeGate(seconds:)` computes a finite mach-time deadline and uses `max(videoReconfigureGateUntilHost, deadline)`.
- `handleEngineWillReconfigure(snapshot:)` still writes `videoReconfigureGateUntilHost = UInt64.max`.
- `handleEngineDidReconfigure()` still writes `videoReconfigureGateUntilHost = mach_absolute_time() &+ settleTicks` directly.

## Findings

- The bounded HAL helper matches the requested local semantics, but the shared gate still has production direct writes outside the helper.
- The direct did-handler write can shorten an earlier HAL-armed 5 second deadline to the 2 second post-engine settle window after an overlapping HAL + engine notification sequence.
- The new helper test covers isolated helper coalescing, but it does not cover interaction with the engine will/did path.
- Comments at the watchdog declaration/test still refer to a `>1 s` stall window after the behavior was raised to 3 seconds.

## Verification

- `xcodebuildmcp --help` and `xcodebuildmcp tools` succeeded.
- `xcodebuildmcp swift-package test --package-path . --filter VideoTapFallbackTests.armVideoRouteChangeGateCoalescesByMax --output text` could not run in this sandbox because SwiftPM/Xcode tried to write under `~/Library` and `~/.cache`.
- Retrying with `/tmp` cache env vars still failed during manifest loading with `sandbox-exec: sandbox_apply: Operation not permitted`.
