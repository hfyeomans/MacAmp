# Research: StreamDecodePipeline Decomposition

> **Description:** Responsibility map for decomposing `StreamDecodePipeline.swift` into smaller, focused files.
> **Updated:** 2026-03-24 (responsibility map complete — reflects 713 lines post-S2)

---

## File Overview

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
**Lines:** 713 (grew from 631 at planning time — S2 added os-workgroup integration)
**Contains:** 3 types — `StreamDecodePipeline` (lines 25-463), `DecodeContext` (lines 473-671), `SessionDelegateProxy` (lines 680-713)

## Imports

| Import | Usage |
|--------|-------|
| `Foundation` | URLSession, URLRequest, Data, NSError, OperationQueue |
| `AudioToolbox` | AudioFileTypeID, AudioStreamBasicDescription, kAudioFileMP3Type, etc. |
| `@preconcurrency import os` | os_workgroup_t |

---

## Section-by-Section Responsibility Map

### Section 1: Enums & State Types (lines 27-49) — 23 lines
- **Responsibility:** Stream state machine and termination reason types
- **Key symbols:** `StreamState` enum (idle, connecting, buffering, playing, paused, error), `StreamTerminationReason` enum (8 cases)
- **External coupling:** StreamTerminationReason extended in StreamPlayer.swift with `userMessage`
- **Extractability:** **Safe** — pure value types

### Section 2: Stored Properties & Callbacks (lines 51-104) — 54 lines
- **Responsibility:** Instance state, callbacks, queue/context, session/task, generation token
- **Key symbols:** `state`, `onStateChange`, `onFormatReady`, `onMetadata`, `onTermination`, `ringBuffer`, `audioWorkgroup`, `decodeQueue`, `decodeContext`, `urlSession`, `dataTask`, `delegateProxy`, `generation`, `formatReadyFired`, `userRequestedStop`
- **Extractability:** N/A — inherent class state

### Section 3: Audio Workgroup Management (lines 64-79) — 16 lines
- **Responsibility:** Forwarding audio IO workgroup to DecodeContext
- **Key symbols:** `audioWorkgroup` property, `setAudioWorkgroup(_:)`
- **Extractability:** **Moderate** — coupled to decodeContext and decodeQueue

### Section 4: Lifecycle Management (lines 106-268) — 163 lines
- **Responsibility:** start/stop/pause/resume, DecodeContext creation, URLSession setup
- **Key symbols:** `start(url:ringBuffer:)`, `startDirectStream(url:ringBuffer:generation:)`, `pause()`, `resume()`, `stop()`, `isolated deinit`, `stopInternal()`, `setState(_:)`
- **Internal coupling:** Creates DecodeContext, SessionDelegateProxy; calls setState; uses generation token
- **Extractability:** **Risky** — core of the class, stays

### Section 5: HTTP Response Handling (lines 275-330) — 56 lines
- **Responsibility:** HTTP status classification, error routing
- **Key symbols:** `handleHTTPResponse(_:generation:)`, `extractICYMetaInt(from:)` (static)
- **Extractability:** **Safe** — `extractICYMetaInt` is pure static function

### Section 6: Stream Completion Handling (lines 332-363) — 32 lines
- **Responsibility:** URLSession completion classification
- **Key symbols:** `handleStreamComplete(error:generation:)`
- **Extractability:** **Safe** — self-contained handler

### Section 7: Playlist Resolution (lines 365-440) — 76 lines
- **Responsibility:** Detect and resolve M3U/M3U8/PLS playlist URLs to direct stream URLs
- **Key symbols:** `isPlaylistURL(_:)` (static), `resolvePlaylistURL(_:)` (static async throws), `parsePLS(content:)` (static), `PlaylistResolveError` enum
- **Internal coupling:** Called only from `start()` (lines 121, 126)
- **External coupling:** `M3UParser`
- **Extractability:** **Safe** — ALL four symbols are `static` with zero instance state coupling

### Section 8: Format Hint Utilities (lines 442-462) — 21 lines
- **Responsibility:** Map URL paths/content types to AudioToolbox format hint IDs
- **Key symbols:** `formatHint(for:)` (static), `formatHint(forContentType:)` (static)
- **Dead code:** `formatHint(forContentType:)` has zero callers in entire codebase
- **Extractability:** **Safe** — pure static functions

### Section 9: DecodeContext (lines 465-671) — 207 lines
- **Responsibility:** Queue-confined decode chain state. Owns ICYFramer, AudioFileStreamParser, AudioConverterDecoder.
- **Key symbols:** `DecodeContext` (private final class, @unchecked Sendable), `handleIncomingData(_:)`, `shutdown()`, `joinWorkgroupIfAvailable()`, `leaveWorkgroup(token:)`, `handleFormatAvailable(_:)`, `handlePackets(data:descriptions:)`
- **Threading:** All mutable state confined to `decodeQueue`. `@unchecked Sendable` with `dispatchPrecondition` assertions. Per-block workgroup join/leave.
- **External coupling:** ICYFramer, AudioFileStreamParser, AudioConverterDecoder, LockFreeRingBuffer, AudioWorkgroupJoin/Leave (ObjC shim)
- **Extractability:** **Safe** — already a separate class with clear boundaries

### Section 10: SessionDelegateProxy (lines 673-713) — 41 lines
- **Responsibility:** NSObject delegate proxy forwarding URLSessionDataDelegate callbacks to closures
- **Key symbols:** `SessionDelegateProxy` (private final class, NSObject, URLSessionDataDelegate, @unchecked Sendable)
- **Internal coupling:** Created in startDirectStream; closures capture [weak self, weak context]
- **Extractability:** **Safe** — completely self-contained

---

## Concurrency / Threading Summary

| Thread/Queue | Code Location | Symbols |
|---|---|---|
| Main Thread (@MainActor) | StreamDecodePipeline | All public API |
| Decode Queue (serial) | DecodeContext | framer, parser, decoder, ringBuffer.write |
| URLSession delegate queue | SessionDelegateProxy | onResponse, onData, onComplete |
| Audio IO Thread (external) | AVAudioSourceNode | ringBuffer.read (not in this file) |

**Generation token pattern:** `generation: UInt64` incremented on every start/stop. All callbacks reject stale data.

## Sole Consumer

`StreamPlayer.swift` is the only external consumer.

---

## Recommended Extraction Units

| # | Target File | Sections | Est. Lines | Risk |
|---|-------------|----------|------------|------|
| 1 | `StreamDecodePipelineTypes.swift` | Section 1 (StreamState, StreamTerminationReason) | ~23 | Safe |
| 2 | `PlaylistResolver.swift` | Section 7 (static playlist detection/resolution) | ~76 | Safe |
| 3 | `StreamFormatHint.swift` | Section 8 (static format hint mapping) | ~21 | Safe |
| 4 | `DecodeContext.swift` | Section 9 (entire DecodeContext class) | ~207 | Safe |
| 5 | `SessionDelegateProxy.swift` | Section 10 (entire delegate proxy) | ~41 | Safe |
| 6 | `StreamDecodePipeline.swift` (remaining) | Sections 2-6 (core lifecycle) | ~310 | Core — stays |

**Post-extraction estimate:** ~310 lines (down from 713)

## Dead Code

- `formatHint(forContentType:)` at line 457 — `static` (internal access) with zero callers in entire codebase

## Intentional Non-Duplication

- Lines 189 and 302-309 both call `extractICYMetaInt` on HTTP response headers. This is **intentional** — proxy call runs on delegate queue for ordering, handleHTTPResponse call runs on MainActor for logging. Comment on lines 311-314 documents this.
