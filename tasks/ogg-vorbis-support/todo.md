# Todo: OGG Vorbis Support

> **Source:** `plan.md` §4–§22.
> **Branch (impl):** `feat/ogg-vorbis-support`. Spike branches throwaway: `spike/ogg-build-wiring`, `spike/ogg-local-playback`.
> **Predecessors:** S3-1 (mwvi + spt), S3-2 (vaer), S3-3 (hls) all merged before C1.

---

## Pre-implementation gates

- [ ] **Gate G0:** Oracle validation of this plan (`gpt-5.5`, `xhigh`) ≥ 9/10. Iterate up to 4 rounds.
- [ ] **Gate G1:** Re-read all "Files Affected" at HEAD; reconfirm line numbers in plan §15. Update plan if drift > 20 lines.
- [ ] **Gate G2:** Phase 0a spike PASS — `Cogg`/`Cvorbis` smoke build links + runs on arm64+x86_64 with TSan, smoke fn returns 42.
- [ ] **Gate G3:** Phase 0b spike PASS — chained `scheduleBuffer` reproduces play / pause / seek / progress / completion semantics on a non-Vorbis WAV; TSan clean on macOS 15 + macOS 26.
- [ ] **Gate G4:** Append "Phase 0a Spike Result" + "Phase 0b Spike Result" sections to `research.md` with build output, decision, and SHAs.
- [ ] **Gate G5:** Delete throwaway spike branches after results recorded.

> **HARD STOP:** if G2 fails AND xcframework fallback also fails → close task per §19 top-level kill switch. If G3 fails → abort task; document in `tasks/done/ogg-vorbis-support/lessons.md`.

---

## Phase 0a — Build-wiring spike (`spike/ogg-build-wiring`, throwaway)

- [ ] 0a.1  Create `Vendor/COggVorbis/Package.swift` declaring `Cogg` + `Cvorbis` cTargets, with `Cvorbis.dependencies = [.target(name: "Cogg")]`.
- [ ] 0a.2  Add `Cogg/include/ogg/og_types_smoke.h` defining `typedef int32_t ogg_int32_t;` and `Cogg/Sources/og_smoke.c` containing `#include "ogg/og_types_smoke.h"\nint og_smoke(void){ ogg_int32_t v = 42; return (int)v; }`.
- [ ] 0a.3  Add `Cvorbis/include/vorbis/vb_smoke.h` declaring `int vb_smoke(void);` and `Cvorbis/Sources/vb_smoke.c` containing both `#include "vorbis/vb_smoke.h"` and `#include "ogg/og_types_smoke.h"` plus `int vb_smoke(void){ return og_smoke(); }`. This proves Cvorbis→Cogg link AND transitive header resolution.
- [ ] 0a.4  Add module map per target (`include/module.modulemap`) declaring umbrella headers.
- [ ] 0a.5  Add `packages: COggVorbis: { path: ./Vendor/COggVorbis }` to `project.yml`.
- [ ] 0a.6  Add `package: COggVorbis, product: Cogg` and `Cvorbis` under `targets.MacAmp.dependencies`.
- [ ] 0a.7  `xcodegen generate`.
- [ ] 0a.8  Add temporary `MacAmpApp/Audio/_OggSmoke.swift` containing `import Cogg; import Cvorbis; let _ = og_smoke(); let _ = vb_smoke()`.
- [ ] 0a.9  `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES","ARCHS=arm64 x86_64","ONLY_ACTIVE_ARCH=NO"]}'` — clean, both `og_smoke` and `vb_smoke` resolved.
- [ ] 0a.10 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — green.
- [ ] 0a.11 `lipo -archs $BUILD/MacAmp` shows EXACTLY `arm64 x86_64` (universal mandatory; single-arch is HARD FAIL).
- [ ] 0a.12 Append "Phase 0a Spike Result" to `research.md`.
- [ ] 0a.13 Decide Option 1 confirmed OR Option 2 fallback. If fallback, re-plan §6. Universal-build remains mandatory under either option.
- [ ] 0a.14 Delete `spike/ogg-build-wiring`. Carry forward only the `project.yml` packages entry + `Vendor/COggVorbis/Package.swift` skeleton (smoke files removed in C1).

## Phase 0b — Local-playback contract spike (`spike/ogg-local-playback`, throwaway)

