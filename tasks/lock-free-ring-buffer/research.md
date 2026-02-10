# Research: Lock-Free Ring Buffer

> **Purpose:** Captures all research findings, reference implementations, and technical analysis for implementing a lock-free circular buffer for real-time audio data transfer between MTAudioProcessingTap and AVAudioSourceNode.

---

## Status: POPULATED FROM PARENT TASK

## Problem Statement

The Loopback Bridge architecture (from `internet-streaming-volume-control` task) requires a lock-free ring buffer to transfer PCM audio data between two real-time threads:
- **Writer:** MTAudioProcessingTap callback (decoding thread) — extracts PCM from AVPlayer
- **Reader:** AVAudioSourceNode render block (audio render thread) — feeds AVAudioEngine

Both threads are real-time audio threads with strict constraints: no allocations, no locks, no ARC, no Swift actor hops.

---

## 1. Requirements (from parent task research)

### Functional Requirements
- Single-writer / single-reader (SPSC) lock-free ring buffer
- Write AudioBufferList data from MTAudioProcessingTap
- Read into AudioBufferList for AVAudioSourceNode
- 4096 frame capacity (~85ms at 48kHz) — initial size, tunable
- Format-aware: stereo float32 (2 channels x 4 bytes/sample)
- Underrun handling: fill remaining frames with silence
- Overrun handling: drop oldest data (advance read pointer)

### Non-Functional Requirements
- Zero allocations on audio thread (all buffers pre-allocated)
- Lock-free using atomic operations (Swift Atomics `ManagedAtomic<UInt64>`)
- No Swift ARC traffic on audio thread
- No Objective-C message sends on audio thread
- Must handle format changes (reinitialize on ABR switches)
- Thread-safe teardown (generation ID / epoch pattern)

### Integration Points
- **Writer context:** C function pointer callback from MTAudioProcessingTap (`tapProcess`)
- **Reader context:** Swift closure from AVAudioSourceNode render block
- **Format source:** `tapPrepare` callback provides `AudioStreamBasicDescription`
- **Lifecycle:** Owned by StreamPlayer, shared via `nonisolated(unsafe)` reference

---

## 2. Technical Design from Parent Task

### Architecture Context
```
AVPlayer → MTAudioProcessingTap (PreEffects) → [Ring Buffer] → AVAudioSourceNode → AVAudioEngine
                    |                                                                      |
              (zero output buffer                                              AVAudioUnitEQ (existing)
               to prevent double-render)                                                   |
                                                                             MainMixerNode → Output
```

### Double-Render Prevention
The tap callback must:
1. Get source audio via `MTAudioProcessingTapGetSourceAudio`
2. Copy PCM data into ring buffer
3. Zero the `bufferListInOut` to silence AVPlayer's direct output

This is the most deterministic approach per Apple QA1783 — PreEffects tap runs before mix effects.

### ABR Format Change Handling
HLS adaptive bitrate switches trigger `tapUnprepare` → `tapPrepare` cycles. The ring buffer must:
1. Be flushed in `tapUnprepare`
2. Be reconfigured for new format in `tapPrepare`
3. Use an atomic generation ID to prevent stale reads across format changes
4. Pre-allocate for worst-case format (48kHz stereo float32)

---

## 3. Swift 6.2 Features Relevant to Ring Buffer

| Feature | Application | macOS Availability |
|---------|------------|-------------------|
| `~Copyable` | Buffer wrapper preventing accidental copies on audio thread | macOS 15+ |
| `nonisolated(unsafe)` | Shared ring buffer reference between tap and render threads | macOS 15+ |
| `InlineArray` (SE-0453) | Stack-allocated scratch buffers in callbacks | **macOS 26+ only** |
| `Span` | Safe pointer access without copying | **macOS 26+ only** |
| `@unchecked Sendable` | Wrapper for tap types (non-Sendable in Swift 6) | macOS 15+ |
| Swift Atomics (`ManagedAtomic`) | Lock-free read/write indices | macOS 15+ (SPM dep) |

### Target: macOS 15+ including macOS 26+
- Core implementation must work on macOS 15+
- `InlineArray`/`Span` optimizations behind `@available(macOS 26, *)` guards

---

## 4. Reference: Lock-Free SPSC Ring Buffer Pattern

