# Research: HLS Streaming Support (Audio-Only)

> **Purpose:** Add audio-only HLS support to MacAmp's existing custom stream decode pipeline so that radio stations served as HLS (.m3u8 + .aac/.ts/.m4s segments) play with full feature parity (EQ, visualization, balance, ICY-equivalent metadata).
>
> **Date:** 2026-04-27
> **Status:** Research complete. Plan to follow.
> **Sprint:** S3 (Large)

---

## Context + Scope

MacAmp's unified audio pipeline (T7, PR #57) decodes progressive HTTP streams (SHOUTcast/Icecast MP3/AAC) into Float32 PCM that flows through `LockFreeRingBuffer → AVAudioSourceNode → AVAudioEngine`. Internet radio that ships HLS (e.g. NPR, BBC, SomaFM mirrors, many CDNs) currently does **not** play because `StreamDecodePipeline` treats `.m3u8` as a *legacy M3U playlist* (text file with one stream URL inside) and the resulting decode fails when it hits HLS-specific headers.

**Scope:**
- Audio-only HLS over HTTP/HTTPS
- Live (continuously growing) and VOD (`#EXT-X-ENDLIST`) media playlists
- Variant playlists (master/multivariant) — pick one variant, no adaptive switching for v1
- Segment formats: AAC ADTS (`.aac`) for v1; MPEG-TS (`.ts`) and fragmented MP4 (`.m4s`) deferred

**Explicitly out of scope:**
- **Video HLS** — handled by `VideoPlaybackController` via AVPlayer; HLS video already works there because AVPlayer natively supports it. The QA1716 tap limitation only blocks audio EQ/viz, and the `video-audio-engine-routing` task addresses that separately.
- **DRM (FairPlay, AES-128/SAMPLE-AES `#EXT-X-KEY`)** — radio audio HLS rarely uses these.
- **Adaptive bitrate switching** — radio bitrates are homogeneous; pick one variant up front.
- **Live DVR / time-shift / `#EXT-X-DISCONTINUITY` recovery** — out of scope for v1.
- **Low-Latency HLS (LL-HLS) partial segments** — radio doesn't need <2s glass-to-glass.

**Why not AVPlayer for HLS audio?** Same reason as progressive streams: `MTAudioProcessingTap` does not fire for any non-file-based AVPlayerItem (Apple QA1716, confirmed by extensive MacAmp testing in T5 Phase 2 and documented in `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`). HLS via AVPlayer = no EQ, no visualizer, no balance — same dead end. The `AVAssetResourceLoaderDelegate` workaround does **not** rescue tap behavior because the limitation is in CoreMedia's renderer for non-file items, not in the asset transport layer.

---

## Current Architecture (what HLS plugs into)

### Files (HEAD as of 2026-04-27)

| File | Lines | Role |
|---|---|---|
| `MacAmpApp/Audio/StreamPlayer.swift` | 415 | @Observable MainActor facade. Owns `StreamDecodePipeline`, ring-buffer lifecycle, reconnect policy, ICY metadata propagation, elapsed-time anchor. |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | 698 | @MainActor orchestrator. Owns URLSession, decode queue, `DecodeContext`. Today it handles **two** kinds of URL: (a) direct audio (HTTP body = audio bytes) and (b) M3U/M3U8/PLS playlist files (resolved to a single direct URL via `resolvePlaylistURL`). |
| `MacAmpApp/Audio/Streaming/ICYFramer.swift` | 200 | Pure value-type framer that strips ICY metadata blocks based on `icy-metaint` header. |
| `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` | 187 | C-API wrapper over `AudioFileStreamOpen/ParseBytes`. Emits ASBD, magic cookie, and packet batches. |
| `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` | 286 | C-API wrapper over `AudioConverter`. Decodes packets to Float32 stereo PCM. |
| `MacAmpApp/Audio/Streaming/QueueConfined.swift` | ~25 | Debug confinement assertion mixin used by Parser/Decoder. |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | 562 | Routes Track/RadioStation to AudioPlayer or StreamPlayer; activates engine bridge on `onFormatReady`. |
| `MacAmpApp/Audio/AudioPlayer.swift` | 705 | Local playback + bridge mechanism (`activateStreamBridge`, `streamSourceNode`). |
| `MacAmpApp/Models/M3UParser.swift` | 142 | Legacy M3U/M3U8 parser (used today for *playlist files*, not HLS). Emits `M3UEntry` with `.url`. |
| `MacAmpApp/Models/Track.swift` | 44 | `isStream` is currently `scheme == http/https && !isFileURL`. |
| `MacAmpApp/Models/RadioStation.swift` | 23 | URL-bearing model. |

### Today's data flow (progressive)

```
RadioStation.streamURL
   │
   ▼
StreamDecodePipeline.start(url:)
   │
   ├─ if isPlaylistURL(.m3u/.m3u8/.pls) → resolvePlaylistURL → single URL → startDirectStream
   └─ else → startDirectStream
            │
            ▼
   URLSession data task
   onResponse → configureFramer(metaInterval) on decode queue
   onData    → DecodeContext.handleIncomingData(Data)
                  ├─ ICYFramer.consume → [.audio | .metadata]
                  ├─ AudioFileStreamParser.parse → ASBD, magic cookie, packets
                  └─ AudioConverterDecoder.decode → Float32 PCM → ringBuffer.write
   onComplete → handleStreamComplete (server closed / error)
```