- [ ] 0b.1  Add `MacAmpApp/Audio/_ChunkedFileSpike.swift` under `#if DEBUG`.
- [ ] 0b.2  Helper loads a known WAV via `AVAudioFile`, reads to 8192-frame `AVAudioPCMBuffer`s.
- [ ] 0b.3  Helper schedules buffers via chained `playerNode.scheduleBuffer(_:completionHandler:)` on `AudioEngineController.playerNode`.
- [ ] 0b.4  Wire a debug menu item to invoke spike against a fixture WAV.
- [ ] 0b.5  V0b.1 — Play: continuous audio, no clicks (subjective + dB-meter check at boundaries).
- [ ] 0b.6  V0b.2 — Pause/resume: works through `playerNode.pause()` / `playerNode.play()`.
- [ ] 0b.7  V0b.3 — `playerTime`-driven progress timer updates monotonically; drift ≤ 100 ms over 60 s.
- [ ] 0b.8  V0b.4 — Seek mid-playback via `playerNode.stop()` + re-prime; existing `seek(to:)` semantics hold.
- [ ] 0b.9  V0b.5 — Final-buffer completion fires `onPlaybackEnded` exactly once with correct seekID.
- [ ] 0b.10 V0b.6 — TSan clean on macOS 15 Sequoia.
- [ ] 0b.11 V0b.6 — TSan clean on macOS 26 Tahoe.
- [ ] 0b.12 Append "Phase 0b Spike Result" to `research.md` with V0b.1–V0b.6 outcomes.
- [ ] 0b.13 Pass → continue. Fail (drift, miscount, race) → escalate; consider abort per §19.
- [ ] 0b.14 Delete `spike/ogg-local-playback`. No code carried forward.

---

## Phase 1 — Vendor libogg + libvorbis (commit C1)

