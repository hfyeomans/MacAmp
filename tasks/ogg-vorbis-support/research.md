# Research: OGG Vorbis Support

> **Purpose:** Add OGG Vorbis decoding to MacAmp's audio pipeline (local files + Icecast streams).
> **Sprint:** S3 (LOW priority, deferred from `unified-audio-pipeline` Phase 2.4).
> **Created:** 2026-04-27.

---

## Context + Scope

MacAmp ships an `AVAudioEngine`-backed pipeline that already handles MP3 + AAC for both local files and HTTP/Icecast streams. **Vorbis is the one mainstream lossy codec Apple AudioToolbox refuses to decode.** Adding it requires bringing our own decoder.

**Two surfaces in scope:**
- **Local files:** `.ogg` and `.oga` on disk (Vorbis-in-Ogg).
- **Streams:** Icecast endpoints serving `application/ogg` / `audio/ogg` with Vorbis as the inner codec.

**Both must integrate with the existing AVAudioEngine graph** (10-band EQ, 20-bar visualizer, balance, master volume) — feature parity with MP3/AAC. This is non-negotiable per the unified-pipeline design: *"any source → decode to PCM → engine"*.

**Out of scope:** Opus, FLAC, Speex (separate future tasks). HLS-Vorbis (vanishingly rare). Vorbis encoding (we never encode anything).

---

## Current Architecture (Where MP3/AAC Integrate)

### Local file path (`AudioPlayer.swift` → `AudioEngineController.swift`)

```
URL → AVAudioFile(forReading:) → AVAudioPlayerNode → EQ → mainMixer → output
```

Apple's `AVAudioFile` opens the file and returns a `processingFormat` (Float32, n-channel). `AVAudioPlayerNode.scheduleSegment(_:startingFrame:frameCount:at:)` schedules ranges for playback. **The pipeline assumes random-access seeking and `file.length` in frames.** Vorbis-in-Ogg supports both, but `AVAudioFile` will fail to open a `.ogg` file because Core Audio cannot decode Vorbis.

Detection points:
- `AudioPlayer.detectMediaType(url:)` — line 369. Currently only branches on video extensions (`mp4/mov/m4v/avi`); everything else falls through to `.audio` and `loadAudioFile()`.
- `AudioPlayer.loadAudioFile(url:)` — line 374. Calls `engine.loadFile(url:)` → `AVAudioFile(forReading: url)` → `throws` on Vorbis.
- `MetadataLoader.loadTrackMetadata(from:)` and `loadAudioProperties(from:)` use `AVURLAsset`. **AVURLAsset does not understand Ogg-Vorbis either** — it reads container-level fields when available, otherwise returns fallbacks.

### Stream path (`StreamDecodePipeline.swift` + `DecodeContext`)

```
URLSession bytes
  → SessionDelegateProxy (NSObject delegate proxy)
  → DecodeContext (queue-confined)
      → ICYFramer.consume()                      (strip Icecast metadata blocks)
      → AudioFileStreamParser.parse()            (MP3/AAC packet extraction)
      → AudioConverterDecoder.decode()           (compressed packets → Float32 stereo PCM)
      → LockFreeRingBuffer.write()
                                                 (real-time boundary)
              ← AVAudioSourceNode renderBlock (reads ringBuffer.read())
                                                 → EQ → mainMixer → output
```

**Format detection / branch points:**
- `StreamDecodePipeline.formatHint(url:)` — line 434. Returns `kAudioFileMP3Type`, `kAudioFileAAC_ADTSType`, or 0. **Vorbis has no `kAudioFile*Type` constant** because AudioToolbox does not support it. This is the structural branch where Vorbis must diverge.
- `DecodeContext.handleFormatAvailable(_:)` — fires when AudioFileStreamParser detects an ASBD. **Will never fire for OGG** because the parser refuses to recognise Ogg pages. The OGG path must bypass `AudioFileStreamParser` + `AudioConverterDecoder` entirely.
- ICY metadata: Icecast OGG streams typically *do not* send `icy-metaint` (ICY metadata blocks would corrupt Ogg page boundaries). Instead, song metadata is embedded as Vorbis comments in periodic chained Ogg streams. **`ICYFramer.configure(metaInterval: 0)` is the natural no-op path** — already supported. We must NOT route Ogg bytes through ICY framing when `icy-metaint` is absent (already correct behaviour).

### Real-time contract on the consumer side
`AVAudioSourceNode` is fed via `LockFreeRingBuffer` (interleaved Float32 stereo). Whatever decoder we choose must ultimately produce *exactly that*: interleaved Float32 stereo at the stream's native sample rate (engine handles SRC). **No new ring buffer or render block is needed.**

---

## Vorbis + Ogg Background

- **Vorbis** — patent-free lossy audio codec, `xiph.org`. ~1.0 reference encoder (`libvorbis 1.3.7`, 2020). Variable bitrate, MDCT-based, supports 1–255 channels and 8 kHz–192 kHz. Comparable quality to MP3 at lower bitrates (~96–192 kbps sweet spot).
- **Ogg** — generic page-based container (RFC 3533/5334). Stores arbitrary codec packets in fixed-size pages (4 KB default). Each page begins with `'OggS'` (`0x4F 0x67 0x67 0x53`). Page header carries page sequence number, granule position (codec-specific timestamp), and a 32-bit CRC.
- **Vorbis-in-Ogg** — first three packets of a Vorbis logical stream are the *identification header*, *comment header*, and *setup header*. Identification packet starts with `0x01` followed by ASCII `"vorbis"` (i.e. magic `01 76 6F 72 62 69 73`). It carries sample rate, channel count, and bitrate hints.
- **Vorbis comments** — UTF-8 `KEY=VALUE` pairs in the second packet. Common keys: `TITLE`, `ARTIST`, `ALBUM`, `DATE`, `TRACKNUMBER`, `GENRE`. Independent of ID3v2.