### Key invariants we must preserve

1. **Single-`configureFramer` rule** (Lesson 2 in `tasks/done/unified-audio-pipeline/lessons-learned.md`): Any code path that resets `audioByteCount` mid-stream corrupts MP3/AAC ADTS framing. HLS path must **not** call `configureFramer` (no ICY in HLS) — but it must also not double-init AudioFileStream.
2. **AudioConverterDispose BEFORE AudioFileStreamClose** (Lesson, decoder lifetime contract).
3. **Ring buffer is shared with the real-time AVAudioSourceNode render block.** Anything we add must remain queue-confined (decode queue) and never block the audio IO thread.
4. **Generation token discipline**: every restart bumps `pipeline.generation`; stale callbacks are dropped. The HLS playlist refresh loop must respect this.
5. **`onFormatReady` fires exactly once per pipeline lifetime** — used by `PlaybackCoordinator` to activate the engine bridge. HLS must wait until enough segment data has been decoded to satisfy `prebufferThreshold = 16384` PCM frames.
6. **Reconnect policy is owned by `StreamPlayer`**, not the pipeline. HLS playlist-refresh failures and segment 5xx/timeouts should map to existing `StreamTerminationReason` cases so reconnect "just works".

---

## HLS Protocol Scope (RFC 8216 + Apple authoring spec)

### What we MUST handle (v1)

| Tag | Where | Action |
|---|---|---|
| `#EXTM3U` | First non-empty line | Magic; required |
| `#EXT-X-VERSION:N` | Once per playlist | Accept any (we only need v3+ behaviors that are universal) |
| `#EXT-X-TARGETDURATION:N` | Media playlist | Drives live refresh interval (refresh every `TARGETDURATION/2` seconds, RFC 8216 §6.3.4) |
| `#EXT-X-MEDIA-SEQUENCE:N` | Media playlist (live) | First segment's sequence number; used to detect new segments on refresh |
| `#EXTINF:duration,title` | Per segment | Duration only (title rarely populated for radio) |
| `<segment-uri>` | Per segment | Resolved relative to playlist URL |
| `#EXT-X-ENDLIST` | VOD only | Marks playlist as immutable; stop refreshing |
| `#EXT-X-STREAM-INF:BANDWIDTH=…` | Master playlist | Variant info; pick one (highest BANDWIDTH ≤ ceiling, or first) |
| Comments / unknown `#EXT-…` | Anywhere | Ignore (per RFC 8216 §4.1) |

### What we MAY tolerate but skip safely (v1)

| Tag | Reason to skip |
|---|---|
| `#EXT-X-DISCONTINUITY` | RFC 8216 §3.4 client guidance is to reset timestamp/decoder context across the discontinuity. For v1 we are AAC-ADTS-only and the codec config does not change across radio discontinuities (same sample rate, same channel count, same magic cookie). The mitigation is: when the feeder sees `#EXT-X-DISCONTINUITY` in the playlist, it (a) logs it, (b) calls a new `parser.reset()` hook on `AudioFileStreamParser` (`AudioFileStreamSeek` / close-and-reopen) to flush any partial-frame state. The decoder's magic cookie remains valid. This is more conservative than "log and continue" and avoids low-frequency artifacts. (Oracle fix.) |
| `#EXT-X-PROGRAM-DATE-TIME` | Wall-clock timestamps; we don't need them. |
| `#EXT-X-BYTERANGE` | Sub-segment HTTP range. Rare for live radio. If seen, fail the variant and either pick another or surface a "not supported" error. |
| `#EXT-X-MEDIA` (alternate audio renditions) | Multi-language audio. Out of scope; if master playlist has only `MEDIA` and no `STREAM-INF`, fail with a clear error. |
| `#EXT-X-INDEPENDENT-SEGMENTS` | Hint about decoder-independent segments; we already treat each segment independently. No-op. |
| `#EXT-X-START` | Initial seek offset; live radio doesn't seek. Ignore. |

### What we MUST reject (v1)

| Tag | Failure mode |
|---|---|
| `#EXT-X-KEY:METHOD=AES-128` or `SAMPLE-AES` | DRM-protected. Surface `decodeError("Encrypted streams not supported")` — **non-reconnectable**, since retry will yield the same encrypted bytes. (Oracle fix: `playlistResolutionFailed` is reconnectable in `StreamPlayer.isReconnectable`.) |
| `#EXT-X-MAP:URI=…` (fMP4 init segment) | fMP4 deferred to v2. Surface `decodeError("Fragmented MP4 segments not supported")` — **non-reconnectable**. |
| Master playlist with only `EXT-X-I-FRAME-STREAM-INF` | Video-only trick mode, no audio. Surface `decodeError("No audio variant in HLS playlist")` — **non-reconnectable**. |

**Reconnectability rule for HLS:** map permanent format/feature failures to `.decodeError(_)` (non-reconnectable in current `StreamPlayer.isReconnectable`); map transient network/server problems to `.networkError`/`.httpServerError` (reconnectable). `.playlistResolutionFailed` is reconnectable today and must be reserved for cases where retry is meaningful (e.g. DNS/network blip during initial playlist fetch), not for permanent unsupported-format conclusions.