- [ ] 1.1  Vendor `libogg-1.3.5/src/{bitwise,framing}.c` + `include/ogg/*.h` under `Vendor/COggVorbis/Sources/Cogg/`.
- [ ] 1.2  Vendor `libvorbis-1.3.7/lib/*.c` (excluding `vorbisenc.c`) + `include/vorbis/*.h` under `Vendor/COggVorbis/Sources/Cvorbis/`.
- [ ] 1.3  Generate `config_types.h` for arm64+x86_64 macOS (`ogg_int16_t = int16_t`, etc.) and place under `Cogg/include/ogg/`.
- [ ] 1.4  Add `Vendor/libogg/LICENSE.txt` + `Vendor/libvorbis/LICENSE.txt` (verbatim Xiph BSD).
- [ ] 1.5  Update `Vendor/COggVorbis/Package.swift` to reference real sources + headers; remove smoke files.
- [ ] 1.6  Wire `Cvorbis.dependencies = [.target(name: "Cogg")]` and `linkerSettings: [.linkedLibrary("m")]`.
- [ ] 1.7  Set `Cvorbis` `cSettings: [.headerSearchPath("include"), .headerSearchPath("lib")]`.
- [ ] 1.8  Create `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` containing both Xiph BSD notices.
- [ ] 1.9  Add `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` to `project.yml` `targets.MacAmp.resources`.
- [ ] 1.10 `xcodegen generate`.
- [ ] 1.11 `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — clean (no warnings about modulemap clashes).
- [ ] 1.12 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all pre-task tests still green; record baseline count in C1 commit message.
- [ ] 1.13 Verify `MacAmp.app/Contents/Resources/THIRD_PARTY_LICENSES.txt` is in the bundle.
- [ ] 1.14 Commit C1: "feat(ogg): vendor libogg+libvorbis, add Xiph license notice".

## Phase 2 — VorbisDecoder (commit C2)

- [ ] 2.1  Create `MacAmpApp/Audio/Vorbis/VorbisDecoder.swift`.
- [ ] 2.2  `final class VorbisDecoder: QueueConfined, @unchecked Sendable` with two mutually-exclusive modes (immutable `let mode: Mode`).
- [ ] 2.3  Define `fileprivate enum Mode { case stream; case seekableFile }`. Construct via `static func makeStream() -> VorbisDecoder` and `static func makeSeekable(url: URL) throws -> VorbisDecoder`.
- [ ] 2.4  Mode `.stream` state: `ogg_sync_state`, `ogg_stream_state`, `vorbis_info`, `vorbis_comment`, `vorbis_dsp_state`, `vorbis_block`.
- [ ] 2.5  Mode `.seekableFile` state: `OggVorbis_File` only (libvorbisfile manages internals).
- [ ] 2.6  Mode `.stream` API: `func feed(_ data: Data)` — `ogg_sync_buffer` + `ogg_sync_wrote` + memcpy. Asserts `mode == .stream`.
- [ ] 2.7  Mode `.stream` API: `func pump() -> [VorbisDecodeEvent]` — drain pages → packets → PCM. Detect chain boundary via `ogg_page_bos` post-first. Asserts `mode == .stream`.
- [ ] 2.8  `enum VorbisDecodeEvent`: `formatReady, metadata, pcm, chainBoundary, endOfStream, error`.
- [ ] 2.9  Mono → stereo duplication.
- [ ] 2.10 Stereo passthrough.
- [ ] 2.11 N>2 channel ITU-R BS.775 downmix to stereo (front L+R direct, center ×0.707, surrounds ×0.5, LFE dropped).
- [ ] 2.12 Mode `.stream` API: `func resetForChain()` — tear down `vorbis_synthesis_*` for chain boundary, keep `ogg_sync` alive.
- [ ] 2.13 Mode `.seekableFile` API: `func ovPCMSeek(_ frame: Int64)`, `ovPCMTotal()`, `ovComment()`, `ovInfo()`, `ovRead(into:frameCount:) -> Int`. All assert `mode == .seekableFile`.
- [ ] 2.14 `func dispose()` — mode-aware full teardown.
- [ ] 2.15 `deinit { dispose() }`.
- [ ] 2.16 Add `dispatchPrecondition(condition: .onQueue(confinementQueue))` (when set) plus `precondition(mode == .stream)` / `precondition(mode == .seekableFile)` per applicability — to every public method.
- [ ] 2.17 Inline doc: "// CONTRACT: never call libvorbis from render thread; mode is immutable post-init".
- [ ] 2.18 `xcodegen generate` (new files).
- [ ] 2.19 Build + tests still green; TSan clean.
- [ ] 2.20 Commit C2.

## Phase 3 — OggCodecSniffer (commit C3)

- [ ] 3.1  Create `MacAmpApp/Audio/Vorbis/OggCodecSniffer.swift`.
- [ ] 3.2  `struct OggCodecSniffer: Sendable`.
- [ ] 3.3  Define `OggInnerCodec` and `OggSniffResult` enums per plan §8.
- [ ] 3.4  `mutating func consume(_ data: Data, deadline: ContinuousClock.Instant) -> OggSniffResult`.
- [ ] 3.5  Buffer cap 8192 bytes.
- [ ] 3.6  Parse first 4 bytes — match "OggS".
- [ ] 3.7  Parse Ogg page header (27 bytes + segment table).
- [ ] 3.8  Classify first packet body: vorbis / opus / flac / speex / theora / unknown.
- [ ] 3.9  Return `.identified(codec, bufferedBytes)` with all accumulated bytes for replay.
- [ ] 3.10 Return `.notOgg(buffered)` on first-4 mismatch.
- [ ] 3.11 Return `.overshoot` after 8192-byte cap or 250 ms deadline.
- [ ] 3.12 Build + tests green; TSan clean.
- [ ] 3.13 Commit C3.

## Phase 4 — StreamBackend enum + state machine + chain-boundary fix (commit C4)

> **Touches:** `StreamDecodePipeline.swift` (697 lines at HEAD). Verify line numbers before editing.

- [ ] 4.1  In `StreamDecodePipeline.swift`, declare `fileprivate enum StreamBackend { case audioFileStream(AudioFileStreamParser, AudioConverterDecoder?); case oggVorbis(VorbisDecoder) }`.
- [ ] 4.2  Declare `fileprivate enum PipelineLifecycle { case connecting, sniffing, decoderSelected, buffering, playing }`.
- [ ] 4.3  Declare `fileprivate enum StreamFormatHint { case audioFileStream(AudioFileTypeID), ogg, unknown }`.
- [ ] 4.4  Replace `formatHint(for: URL) -> AudioFileTypeID` with `formatHint(for: URL, contentType: String?) -> StreamFormatHint`.
- [ ] 4.5  Modify `DecodeContext` — remove eager parser init; add `lifecycle`, `sniffer`, `formatHint`, `backend`, `detectedChannels`.
- [ ] 4.6  Add `setHint(_:)` queue-confined on `DecodeContext`; wire from `handleHTTPResponse` (MainActor) via `decodeQueue.async`.
- [ ] 4.7  `handleIncomingData` rewritten as state-machine dispatch.
- [ ] 4.8  `.sniffing` → feed `OggCodecSniffer`; on `.identified(.vorbis, buffered)` → instantiate `VorbisDecoder`, feed buffered bytes BEFORE new bytes; on other identified codecs → `decodeError("OGG <codec> not supported")`; on `.notOgg(buffered)` → instantiate `AudioFileStreamParser`, replay buffered bytes; on `.overshoot` → `decodeError`.
- [ ] 4.9  `.decoderSelected` / `.buffering` → drain backend; emit format-ready / metadata / PCM events.
- [ ] 4.10 **Collapse dual format-ready gate to ONE source of truth**: remove `StreamDecodePipeline.formatReadyFired` (the @MainActor copy at line 100); `DecodeContext.formatReadyFired` becomes the single gate. The `onFormatReady` MainActor closure body becomes idempotent against duplicate same-sample-rate fires (compare-and-skip).
- [ ] 4.11 `DecodeContext.formatReadyFired` is reset to false on chain-boundary if sample rate changed; reset prebufferedFrames=0; flush ring buffer; emit `onChainFormatChange(newRate)`.
- [ ] 4.12 New `onChainFormatChange: (@MainActor @Sendable (Float64) -> Void)?` on `StreamDecodePipeline`.
- [ ] 4.13 New `onStreamChainFormatChanged: (@MainActor (Float64) -> Void)?` on `StreamPlayer` plumbing through to `PlaybackCoordinator`.
- [ ] 4.14 `PlaybackCoordinator.onStreamChainFormatChanged` handler: deactivate bridge → activate bridge with new rate → re-pass `audioWorkgroup` (workgroup must be re-fetched post-activate).
- [ ] 4.15 Generation-token guards on every new state transition AND on chain-boundary callback.
- [ ] 4.16 Replay-byte ordering preserved by serial decode queue; document in comment.
- [ ] 4.17 Build + tests; new T11 + T12 + T13 + T13b added (T13b = full coordinator retune harness).
- [ ] 4.18 Commit C4.

## Phase 5 — LocalAudioSource + VorbisFileSource (commit C5)

- [ ] 5.1  Create `MacAmpApp/Audio/Vorbis/VorbisFileSource.swift`.
- [ ] 5.2  `init(url: URL) throws` opens via `VorbisDecoder.makeSeekable(url:)`.
- [ ] 5.3  `var totalFrames`, `sampleRate`, `processingFormat: AVAudioFormat`.
- [ ] 5.4  `func bufferAt(frame:frameCount:) -> AVAudioPCMBuffer?` — pulls PCM from decoder; seeks if needed.
- [ ] 5.5  `func close()`.
- [ ] 5.6  In `AudioEngineController.swift` (424 lines at HEAD), add `fileprivate enum LocalAudioSource { case avAudioFile(AVAudioFile); case vorbis(VorbisFileSource) }`.
- [ ] 5.7  Add `private var currentSource: LocalAudioSource?`.
- [ ] 5.8  Add `var hasLoadedSource: Bool { currentSource != nil }`.
- [ ] 5.9  Replace `audioFile` direct reads with `currentSource` switch where possible; keep `audioFile` as computed `currentSource.asAVAudioFile` for transitional internal callers.
- [ ] 5.10 Add `rewireForVorbis(_ source: VorbisFileSource)` mirroring `rewireForFile` but with Vorbis processingFormat.
- [ ] 5.11 Modify `loadFile(url:)` — branch on `.ogg`/`.oga`; load via `VorbisFileSource`; call `rewireForVorbis`.
- [ ] 5.12 Modify `currentFileDuration` to switch on `currentSource`.
- [ ] 5.13 Modify `scheduleFrom(time:seekID:)` — for `.vorbis` case, cancel previous producer (generation bump), seek decoder via `ovPCMSeek`, kick off new producer queue chaining `scheduleBuffer`. Final-completion fires `onPlaybackEnded(seekID)`.
- [ ] 5.14 **Strict producer-queue contract**: dedicated `DispatchQueue` (`com.macamp.vorbis.file.producer`, QoS `.userInitiated`) owns ALL `bufferAt` / libvorbis calls. Pre-fill depth 3 buffers (~558 ms at 8192 frames / 44.1 kHz). The `scheduleBuffer` completion handler ONLY hops to producer queue and signals; it MUST NOT call libvorbis. Add inline `// CONTRACT: completion handler does not decode` comment.
- [ ] 5.15 Add producer-task generation token (`vorbisProducerGen: UInt64`) to reject stale completions.
- [ ] 5.16 Final-chunk EOF: when `bufferAt` returns nil, set "no more buffers" flag; LAST `scheduleBuffer` completion handler reads flag and fires `onPlaybackEnded(seekID)` exactly once.
- [ ] 5.17 Modify `clearFile()` — `currentSource?.close(); currentSource = nil`.
- [ ] 5.18 In `AudioPlayer.swift` (734 lines at HEAD), replace 3-4 sites of `engine.audioFile != nil` with `engine.hasLoadedSource` (verify exact lines: 417, 552, 568 at planning time).
- [ ] 5.19 Manual verify: `tone-440hz-q5.ogg` plays; play/pause/seek-50%/seek-end/manual-pause/resume all behave per existing transport semantics.
- [ ] 5.20 EQ slider, visualizer, balance behave on Vorbis identically to MP3 (A/B compare).
- [ ] 5.21 Drag .ogg from Finder → loads + plays.
- [ ] 5.22 TSan clean.
- [ ] 5.23 Commit C5.

