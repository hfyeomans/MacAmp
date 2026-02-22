# State: Lock-Free Ring Buffer

> **Purpose:** Tracks the current state of the task including progress, blockers, decisions made, and open questions.

---

## Current Status: COMPLETE

## Progress

- [x] Task created with file structure
- [x] Research populated from parent task (`internet-streaming-volume-control`)
- [x] Plan written
- [x] Plan approved (cross-task plan approved 2026-02-21)
- [x] Implementation (`MacAmpApp/Audio/LockFreeRingBuffer.swift`)
- [x] Unit tests (14 tests in `LockFreeRingBufferTests` suite)
- [x] Concurrent stress tests (3 tests in `LockFreeRingBufferConcurrencyTests` suite)
- [x] Oracle review — 2 rounds (initial concurrency review + end-to-end code review)
- [x] TSan verification (serial execution, 40/40 tests pass)
- [x] Pre-existing test failures fixed (DockingController + PlaylistNavigation)
- [ ] Performance benchmarks (deferred — see todo.md)
- [ ] Integration into parent task (deferred to `internet-streaming-volume-control`)

## Commits

1. `3acf75e` — Package.swift bump to swift-tools-version 6.2 + swift-atomics dependency
2. `a6e73e4` — LockFreeRingBuffer implementation + initial test suite
3. `55cc422` — Phase 4-6: pbxproj, tags, Oracle fixes, edge case tests, #expect workaround
4. `3bd5bec` — Fix two pre-existing test failures (DockingController + PlaylistNavigation)

## Key Decisions

1. **Pattern:** SPSC (single-producer single-consumer) lock-free ring buffer
2. **Atomics:** Swift Atomics `ManagedAtomic<UInt64>` for read/write indices
3. **Capacity:** 4096 frames (~85ms at 48kHz), pre-allocated
4. **Format:** Stereo float32 (worst-case pre-allocation)
5. **Overrun:** Drop oldest data (advance read pointer) — accepted design trade-off
6. **Underrun:** Fill silence, return 0 frames read, increment underrun counter
7. **Format changes:** Generation ID pattern with atomic counter
8. **Memory ordering:** Acquire-release for SPSC correctness
9. **Flush:** Monotonic head counters (readHead = writeHead, never reset to zero)
10. **Oversized writes:** Bounded to capacity, keep newest tail frames

## Oracle Review Findings

### Round 1 (Concurrency Review, 2026-02-21)
1. **High (accepted):** Overrun path can race with reader `memcpy` on storage. By-design for real-time audio — documented in class-level doc comment.
2. **Medium (mitigated):** `flush()` only safe if producer quiesced. Documented in method doc comment.
3. **Low (fixed):** Tautological `UInt64 >= 0` assertion → meaningful bound check.
4. **Low (fixed):** `capacity * channelCount` overflow → `multipliedReportingOverflow` precondition.

### Round 2 (End-to-End Review, 2026-02-21)
1. **High (fixed):** DockingControllerTests crash — `togglePlaylist()` asserts windowCoordinator. Fixed: use `toggleVisibility(.playlist)`.
2. **High (fixed):** PlaylistNavigationTests assertion — wrong `currentTrack` setup. Fixed: set `currentTrack = streamTrack`.
3. **Medium:** Debounce cancellation in DockingController can persist stale state (`try?` swallows cancellation). Not fixed — separate concern.
4. **Medium:** Overrun head adjustment can over-advance under contention. Accepted — SPSC contract means single producer.
5. **Low:** `highThroughput` test potentially flaky under scheduler pressure. Accepted — bound is generous (`< chunks/2`).

## Files

- `MacAmpApp/Audio/LockFreeRingBuffer.swift` — Implementation (17 tests covering it)
- `Tests/MacAmpTests/LockFreeRingBufferTests.swift` — Test suite (14 unit + 3 concurrency)
- `Tests/MacAmpTests/TestTags.swift` — Shared `.audio` and `.concurrency` tags

## Parent Task

- `internet-streaming-volume-control` — Phase 2 (Loopback Bridge) depends on this task