### Master vs Media playlist disambiguation

A **master** (multivariant) playlist contains `#EXT-X-STREAM-INF` lines. A **media** playlist contains `#EXTINF` lines and segment URIs. Detection: scan all lines once; presence of `#EXT-X-STREAM-INF` → master. RFC 8216 §6.2.1 forbids mixing them.

For master playlists, v1 picks one variant by:
1. Filter out variants tagged with video-only codecs (rare for audio HLS, but safe to check `CODECS="avc1.…"` without `mp4a.…`).
2. Prefer highest `BANDWIDTH` ≤ a soft cap (e.g. 256 kbps for radio). If none, take the lowest BANDWIDTH variant.
3. Resolve the variant URI, then proceed exactly like a media playlist.

---

## Detection Strategy

The **collision** with the existing pipeline is real and important: today, `.m3u8` URLs are routed to `M3UParser` (legacy playlist file), which extracts the *first non-file URL* and starts a direct stream against it. An HLS playlist accidentally parsed by `M3UParser` would yield the **first segment URL**, play ~6 seconds, then stop with "server closed".

### Proposed detection order (cheapest first)

The extension `.m3u8` is **not** dispositive — legacy SHOUTcast/Icecast playlist files are still served with that extension and contain a single stream URL. Final HLS-vs-legacy verdict requires a content sniff in every ambiguous case.

1. **URL extension hint** — `.m3u8` (case-insensitive) marks the URL as a **playlist of unknown dialect** (HLS or legacy M3U). It does not bypass the sniff. `.m3u` is treated as legacy M3U with no sniff.
2. **HTTP `Content-Type`** (from initial GET response):
   - Strong-HLS: `application/vnd.apple.mpegurl`, `application/x-mpegURL`, `vnd.apple.mpegurl` — promote to HLS sniff.
   - Ambiguous: `audio/mpegurl`, `audio/x-mpegurl` — could be either dialect; sniff required.
   - Legacy: `audio/x-scpls` — PLS, route to legacy parser.
3. **Content sniff** (authoritative): fetch playlist body once. First non-blank line must equal `#EXTM3U`. If any subsequent line starts with `#EXT-X-` → HLS. Else → legacy M3U.

### Where detection lives

The cleanest insertion point is **inside `StreamDecodePipeline.start(url:)`**, expanding the current two-branch logic (direct vs playlist) into three branches. Note the sniff is the dispositive step — extension and Content-Type only *route into* the sniff:

```text
start(url:)
  ├─ .m3u8 OR HLS Content-Type OR ambiguous mpegurl
  │     → fetch body once
  │       ├─ #EXT-X-* present  → startHLSStream(url:, prefetchedBody:)
  │       └─ legacy            → resolveLegacyPlaylist → startDirectStream
  ├─ .m3u/.pls OR audio/x-scpls Content-Type        → resolveLegacyPlaylist → startDirectStream
  └─ else                                            → startDirectStream
```

The HLS feeder accepts the prefetched body so we don't re-fetch the playlist on the first pass. (Subsequent live refreshes always re-fetch.)

**Important**: `Track.isStream` does not need to change — HTTP/HTTPS URLs already route to StreamPlayer. The *internal* dispatch in `StreamDecodePipeline` does the HLS-vs-progressive split. This avoids spreading HLS knowledge into Models layer.

A small ambiguity exists for URLs with no extension (e.g. radio directory entries like `https://example.com/listen?stream=foo`). For those, fall back to the *current* progressive path; if the very first response is a `Content-Type: application/vnd.apple.mpegurl` body, retry as HLS. This adds one extra round trip in the worst case — acceptable for a corner case.

---

## Integration Options

Two architectural shapes were considered. Both keep ICYFramer/AudioFileStreamParser/AudioConverterDecoder unchanged.

### Option A — `HLSSegmentFeeder` emulates a single byte stream

A new component that owns:
- A `URLSession` for segment downloads
- The parsed M3U8 state machine (target duration, last sequence, `endlist` flag)
- A serial-segment download loop
- A pull/push connection into the **existing** `DecodeContext.handleIncomingData(_:)`

To `DecodeContext` it looks identical to the current URLSession byte stream — just with `metaInterval = 0` (no ICY in HLS). The framer is configured once with `metaInterval: 0` and becomes a passthrough.

```text
HLSSegmentFeeder
  ├─ playlistURL → fetch → M3U8Parser → segments[]
  ├─ for each segment: download → bytes → DecodeContext.handleIncomingData(data)
  ├─ if !endlist: schedule next playlist refresh @ targetDuration/2
  └─ on cancel: stop URLSession, kill refresh timer

DecodeContext (unchanged)
  ├─ ICYFramer (no-op when metaInterval=0)
  ├─ AudioFileStreamParser
  └─ AudioConverterDecoder
```

**Pros:**
- *Maximum reuse* — DecodeContext, ICYFramer, AudioFileStreamParser, AudioConverterDecoder all unchanged.
- HLSSegmentFeeder is a single new file with one responsibility (orchestrate segment fetch). Aligns with Principle 1 (problem-first), Principle 5 (no visibility widening), Principle 6 (no pass-through middlemen — it adds real policy: refresh, sequencing).
- Keeps the existing `StreamTerminationReason` taxonomy intact; segment errors map to existing cases.
- Easy to delete if v2 chooses a different approach.

