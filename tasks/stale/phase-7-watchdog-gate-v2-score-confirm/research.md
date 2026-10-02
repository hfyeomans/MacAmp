# Phase 7 Watchdog Gate V2 Score Confirm Research

## Scope

- Reviewed commit `9825b4f` against:
  - `MacAmpApp/Audio/AudioPlayer.swift`
  - `MacAmpApp/Audio/VideoAudioTap.swift`
  - `Tests/MacAmpTests/VideoTapFallbackTests.swift`

## Findings

- `startVideoTapWatchdog(for:)` now tracks `wasReconfigureGated`.
- The watchdog clears `fallbackRequested` during gated ticks and performs one additional post-gate cleanup tick before normal fallback checks resume.
- `shouldBypassConverter` now requires exact `kAudioFormatFlagsNativeFloatPacked` flags and checks `mBytesPerPacket`.
- `tapPrepare` resets `requiresConverter` and `fallbackRequested` before the converter bypass early return.
- New test `watchdogClearsLateGateEdgeFallback` covers late-edge fallback absorption and proves a fresh later failure still demotes.

## Duplicate-Path Sweep

- Used duplicate-path inventory for:
  - `startVideoTapWatchdog`
  - `engageVideoTapFallback`
  - `clearFallbackRequested`
  - `requiresConverter`
  - `shouldBypassConverter`
  - `videoReconfigureGateUntilHost`
- Result: no competing watchdog implementation or split owner found.
- `clearFallbackRequested()` appears only in the gated tick and the one-shot post-gate cleanup branch.
- `shouldBypassConverter` has one production call site.

## Verification

- `xcodebuildmcp macos test --project-path MacAmpApp.xcodeproj --scheme MacAmpApp --derived-data-path /Users/hank/dev/src/MacAmp/.build/derived-data-codex`
  - Passed: 108/108.
- Initial TSan full-suite run failed once with `cancelMidBurstThenDidArmsSettleAndAllowsFreshFailure` and a ThreadSanitizer race warning.
- Isolated TSan reruns of that test passed twice.
- Repeat full TSan run passed 108/108:
  - `xcodebuildmcp macos test --json '{"projectPath":"MacAmpApp.xcodeproj","scheme":"MacAmpApp","derivedDataPath":"/Users/hank/dev/src/MacAmp/.build/derived-data-tsan","extraArgs":["-skipMacroValidation","-skipPackagePluginValidation","-enableThreadSanitizer","YES"],"preferXcodebuild":true}' --output text`