**Codec ≠ container.** Ogg pages can also carry Opus (`OpusHead` magic), FLAC (`fLaC` magic), Speex, and Theora video. Discrimination requires reading the first packet of the first logical stream.

---

## Library Options

### Option A — libvorbis + libogg (Xiph reference)

- **Project:** xiph.org. `libogg 1.3.5` (2021), `libvorbis 1.3.7` (2020), `libvorbisfile` (the high-level convenience API).
- **Language:** C89, no exotic deps.
- **Static size:** ~370 KB combined (arm64, `-Os`); ~250 KB stripped.
- **API for our use case:** `libvorbisfile`'s `ov_open_callbacks` for local files (callback-based, lets us feed bytes from any source) + manual `ogg_sync_state`/`vorbis_dsp_state` for streams.
- **Quality:** Reference. By definition the bit-exact ground truth.
- **Maturity:** Powers VLC, Firefox, Chromium, Audacity, ffmpeg fallback. Battle-tested for 25 years.
- **Streaming friendliness:** First-class. `ogg_sync_buffer` / `ogg_sync_wrote` / `ogg_sync_pageout` is a pull-based stream parser designed for incremental input.

### Option B — stb_vorbis (single-header, public domain)

- **Project:** Sean Barrett, `nothings/stb`. `stb_vorbis.c` is a single ~5,500-line C file.
- **License:** Public domain / MIT (dual).
- **Static size:** ~80 KB compiled (arm64, `-Os`). About a third of libvorbis+libogg.
- **API:** Two modes — *pulldata* (whole file in memory, simpler) and *pushdata* (incremental — `stb_vorbis_open_pushdata` + `stb_vorbis_decode_frame_pushdata`). Pushdata is the streaming-friendly path.
- **Quality:** Sean Barrett's own notes (header docblock) acknowledge minor numeric differences from reference libvorbis but no audible artifacts have been reported in the wild for Vorbis q0 through q10. Used in id Tech engines, Unity (historical), Godot, dozens of games. **No published PEAQ/ODG comparison** (lack of formal evaluation is itself a small risk for an audiophile use case, though Vorbis at music-quality bitrates is far above the audibility threshold of decoder-side numerical noise).
- **Container:** Built-in Ogg demuxer for *single-Vorbis-stream Ogg files*. Does NOT handle chained Ogg streams (Icecast often chains streams when metadata changes). This is a known limitation.
- **Streaming friendliness:** Pushdata API tolerates incremental input *for the audio packets*. **Chained stream handling is the real concern for Icecast** — see "Risk Assessment" below.

### Option C — Pure Swift / Vorbis.rs

- **State of the art (2024-2026):** No mature pure-Swift Vorbis decoder. Searched Swift Package Index, GitHub `language:swift vorbis`, Hacker News. Found two abandoned proof-of-concept ports (last commits 2018-2020), neither with format compliance tests. **Not viable.**
- A Rust port (`lewton`) is well-tested but introduces a Rust toolchain into the build — outsized infrastructure cost for a single codec.

### Option D — Apple AudioToolbox tricks

- Confirmed: no hidden support. `kAudioFormatLinearPCM`, `kAudioFormatMPEGLayer3`, `kAudioFormatMPEG4AAC`, `kAudioFormatFLAC` (added macOS 11), `kAudioFormatOpus` (added macOS 14) — but **no `kAudioFormat*Vorbis*`**, no `kAudioFileOggType`. Apple has never shipped Vorbis. This is the gap the task exists to fill.

### Option E — ffmpeg via FFmpegKit

- Pulls in ~25 MB of binaries for one codec. License compliance (LGPL dynamic linking on macOS) requires care. Massively overkill. Reject.

### Recommendation: **Option A (libvorbis + libogg)**

**Rationale:**
1. **Streaming correctness is the harder half** of this task; libvorbis's ogg_sync API is the gold standard for incremental Icecast input including chained streams. stb_vorbis's chained-stream gap is a real risk for Icecast — many stations chain on every metadata change.
2. **Size is not the constraint.** MacAmp's release `.app` is ~30 MB; +300 KB for the gold-standard decoder is invisible. We're not shipping for embedded/games where stb_vorbis shines.
3. **Quality reference.** Eliminates one dimension of risk for a feature that has to "just work" for audiophile users (auto-EQ, classic Winamp parity).
4. **Vorbis comments are first-class** in libvorbisfile — `ov_comment()` returns a parsed `vorbis_comment` struct.

**stb_vorbis is the clear backup if Phase A integration friction is high** — start with libvorbis, fall back to stb_vorbis only if SwiftPM C interop turns into a yak shave longer than two days.

---

## License Analysis

| Library | License | MacAmp `LICENSE` | Compatible? |
|---|---|---|---|
| libvorbis | Xiph BSD-3-Clause variant | MIT | YES |
| libogg | Xiph BSD-3-Clause variant | MIT | YES |
| stb_vorbis | Public domain / MIT (dual) | MIT | YES |

**Distribution requirements (BSD-3-Clause):**
- Reproduce copyright notice + disclaimer in distribution.
- Cannot use Xiph trademarks for endorsement.

