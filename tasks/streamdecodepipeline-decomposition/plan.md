# Plan: StreamDecodePipeline Decomposition

> **Description:** Implementation plan for decomposing `StreamDecodePipeline.swift` (697 lines) into focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## Objective

Reduce `StreamDecodePipeline.swift` from 697 to ~380 lines by extracting self-contained types and static utilities into neighboring files within `Audio/Streaming/`.

## Extraction Plan

### Step 1: Extract `DecodeContext.swift` (Safe, ~207 lines)

Move the entire `DecodeContext` class (lines 457-655) to its own file. This is already a separate class with clear boundaries — queue-confined decode chain owning ICYFramer, AudioFileStreamParser, AudioConverterDecoder. Consider adopting `QueueConfined` protocol (already used by AudioFileStreamParser + AudioConverterDecoder) for consistency.

- Change access from `private` to `internal`
- No API changes needed — constructed via init, communicated via closures
- Include all methods: `handleIncomingData`, `shutdown`, `joinWorkgroupIfAvailable`, `leaveWorkgroup`, `handleFormatAvailable`, `handlePackets`, `configureFramer`

### Step 2: Extract `SessionDelegateProxy.swift` (Safe, ~41 lines)

Move the entire `SessionDelegateProxy` class (lines 664-697) to its own file. Completely self-contained NSObject delegate proxy.

- Change access from `private` to `internal`
- No behavioral change — closures set at init, then read-only

### Step 3: Extract `PlaylistResolver.swift` (Safe, ~76 lines)

Move all static playlist resolution code (lines 358-430) to a standalone utility:
- `isPlaylistURL(_:)` (static)
- `resolvePlaylistURL(_:)` (static async throws)
- `parsePLS(content:)` (static)
- `PlaylistResolveError` enum

These have **zero instance state coupling** — all `static` or `private static`. Move `PlaylistResolveError` into the same file (not its own file — too small).

### Step 4: Extract `StreamFormatHint.swift` (Safe, ~14 lines)

Move `formatHint(for:)` (lines 434-445, static). `formatHint(forContentType:)` was already removed in Phase 2.5 (zero callers). At only 14 lines, consider folding into `PlaylistResolver.swift` instead of a separate file.

### Step 5: Clean up residual pipeline (no extraction)

- Update `StreamDecodePipeline.swift` to reference extracted types
- Verify generation-token semantics still work across file boundaries

**NOT extracting `StreamState`/`StreamTerminationReason` (23 lines).** Per Gemini guidance: these are tiny enums consumed primarily within the same file. Extracting them to their own file adds a file with no distinct lifecycle. They stay in `StreamDecodePipeline.swift`.

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `Audio/Streaming/DecodeContext.swift` | ~199 | Nested class extraction |
| `Audio/Streaming/SessionDelegateProxy.swift` | ~34 | Nested class extraction |
| `Audio/Streaming/PlaylistResolver.swift` | ~87 | Static methods + error enum + format hint |
| ~~`Audio/Streaming/StreamFormatHint.swift`~~ | ~~~14~~ | Folded into PlaylistResolver (too small for own file) |

**Total new files: 3** (StreamFormatHint folded into PlaylistResolver — only 14 lines after Phase 2.5 cleanup)
**Residual StreamDecodePipeline.swift: ~380 lines**

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