**Cons:**
- Requires `DecodeContext.handleIncomingData(_:)` to be reachable from a non-URLSession source. Today it's `internal` to the file but called only from `SessionDelegateProxy`. Calling it from a sibling component requires either making `DecodeContext` reachable from the new file (move it or expose it via an injected closure).
- Slight indirection: the URL bound to URLSession is now a *playlist URL*, not the audio URL. Logging/diagnostics need to reflect this.

### Option B — Branch inside `StreamDecodePipeline`

Instead of a new component, add an `HLSCoordinator` *inside* the pipeline class with a sibling `start(hlsURL:)` path that opens a separate URLSession for segments and calls `decodeContext.handleIncomingData` directly.

**Pros:**
- No new top-level type; everything stays in StreamDecodePipeline.swift.
- Reuses the existing `decodeQueue`, `audioWorkgroup`, `generation` token, and termination plumbing without indirection.

**Cons:**
- Inflates StreamDecodePipeline.swift from 698 → ~1100 lines, mixing two transport responsibilities. Violates Principle 2 (cohesion over LOC) and Principle 3 (state ownership): two state machines (HTTP byte stream vs HLS playlist+segments) inside one class share `generation` and `state` but otherwise share nothing.
- Already-deferred decomposition (`streamdecodepipeline-decomposition`) would re-emerge immediately.

### Recommendation: **Option A**

Create `HLSSegmentFeeder.swift` and a small `M3U8Parser.swift` (separate from the legacy `M3UParser.swift`). `StreamDecodePipeline` exposes a narrow internal seam — a single method on `DecodeContext` to feed bytes — that the feeder can call. To minimize visibility widening (Principle 5), the seam is delivered as a closure `(@Sendable (Data) -> Void)` captured at HLS-init time; `DecodeContext` does **not** need to become non-private.

**Single concurrency boundary.** All mutable feeder state (`pendingSegments`, `lastDownloadedMediaSequence`, `targetDuration`, `endlistSeen`, `inFlightSegmentTask`, `refreshTask`) lives on **one dedicated serial queue** owned by `HLSSegmentFeeder` (call it `feederQueue`). URLSession's delegate queue is a separate OperationQueue used only to *receive* HTTP callbacks; every callback immediately re-dispatches to `feederQueue` before mutating state. This mirrors the pattern in `StreamDecodePipeline` where `decodeQueue` is the single confinement boundary for `DecodeContext`. (Oracle fix: avoid claiming feeder is "decode-queue-confined" — it is **not**, because the decode queue is owned by `DecodeContext` and must not see playlist/segment state. Keep the two queues separate.)

**Stale-generation guard on the feed path.** The `feedAudio` closure captures the pipeline's current generation token at construction time. Before forwarding bytes to `DecodeContext`, the feeder compares the stored generation to a `@Sendable () -> UInt64` getter exposed by `StreamDecodePipeline` (read-only access to `generation`). If they diverge, drop the bytes — a restart is in progress. This avoids wasted decode work and matches the pattern already used in `StreamDecodePipeline` callbacks. (Oracle nit applied.)

Concretely:
```swift
// In StreamDecodePipeline.startHLSStream(url:)
// Build the same DecodeContext, but skip URLSession + SessionDelegateProxy.
// Hand the feeder an injection closure:
let feedAudio: @Sendable (Data) -> Void = { [weak context] data in
    context?.handleIncomingData(data)   // already decode-queue dispatched internally
}
let onFinished: @Sendable (StreamTerminationReason) -> Void = { [weak self] reason in
    Task { @MainActor in self?.handleHLSTermination(reason, generation: gen) }
}
hlsFeeder = HLSSegmentFeeder(
    playlistURL: url,
    feedAudio: feedAudio,
    onFinished: onFinished,
    onMasterVariantChosen: { [weak self] variantURL in /* log only */ }
)
hlsFeeder.start()
```

`DecodeContext.handleIncomingData(_:)` already dispatches to the decode queue and respects `isShutdown`. The feeder's URLSession callbacks happen on its delegate queue, but every byte still funnels through the same decode-queue serialization point — no new threading model.

---

## Segment Format Strategy

### V1: AAC ADTS (`.aac`) only

- AAC ADTS is the simplest HLS audio carrier: each segment is a self-syncing stream of ADTS frames. `AudioFileStream` already handles it (we use it for SHOUTcast AAC today). Segment-to-segment concatenation works because every ADTS frame has its own sync word and header — there's no global container to maintain.
- Magic cookie handling: AudioFileStream emits the cookie once for the first segment; subsequent segments don't re-emit it. Our `AudioConverterDecoder` already snapshots the cookie at converter creation time.
- Detection: segment URL extension `.aac`, OR `Content-Type: audio/aac` / `audio/aacp`. The format hint passed to `AudioFileStreamParser` is `kAudioFileAAC_ADTSType`.
- Coverage estimate (based on Apple HLS authoring spec and observed deployment): a large share of audio-only HLS — including most public radio and ad-tech mirrors — ships as ADTS. Apple's authoring spec also lists ADTS as an acceptable audio-only delivery format for legacy clients.

### V2 (deferred): MPEG-TS (`.ts`)

