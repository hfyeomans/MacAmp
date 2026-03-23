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

- [x] Play internet radio stream — no audio glitches, no workgroup errors in console
- [x] Stop stream — clean teardown, no warnings
- [x] Play local file — no workgroup activity (correct)
- [x] Reconnect scenario — workgroup re-acquired on new stream
- [x] Switch audio output device during stream — not tested (accepted limitation, documented)

## Review & PR

- [x] Oracle review — 8.5/10, device-change gap accepted
- [x] Create PR #66 — merged (2026-03-22)
