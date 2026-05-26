# Video Gate bf13572 Re-review Research

## Scope

Reviewed commit `bf13572` against `617622b`, focused on the decoupled watchdog gate state in:

- `MacAmpApp/Audio/AudioPlayer.swift`
- `Tests/MacAmpTests/VideoTapFallbackTests.swift`

## Evidence

- `videoBurstGateOpen` production writes:
  - `handleEngineWillReconfigure`: sets `true`
  - `handleEngineDidReconfigure`: sets `false`
- `videoReconfigureGateUntilHost` production writes:
  - `armVideoRouteChangeGate(seconds:)`: max-coalesced finite deadline
- HAL listener path:
  - `handleHALDefaultOutputChange` scopes to active/in-flight video and calls `armVideoRouteChangeGate(seconds: 5.0)`.
- Watchdog read path:
  - Gates on `videoBurstGateOpen || mach_absolute_time() < videoReconfigureGateUntilHost`.

## Findings

- No correctness finding found in the decoupled overlap handling.
- The HAL -> engine will -> engine did shortening bug is fixed by the production state split and covered by the new regression test.
- `cancelPendingReconfigure()` leaving `videoBurstGateOpen` untouched is correct for live players: `AudioPlayer.stop()` does not stop the engine configuration observer, so the delayed `did` still closes the burst flag. The only documented skipped-`did` case is observer shutdown/deinit, where the player is being torn down.
- Remaining issue is documentation-only: comments still reference the old `UInt64.max` burst sentinel in `AudioPlayer.swift` and `VideoTapFallbackTests.swift`.
- Debug seam caveat: `_testHandleEngineDidReconfigure(overrideSettleSeconds:)` directly assigns a compressed deadline after the production handler. It is fine for current tests but should not be used in future HAL-overlap tests because it can bypass max-coalescing.
