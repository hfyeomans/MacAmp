# Plan: HLS Streaming Support (Audio-Only)

> **Status:** Plan — Oracle-validated 9/10 in Round 4. Ready for implementation when predecessors merge.
> **Sprint:** S3 (Wave S3-3, sequential).
> **Branch:** `feat/hls-streaming-support`.
> **PR target:** PR #D (after PR #B `stream-pause-tail` and PR #C `video-audio-engine-routing` merge).
> **Predecessors merged:** S3-1 (`stream-pause-tail`), S3-2 (`video-audio-engine-routing`).
> **Source of truth:** `tasks/hls-streaming-support/research.md` (Oracle 7/10, 8/8 actionable items applied).
> **Scope locked:** AAC-ADTS audio-only, master + media playlists, live + VOD, no DRM, no fMP4, no MPEG-TS, no LL-HLS, no ABR.

---

## 1. Problem Statement

A growing share of public internet radio (NPR Live HLS feeds, several BBC / Radio France mirrors, CDN-hosted SomaFM relays, ad-tech radio aggregators) is delivered as audio-only HLS (`.m3u8` master/media playlists referencing AAC-ADTS segments). MacAmp's existing custom decode pipeline (`StreamDecodePipeline`) treats every `.m3u8` URL as a *legacy* M3U playlist file — a single-line text file pointing at one progressive stream URL. When fed an actual HLS playlist:

1. `M3UParser.parse(...)` extracts the **first segment URL** as if it were a stream URL.
2. `StreamDecodePipeline.startDirectStream(...)` opens that URL.
3. The segment is ~6 s of AAC; URLSession completes; the pipeline reports `serverClosed`.
4. The existing reconnect machinery loops because `serverClosed` is reconnectable.
5. User experience: the station "buffers" forever, audio plays for 6 s every minute, or fails silently.

This is the concrete failure mode. Severity: increasing — most new public radio backends ship HLS by default. Workarounds (telling users to find a non-HLS mirror) are user-hostile and frequently impossible.

## 2. Non-Goals (explicit)

The following are out of scope for v1 and **must not** creep in:

- **Video HLS.** AVPlayer already handles HLS video natively in `VideoPlaybackController`. The `video-audio-engine-routing` task (S3-2) addresses MTAudioProcessingTap routing for local video; HLS-video routing through the engine is not in scope here and is not blocked by this task.
- **DRM** (`#EXT-X-KEY:METHOD=AES-128`, `SAMPLE-AES`, FairPlay). Detected and rejected with a non-reconnectable error.
- **fMP4 segments** (`#EXT-X-MAP:URI=…`, `.m4s`/`.mp4`). Detected and rejected with a non-reconnectable error.
- **MPEG-TS segments** (`.ts`). Detected and rejected with a non-reconnectable error.
- **Adaptive bitrate (ABR) switching.** Pick one variant at start; no mid-stream switching.
- **Low-Latency HLS** (`#EXT-X-PART`).
- **`#EXT-X-DISCONTINUITY` recovery beyond a parser.reset() flush.** No timestamp re-anchoring, no decoder swap.
- **Live DVR / time-shift / seeking inside live windows.**
- **Alternate audio renditions** via `#EXT-X-MEDIA` (multi-language). Master playlists with only `MEDIA` and no `STREAM-INF` are rejected.
- **Decomposition of `StreamDecodePipeline`.** Add a narrow new branch; do not split the file.
- **New top-level types in `Models/`.** HLS lives entirely under `Audio/Streaming/` (and a single new `Audio/HLS/` subfolder).

## 3. Pre-Decomposition Gate Checklist (per `_context/principles.md`)

Although this task primarily *adds* files rather than splitting an existing one, two new top-level types are introduced (`M3U8Parser`, `HLSSegmentFeeder`) and `StreamDecodePipeline` gains a new branch. The gate applies. All 8 items must be answered before structural edits proceed.

