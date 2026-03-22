# State: os_workgroup Integration

> **Purpose:** Integrate Apple os_workgroup API for audio render thread on Apple Silicon
> **Created:** 2026-03-14
> **Sprint:** S2 (MEDIUM)
> **Status:** IN PROGRESS

---

## Current Status

**Phase:** Implementation
**Status:** IN PROGRESS — Plan revised after Oracle review (4/10 → revised)
**Branch:** `feature/os-workgroup-integration` (not yet created)
**Last Updated:** 2026-03-22

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
