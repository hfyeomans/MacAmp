# Docs Update Needed: os_workgroup Integration

> **Purpose:** Track documentation updates needed for this task's architectural changes.
> **When:** During next docs sweep or before a release.

---

## MACAMP_ARCHITECTURE_GUIDE.md

### Audio Threading Model (Section 4 or wherever threading is documented)

Add os_workgroup integration to the threading diagram:

```
Main Thread (@MainActor)     Decode Queue (serial, WORKGROUP-JOINED)     Audio IO Thread (RT)
├─ StreamPlayer              ├─ ICYFramer                                 ├─ AVAudioSourceNode
├─ PlaybackCoordinator       ├─ AudioFileStreamParser                      │  render block
└─ UI                        ├─ AudioConverterDecoder                      │  ringBuffer.read()
                             └─ ringBuffer.write()  ─────────────────────►│
```

Note that decode queue does per-block `os_workgroup_join`/`os_workgroup_leave` via ObjC shim, not once-per-session (GCD serial queues reuse threads).

### Component File Structure

Add new files:
- `Audio/ObjCBridge/AUAudioUnitWorkgroupShim.h` — ObjC bridge for Swift-unavailable `AUAudioUnit.osWorkgroup`
- `Audio/ObjCBridge/AUAudioUnitWorkgroupShim.m` — join/leave with heap-allocated token lifecycle
- `MacAmpApp-Bridging-Header.h` — Swift-ObjC bridging header

### AudioEngineController Section

Add `audioWorkgroup` computed property — exposes `os_workgroup_t` from output node via ObjC shim. Only valid while engine is running.

### Known Limitations

Document device-change refresh gap: workgroup is reacquired on bridge activation but not refreshed mid-session on output device change. Low impact — suboptimal scheduling, not a crash.

## IMPLEMENTATION_PATTERNS.md

### New Pattern: ObjC Bridging for Swift-Unavailable APIs

```swift
// When an Apple API is __attribute__((swift_private)):
// 1. Create ObjC shim in Audio/ObjCBridge/
// 2. Add to MacAmpApp-Bridging-Header.h
// 3. Add SWIFT_OBJC_BRIDGING_HEADER to project.yml
// 4. Call ObjC function from Swift
var audioWorkgroup: os_workgroup_t? {
    guard audioEngine.isRunning else { return nil }
    return AUAudioUnitGetWorkgroup(audioEngine.outputNode.auAudioUnit)
}
```

### New Pattern: Per-Block Workgroup Join/Leave

```swift
// GCD serial queues reuse threads — os_workgroup_join is thread-scoped.
// Must join/leave per dispatch block, not once per session.
decodeQueue.async { [self] in
    let token = joinWorkgroupIfAvailable()  // ObjC shim → heap-allocated token
    defer {
        if let t = token { leaveWorkgroup(token: t) }  // ObjC shim → free token
    }
    // decode work here
}
```

### Flow Diagram: Workgroup Lifecycle

```
activateStreamBridge()
    ├─► Engine starts
    ├─► AUAudioUnitGetWorkgroup(outputNode.auAudioUnit)  [ObjC shim]
    ├─► StreamDecodePipeline.setAudioWorkgroup(workgroup)
    │       └─► DecodeContext.audioWorkgroup = workgroup  [queue-confined]
    ▼
Each URLSession data callback (on decodeQueue):
    ├─► AudioWorkgroupJoin(workgroup)  → heap token
    ├─► ICY → Parse → Decode → ringBuffer.write()
    └─► AudioWorkgroupLeave(workgroup, token)  → free token
```

## project.yml / Build Configuration

Document `SWIFT_OBJC_BRIDGING_HEADER` setting and that `xcodegen generate` is required after adding `.m` files.
