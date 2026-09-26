# AirPods Route Gate Validation Plan

1. Validate whether the missing `Engine will reconfigure` log proves the engine notification path did not run.
2. Compare Apple documentation/header semantics against the observed AirPods route-change behavior.
3. Evaluate proposed fixes A, B, and C against current ownership boundaries.
4. Identify implementation constraints for a HAL default-output listener, especially callback threading and Swift concurrency.
5. Recommend threshold and scoping for the watchdog gate.