- `.ts` segments wrap AAC ES inside MPEG-2 Transport Stream packets (188-byte packets, PES framing). `AudioFileStream` does **not** parse TS.
- Two paths if/when needed:
  1. **Pure-Swift TS demuxer** (~500-800 lines): scan 188-byte packets, follow PMT → audio PID, extract PES, strip PES headers, hand AAC ADTS bytes to `AudioFileStreamParser`. Self-contained, no new dependency.
  2. **`AVAssetReader` on a transient file**: write segment bytes to a temp file, open with `AVAssetReader`, pull `CMSampleBuffer`s, convert to PCM. Heavier (file I/O + CMSampleBuffer decode), but uses Apple's mature TS demuxer.
- Recommendation if v2 happens: **path 1**. The TS demuxer needed for audio-only ADTS extraction is small, deterministic, allocation-bounded, and stays inside our existing decode queue. Path 2 introduces async file I/O on the decode path and breaks our "no AVPlayer / AVFoundation in the audio data path" rule.
- HaishinKit and similar Swift libraries focus on RTMP/HLS *publishing* — heavyweight, not aligned with our consumer-only need.

### V2 (deferred): fragmented MP4 (`.m4s` / `.mp4`)

- fMP4 segments require an init segment (`#EXT-X-MAP:URI=…`) that holds the `moov`/`trak` boxes. AudioFileStream can parse fMP4 with `kAudioFileMPEG4Type` *if* the init segment is fed first; some experimentation is required (init+segment concatenation is not always accepted by AFS — may need a custom box-walker to feed packets via `AudioConverterFillComplexBuffer` directly).
- Defer to v2 unless market data shows a meaningful share of audio HLS uses fMP4 (radio is overwhelmingly ADTS or TS).

### Acceptance for v1

If the chosen variant's first segment Content-Type / extension is not AAC ADTS, surface `decodeError("HLS segment format not supported (only AAC ADTS in v1)")` — non-reconnectable, lets the user pick a different stream.

---

## Live vs VOD Handling

### VOD (`#EXT-X-ENDLIST` present)

- Fetch playlist once. Segments list is final.
- Download segments serially; on last segment, `onFinished(.userStopped)` — **non-reconnectable** so the UI cleanly returns to idle. **Do not** map VOD-completion to `.serverClosed`: `.serverClosed` is reconnectable in `StreamPlayer.isReconnectable` and would loop. (Oracle fix.) An alternative is to add a new `StreamTerminationReason.streamFinished` case explicitly for "stream ended naturally, do not reconnect"; this is preferred for clarity. Plan should choose between reusing `.userStopped` (zero new surface) or adding `.streamFinished` (clearer semantics).
- No refresh loop needed.

### Live (no `#EXT-X-ENDLIST`)