**Implementation:** Bundle a `Resources/THIRD_PARTY_LICENSES.txt` (or `.bundle/Contents/Resources/Credits.rtf` — macOS About dialog convention) containing the verbatim Xiph BSD notice. No NOTICE-style file required (NOTICE is Apache-specific). Update `Package.swift` `resources:` array.

**Notarization / Hardened Runtime:** No issue. Static archives of permissively-licensed C are routinely shipped through Apple notarization. No special entitlements. Decoding is in-process with no IPC, no JIT, no executable memory — Hardened Runtime defaults are fine.

**Patents:** Vorbis is intentionally patent-unencumbered. Xiph holds defensive patents. No royalty obligation.

---

## Integration Architecture

### Branch point: format detection upgrade

A new `AudioCodec` enum (or extension to existing detection) with three call sites:

1. `AudioPlayer.loadAudioFile(url:)` (local files) — branch on extension.
2. `StreamDecodePipeline.formatHint(for:)` (streams) — branch on extension AND HTTP `Content-Type`.
3. `DecodeContext` initialization — choose Vorbis decoder vs. AudioConverter pipeline.

**Architecture choice (revised after Oracle review):** Introduce a `StreamBackend` **enum** (sum type), NOT a protocol with strategy objects.

```swift
// Inside DecodeContext (or its replacement)
private enum StreamBackend {
    case audioConverter(AudioFileStreamParser, AudioConverterDecoder)
    case vorbis(VorbisStreamDecoder)
}
private var backend: StreamBackend?
```

**Why an enum, not a protocol with adapter classes:**
- Oracle (Principle 6) flagged the original `StreamDecoder` protocol proposal as a Principle-6 pass-through middleman risk. A protocol where each conformance forwards `feed(bytes:)` and emits PCM events with no added invariants is exactly the anti-pattern.
- Oracle (Principle 3) flagged state-ownership fragmentation: `DecodeContext` already owns all queue-confined mutable state. Splitting parser/decoder/control flags across "strategy" files weakens single-source-of-truth.
- Sum-type keeps ownership in one place and makes the codec branch explicit at every call site.

**Each enum case is a pure mechanism** (parser/decoder pair) emitting typed events (PCM frames + format changes + metadata) into the surrounding `DecodeContext` which still owns all control flags, generation tokens, prebuffer state, ring buffer, and workgroup. No adapter objects; no forwarding shims.

### Local files — Path A (REVISED, was "RECOMMENDED"): scheduleBuffer chunks into AVAudioPlayerNode

> **Oracle (CRITICAL, 2026-04-27):** The original "AVAudioSourceNode pull-loop" proposal *broke* the existing local-playback contracts. `AudioPlayer`/`AudioEngineController` assume local playback == `AVAudioFile` + `AVAudioPlayerNode.scheduleSegment` (`audioFile != nil`, `file.length`, `playerTime`, completion callback). A source-node/ring-buffer local path silently breaks play/pause/seek/progress/completion semantics unless we first introduce a `LocalPlaybackBackend` abstraction (months of work).
> **Revised plan:** keep `AVAudioPlayerNode`. Decode Vorbis to PCM in chunks via libvorbisfile, schedule each chunk via `playerNode.scheduleBuffer(_:completionHandler:)`. Same node, same EQ wiring, same progress timer.

```
URL → libvorbisfile (ov_open_callbacks)
        → pull Float32 stereo PCM in N-frame buffers (e.g., 8192 frames)
        → AVAudioPCMBuffer
        → playerNode.scheduleBuffer(buffer) [chained completion]
        → existing playerNode → EQ → mainMixer → output
```

- **No new transport.** AudioEngineController's `loadFile` / `scheduleFrom` / `currentFileDuration` keep their public shape. New `VorbisFileSource` becomes the substrate behind a *minimal* abstraction:
  - For `.mp3`/`.flac`/etc. (AVAudioFile-supported): existing path (`AVAudioFile` + `scheduleSegment`).
  - For `.ogg`/`.oga`: `VorbisFileSource` + chained `scheduleBuffer` calls.
- **Seek:** `ov_pcm_seek(file, sampleFrame)` + clear scheduled buffers (`playerNode.stop()`) + resume scheduling from new position. Maps cleanly onto existing `seek(to:)`.
- **Duration:** `ov_pcm_total(file)` → frames → seconds. `currentFileDuration` becomes "AVAudioFile.length / sampleRate" *or* "ov_pcm_total / sampleRate", picked at load time. `AudioEngineController.currentFileDuration` already only reads from `audioFile`; introduce a `currentSource` abstraction (sum type) that has both implementations.
- **Progress:** `playerTime` (sample-clock-based) still works because we're still using `AVAudioPlayerNode`. **No regression.**
- **Completion:** `scheduleBuffer` completion handler chains the next buffer; the *last* buffer's completion fires `onPlaybackEnded` (matches existing `scheduleSegment` completion semantics).
- **Trade-off:** Decoder state must persist across the lifetime of the file; seeking restarts decode from the seeked sample. Slightly more state than `AVAudioFile` but contained inside `VorbisFileSource`.

**Net change to AudioEngineController:** introduce a small `LocalAudioSource` enum (`.avAudioFile(AVAudioFile) | .vorbis(VorbisFileSource)`) and route `scheduleFrom`/`currentFileDuration`/`clearFile` through it. ~60 lines of changes, no new transport.

### Local files — Path B (alternative): Pre-decode to PCM

- Decode entire `.ogg` to a temp WAV via libvorbisfile, then load via `AVAudioFile`.
- **Pro:** zero changes to playback graph, AVAudioPlayerNode handles everything.
- **Con:** ~10 MB per minute of audio in /tmp. A 60-minute album = 600 MB temp file. Disk IO on track open. Eject must clean up. **Reject** — not viable for normal listening.