| # | Item | Answer |
|---|------|--------|
| 1 | Problem statement written | Yes — §1 above. Concrete user-visible failure mode for a growing class of stations. |
| 2 | Non-goals listed | Yes — §2 above. Explicit fence around DRM/fMP4/TS/ABR/LL-HLS/discontinuity beyond reset/multi-language/decomposition. |
| 3 | Principles contract approved | Yes — §10 below maps each principle. Critical: P3 (state ownership: feeder owns its own queue, does not co-own DecodeContext state), P5 (no visibility widening — closure injection seam), P6 (no pass-through — feeder adds real policy: refresh, sequencing, generation gating). |
| 4 | Responsibility map | Yes — §11 below. Three layers: M3U8Parser (pure data), HLSSegmentFeeder (mechanism: orchestrate fetch + refresh + variant selection), StreamDecodePipeline branch (bridge). |
| 5 | Complexity assessed | High cognitive *new* complexity (state machine: variant pick → media playlist refresh loop → segment download → discontinuity reset). Low cognitive load on the existing pipeline (single new branch; existing `start(url:)` keeps shape). Verdict: introduce HLS as a separate type to keep the existing file's cognitive complexity bounded. |
| 6 | Candidate split scored | Cohesion gain: high (HLS state + segment fetch is one concern). State risk: low (DecodeContext untouched; feeder's state lives on its own queue). Visibility impact: zero (closure-injection seam). Pass-through risk: zero (feeder adds real policy). |
| 7 | Public/internal API delta | None public. Two new file-private/internal types. `AudioFileStreamParser` gets one new internal method `reset()`. `StreamDecodePipeline` gets one new internal method `currentGeneration` getter (read-only token) and one new branch in `start(url:)`. No `private → internal` widening on existing types. |
| 8 | Stop criteria | §16 below. Hard kill switch: if `parser.reset()` cannot be made safe inside the AudioConverter lifetime contract (Lesson 6), or if AudioFileStream produces audible glitches at every segment boundary that we cannot eliminate, fall back to "v1 supports VOD only, live deferred to v2" and surface a clear error for live streams. |

**Gate: PASS.** Items 1–5 complete; structural edits may proceed.

## 4. Phase 0 (optional): Gemini re-run — SKIPPED with rationale

The research file's "Gemini Research Findings" section flagged that the original Gemini deep-research call did not return structured output and recommended re-running at planning time *only if implementation reveals a question not answered above*. The remaining open questions (5 listed in research §"Open Questions") are all engineering-judgment calls, not factual gaps:

1. Allow Content-Type promotion of non-`.m3u8` URLs → engineering decision (yes, on first response only).
2. `parser.reset()` between ADTS segments → empirical question, answered by the parser.reset() hook itself plus listening test.
3. Own URLSession vs `URLSession.shared` → engineering decision (own it).
4. `displayDuration` for HLS VOD → product decision (leave 0).
5. `EXTINF` titles → product decision (best-effort, opportunistic).

None of these benefit from external research. The architecture decisions (RFC 8216 reload timing, ADTS segment boundaries, magic cookie reuse, AAC-only scope) are anchored in primary sources (RFC 8216, Apple HLS Authoring Spec, MacAmp's own `tasks/done/unified-audio-pipeline/research.md`).

**Decision:** Skip Phase 0. If implementation surfaces a real gap, run a focused Gemini prompt at that point and append findings to `research.md`.

## 5. Phase 1 — `M3U8Parser.swift` (pure data)

**File:** `MacAmpApp/Audio/HLS/M3U8Parser.swift` (new). Estimated 200–250 LOC.

> Note on placement: Create a new `MacAmpApp/Audio/HLS/` subfolder (not `Audio/Streaming/`). HLS is a *transport orchestration* concern, not a *byte-stream decode* concern; the existing `Audio/Streaming/` files (ICYFramer, AudioFileStreamParser, AudioConverterDecoder, StreamDecodePipeline) handle the byte-and-decode path. Keeping HLS files in their own subfolder communicates that boundary and makes the v2 deferred work (TS demuxer, fMP4) sit naturally beside this code. No `project.yml` edit required (path-based source globbing); `xcodegen generate` picks them up.

### 5.1 Public surface (module-internal — `internal` access, default; no `public`)

```swift
enum M3U8Parser {

    /// Parsed playlist kind. Caller (HLSSegmentFeeder) decides what to do next.
    enum Playlist {
        case master(MasterPlaylist)
        case media(MediaPlaylist)
    }

    struct MasterPlaylist {
        let variants: [Variant]
    }

    struct Variant {
        let uri: URL                  // resolved against playlist URL
        let bandwidthBitsPerSec: Int? // from BANDWIDTH attr
        let codecs: String?           // from CODECS attr (e.g. "mp4a.40.2")
        let isAudioOnly: Bool         // heuristic: codecs lists mp4a.* and no avc/hev/hvc
    }

    struct MediaPlaylist {
        let version: Int?                       // EXT-X-VERSION
        let targetDurationSeconds: Double       // EXT-X-TARGETDURATION (required for live; defaulted for VOD)
        let mediaSequence: UInt64               // EXT-X-MEDIA-SEQUENCE (default 0)
        let segments: [Segment]
        let endlistSeen: Bool                   // EXT-X-ENDLIST
        let discontinuityFlags: [UInt64: Bool]  // sequence number → had EXT-X-DISCONTINUITY before its segment
    }

    struct Segment {
        let sequence: UInt64
        let uri: URL
        let durationSeconds: Double
        let title: String?       // optional EXTINF title field — opportunistically used as ICY-equivalent
    }

    enum ParseFailure: Error, CustomStringConvertible {
        case notM3U8                              // missing #EXTM3U
        case mixedMasterAndMedia                  // RFC 8216 §6.2.1 forbids both STREAM-INF and EXTINF
        case encryptedNotSupported                // EXT-X-KEY METHOD ≠ NONE
        case fragmentedMP4NotSupported            // EXT-X-MAP present
        case byteRangeNotSupported                // EXT-X-BYTERANGE present
        case noAudioVariant                       // master with only EXT-X-I-FRAME-STREAM-INF or only MEDIA
        case malformed(String)

        var description: String { /* human-readable */ ... }
    }

    /// Parse the body of a fetched playlist. URL is the playlist URL itself, used to
    /// resolve relative segment / variant URIs.
    static func parse(_ body: String, baseURL: URL) -> Result<Playlist, ParseFailure>
}
```

### 5.2 Parser behaviour

- **Magic check.** First non-empty, non-whitespace line must equal `#EXTM3U`. Otherwise `notM3U8`.
- **Tag detection pass (single line scan).**
  - Track booleans `hasStreamInf`, `hasInf`, `hasKeyEncrypted`, `hasMap`, `hasByteRange`, `hasIFrameOnly`, `hasMediaButNoStreamInf`.
  - On `#EXT-X-KEY:METHOD=NONE` (and only `NONE`) → no-op. On any other METHOD → `encryptedNotSupported`.
  - On `#EXT-X-MAP` → `fragmentedMP4NotSupported`.
  - On `#EXT-X-BYTERANGE` → `byteRangeNotSupported`.
  - If both `hasStreamInf` and `hasInf` → `mixedMasterAndMedia`.
  - If only `hasIFrameOnly` and no `hasStreamInf` and no `hasMediaWithAudio` → `noAudioVariant`.
- **Master parse.**
  - For each `#EXT-X-STREAM-INF:…\n<uri>` pair, read attribute list (CSV with quoted values), extract `BANDWIDTH`, `CODECS`, optional `RESOLUTION` (presence of RESOLUTION ≠ video-only), `AUDIO`, `VIDEO`, `URI`.
  - Detect audio-only: `isAudioOnly = codecs.contains("mp4a") && !codecs.contains("avc") && !codecs.contains("hvc") && !codecs.contains("hev")`. If `codecs` is missing, fall back to `isAudioOnly = (resolution == nil)` — this is heuristic but conservative for the v1 reject-or-pick logic.
  - Resolve variant URI relative to `baseURL`.
- **Media parse.**
  - Track running media sequence (start = `EXT-X-MEDIA-SEQUENCE` or 0).
  - For each `#EXTINF:duration[,title]\n<uri>`, build a `Segment` with `sequence = mediaSequence + indexInList`. Resolve URI relative to `baseURL`.
  - Track `EXT-X-DISCONTINUITY` as a flag on the *next* segment.
  - Set `endlistSeen = true` if `#EXT-X-ENDLIST` appears.
  - If `targetDuration == nil` and `endlistSeen == false` → `malformed("missing EXT-X-TARGETDURATION on live playlist")`. For VOD, default to `max(segment.duration)` if missing.
- **Robustness (parser-side — operates on already-decoded `String`).**
  - Ignore comments and unknown `#EXT-…` per RFC 8216 §4.1.
  - Trim BOM / CR / leading whitespace; accept LF or CRLF.
  - Reject overly long bodies — return `.malformed("playlist too large")` if body exceeds 1 MB (defensive cap; radio playlists are < 50 KB in practice).

- **Robustness (caller-side — fetch layer).**
  - The classifier (`StreamDecodePipeline.classifyM3UDialect`, §8.2) and the feeder (`HLSSegmentFeeder` playlist fetch / refresh) own body-decoding policy: try UTF-8 first; on failure, fall back to Latin-1; on still-failure, surface as classifier/feeder network/malformed error.
  - The parser sees only a `String` body. The decoded-bytes contract avoids two competing decoding code paths in `M3U8Parser` itself.

### 5.3 Tests (Swift Testing)

- Master with mixed audio + video variants → audio-only filter selects mp4a-only variant.
- Master with only `EXT-X-I-FRAME-STREAM-INF` → `noAudioVariant`.
- Master with only `EXT-X-MEDIA` and no `STREAM-INF` → `noAudioVariant`.
- Media VOD with `ENDLIST` → endlistSeen true, no targetDuration falls back to max(segment).
- Media live without `ENDLIST` and without `TARGETDURATION` → `malformed`.
- Media with `EXT-X-MEDIA-SEQUENCE: 12345` → sequence numbers start at 12345.
- Media with `EXT-X-DISCONTINUITY` between segments → flag on the following segment.
- Media with `EXT-X-KEY:METHOD=AES-128` → `encryptedNotSupported`.
- Media with `EXT-X-KEY:METHOD=NONE` followed by segments → parses successfully.
- Media with `EXT-X-MAP` → `fragmentedMP4NotSupported`.
- Media with `EXT-X-BYTERANGE` → `byteRangeNotSupported`.
- Mixed `STREAM-INF` + `EXTINF` → `mixedMasterAndMedia`.
- Missing `#EXTM3U` magic → `notM3U8`.
- Relative segment URIs resolve against playlist URL (e.g. base `https://x/y/playlist.m3u8` + `seg/0.aac` → `https://x/y/seg/0.aac`).
- BOM at start of body → handled.
- CRLF line endings → handled.
- Body > 1 MB → `.malformed("playlist too large")`.

## 6. Phase 2 — `AudioFileStreamParser.reset()` hook

**File:** `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` (modify — minimal surface).

### 6.1 Behaviour

Add a single new internal method:

```swift
/// Reset the parser to a clean state. Used between HLS segments after #EXT-X-DISCONTINUITY
/// to flush any partial-frame state in AudioFileStream. Format hint is preserved across reset
/// so AAC ADTS detection is not lost. Magic cookie is *not* re-emitted (it is the same across
/// AAC ADTS discontinuities for our v1 scope).
///
/// Concurrency: must be called from the parser's confinement queue (the decode queue).
func reset() {
    assertConfinement()
    // 1. Close current AudioFileStreamID (if any).
    // 2. Re-open with the same formatHint and the same selfPtr.
    // 3. Re-wire the property listener and packet callbacks (already retained on self).
    // 4. Clear inputFormat (the new stream ID will re-emit format if needed).
    // initError is overwritten only if reopen fails.
}
```

### 6.2 Why this is safe

- The C-API contract is `AudioFileStreamClose` then `AudioFileStreamOpen`. The decoder lifetime contract (Lesson 6: dispose decoder before parser close) is preserved because `reset()` is called *only* between segments while the decoder still has its existing magic cookie cached and its converter intact. We do **not** dispose the decoder during reset.
- The format hint is unchanged (still `kAudioFileAAC_ADTSType`), so the new stream ID will produce the same ASBD. The existing `onFormatAvailable` callback in `DecodeContext.handleFormatAvailable` (`StreamDecodePipeline.swift:591-610`) early-returns if `decoder != nil`. **Therefore the decoder is NOT swapped on reset**, even if the post-reset ASBD is different.
- We reuse the same `selfPtr` for the C callback context, so retain/release semantics are unchanged.

### 6.3 Format mismatch on post-reset (Oracle round 1, A-4)

If a post-reset segment delivers an ASBD that differs from the pre-reset ASBD, the decoder will continue producing PCM at the OLD ASBD-driven configuration — which would corrupt audio without warning.

**Detection at the parser level.** `AudioFileStreamParser` tracks `inputFormat` (`AudioFileStreamParser.swift:41`). After `reset()`, this field is cleared. When the new property listener fires `kAudioFileStreamProperty_DataFormat`, the parser compares the new ASBD against the pre-reset value (held in new fields `previousInputFormat: AudioStreamBasicDescription?` and `previousMagicCookie: Data?`).

**Comparison key (defence in depth):**
- `mFormatID` (e.g. `kAudioFormatMPEG4AAC`).
- `mSampleRate`.
- `mChannelsPerFrame`.
- `mFramesPerPacket`.
- `mBitsPerChannel`.
- `mFormatFlags` (AAC profile is encoded here — e.g. AAC-LC vs AAC-HE; a profile change requires a new converter even at matching sample rate).
- Magic cookie content (`AudioFileStreamGetProperty(kAudioFileStreamProperty_MagicCookieData)` after the new ASBD is reported). For AAC, the cookie includes the codec config; a change implies a different stream config that the existing `AudioConverter` cannot decode correctly.

**Fatal-state flag.** Add a `parserFatalState: Bool = false` field on `AudioFileStreamParser`. When set, all subsequent `parse(_:)` calls return early without invoking `AudioFileStreamParseBytes` and all C-callback-induced `onPackets` invocations are short-circuited at the boundary in the property/packet callbacks via:

```swift
guard !parser.parserFatalState else { return }
```

This flag is set by the post-reset comparison logic on mismatch (along with `onError(...)`), and is cleared only by a fresh `init` of the parser (i.e. a new pipeline `start(...)`).

If any compared field differs, the parser emits `onError("HLS segment format changed mid-stream (decoder swap not supported in v1)")` and sets `parserFatalState = true`. The pipeline routes this through `DecodeContext.onError` → `.decodeError(message)` → non-reconnectable. No further packets reach the decoder; the user gets a clear message; no silent corruption.

**Why not swap the decoder?** Decoder swap requires:
1. Disposing the existing `AudioConverter` (Lesson 6 ordering).
2. Flushing the ring buffer (in-flight PCM at the old format would still be valid in absolute terms but would change sample rate mid-buffer — produces clicks / pitch shift).
3. Re-emitting `onFormatReady` with the new sample rate (would break `PlaybackCoordinator`'s once-per-bridge-lifetime contract — `formatReadyFired` is single-shot).

These complications are out of scope for v1. **Decoder swap on post-discontinuity ASBD change is explicitly unsupported.** Documented as deferred in `placeholder.md` on merge.

**Practical note.** All AAC ADTS HLS radio observed in the field uses a single ASBD across discontinuities (sample rate + channel count + bit depth do not change because the encoder config is fixed at the publisher). The mismatch path is a defence-in-depth tripwire, not a routine fail.

### 6.4 Failure mode (reopen)

If `AudioFileStreamOpen` fails inside `reset()`, surface via `onError("AudioFileStream reopen failed: …")` on the decode queue. The pipeline routes this to `.decodeError` (non-reconnectable) — better to fail loudly than to silently produce no audio.

### 6.5 Tests

- Reset on a fresh parser is a no-op (no streamID open yet) — does not crash.
- Reset on an open parser closes + reopens; `parse(_:)` continues to deliver packets.
- Reset preserves the format hint.
- Reset followed by a *matching* ASBD on the new stream — no `onError`, parsing continues.
- Reset followed by a *mismatched* ASBD (e.g. different sample rate) — `onError` fired with the "format changed mid-stream" message; no further packets delivered.

## 7. Phase 3 — `HLSSegmentFeeder.swift`

**File:** `MacAmpApp/Audio/HLS/HLSSegmentFeeder.swift` (new). Estimated 300–400 LOC.

### 7.1 Type and isolation

```swift
/// Fetches HLS playlists, picks one variant from a master, downloads media segments
/// in order, refreshes live media playlists per RFC 8216 §6.3.4, and pushes segment
/// audio bytes into a caller-provided `feedAudio` closure.
///
/// **Confinement:** All mutable state is confined to `feederQueue` (a dedicated serial
/// DispatchQueue owned by the feeder). URLSession callbacks land on the session's
/// delegate operationQueue and immediately re-dispatch to `feederQueue` before
/// touching state. The caller's `feedAudio` closure may safely be invoked from
/// `feederQueue` — `DecodeContext.handleIncomingData` re-dispatches internally to its
/// own decode queue.
///
/// **Generation gating:** A `@Sendable () -> UInt64` getter for the pipeline's current
/// generation is captured at init. Before forwarding bytes via `feedAudio`, the feeder
/// checks `getGeneration() == capturedGeneration`. Mismatch → drop bytes (a restart is
/// in progress).
final class HLSSegmentFeeder: @unchecked Sendable {

    init(
        playlistURL: URL,
        prefetchedBody: String?,                                         // body from detection sniff, may be nil
        feedAudio: @escaping @Sendable (Data) -> Void,
        onParserReset: @escaping @Sendable () -> Void,                    // called on EXT-X-DISCONTINUITY
        onMetadataTitle: @escaping @Sendable (String) -> Void,           // EXTINF title best-effort
        onFinished: @escaping @Sendable (FeederTermination) -> Void,
        getPipelineGeneration: @escaping @Sendable () -> UInt64,
        capturedGeneration: UInt64
    )

    func start()
    func cancel()

    enum FeederTermination: Sendable {
        case vodCompleted             // mapped by pipeline → .streamFinished
        case decodeRejected(String)   // encrypted / fMP4 / TS / no-audio-variant / malformed-HLS — non-reconnectable
        case networkError(String, Int) // transient — reconnectable
        case httpServerError(Int)     // 5xx + 429 — reconnectable
        case httpClientError(Int)     // 4xx (non-429) — non-reconnectable
        // No malformedPlaylist case: permanent malformed bodies fold into decodeRejected;
        // transient malformed (5xx with partial body, etc.) fold into networkError/httpServerError.
        // See §9.1 for the rationale (avoids reconnect loops).
    }
}
```

### 7.2 Lifecycle (state machine on `feederQueue`)

```
init → start() →
    PARSE_INITIAL → fetch playlist (or use prefetchedBody) → M3U8Parser.parse →
        if Master → pick variant → recurse PARSE_INITIAL with variant URI
        if Media VOD → enqueue all segments → DOWNLOAD_LOOP → onFinished(.vodCompleted)
        if Media Live → enqueue current segments → DOWNLOAD_LOOP + REFRESH_LOOP →
            (continues until cancel() or refresh sees ENDLIST + queue drains)
    DOWNLOAD_LOOP (serial):
        pop next segment → URLSession data task → onData (delegate q) → re-dispatch to feederQueue
        → check generation → invoke feedAudio(bytes)
        → on segment complete → if discontinuity flag → onParserReset() then advance
    REFRESH_LOOP (live):
        every refreshInterval → fetch playlist → diff sequence numbers → append new segments → reschedule
```

### 7.3 Variant selection (master playlist)

1. Filter `variants` to `isAudioOnly == true`.
2. If empty after filter, fail with `decodeRejected("No audio variant in HLS playlist")`.
3. Pick the highest `bandwidthBitsPerSec ≤ 320_000`. If none meet that ceiling, pick the lowest bandwidth available (fail-open for stations with single 384 kbps variants).
4. Emit a debug log of the chosen variant URI + bandwidth.

### 7.4 Media playlist refresh (RFC 8216 §6.3.4)

State (on `feederQueue`):
- `targetDuration: TimeInterval`
- `lastSeenMediaSequence: UInt64`
- `lastEnqueuedMediaSequence: UInt64?`
- `playlistChangedOnLastReload: Bool`
- `endlistSeen: Bool`

Refresh interval:
- First reload: `targetDuration` seconds (conservative default within the half-to-full window).
- Reload where `mediaSequence` advanced (playlist changed): wait `targetDuration`.
- Reload where `mediaSequence` unchanged and segment list identical: wait `max(targetDuration / 2, 1.0)`.
- After a single failed refresh: wait `targetDuration`, retry once. Two consecutive failures → `networkError(...)` → terminate.

Sequence diff:
- New segments are those with `sequence > lastEnqueuedMediaSequence`.
- If `mediaSequence` jumps backward (server reset), log a warning, reset `lastEnqueuedMediaSequence = nil`, treat the entire new list as fresh segments.
- If `endlistSeen` newly appears, mark the feeder VOD-finalised; stop scheduling refreshes; on queue drain → `onFinished(.vodCompleted)`.

Buffer-ahead policy: keep at most 3 enqueued-but-not-downloaded segments. If the refresh has more new segments than that, accept all but rely on the serial download loop to apply backpressure (the refresh loop does not pause on the download loop — the queue absorbs bursts).

### 7.5 Segment download and feeding

For each enqueued segment:

1. Validate format up front. Segment URL extension AND/OR Content-Type sniff:
   - Allowed: `.aac` extension OR `audio/aac` / `audio/aacp` / `audio/x-aac` Content-Type. → continue.
   - Rejected: `.ts` / `.m4s` / `.mp4` extension OR `video/mp2t` / `audio/mp4` / `video/mp4` Content-Type → `decodeRejected("HLS segment format not supported (only AAC ADTS in v1)")`.
   - Ambiguous (no extension, no Content-Type): allow first segment, sniff the first 7 bytes for ADTS sync (`0xFF F1` or `0xFF F9`); reject otherwise.
2. URLSession data task (own session — see 7.6), `cachePolicy = .reloadIgnoringLocalCacheData` for segments too (some CDNs serve stale 200s otherwise).
3. On `urlSession(_:dataTask:didReceive:)` — re-dispatch to `feederQueue`:
   - If `getPipelineGeneration() != capturedGeneration` → drop (pipeline restart).
   - If `pauseEpoch != taskEpoch` → drop (pause/resume cycle invalidated this task).
   - Otherwise → `feedAudio(data)`.
4. On `urlSession(_:task:didCompleteWithError:)`:
   - On error → map to `networkError` and terminate.
   - On non-2xx HTTP → map to `httpClientError` / `httpServerError` and terminate (or, for transient 502/503/504/429, count as a single refresh failure and let the refresh policy take over).
   - On success → if next segment in queue has its discontinuity flag set, call `onParserReset()` *before* the next `feedAudio` for that segment.

### 7.6 URLSession ownership

The feeder owns its own `URLSession` (separate from `StreamDecodePipeline`'s session). Rationale:

- Different timeouts (segments are short, bounded; playlists are tiny). `timeoutIntervalForRequest = 15`, `timeoutIntervalForResource = 60`.
- Different cache policy (always-reload for live).
- Clean cancel-on-stop via `invalidateAndCancel()`.
- Mirrors the existing pattern in `StreamDecodePipeline`.

The session's delegate is a small NSObject proxy (mirroring `SessionDelegateProxy` in `StreamDecodePipeline.swift`), `fileprivate` to `HLSSegmentFeeder.swift`. No retain-cycle: the proxy holds a weak reference to a `FeederCallbackTarget` actor-free class that re-dispatches to `feederQueue`.

#### 7.6.1 Test seam (resolves Oracle round 1 N-3)

The feeder needs a single test seam, not two. The seam is a small protocol covering only the methods the feeder uses:

```swift
protocol HLSURLSessionAdapter: Sendable {
    /// Fetch a playlist body as text. Used for initial playlist + every refresh.
    func fetchPlaylist(_ request: URLRequest) async throws -> (Data, URLResponse)

    /// Stream a segment's bytes via a delegate-driven data task. The adapter delivers the HTTP
    /// response BEFORE any bytes are forwarded — `onResponse` returns a verdict that gates `onData`.
    /// If `onResponse` returns `.reject`, the data task is cancelled and `onComplete` is invoked
    /// with the supplied termination reason; no `onData` callbacks fire.
    /// The returned `URLSessionDataTask` may be cancelled directly by the feeder for fast teardown.
    func streamSegment(
        _ request: URLRequest,
        onResponse: @Sendable @escaping (HTTPURLResponse) -> SegmentResponseVerdict,
        onData: @Sendable @escaping (Data) -> Void,
        onComplete: @Sendable @escaping (SegmentCompletion) -> Void
    ) -> URLSessionDataTask

    /// Cancel any in-flight tasks and the underlying session.
    func invalidateAndCancel()
}

enum SegmentResponseVerdict: Sendable {
    case allow                  // Forward subsequent bytes via onData.
    case reject(SegmentCompletion)  // Cancel task; deliver onComplete with the supplied reason. No onData.
}

enum SegmentCompletion: Sendable {
    case success                                 // Task completed normally — onData delivered all bytes.
    case networkError(String, Int)               // Underlying URLError. → networkError termination.
    case httpClientError(Int)                    // 4xx (non-429). → httpClientError termination.
    case httpServerError(Int)                    // 5xx + 429. → httpServerError termination.
    case unsupportedFormat(String)               // Content-Type or extension rejection. → decodeRejected.
    case cancelled                               // Adapter or feeder cancel. Drop silently.
}
```

The `onResponse` hook is the seam through which the feeder enforces:
- Status code → success (2xx) / `httpClientError` (4xx non-429) / `httpServerError` (5xx + 429).
- Content-Type → AAC ADTS allowed; TS / fMP4 / video/* → `.reject(.unsupportedFormat(...))`.
- Optional ADTS sync sniff: not done in `onResponse` (no body yet); first 7 bytes via `onData` if Content-Type was ambiguous (no extension AND no Content-Type) — see §7.5 step 1.

The Live adapter forwards `urlSession(_:dataTask:didReceive response:completionHandler:)` to `onResponse`, calls `completionHandler(.cancel)` on `.reject` and `completionHandler(.allow)` on `.allow`. The Stub adapter exercises both paths with synthesised HTTPURLResponse fixtures.

Production implementation (`HLSURLSessionLiveAdapter`):
- Owns a private `URLSession` with the feeder's required configuration (timeouts, no-cache, dedicated delegate operationQueue).
- Maps `fetchPlaylist` to `URLSession.data(for:)` on its own session (NOT `URLSession.shared`).
- Maps `streamSegment` to `URLSession.dataTask(with:)` with a delegate that forwards `didReceive(data:)` and `didCompleteWithError:`.
- Maps `invalidateAndCancel` to `URLSession.invalidateAndCancel()`.

Test implementation (`HLSURLSessionStubAdapter`, in tests target):
- In-memory map of URL → response body / status code.
- Synchronous queue ordering of stub responses (e.g. "playlist v1, then v2, then v2-with-ENDLIST").
- Hook for inducing failures (network error, 5xx, 4xx).

Both implementations satisfy the same contract. No `URLSession.shared` reference appears in the production feeder — the cancellation guarantee is preserved end-to-end.

### 7.7 Cancel / teardown

`cancel()` on any thread:
- Sets `isCancelled = true` (atomic flag — read on `feederQueue` and from the proxy thread for early-return).
- Re-dispatches to `feederQueue` to:
  - Cancel current `URLSessionDataTask`.
  - Cancel `refreshTimer` (a `DispatchSourceTimer` rather than a `Task` — avoids Swift 6.2 task-leak concerns and matches existing pipeline patterns).
  - Call `urlSession.invalidateAndCancel()`.
  - Drop pending segment queue.

After cancel, no further `feedAudio`, `onParserReset`, `onMetadataTitle`, or `onFinished` invocations occur.

### 7.8 Two-token gating: pipelineGeneration + pauseEpoch

The feed path enforces **two** orthogonal stale-callback gates. Before *any* `feedAudio`, `onResponse`, or `onComplete` work in the feeder is allowed to influence post-resume state, both gates must pass:

1. **Pipeline generation gate** — captured at feeder init. Rejects callbacks across pipeline restart (`StreamDecodePipeline.start(...)` / `stopInternal()`). Implementation: `@Sendable () -> UInt64` getter (`OSAllocatedUnfairLock<UInt64>` snapshot, see §8.3.1) compared against `capturedGeneration`.

2. **Pause epoch gate** — `pauseEpoch: UInt64` field on the feeder, owned by `feederQueue`. Rejects callbacks across pause/resume cycles within the same pipeline lifetime. Bumped in both `pauseByUser` and `resumeByUser` (§8.5.1). Each segment task captures the current value as `taskEpoch` at creation; every callback re-checks `pauseEpoch == taskEpoch` on `feederQueue` before doing work.

Both gates protect different invariants and must coexist (see §8.5.1 "Why two tokens" rationale). Either failure drops bytes silently; debug-level log only — these races are expected during restart and pause/resume.

### 7.9 EXTINF title pass-through (best effort)

If a segment's `EXTINF` title is non-empty AND differs from the last emitted title, call `onMetadataTitle(title)`. Pipeline maps this to a synthetic `ICYFramer.ICYMetadata` (title-only, artist nil) and forwards via the existing `onMetadata` callback. Stations without titles see no behaviour change.

### 7.10 Tests (Swift Testing, mocked URLSession)

- Master + media (VOD, 4 segments) → all segments downloaded in order, `vodCompleted` fired.
- Master picks audio-only variant when both audio and video are present.
- Master with only video variants → `decodeRejected`.
- Live media playlist refresh: stub returns playlist v1 (3 segments), then v2 (3 + 2 new), then v2 with ENDLIST → exactly 5 distinct segments downloaded; `vodCompleted` after the queue drains.
- Live refresh sees backward `MEDIA-SEQUENCE` jump → resets sequence baseline, continues.
- Live refresh: 2 consecutive failures → `networkError` fired.
- `EXT-X-DISCONTINUITY` between segments 2 and 3 → `onParserReset` called exactly once, between feeding segment 2's last byte and segment 3's first byte.
- Encrypted segment (`EXT-X-KEY:METHOD=AES-128`) → `decodeRejected("Encrypted streams not supported")`, no segments downloaded.
- fMP4 detected via `EXT-X-MAP` → `decodeRejected`.
- Stale generation: getter returns `capturedGeneration + 1` after start → `feedAudio` is never invoked.
- Cancel mid-segment → `feedAudio` invocations stop within one URLSession callback; no further callbacks fire after `cancel()` returns.

## 8. Phase 4 — Detection integration

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` (modify — bounded extension).

### 8.1 New `StreamTerminationReason` cases

Add two cases to the enum (keeps existing 8 cases untouched):

```swift
enum StreamTerminationReason: Sendable {
    // ... existing 8 cases ...
    case streamFinished       // VOD ended cleanly. NOT reconnectable. Distinct from .userStopped (user UX clarity).
    case unsupportedFormat(String) // HLS encrypted/fMP4/TS/no-audio. NOT reconnectable. Distinct from .decodeError (caller intent: surface a clearer message).
}
```

`unsupportedFormat` is a deliberate refinement of `.decodeError` for the HLS rejection cases: the user-facing message becomes "Stream format not supported" (specific) instead of "Unsupported audio format" (generic). It is non-reconnectable.

`streamFinished` separates "VOD completed successfully" from `.userStopped` (which is fired by the `stop()` API entry-point and has empty `userMessage`). Both are non-reconnectable; `streamFinished` is for cleaner Now-Playing state when a finite-duration HLS asset reaches its end.

(Per research §"Live vs VOD Handling", the plan picks the **add-new-case** option for clarity. Zero risk of breaking existing reconnect behaviour because both new cases are non-reconnectable.)

### 8.2 Detection flow inside `start(url:)`

Extend the current 2-branch logic to a 3-branch flow:

```text
start(url:)
  ├─ stopInternal()
  ├─ generation += 1, capture currentGeneration
  ├─ ringBuffer assigned + flushed
  ├─ formatReadyFired = false
  │
  ├─ if isLikelyM3UDialect(url)  // ext == "m3u8" OR ext == "m3u"
  │     → Task { @MainActor [weak self] in
  │           guard let self, currentGeneration == self.generation else { return }
  │           do {
  │               let outcome = try await Self.classifyM3UDialect(url)  // fetch + sniff
  │               guard currentGeneration == self.generation else { return }
  │               switch outcome {
  │               case .hls(let body):
  │                   self.startHLSStream(playlistURL: url, prefetchedBody: body,
  │                                       ringBuffer: ringBuffer, generation: currentGeneration)
  │               case .legacyM3U(let resolvedAudioURL):
  │                   self.startDirectStream(url: resolvedAudioURL,
  │                                          ringBuffer: ringBuffer,
  │                                          generation: currentGeneration)
  │               case .legacyPLS(let resolvedAudioURL):
  │                   self.startDirectStream(url: resolvedAudioURL, ...)
  │               }
  │           } catch let error as ClassifyError {
  │               self.setState(.error(error.userMessage))
  │               self.onTermination?(error.terminationReason)
  │           }
  │         }
  │
  ├─ else if isLegacyPlaylistURL(url) (.pls only — .m3u8/.m3u handled above)
  │     → existing resolvePlaylistURL → startDirectStream
  │
  └─ else
        → startDirectStream(url: url, ...)
```

`isLikelyM3UDialect(url)` returns true for `.m3u`, `.m3u8` (case-insensitive). `.pls` keeps existing behaviour.

`classifyM3UDialect(url)` (new private static, async, throws `ClassifyError`):
1. Fetch the body once with `URLSession.shared.data(from:)`. (Re-using `URLSession.shared` is fine here — this is a one-shot text fetch, not a streaming session.)
2. Map non-2xx to `ClassifyError.httpClientError(code)` or `ClassifyError.httpServerError(code)`.
3. Decode body as UTF-8 (Latin-1 fallback).
4. **Sniff** (authoritative):
   - First non-blank line == `#EXTM3U`? If no → legacy M3U; resolve via existing `M3UParser.parse(content:relativeTo:)` and return `.legacyM3U(firstStreamURL)`. If `M3UParser` fails → attempt `parsePLS` next; if that also fails → `ClassifyError.malformedLegacyPlaylist(message)` (reconnectable per §8.2 mapping table below).
   - Otherwise, scan remaining lines for any `#EXT-X-` prefix → `.hls(body)`. If the body has `#EXTM3U` but no `#EXT-X-` tags, treat as legacy M3U (some legacy servers ship `#EXTM3U` headers without HLS extensions).
   - If the sniff said HLS (`.hls(body)`) and the M3U8 parser then rejects the body inside the HLS branch (e.g. `M3U8Parser.parse` returns `.encryptedNotSupported`, `.fragmentedMP4NotSupported`, `.notM3U8`, etc.), this is a **feeder-side** decision (`HLSSegmentFeeder`'s parse step, §7.2 PARSE_INITIAL), which produces `FeederTermination.decodeRejected`. The classifier itself does **not** invoke `M3U8Parser` — it only does the cheap sniff. `malformedHLSPlaylist` is therefore a **feeder-only** outcome, never a classifier outcome.
5. Content-Type promotion: **deferred for v1** (resolves Oracle round 1 N-1 contradiction). Only `.m3u8` / `.m3u` URLs go through `classifyM3UDialect`. URLs without those extensions go through the existing `startDirectStream` path; if the body returned is HLS-typed by Content-Type, the existing path will fail loudly with a decode error — the user retries with a `.m3u8` URL or reports it. Document as `placeholder.md` deferral on merge so we can revisit if a real-world station ships HLS at an extension-less endpoint. (Open Question 1 from research.md is **closed** — the answer is "no Content-Type promotion in v1"; the speculative "yes, on first response only" alternative was contradictory and is rejected.)

`ClassifyError` (mapping carried at error-construction time, not deferred to §9.1):

| ClassifyError case | When | Maps to | Reconnectable? |
|---|---|---|:---:|
| `network(message, code)` | URLSession failure during the one-shot body fetch | `.networkError(message, code)` | depends on code (existing rules) |
| `httpClientError(code)` | 4xx (non-429) on the body fetch | `.httpClientError(code)` | no |
| `httpServerError(code)` | 5xx + 429 on the body fetch | `.httpServerError(code)` | yes |
| `malformedLegacyPlaylist(message)` | Body sniff said legacy M3U/PLS but BOTH `M3UParser` AND `parsePLS` rejected | `.playlistResolutionFailed(message)` | yes (legacy parser is lenient; transient DNS/CDN blip plausible) |

**There is no `ClassifyError.malformedHLSPlaylist` case** — the classifier does only the cheap sniff (`#EXTM3U` magic + `#EXT-X-` scan). Once the sniff routes to HLS, the body is handed to `HLSSegmentFeeder`, and any rejection by `M3U8Parser` is a feeder-side outcome (`FeederTermination.decodeRejected` → `.unsupportedFormat`, non-reconnectable). This split-by-responsibility ensures the §9.1 termination handler never sees an HLS body returning `.playlistResolutionFailed` — eliminating the loop risk by construction.

### 8.3 New `startHLSStream(playlistURL:prefetchedBody:ringBuffer:generation:)` method

Build a `DecodeContext` with `formatHint = kAudioFileAAC_ADTSType` (HLS v1 is AAC ADTS only). Do **not** create a `URLSession`/`SessionDelegateProxy` (the feeder owns those). Do **not** call `context.configureFramer(metaInterval:)` — HLS has no ICY (the framer's default `metaInterval = 0` is already pass-through; verify no double-configure path exists).

#### 8.3.1 Generation snapshot mechanism (deadlock-safe)

Introduce a single new field on `StreamDecodePipeline`:

```swift
// Generation snapshot — readable from any thread (e.g. HLSSegmentFeeder's feederQueue).
// Wraps a UInt64 in OSAllocatedUnfairLock for Swift 6.2-idiomatic, TSan-clean,
// deadlock-safe access without an actor hop. Mirrors the locking pattern used by
// EqualizerController for cross-thread state reads.
private let generationSnapshot = OSAllocatedUnfairLock<UInt64>(initialState: 0)

// Always update alongside `generation`. Called from the same MainActor body that
// mutates `generation`.
private func updateGenerationSnapshot() {
    generationSnapshot.withLock { $0 = generation }
}
```

Call sites that mutate `generation` (every `start(...)` and every `stopInternal()`) **must** call `updateGenerationSnapshot()` immediately after the increment. This is the only safe path to expose generation to the feeder; do **not** use `MainActor.assumeIsolated` from `feederQueue`.

#### 8.3.2 Wiring the feeder

```swift
let captured = currentGeneration
let weakContext = WeakBox(context)  // local utility — avoids capturing context in closures by strong ref

let feedAudio: @Sendable (Data) -> Void = { data in
    weakContext.value?.handleIncomingData(data)
}

let onParserReset: @Sendable () -> Void = {
    weakContext.value?.resetParserOnDecodeQueue()  // see §8.4
}

let onMetadataTitle: @Sendable (String) -> Void = { [weak self] title in
    Task { @MainActor [weak self] in
        guard let self, captured == self.generation else { return }
        let metadata = ICYFramer.ICYMetadata(title: title, artist: nil)
        self.onMetadata?(metadata)
    }
}

let onFinished: @Sendable (HLSSegmentFeeder.FeederTermination) -> Void = { [weak self] reason in
    Task { @MainActor [weak self] in
        guard let self, captured == self.generation else { return }
        self.handleHLSTermination(reason, generation: captured)
    }
}

// Generation getter: reads the OSAllocatedUnfairLock-protected snapshot — safe from
// any thread, no actor hop, no deadlock.
let snapshotRef = self.generationSnapshot   // capturing the let by value
let getGeneration: @Sendable () -> UInt64 = {
    snapshotRef.withLock { $0 }
}

let feeder = HLSSegmentFeeder(
    playlistURL: playlistURL,
    prefetchedBody: prefetchedBody,
    feedAudio: feedAudio,
    onParserReset: onParserReset,
    onMetadataTitle: onMetadataTitle,
    onFinished: onFinished,
    getPipelineGeneration: getGeneration,
    capturedGeneration: captured
)
hlsFeeder = feeder
decodeContext = context
setState(.connecting)
feeder.start()
```

### 8.4 Wiring `parser.reset()` through `DecodeContext`

`DecodeContext` is queue-confined (decode queue). Add a single new internal method:

```swift
func resetParserOnDecodeQueue() {
    decodeQueue.async { [self] in
        guard !isShutdown else { return }
        parser?.reset()  // new method from Phase 2
    }
}
```

The closure passed to the feeder calls this method. The feeder may call it from `feederQueue`; the `decodeQueue.async` re-dispatch keeps the parser confinement intact. Reset is *advisory* — if the parser pointer is nil (already torn down), the reset is dropped silently.

### 8.5 Cancelling the feeder in `stopInternal()`

Extend the existing `stopInternal()`:

```swift
private func stopInternal() {
    generation &+= 1
    updateGenerationSnapshot()  // for HLS feeder generation gating

    dataTask?.cancel(); dataTask = nil
    urlSession?.invalidateAndCancel(); urlSession = nil
    delegateProxy = nil

    hlsFeeder?.cancel(); hlsFeeder = nil   // NEW

    decodeContext?.shutdown(); decodeContext = nil
    ringBuffer = nil
    audioWorkgroup = nil
    formatReadyFired = false
}
```

### 8.5.1 `pauseByUser()` / `resumeByUser()` for HLS (post-S3-1B integration)

> **S3-1B (`stream-pause-tail`) merges before this task** and replaces `pause()`/`resume()` with async barrier-aware variants `pauseByUser()` / `resumeByUser()`. See `tasks/stream-pause-tail/plan.md` §3.5. The HLS branch must integrate with these, **not** the legacy `pause()`/`resume()`. This subsection specifies the integration.

Post-S3-1B API as of merge:

- `StreamDecodePipeline.pauseByUser()` (async): suspends `dataTask`, awaits a decode-queue barrier that sets `DecodeContext.isPausedByUser = true`, calls `decoder?.clearQueue()`, then `ringBuffer.flush(newGeneration: false)`.
- `StreamDecodePipeline.resumeByUser()` (async): resets prebuffer tracking on the decode queue, clears `isPausedByUser`, then resumes `dataTask`.
- `StreamPlayer.pause()` (sync facade): sets `userPaused = true`, calls `silenceGateForwarder?(true)`, awaits `pipeline.pauseByUser()`.

For the HLS branch, `pipeline.pauseByUser()` / `pipeline.resumeByUser()` must do the right thing for an HLS feeder, which has:
- A live-refresh `DispatchSourceTimer`.
- A serial segment-download loop (current `URLSessionDataTask` may be in flight).
- A pending segment queue.

**Decision (v1):** the HLS feeder gets two new methods that mirror the pipeline contract:

```swift
// Inside HLSSegmentFeeder
func pauseByUser(completion: @escaping @Sendable () -> Void)
func resumeByUser(completion: @escaping @Sendable () -> Void)
```

`pauseByUser`:
1. Re-dispatches to `feederQueue`.
2. Cancels the current `URLSessionDataTask` (if any) — does NOT call `urlSession.invalidateAndCancel()` (that would prevent resume).
3. Suspends the `DispatchSourceTimer` (refresh loop).
4. Sets `isFeederPaused = true` (queue-confined flag — feeder ignores any in-flight callback after this point, dropping bytes silently).
5. Drops the current segment's accumulated buffer (we will re-download from scratch on resume — segment boundaries are clean for AAC ADTS, so this does not corrupt the parser).
6. Calls `completion()`.

`resumeByUser` (ordering matters; this mirrors S3-1B's `pauseByUser` barrier discipline in reverse):
1. Re-dispatches to `feederQueue`.
2. Clears `isFeederPaused` (queue-confined flag drop). At this point the feeder is allowed to download bytes again, but no segment is in flight yet, so no `feedAudio` call has been made.
3. Calls `onParserReset()` (Phase 2 / §8.5.2). The parser is now in a fresh state on the decode queue.
4. **Re-fetches the playlist** (always; live and VOD alike). Rationale: HLS pause may be long; the live window may have advanced past our last sequence number, and even VOD playlists are cheap to re-fetch. Re-fetching the playlist guarantees we land at a valid live edge or at the same VOD position.
5. Resumes the `DispatchSourceTimer` (live only).
6. Calls `completion()`. **At this point** `pipeline.resumeByUser()` proceeds to its next step (clearing `isPausedByUser` on the decode side, per S3-1B §3.5).
7. The first segment download begins; first `feedAudio` call lands AFTER `pipeline.resumeByUser()` has cleared `isPausedByUser` on the decode side — so the bytes flow through cleanly.

The `pipeline.resumeByUser()` HLS branch (mirror of §8.5.1's pause branch):

```swift
func resumeByUser() async {
    guard case .paused = state else { return }

    if let feeder = hlsFeeder {
        // Step 1 (mirror of S3-1B step 1): reset prebuffer tracking on decode side.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            guard let ctx = decodeContext else { cont.resume(); return }
            ctx.resetPrebufferTracking { cont.resume() }
        }
        // Step 2: feeder-side resume (drops isFeederPaused, calls onParserReset, re-fetches playlist).
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            feeder.resumeByUser { cont.resume() }
        }
        // Step 3 (mirror of S3-1B step 3): clear isPausedByUser on decode side, allowing
        // handleIncomingData/handlePackets to process bytes again.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            guard let ctx = decodeContext else { cont.resume(); return }
            ctx.setPausedByUser(false) { cont.resume() }
        }
        setState(.playing)
        return
    }

    // Existing progressive path (from S3-1B):
    // ...
}
```

**Ordering invariant:** the feeder may not invoke `feedAudio` for *new* (post-resume) bytes until after step 3 has cleared `isPausedByUser` on the decode queue. The pipeline-level `generation` token is **NOT** sufficient for this — `generation` is bumped only on `start(...)` / `stopInternal()`, not on pause/resume. We need a separate strict-ordering token for pause/resume.

**Pause epoch gate (Oracle round 3, A-1).** Add a `pauseEpoch: UInt64` counter on `HLSSegmentFeeder`, owned and mutated on `feederQueue`:

- Initial value: 0.
- Incremented in `pauseByUser` (step 4 of §8.5.1, between "set isFeederPaused = true" and "drop current segment buffer").
- Incremented in `resumeByUser` (step 2 of §8.5.1, between "clear isFeederPaused" and "re-fetch playlist").

Every segment download captures the current `pauseEpoch` at task-creation time as `taskEpoch`. The adapter's `onResponse`, `onData`, and `onComplete` callbacks all check `pauseEpoch == taskEpoch` (read on `feederQueue`) before doing any work. If they diverge, the callback drops silently — this is a stale-callback from a pre-pause or pre-resume task that must not influence post-resume state. Concretely:

```swift
let taskEpoch = self.pauseEpoch  // captured on feederQueue at start of segment

adapter.streamSegment(
    request,
    onResponse: { [weak self] resp in
        // Re-dispatch to feederQueue immediately.
        var verdict: SegmentResponseVerdict = .reject(.cancelled)
        self?.feederQueue.sync {
            guard let self, self.pauseEpoch == taskEpoch else { return }
            verdict = self.classifySegmentResponse(resp)
        }
        return verdict
    },
    onData: { [weak self] data in
        self?.feederQueue.async { [weak self] in
            guard let self, self.pauseEpoch == taskEpoch, !self.isFeederPaused else { return }
            // Generation gate (§7.8): also check pipeline generation before feedAudio.
            guard self.getPipelineGeneration() == self.capturedGeneration else { return }
            self.feedAudio(data)
        }
    },
    onComplete: { [weak self] reason in
        self?.feederQueue.async { [weak self] in
            guard let self, self.pauseEpoch == taskEpoch else { return }
            self.handleSegmentCompletion(reason)
        }
    }
)
```

This makes the resume invariant *strict*: any callback from a pre-pause segment task is rejected by the epoch check, regardless of timing. The pipeline-generation gate (§7.8) handles the orthogonal concern of pipeline restart (`start(...)` / `stopInternal()`).

**Why two tokens, not one?**
- `pauseEpoch` rejects stale callbacks across pause/resume cycles within the same pipeline lifetime — the feeder is reused.
- `pipelineGeneration` rejects stale callbacks across pipeline restarts — the feeder is replaced.
- They protect different invariants. A single token would over-restrict (a pause-resume cycle would invalidate the captured generation, triggering the feeder's no-output sentinel — incorrect).

`StreamDecodePipeline.pauseByUser()` (modified by S3-1B) gets one new branch:

```swift
func pauseByUser() async {
    guard case .playing = state else { return }

    if let feeder = hlsFeeder {
        // HLS path: feeder owns the network, no dataTask to suspend at pipeline level.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            feeder.pauseByUser { cont.resume() }
        }
        // Still flush the decode side so any partial segment bytes don't replay on resume.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            guard let ctx = decodeContext else { cont.resume(); return }
            ctx.setPausedByUser(true) { cont.resume() }
        }
        setState(.paused)
        return
    }

    // Existing progressive path (from S3-1B):
    dataTask?.suspend()
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        guard let ctx = decodeContext else { cont.resume(); return }
        ctx.setPausedByUser(true) { cont.resume() }
    }
    setState(.paused)
}
```

`resumeByUser()` mirrors with the feeder branch resuming via `feeder.resumeByUser`.

### 8.5.2 The `parser.reset()` call on resume

When a paused HLS feeder resumes, it re-fetches the playlist and starts the next segment fresh. Because we just dropped a partial segment buffer in `pauseByUser`, the parser may have ingested partial AAC ADTS frame data. **Always call `onParserReset()` on resume**, before the first feed of post-resume bytes. This is a single additional invocation of the same hook used for `EXT-X-DISCONTINUITY` (Phase 2) — no new mechanism, just an additional call site. Implemented inside `HLSSegmentFeeder.resumeByUser` after step 2 (clear `isFeederPaused`) and before step 3 (re-fetch playlist).

### 8.5.3 Why this matters for cohesion with S3-1B

S3-1B's `pauseByUser` flushes the ring buffer and quiesces the decode queue. The HLS feeder's `pauseByUser` quiesces the network/segment side. The two run sequentially in `pipeline.pauseByUser()`'s HLS branch (feeder pause → decode-side pause). Result: at the time `pauseByUser()` returns to `StreamPlayer.pause()`, both the producer (feeder) and the decoder (DecodeContext) are quiesced, the ring buffer is flushed, and the silence gate has already been raised by `StreamPlayer.pause()` *before* awaiting `pipeline.pauseByUser()`. The silence-gate-then-quiesce-then-flush sequence is preserved end-to-end.

### 8.5.4 Pause UX trade-off (documented in `placeholder.md` on merge)

On HLS resume, the user will hear a brief warmup (re-fetch playlist + download fresh segment + prebuffer to the resume threshold) before audio resumes. S3-1B's existing 1-s warmup timeout in `StreamPlayer.startResumeWarmup` covers this. If the prebuffer threshold is not reached within 1 s, the live-edge fallback fires (a fresh `pipeline.start(url:)` is issued — for HLS, that re-creates a fresh feeder on the same playlist URL).

### 8.6 Detection helpers (new private static helpers)

```swift
private static func isLikelyM3UDialect(_ url: URL) -> Bool {
    ["m3u8", "m3u"].contains(url.pathExtension.lowercased())
}

private static func classifyM3UDialect(_ url: URL) async throws -> ClassifyOutcome { ... }
```

`isPlaylistURL(_:)` (existing) is adjusted to return true only for `.pls` once `.m3u8`/`.m3u` route through the new path. (Or: leave it untouched and gate on `isLikelyM3UDialect` first in `start(url:)`. Pick the latter for minimal diff.)

## 9. Phase 5 — `StreamDecodePipeline` HLS termination handler

**File:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`.

### 9.1 `handleHLSTermination(_:generation:)`

> **Termination mapping rule (Oracle round 1, A-1):** Permanent HLS parse/format failures **must not** map to `.playlistResolutionFailed` (which is reconnectable in `StreamPlayer.isReconnectable` and would cause a reconnect loop on a permanently broken playlist). They map to `.unsupportedFormat` (non-reconnectable). Reserve `.playlistResolutionFailed` strictly for *transient* legacy playlist resolution failures (DNS blip during the initial fetch).

The `FeederTermination` enum (§7.1) deliberately does **not** include a `malformedPlaylist` case. Outcomes from the feeder's parse step fall into one of two existing cases:

- **Transient malformed (network/DNS blip during initial playlist fetch, bad gateway, etc.):** the feeder produces `.networkError(...)` or `.httpServerError(...)` — these reach `handleHLSTermination` and are reconnectable.
- **Permanent malformed (`M3U8Parser.ParseFailure` other than network — `notM3U8`, `mixedMasterAndMedia`, `noAudioVariant`, `malformed(_)` body):** the feeder produces `.decodeRejected(message)`. These reach `handleHLSTermination` as `.unsupportedFormat` (non-reconnectable).

The classification is decided at the parse site inside the feeder, never deferred to `handleHLSTermination`.

Updated `FeederTermination` enum (revised from §7.1):

```swift
enum FeederTermination: Sendable {
    case vodCompleted             // → .streamFinished (non-reconnectable)
    case decodeRejected(String)   // permanent format/parse rejection → .unsupportedFormat (non-reconnectable)
    case networkError(String, Int) // transient → .networkError (reconnectable per existing rules)
    case httpServerError(Int)     // 5xx + 429 → .httpServerError (reconnectable)
    case httpClientError(Int)     // 4xx (non-429) → .httpClientError (non-reconnectable)
}
```

Handler:

```swift
@MainActor
private func handleHLSTermination(_ reason: HLSSegmentFeeder.FeederTermination,
                                  generation: UInt64) {
    guard generation == self.generation else { return }
    stopInternal()

    switch reason {
    case .vodCompleted:
        setState(.idle)
        onTermination?(.streamFinished)
    case .decodeRejected(let message):
        setState(.error(message))
        onTermination?(.unsupportedFormat(message))
    case .networkError(let message, let code):
        setState(.error(message))
        onTermination?(.networkError(message, code))
    case .httpServerError(let code):
        setState(.error("HTTP \(code)"))
        onTermination?(.httpServerError(code))
    case .httpClientError(let code):
        setState(.error("HTTP \(code)"))
        onTermination?(.httpClientError(code))
    }
}
```

Cross-reference: `ClassifyError` (defined in §8.2) carries its mapping at construction-time. The HLS-side malformed body becomes `.unsupportedFormat` and the legacy-side malformed body becomes `.playlistResolutionFailed` — see §8.2 for the authoritative table. `handleHLSTermination` therefore never sees a `.playlistResolutionFailed` originating from an HLS body.

### 9.2 `userMessage` mappings for new cases (in `StreamPlayer.swift` extension)

```swift
case .streamFinished:    return "Stream ended"
case .unsupportedFormat(let msg):
    // Caller-supplied message (already short, e.g. "Encrypted streams not supported").
    // Title bar truncation is handled by the UI layer — no string slicing here.
    return msg
```

## 10. Phase 6 — `StreamPlayer.isReconnectable` update

**File:** `MacAmpApp/Audio/StreamPlayer.swift`.

### 10.1 `isReconnectable(_:)` extension

Extend the existing switch with the two new cases:

```swift
private func isReconnectable(_ reason: StreamDecodePipeline.StreamTerminationReason) -> Bool {
    switch reason {
    case .networkError(_, let code):
        let terminalCodes: Set<Int> = [
            NSURLErrorCannotFindHost, NSURLErrorUnsupportedURL, NSURLErrorBadURL
        ]
        return !terminalCodes.contains(code)
    case .serverClosed, .httpServerError, .playlistResolutionFailed:
        return true
    case .httpClientError, .decodeError, .invalidResponse, .userStopped:
        return false
    case .streamFinished, .unsupportedFormat:   // NEW
        return false
    }
}
```

This is the only StreamPlayer change. No reconnect-policy regressions for legacy progressive streams.

## 11. Files Inventory (verified against HEAD 2026-04-27)

> HEAD inspection confirms research.md's appendix line numbers are still accurate within ±2 lines. `stream-pause-tail` (S3-1B) and `video-audio-engine-routing` (S3-2) are not yet merged at the time of writing this plan; **the implementation step must re-read these files at HEAD post-merge of the predecessors** and adjust line numbers if needed. The semantic anchors below should still hold.

### 11.1 New files (3)

| File | Estimated LOC | Role |
|------|---------------|------|
| `MacAmpApp/Audio/HLS/M3U8Parser.swift` | 200–250 | Pure-Swift HLS playlist parser. File-internal types, no I/O. |
| `MacAmpApp/Audio/HLS/HLSSegmentFeeder.swift` | 300–400 | Mechanism: playlist fetch + variant pick + segment download + live refresh + termination mapping. `@unchecked Sendable`, queue-confined. |
| `Tests/MacAmpTests/HLSStreamingTests.swift` | 250–350 | Swift Testing: 17+ M3U8Parser cases (above), 11+ feeder cases (above), 3+ end-to-end smoke. |

### 11.2 Modified files (3)

| File | HEAD lines | Δ | Change |
|------|-----------:|--:|--------|
| `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` | 186 | +25 / 0 | Add `reset()` method (close + reopen, preserve formatHint, reuse selfPtr). |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | 697 | +160 / -10 | Add 2 enum cases, `isLikelyM3UDialect`, `classifyM3UDialect`, `startHLSStream`, `handleHLSTermination`, generation snapshot, `hlsFeeder` field, feeder cancel in `stopInternal`, `DecodeContext.resetParserOnDecodeQueue`. |
| `MacAmpApp/Audio/StreamPlayer.swift` | 414 | +12 | Extend `isReconnectable` switch with 2 new cases; extend `userMessage` switch with 2 new cases. |

### 11.3 Possibly affected (verify, no expected change)

- `Audio/PlaybackCoordinator.swift` — bridge activation gated on `onFormatReady`; HLS path emits `onFormatReady` from the same `DecodeContext.formatReadyFired` logic. **Expect no change.**
- `Audio/AudioPlayer.swift` / `Audio/AudioEngineController.swift` — bridge mechanism unchanged. **Expect no change.**
- `Models/Track.swift` (`isStream`), `Models/RadioStation.swift`, `Models/M3UParser.swift` — **no change** (legacy parser remains for the `.legacyM3U` branch of the classifier).

### 11.4 Operational tasks

- `xcodegen generate` after adding the 3 new Swift files (path-based source globbing in `project.yml`; no edit needed).
- `tasks/_context/tasks_index.md` — flip `hls-streaming-support` from PLANNED to ✅ COMPLETE on PR merge (status update only).
- `tasks/_context/state.md` — append S3-3 outcome row.
- `docs/MACAMP_ARCHITECTURE_GUIDE.md` — add an "HLS audio path" subsection beside the existing progressive stream subsection in §4.
- `docs/IMPLEMENTATION_PATTERNS.md` — append a new pattern: "Closure-injection seam to preserve private visibility" (justification: the seam will repeat in future stream-side features such as ogg).

> Note on filename spelling: the project convention (per `~/.claude/CLAUDE.md` and `~/.claude/projects/-Users-hank-dev-src-MacAmp/memory/MEMORY.md` "PR Review False Positives") uses `depreciated.md` (every existing task folder, including `tasks/done/`, uses this spelling). Plan and todo files use it consistently. This is **not** an English typo to be corrected — it is a project naming convention. CodeRabbit / Gemini-bot comments suggesting otherwise are pre-classified false positives.

## 12. Phase 7 — Tests

**File:** `Tests/MacAmpTests/HLSStreamingTests.swift` (new).

Use Swift Testing (`import Testing`). All tests run on the test plan's "All" configuration. TSan must remain clean.

### 12.1 M3U8Parser unit tests (golden inputs)

Each test loads a small fixture string in-line (no resource files — keeps the test self-contained and grep-able). 17 cases enumerated in §5.3 above (16 originals + body-too-large).

### 12.2 HLSSegmentFeeder unit tests (mocked URLSession)

Use the `HLSURLSessionAdapter` protocol from §7.6.1. Production uses `HLSURLSessionLiveAdapter` (own URLSession, not `URLSession.shared`); tests use `HLSURLSessionStubAdapter` (in-memory). The cancellation contract (`invalidateAndCancel()` cancels the underlying session, regardless of in-flight tasks) is identical across both implementations.

11 cases enumerated in §7.10 above.

### 12.3 End-to-end smoke (manual + opt-in)

A single integration test gated behind an env var (`MACAMP_HLS_INTEGRATION=1`) pointing at a known-good public AAC HLS station (URL configurable; default: an unmetered public station — pick one at implementation time). The test:
1. Creates a `StreamDecodePipeline`.
2. Calls `start(url: hlsURL, ringBuffer: rb)`.
3. Awaits `onFormatReady` with a 30 s timeout.
4. Reads at least 1 second of non-zero PCM from the ring buffer.
5. Calls `stop()` and verifies clean teardown (no orphan tasks, ring buffer flushed).

Default-skipped in CI; runs locally when the env var is set.

### 12.4 Regression coverage

Existing 57 tests must pass. Particular attention to:
- `StreamDecodePipelineTests` (if any exist — verify at implementation time).
- `M3UParserTests` (legacy parser unchanged).
- `LockFreeRingBufferTests` (ring buffer semantics unchanged).

## 13. Verification Approach

### 13.1 Automated

- `xcodegen generate && xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — must build clean with TSan.
- `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all tests pass, no TSan reports.

### 13.2 Manual (against live HLS audio stations)

Pick at least 3 distinct stations covering: (a) major broadcaster (NPR / BBC / Radio France), (b) SomaFM HLS mirror or equivalent, (c) ad-tech aggregator. Verify for each:
- Plays within 5 s of click.
- Audible quality (no warble — would indicate ADTS segment-boundary glitches and hint that `parser.reset()` is needed *every* segment, not just on discontinuity).
- EQ slider bands respond.
- Spectrum analyzer animates.
- Balance slider pans.
- 30+ minute soak: no drift, no memory growth in Instruments Allocations.
- Network-flap: TSan clean, reconnect machinery engages cleanly (existing reconnect path is reused for `networkError`/`httpServerError`).
- Stop: ring buffer, feeder, URLSession all torn down.

### 13.3 Regression

- Play 3 legacy SHOUTcast/Icecast stations (MP3 + AAC). Verify ICY metadata, EQ, visualizer all behave as today.
- Play 1 legacy `.m3u` playlist file (one-line stream URL). Verify the classifier correctly routes it through `M3UParser` and `startDirectStream` — no behaviour change.
- Play 1 legacy `.pls` file. Verify routed through `resolvePlaylistURL` unchanged.
- Play 5 local files (MP3, AAC, FLAC, WAV, M4A). Regression sanity for the engine bridge.
- Switch HLS → local file → HLS. Verify clean transitions, no `-10868`.

### 13.4 Documentation

- `docs/MACAMP_ARCHITECTURE_GUIDE.md` §4 gets the new HLS subsection.
- `docs/IMPLEMENTATION_PATTERNS.md` gets the new closure-injection-seam pattern.
- `placeholder.md` records any deferrals discovered during implementation (likely candidates: Content-Type promotion of non-`.m3u8` URLs; HLS pause as suspend-segment instead of stop-restart).

## 14. Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|---------:|-----------:|------------|
| AudioFileStream produces audible boundary clicks at every ADTS segment | Medium | Low–Med | `parser.reset()` is available (Phase 2). If clicks occur on every boundary, call it always; if only on discontinuity, call only there. Verified via WAV-dump methodology (Lesson 3). |
| `MainActor.assumeIsolated` in generation getter traps off-main | High | Med (without snapshot) | Eliminated by §8.3: use `OSAllocatedUnfairLock<UInt64>` snapshot, no actor hop. |
| Live playlist sequence wraparound | Low | Low | Backward jump → reset baseline, log warning, continue. |
| `onFormatReady` never fires (first segment too small) | Low–Med | Low | Existing 16 384-frame threshold is ~371 ms @ 44.1 kHz; HLS segments are typically 6–10 s. If a station ships sub-200 ms segments, lower threshold to 8 192 frames specifically for HLS (decision at implementation time). |
| Refresh task leak across restarts | Med | Low | All timers are `DispatchSourceTimer`, cancelled in `feeder.cancel()`. Generation gate drops late callbacks. |
| Encrypted bytes reach AudioFileStream | High | Low | `M3U8Parser` rejects `EXT-X-KEY:METHOD≠NONE` *before* any segment fetch. Feeder also re-checks per segment. Defence in depth. |
| Visibility widening for `DecodeContext` | Med | Low | Closure-injection seam (P5). Only `resetParserOnDecodeQueue` is added (file-internal). |
| ICY metadata loss for HLS | Low | High (by design) | HLS does not use inline ICY. Best-effort `EXTINF` title pass-through partially compensates. Not a regression — HLS does not play at all today. |
| Conflict with S3-1B `stream-pause-tail` on `StreamDecodePipeline.swift` | Med | Med | S3 ordering is strict serial. Re-read HEAD after S3-1B/S3-2 merge before starting implementation; rebase plan locations as needed. The HLS branch only adds new methods + a single new branch in `start(url:)`; conflict surface is small. |
| Conflict with S3-4 `ogg-vorbis-support` on `StreamDecodePipeline.swift` | Low | Med | OGG plan must rebase on this branch. We keep changes minimal and grouped (new branch + new method) to make the rebase mechanical. |
| HLS pause UX worse than progressive pause | Low | High (by choice) | Documented trade-off; revisit if user feedback demands. Listed in `placeholder.md` on merge. |

## 15. Principles Contract (per `_context/principles.md`)

| Principle | Application |
|-----------|-------------|
| **P1 Problem-First** | Concrete user-visible failure documented in §1. Not a cleanup. |
| **P2 Cohesion > LOC** | New types are added; existing files grow modestly (StreamDecodePipeline +160 lines is acceptable — single new responsibility-branch, no new state machine inside the file). |
| **P3 State Ownership** | Feeder owns its own queue and state. `DecodeContext` is unchanged in its mutable state. The generation token has a single owner (pipeline) and a read-only snapshot for the feeder — no shared writers. |
| **P4 AHA / Rule of Three** | `M3U8Parser` is its own type, deliberately separate from `M3UParser` (different protocol, different semantics, different tag space). No premature abstraction; both stay distinct WET implementations. Safety-invariant exception applies for the closure-injection seam (threading boundary between MainActor pipeline and feeder queue). |
| **P5 API Surface Minimization** | Zero `private → internal` widening on existing types. The seam is delivered via captured closures. Two new file-internal types. One new internal method on AudioFileStreamParser; one new internal method on DecodeContext; two new internal methods on StreamDecodePipeline; one new field. |
| **P6 No Pass-Through Middlemen** | `HLSSegmentFeeder` adds real policy: variant selection, RFC 8216 reload timing, sequence diffing, generation gating, format rejection, EXTINF title pass-through. `M3U8Parser` is pure data, not a forwarder. |
| **P7 ADR + Kill Switch** | This document is the ADR. Kill switch in §16. |

## 16. Stop Criteria / Kill Switch

Halt implementation and re-plan if any of the following occur:

1. **`parser.reset()` cannot be made safe** within the AudioConverter lifetime contract (Lesson 6) — i.e. closing+reopening the parser invalidates the converter's magic cookie reference. Fallback: drop discontinuity handling, surface a non-fatal log on `EXT-X-DISCONTINUITY`, and ship without it. (Most radio HLS does not use discontinuities.)
2. **AudioFileStream produces an unrecoverable click at every ADTS segment boundary** that `parser.reset()` does not fix. Fallback: detect boundary glitches via dump-test, switch to per-segment `parser.reset()` always, accept the ~5 ms cost.
3. **No public AAC-ADTS HLS station can be found** for end-to-end smoke testing during implementation. Fallback: build a local HLS test harness (a tiny `vapor` or `python -m http.server` serving a recorded ADTS playlist + segments) and document the harness in `docs/`.
4. **Generation snapshot pattern fails TSan** under high-frequency restart. Fallback: hop the getter through MainActor with a `withCheckedContinuation` and accept the latency. (Unlikely — `OSAllocatedUnfairLock<UInt64>` is TSan-clean by design.)
5. **The plan's scope exceeds 7 days of implementation effort.** v1 is intentionally narrow; if scope creep occurs (e.g. someone asks for TS support mid-implementation), defer to v2 and ship v1 as-is.

If a kill switch fires, write findings to `placeholder.md` and `depreciated.md` as appropriate, leave the branch in a clean state, and report back for re-planning.

## 17. Branch + PR Plan

- **Branch:** `feat/hls-streaming-support` off `main` *after S3-1B (`stream-pause-tail`, PR #B) and S3-2 (`video-audio-engine-routing`, PR #C) are merged*.
- **Commits:** roughly one per Phase (P1–P6), plus tests, plus docs. Aim for 8–10 small commits to keep review tractable and revertable.
- **PR target:** PR #D. Title: `feat(audio): add HLS audio-only streaming (AAC ADTS, master+media, live+VOD)`.
- **Reviewers:** automated (CodeRabbit, Gemini-bot if configured) + Oracle code-review pass before request-review.
- **Merge gate:**
  - Build clean with TSan.
  - All tests pass.
  - 3+ live HLS stations smoke-tested manually.
  - Legacy `.m3u`/`.pls` regression smoke-tested.
  - Docs updated.
  - Oracle code-review score ≥ 9/10 OR all P1/P2 findings dispositioned.

## 17.1 Successor integration — S3-4 `ogg-vorbis-support`

> Oracle round 1 actionable item A-5: the OGG plan changes shape under the HLS plan's feet. This section makes the integration hand-off explicit so the OGG branch's rebase is mechanical and intentional, not surprise-driven.

### 17.1.1 OGG plan refactors that affect HLS code paths

OGG Phase 4 (`StreamBackend` enum + DecodeContext state machine) and Phase 6 (`ICYMetadata` → `StreamMetadata` rename) are large changes to the very files this plan modifies. The HLS branch ships **before** OGG, so the OGG branch is responsible for the rebase. To minimize that rebase pain:

#### A. `ICYFramer.ICYMetadata` rename

The HLS plan introduces one new use site of `ICYFramer.ICYMetadata` (in `StreamDecodePipeline.startHLSStream` §8.3.2 — the `onMetadataTitle` closure constructs an `ICYFramer.ICYMetadata(title: title, artist: nil)` and forwards via `self.onMetadata?(metadata)`).

The OGG branch will rename `ICYFramer.ICYMetadata` → top-level `StreamMetadata` (per `tasks/ogg-vorbis-support/plan.md` §11). To keep the OGG rebase mechanical, the HLS branch **encapsulates** the metadata-construction site in a small file-private factory inside `StreamDecodePipeline.swift`:

```swift
// File-private convenience. OGG renames the underlying type — only this single line needs updating.
fileprivate func makeStreamMetadata(title: String?, artist: String?) -> ICYFramer.ICYMetadata {
    ICYFramer.ICYMetadata(title: title, artist: artist)
}
```

The HLS branch calls `makeStreamMetadata(title: title, artist: nil)` from `onMetadataTitle`. The OGG rename then becomes a single-line edit (return type + body) in this one location, no scattered call-site changes.

#### B. `formatHint: AudioFileTypeID` → `StreamFormatHint` enum

OGG replaces `AudioFileTypeID` with a typed `StreamFormatHint` enum (`tasks/ogg-vorbis-support/plan.md` §9.5). The HLS branch passes `formatHint = kAudioFileAAC_ADTSType` directly when constructing `DecodeContext` for HLS (§8.3.2). After OGG merges, that becomes `formatHint = .audioFileStream(kAudioFileAAC_ADTSType)` (or whatever shape OGG settles on). This is a single-line rebase on the OGG branch.

The HLS branch deliberately does **not** introduce its own `StreamFormatHint` abstraction — that would put two competing abstractions in main and force unnecessary cross-branch coordination. AHA Rule of Three: HLS is the second use site (after MP3/AAC progressive); OGG is the third and the abstraction is correctly introduced there.

#### C. `DecodeContext` lifecycle (`PipelineLifecycle` state machine)

OGG introduces a new `PipelineLifecycle` enum on `DecodeContext` (`sniffing` / `buffering` / `playing`). The HLS branch does **not** add lifecycle states to `DecodeContext` — it routes around the lifecycle entirely by skipping `configureFramer` and bypassing `SessionDelegateProxy`. After OGG merges, the HLS branch's `startHLSStream` initializes `DecodeContext` in the same `.buffering` state OGG uses for AAC ADTS. Single-line rebase.

#### D. `onFormatReady` re-fire on chain boundary

OGG's Phase 4.7 introduces `onChainFormatChange` for chained Icecast Vorbis streams. HLS does not need this — the AAC ADTS scope is single-format. But: the HLS plan's `parser.reset()` flow (Phase 2 + §6.3) explicitly **rejects** post-reset format mismatch by surfacing `decodeError`. After OGG merges, this rejection logic should remain unchanged: HLS does not opt into the new `onChainFormatChange` callback. Documented as deferred in `placeholder.md` on merge of OGG.

### 17.1.2 OGG branch hand-off checklist (referenced in OGG plan rebase phase)

When the OGG branch starts (after this PR merges), the OGG implementer rebases against `main` and:

1. Updates the HLS `makeStreamMetadata` factory's return type to `StreamMetadata`.
2. Updates the HLS `formatHint = kAudioFileAAC_ADTSType` line to the new `StreamFormatHint` shape.
3. Verifies that HLS `DecodeContext` initialization sits cleanly in OGG's new `PipelineLifecycle` state-machine — for HLS, the lifecycle is `buffering → playing` only, the same as MP3/AAC progressive.
4. Verifies that HLS does NOT subscribe to `onChainFormatChange` — HLS rejects mid-stream format change.
5. Runs the HLS tests + adds an integration test that confirms HLS still works after OGG's refactor.

This checklist is referenced in `tasks/ogg-vorbis-support/plan.md`'s rebase phase by the OGG plan author after this plan merges.

**Action for OGG plan author:** when this HLS plan merges, the OGG plan author must add a cross-reference to this section in `tasks/ogg-vorbis-support/plan.md` (suggested: a new "§17.5 HLS rebase checklist" pointing back to `tasks/hls-streaming-support/plan.md` §17.1.2). Tracked separately so the OGG branch's bookkeeping remains in OGG's own plan; this HLS plan does not edit OGG files.

## 18. Rollback Plan

Each Phase is committed independently. Roll-forward is preferred, but a clean rollback is available at every Phase boundary.

- **Pre-merge rollback:** `git revert <phase commit>` per Phase, in reverse order. Phase 6 (StreamPlayer extension) is the last to add, first to revert.
- **Post-merge rollback:** revert PR #D in full. The only persistent risk is if a future commit depends on the new `.streamFinished` / `.unsupportedFormat` enum cases — keep an eye on S3-4 (OGG) which may add cases too. If it does, coordinate via `_context/state.md`.
- **Feature flag:** none. The feature only activates for URLs that the new classifier identifies as HLS; existing code paths are byte-for-byte unchanged for non-HLS URLs.

## 19. Oracle Validation Summary (this plan)

Reviewer: `mcp__codex-cli__codex` model `gpt-5.5`, `reasoningEffort: xhigh`, read-only sandbox. Inputs: `plan.md`, `todo.md`, `research.md`, `_context/principles.md`, `_context/state.md`, `StreamDecodePipeline.swift`, `AudioFileStreamParser.swift`, `AudioConverterDecoder.swift`, `ICYFramer.swift`, `StreamPlayer.swift`, `M3UParser.swift`.

### Round 1 — score 7/10

**Actionable findings (all FIXED inline):**

| # | Finding | Disposition |
|---|---------|-------------|
| A-1 | Permanent HLS parse failures mapped to `.playlistResolutionFailed` (reconnectable) — would loop on permanently broken playlists | **FIXED** §9.1: split `FeederTermination.malformedPlaylist` into `.decodeRejected` (permanent → `.unsupportedFormat`) and transient `networkError`/`httpServerError`. ClassifyError mapping also split. |
| A-2 | HLS pause-as-stop is underspecified vs S3-1B's `pauseByUser`/`resumeByUser` | **FIXED** §8.5.1: added explicit `HLSSegmentFeeder.pauseByUser/resumeByUser` methods, integrated with S3-1B's pipeline barrier flow, with parser-reset on resume. §8.5.2 documents the resume-time `parser.reset()` call. |
| A-3 | `MainActor.assumeIsolated` snippet shown then disclaimed — confusing for an executable plan | **FIXED** §8.3.1: removed the snippet entirely. Plan now shows only the `OSAllocatedUnfairLock<UInt64>` snapshot pattern. `updateGenerationSnapshot()` is called at every `generation` mutation. |
| A-4 | `parser.reset()` post-reset format-mismatch is unobservable (existing handleFormatAvailable early-returns on `decoder != nil`) | **FIXED** §6.3: parser-side ASBD comparison emits `onError` on mismatch → `.decodeError` non-reconnectable. Decoder swap explicitly out of scope. Test added in §6.5. |
| A-5 | S3-4 OGG conflict map too optimistic (renames `ICYMetadata`, swaps `formatHint` to enum, adds `PipelineLifecycle`, adds `onChainFormatChange`) | **FIXED** §17.1 added: factory wrapper for `ICYMetadata` to keep OGG rename to one line; deferred `StreamFormatHint` abstraction (AHA Rule of Three — OGG is the right place); HLS opts out of `onChainFormatChange`; explicit OGG-rebase checklist. |

**Nitpicks (all FIXED):**

| # | Finding | Disposition |
|---|---------|-------------|
| N-1 | Content-Type promotion contradiction (§4 said yes, §8.2 deferred) | **FIXED** §8.2 step 5: explicit "no Content-Type promotion in v1, deferred to placeholder.md". Open Question 1 closed. |
| N-2 | "File-internal" terminology imprecise across-file | **FIXED** §5.1: clarified as `internal` (default access). §7.6 / §8.5 use `fileprivate` precisely where applicable. |
| N-3 | URLSession test seam ambiguous (own-session vs URLSession.shared adapter) | **FIXED** §7.6.1: single `HLSURLSessionAdapter` protocol, production `LiveAdapter` owns its own URLSession (not `URLSession.shared`), test `StubAdapter` in tests target. §12.2 updated. |
| N-4 | "depreciated.md" spelling | **REJECTED as project convention** §11.4 footnote. The project's CLAUDE.md and global memory document `depreciated.md` as the established folder convention; CodeRabbit/Gemini hits on this are pre-classified false positives. Plan keeps `depreciated.md`. |
| N-5 | "first ~40 chars" truncation message inconsistent with snippet | **FIXED** §9.2: the snippet now reflects the actual behaviour (caller passes a short message; UI handles truncation). |

**Rejected (false positives) — Oracle round 1 listed 5; all upheld here:**

1. "Option A is just pass-through" — feeder owns real policy.
2. "Reuse `M3UParser` for HLS" — different protocols, WET correct.
3. "HLS should call `configureFramer(metaInterval: 0)`" — default is pass-through; avoids violating the single-configure invariant (Lesson 2).
4. "New `.streamFinished` / `.unsupportedFormat` cases unnecessary" — they prevent reconnect loops (A-1 closure).
5. "`project.yml` must be edited for `Audio/HLS/`" — globbed paths cover the new folder.

### Round 2 — score 8/10

**Actionable findings (all FIXED inline):**

| # | Finding | Disposition |
|---|---------|-------------|
| A-1 | `HLSURLSessionAdapter.streamSegment` had no response callback — feeder couldn't enforce HTTP status mapping or Content-Type validation before `onData` | **FIXED** §7.6.1: `streamSegment` now takes `onResponse: (HTTPURLResponse) -> SegmentResponseVerdict` plus `onComplete: (SegmentCompletion)` enum. The verdict gates byte forwarding; bytes withheld until status/Content-Type pass. Live and Stub adapters both implement the contract. |
| A-2 | `ClassifyError.malformedPlaylist` mapped to `.playlistResolutionFailed` in §8.2 (reconnectable), contradicting §9.1 | **FIXED** §8.2: split `malformedHLSPlaylist` (→ `.unsupportedFormat`, non-reconnectable) from `malformedLegacyPlaylist` (→ `.playlistResolutionFailed`, reconnectable). Mapping decided at construction site, not in `handleHLSTermination`. §9.1 cross-references back to §8.2. |
| A-3 | `resumeByUser` ordering underspecified vs S3-1B's barrier discipline | **FIXED** §8.5.1: explicit 7-step ordering for the feeder; explicit 3-step ordering inside `pipeline.resumeByUser()` HLS branch (resetPrebufferTracking → feeder.resumeByUser → setPausedByUser(false)); ordering invariant called out and defended. |
| A-4 | ASBD compare insufficient — missing `mFormatFlags` (AAC profile) and magic cookie; no fatal-state flag to truly stop subsequent packets | **FIXED** §6.3: comparison key extended with `mFormatFlags` and magic cookie content; new `parserFatalState: Bool` flag short-circuits all subsequent `parse(_:)` and packet callbacks until a fresh `init`. |

**Nitpicks (all FIXED):**

| # | Finding | Disposition |
|---|---------|-------------|
| N-1 | Stale `FeederTermination.malformedPlaylist` in §7.1 enum snippet | **FIXED** §7.1: case removed; comment explains the fold into `decodeRejected`/`networkError`/`httpServerError`. |
| N-2 | OGG plan does not yet reference §17.1.2 checklist | **NOTED**: HLS plan §17.1.2 calls out the action item for the OGG plan author. The OGG plan edit happens at OGG plan-writing time (separate sub-agent task). |
| N-3 | `M3U8Parser.parse` takes `String` but §5.2 mentions Latin-1 fallback / 1 MB rejection (mixed responsibility) | **FIXED** §5.2: parser-side robustness (BOM/CRLF/comments/1 MB cap returning `.malformed`) vs caller-side fetch decoding (UTF-8 → Latin-1) cleanly separated. Parser API stays `String`. |
| N-4 | "17 cases" but visible list had 16 | **FIXED** §5.2: added body-too-large case → 17. §12.1 description updated. |

**Rejected Round-1 false positives (still upheld in Round 2):**
- generation snapshot pattern, no `MainActor.assumeIsolated`.
- feeder permanent-rejection mapping correct.
- `configureFramer(metaInterval: 0)` not needed.
- `StreamFormatHint` abstraction belongs in OGG (AHA Rule of Three).

### Round 3 — score 8/10

**Actionable findings (all FIXED inline):**

| # | Finding | Disposition |
|---|---------|-------------|
| A-1 | `resumeByUser` ordering still not strict — pipeline `generation` does not change on pause/resume, so it cannot reject stale callbacks from a cancelled pre-pause segment | **FIXED** §8.5.1 (invariant section): added `pauseEpoch` field on the feeder, incremented in both `pauseByUser` and `resumeByUser`, captured at task creation as `taskEpoch`, checked in every `onResponse`/`onData`/`onComplete`. The two gates (pipelineGeneration + pauseEpoch) protect orthogonal invariants. |
| A-2 | `todo.md` stale — P1.8 still implied parser-side Latin-1; P2.5 omitted `mFormatFlags`, magic cookie, `parserFatalState` | **FIXED** todo.md: P1.8 rewritten to explicitly defer Latin-1 to caller; P2.5/P2.6/P2.7 added covering ASBD `mFormatFlags`, magic cookie compare, `parserFatalState` flag short-circuit; P3.10/P3.10b added covering pauseEpoch gate. |
| A-3 | §8.2 sniff branch still names `ClassifyError.malformedPlaylist` (singular) | **FIXED** §8.2 step 4: renamed to `malformedLegacyPlaylist`; added explicit clarification that `malformedHLSPlaylist` is **not** a classifier outcome — only `M3U8Parser` rejection in the feeder produces it (as `FeederTermination.decodeRejected`). Mapping table in §8.2 reflects this. |

**Nitpicks:**

| # | Finding | Disposition |
|---|---------|-------------|
| N-1 | §14 still labels S3-1B conflict as "small" | **NOTED**: HLS does add a new branch to `pauseByUser`/`resumeByUser`. Risk severity assessment is fine (`Med` in the table); descriptive text not updated since the table already conveys the truth. Acceptable as-is. |
| N-2 | OGG plan does not yet reference §17.1.2 checklist | **NOTED** (carry-over from Round 2): action item documented for the OGG plan author; out-of-scope for this HLS plan write. |

### Round 4 — score 9/10. PR-READY.

**Actionable findings:** None.

**Nitpicks (both addressed for cleanliness):**

| # | Finding | Disposition |
|---|---------|-------------|
| N-1 | §7.2/§7.5 still described feed path as generation-only | **FIXED** §7.5 step 3 + §7.8 rewritten to call out both gates (pipelineGeneration AND pauseEpoch). |
| N-2 | `FeederTermination.malformedPlaylist` historical reference in §9.1 prose | **FIXED** §9.1 prose updated to state directly that the enum does not include the case; no historical reference remaining. |

### Final score: 9/10. Plan is PR-ready.

### Findings disposition (cumulative across 4 rounds)

- 5 Round-1 actionable items applied inline.
- 4 Round-1 nitpicks applied; 1 (N-4 `depreciated.md` spelling) rejected with documented project convention.
- 4 Round-2 actionable items applied inline.
- 4 Round-2 nitpicks applied (1 deferred to OGG plan author).
- 3 Round-3 actionable items applied inline.
- 2 Round-3 nitpicks: 1 deferred to OGG plan author (carry-over), 1 acknowledged as descriptive-text vs accurate-table.
- 0 Round-4 actionable; 2 Round-4 nitpicks applied.

Total: **16/16 actionable items applied across 4 rounds**. Plan converged at 9/10 in Round 4.

