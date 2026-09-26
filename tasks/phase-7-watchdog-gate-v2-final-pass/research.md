# Phase 7 Watchdog Gate v2 Final Pass Research

## Scope

- Reviewed `MacAmpApp/Audio/AudioPlayer.swift`
- Reviewed `MacAmpApp/Audio/VideoAudioTap.swift`
- Reviewed `Tests/MacAmpTests/VideoTapFallbackTests.swift`
- Checked adjacent observer and bridge code in `AudioEngineConfigurationObserver.swift`,
  `AudioEngineController.swift`, and existing `VideoAudioTapTests.swift`

## Findings

- The orphan gate fixed in `handleEngineDidReconfigure()` is closed for the
  normal `will -> did` lifecycle and for `cancelPendingReconfigure()` during a
  burst: the finite settle deadline is now armed before the nil snapshot guard.
- Production writers for `videoReconfigureGateUntilHost` are limited to the
  reconfigure will/did handlers. `cancelPendingReconfigure()` no longer owns the
  gate lifecycle.
- The observer already collapses notification bursts into one will/did pair and
  only skips did on observer stop/deinit.
- The watchdog clears `fallbackRequested` only on ticks where
  `mach_absolute_time() < videoReconfigureGateUntilHost`. A fallback flag raised
  after the last gated watchdog tick but before the deadline can still carry
  into the first ungated tick.
- `requiresConverter` correctly prevents fallback flag clearing from enabling
  the bypass write path for converter-required sources.
- `shouldBypassConverter` is conservative for common cases, but does not check
  `mBytesPerPacket` and accepts extra incompatible format flags such as
  big-endian Float32 on little-endian hosts.
- `VideoAudioTap` creates a fresh context in production, but the public `attach`
  method has reuse-aware state reset for channel layout only. If a tap instance
  is reused after a converter-required prepare, `requiresConverter` remains true.

## Verification

- Focused XcodeBuildMCP run passed 9/9:
  `xcodebuildmcp macos test --json '{"projectPath":"MacAmpApp.xcodeproj","scheme":"MacAmpApp","derivedDataPath":"/tmp/MacAmpDerivedData-phase7-watchdog-review","extraArgs":["-skipMacroValidation","-skipPackagePluginValidation","-only-testing:MacAmpTests/VideoTapFallbackTests"],"preferXcodebuild":true}' --output text`
- Focused XcodeBuildMCP TSan run passed 9/9:
  `xcodebuildmcp macos test --json '{"projectPath":"MacAmpApp.xcodeproj","scheme":"MacAmpApp","derivedDataPath":"/tmp/MacAmpDerivedData-phase7-watchdog-review-tsan","extraArgs":["-skipMacroValidation","-skipPackagePluginValidation","-enableThreadSanitizer","YES","-only-testing:MacAmpTests/VideoTapFallbackTests"],"preferXcodebuild":true}' --output text`
