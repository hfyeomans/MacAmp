# Todo: os_workgroup Integration

> **Purpose:** Track implementation tasks for os_workgroup integration.

---

## Implementation

- [x] Create `AUAudioUnitWorkgroupShim.h` and `.m` (ObjC bridging for `osWorkgroup` + join/leave)
- [x] Add `#import "AUAudioUnitWorkgroupShim.h"` to bridging header
- [x] Add `audioWorkgroup` computed property to `AudioEngineController.swift`
- [x] Add `setAudioWorkgroup()` to `StreamDecodePipeline.swift`
- [x] Add per-block `joinWorkgroupIfAvailable()` / `leaveWorkgroup()` to `DecodeContext`
- [x] Wrap decode data handler with join/leave in `DecodeContext`
- [x] Wire workgroup from `AudioPlayer` → `StreamPlayer` → `StreamDecodePipeline` after bridge activation
- [x] Clear workgroup on `stopInternal()`
- [x] Run `xcodegen generate` for new ObjC files
- [x] Add `SWIFT_OBJC_BRIDGING_HEADER` to `project.yml`

## Build & Test

- [x] XcodeBuildMCP build with Thread Sanitizer — no new warnings
- [x] XcodeBuildMCP test — all 53 tests pass
- [x] Use `ast-grep` to check for duplicate workgroup patterns — clean

## Manual Testing

- [ ] Play internet radio stream — no audio glitches, no workgroup errors in console
- [ ] Stop stream — clean teardown, no warnings
- [ ] Play local file — no workgroup activity (correct)
- [ ] Reconnect scenario — workgroup re-acquired on new stream
- [ ] Switch audio output device during stream — no crash

## Review & PR

- [ ] Oracle review — address all findings
- [ ] Create PR for user review
