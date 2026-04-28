# Plan: OGG Vorbis Support

> **Status:** PLANNED — awaits successful completion of Phase 0a + Phase 0b spikes before implementation begins.
> **Sprint:** S3-4 (last task in S3, sequential after `hls-streaming-support`).
> **Branch (implementation):** `feat/ogg-vorbis-support`.
> **Spike branches (throwaway):** `spike/ogg-build-wiring` (Phase 0a) + `spike/ogg-local-playback` (Phase 0b).
> **PR target:** PR #E.
> **Source of truth:** `tasks/ogg-vorbis-support/research.md` (Oracle GO-WITH-CHANGES 6.8/10 with revisions applied).

---

## 1. Problem Statement

OGG Vorbis is a widely-used patent-free lossy codec. Apple's AudioToolbox stack does not decode it, so MacAmp currently:

- Rejects local `.ogg` / `.oga` files (`AVAudioFile(forReading:)` throws on Vorbis).
- Cannot tune Icecast OGG streams — `AudioFileStreamParser` does not recognise Ogg pages, leaving the pipeline stuck in `Sniffing` / `buffering` indefinitely.
- Reports unhelpful errors to the user ("Unsupported audio format") for content that classic Winamp plays out of the box.

This is the last unaddressed lossy-codec gap relative to Winamp 5 parity. The task is medium-cost (one external decoder, one new pipeline branch) but high-leverage for indie/free-music ecosystems (SomaFM Groove Salad OGG, RadioParadise lossless OGG endpoint, BBC OGG fallbacks, classic.com OGG, indie Icecast).

**Concrete failure modes resolved:**

1. `.ogg` file double-clicked from Finder is rejected with no playback.
2. Icecast OGG station added via "Add URL" hangs in `Connecting...` → `Stream error: Unsupported audio format`.
3. `MetadataLoader.loadTrackMetadata` returns `Unknown` for OGG files even though Vorbis Comments are trivially parseable.

**Concrete failure modes EXPOSED (and fixed in passing):**

4. Existing `onFormatReady` is one-shot (`StreamDecodePipeline.swift:152-158`). A chained Icecast Vorbis stream that changes sample rate or channel count at a chain boundary would silently corrupt the engine bridge. This gap exists today for any future codec change; OGG is the first real-world trigger.

---

## 2. Non-Goals

- **Opus codec** (in Ogg or otherwise) — separate future task. Sniffer must REJECT Opus with a clear error.
- **OGG Theora video** — out of scope; sniffer must REJECT.
- **OGG FLAC** — separate task; sniffer must REJECT.
- **OGG Speex** — sniffer must REJECT.
- **Vorbis encoding** — MacAmp never encodes.
- **Multichannel (>2) Vorbis** — downmix to stereo at decode time.
- **Variable-bitrate display** — already deferred under shared `_context/state.md`.
- **HLS-Vorbis** — vanishingly rare in production; out of scope.
- **Pure-Swift Vorbis port** — explicitly rejected in research §"Library Options"; no mature implementation exists.

---

## 3. Pre-Decomposition Gate Checklist (per `_context/principles.md`)

| # | Item | Outcome |
|---|------|---------|
| 1 | Problem statement written | YES — §1, four concrete failure modes. |
| 2 | Non-goals listed | YES — §2. |
| 3 | Principles contract approved | YES — §16 (state map) and §22 (ADR) below: P1 (problem-first), P3 (state ownership: keep DecodeContext as single source of truth), P4 (rule of three: only `ICYMetadata`→`StreamMetadata` rename hits the safety-invariant exception at 2 callers; no other extractions until 3rd codec lands), P5 (no visibility widening: `StreamBackend` lives inside `StreamDecodePipeline.swift` as fileprivate where possible), P6 (no pass-through middlemen: backend is enum, not protocol with adapter classes), P7 (ADR + kill switch: §19 + §22). |
| 4 | Responsibility map exists | YES — §11. |
| 5 | Complexity assessed | YES — adds ~700-1000 lines new Swift + ~3 MB vendored C. New cognitive load is concentrated in `VorbisDecoder` (libvorbis state machine) and `StreamDecodePipeline` state machine. The rest is mechanical wiring. |
| 6 | Candidate split scored | YES — `LocalAudioSource` enum (60 lines) vs full `LocalPlaybackBackend` protocol (months): scored cohesion-positive, state-risk-low, visibility-impact-zero, pass-through-risk-zero. Sum-type wins. |
| 7 | Public/internal API delta | Low: new public `VorbisDecoder` (internal to module), `OggCodecSniffer` (internal), `VorbisFileSource` (internal), `StreamMetadata` rename (internal). No public-API expansion. |
| 8 | Stop criteria defined | YES — §19. |

**Gate verdict:** PASS — proceed to Phase 0a spike.

---

## 4. Phase 0a — Build-Wiring Spike (MANDATORY, throwaway branch `spike/ogg-build-wiring`)

> **Why mandatory:** Oracle (HIGH, research §"Build / SwiftPM Integration Approach") flagged "Option 1 needs no `project.yml` change" as not credible. XcodeGen does not auto-inherit root `Package.swift` target graph for cTargets; per-target `dependencies` and a `packages:` block entry are likely required. Failure here cascades — vendoring ~3 MB of libvorbis source before knowing it links is wasted effort.

**Goal:** Prove that a SwiftPM cTarget defined in a local sibling package + wired through `project.yml` can be `import`ed and called from the `MacAmp` target, building cleanly with TSan on both arm64 and x86_64.

**Approach:**

1. Create `Vendor/COggVorbis/Package.swift` declaring two cTargets (`Cogg`, `Cvorbis`) where `Cvorbis` declares `dependencies: [.target(name: "Cogg")]` (this is the real wiring, not a smoke-only test).
2. `Cogg/Sources/og_smoke.c` contains `#include "ogg/og_types_smoke.h"` and `int og_smoke(void){ ogg_int32_t v = 42; return (int)v; }`. The header `Cogg/include/ogg/og_types_smoke.h` typedefs `ogg_int32_t` to a 32-bit int. This guarantees the header search path actually resolves `ogg/...` (the real layout libogg uses).
3. `Cvorbis/Sources/vb_smoke.c` contains BOTH `#include "vorbis/vb_smoke.h"` AND `#include "ogg/og_types_smoke.h"` (transitive header include) and exports `int vb_smoke(void){ return og_smoke(); }`. This forces the `Cvorbis → Cogg` linkage to resolve at link time, the modulemap to expose Cogg's headers transitively, and proves the umbrella headers are correct.
4. Module map per target (`include/module.modulemap`) declaring umbrella headers for `Cogg` and `Cvorbis`.
5. Add `packages:` entry to `project.yml`:
   ```yaml
   packages:
     COggVorbis:
       path: ./Vendor/COggVorbis
   ```
6. Add `dependencies:` entries on the `MacAmp` target:
   ```yaml
   - package: COggVorbis
     product: Cogg
   - package: COggVorbis
     product: Cvorbis
   ```
7. `xcodegen generate`.
8. Add a temporary `MacAmpApp/Audio/_OggSmoke.swift` containing:
   ```swift
   import Cogg
   import Cvorbis
   let _ = og_smoke()      // Cogg-only path
   let _ = vb_smoke()      // Cvorbis-calls-Cogg path (real linkage)
   ```
9. Build (universal, mandatory both arches):
   - `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES","ARCHS=arm64 x86_64","ONLY_ACTIVE_ARCH=NO"]}'`
   - Confirm zero warnings related to module map / unresolved symbol.
10. Run TSan-enabled test suite — must remain green.
11. Verify dual-arch by running `lipo -archs` on the built binary — the result MUST be exactly `arm64 x86_64`. Single-arch result is a HARD FAIL of Phase 0a.

**Pass criterion:** All 11 steps succeed; both `og_smoke()` AND `vb_smoke()` link and execute; TSan clean; `lipo -archs` shows `arm64 x86_64`.

**Fail criteria + branch decisions:**