## Phase 6 — StreamMetadata rename (commit C6)

- [ ] 6.1  Create `MacAmpApp/Audio/Streaming/StreamMetadata.swift` declaring `struct StreamMetadata: Sendable { let title: String?; let artist: String? }`.
- [ ] 6.2  In `ICYFramer.swift`, remove inner `ICYMetadata` struct; change `Chunk.metadata(StreamMetadata)`.
- [ ] 6.3  Update `parseMetadata(_:)` return type and call sites.
- [ ] 6.4  In `StreamDecodePipeline.swift`, change `onMetadata` signature to `(@MainActor @Sendable (StreamMetadata) -> Void)?`.
- [ ] 6.5  In `StreamPlayer.swift` (414 lines at HEAD), update `pipeline.onMetadata` closure parameter type.
- [ ] 6.6  In `VorbisDecoder.swift`, add `commentsToMetadata(_ comment: vorbis_comment) -> StreamMetadata` extracting TITLE + ARTIST (case-insensitive).
- [ ] 6.7  Build + tests.
- [ ] 6.8  Verify ICY metadata still surfaces via existing MP3/AAC stream playback (regression).
- [ ] 6.9  Commit C6.

## Phase 7 — Detection routing integration (commit C7)

- [ ] 7.1  In `MetadataLoader.swift` (169 lines at HEAD), branch `loadTrackMetadata(from:)` on `.ogg`/`.oga`.
- [ ] 7.2  Add `loadVorbisMetadata(url:) async -> TrackMetadata` — opens VorbisDecoder seekable, reads `ovComment` + `ovInfo` + `ovPCMTotal`, closes.
- [ ] 7.3  Branch `loadAudioProperties(from:)` on `.ogg`/`.oga`; populate channels + sampleRate from `ovInfo`; bitrate from `vorbis_info.bitrate_nominal` or 0.
- [ ] 7.4  In `StreamDecodePipeline.formatHint(for:contentType:)` add Content-Type rules: `audio/ogg`, `application/ogg`, `audio/vorbis` → `.ogg`; `.ogg`/`.oga` ext → `.ogg`.
- [ ] 7.5  In `handleHTTPResponse`, extract Content-Type, compute `StreamFormatHint`, forward to `DecodeContext.setHint(_:)` BEFORE first data byte ordering preserved by existing `onResponse → decodeQueue.async` pattern.
- [ ] 7.6  Manual verify: `.audio` UTType already includes `.ogg` in file picker; if not, add `UTType(filenameExtension: "ogg")` and `"oga"` to `PlaylistWindowActions.swift:60`.
- [ ] 7.7  Manual verify: drag-drop `.ogg`/`.oga` files into playlist works.
- [ ] 7.8  Build + tests.
- [ ] 7.9  Commit C7.