### Local files — Path C (alternative): Decode to in-memory `AVAudioPCMBuffer`

- Like Path B but in RAM.
- **Pro:** no temp file, no graph changes.
- **Con:** ~10 MB/min RAM. Long mixes/audiobooks (8h podcasts via .ogg) become 5 GB. **Reject** — silently breaks for legitimate use cases.

### Streams — single path

```
URLSession bytes
  → SessionDelegateProxy
  → DecodeContext (Vorbis decoder branch)
      → libogg ogg_sync_buffer/wrote/pageout    (incremental Ogg page assembly)
      → libvorbis vorbis_synthesis_blockin       (decode packets to PCM)
      → Float32 stereo (downmix if N>2 channels)
      → LockFreeRingBuffer.write()
              ← AVAudioSourceNode renderBlock
```

- **No ICY framing.** Icecast OGG streams never set `icy-metaint`. `ICYFramer.configure(metaInterval: 0)` already passes bytes through unchanged — already correct.
- **Metadata:** Vorbis comments arrive in the stream's second packet. For chained Icecast streams, a new comment header arrives every chain boundary (typically per-track).

> **Oracle (MEDIUM, 2026-04-27):** Reusing `ICYFramer.ICYMetadata(title:artist:)` was structurally convenient but semantically leaky — the type name ties the model to the ICY protocol and Latin-1 framing semantics that have nothing to do with Vorbis. Rename / promote to a shared `NowPlayingMetadata` struct with the same shape (`title: String?`, `artist: String?`); ICY and Vorbis are both adapters that produce this shared model.

  Implementation: rename `ICYFramer.ICYMetadata` → `StreamMetadata` (or `NowPlayingMetadata`) at the type level; existing `onMetadata` callback signatures change in lock-step. Backwards-compatibility shim is unnecessary (internal type, no external API surface).
- **Format ready:** Fire `onFormatReady(sampleRate)` after `vorbis_info` is decoded (first ~1-2 KB of stream).
- **Bridge activation:** No changes. `PlaybackCoordinator.streamPlayer.onFormatReady` already activates the engine bridge (`AudioEngineController.activateStreamBridge`).

### Recommended split

- New file `MacAmpApp/Audio/Streaming/VorbisDecoder.swift` — Swift wrapper around libvorbisfile callbacks.
- New file `MacAmpApp/Audio/Streaming/OggDecodeStrategy.swift` (or merged into `DecodeContext`) — implements `StreamDecoder` protocol for the Vorbis branch.
- New file `MacAmpApp/Audio/VorbisFileSource.swift` (Path A) — local-file pull source, plays role analogous to `AVAudioFile` on the AudioConverter path.
- Modified `AudioPlayer.swift` — branch `loadAudioFile(url:)` on extension.
- Modified `AudioEngineController.swift` — alternative `loadFile`/scheduling path for Vorbis local files (or generalized to "PCM source", with AVAudioFile + Vorbis as two implementations).

---

## Build / SwiftPM Integration Approach

### Option 1 — Vendored C sources as a SwiftPM `cTarget` (RECOMMENDED)

Add to `Package.swift`:

```swift
.target(
    name: "Cogg",
    path: "Vendor/libogg",
    sources: ["src/bitwise.c", "src/framing.c"],
    publicHeadersPath: "include",
    cSettings: [.headerSearchPath("include")]
),
.target(
    name: "Cvorbis",
    path: "Vendor/libvorbis",
    sources: ["lib/analysis.c", "lib/bitrate.c", /* ...lots... */],
    publicHeadersPath: "include",
    cSettings: [
        .headerSearchPath("include"),
        .headerSearchPath("lib"),
    ],
    linkerSettings: [.linkedLibrary("m")]
),
```

**Gotchas:**
- libvorbis ships with a `config_types.h.in` autoconf template. Vendor a pre-generated `config_types.h` for arm64+x86_64 macOS (typedefs `ogg_int16_t = int16_t` etc.). One file, frozen since 2008.
- libvorbis depends on libogg headers — `Cvorbis` declares `dependencies: [.target(name: "Cogg")]`.
- modulemap: SwiftPM auto-generates from `publicHeadersPath`; verify no name collisions (libogg `os_types.h` vs system `os/types.h` — namespace via folder layout).
- XcodeGen (`project.yml`): the `.target(name: "Cogg")` and `Cvorbis` SwiftPM targets become regular dependencies. The `MacAmp` Xcode target imports `Cvorbis` via `import Cvorbis`. **No project.yml change needed** beyond adding `Cogg`/`Cvorbis` to the package's `Package.swift` if we wire them as SwiftPM products. **However:** MacAmp's primary build is the `.xcodeproj` generated from `project.yml`, NOT SwiftPM. Need to verify XcodeGen pulls in the local SwiftPM C targets. Likely requires adding them as `packages:` entries pointing to `path: ./Vendor/...`.

### Option 2 — Pre-built xcframework

- Build libvorbis + libogg static archives once for arm64 + x86_64 macOS.
- Wrap as `Vorbis.xcframework`.
- Reference via `binaryTarget(name: "Vorbis", path: "Vendor/Vorbis.xcframework")`.

**Pros:** Smaller PR diff. No 5000+ line C files in the repo.
**Cons:** Maintenance burden — can't easily update upstream, pre-builds can drift from source. Apple Silicon-only releases would need re-builds when Apple changes ABI defaults. Reproducibility of the binary becomes a security concern.

