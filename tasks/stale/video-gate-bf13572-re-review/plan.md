# Video Gate bf13572 Re-review Plan

1. Inspect `617622b..bf13572` diff for `AudioPlayer.swift` and `VideoTapFallbackTests.swift`.
2. Inventory all writers/readers of `videoBurstGateOpen`, `videoReconfigureGateUntilHost`, and `armVideoRouteChangeGate`.
3. Check the requested event-order matrix:
   - HAL -> engine will -> engine did
   - engine will -> HAL -> engine did
   - HAL -> user-intent cancel -> engine did
   - HAL twice with overlapping windows
   - HAL during burst
4. Attempt targeted verification for `VideoTapFallbackTests`.
5. Score the patch and note residual risk.
