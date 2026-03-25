# Research: StreamDecodePipeline Decomposition

> **Description:** Responsibility map for decomposing `StreamDecodePipeline.swift` into smaller, focused files.
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## File Overview

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
**Lines:** 697 (down from 713 — Phase 2.5 removed dead `formatHint(forContentType:)` + unused `metaInt` block)
**Contains:** 3 types — `StreamDecodePipeline` (lines 25-447), `DecodeContext` (lines 457-655), `SessionDelegateProxy` (lines 664-697)

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

### Section 7: Playlist Resolution (lines 358-430) — 73 lines
- **Responsibility:** Detect and resolve M3U/M3U8/PLS playlist URLs to direct stream URLs
- **Key symbols:** `isPlaylistURL(_:)` (static), `resolvePlaylistURL(_:)` (static async throws), `parsePLS(content:)` (static), `PlaylistResolveError` enum
- **Internal coupling:** Called only from `start()` (lines 121, 126)
- **External coupling:** `M3UParser`
- **Extractability:** **Safe** — ALL four symbols are `static` with zero instance state coupling

### Section 8: Format Hint Utility (lines 434-445) — 14 lines
- **Responsibility:** Map URL paths to AudioToolbox format hint IDs
- **Key symbols:** `formatHint(for:)` (static, 14 lines)
- **Phase 2.5:** `formatHint(forContentType:)` removed (zero callers)
- **Extractability:** **Safe** — pure static function. Small enough to fold into PlaylistResolver.

### Section 9: DecodeContext (lines 457-655) — 199 lines
- **Responsibility:** Queue-confined decode chain state. Owns ICYFramer, AudioFileStreamParser, AudioConverterDecoder.
- **Key symbols:** `DecodeContext` (private final class, @unchecked Sendable), `handleIncomingData(_:)`, `shutdown()`, `joinWorkgroupIfAvailable()`, `leaveWorkgroup(token:)`, `handleFormatAvailable(_:)`, `handlePackets(data:descriptions:)`
- **Threading:** All mutable state confined to `decodeQueue`. `@unchecked Sendable` with `dispatchPrecondition` assertions. Per-block workgroup join/leave.
- **External coupling:** ICYFramer, AudioFileStreamParser, AudioConverterDecoder, LockFreeRingBuffer, AudioWorkgroupJoin/Leave (ObjC shim)
- **Extractability:** **Safe** — already a separate class with clear boundaries

### Section 10: SessionDelegateProxy (lines 664-697) — 34 lines
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
| 1 | `PlaylistResolver.swift` (incl. format hint) | Section 7 + 8 | ~87 | Safe |
| 2 | `DecodeContext.swift` | Section 9 (entire DecodeContext class) | ~199 | Safe |
| 3 | `SessionDelegateProxy.swift` | Section 10 (entire delegate proxy) | ~34 | Safe |
| 4 | `StreamDecodePipeline.swift` (remaining) | Sections 2-6 (core lifecycle) | ~380 | Core — stays |

**Post-extraction estimate:** ~380 lines (down from 697)

## Dead Code

- ~~`formatHint(forContentType:)` at line 457~~ — **Removed in Phase 2.5** (was `static` with zero callers)

## Intentional Non-Duplication

- `extractICYMetaInt` is called from the `onResponse` proxy callback (line 189, delegate queue). The `handleHTTPResponse` method (lines 301-305) has a comment explaining why it does NOT call `extractICYMetaInt` again — the proxy already handles it.