### Option 3 — System library via Homebrew (`brew install libvorbis`)

- `.systemLibrary(name: "Cvorbis", pkgConfig: "vorbis", providers: [.brew(["libvorbis"])])`.
- **Reject.** Forces every developer + CI runner to install Homebrew + libvorbis. Notarization on a clean machine fails. Only acceptable for dev tools, not shipped apps.

### Recommendation: **Option 1 (vendored sources, SwiftPM cTarget) — PENDING SPIKE**

> **Oracle (HIGH, 2026-04-27):** "No project.yml change needed" was not credible. MacAmp builds from XcodeGen `project.yml`; the app target does NOT automatically inherit root `Package.swift` target graph just because the package exists. The Package.swift dependencies (`ZIPFoundation`, `swift-atomics`) are wired through `project.yml`'s `packages:` block and per-target `dependencies` — `Cogg`/`Cvorbis` need the same treatment via a *local* SwiftPM package or sibling targets.
> Risk re-rating: **medium-high**, not low. Confidence in Option 1 is conditional on a successful build wiring spike.

- One-time vendor cost (~3 MB of source) is offset by zero ongoing dependency-management burden.
- Reproducible builds on any Mac with Xcode.
- Clean SwiftPM hygiene IF and only if the spike confirms wiring works.

**Required pre-plan spike:**
1. Add `Vendor/COggVorbis/Package.swift` defining `Cogg` + `Cvorbis` cTargets with one trivial source file each (e.g., a `.c` containing only `int og_smoke(void){return 42;}`).
2. Add `packages:` entry in `project.yml` pointing to `path: ./Vendor/COggVorbis`.
3. Add `dependencies: [package: COggVorbis, product: Cogg]` to the `MacAmp` target in `project.yml`.
4. Run `xcodegen generate` + `xcodebuild -scheme MacAmpApp build`.
5. Add `import Cogg` to a Swift file. Call `og_smoke()`. Verify build.

If this works → vendor full sources. If it fails → fallback to Option 2 (xcframework). The spike is a few hours of work and is mandatory before plan.md commits to a build approach.

---

## Detection Strategy

### Local files

```swift
private static let vorbisExtensions: Set<String> = ["ogg", "oga"]
```

Check `url.pathExtension.lowercased()`. Used to branch in `AudioPlayer.loadAudioFile(url:)` and `MetadataLoader` (skip `AVURLAsset` entirely for `.ogg` — go straight to libvorbisfile for metadata).

**Edge case:** `.ogg` is also used for OGG Opus / OGG FLAC / OGG Speex. The `.oga` extension is recommended-by-Xiph for "Ogg Audio (any codec)". If we open a `.ogg` and find Opus inside, we currently can't decode — **fail with a clear "OGG Opus not supported" error** (Opus comes in a future task). Same for FLAC/Speex inside Ogg.

### Streams

Triple-check with priority order:
1. **HTTP `Content-Type` header** — most reliable.
   - `application/ogg` → Ogg container, codec TBD.
   - `audio/ogg` → Ogg with audio codec, codec TBD (RFC 5334 deprecates `application/ogg` in favour of `audio/ogg` for audio).
   - `audio/vorbis` → Vorbis (rare in the wild but RFC-blessed).
2. **URL extension** — fallback when servers omit Content-Type.
3. **Magic byte sniffing** — final fallback. First 4 bytes `'OggS'` (`0x4F 0x67 0x67 0x53`) → it's an Ogg page. To discriminate codec, read the first packet of the first logical stream:
   - First byte `0x01` + ASCII `"vorbis"` → Vorbis.
   - First 8 bytes `"OpusHead"` → Opus.
   - First 4 bytes `"fLaC"` → FLAC-in-Ogg.
   - `"Speex   "` (with spaces) → Speex.

**Implementation:** Add `OggCodecSniffer` that consumes the *first complete BOS (Beginning-Of-Stream) Ogg page*, then reads the first packet inside, returning `.vorbis | .opus | .flac | .speex | .unknown`.

> **Oracle (HIGH, 2026-04-27):** "First ~64 bytes" was wrong. Ogg page header is 27 bytes minimum + segment table (variable). The first packet in the page contains the codec ID; for Vorbis the magic is at byte offset 0 of the packet body but the page must be reassembled first. Sniffing should buffer **until the first complete page is available, capped at 4-8 KB or 250 ms timeout** with explicit error on overshoot. Default Ogg page size is ~4 KB so 8 KB is a safe upper bound.

