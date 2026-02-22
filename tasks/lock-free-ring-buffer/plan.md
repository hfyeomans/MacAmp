# Plan: Lock-Free Ring Buffer

> **Purpose:** Implementation plan for a lock-free SPSC ring buffer for real-time audio data transfer. Prerequisite for `internet-streaming-volume-control` Phase 2 (Loopback Bridge).
> **Derived from:** `research.md` (this task) + parent task research

---

## Status: PLANNED

---

## Overview

| Metric | Value |
|--------|-------|
| New files | 1 production (`LockFreeRingBuffer.swift`) + 1 test file |
| Dependencies added | `apple/swift-atomics` (1.2.0+) |
| Production files modified | 0 (standalone component) |
| Package.swift modified | Yes (add dependency) |
| Target platforms | macOS 15+ (core), macOS 26+ (`InlineArray`/`Span` optimizations via `@available`) |

---

## Phase 1: Package.swift + Scaffolding

### 1.1 Add swift-atomics dependency

**File:** `Package.swift`

**Note:** This step is coordinated with T6 (swift-testing-modernization) in the same worktree. T6 bumps `swift-tools-version` to 6.2 first, then this step adds the dependency.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    // Existing ZIPFoundation dependency...
    .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),  // NEW
]
```

Add `Atomics` as a dependency of the main target:
```swift
.target(
    name: "MacAmpApp",
    dependencies: [
        // existing deps...
        .product(name: "Atomics", package: "swift-atomics"),
    ]
)
```

### 1.2 Create LockFreeRingBuffer.swift

**New file:** `MacAmpApp/Audio/LockFreeRingBuffer.swift`

---

## Phase 2: Core Implementation

### 2.1 Buffer Structure

```swift
import Atomics

/// Lock-free single-producer single-consumer ring buffer for real-time audio.
/// Writer: MTAudioProcessingTap thread. Reader: AVAudioSourceNode render thread.
/// Both threads are real-time — zero allocations, zero locks, zero ARC on hot path.
final class LockFreeRingBuffer: @unchecked Sendable {
    private let capacity: Int           // Frame count (e.g. 4096)
    private let channelCount: Int       // Typically 2 (stereo)
    private let storage: UnsafeMutableBufferPointer<Float>  // Pre-allocated flat buffer

    private let writeHead = ManagedAtomic<UInt64>(0)
    private let readHead = ManagedAtomic<UInt64>(0)
    private let generation = ManagedAtomic<UInt64>(0)

    // Telemetry (read from main thread for diagnostics)
    private let underrunCount = ManagedAtomic<UInt64>(0)
    private let overrunCount = ManagedAtomic<UInt64>(0)

    init(capacity: Int = 4096, channelCount: Int = 2) { ... }
    deinit { storage.deallocate() }
}
```

**Storage layout:** Flat interleaved `[L0, R0, L1, R1, ...]`. Total allocation: `capacity * channelCount * MemoryLayout<Float>.size` bytes. Pre-allocated once in `init`, never reallocated.

### 2.2 Write Operation (Tap Thread)

```swift
/// Write frames from an AudioBufferList into the ring buffer.
/// Called from MTAudioProcessingTap process callback (real-time thread).
/// Returns number of frames actually written.
func write(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) -> UInt32
```

- Load `writeHead` with `.relaxed`, `readHead` with `.acquiring`
- Calculate available space: `capacity - (writeHead - readHead)`
- If overrun: advance `readHead` to make room, increment `overrunCount`
- Copy frames via `memcpy` (handles wrap-around at buffer boundary)
- Store new `writeHead` with `.releasing`

### 2.3 Read Operation (Render Thread)

```swift
/// Read frames into an AudioBufferList from the ring buffer.
/// Called from AVAudioSourceNode render block (real-time thread).
/// Returns number of frames actually read. Caller fills remaining with silence.
func read(into bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) -> UInt32
```

- Load `readHead` with `.relaxed`, `writeHead` with `.acquiring`
- Calculate available: `writeHead - readHead`
- If underrun (available == 0): increment `underrunCount`, return 0
- Copy frames via `memcpy` (handles wrap-around)
- Store new `readHead` with `.releasing`

### 2.4 Generation ID (Format Changes)

```swift
/// Increment generation to signal format change. Flushes all buffered data.
/// Called from tapPrepare (NOT real-time — this is a setup callback).
func flush(newGeneration: Bool = true)