## Phase 8 — Tests (commit C8)

- [ ] 8.1  Add fixtures under `Tests/MacAmpTests/Fixtures/Vorbis/` (commit binaries; small total).
- [ ] 8.2  `tone-440hz-q5.ogg`, `chained-2streams.ogg`, `chained-rate-change.ogg`, `mono.ogg`, `5_1.ogg`, `truncated.ogg`.
- [ ] 8.3  Sniff fixtures: `vorbis-bos.bin`, `opus-bos.bin`, `flac-bos.bin`, `speex-bos.bin`, `theora-bos.bin`, `notogg.bin`.
- [ ] 8.4  Optional `Scripts/fetch-vorbis-fixtures.sh` regenerates from WAV.
- [ ] 8.5  Create `Tests/MacAmpTests/VorbisDecoderTests.swift`.
- [ ] 8.6  T1: tone decode → 44100±100 frames + 440 Hz peak (FFT).
- [ ] 8.7  T2: Vorbis Comments TITLE + ARTIST extraction.
- [ ] 8.8  T3: Chained 2-streams → metadata fires twice.
- [ ] 8.9  T4: Chained rate-change → `.chainBoundary(48000, 2)` event emitted.
- [ ] 8.10 T5: Mono → stereo duplication.
- [ ] 8.11 T6: 5.1 → stereo downmix, no clipping (peak ≤ 1.0).
- [ ] 8.12 T7: Truncated input → `.error` after EOF, no crash.
- [ ] 8.13 T8: OggCodecSniffer per-codec correctness.
- [ ] 8.14 T9: 7 KB random bytes → `.notOgg`.
- [ ] 8.15 T10: 8.5 KB OggS-prefixed garbage → `.overshoot` after deadline.
- [ ] 8.16 T11: StreamBackend integration with pre-recorded ~10 s Vorbis stream snippet.
- [ ] 8.17 T12: Sniff replay (split feed) produces identical PCM to single-feed.
- [ ] 8.18 T13: Pre-recorded chained stream triggers `DecodeContext.onChainFormatChange` exactly once at the rate-change boundary.
- [ ] 8.19 T13b: **Full coordinator bridge retune harness** — `chained-rate-change.ogg` fed to `StreamDecodePipeline` triggers `StreamPlayer.onStreamChainFormatChanged` → `PlaybackCoordinator` deactivates+activates bridge → `setAudioWorkgroup` re-passed with non-nil workgroup. Verifies full plumbing.
- [ ] 8.20 T14: Local-file play / pause / seek / completion via `VorbisFileSource`.
- [ ] 8.21 T14b: Producer-thread invariant — assert no libvorbis call occurs inside `scheduleBuffer` completion handler context (capture thread-id sentinel in producer queue, assert ≠ completion-handler thread-id).
- [ ] 8.22 T15: TSan green.
- [ ] 8.23 Live-station spot-check table populated (5 stations × ≥ 5 minutes each).
- [ ] 8.24 Commit C8.

