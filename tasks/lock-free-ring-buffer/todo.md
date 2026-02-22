# TODO: Lock-Free Ring Buffer

> **Purpose:** Broken-down task checklist derived from the plan.

---

## Status: COMPLETE (with deferrals noted)

## Pre-Flight
- [x] Research complete
- [x] Plan written
- [x] Combined with T6 (swift-testing-modernization) in shared worktree `infra-ring-testing`

## Phase 1: Package.swift + Scaffolding
- [x] Bump swift-tools-version to 6.2 (bumped to 6.2, not 6.0 as originally planned)
- [x] Add swift-atomics dependency to Package.swift
- [x] Add Atomics product to MacAmpApp target dependencies
- [x] Xcode build succeeds (`swift build` has unrelated SPM "multiple producers" error — see deferred)
- [x] Create `MacAmpApp/Audio/LockFreeRingBuffer.swift`

## Phase 2: Core Implementation
- [x] Buffer structure with pre-allocated storage
- [x] `init(capacity:channelCount:)` with storage allocation + overflow precondition
- [x] `deinit` with storage deallocation
- [x] `write(_:frameCount:)` with acquire-release atomics
- [x] `read(into:frameCount:)` with acquire-release atomics
- [x] `flush(newGeneration:)` for format changes
- [x] `currentGeneration()` for reader detection
- [x] `telemetry()` for underrun/overrun counters
- [x] `@unchecked Sendable` conformance

## Phase 3: Wrap-Around Handling
- [x] Split memcpy for writes crossing buffer boundary
- [x] Split memcpy for reads crossing buffer boundary
- [x] Verify with boundary-value unit test

## Phase 4: Unit Tests
- [x] Create `Tests/MacAmpTests/LockFreeRingBufferTests.swift`
- [x] `writeAndReadExact` — data integrity
- [x] `readFromEmpty` — returns 0, no crash
- [x] `writeOverCapacity` — overrun behavior
- [x] `oversizedSingleWrite` — single write > capacity keeps newest
- [x] `wrapAround` — cross-boundary correctness
- [x] `multipleSmallWrites` — accumulation then bulk read
- [x] `generationChange` — reader detects format change
- [x] `flushClearsData` — available frames is 0
- [x] `telemetryCounters` — underrun/overrun counts
- [x] `stereoDataIntegrity` — channel separation preserved
- [x] `zeroFrameWrite` — returns 0, no side effects
- [x] `zeroFrameRead` — returns 0, no underrun
- [x] `stereoWrapAround` — L/R pairing preserved across boundary

## Phase 5: Concurrent Stress Tests
- [x] `concurrentWriteRead` — two tasks, TSan clean
- [x] `concurrentWithFormatChange` — periodic flush during read/write
- [x] `highThroughput` — 48kHz simulated real-time rate

## Phase 6: Performance Benchmarks
- [ ] **DEFERRED** Write latency < 1 microsecond (512 frames)
- [ ] **DEFERRED** Read latency < 1 microsecond (512 frames)
- [ ] **DEFERRED** Zero allocations on hot path

## Verification
- [x] Xcode build succeeds
- [ ] **DEFERRED** `swift test` — SPM build has unrelated "multiple producers" error
- [x] Thread Sanitizer — no warnings (serial execution, 40/40 pass)
- [x] All existing tests still pass (no regressions)
- [x] Oracle code review (2 rounds: initial + end-to-end)

---

## Deferred Items Summary

| Item | Reason | Follow-up |
|------|--------|-----------|
| Performance benchmarks (Phase 6) | Not in scope for initial implementation; needs `swift-testing` benchmark support or Instruments profiling | Create separate `ring-buffer-benchmarks` task |
| `swift test` via SPM | Unrelated "multiple producers" build error in SPM graph; Xcode builds fine | Investigate SPM package graph conflict separately |
| AudioBufferList overload tests | Oracle noted missing coverage for `write(_:bufferList:)` and `read(into:bufferList:)` | Add in follow-up test coverage task |
| Overrun-during-active-read stress test | Oracle noted missing TSan-targeted test for concurrent overrun + read | Add in follow-up test coverage task |
