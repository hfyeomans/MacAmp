# Research: os_workgroup Integration

> **Purpose:** Research Apple os_workgroup API usage for real-time audio threads on Apple Silicon, preventing audio glitches under CPU pressure.

**Status:** Complete (2026-03-22). Revised after Oracle review (4/10 on initial plan).

---

## Problem Statement

The `AVAudioSourceNode` render block runs on the Core Audio IO thread — inherently in the audio workgroup. The **decode thread** (`StreamDecodePipeline.decodeQueue`) that feeds PCM into the `LockFreeRingBuffer` is a regular `DispatchQueue` with `.userInitiated` QoS. Under CPU pressure on Apple Silicon, the kernel can deprioritize this thread, causing ring buffer underruns and audible glitches.

## API Analysis

### `os_workgroup_join` / `os_workgroup_leave` (macOS 11.0+)

- **Thread-scoped:** Joins the *current thread*, not the queue. The token must be used to leave from the same thread.
- **GCD implication:** A serial `DispatchQueue` can run blocks on different backing threads. Join-once-per-session is **unsafe** — you'd need join/leave per dispatch block, which is expensive and fragile.

### `AUAudioUnit.osWorkgroup` — Swift Unavailable

The Oracle confirmed: `AUAudioUnit.osWorkgroup` is explicitly marked `__attribute__((swift_private))` in the SDK header (`AUAudioUnit.h:1326`). It **cannot be called from Swift directly**. An ObjC bridging shim is required:

```objc
// AUAudioUnitWorkgroupShim.h
#import <AudioToolbox/AudioToolbox.h>
#import <os/workgroup.h>

os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit);
```

```objc
// AUAudioUnitWorkgroupShim.m
#import "AUAudioUnitWorkgroupShim.h"

os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit) {
    return unit.osWorkgroup;
}
```

### Recommended Approach: `DispatchWorkloop` (macOS 11.0+)

Apple's `dispatch/workloop.h` provides `dispatch_workloop_set_os_workgroup()` which automatically joins/leaves the workgroup for each work item executed on the workloop. This avoids the thread-hopping bug entirely:

```c
// From dispatch/workloop.h:143-145
// The worker thread will be a member of the specified os_workgroup
// while executing work items submitted to this workloop.
```

**However:** `DispatchWorkloop` is not publicly exposed in Swift's libdispatch overlay. The C API `dispatch_workloop_create` / `dispatch_workloop_set_os_workgroup` would need to be called via a C shim as well.

### Alternative: Dedicated Thread

A simpler approach that avoids all GCD thread-reuse issues:

1. Create a dedicated `Thread` for decode work
2. Call `os_workgroup_join` once when the thread starts
3. Call `os_workgroup_leave` when the thread ends
4. Use the thread's run loop or a semaphore to dispatch work

**Trade-off:** More manual lifecycle management, but thread identity is stable.

### Chosen Approach: Per-Block Join/Leave on Existing Queue

After weighing options:
- `DispatchWorkloop` requires additional C shims and is a more invasive change
- Dedicated thread requires rewriting the decode queue dispatch model
- **Per-block join/leave** is the simplest correct approach for the existing architecture

The decode queue processes data in discrete chunks (URLSession delegate callbacks). Each callback block joins the workgroup at entry and leaves at exit. The overhead of join/leave per block is negligible compared to the decode work itself.

The join token is stored in `DecodeContext` (queue-confined, not @MainActor) to avoid actor isolation issues.

## Architecture

### Current Threading Model

```
Main Thread (@MainActor)     Decode Queue (serial)     Audio IO Thread (RT)
├─ StreamPlayer              ├─ ICYFramer              ├─ AVAudioSourceNode
├─ PlaybackCoordinator       ├─ AudioFileStreamParser   │  render block
└─ UI                        ├─ AudioConverterDecoder   │  ringBuffer.read()
                             └─ ringBuffer.write()  ──►│
```

### Integration Points

| Component | File | What Changes |
|-----------|------|-------------|
| ObjC Shim (NEW) | `Audio/AUAudioUnitWorkgroupShim.{h,m}` | Bridges `osWorkgroup` to Swift |
| AudioEngineController | `Audio/AudioEngineController.swift` | Expose workgroup via shim |
| StreamDecodePipeline | `Audio/Streaming/StreamDecodePipeline.swift` | Pass workgroup to DecodeContext |
| DecodeContext | (inner class in StreamDecodePipeline) | Join/leave per decode block |

### Key Constraints

1. **Join token in DecodeContext** — queue-confined, not @MainActor
2. **Reacquire workgroup on every bridge activation** — workgroup changes with device changes
3. **Guard double-join** — check if already joined before calling join
4. **Graceful fallback** — if join fails, log warning but continue (correctness unaffected)
5. **ObjC shim in bridging header** — add to `MacAmpApp-Bridging-Header.h`

### Workgroup Lifecycle

```
activateStreamBridge()
    │
    ├─► Engine starts
    │
    ├─► AUAudioUnitGetWorkgroup(outputNode.auAudioUnit)
    │       │
    │       ▼
    │   StreamDecodePipeline receives os_workgroup_t
    │       │
    │       ▼
    │   DecodeContext stores workgroup reference
    │
    ▼
Each URLSession data callback (on decodeQueue):
    ├─► os_workgroup_join(workgroup, &token)
    ├─► ICY → Parse → Decode → ringBuffer.write()
    └─► os_workgroup_leave(workgroup, &token)

stop() / teardown:
    └─► DecodeContext.workgroup = nil (no explicit leave needed — per-block)
```

## Risk Assessment

**Low risk.** Additive change:
- No behavior change if workgroup join fails (just logs)
- No impact on local file playback
- Per-block join/leave is self-cleaning (no dangling tokens)
- ObjC shim is trivial (2 files, ~10 lines)
- Requires `xcodegen generate` for new ObjC files