| Failure mode | Decision |
|--------------|----------|
| Module map ambiguity (libogg `os_types.h` vs system header) | Acceptable — namespace via `Cogg/include/ogg/` folder. Not a kill condition. |
| `xcodegen` does not produce a `MacAmp` target that links the cTargets | Try wiring as separate `targets:` (sibling Swift target dep). If still failing → fall back to **Option 2 (xcframework)**. |
| Cross-arch build fails (e.g., x86_64 missing) | Investigate `ARCHS` setting; if structural → fall back to xcframework. |
| Builds but `og_smoke()` returns garbage / linker silently picks wrong symbol | Hard fail → re-plan with xcframework. |

**Deliverable:** Append "Phase 0a Spike Result" section to `research.md` with: build command output, `lipo -info` output, decision (Option 1 confirmed / Option 2 fallback), commit SHA on spike branch.

**Branch lifecycle:** `spike/ogg-build-wiring` is **deleted after results recorded**. No code from the spike is reused beyond the `project.yml` packages block and the `Vendor/COggVorbis/Package.swift` skeleton (those carry forward to Phase 1 with smoke files removed).

---

## 5. Phase 0b — Local-Playback Contract Spike (MANDATORY, throwaway branch `spike/ogg-local-playback`)

> **Why mandatory:** Oracle (CRITICAL) revised Path A from "AVAudioSourceNode pull-loop" to "chained `playerNode.scheduleBuffer`" specifically because `AudioPlayer`/`AudioEngineController` assume `audioFile != nil`, `file.length`, `playerTime`, and `scheduleSegment` completion semantics. We must validate that chained `scheduleBuffer` *actually* preserves those contracts BEFORE we wire it to a brand-new Vorbis decoder where bugs will be hard to attribute (decoder vs scheduling).

**Goal:** Reproduce play / pause / seek-while-playing / progress-timer / completion semantics using chained `playerNode.scheduleBuffer(_:completionHandler:)` against a known-good NON-Vorbis source — i.e., bypass `AVAudioFile`'s segment-scheduling path by re-buffering an MP3 or WAV through a synthetic chunked PCM source.

**Approach:**

1. Add a temporary file `MacAmpApp/Audio/_ChunkedFileSpike.swift` (under `#if DEBUG`) that:
   - Loads a known WAV via `AVAudioFile`.
   - Reads it into N-frame chunks (e.g. 8192 frames each) as `AVAudioPCMBuffer`s.
   - Schedules them via chained `scheduleBuffer(_:completionHandler:)` on the existing `AudioEngineController.playerNode`.
   - Each completion handler schedules the next chunk; the final chunk's completion fires `onPlaybackEnded`.
2. Wire a debug menu item that invokes the spike against a fixture WAV.
3. Manual verification on macOS 15 Sequoia + macOS 26 Tahoe (both targets):
   - V0b.1 — Play: hear continuous audio, no clicks at chunk boundaries.
   - V0b.2 — Pause / resume: `playerNode.pause()` and `playerNode.play()` continue to work; no scheduled-buffer queue corruption.
   - V0b.3 — `playerTime` driven progress timer continues to update during chained playback (no jumps at chunk boundaries).
   - V0b.4 — Seek mid-playback: clear scheduled buffers via `playerNode.stop()`, then re-prime from new offset; existing `seek(to:)` semantics hold.
   - V0b.5 — Completion: final-buffer completion fires `onPlaybackEnded` exactly once with correct seekID.
   - V0b.6 — TSan clean across all of the above.

**Pass criterion:** All six checks pass on both macOS 15 and macOS 26.

**Fail criteria:**

| Failure mode | Decision |
|--------------|----------|
| Audible clicks at chunk boundaries | Acceptable for spike; consider 16384-frame chunks in real impl. Not a kill condition. |
| `playerTime` drifts more than 100 ms over 60 s | Investigate sample-clock anchor; if structural → escalate before Phase 5. |
| Completion fires multiple times or not at all | **HARD FAIL.** Path A-revised assumptions wrong. Escalate; consider `LocalPlaybackBackend` protocol redesign — likely **abort task** because that is months of work for low-value codec. |
| Seek mid-playback corrupts buffer queue | Investigate `playerNode.stop()` semantics; if unfixable → abort. |
| TSan flags scheduling thread issues | Investigate — `scheduleBuffer` completion handler runs on an audio scheduling queue, callbacks must hop to MainActor explicitly. |

**Deliverable:** Append "Phase 0b Spike Result" section to `research.md` with verification table, audio recording snippet (silence detection at boundaries), decision.

**Branch lifecycle:** `spike/ogg-local-playback` deleted after results recorded. No code reused (the real impl uses `VorbisFileSource`, not the WAV-rebuffering hack).

---

## 6. Phase 1 — Vendor libogg + libvorbis

**Pre-condition:** Phase 0a passed; Option 1 (vendored cTarget) confirmed.

**Sources to vendor (frozen versions):**

- `libogg-1.3.5` — `src/bitwise.c`, `src/framing.c`, headers under `include/ogg/`.
- `libvorbis-1.3.7` — `lib/*.c` (analysis, bitrate, block, codebook, envelope, floor0, floor1, info, lookup, lpc, lsp, mapping0, mdct, psy, registry, res0, sharedbook, smallft, synthesis, vorbisenc (exclude), vorbisfile, window), headers under `include/vorbis/`.
- `config_types.h` — pre-generated for arm64 + x86_64 macOS (typedefs `ogg_int16_t = int16_t` etc.).
- License files: `Vendor/libogg/LICENSE.txt`, `Vendor/libvorbis/LICENSE.txt` (verbatim Xiph BSD).

**Build wiring:**

- `Vendor/COggVorbis/Package.swift`:
  - `Cogg` cTarget — sources, `publicHeadersPath: "include"`, `cSettings: [.headerSearchPath("include")]`.
  - `Cvorbis` cTarget — sources, `publicHeadersPath: "include"`, `cSettings: [.headerSearchPath("include"), .headerSearchPath("lib")]`, `dependencies: [.target(name: "Cogg")]`, `linkerSettings: [.linkedLibrary("m")]`.
  - Exclude `vorbisenc.c` (encoding only).
- `project.yml`:
  - `packages: COggVorbis: { path: ./Vendor/COggVorbis }`.
  - `MacAmp.dependencies` adds `package: COggVorbis, product: Cogg` and `Cvorbis`.

**License compliance (BSD-3-Clause + MIT):**

- New file `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` containing verbatim Xiph BSD notices for libogg and libvorbis.
- Add to `project.yml` `targets.MacAmp.resources`.
- Update `MacAmp.entitlements` / About-box wiring is **out of scope** for v1; the file is shipped in the bundle, satisfying redistribution clause. (Follow-up nit may be filed for About-box link.)

**Deliverable:** PR-time check that `THIRD_PARTY_LICENSES.txt` is in `MacAmp.app/Contents/Resources/`.

**Build verification (gate to Phase 2):**

```bash
xcodegen generate
xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'
```

Plus binary-size measurement (Phase 10).

---

## 7. Phase 2 — VorbisDecoder + Ogg Demuxer Wrapper

**New file:** `MacAmpApp/Audio/Vorbis/VorbisDecoder.swift`.

**Type:** `final class VorbisDecoder: QueueConfined { ... }` — `@unchecked Sendable`, queue-confined to its owner's queue (matches `AudioConverterDecoder` and `AudioFileStreamParser` patterns).

**Two explicit modes (mutually exclusive, set at init, enforced by enum + asserts):**

```swift
fileprivate enum Mode {
    case stream          // libogg ogg_sync + libvorbis synthesis (incremental input)
    case seekableFile    // libvorbisfile OggVorbis_File (whole-file random-access)
}
```

The two modes share NOTHING beyond the type name. Each mode owns disjoint state:

| Mode | State held |
|------|-----------|
| `.stream` | `ogg_sync_state`, `ogg_stream_state`, `vorbis_info`, `vorbis_comment`, `vorbis_dsp_state`, `vorbis_block` |
| `.seekableFile` | `OggVorbis_File` only (libvorbisfile manages the rest internally) |

**Init invariant:** the decoder is constructed via one of two factory methods — `VorbisDecoder.makeStream()` or `VorbisDecoder.makeSeekable(url:)`. The runtime `mode` is `let`-immutable after init. Every public method asserts `precondition(self.mode == .stream)` or `.seekableFile` per applicability. Calling a stream-mode method on a seekable instance traps in DEBUG and is undefined behaviour in RELEASE (acceptable — internal API, single-call-site per mode).