## Phase 9 — Binary size measurement (commit C9, append to research)

- [ ] 9.1  Build release on `main` HEAD (pre-OGG): record `du -sh`, `lipo -archs`, `size -m | grep __TEXT` for arm64 and x86_64.
- [ ] 9.2  Build release on `feat/ogg-vorbis-support` post-Phase 1 (or post-C8 — same vendoring): same metrics.
- [ ] 9.3  Append "Binary Size Delta" table to `research.md`.
- [ ] 9.4  Confirm delta ≤ 500 KB stripped (target). If > 1 MB, investigate static-archive flags before continuing.
- [ ] 9.5  Commit C9 (research-only; no code).

---

## PR + Oracle gate

- [ ] PR.1  All tests + manual checks per plan §17 pass.
- [ ] PR.2  Oracle code review of full diff (`gpt-5.5`, `xhigh`) ≥ 9/10. Iterate up to 4 rounds.
- [ ] PR.3  Append "Oracle Code Review Summary" to `research.md`.
- [ ] PR.4  Open PR #E with summary referencing this plan + research.md.
- [ ] PR.5  Update `tasks/_context/state.md` S3 table: ogg row → "PR open".
- [ ] PR.6  After merge: move `tasks/ogg-vorbis-support/` → `tasks/done/ogg-vorbis-support/`.
- [ ] PR.7  Update `tasks/_context/state.md` S3 table: ogg row → "MERGED" with PR # and date.
- [ ] PR.8  Delete `feat/ogg-vorbis-support` branch.

---

## Deferred (do NOT do in this task)

- OGG Opus, OGG FLAC, OGG Speex decoders (sniffer rejects with clear error message; new tasks).
- Vorbis encoding.
- About-box link to `THIRD_PARTY_LICENSES.txt` (file ships in bundle, satisfies clause).
- Variable-bitrate display for Vorbis.
- Multichannel >2 listening (always downmix to stereo).
- HLS-Vorbis.
- `LocalPlaybackBackend` protocol redesign (only triggered if Phase 0b fails — would itself become a separate task or task abort).