> **Oracle (HIGH, 2026-04-27):** Detection flow conflicts with current `DecodeContext` lifecycle. The current code creates the parser eagerly in `DecodeContext.init` and starts parsing the first chunk immediately ([StreamDecodePipeline.swift:497-523](../../MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift#L497)). For "sniff first, then choose decoder" we need a new explicit startup state: collect bytes into a buffer, classify codec when threshold reached, then instantiate backend and **replay buffered bytes through it**. Add to plan as an explicit pipeline phase: `Connecting → Sniffing → DecoderSelected → Buffering → Playing`.

**`StreamDecodePipeline.formatHint(for:)` upgrade** — replace the `AudioFileTypeID` return with a richer enum:

```swift
enum StreamFormatHint: Sendable {
    case mp3, aacADTS
    case oggVorbis
    case unknown
}
```

Branched on extension AND `Content-Type`. Magic byte sniffing happens later in DecodeContext after first bytes arrive.

---

## Phasing Recommendation (v1 Minimum Viable)

**v1 (this task):** Vorbis-in-Ogg only. Local files + Icecast streams.

> **Oracle (MEDIUM, 2026-04-27):** Phasing was directionally fine but mis-risked Phase 1 as Low. Build wiring is "low complexity if it works" but the *probability of failure* is medium until the SwiftPM-cTarget-from-XcodeGen spike succeeds. Local-path phase under-priced the abstraction work needed in `AudioEngineController`. Inserted explicit **Phase 0 — viability spikes** with hard pass/fail gates.

| Phase | Scope | Risk | Pass/fail gate |
|---|---|---|---|
| **0a. Build wiring spike** | Trivial `Cogg`+`Cvorbis` SwiftPM cTargets via `Vendor/COggVorbis/Package.swift`; wire through `project.yml` `packages:` block. Smoke test = `import Cogg` + call from Swift compiles+links+runs. | High (decides Option 1 vs Option 2) | If fails, fallback to xcframework (Option 2) and re-plan. |
| **0b. Local playback contract spike** | Verify `AVAudioPCMBuffer` chained `scheduleBuffer` reproduces `playerTime`/completion semantics for a known WAV (no Vorbis yet). Confirms Path A-revised is sound. | Medium (decides whether AVAudioPlayerNode-chain works for chunked decode) | If `playerTime` drifts or completion doesn't fire reliably, escalate to plan-time architecture review. |
| **1. Full vendoring** | Vendor full libogg + libvorbis sources; build clean across arm64+x86_64; license bundle in `THIRD_PARTY_LICENSES.txt`. | Low (after Phase 0a passes) | Static archives build clean. |
| **2. Local file path** | `VorbisFileSource` + `LocalAudioSource` enum in `AudioEngineController` + extension detection. EQ + visualizer + seek must work end-to-end. Reuses `AVAudioPlayerNode`. | Medium | Manual: open `.ogg` file, play, seek, pause, resume, EQ change. |
| **3. Stream path** | `StreamBackend` sum type + Vorbis stream decoder (libogg sync + libvorbis synthesis) + DecodeContext branch + sniffer-driven backend selection + buffered byte replay. ICY framing bypassed. | Medium-High (chained streams + sniff replay) | Manual: connect to live Icecast OGG, verify metadata changes mid-stream. |
| **4. Metadata surfacing** | Vorbis comments → `StreamMetadata` (renamed from `ICYMetadata`) → existing `Track.title/.artist` and `streamTitle/streamArtist` flow. | Low | Manual: file metadata visible in playlist; stream title updates on chained-stream metadata change. |
| **5. Detection robustness** | First-BOS-page codec sniffer for ambiguous `.ogg` / `audio/ogg`. Clear error path for Opus/FLAC/Speex inside Ogg. Buffered replay verified. | Low | Unit test: feed first 8 KB of each codec's signature → correct discrimination; no false positives. |
| **6. Verification** | Unit tests against canonical Xiph test vectors. Manual integration on real files + 3-5 live Icecast OGG stations (incl. one chained — e.g., SomaFM Groove Salad OGG). Thread Sanitizer pass. | Low | All existing tests still green; new Vorbis tests pass; TSan clean. |

**v2 (future, separate task):** OGG Opus, OGG FLAC. Adds new `StreamDecoder` implementations that hang off the same protocol. Sniffer already discriminates them.

**Explicitly out of v1:**
- Vorbis encoding.
- Multi-channel (>2 channels) Vorbis. Downmix to stereo at decode time.
- Variable-bitrate display (covered by deferred "Real-time VBR bitrate display" item in `_context/state.md`).
- HLS-Vorbis (effectively non-existent in production).

---

## Files Affected (Inventory)

**New files:**
- `Vendor/libogg/` — vendored sources (~10 .c files, ~40 KB of .h) + `LICENSE.txt`.
- `Vendor/libvorbis/` — vendored sources (~25 .c files, ~80 KB of .h) + `LICENSE.txt`.
- `MacAmpApp/Audio/Streaming/VorbisDecoder.swift` — Swift wrapper for stream decode (libogg sync + libvorbis synthesis).
- `MacAmpApp/Audio/VorbisFileSource.swift` — Swift wrapper for local-file decode (libvorbisfile callbacks).
- `MacAmpApp/Audio/Streaming/StreamDecoder.swift` — protocol unifying AudioConverter path + Vorbis path.
- `MacAmpApp/Audio/Streaming/OggCodecSniffer.swift` — first-packet codec discrimination.
- `Resources/THIRD_PARTY_LICENSES.txt` (or extend existing) — Xiph BSD notice.
- `Tests/MacAmpTests/VorbisDecoderTests.swift` — known-PCM-from-known-input tests.

**Modified files:**
- `Package.swift` — add `Cogg`, `Cvorbis` cTargets; add `MacAmp` dependencies.
- `project.yml` — verify SwiftPM C target inheritance (likely no edit; possible `packages:` entry).
- `MacAmpApp/Audio/AudioPlayer.swift` — `detectMediaType`/`loadAudioFile` branch on `.ogg`/`.oga`.
- `MacAmpApp/Audio/AudioEngineController.swift` — accept a `PCMSource` abstraction or new `loadVorbisFile()` method; preserve existing AVAudioFile path.
- `MacAmpApp/Audio/MetadataLoader.swift` — `loadTrackMetadata` and `loadAudioProperties` branch on `.ogg`/`.oga`, using libvorbisfile metadata APIs (`ov_comment`, `ov_info`).
- `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` — replace `formatHint` enum, route to new Vorbis decode path. **Possibly:** rename `DecodeContext` internal fields to be decoder-agnostic.
- `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift` — make conform to new `StreamDecoder` protocol. No behavior change.
- `MacAmpApp/Views/PlaylistWindowActions.swift` — already uses `.audio` UTType which *should* include `.ogg`; verify (UTType `.audio` is broad). Add `.ogg`/`.oga` explicitly if not auto-detected.

**Estimated code change:** ~600-1000 lines new Swift, ~3 MB vendored C, ~1 modified line in `Package.swift`/`project.yml` per dependency wiring. Existing pipeline changes are surgical — protocol introduction + branch, no behavior change for MP3/AAC.

---

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| **Chained Ogg streams in Icecast** (new logical stream every metadata change) | High — silent decode failure mid-stream | libvorbis ogg_sync handles this natively (`ogg_stream_destroy` + new `ogg_stream_state` per chain). stb_vorbis does not — primary reason to prefer libvorbis. Test with `SomaFM Groove Salad OGG` which chains on every track. |
| **SwiftPM C target visibility** | Medium — XcodeGen may not pick up local Package C targets | Spike: vendor a tiny C file, verify `import Cogg` works from MacAmp. Fallback = xcframework. |
| **Binary size growth** | Low (~300 KB) | Acceptable. App is already ~30 MB. |
| **A/V sync (n/a here, audio-only)** | n/a | n/a |
| **macOS arch coverage** | Low — libvorbis is portable C89 | Build on arm64+x86_64; configure `config_types.h` for both. |
| **Performance on render thread** | Low | Vorbis decode is ~5-10× faster than realtime on M1; running off a producer thread into the ring buffer (same as AudioConverter path). |
| **Format detection ambiguity** (`.ogg` could be Opus) | Low-Medium — user confusion if Opus file fails | Magic-byte sniffer + explicit error message. |
| **Metadata surfacing differences** | Low — Vorbis comments already structured (UTF-8 KEY=VALUE) | Map `TITLE`/`ARTIST` directly to existing fields. |
| **Concurrency / strict concurrency** | Low — libvorbis state is thread-confined to decode queue (same pattern as `AudioFileStreamParser`/`AudioConverterDecoder`) | Mark Swift wrapper class `@unchecked Sendable` with `dispatchPrecondition` confinement asserts (same QueueConfined pattern). |
| **Xiph license notice missing in shipped app** | Low — minor compliance gap | Bundle `THIRD_PARTY_LICENSES.txt`; add to "About" via `NSHumanReadableCopyright` or Credits.rtf. |
| **Vorbis comments containing track-position metadata in chained streams** | Low | Honor Winamp behaviour: don't reset elapsed time on metadata change (already implemented for ICY in `StreamPlayer`; same rule applies). |
| **Local transport regression** *(Oracle)* | High — silent breakage of progress/completion/seek if the local-file abstraction goes wrong | Path A-revised (chained `scheduleBuffer` on existing `playerNode`) deliberately preserves transport. Phase 0b spike pre-validates with a non-Vorbis source. Add unit tests for chained-buffer completion and seek-while-playing. |
| **Render-thread safety** *(Oracle)* | High — any libvorbis call inside the render block would risk audio glitches | All decode work runs on the producer side (decode queue or scheduleBuffer producer task). Render thread only consumes pre-decoded `AVAudioPCMBuffer` (file path) or `LockFreeRingBuffer` (stream path). Document this invariant in code comments and add `dispatchPrecondition` asserts. |
| **Chained-stream format change mid-playback** *(Oracle)* | High — current `onFormatReady` is one-shot ([StreamDecodePipeline.swift:153](../../MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift#L153)); a chained Vorbis stream that changes sample rate or channel count would silently corrupt the bridge | Allow `onFormatReady` to fire on chain boundaries when sample-rate/channel-count differ from current. Coordinator must tear down + re-activate the engine bridge with the new ASBD. **This is a real existing gap in the streaming pipeline that OGG support exposes.** Plan must address. |
| **stb_vorbis chained-stream gap not yet evidenced** *(Oracle)* | Medium — "many stations chain on metadata change" was asserted, not measured | Plan-time spot check: test 5 live OGG stations (SomaFM Groove Salad, KEXP, RadioParadise OGG endpoint if any, BBC backup, indie). Record per-station: chain frequency, sample-rate stability, channel-count stability. Add evidence table to research before plan finalization. |
| **Binary size — measured, not asserted** *(Oracle)* | Low — directionally certain but not measured | Measure release-build delta arm64+x86_64 after Phase 1; add to research. |

---

## Open Questions

1. **Is OGG Vorbis still worth supporting in 2026?** Public Icecast directories (Shoutcast, Icecast) still list Vorbis stations but counts have dropped sharply since Opus matured (~2018+). SomaFM emits OGG-Vorbis on its premium endpoints (e.g., `https://ice2.somafm.com/groovesalad-256-aac` is AAC, but `groovesalad-128-ogg` is Vorbis). Many BBC/NPR national stations dropped OGG in 2020-22. **Verdict:** still emitted by enthusiast/indie stations; long-tail value is real but not large. Justifies LOW S3 priority (already classified that way). Validate in the plan stage with a small spot-check of public radio directories.
2. **Local file decoder choice — re-use the `AVAudioSourceNode` + ring buffer pattern, or build a custom `AVAudioPlayerNode`-style wrapper?** The first is simpler (already proven by streams); the second matches the existing `AVAudioFile` API surface that `AudioEngineController` is built around. Recommend the source-node path for consistency with streams.
3. **Should `StreamDecoder` be a protocol or a sum type (`enum`)?** Protocol is more idiomatic Swift; sum type is easier to reason about in `DecodeContext`. Both work — pick at plan time.
4. **What's the test corpus?** Need ~5 known-PCM-from-known-Vorbis fixtures for unit tests (e.g., test_vector_q0.ogg through q10.ogg). Xiph publishes test vectors. Confirm checked into the repo or downloaded by a test setup script.
5. **XcodeGen ↔ SwiftPM C target verification.** Spike before committing to Option 1 (vendored cTarget).

---

## Gemini Research Findings

**Status:** Gemini CLI was invoked but returned empty output (cwd-related auth issue under the sub-agent sandbox). Gemini was asked to cover: pure-Swift Vorbis decoder maturity, SwiftPM gotchas for libvorbis, stb_vorbis quality vs reference, Ogg streaming-API behaviour, BSD-license distribution requirements, modern Icecast OGG prevalence, codec discrimination, Vorbis comments format.

**Substituted with direct knowledge** of the well-established Vorbis ecosystem (libvorbis 1.3.7, libogg 1.3.5, stb_vorbis are stable since 2008-2020; RFCs 3533/5334 are unchanged; Vorbis spec is frozen). Where this research makes claims that warrant verification before implementation, those are flagged in **Open Questions** — particularly stream prevalence in 2026 and stb_vorbis chained-stream behaviour. **Plan-stage agent should re-run Gemini once cwd auth is resolved**, focused on those two narrow points, and append findings here. The library/license/integration recommendations are stable enough not to require external validation.

---

## Oracle Validation Summary

**Run:** 2026-04-27, `gpt-5.3-codex` xhigh, read-only sandbox. Cross-referenced against pipeline implementation files.

**Score:** 6.8 / 10 (initial draft) → revisions applied inline.
**Verdict:** **GO-WITH-CHANGES** — proceed to plan with two mandatory pre-plan closures (Phase 0a build-wiring spike + Phase 0b local-playback-contract spike).

**Findings & resolutions** (severity-ordered):

| # | Sev | Finding | Resolution |
|---|---|---|---|
| 1 | **CRITICAL** | Local-file Path A (AVAudioSourceNode pull-loop) silently broke `audioFile`/`scheduleSegment`/`playerTime`/completion contracts. | **Revised Path A** to chain `scheduleBuffer` on existing `AVAudioPlayerNode`. Introduces a small `LocalAudioSource` enum, no transport rewrite. |
| 2 | **HIGH** | Option 1 (SwiftPM cTarget) "no project.yml change needed" was wrong; XcodeGen does not auto-inherit root `Package.swift`. | Re-rated risk **medium-high**, added explicit Phase 0a wiring spike with hard pass/fail before vendoring full sources. |
| 3 | **HIGH** | Sniffer-driven detection conflicts with `DecodeContext` lifecycle that creates parser eagerly. | Added explicit pipeline state machine: `Connecting → Sniffing → DecoderSelected → Buffering → Playing`. Buffered bytes replayed through chosen backend. |
| 4 | **HIGH** | "First ~64 bytes" sniff window too small. | Buffer up to first complete BOS Ogg page, 4-8 KB cap, 250 ms timeout. |
| 5 | **MEDIUM** | `StreamDecoder` protocol risked Principle-6 pass-through middleman. | Replaced with **`StreamBackend` enum (sum type)**; `DecodeContext` retains all queue-confined state. |
| 6 | **MEDIUM** | State-ownership fragmentation if backends become strategy objects. | Same — sum-type keeps ownership in `DecodeContext`. |
| 7 | **MEDIUM** | libvorbis-vs-stb_vorbis decisive claim under-evidenced (chained streams). | Added spot-check task to plan: test 5 live OGG stations and record chain behaviour before locking in libvorbis. |
| 8 | **MEDIUM** | `ICYMetadata` reuse is semantically leaky. | Rename to `StreamMetadata` (or `NowPlayingMetadata`); ICY and Vorbis are adapters. |
| 9 | **MEDIUM** | Phasing under-priced Phase 1 risk; missing pre-plan spikes. | Added Phase 0a + 0b with hard pass/fail gates. |
| 10 | **LOW** | Binary-size claim asserted not measured. | Measure post-Phase-1 release delta; append to research. |

**Missing risks added to Risk Assessment table:**
- Local transport regression (HIGH).
- Render-thread safety with libvorbis (HIGH).
- Chained-stream sample-rate/channel-count change mid-playback exposing existing one-shot `onFormatReady` gap (HIGH).

**Verdict for plan.md:** Proceed only after Phase 0a + 0b spikes complete with success. If 0a fails, fall back to xcframework (Option 2) and re-evaluate. If 0b fails, escalate — Path A-revised assumptions wrong.

---

## References

- Xiph.org Vorbis I specification (frozen, 2002): https://xiph.org/vorbis/doc/Vorbis_I_spec.html
- RFC 3533 (Ogg encapsulation), RFC 5334 (Ogg media types).
- libvorbis source: https://gitlab.xiph.org/xiph/vorbis
- libogg source: https://gitlab.xiph.org/xiph/ogg
- stb_vorbis: https://github.com/nothings/stb/blob/master/stb_vorbis.c
- Sean Barrett's notes on stb_vorbis correctness — header docblock in `stb_vorbis.c`.
- Prior MacAmp work: `tasks/done/unified-audio-pipeline/research.md` §"Component Design" — mirrored here for the OGG path.
- MacAmp pipeline files cited inline (full paths in "Files Affected").
