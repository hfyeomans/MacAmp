# Plan: Regression Diagnosis

1. Trace local playback call graph from PlaybackCoordinator and direct UI entry points.
2. Verify bridge lifecycle hooks and possible unintended deactivation paths.
3. Trace stream decode + render path and identify throughput/underrun risks.
4. Check first-play/initialization behavior in coordinator/pipeline wiring.
5. Check strict-concurrency/sendable/isolation risk surfaces under Swift 6.2.
6. Produce ranked diagnosis with concrete file:line references and confidence level.