/// Current generation. Reader checks this to detect format changes.
func currentGeneration() -> UInt64
```

- `flush()`: reset `readHead` and `writeHead` to 0, optionally increment `generation`
- Reader checks `generation` each render cycle; if changed, fills silence and updates its cached generation

### 2.5 Telemetry

```swift
/// Read telemetry counters (safe to call from main thread).
func telemetry() -> (underruns: UInt64, overruns: UInt64)
```

Atomic loads with `.relaxed` ordering — telemetry is best-effort, not synchronization.

---

## Phase 3: Wrap-Around Handling

The critical implementation detail. When `writeHead % capacity + frameCount > capacity`, the write wraps around the buffer boundary. Must split into two `memcpy` calls:

```
Write 300 frames starting at position 3900 in a 4096-frame buffer:
  memcpy 1: copy frames 0-195 into positions 3900-4095 (196 frames)
  memcpy 2: copy frames 196-299 into positions 0-103 (104 frames)
```

Same logic applies to reads. Use `% capacity` indexing on the monotonically increasing head values.

---

## Phase 4: Unit Tests

**New file:** `Tests/MacAmpTests/LockFreeRingBufferTests.swift`

### Test Cases

| Test | What It Verifies |
|------|-----------------|
| `writeAndReadExact` | Write N frames, read N frames — data integrity (values match) |
| `readFromEmpty` | Read from fresh buffer returns 0, no crash |
| `writeOverCapacity` | Write > capacity frames — overrun drops oldest, read pointer advances |
| `wrapAround` | Write past buffer boundary, read correctly across wrap |
| `multipleSmallWrites` | Multiple small writes followed by one large read |
| `generationChange` | Flush with new generation, verify reader detects it |
| `flushClearsData` | After flush, available frames is 0 |
| `telemetryCounters` | Underrun increments on empty read, overrun increments on overflow |
| `stereoDataIntegrity` | Write stereo L/R pattern, read back and verify channel separation |

---

## Phase 5: Concurrent Stress Tests

### Test Cases

| Test | What It Verifies |
|------|-----------------|
| `concurrentWriteRead` | Writer + reader on separate dispatch queues, 10 seconds, verify no crash and data integrity |
| `concurrentWithFormatChange` | Writer + reader + periodic flush (simulating ABR), verify generation ID prevents stale reads |
| `highThroughput` | Writer pushes 48000 frames/sec (1 second of audio per second), reader pulls at same rate, measure drop rate |

All concurrent tests must run with Thread Sanitizer enabled.

---

## Phase 6: Performance Benchmarks

| Benchmark | Target |
|-----------|--------|
| Single write (512 frames) | < 1 microsecond |
| Single read (512 frames) | < 1 microsecond |
| Zero allocations during write/read | Verified via Instruments (Allocations) |
| Memory footprint | `4096 * 2 * 4 = 32,768 bytes` + atomic overhead |

---

## Verification Checklist

- [ ] `swift build` succeeds with swift-atomics dependency
- [ ] All unit tests pass
- [ ] All concurrent stress tests pass with Thread Sanitizer
- [ ] Performance benchmarks meet targets
- [ ] Zero allocations on write/read path (Instruments verification)
- [ ] `swift test` passes in full suite (no regressions)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Wrap-around off-by-one | MEDIUM | HIGH | Extensive unit tests with boundary values |
| Memory ordering incorrect | LOW | HIGH | Standard SPSC acquire-release pattern; stress test with TSan |
| swift-atomics version conflict | LOW | LOW | First-party Apple package, stable API |
| Performance exceeds 1us | LOW | MEDIUM | Pre-allocated storage, memcpy-only hot path |

---

## Out of Scope

- Integration with StreamPlayer/AudioPlayer (that's T5 Phase 2)
- MTAudioProcessingTap implementation (that's T5 Phase 2)
- AVAudioSourceNode render block (that's T5 Phase 2)
- This task produces a **standalone, tested component** that T5 Phase 2 consumes