### Standard SPSC Design
```
Memory Layout:
[  slot 0  |  slot 1  |  slot 2  |  ...  |  slot N-1  ]
     ^                                          ^
  readIndex                                 writeIndex
  (atomic)                                  (atomic)

Writer: writes at writeIndex, advances atomically
Reader: reads at readIndex, advances atomically
Empty: readIndex == writeIndex
Full: (writeIndex + 1) % capacity == readIndex
```

### Key Operations

**Write (tap thread):**
```swift
func write(_ bufferList: UnsafePointer<AudioBufferList>, frameCount: UInt32) -> Bool {
    let currentWrite = writeIndex.load(ordering: .relaxed)
    let currentRead = readIndex.load(ordering: .acquiring)
    let available = capacity - (currentWrite - currentRead)

    guard available >= frameCount else {
        // Overrun: advance read pointer to make room
        readIndex.store(currentWrite - capacity + frameCount, ordering: .releasing)
        // ... or drop write
        return false
    }

    // Copy frames into buffer at writeIndex % capacity
    // Use memcpy for float32 audio data (no ARC)

    writeIndex.store(currentWrite + frameCount, ordering: .releasing)
    return true
}
```

**Read (render thread):**
```swift
func read(into bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: UInt32) -> UInt32 {
    let currentRead = readIndex.load(ordering: .relaxed)
    let currentWrite = writeIndex.load(ordering: .acquiring)
    let available = currentWrite - currentRead

    let framesToRead = min(available, UInt64(frameCount))

    if framesToRead == 0 {
        // Underrun: fill with silence
        return 0
    }

    // Copy frames from buffer at readIndex % capacity into output
    // Handle wrap-around at buffer boundary

    readIndex.store(currentRead + framesToRead, ordering: .releasing)
    return UInt32(framesToRead)
}
```

### Memory Ordering
- Writer uses `.releasing` store on writeIndex (ensures data writes visible before index update)
- Reader uses `.acquiring` load on writeIndex (ensures it sees data written before index)
- Same pattern reversed for readIndex
- This is the standard acquire-release SPSC pattern

### Generation ID for Format Changes
```swift
let generation = ManagedAtomic<UInt64>(0)

// In tapPrepare (format change):
generation.wrappingIncrement(ordering: .releasing)
// Reset read/write indices

// In source node render:
let currentGen = generation.load(ordering: .acquiring)
if currentGen != lastKnownGeneration {
    // Format changed — skip this render, fill silence
    lastKnownGeneration = currentGen
}
```

---

## 5. Dependency: Swift Atomics Package

**Package:** [apple/swift-atomics](https://github.com/apple/swift-atomics)

```swift
// Package.swift
.package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0")
```

This is a first-party Apple package, well-maintained, and the standard approach for lock-free data structures in Swift.

MacAmp currently has one dependency (ZIPFoundation). This would be the second.

---

## 6. Testing Strategy

### Unit Tests
- Write N frames, read N frames — data integrity
- Write more than capacity — overrun behavior
- Read from empty buffer — underrun (returns 0, no crash)
- Wrap-around: write past buffer end, read correctly across boundary
- Generation ID change: reader detects format change

### Concurrent Tests
- Concurrent writer + reader with dispatch queues simulating audio threads
- Stress test: rapid write/read cycles for 60 seconds
- Format change mid-stream: flush + reinitialize while reader is active

### Performance Tests
- Measure write/read latency (should be < 1 microsecond)
- Verify zero allocations during write/read (Instruments)
- Memory footprint: should be exactly capacity * channelCount * sizeof(Float) + overhead

---

## 7. Sources

- **Parent task:** `tasks/internet-streaming-volume-control/research.md` (sections 8, Oracle reviews)
- **Oracle review (round 2):** Loopback Bridge feasibility analysis, ring buffer sizing
- **Oracle review (round 3):** Muting approach — zero bufferListInOut in tap callback
- **Oracle review (round 4):** Plan review — generation ID for ABR races, readiness guards
- **Gemini research (round 2):** Swift 6.2 ~Copyable and InlineArray for buffer management
- **Apple documentation:** Swift Atomics, AudioBufferList, MTAudioProcessingTap
- **Apple QA1783:** MTAudioProcessingTap pre/post effects semantics