**Responsibilities — mode `.stream`:**

- Public methods (queue-confined):
  - `func feed(_ data: Data)` — copy bytes into `ogg_sync_buffer` + `ogg_sync_wrote`.
  - `func pump() -> [VorbisDecodeEvent]` — drain pages → packets → PCM. Returns events:
    - `.formatReady(sampleRate: Int, channels: Int)` (one per BOS or chain boundary).
    - `.metadata(StreamMetadata)` (after comment header).
    - `.pcm(UnsafePointer<Float>, frameCount: Int)` — interleaved Float32 stereo (downmix in-decoder if `vorbis_info.channels > 2`).
    - `.chainBoundary(newSampleRate: Int, newChannels: Int)` — fires when `ogg_page_bos` arrives mid-stream.
    - `.endOfStream`.
    - `.error(String)`.
  - `func resetForChain()` — destroy stream/dsp/block, keep `ogg_sync` alive (chain-only).
  - `func dispose()` — full teardown of stream-mode state.

**Responsibilities — mode `.seekableFile` (used by `VorbisFileSource` only):**

- Public methods (queue-confined):
  - `func ovPCMSeek(_ frame: Int64)` — seek by sample frame.
  - `func ovPCMTotal() -> Int64` — total frame count.
  - `func ovComment() -> StreamMetadata?`.
  - `func ovInfo() -> (sampleRate: Int, channels: Int)`.
  - `func ovRead(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> Int` — pull N frames into a caller-owned buffer (interleaved Float32 stereo, downmix if needed). Returns frames actually read; 0 = EOF.
  - `func dispose()` — closes `OggVorbis_File`.

The two surfaces are physically separated by `// MARK:` sections; tests cover them independently. If the file grows past ~600 LOC, split into `VorbisStreamDecoder` and `VorbisSeekableDecoder` as a follow-up — but **the unified type is acceptable for v1** because the cognitive load is "two modes, mutually exclusive" rather than "shared state with conditional flags" (Principle 4 rejection criterion does NOT apply since there is no boolean-flag-driven divergent abstraction; mode is a pure sum type).

**Render-thread safety:**