- After initial fetch, schedule a refresh `Task` per **RFC 8216 §6.3.4**:
  - **First reload:** wait between half target duration and target duration (we'll use one full target duration as the conservative default).
  - **Subsequent reloads where the playlist *did* change:** wait at least target duration.
  - **Subsequent reloads where the playlist did *not* change:** wait at least half target duration before retrying.
  - Track these two cases by comparing the new playlist's last `EXT-X-MEDIA-SEQUENCE` against the previous reload's value. (Oracle fix: original wording "every TARGETDURATION/2" did not distinguish changed vs unchanged playlists.)
- On each refresh:
  1. Re-fetch playlist URL (no cache: `URLRequest.cachePolicy = .reloadIgnoringLocalCacheData`).
  2. Compare new `EXT-X-MEDIA-SEQUENCE` to last seen. New segments are at indices ≥ `(lastDownloadedSequence + 1)`.
  3. Append newly seen segment URIs to a download queue; drop already-downloaded ones.
  4. If `EXT-X-ENDLIST` newly appears → mark VOD-finalized, stop refreshing after the queue drains.
  5. If the playlist *jumps backward* in MEDIA-SEQUENCE (server reset) → log + continue with new sequence baseline.
- **Buffer-ahead policy**: keep 2-3 segments queued for download but **do not pre-download** more than 3 — radio is real-time; over-buffering wastes bandwidth and lags ICY-equivalent metadata. The existing `LockFreeRingBuffer` (32768 frames ≈ 743ms) is sufficient jitter buffer once segments arrive.
- **Refresh failure handling**: a single failed refresh is non-fatal (try once more after `targetDuration` seconds). Two consecutive failures → `networkError` → existing reconnect machinery in StreamPlayer takes over.

### Sequence-tracking state (feeder-queue-confined)

Lives in `HLSSegmentFeeder`, **on `feederQueue`**, not in `DecodeContext`:
- `lastDownloadedMediaSequence: UInt64?`
- `targetDuration: TimeInterval`
- `endlistSeen: Bool`
- `pendingSegments: [SegmentRef]` (URL + sequence + expected duration)
- `playlistChangedOnLastReload: Bool` (drives RFC §6.3.4 retry interval choice)

---

## Adaptive Bitrate (ABR) — deferred

For radio audio, variants are typically homogeneous (e.g. one or two AAC bitrates). True ABR (mid-stream switching) requires:
- Decoder reset on variant switch (different sample rate / codec config means new magic cookie).
- Bitrate measurement loop (segment download time vs duration ratio).
- Variant-switch hysteresis to avoid flapping.

None of this is needed for v1. The variant chosen at start sticks for the lifetime of the pipeline. If the user wants a different variant, they pick a different station URL.

Document as `placeholder.md` entry only if implementation reveals stations with mandatory ABR.

---

## Library Options (build vs buy)

### M3U8 parsing

- **Roll our own** (~150-250 lines of Swift). M3U8 is a line-oriented text format with simple `#EXT-X-NAME:attr1=val1,attr2="quoted val"` semantics. Parsing the v1 subset (the tags listed under "Protocol Scope") is well within reach.
- Existing Swift M3U8 packages (none widely adopted; small one-off implementations exist on GitHub) tend to either pull in too much (full HLS parser including DRM/byterange) or are abandoned. AHA Rule of Three argues against adopting a dependency for a single use site.
- **Decision:** roll our own as `MacAmpApp/Audio/Streaming/M3U8Parser.swift`. Keep it deliberately separate from `Models/M3UParser.swift` (which serves a different protocol and has different semantics — leniency around relative paths, no `#EXT-X-…` awareness).

### HLS clients

- AVFoundation's HLS support is **off-limits** for the audio data path (QA1716).
- Open-source pure-Swift HLS *consumer* libraries are rare; most are video-publishing oriented. Building our own thin client is straightforward.

### TS demuxer (if v2 happens)

- **Roll our own** if needed. As argued above, AVAssetReader on temp files breaks isolation; HaishinKit is publisher-oriented.

---

## Files Affected (complete inventory)

### New files (3)

| File | Estimated lines | Role |
|---|---|---|
| `MacAmpApp/Audio/Streaming/M3U8Parser.swift` | 200-250 | Pure-Swift HLS playlist parser. Public surface: `parseMaster([Variant])` and `parseMedia(MediaPlaylist)`. Pure value types, no I/O. |
| `MacAmpApp/Audio/Streaming/HLSSegmentFeeder.swift` | 300-400 | Owns playlist fetch + segment download loop + live-refresh timer. Decode-queue-confined state; URLSession on its own delegate queue. Calls `feedAudio` closure to push bytes into DecodeContext. |
| `Tests/MacAmpTests/HLSStreamingTests.swift` | 150-250 | Swift Testing: M3U8 parser fixtures (master, media VOD, media live, with/without #EXT-X-MEDIA-SEQUENCE, encrypted-rejected); feeder sequence-tracking unit tests with a stub URLSession. |

### Modifications (3)

| File | Change | Estimated delta |
|---|---|---|
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | Add `startHLSStream(url:ringBuffer:generation:)` branch in `start(url:)`. Add HLS-detection helper. Hold an optional `HLSSegmentFeeder` alongside `dataTask`. Extend `stopInternal()` to cancel feeder. Map feeder termination reasons → existing `StreamTerminationReason`. | +120 / -10 |
| `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` | Add a `reset()` helper used between segments **only if** AudioFileStream proves not to handle ADTS segment boundaries cleanly. Likely **no change** for v1 (ADTS frames are self-syncing). | 0 (verify in implementation) |
| `MacAmpApp/Audio/StreamPlayer.swift` | No structural change; reconnect already covers `networkError` / `playlistResolutionFailed` / `httpServerError` which the feeder reuses. Confirm logging tags ("HLSSegmentFeeder:") for diagnostics. | +10 |

### Possibly affected (verify, no expected change)

- `Audio/PlaybackCoordinator.swift` — `onFormatReady` already gates bridge activation; HLS path emits `onFormatReady` from the same `DecodeContext.formatReadyFired` logic. No change.
- `Audio/AudioPlayer.swift` — bridge activation/format negotiation unchanged.
- `Models/Track.swift` — `isStream` unchanged; HLS is still HTTP/HTTPS.
- `Models/RadioStation.swift` — unchanged.
- `Models/M3UParser.swift` — unchanged. Continues to serve legacy `.m3u`/`.m3u8` *playlist files* (the old SHOUTcast-style ones with one stream URL inside). The HLS path takes priority in `StreamDecodePipeline` based on detection.

### Operational tasks (Oracle nit applied)

- `xcodegen generate` after adding the 3 new Swift files (project.yml uses path-based source globbing, so no project.yml edit; just regenerate `MacAmpApp.xcodeproj`).
- `tasks/_context/tasks_index.md` — flip `hls-streaming-support` from PLANNED to COMPLETE on PR merge.
- `tasks/_context/state.md` — append S3 outcome row.
- `docs/MACAMP_ARCHITECTURE_GUIDE.md §4` — new "HLS audio path" subsection beside the existing progressive stream subsection.
- `docs/IMPLEMENTATION_PATTERNS.md` — append "Closure-injection seam to preserve private visibility" as a reusable pattern (justification: this seam will likely repeat in future stream-side features).

### Conflict surface check

- `M3UParser.swift` + new `M3U8Parser.swift`: deliberately separate. The legacy parser's existing call site (`StreamDecodePipeline.resolvePlaylistURL`) only fires when detection has *not* already routed to HLS.
- The collision case "user has a 1990s `.m3u8` file containing one HTTP URL to an HLS stream" works: legacy parse extracts the URL → that URL is itself `.m3u8` → second pass through `start(url:)` → HLS branch fires.

---

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| **Detection ambiguity** for `.m3u8` URLs that contain legacy single-URL playlists vs HLS | Medium | Sniff `#EXT-X-` after `#EXTM3U`; fall through to legacy parser if absent. Unit test both cases. |
| **AudioFileStream segment-boundary glitches** for ADTS | Medium | ADTS is designed to be re-syncable; AFS recovers on the next sync word. If audible glitches occur, add a `parser.reset()` on segment boundary. Sine-wave-test path validates engine, MP3 dump path validates pre-decoder (Lessons 1+3). |
| **Live playlist drift / sequence wraparound** | Low | Treat backward sequence jump as server reset; rebase from new sequence. Cap reconnect attempts via existing `StreamPlayer` policy. |
| **`onFormatReady` never fires** if first segment is too small to reach prebuffer threshold | Low-Medium | The existing 16384-frame threshold is ~371ms at 44.1kHz. Typical HLS audio segment is 6-10s, far beyond threshold. If a station ships sub-200ms segments, lower threshold to 8192 frames specifically for HLS. Defer until observed. |
| **Refresh task leak across restarts** | Medium | All refresh `Task`s capture `[weak self]` and check the pipeline `generation` token before applying results. `stopInternal()` cancels feeder which cancels its refresh task. Mirror the pattern from `StreamPlayer.reconnectTask`. |
| **Encrypted streams crash the parser** | High → Mitigated | Detect `#EXT-X-KEY:METHOD≠NONE` during master/media parse; fail fast with `playlistResolutionFailed("Encrypted streams not supported")`. **Never** feed encrypted bytes to AudioFileStream — its behavior with encrypted ADTS is undefined and may produce extreme noise. |
| **Workgroup join/leave on segment HTTP delegate queue** | Low | Workgroup is joined inside `DecodeContext.handleIncomingData`, which is the same single chokepoint for HLS-fed bytes. No new join sites. |
| **Visibility widening for DecodeContext** | Low | Use closure injection (`feedAudio: @Sendable (Data) -> Void`) instead of widening `DecodeContext` visibility — preserves Principle 5. |
| **A/V "ICY-equivalent" metadata loss for HLS** | Low | HLS does not support inline ICY by spec. Some stations expose `#EXTINF:duration,artist - title` per segment; we can opportunistically parse the title field if present and emit it via `onMetadata` (best effort). Not a regression — current behavior for HLS is "no playback at all". |

---

## Phasing Recommendation

### V1 (this task — single PR)

1. **`M3U8Parser.swift`** — master + media playlists; encrypted/byterange/fMP4 detection-and-reject. Pure value types. Full test coverage on fixtures.
2. **`HLSSegmentFeeder.swift`** — playlist fetch, variant selection, serial segment download, live refresh loop, sequence tracking, termination mapping. Confined to decode queue plus its own URLSession delegate queue.
3. **`StreamDecodePipeline.swift`** — add HLS detection (extension + Content-Type + sniff) and `startHLSStream(...)` branch. Reuse `DecodeContext` via injected `feedAudio` closure.
4. **`AAC ADTS` segment support only.** TS / fMP4 segments → "format not supported" error.
5. **No ABR**, no master-with-alternates renditions (fail fast), no DRM, no LL-HLS.
6. **Tests**: parser fixtures, feeder unit tests with fake URLSession, integration-level smoke test that points at a known-good public AAC HLS stream and waits for `onFormatReady`.
7. **Docs update**: `docs/MACAMP_ARCHITECTURE_GUIDE.md §4` — add "HLS audio path" subsection. `tasks/_context/state.md` — mark task complete. `placeholder.md` for any deferrals discovered during implementation.

### V2 (separate task if needed)

- **MPEG-TS demuxer** — pure-Swift TS → ADTS extraction.
- **fMP4 init segment** handling.
- **Adaptive bitrate** if telemetry shows users hitting bandwidth-constrained variants.
- **#EXT-X-DISCONTINUITY** explicit handling (decoder reset across discontinuity).

### V3 (probably never for radio)

- **Low-Latency HLS** (`#EXT-X-PART`).
- **AES-128 segment decryption** if a notable station requires it.

---

## Open Questions

1. **Should HLS detection be allowed to "promote" a non-`.m3u8` URL based on Content-Type?** Trade-off: extra request on first response failure vs handling stations that publish HLS at extension-less endpoints. Recommendation: yes, but only on first response — never again for the lifetime of the pipeline (avoid loops).
2. **Do we need `parser.reset()` between ADTS segments?** Empirically AFS handles ADTS resync; but if any station produces audible boundary clicks, add a reset hook. Verify during implementation by running an HLS stream end-to-end and listening; reuse the WAV/MP3 dump methodology from Lesson 3.
3. **Should `HLSSegmentFeeder` own its own URLSession or reuse `URLSession.shared`?** Recommendation: own it. Different timeouts (segments are short and bounded; playlists are short text), different cache policy (always-reload for live), and clean cancel-on-stop. Mirrors `StreamDecodePipeline`'s pattern.
4. **What does `displayDuration` show for HLS VOD?** Today, `PlaybackCoordinator.displayDuration` returns 0 for radio. We *could* sum segment durations for VOD, but that requires plumbing. Recommendation: leave at 0 for v1 (no UI regression); revisit only if user-visible.
5. **Should `EXTINF` titles populate `streamTitle`?** Some HLS radio injects per-segment metadata via `EXTINF:duration,title`. If the title field is non-empty and changes, emit a synthetic `ICYFramer.ICYMetadata`. Cheap to add, no harm if titles never appear. Recommend yes.

---

## Gemini Research Findings

A focused Gemini deep-research prompt was issued covering: (a) audio-only HLS variant distribution in radio, (b) AVAssetResourceLoaderDelegate vs MTAudioProcessingTap behavior, (c) Swift M3U8 parser ecosystem, (d) MPEG-TS demuxing complexity in Swift, (e) live playlist refresh patterns, (f) Apple HLS authoring requirements for audio-only, (g) detection heuristics. The Gemini call did not produce structured output before this research file was finalized; the architecture proposed here therefore relies on:
- RFC 8216 (HLS spec) directly
- Apple's HLS Authoring Specification (referenced in `tasks/done/unified-audio-pipeline/research.md` notes)
- Prior MacAmp deep-research findings already captured in `tasks/done/unified-audio-pipeline/research.md` §"Updated Open Questions" item 4: *"individual .ts/.aac segments from parsed HLS .m3u8 playlists can be fed to AudioFileStream"* — independent confirmation of the Option A architecture.
- Direct codebase inspection of HEAD as of 2026-04-27.

If implementation reveals a question not answered above (most likely: real-world TS/fMP4 prevalence among target radio stations), re-run the Gemini prompt at planning time. The architecture as designed degrades gracefully: an unsupported segment format produces a clear non-reconnectable error rather than corruption.

---

## Oracle Validation Summary

**Reviewer:** `gpt-5.3-codex` at `xhigh` reasoning effort, read-only sandbox, files passed as @-references (this research.md, StreamDecodePipeline.swift, AudioFileStreamParser.swift, AudioConverterDecoder.swift, StreamPlayer.swift, principles.md).

**Initial score:** 7/10.

### Actionable findings (FIXED inline above)

| # | Finding | Disposition |
|---|---|---|
| 1 | VOD end mapped to `.serverClosed` (which is reconnectable in `StreamPlayer.isReconnectable`) — would cause reconnect loop on natural end | **FIXED** in "Live vs VOD Handling" → VOD: map to `.userStopped` (non-reconnectable) or add new `.streamFinished` case. Plan picks one. |
| 2 | Encrypted/fMP4/no-audio-variant rejection used `.playlistResolutionFailed` which is reconnectable | **FIXED** in "What we MUST reject" table — all three now map to `.decodeError` (non-reconnectable) with explicit reconnectability rule documented. |
| 3 | Detection branch logic said `.m3u8 → HLS` directly, contradicting "sniff resolves the collision" | **FIXED** in "Detection Strategy" → `.m3u8` is now an *ambiguous routing hint*, sniff is dispositive. New flow diagram shows fetch-then-sniff before routing to HLS or legacy. |
| 4 | `#EXT-X-DISCONTINUITY` "log and continue" is too lax vs RFC client guidance | **FIXED** in "What we MAY tolerate" → on discontinuity, call new `parser.reset()` hook on AudioFileStreamParser to flush partial-frame state. AudioFileStreamParser.swift gets a small new method (called out in "Files Affected"). |
| 5 | Feeder concurrency boundary was ambiguous (queue-confined vs decode-queue-confined vs URLSession delegate queue) | **FIXED** in "Recommendation: Option A" → single `feederQueue` is the confinement boundary; URLSession delegate queue is callbacks-only; decode queue stays owned by `DecodeContext`. |
| 6 | RFC 8216 §6.3.4 reload timing was simplified to "every TARGETDURATION/2" | **FIXED** in "Live (no `#EXT-X-ENDLIST`)" → explicit handling of changed-vs-unchanged playlist intervals. |

### Nitpicks (FIXED)

| # | Finding | Disposition |
|---|---|---|
| N1 | Missing stale-generation short-circuit in feed path | **FIXED** in "Recommendation: Option A" → `feedAudio` closure compares captured generation against a `@Sendable () -> UInt64` getter from the pipeline before forwarding bytes. |
| N2 | File inventory missed operational steps (xcodegen, tasks_index, IMPLEMENTATION_PATTERNS) | **FIXED** in new "Operational tasks" subsection under "Files Affected". |

### Rejected (none)

No findings rejected. All 6 actionable + 2 nitpick items applied inline.

### Re-validation

A second Oracle pass would be appropriate when `plan.md` exists, since the plan will need to materialize the closure-seam, the parser-reset hook, and the explicit termination mapping. Defer that to the planning step.

---

## Appendix: HEAD line numbers (for plan.md author)

- `StreamDecodePipeline.start(url:)` — line 108
- `StreamDecodePipeline.isPlaylistURL(_:)` — line 358
- `StreamDecodePipeline.resolvePlaylistURL(_:)` — line 365
- `StreamDecodePipeline.formatHint(for:)` — line 434
- `DecodeContext.handleIncomingData(_:)` — line 537
- `DecodeContext.shutdown()` — line 561
- `DecodeContext.handlePackets(...)` — line 612
- `StreamPlayer.handleTermination(_:)` — line 272
- `StreamPlayer.attemptReconnect()` — line 305
- `M3UParser.parse(content:relativeTo:)` — line 37 (legacy, kept in place)
- `Track.isStream` — line 17
