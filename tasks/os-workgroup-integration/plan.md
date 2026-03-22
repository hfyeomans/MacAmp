# Plan: os_workgroup Integration

> **Purpose:** Integrate Apple os_workgroup API so the stream decode thread shares the audio IO thread's real-time scheduling group on Apple Silicon.

**Status:** Revised after Oracle review (2026-03-22). Original plan scored 4/10; this addresses all 7 findings.

---

## Scope

Add `os_workgroup` per-block join/leave for the stream decode queue. This ensures the kernel treats the decode thread with real-time priority while processing audio data, preventing ring buffer underruns under CPU pressure.

## Changes

### 1. ObjC Bridging Shim (NEW — Small)

**New files:** `MacAmpApp/Audio/AUAudioUnitWorkgroupShim.h`, `MacAmpApp/Audio/AUAudioUnitWorkgroupShim.m`

`AUAudioUnit.osWorkgroup` is Swift-unavailable (`__attribute__((swift_private))`). A minimal ObjC function bridges it:

```objc
// AUAudioUnitWorkgroupShim.h
#import <AudioToolbox/AudioToolbox.h>
#import <os/workgroup.h>

/// Retrieve the os_workgroup from an AUAudioUnit's output node.
/// Swift-unavailable property requires ObjC bridging.
os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit);
```

```objc
// AUAudioUnitWorkgroupShim.m
#import "AUAudioUnitWorkgroupShim.h"

os_workgroup_t _Nullable AUAudioUnitGetWorkgroup(AUAudioUnit * _Nonnull unit) {
    return unit.osWorkgroup;
}
```

**Bridging header:** Add `#import "AUAudioUnitWorkgroupShim.h"` to `MacAmpApp-Bridging-Header.h`.

**XcodeGen:** Run `xcodegen generate` after adding `.m` file.

### 2. AudioEngineController — Expose Workgroup (Small)

**File:** `MacAmpApp/Audio/AudioEngineController.swift`

Add computed property using the ObjC shim:

```swift
/// The audio IO workgroup from the output node. Only valid while engine is running.
/// Returns nil if engine is stopped or workgroup unavailable.
var audioWorkgroup: os_workgroup_t? {
    guard audioEngine.isRunning else { return nil }
    return AUAudioUnitGetWorkgroup(audioEngine.outputNode.auAudioUnit)
}
```

Pass workgroup to pipeline in `activateStreamBridge()` — add a new parameter or a post-activation callback.

### 3. StreamDecodePipeline + DecodeContext — Per-Block Join/Leave (Medium)

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`

**a) Pipeline level:** Add property to receive workgroup from caller:

```swift
/// Audio IO workgroup — set after bridge activation, cleared on stop.
/// Passed to DecodeContext for per-block join/leave.
private var audioWorkgroup: os_workgroup_t?

func setAudioWorkgroup(_ workgroup: os_workgroup_t?) {
    self.audioWorkgroup = workgroup
    decodeQueue.async { [weak self] in
        self?.decodeContext?.audioWorkgroup = workgroup
    }
}
```

**b) DecodeContext level (queue-confined):** Add per-block join/leave around decode work:

```swift
// In DecodeContext (queue-confined, NOT @MainActor)
var audioWorkgroup: os_workgroup_t?

/// Join workgroup for the duration of a decode block. Returns token for leave.
private func joinWorkgroupIfAvailable() -> os_workgroup_join_token_s? {
    guard let wg = audioWorkgroup else { return nil }
    var token = os_workgroup_join_token_s()
    let result = os_workgroup_join(wg, &token)
    if result != 0 {
        // Non-fatal — log and continue without workgroup membership
        return nil
    }
    return token
}

private func leaveWorkgroup(token: inout os_workgroup_join_token_s) {
    guard let wg = audioWorkgroup else { return }
    os_workgroup_leave(wg, &token)
}
```

**c) Wrap decode callbacks:** In the URLSession data handler that dispatches to decodeQueue:

```swift
decodeQueue.async { [weak self] in
    guard let self else { return }
    var token = self.joinWorkgroupIfAvailable()
    defer {
        if var t = token { self.leaveWorkgroup(token: &t) }
    }
    // existing decode work: ICY → Parse → Decode → ringBuffer.write()
    self.handleData(data)
}
```

### 4. Wiring — Bridge Activation Path (Small)

**Where workgroup flows:**

```
PlaybackCoordinator → AudioPlayer.activateStreamBridge()
    → AudioEngineController.activateStreamBridge()
        → engine starts
        → AudioEngineController.audioWorkgroup (via ObjC shim)
    → StreamPlayer receives workgroup
        → StreamDecodePipeline.setAudioWorkgroup(workgroup)
            → DecodeContext.audioWorkgroup = workgroup
```

The exact wiring depends on how `AudioPlayer` exposes the engine's workgroup. Options:
- **a)** `AudioPlayer` adds `var audioWorkgroup: os_workgroup_t? { engine?.audioWorkgroup }` — StreamPlayer reads it after bridge activation
- **b)** Callback from AudioEngineController's `activateStreamBridge` returns the workgroup

Option (a) is simpler and matches the existing facade pattern.

### 5. Teardown / Reconnect

On `stop()` / `deactivateStreamBridge()`:
- `StreamDecodePipeline.setAudioWorkgroup(nil)` clears the reference
- Per-block join/leave means no dangling tokens (each block is self-contained)
- On reconnect: `activateStreamBridge` reacquires a fresh workgroup (handles device changes)

## Non-Changes

- **Local file playback** — unaffected (playerNode runs on IO thread natively)
- **Ring buffer** — no changes
- **Render block** — no changes (already on IO thread)
- **EQ/Visualizer** — unaffected

## Verification

1. Build with Thread Sanitizer — no new warnings
2. Run all tests — pass
3. Manual: play internet radio, verify "Joined audio workgroup" log (or absence of errors)
4. Manual: stop stream — no workgroup warnings
5. Manual: play local file — no workgroup activity
6. Manual: reconnect — workgroup re-acquired cleanly
