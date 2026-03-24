# Plan: StreamDecodePipeline Decomposition

> **Description:** Implementation plan for decomposing `StreamDecodePipeline.swift` (713 lines) into focused files.
> **Updated:** 2026-03-24 (implementation-ready, based on responsibility map)

---

## Objective

Reduce `StreamDecodePipeline.swift` from 713 to ~345 lines by extracting self-contained types and static utilities into neighboring files within `Audio/Streaming/`.

## Extraction Plan

### Step 1: Extract `DecodeContext.swift` (Safe, ~207 lines)

Move the entire `DecodeContext` class (lines 465-671) to its own file. This is already a separate class with clear boundaries — queue-confined decode chain owning ICYFramer, AudioFileStreamParser, AudioConverterDecoder.

- Change access from `private` to `internal`
- No API changes needed — constructed via init, communicated via closures
- Include all methods: `handleIncomingData`, `shutdown`, `joinWorkgroupIfAvailable`, `leaveWorkgroup`, `handleFormatAvailable`, `handlePackets`, `configureFramer`

### Step 2: Extract `SessionDelegateProxy.swift` (Safe, ~41 lines)

Move the entire `SessionDelegateProxy` class (lines 673-713) to its own file. Completely self-contained NSObject delegate proxy.

- Change access from `private` to `internal`
- No behavioral change — closures set at init, then read-only

### Step 3: Extract `PlaylistResolver.swift` (Safe, ~76 lines)

Move all static playlist resolution code (lines 365-440) to a standalone utility:
- `isPlaylistURL(_:)` (static)
- `resolvePlaylistURL(_:)` (static async throws)
- `parsePLS(content:)` (static)
- `PlaylistResolveError` enum

These have **zero instance state coupling** — all `static` or `private static`. Move `PlaylistResolveError` into the same file (not its own file — too small).

### Step 4: Extract `StreamFormatHint.swift` (Safe, ~21 lines)

Move both static format hint functions (lines 442-462):
- `formatHint(for:)` (static)
- `formatHint(forContentType:)` (static — **dead code**, zero callers)

Keep both in one file. Flag the dead code in `placeholder.md`.

### Step 5: Clean up residual pipeline (no extraction)

- Update `StreamDecodePipeline.swift` to reference extracted types
- Remove dead `formatHint(forContentType:)` callers if any appear during extraction
- Verify generation-token semantics still work across file boundaries

**NOT extracting `StreamState`/`StreamTerminationReason` (23 lines).** Per Gemini guidance: these are tiny enums consumed primarily within the same file. Extracting them to their own file adds a file with no distinct lifecycle. They stay in `StreamDecodePipeline.swift`.

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `Audio/Streaming/DecodeContext.swift` | ~207 | Nested class extraction |
| `Audio/Streaming/SessionDelegateProxy.swift` | ~41 | Nested class extraction |
| `Audio/Streaming/PlaylistResolver.swift` | ~76 | Static methods + error enum |
| `Audio/Streaming/StreamFormatHint.swift` | ~21 | Static methods |

**Total new files: 4** (consolidated from original 5 — merged types into PlaylistResolver)
**Residual StreamDecodePipeline.swift: ~345 lines**

## Constraints

- Preserve generation-token, shutdown, and callback semantics
- Do not destabilize the decode queue / audio-thread handoff
- Decompose in place within `Audio/Streaming/` (already at target location)
- Do not mix new stream features into this cleanup task
- Flag-but-don't-fix duplications and dead code in `placeholder.md`

## Verification

- Stream startup, buffering, pause/resume, and stop still work
- Metadata and format-ready callbacks still fire correctly
- Error paths and termination reasons surface cleanly
- Auto-reconnect (exponential backoff) still works end-to-end
- `xcodegen generate` + XcodeBuildMCP build + test pass
- Thread Sanitizer clean