- ALL libvorbis/libogg calls happen on the producer side (decode queue or `VorbisFileSource`'s producer task). The render block (`AVAudioSourceNode` render block or `playerNode` scheduling thread) only ever reads pre-decoded buffers.
- Document this invariant inline (`// CONTRACT: never call libvorbis from render thread`).
- `dispatchPrecondition(condition: .onQueue(decodeQueue))` at top of every public method.

**Multichannel handling:**

- For `vorbis_info.channels == 1` → mono → duplicate to L/R.
- For `vorbis_info.channels == 2` → already stereo, copy.
- For `vorbis_info.channels > 2` → use Vorbis channel mapping (`5.1`, `7.1`) per Vorbis I spec §A.2; downmix to stereo using ITU-R BS.775 coefficients (front L+R = direct; center = ×0.707 to both; surrounds = ×0.5 to respective sides; LFE dropped). This is the simplest correct downmix. Document the choice inline.

**Memory management:**

- `OggVorbis_File`, `vorbis_dsp_state`, `vorbis_block` etc. live on the heap (libvorbis allocates internally). The Swift wrapper holds only opaque `UnsafeMutablePointer`s + a manual `dispose()`.
- `deinit { dispose() }` for safety net.

**Tests:** §13.

---

## 8. Phase 3 — OggCodecSniffer

**New file:** `MacAmpApp/Audio/Vorbis/OggCodecSniffer.swift`.

**Type:** `struct OggCodecSniffer: Sendable` — pure value type, no I/O.

**API:**

```swift
enum OggInnerCodec: Sendable {
    case vorbis, opus, flac, speex, theora, unknown
}

enum OggSniffResult: Sendable {
    case need(moreBytes: Int)        // not enough data yet
    case identified(OggInnerCodec, bufferedBytes: Data)  // replay these through chosen backend
    case notOgg(bufferedBytes: Data) // first 4 bytes != "OggS"
    case overshoot                   // exceeded 8 KB or 250 ms — bail
}

mutating func consume(_ data: Data, deadline: ContinuousClock.Instant) -> OggSniffResult
```

**Algorithm:**

1. Append incoming bytes to internal buffer (cap 8192 bytes).
2. If buffer < 4 bytes: `.need(more: 4 - count)`.
3. If first 4 bytes ≠ `"OggS"` (`[0x4F, 0x67, 0x67, 0x53]`): `.notOgg(buffered)`.
4. Parse Ogg page header (27 bytes minimum) + segment table (variable, at byte 27).
5. If full first page not yet present: `.need(more: estimate)`.
6. Read first packet from the page body. Inspect:
   - First byte `0x01` + bytes 1–6 == `"vorbis"` → `.identified(.vorbis, buffered)`.
   - First 8 bytes == `"OpusHead"` → `.identified(.opus, buffered)`.
   - First 4 bytes == `"fLaC"` → `.identified(.flac, buffered)`.
   - First 8 bytes == `"Speex   "` (with 3 spaces) → `.identified(.speex, buffered)`.
   - First 7 bytes == `[0x80, 't','h','e','o','r','a']` → `.identified(.theora, buffered)`.
   - Otherwise → `.identified(.unknown, buffered)`.
7. If buffer reaches 8192 bytes OR `ContinuousClock.now > deadline` → `.overshoot`.

**Replay contract:** the caller MUST hand `bufferedBytes` to the chosen backend's `feed()` BEFORE feeding any new bytes. Documented inline.

**Tests:** §13 — fixture page snippets for each codec; malformed-page negatives; 7-KB no-decision edge.

---

## 9. Phase 4 — StreamBackend Enum + DecodeContext State Machine

**Modified file:** `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`.

### 9.1 New `StreamBackend` sum type (fileprivate inside `StreamDecodePipeline.swift`)

```swift
fileprivate enum StreamBackend {
    case audioFileStream(AudioFileStreamParser, AudioConverterDecoder?)  // existing path
    case oggVorbis(VorbisDecoder)                                         // new path
}
```

**Why enum, not protocol** (Principle 6, Oracle MEDIUM finding #5/6):

- The would-be protocol methods (`feed(_:)`, drain to PCM, surface format/metadata events) carry zero policy, only forwarding. That is a textbook pass-through.
- `DecodeContext` already owns ring buffer, generation token, prebuffer threshold, workgroup, framer, error reporting. Splitting backends into adapter classes fragments state ownership (Principle 3).
- Sum type keeps single source of truth + makes the codec branch explicit at every call site. Pattern-matching is the right primitive.

### 9.2 Pipeline state machine

Replace the implicit `parser-eager-init` lifecycle with explicit states (Oracle HIGH finding #3):

```swift
fileprivate enum PipelineLifecycle: Sendable {
    case connecting          // URLSession active, no bytes yet
    case sniffing            // bytes arriving, OggCodecSniffer accumulating
    case decoderSelected     // backend chosen; replaying buffered bytes
    case buffering           // backend producing PCM; below prebuffer threshold
    case playing             // prebuffer threshold reached; onFormatReady fired
}
```

### 9.3 Detection flow in `DecodeContext`

1. `init` no longer eagerly creates `AudioFileStreamParser`. It records `formatHint: StreamFormatHint` (see §9.5) and creates an empty `OggCodecSniffer`.
2. `handleIncomingData`:
   - `.connecting` → set `.sniffing`.
   - `.sniffing`:
     - If `formatHint == .audioFileStream` (clear MP3/AAC by Content-Type) → skip sniff; instantiate `.audioFileStream(parser, nil)` backend immediately.
     - If `formatHint == .ogg` or `.unknown` → feed sniffer; on `.identified(.vorbis, buffered)` instantiate `.oggVorbis(VorbisDecoder())` and feed `buffered` first; on `.identified(.opus|.flac|.speex|.theora|.unknown, _)` emit `decodeError("OGG <codec> not supported")` (non-reconnectable); on `.notOgg(buffered)` instantiate `.audioFileStream(parser, nil)` and replay buffered bytes; on `.overshoot` emit `decodeError("Stream sniff timeout")`.
   - `.decoderSelected` → forward to backend; emit format-ready / metadata / PCM events; transition to `.buffering`.
   - `.buffering` → write PCM to ring buffer; when `prebufferedFrames >= prebufferThreshold` → fire `onFormatReady` → `.playing`.
   - `.playing` → continue feeding.

### 9.4 Generation-token guards (existing pattern — preserve)

Every queue hop, every callback, every state transition checks `gen == self.generation`. New states do not relax this. `stopInternal()` advances `generation` first.

### 9.5 New `StreamFormatHint` enum

Replace the bare `AudioFileTypeID` return from `formatHint(for:)`:

```swift
fileprivate enum StreamFormatHint: Sendable {
    case audioFileStream(AudioFileTypeID)  // mp3 / aac confirmed
    case ogg                                // .ogg/.oga/audio/ogg/application/ogg
    case unknown                            // sniff at first bytes
}

private static func formatHint(for url: URL, contentType: String?) -> StreamFormatHint
```

**Branch rules:**

- Content-Type `audio/mpeg`, `audio/aac`, `audio/aacp`, `audio/x-aac` → `.audioFileStream(...)`.
- Content-Type `audio/ogg`, `application/ogg`, `audio/vorbis` → `.ogg`.
- URL ext `.mp3`/`.aac`/`.aacp` → `.audioFileStream(...)`.
- URL ext `.ogg`/`.oga` → `.ogg`.
- Otherwise `.unknown`.

`handleHTTPResponse` is the natural place to compute this (it has the response). Pass to `DecodeContext` via a new `setHint(_:)` queue-confined method.

### 9.6 Buffered byte replay correctness (Oracle HIGH finding #4)

`OggCodecSniffer.consume` returns `bufferedBytes: Data` containing **exactly** the bytes accumulated. After backend instantiation, `DecodeContext` calls `backend.feed(bufferedBytes)` BEFORE forwarding any newer bytes. Preserved ordering = guaranteed by serial decode queue (same invariant as ICY framer).

### 9.7 `onFormatReady` re-fire on chain boundary (Oracle HIGH risk → CRITICAL after Round 1 review)

**Existing behaviour (TWO independent gates today — must collapse to one):**

- `StreamDecodePipeline.formatReadyFired` (line 100) — gate that prevents re-firing the @MainActor `onFormatReady` callback.
- `DecodeContext.formatReadyFired` (declared on the queue-confined context) — gate that prevents re-invoking `onFormatReady(detectedSampleRate, generation)` from `handlePackets`.

A chained Vorbis stream that changes sample rate or channel count silently writes the new PCM into a ring buffer whose source-node format is now wrong → audio corruption. Both gates must be reset together; otherwise a partial reset leaves stale bridge format and silent corruption.

**Fix (single authoritative gate + bridge re-tune):**

1. **Eliminate the duplicate gate.** Remove `StreamDecodePipeline.formatReadyFired` (the @MainActor copy at line 100). The decode-queue-confined `DecodeContext.formatReadyFired` becomes the single source of truth. The MainActor pipeline relies on the closure-arrival ordering: `onFormatReady` is only emitted from `DecodeContext` and the closure body is itself idempotent against duplicate same-sample-rate fires (compare-and-skip). This satisfies Principle 3 (state ownership: one source).
2. **`VorbisDecoder` emits `.chainBoundary(newSampleRate, newChannels)`** on every BOS page after the first.
3. **`DecodeContext` compares `(detectedSampleRate, detectedChannels)` against the previous values**:
   - If sample rate AND channel count unchanged: log + continue (no flush, no callback).
   - If sample rate changed: (a) flush ring buffer; (b) reset `formatReadyFired = false`; (c) reset `prebufferedFrames = 0`; (d) update `detectedSampleRate`/`detectedChannels`; (e) emit a NEW `onChainFormatChange(newSampleRate, generation)` callback. Then re-prime via the existing prebuffer threshold path — once threshold reached, `formatReadyFired` flips back to true and the existing `onFormatReady` callback path fires again. (No second one-shot `onFormatReady` gate to manage.)
   - If channel count changed but sample rate unchanged: still emit `onChainFormatChange` so the coordinator can verify; downmix in `VorbisDecoder` keeps ring buffer interleaved Float32 stereo, so ring buffer format itself is unaffected — but emit the event for observability.
4. **Callback naming convention** (deliberate, not a typo): the pipeline-side callback mirrors existing `onFormatReady` style → `onChainFormatChange`. The StreamPlayer/PlaybackCoordinator-side callback mirrors existing `onMetadataChanged` / `onStreamStateChanged` style → `onStreamChainFormatChanged`. Same pattern as the `onFormatReady` (pipeline) → `onFormatReady` (StreamPlayer) seam, but with the more descriptive past-tense form on the StreamPlayer surface to match its existing past-tense convention.
5. **New callback on `StreamDecodePipeline`:**
   ```swift
   var onChainFormatChange: (@MainActor @Sendable (Float64) -> Void)?
   ```
   Wired in lock-step with `onFormatReady`. Generation-token guarded.
7. **`PlaybackCoordinator.onStreamChainFormatChanged` handler** (new) executes the bridge retune sequence:
   - `audioPlayer.deactivateStreamBridge()`.
   - `audioPlayer.activateStreamBridge(ringBuffer: streamPlayer.currentRingBuffer, sampleRate: newRate)`.
   - `streamPlayer.setAudioWorkgroup(audioPlayer.audioWorkgroup)` — workgroup MUST be re-passed because each `activateStreamBridge` may produce a fresh `os_workgroup_t` from the freshly-started engine output node.
8. **Verification:** new test T13b asserts the full plumbing — feed a fixture that changes 44.1 kHz → 48 kHz mid-stream into the pipeline (via DecodeContext-level harness), verify `StreamPlayer.onStreamChainFormatChanged` fires exactly once, verify `audioPlayer.deactivateStreamBridge` then `audioPlayer.activateStreamBridge(_, sampleRate: 48000)` are invoked in order, verify `streamPlayer.setAudioWorkgroup` is called with a non-nil workgroup post-activation.

**Why one gate, not two (Principle 3):** Today's two `formatReadyFired` flags drift independently if either side resets without the other. Collapsing to a single decode-queue-confined gate makes the invariant "format-ready state lives on the decode queue; MainActor side is purely reactive." This is the same pattern as `generation` (queue-confined token, MainActor reads via closure args).

This fix is in scope because OGG is the first codec that exposes the gap. The dual-gate collapse can land in C4 alongside the chain-boundary work or be split into a tiny preparatory commit if review wants to atomically test the simplification.

---

## 10. Phase 5 — Local-File Path (Path A-revised)

**Pre-condition:** Phase 0b passed.

### 10.1 New `VorbisFileSource` (`MacAmpApp/Audio/Vorbis/VorbisFileSource.swift`)

Mirrors the AVAudioFile contract surface that `AudioEngineController` reads:

- `init(url: URL) throws` — opens via `VorbisDecoder.makeSeekable(url:)`.
- `var totalFrames: AVAudioFramePosition` — `ovPCMTotal()`.
- `var sampleRate: Double` — `ovInfo().sampleRate`.
- `var processingFormat: AVAudioFormat` — Float32 stereo at `sampleRate`.
- `func bufferAt(frame: AVAudioFramePosition, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer?` — pulls + decodes; seeks via `ovPCMSeek` if needed; returns nil at EOF.
- `func close()` — disposes decoder.

**Producer model (decode work pinned OFF the completion thread):**

The completion handler that `AVAudioPlayerNode.scheduleBuffer` invokes runs on an internal audio scheduling thread (NOT the render thread, but adjacent to it — Apple does not document the exact QoS). Performing libvorbis decoding inside that handler risks: (a) priority inversion against the audio IO thread, (b) jitter / crackles on under-budget hardware, (c) flaky completion timing under load.

**Strict contract:**

1. A dedicated serial `DispatchQueue` (`com.macamp.vorbis.file.producer`, QoS `.userInitiated`) owns all `VorbisFileSource.bufferAt` calls.
2. The producer task pre-fills a small in-Swift queue (target depth: 3 buffers, ~558 ms at 8192 frames / 44.1 kHz) on the producer queue.
3. `playerNode.scheduleBuffer(buffer) { [weak self] in self?.notifyConsumed() }` — the completion handler ONLY:
   - Hops to the producer queue (`producerQueue.async { ... }`).
   - Decrements an in-flight counter.
   - Signals "produce one more buffer".
   The completion handler MUST NOT call libvorbis directly. Documented inline (`// CONTRACT: completion handler does not decode`).
4. The producer queue handler (a) calls `bufferAt`, (b) hops back to MainActor to call `playerNode.scheduleBuffer(...)` (scheduleBuffer is MainActor-safe; the call itself is fast and non-blocking).
5. Generation token (`vorbisProducerGen: UInt64`) on `AudioEngineController`. Each `loadFile`/`scheduleFrom`/`clearFile` advances the generation. The producer queue checks generation before every `bufferAt` and discards stale buffers.
6. Final-chunk completion: when `bufferAt` returns nil (EOF), the producer task signals "no more buffers" via a flag; the LAST `scheduleBuffer` completion handler checks that flag and fires `onPlaybackEnded(seekID)` exactly once.

**Chunk size:** 8192 frames (~186 ms at 44.1 kHz). Tunable; documented.

**Render-thread invariant:** The render thread (the actual audio IO thread) is fed by `AVAudioPlayerNode` from its internal pre-scheduled buffer queue. Scheduled `AVAudioPCMBuffer`s are immutable Float32 PCM — the render thread never touches libvorbis state. Documented in `VorbisFileSource.swift` header.

### 10.2 `LocalAudioSource` enum in `AudioEngineController`

```swift
fileprivate enum LocalAudioSource {
    case avAudioFile(AVAudioFile)
    case vorbis(VorbisFileSource)

    var totalFrames: AVAudioFramePosition { ... }
    var processingFormat: AVAudioFormat { ... }
}
private var currentSource: LocalAudioSource?
```

### 10.3 Methods to refactor (route through `currentSource`)

- `loadFile(url:)` — branch on extension:
  - `.ogg`/`.oga` → `currentSource = .vorbis(VorbisFileSource(url: url))`; call new `rewireForVorbis(_:)`.
  - else → existing `currentSource = .avAudioFile(AVAudioFile(forReading: url))`; existing `rewireForFile(_:)`.
- `audioFile` getter is now `currentSource?.asAVAudioFile` (returns nil for Vorbis). **Important:** existing call sites in `AudioPlayer` (`engine.audioFile != nil`) become `engine.hasLoadedSource`. Add a new `var hasLoadedSource: Bool { currentSource != nil }` — replaces 4 call sites in `AudioPlayer.swift` (lines 417, 552, 568; verify at HEAD).
- `currentFileDuration` — switch on `currentSource`.
- `scheduleFrom(time:seekID:)`:
  - `.avAudioFile` → existing `playerNode.scheduleSegment(...)` path.
  - `.vorbis(let source)` → `source.seek(toFrame: ...)` then chained `scheduleBuffer` producer task; final completion fires `onPlaybackEnded(seekID)`. Cancel previous producer task on each call (generation token pattern, mirroring stream pipeline's `generation`).
- `clearFile()` → `currentSource?.close(); currentSource = nil`.
- `rewireForVorbis(_ source: VorbisFileSource)` — new helper analogous to `rewireForFile`. Difference: `playerNode → eqNode` connection format uses `source.processingFormat` (which is Float32 stereo at the file's native sample rate; engine handles SRC).

### 10.4 Transport semantics preserved

- `play()` / `pause()` / `stop()` on `AudioPlayer` continue to call `engine.playAudio() / pauseAudio() / stopAudio()` which act on the same `AVAudioPlayerNode`. **No public-API change.**
- `playerNode.lastRenderTime` + `playerTime(forNodeTime:)` continue to drive `progressTimer` — same code, no change.
- Completion: chained-buffer final-completion handler calls `onPlaybackEnded(seekID)` exactly like `scheduleSegment`.
- Seek: producer task cancelled (generation), `playerNode.stop()`, new producer started from new frame.

### 10.5 EQ + visualizer + balance

Unchanged. The graph is still `playerNode → eqNode → mainMixer → output`. Tap-based visualizer still fires on the mixer.

---

## 11. Phase 6 — `ICYMetadata` → `StreamMetadata` Rename + Adapter Pattern

**Driver:** Oracle MEDIUM finding #8 — `ICYMetadata` reuse is semantically leaky for Vorbis Comments.

**Renames (mechanical):**

1. `ICYFramer.ICYMetadata` → top-level `StreamMetadata` in new file `MacAmpApp/Audio/Streaming/StreamMetadata.swift`:

   ```swift
   /// Codec-agnostic now-playing metadata. Adapters: ICYFramer, VorbisDecoder.
   struct StreamMetadata: Sendable {
       let title: String?
       let artist: String?
   }
   ```

2. `ICYFramer.consume(_:)` returns `[Chunk]` where `Chunk.metadata(StreamMetadata)`.
3. `VorbisDecoder.pump()` emits `.metadata(StreamMetadata)` derived from `ov_comment()` (TITLE, ARTIST keys; UTF-8 already).
4. All call sites updated in lock-step (no compatibility shim — internal type, internal callers):
   - `StreamDecodePipeline.swift:57` — `onMetadata: (@MainActor @Sendable (StreamMetadata) -> Void)?`
   - `StreamPlayer.swift:214` callback signature.
   - `DecodeContext` `onMetadata` closure.

**Vorbis Comments → StreamMetadata adapter:**

- Inside `VorbisDecoder`: a private `commentsToMetadata(_ comment: vorbis_comment) -> StreamMetadata` method that pulls `TITLE` and `ARTIST` (case-insensitive). Keep simple — no album/genre/etc. for v1.

**File path:** `MacAmpApp/Audio/Streaming/StreamMetadata.swift` is the new home; `ICYFramer.swift` keeps `Chunk` enum but its `.metadata(StreamMetadata)` references the shared type.

**Rule of Three exception:** Only 2 callers (ICY + Vorbis), but per principles.md "safety invariants (threading, lifetime, FFI) may be extracted with 2 callers." This isn't strictly safety, but Oracle confirmed the rename is justified by API hygiene. No flag-driven divergent abstraction (Principle 4 rejection criterion).

---

## 12. Phase 7 — Detection + Routing Integration

### 12.1 Local file detection

- `AudioPlayer.detectMediaType(url:)` — unchanged; `.ogg`/`.oga` are `.audio` (not `.video`).
- `AudioEngineController.loadFile(url:)` — new branch on `url.pathExtension.lowercased()`:
  - `["ogg", "oga"]` → `currentSource = .vorbis(...)`.
  - else → existing.

### 12.2 Stream detection

- `StreamDecodePipeline.formatHint(for: url, contentType:)` — see §9.5.
- `handleHTTPResponse` extracts `Content-Type` header, calls `formatHint`, forwards to `DecodeContext.setHint(_:)` BEFORE first data byte (same ordering trick used today for `configureFramer`).

### 12.3 Metadata pipeline

- `MetadataLoader.loadTrackMetadata(from:)` — branch on extension:
  - `["ogg", "oga"]` → new helper `loadVorbisMetadata(url:)` that constructs `VorbisDecoder.makeSeekable(url:)`, calls `ovComment()`, `ovInfo()`, `ovPCMTotal()` for duration, then `dispose()`. Returns `TrackMetadata`.
  - else → existing `AVURLAsset` path.
- `MetadataLoader.loadAudioProperties(from:)` — same branch:
  - Vorbis path returns `AudioProperties(channelCount, bitrate: 0, sampleRate)` (Vorbis nominal bitrate is in `vorbis_info.bitrate_nominal`; populate when present, else 0).

### 12.4 File picker

- `PlaylistWindowActions.swift:60` — `.audio` UTType already includes `.ogg` (verified via macOS UTType registry: `public.ogg-vorbis`, `org.xiph.ogg-vorbis` both conform to `public.audio`). **No edit required**, but add a manual verification step: drop a `.ogg` file into the file picker, confirm it appears in the allowed-files list. If not, add `UTType(filenameExtension: "ogg")` and `UTType(filenameExtension: "oga")` explicitly (one line, defensive).

---

## 13. Phase 8 — Tests (Swift Testing)

**New test file:** `Tests/MacAmpTests/VorbisDecoderTests.swift`.

**Fixtures (committed to repo or downloaded by `Scripts/fetch-vorbis-fixtures.sh`):**

- `tone-440hz-q5.ogg` — 1-second 440 Hz sine, Vorbis q5, stereo 44.1 kHz. (Generate via `oggenc` from a known-WAV; commit the .ogg, not the WAV.)
- `chained-2streams.ogg` — two concatenated logical streams, both stereo 44.1 kHz, with different `ARTIST` Vorbis comments.
- `chained-rate-change.ogg` — two concatenated streams, 44.1 kHz then 48 kHz.
- `mono.ogg` — single-channel Vorbis (must duplicate to stereo).
- `5_1.ogg` — 6-channel Vorbis (must downmix to stereo).
- `truncated.ogg` — first 4 KB of a valid file, for error-path testing.
- Per-codec sniff samples: `opus-bos.bin`, `flac-bos.bin`, `speex-bos.bin`, `theora-bos.bin`, `vorbis-bos.bin`, `notogg.bin`.

**Test cases:**

| ID | Test | Type |
|----|------|------|
| T1 | Decode `tone-440hz-q5.ogg` → expect 44100 ± 100 frames, peak amplitude ≈ 0.9, FFT bin around 440 Hz | unit |
| T2 | Vorbis Comments extraction: TITLE and ARTIST from `tone-440hz-q5.ogg` | unit |
| T3 | Chained stream: `chained-2streams.ogg` decodes both, `.metadata` fires twice | unit |
| T4 | Chain boundary with rate change: `chained-rate-change.ogg` emits `.chainBoundary(48000, 2)` | unit |
| T5 | Mono → stereo duplication: `mono.ogg` produces 2-channel interleaved Float32 | unit |
| T6 | 5.1 → stereo downmix: `5_1.ogg` produces 2-channel interleaved Float32, no clipping | unit |
| T7 | Truncated input: `truncated.ogg` emits `.error` after EOF, no crash | unit |
| T8 | OggCodecSniffer: each fixture identifies correct inner codec | unit |
| T9 | OggCodecSniffer: 7 KB random bytes → `.notOgg` (no false positive) | unit |
| T10 | OggCodecSniffer: 8.5 KB OggS-prefixed garbage → `.overshoot` after deadline | unit |
| T11 | StreamBackend integration: pre-recorded Vorbis stream snippet (~10 s) decodes via `DecodeContext`, format ready fires, ring buffer fills | integration |
| T12 | Sniff replay: feed first 2 KB then rest separately; verify identical PCM output to single-feed | integration |
| T13 | Chain format change: pre-recorded chained stream (`chained-rate-change.ogg`) triggers `DecodeContext.onChainFormatChange` exactly once at the boundary | integration |
| T13b | **Full coordinator bridge retune chain** — uses a test seam (or fake `AudioPlayer`/`StreamPlayer` doubles) to assert: feeding `chained-rate-change.ogg` to a real `StreamDecodePipeline` triggers `StreamPlayer.onStreamChainFormatChanged`, which triggers `PlaybackCoordinator` deactivate→activate sequence, with `setAudioWorkgroup` re-passed using the post-activate workgroup. Verifies the FULL plumbing, not just the decoder event. | integration |
| T14 | Local play / pause / seek / completion via `VorbisFileSource` against `tone-440hz-q5.ogg` | integration |
| T14b | Local-file producer-thread invariant — assert no libvorbis call occurs inside the `scheduleBuffer` completion handler context (verified via a sentinel-thread-id captured in the producer queue and asserted ≠ in-completion-thread-id) | integration |
| T15 | TSan: full suite green | sanity |

**Live-station spot-check table (manual, recorded in research.md):**

| Station | URL hint | Chain frequency | Sample rate | Channels |
|---------|----------|-----------------|-------------|----------|
| SomaFM Groove Salad OGG | `https://ice2.somafm.com/groovesalad-128-ogg` | per-track | 44.1 | 2 |
| SomaFM Drone Zone OGG | `https://ice2.somafm.com/dronezone-128-ogg` | per-track | 44.1 | 2 |
| RadioParadise main mix OGG | (verify endpoint at plan time) | per-track | 44.1 | 2 |
| BBC Radio 3 OGG fallback (if extant) | TBD | per-track | 48 | 2 |
| Indie / classic.com / similar | TBD | per-track | 44.1 | 2 |

Each station: ≥ 5 minutes uninterrupted playback, TSan clean, EQ slider reacts, visualizer animates, balance pans audibly, metadata updates on chain boundary.

---

## 14. Phase 9 — Binary Size Measurement (post-Phase 1)

Goal: replace the asserted "+300 KB" claim with a measurement.

**Procedure:**

1. Branch checkpoint A: `main` HEAD before Phase 1.
2. Branch checkpoint B: `feat/ogg-vorbis-support` after Phase 1 merges.
3. For both, run release build:
   ```bash
   xcodebuildmcp macos build --json '{"configuration":"Release"}'
   ```
4. Measure each slice:
   ```bash
   du -sh dist/MacAmp.app/Contents/MacOS/MacAmp
   lipo -archs dist/MacAmp.app/Contents/MacOS/MacAmp
   size -m dist/MacAmp.app/Contents/MacOS/MacAmp | grep -i __TEXT
   ```
5. Append "Binary Size Delta" table to `research.md`:
   - arm64 .text delta (bytes).
   - x86_64 .text delta (bytes).
   - Stripped `.app` delta.
   - Compressed `.dmg` delta.

Decision criterion (already accepted): up to +500 KB stripped is acceptable. >1 MB warrants investigation.

---

## 15. Files Inventory

### New files

| Path | Purpose | Approx LOC |
|------|---------|-----------|
| `Vendor/COggVorbis/Package.swift` | Local SwiftPM package wrapping cTargets | 60 |
| `Vendor/COggVorbis/Sources/Cogg/...` | libogg sources + headers + modulemap | C only |
| `Vendor/COggVorbis/Sources/Cvorbis/...` | libvorbis sources + headers + modulemap (encoder excluded) | C only |
| `MacAmpApp/Audio/Vorbis/VorbisDecoder.swift` | libvorbis Swift wrapper (stream + seekable file paths) | 400-500 |
| `MacAmpApp/Audio/Vorbis/VorbisFileSource.swift` | Local-file pull source feeding chained `scheduleBuffer` | 150-200 |
| `MacAmpApp/Audio/Vorbis/OggCodecSniffer.swift` | First-BOS-page codec discriminator | 100 |
| `MacAmpApp/Audio/Streaming/StreamMetadata.swift` | Codec-agnostic metadata struct | 30 |
| `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` | Xiph BSD notices | text |
| `Tests/MacAmpTests/VorbisDecoderTests.swift` | T1-T15 | 400 |
| `Tests/MacAmpTests/Fixtures/Vorbis/*.ogg` + `*.bin` | Audio + sniff fixtures | binary |
| `Scripts/fetch-vorbis-fixtures.sh` | Optional: regenerate fixtures from WAV | 40 |

### Modified files (verified at HEAD)

| Path | Change |
|------|--------|
| `Package.swift` | Add `Vendor/COggVorbis` as dependency package. |
| `project.yml` | Add `packages: COggVorbis: { path: ./Vendor/COggVorbis }`; add `package: COggVorbis, product: Cogg` and `Cvorbis` to `MacAmp.dependencies`; add `Resources/THIRD_PARTY_LICENSES.txt` to resources. |
| `MacAmpApp/Audio/AudioEngineController.swift` (424 lines at HEAD) | Add `LocalAudioSource` enum, `currentSource` property, `hasLoadedSource` getter, `rewireForVorbis(_:)`, `loadFile` branch on extension, `currentFileDuration` switch, `scheduleFrom` Vorbis branch with producer task, `clearFile` close. ~120 lines added. |
| `MacAmpApp/Audio/AudioPlayer.swift` (734 lines at HEAD) | Replace 4 sites of `engine.audioFile != nil` with `engine.hasLoadedSource`. No other changes. swiftlint suppressions remain. |
| `MacAmpApp/Audio/MetadataLoader.swift` (169 lines at HEAD) | Branch `loadTrackMetadata` and `loadAudioProperties` on `.ogg`/`.oga`; add `loadVorbisMetadata` helper. ~80 lines added. |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` (697 lines at HEAD) | Add `StreamBackend` fileprivate enum, `PipelineLifecycle` state, `StreamFormatHint` enum, `setHint` on DecodeContext, `OggCodecSniffer` integration, buffered-byte replay, `onChainFormatChange` callback, sample-rate change handling. ~250 lines net added. |
| `MacAmpApp/Audio/Streaming/ICYFramer.swift` (200 lines at HEAD) | Replace `ICYMetadata` with shared `StreamMetadata` (move struct out). ~5 lines net change. |
| `MacAmpApp/Audio/StreamPlayer.swift` (414 lines at HEAD) | `onMetadata` signature update; new `onStreamChainFormatChanged: (@MainActor (Float64) -> Void)?` callback (forwards from `pipeline.onChainFormatChange`). ~20 lines. |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` (562 lines at HEAD) | Wire `streamPlayer.onStreamChainFormatChanged` → `audioPlayer.deactivateStreamBridge()` → `audioPlayer.activateStreamBridge(_, sampleRate:)` → re-pass workgroup. ~25 lines. |
| `MacAmpApp/Views/PlaylistWindowActions.swift` | Optional defensive add of `UTType(filenameExtension: "ogg")` and `"oga"` if `.audio` doesn't auto-include them. 0-2 lines. |

**Estimated total:** ~1000 lines new Swift, ~250 lines modified Swift, ~3 MB vendored C, ~30 binary KB fixture audio.

---

## 16. State / Responsibility Map

| State | Owner | Confinement |
|-------|-------|-------------|
| URLSession lifecycle, `dataTask`, `urlSession`, `delegateProxy`, `generation`, `userRequestedStop`, `state`, `audioWorkgroup` | `StreamDecodePipeline` (@MainActor) | MainActor |
| `framer`, `parser`, `decoder` (existing), `magicCookie`, `prebufferedFrames`, `detectedSampleRate`, `isShutdown`, **`formatReadyFired` (single authoritative gate, was duplicated on @MainActor; now collapsed per §9.7)** | `DecodeContext` (@unchecked Sendable, queue-confined) | decode queue |
| **NEW:** `backend: StreamBackend?`, `lifecycle: PipelineLifecycle`, `sniffer: OggCodecSniffer`, `formatHint: StreamFormatHint`, `detectedChannels: Int` | `DecodeContext` | decode queue |
| **NEW:** libvorbis state (`ogg_sync_state`, `vorbis_dsp_state`, etc.) | `VorbisDecoder` (queue-confined) | decode queue (stream) OR `VorbisFileSource` producer task (file) |
| **NEW:** `currentSource: LocalAudioSource?`, `vorbisProducerTask`, `vorbisProducerGeneration` | `AudioEngineController` (@MainActor) | MainActor (control) + producer task (decode work) |

No new actor isolation. No widening of `private` → `internal`. `StreamBackend` is `fileprivate` to `StreamDecodePipeline.swift` (Principle 5).

---

## 17. Verification Approach

**Quantitative gates (must all pass before PR review):**

1. `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — clean.
2. `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all new tests (T1-T15, T13b, T14b) green; all pre-task tests still green (baseline count recorded in C1 commit message).
3. `lipo -archs MacAmp` shows `arm64 x86_64`.
4. Release-build size delta documented (Phase 9).

**Manual gates (must all pass before PR review):**

5. 5 OGG live stations from §13 table — ≥ 5 minutes each, TSan clean, EQ + visualizer + balance functional, metadata updates on chain.
6. `tone-440hz-q5.ogg` plays via local-file path; play/pause/seek-to-50%/seek-to-end/manual-pause/resume all behave per existing transport semantics.
7. `chained-rate-change.ogg` (committed fixture) plays end-to-end; engine bridge correctly re-activates on chain.
8. EQ + visualizer + balance behave on local Vorbis identically to local MP3 (compare A/B).
9. Drag .ogg from Finder into playlist → loads + plays.
10. Add Internet Radio Station with Icecast OGG URL → plays.
11. Try Opus/.opus URL → user-visible error "OGG Opus not supported", no hang.

**Oracle gates (during planning + implementation):**

12. This plan iterated with Oracle (`gpt-5.5`, `xhigh`) to score ≥ 9/10 BEFORE implementation begins.
13. Post-implementation: Codex Oracle code review of full diff, score ≥ 9/10 BEFORE PR opens.

---

## 18. Risk Assessment (research.md table extended for plan-time)

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Phase 0a wiring fails** | Medium-High | Spike is throwaway; fall back to xcframework (Option 2). Re-plan §6. |
| **Phase 0b chained-buffer transport fails** | High | Likely abort task per §19; OGG local support is low-value if it requires `LocalPlaybackBackend` redesign. |
| **Chained Ogg streams in Icecast** | High | libvorbis `ogg_sync` handles natively; `.chainBoundary` event drives bridge re-activation (§9.7). Verified against ≥ 1 known-chained station (SomaFM). |
| **Chained-format change mid-playback** (existing pipeline gap) | High | §9.7 explicit fix; plan-time test fixture `chained-rate-change.ogg` (T4 + T13). |
| **Render-thread libvorbis call** | High | Documented invariant in `VorbisDecoder.swift` header; `dispatchPrecondition` in every public method; producer side only. |
| **Local transport regression** | High | Phase 0b spike pre-validates; T14 covers play/pause/seek/completion. |
| **Sniff replay byte loss** | Medium | T12 explicit test; serial decode queue ordering invariant documented. |
| **`.ogg` is actually Opus / FLAC / Speex / Theora** | Medium | Sniffer identifies; user gets explicit "OGG <codec> not supported" error (non-reconnectable). |
| **stb_vorbis fallback needed** | Low | Not the primary plan; documented in research. |
| **Binary size regression** | Low | Measured in Phase 9; budget +500 KB stripped. |
| **License notice missing in shipped app** | Low | `THIRD_PARTY_LICENSES.txt` in bundle resources; verify post-build. |
| **macOS arch coverage** | Low | Phase 0a step 9 verifies `lipo -archs`. |
| **Vorbis Comments encoding** | Low | UTF-8 per spec — `String(data:encoding:.utf8)` direct. |
| **Mono / 5.1 Vorbis** | Low | T5 + T6 fixtures; downmix coefficients per ITU-R BS.775. |
| **MetadataLoader regression on non-OGG files** | Low | Branch is at the top of method; existing path untouched. |

---

## 19. Stop Criteria / Kill Switch

**Per-phase kill switches:**

| Phase | If this happens | Action |
|-------|-----------------|--------|
| 0a | XcodeGen + cTargets fail to link after 1 day of investigation | Fall back to **Option 2 xcframework** (research §"Option 2"). Re-plan vendoring step. Continue task. |
| 0a | xcframework also fails | **Pause task.** Escalate; consider Homebrew system-library only as dev-mode build (not shipping). |
| 0b | `playerTime` drift ≥ 100 ms over 60 s with chained `scheduleBuffer` | Investigate sample-clock anchor. If unfixable → escalate; consider `LocalPlaybackBackend` protocol redesign. |
| 0b | Completion fires multiple/zero times | **Abort task** — Path A-revised assumptions wrong; protocol redesign is months of work for low-value codec. |
| 1 | libvorbis fails to compile cleanly on x86_64 | Fall back to xcframework (Option 2) which can be built once per arch and combined. **Universal build is non-negotiable for this task** — MacAmp ships arm64 + x86_64 (see `project.yml`). Dropping x86_64 is a formal scope change, not an implicit fallback; if all paths fail, abort task per top-level kill switch. |
| 4 | DecodeContext state machine introduces TSan-detectable races | Roll back §9.7 chain-boundary fix; ship Phase 5 (local-only) as v1; re-plan stream path as separate PR. |
| 5 | Audible artifacts at chunk boundaries on real Vorbis content | Increase chunk size to 16384 frames; if still audible → cross-fade chunks (small additional code). Not a kill condition. |
| 6 | Renaming `ICYMetadata` introduces unexpected call-site fanout | Cancel rename; use a `typealias StreamMetadata = ICYFramer.ICYMetadata` instead (still satisfies API hygiene). |
| 9 | Binary size delta > 1 MB stripped | Investigate static-archive build flags (`-Os`, `-fdata-sections`, `-ffunction-sections`, `-Wl,-dead_strip`). Not a kill condition. |

**Top-level kill switch:** if 0a OR 0b fails AND fallbacks fail → close task without merge. Document findings in `tasks/done/ogg-vorbis-support/lessons.md`. The codebase remains as-is; user-visible behaviour unchanged.

---

## 20. Branch + PR Plan

**Branches:**

- `feat/ogg-vorbis-support` — implementation. PR #E.
- `spike/ogg-build-wiring` — Phase 0a, throwaway, deleted post-merge of `feat/...`.
- `spike/ogg-local-playback` — Phase 0b, throwaway, deleted post-merge of `feat/...`.

**Predecessors (locked S3 ordering, see `_context/state.md`):**

- S3-3 `hls-streaming-support` MUST be merged.
- S3-2 `video-audio-engine-routing` MUST be merged.
- S3-1 (`mwvi`, `spt`) MUST be merged.

**Pre-implementation steps (in order):**

1. Run Phase 0a spike on `spike/ogg-build-wiring`. Append result to `research.md`. Decide Option 1 vs 2.
2. Run Phase 0b spike on `spike/ogg-local-playback`. Append result to `research.md`. Pass/abort.
3. Re-read affected files at HEAD (this plan was authored against post-S3-3 HEAD on 2026-04-27; line numbers may shift if hotfixes land).
4. Branch `feat/ogg-vorbis-support` off latest `main`.

**Commit cadence (one commit per phase, force-push permitted on feature branch):**

- C1 — Phase 1 (vendoring + license).
- C2 — Phase 2 (`VorbisDecoder`).
- C3 — Phase 3 (`OggCodecSniffer`).
- C4 — Phase 4 (`StreamBackend` enum + state machine + chain-boundary fix).
- C5 — Phase 5 (`LocalAudioSource` + `VorbisFileSource`).
- C6 — Phase 6 (`StreamMetadata` rename).
- C7 — Phase 7 (detection routing).
- C8 — Phase 8 (tests).
- C9 — Phase 9 (binary size measurement appended to research).

**PR template:**

- Summary: ≤ 3 bullets, link to `tasks/ogg-vorbis-support/research.md` + this plan.
- Test plan: §17.
- Co-Authored-By: Claude Opus 4.7.
- Oracle review summary appended once score ≥ 9/10.

---

## 21. Rollback Plan

**Granular rollbacks (per phase):**

| Phase | Rollback procedure |
|-------|-------------------|
| 1 | `git revert C1`. Rebuild. Vendor dir + `Package.swift` packages entry removed. No app behaviour change (no Vorbis code referenced yet). |
| 2 | `git revert C2`. `VorbisDecoder.swift` deleted. No call sites yet (introduced in C4/C5). |
| 4 | `git revert C4`. Stream pipeline returns to pre-OGG state. `chained-rate-change` gap returns (acceptable until next attempt). Local file path retained from C5 (independent). |
| 5 | `git revert C5`. Local Vorbis disabled; streams retained. |
| 6 | `git revert C6`. Type rename reverted; `ICYFramer.ICYMetadata` restored. |
| 7 | `git revert C7`. Detection routes back to existing-only paths. |

**Full rollback:** `git revert C9..C1` on feature branch, force-push, close PR. The vendored sources, license file, and `project.yml` packages block can remain in `main` if Phase 1 alone merges (provides no behaviour, no risk).

**Post-merge rollback:** PR-level revert via GitHub UI. Coordinate with state.md update.

**Kill switch trigger:** any of §19's "Abort task" conditions → file `tasks/done/ogg-vorbis-support/lessons.md` documenting failure mode + telemetry.

---

## 22. Architecture Decision Record

**Decision:** Add OGG Vorbis support via vendored libvorbis + libogg, with stream-side `StreamBackend` enum branch and local-side `LocalAudioSource` enum branch on `AudioEngineController`. Rename `ICYMetadata` → `StreamMetadata` in passing.

**Status:** Proposed (this plan). Awaits Oracle ≥ 9/10 + Phase 0a/b spike pass.

**Context:** Last unaddressed lossy-codec parity gap; resolves a real-world existing pipeline gap (one-shot `onFormatReady`).

**Trade-offs accepted:**

- +~3 MB vendored C source under `Vendor/`.
- +300 KB (estimated, will measure) static archive in shipped binary.
- One additional state machine in `DecodeContext` (`PipelineLifecycle`).
- Two mandatory throwaway spike branches.

**Trade-offs rejected:**

- xcframework (Option 2) — chosen as fallback only.
- Homebrew system library — incompatible with notarization.
- ffmpeg — overkill (~25 MB).
- stb_vorbis — chained-stream gap is exactly the Icecast use case.
- Pure-Swift port — does not exist mature.
- `LocalPlaybackBackend` protocol redesign — months of work for low-value codec.
- `StreamDecoder` protocol — Principle 6 pass-through middleman risk.

**When to stop / cancel:** §19 kill-switch table.

**ADR-level success criteria:** §17 verification gates 1-13 all pass.

---

## 23. Oracle Validation Summary

**Pre-implementation Oracle validation gate:** `mcp__codex-cli__codex` with `model: gpt-5.3-codex` (xhigh reasoning), against this plan + `research.md` + `_context/principles.md`.

**Target:** ≥ 9/10. Iteration limit: 4 rounds.

| Round | Date | Score | Verdict | Top findings | Resolution |
|-------|------|-------|---------|--------------|------------|
| 1 | 2026-04-27 | 8.2 | GO-WITH-CHANGES | CRITICAL: dual `formatReadyFired` gates leave bridge stale on chain rate change. HIGH: Phase 0a smoke didn't exercise Cvorbis→Cogg link; arch policy contradicted itself; chained-buffer completion handler decode risk. MEDIUM: VorbisDecoder dual responsibility; missing full coordinator bridge-retune integration test. | Single decode-queue-confined `formatReadyFired` gate + new chain callback chain (§9.7); Cvorbis smoke now calls Cogg + universal-build hard fail (§4); dedicated producer queue + completion-handler ban (§10.1); explicit immutable `Mode` sum-type on VorbisDecoder (§7); T13b + T14b added (§13). |
| 2 | 2026-04-27 | 8.9 | GO-WITH-CHANGES | MEDIUM: state map still listed `formatReadyFired` on @MainActor side (single-source-of-truth not fully propagated). LOW: callback name inconsistency between layers; LOW: brittle test count "57 existing" in plan §17. | State map updated (§16); explicit naming-convention note added (§9.7 step 4); §17 quantitative gate now references "all pre-task tests" + baseline-in-commit-message. |
| 3 | 2026-04-27 | **9.3** | **GO** | LOW: stale §15 cross-reference (should be §19); LOW: `openSeekable` API drift between §10.1 and §7 / todo. | Both fixed in trailing pass. |
| 4 | — | n/a | n/a | n/a (≥9 reached at round 3) | — |

**Post-implementation Oracle review:** mandatory before PR opens; same model/effort; full diff against base branch; target ≥ 9/10. Per `_context/state.md` "Per the research, second Oracle pass mandatory after plan exists" — this is the post-implementation pass, gating PR.

---

## 24. References

- `tasks/ogg-vorbis-support/research.md` — Oracle GO-WITH-CHANGES 6.8/10 with revisions applied.
- `tasks/_context/principles.md` — 7 decomposition principles.
- `tasks/_context/state.md` — locked S3 ordering.
- `tasks/done/unified-audio-pipeline/plan.md` — streaming pipeline pattern reference.
- `tasks/done/unified-audio-pipeline/lessons-learned.md` — bridge lifecycle lessons.
- Xiph Vorbis I spec — https://xiph.org/vorbis/doc/Vorbis_I_spec.html
- RFC 3533 / 5334 (Ogg encapsulation + media types).
- libvorbis 1.3.7, libogg 1.3.5, vorbisfile.h documentation.
