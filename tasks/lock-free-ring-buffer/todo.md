# TODO: Lock-Free Ring Buffer

> **Purpose:** Broken-down task checklist derived from the plan.

---

## Status: READY FOR IMPLEMENTATION

## Pre-Flight
- [x] Research complete
- [x] Plan written
- [ ] Combined with T6 in shared worktree (infra/ring-buffer-and-testing)

## Phase 1: Package.swift + Scaffolding
- [ ] T6 bumps swift-tools-version to 6.2 (T6 goes first in shared worktree)
- [ ] Add swift-atomics dependency to Package.swift
- [ ] Add Atomics product to MacAmpApp target dependencies
- [ ] `swift build` succeeds
- [ ] Create `MacAmpApp/Audio/LockFreeRingBuffer.swift`

## Phase 2: Core Implementation
- [ ] Buffer structure with pre-allocated storage
- [ ] `init(capacity:channelCount:)` with storage allocation
- [ ] `deinit` with storage deallocation
- [ ] `write(_:frameCount:)` with acquire-release atomics
- [ ] `read(into:frameCount:)` with acquire-release atomics
- [ ] `flush(newGeneration:)` for format changes
- [ ] `currentGeneration()` for reader detection
- [ ] `telemetry()` for underrun/overrun counters
- [ ] `@unchecked Sendable` conformance

## Phase 3: Wrap-Around Handling
- [ ] Split memcpy for writes crossing buffer boundary
- [ ] Split memcpy for reads crossing buffer boundary
- [ ] Verify with boundary-value unit test

## Phase 4: Unit Tests
- [ ] Create `Tests/MacAmpTests/LockFreeRingBufferTests.swift`
- [ ] `writeAndReadExact` — data integrity
- [ ] `readFromEmpty` — returns 0, no crash
- [ ] `writeOverCapacity` — overrun behavior
- [ ] `wrapAround` — cross-boundary correctness
- [ ] `multipleSmallWrites` — accumulation then bulk read
- [ ] `generationChange` — reader detects format change
- [ ] `flushClearsData` — available frames is 0
- [ ] `telemetryCounters` — underrun/overrun counts
- [ ] `stereoDataIntegrity` — channel separation preserved

## Phase 5: Concurrent Stress Tests
- [ ] `concurrentWriteRead` — 10 seconds, two queues, TSan
- [ ] `concurrentWithFormatChange` — periodic flush during read/write
- [ ] `highThroughput` — 48kHz simulated real-time rate

## Phase 6: Performance Benchmarks
- [ ] Write latency < 1 microsecond (512 frames)
- [ ] Read latency < 1 microsecond (512 frames)
- [ ] Zero allocations on hot path

## Verification
- [ ] `swift build` succeeds
- [ ] `swift test` — all tests pass
- [ ] Thread Sanitizer — no warnings
- [ ] All existing tests still pass (no regressions)
