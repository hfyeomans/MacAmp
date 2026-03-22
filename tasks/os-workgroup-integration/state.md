# State: os_workgroup Integration

> **Purpose:** Integrate Apple os_workgroup API for audio render thread on Apple Silicon
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** IN PROGRESS

---

## Current Status

**Phase:** Implementation complete — awaiting manual testing + PR
**Status:** IN PROGRESS
**Branch:** `feature/os-workgroup-integration`
**Oracle Score:** 8.5/10 (revised from 4/10 initial plan)
**Last Updated:** 2026-03-22

## Post-Implementation Review (2026-03-22)

**Review scope:** `os_workgroup` integration in stream decode pipeline

**Verification completed:**
- `build_macos` for scheme `MacAmpApp` — passed
- `test_macos` for scheme `MacAmpApp` — passed (`53/53`)

**Review result:** One remaining lifecycle risk

1. **Device-change refresh gap (ACCEPTED):** Workgroup is reacquired on bridge activation, but there is no active-path refresh when the output device / engine configuration changes while a stream is already playing. The decode queue keeps using the previously captured workgroup until the next reconnect or manual bridge teardown/reactivation. **Impact:** Low — stale workgroup means slightly suboptimal scheduling on the new device, not a crash or correctness issue. A `kAudioDevicePropertyIOThreadOSWorkgroup` observer could refresh it, but that's over-engineering for the current use case. Documented for future consideration.

**Other review notes:**
- Per-block join/leave on the serial decode queue is thread-safe.
- ObjC token allocation/free pairing is correct and leak-free in the current call path.
- Strict concurrency build passes under Swift 6.2 with `SWIFT_STRICT_CONCURRENCY=complete`.

## Oracle Review (Initial Plan)

**Score:** 4/10
**Key findings:**
1. `AUAudioUnit.osWorkgroup` is Swift-unavailable — needs ObjC shim
2. `os_workgroup_join` is thread-scoped, not queue-scoped — per-session join is unsafe on GCD
3. Token on `@MainActor` pipeline is actor-isolation violation
4. Integration point wrong — `AudioPlayer.engine` is private
5. Must reacquire workgroup on every bridge activation (device changes)
6. Leave path referenced non-existent `currentWorkgroup`
7. Decode work starts before bridge activation — timing wrong

**Resolution:** Revised plan uses per-block join/leave on DecodeContext (queue-confined), ObjC shim for Swift bridging, reacquire on each activation.

---
