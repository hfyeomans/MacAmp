# Todo: OGG Vorbis Support

Updated: 2026-10-02

> **Source:** `plan.md` §4–§22.
> **Branch (impl):** `feat/ogg-vorbis-support`. Spike branches throwaway: `spike/ogg-build-wiring`, `spike/ogg-local-playback`.
> **Predecessors:** S3-1 (PR #80, #82) and S3-2 `avplayer-native-video-dsp` (PR #89) merged; S3-3 `hls-streaming-support` must merge before G1.
> **Platform:** arm64 only, macOS 27.

---

## Pre-implementation gates

- [x] **Gate G0:** Oracle plan validation ≥ 9/10: 9.3/10 in round 3 (reviewer `gpt-5.3-codex`, xhigh, per plan §23).
- [ ] **Gate G1:** After S3-3 merges, re-read every file in plan §15 at HEAD and refresh the plan's anchors (refreshed at `b3894d9`; S3-3 and PR #91 will shift them). No code. The HLS hand-off below is applied later, as the first work on `feat/ogg-vorbis-support` (Gate G6).
  1. Retype the HLS `makeStreamMetadata` factory to return `StreamMetadata`.
  2. Convert the HLS `formatHint = kAudioFileAAC_ADTSType` line to `.audioFileStream(kAudioFileAAC_ADTSType)`.
  3. Fit HLS `DecodeContext` init into `PipelineLifecycle` (`buffering → playing`, like MP3/AAC progressive).
  4. Confirm HLS does not subscribe to `onChainFormatChange` (HLS rejects mid-stream format changes).
  5. Run the HLS tests and add an HLS-after-OGG integration test.
  - Re-derive the map in `tasks/_context/research.md` (File-conflict map) at HEAD.
- [ ] **Gate G1b (owner call):** Run the 5-station live OGG spot-check before Phase 1 (chain frequency, sample rate and channels per station; research Oracle finding 7; plan §13 table holds assumed values only), or record the risk as accepted. Either way, fold the open Gemini re-run (2026 OGG station prevalence, stb_vorbis chaining) into it or drop it explicitly. The result also answers whether OGG is still worth doing.
- [ ] **Gate G2:** Phase 0a spike PASS — `Cogg`/`Cvorbis` smoke build links + runs on arm64 with TSan, smoke fn returns 42.
- [ ] **Gate G3:** Phase 0b spike PASS — chained `scheduleBuffer` reproduces play / pause / seek / progress / completion semantics on a non-Vorbis WAV; TSan clean on macOS 27.
- [ ] **Gate G4:** Append "Phase 0a Spike Result" + "Phase 0b Spike Result" sections to `research.md` with build output, decision, and SHAs.
- [ ] **Gate G5:** Delete throwaway spike branches after results recorded.
- [ ] **Gate G6:** Cut `feat/ogg-vorbis-support` from `main`, then apply the HLS hand-off in `tasks/hls-streaming-support/plan.md` §17.1.2 (steps 1-5 listed under G1) before Phase 1.

> **HARD STOP:** if G2 fails AND xcframework fallback also fails → close task per §19 top-level kill switch. If G3 fails → abort task; document in `tasks/done/ogg-vorbis-support/lessons.md`.

---

## Phase 0a — Build-wiring spike (`spike/ogg-build-wiring`, throwaway)

- [ ] 0a.1  Create `Vendor/COggVorbis/Package.swift` (`swift-tools-version: 6.2`, `.macOS("27.0")`, matching the project's language-mode and deployment-target decisions) declaring `Cogg` + `Cvorbis` cTargets, with `Cvorbis.dependencies = [.target(name: "Cogg")]`.
- [ ] 0a.2  Add `Cogg/include/ogg/og_types_smoke.h` defining `typedef int32_t ogg_int32_t;` and `Cogg/Sources/og_smoke.c` containing `#include "ogg/og_types_smoke.h"\nint og_smoke(void){ ogg_int32_t v = 42; return (int)v; }`.
- [ ] 0a.3  Add `Cvorbis/include/vorbis/vb_smoke.h` declaring `int vb_smoke(void);` and `Cvorbis/Sources/vb_smoke.c` containing both `#include "vorbis/vb_smoke.h"` and `#include "ogg/og_types_smoke.h"` plus `int vb_smoke(void){ return og_smoke(); }`. This proves Cvorbis→Cogg link AND transitive header resolution.
- [ ] 0a.4  Add module map per target (`include/module.modulemap`) declaring umbrella headers.
- [ ] 0a.5  Add `packages: COggVorbis: { path: ./Vendor/COggVorbis }` to `project.yml`.
- [ ] 0a.6  Add `package: COggVorbis, product: Cogg` and `Cvorbis` under `targets.MacAmp.dependencies`.
- [ ] 0a.7  `xcodegen generate`.
- [ ] 0a.8  Add temporary `MacAmpApp/Audio/_OggSmoke.swift` containing `import Cogg; import Cvorbis; let _ = og_smoke(); let _ = vb_smoke()`.
- [ ] 0a.9  `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — clean, both `og_smoke` and `vb_smoke` resolved.
- [ ] 0a.10 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — green.
- [ ] 0a.11 Record `lipo -archs $BUILD/MacAmp` (arm64 expected).
- [ ] 0a.12 Append "Phase 0a Spike Result" to `research.md`.
- [ ] 0a.13 Decide Option 1 confirmed OR Option 2 fallback. If fallback, re-plan §6.
- [ ] 0a.14 Delete `spike/ogg-build-wiring`. Carry forward only the `project.yml` packages entry + `Vendor/COggVorbis/Package.swift` skeleton (smoke files removed in C1). The root `Package.swift` deletion is not part of the spike; it lands in C1 (1.9b).

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
- [ ] 0b.10 V0b.6 — TSan clean on macOS 27.
- [ ] 0b.11 Append "Phase 0b Spike Result" to `research.md` with V0b.1–V0b.6 outcomes.
- [ ] 0b.12 Pass → continue. Fail (drift, miscount, race) → escalate; consider abort per §19.
- [ ] 0b.13 Delete `spike/ogg-local-playback`. No code carried forward.

---

## Phase 1 — Vendor libogg + libvorbis (commit C1)

- [ ] 1.1  Vendor `libogg-1.3.5/src/{bitwise,framing}.c` + `include/ogg/*.h` under `Vendor/COggVorbis/Sources/Cogg/`.
- [ ] 1.2  Vendor `libvorbis-1.3.7/lib/*.c` (excluding `vorbisenc.c`) + `include/vorbis/*.h` under `Vendor/COggVorbis/Sources/Cvorbis/`.
- [ ] 1.3  Generate `config_types.h` for arm64 macOS (`ogg_int16_t = int16_t`, etc.) and place under `Cogg/include/ogg/`.
- [ ] 1.4  Add `Vendor/libogg/LICENSE.txt` + `Vendor/libvorbis/LICENSE.txt` (verbatim Xiph BSD).
- [ ] 1.5  Update `Vendor/COggVorbis/Package.swift` to reference real sources + headers; remove smoke files.
- [ ] 1.6  Wire `Cvorbis.dependencies = [.target(name: "Cogg")]` and `linkerSettings: [.linkedLibrary("m")]`.
- [ ] 1.7  Set `Cvorbis` `cSettings: [.headerSearchPath("include"), .headerSearchPath("lib")]`.
- [ ] 1.8  Create `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` containing both Xiph BSD notices.
- [ ] 1.9  Add `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` to `project.yml` `targets.MacAmp.resources`.
- [ ] 1.9b Delete the root `Package.swift` and `Package.resolved`, and the `Package.swift` entry under `excluded:` in `.swiftlint.yml` (rationale in plan §6). If this cannot land in C1, it falls back to S4-1.
- [ ] 1.9c Pin exact versions in `project.yml`: `ZIPFoundation` `exactVersion: 0.9.20`, `swift-atomics` `exactVersion: 1.3.0` (what both lockfiles resolve at `b3894d9`; re-check at C1). Root `Package.resolved` is the only tracked lockfile because `MacAmpApp.xcodeproj` is gitignored.
- [ ] 1.10 `xcodegen generate`.
- [ ] 1.11 `xcodebuildmcp macos build --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — clean (no warnings about modulemap clashes).
- [ ] 1.12 `xcodebuildmcp macos test  --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all pre-task tests still green; record baseline count in C1 commit message.
- [ ] 1.13 Verify `MacAmp.app/Contents/Resources/THIRD_PARTY_LICENSES.txt` is in the bundle.
- [ ] 1.14 Commit C1: "feat(ogg): vendor libogg+libvorbis, add Xiph license notice"; the body names the root `Package.swift`/`Package.resolved` removal and the version pins.

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
- [ ] 2.16b Document the Release-build confinement gap that `VorbisDecoder` inherits: `AudioConverterDecoder.clearQueue` relies on `assertConfinement()` (`AudioConverterDecoder.swift:139-140`), which is Debug-only (`QueueConfined.swift:12`).
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

> **Touches:** `StreamDecodePipeline.swift` (825 lines at `b3894d9`, plus HLS). Verify line numbers before editing.

- [ ] 4.1  In `StreamDecodePipeline.swift`, declare `fileprivate enum StreamBackend { case audioFileStream(AudioFileStreamParser, AudioConverterDecoder?); case oggVorbis(VorbisDecoder) }`.
- [ ] 4.2  Declare `fileprivate enum PipelineLifecycle { case connecting, sniffing, decoderSelected, buffering, playing }`.
- [ ] 4.3  Declare `fileprivate enum StreamFormatHint { case audioFileStream(AudioFileTypeID), ogg, unknown }`.
- [ ] 4.4  Replace `formatHint(for: URL) -> AudioFileTypeID` with `formatHint(for: URL, contentType: String?) -> StreamFormatHint`.
- [ ] 4.5  Modify `DecodeContext` — remove eager parser init; add `lifecycle`, `sniffer`, `formatHint`, `backend`, `detectedChannels`.
- [ ] 4.6  Add `setHint(_:)` queue-confined on `DecodeContext`; wire from `handleHTTPResponse` (MainActor) via `decodeQueue.async`.
- [ ] 4.7  `handleIncomingData` rewritten as state-machine dispatch.
- [ ] 4.8  `.sniffing` → feed `OggCodecSniffer`; on `.identified(.vorbis, buffered)` → instantiate `VorbisDecoder`, feed buffered bytes BEFORE new bytes; on other identified codecs → `decodeError("OGG <codec> not supported")`; on `.notOgg(buffered)` → instantiate `AudioFileStreamParser`, replay buffered bytes; on `.overshoot` → `decodeError`.
- [ ] 4.9  `.decoderSelected` / `.buffering` → drain backend; emit format-ready / metadata / PCM events.
- [ ] 4.10 **Collapse dual format-ready gate to ONE source of truth**: remove `StreamDecodePipeline.formatReadyFired` (the @MainActor copy at line 104; its guard is at :157); `DecodeContext.formatReadyFired` becomes the single gate. The `onFormatReady` MainActor closure body becomes idempotent against duplicate same-sample-rate fires (compare-and-skip).
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
- [ ] 5.6  In `AudioEngineController.swift` (580 lines at `b3894d9`), add `fileprivate enum LocalAudioSource { case avAudioFile(AVAudioFile); case vorbis(VorbisFileSource) }`.
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
- [ ] 5.18 In `AudioPlayer.swift` (1101 lines at `b3894d9`), replace the 4 `engine.audioFile != nil` sites (`:628`, `:791`, `:808`, `:927`) with `engine.hasLoadedSource`; re-check at HEAD.
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
- [ ] 6.5  In `StreamPlayer.swift` (714 lines at `b3894d9`), update the `pipeline.onMetadata` closure parameter type (`:323`).
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
- [ ] 8.4  Optional `scripts/fetch-vorbis-fixtures.sh` regenerates from WAV.
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
- [ ] 8.23 Live-station playback gate: 5 stations × ≥ 5 minutes each (plan §13), using the G1b stations if that check ran.
- [ ] 8.24 Commit C8.

## Phase 9 — Binary size + leak check (commit C9, append to research)

- [ ] 9.1  Build release on `main` HEAD (pre-OGG): record `du -sh`, `lipo -archs` and `size -m | grep __TEXT` for each slice present.
- [ ] 9.2  Build release on `feat/ogg-vorbis-support` post-Phase 1 (or post-C8 — same vendoring): same metrics.
- [ ] 9.3  Append "Binary Size Delta" table to `research.md`.
- [ ] 9.4  Confirm delta ≤ 500 KB stripped (target). If > 1 MB, investigate static-archive flags before continuing.
- [ ] 9.4b Instruments decoder-lifecycle leak check (`VorbisDecoder`, `VorbisFileSource`) per `tasks/_context/instruments-allocations-workflow.md`: Debug build (Allocations needs dylib injection, which hardened builds block); filter Recorded Types with `MacAmp.`, not `MacAmpApp.` (matches nothing, false PASS).
- [ ] 9.5  Commit C9 (research-only; no code).

---

## PR + review gate

- [ ] PR.1  All tests + manual checks per plan §17 pass. A manual-gate FAILURE means an ADR amendment in `plan.md` §22 plus a targeted retry, never a soft-skip; NOT ABLE with a stated reason is acceptable.
- [ ] PR.2  One exhaustive `/codex:review --base main`; fix findings that affect correctness or requirements. Before any second round, tell the owner what it would chase and roughly what it costs.
- [ ] PR.3  Record the review outcome in `state.md`: what was fixed, one line per finding left open.
- [ ] PR.3b (optional) Add an About-box link to `THIRD_PARTY_LICENSES.txt` (`tasks/_context/deferred.md`, S3-4).
- [ ] PR.4  Push and `gh pr create` with a summary referencing `plan.md` + `research.md`; record the PR number in `state.md`. Then stop.
- [ ] PR.5  Update the Open PR and Active work rows in `tasks/_context/state.md` (Snapshot).
- [ ] PR.6  The owner merges and deletes `feat/ogg-vorbis-support` on GitHub (GH013 blocks CLI deletion).
- [ ] PR.7  Close out per `tasks/_context/resume-prompt.md` step 8: task `state.md` MERGED; `git mv tasks/ogg-vorbis-support tasks/done/`; add the Shipped row to `tasks/_context/state.md`; update `_context` plan, todo, deferred, tasks_index (move the row, recount `done/`) and resume-prompt. Repoint the decision lines that cite the root `Package.swift` (swift-tools-version, deployment target) to `Vendor/COggVorbis/Package.swift`, and name that manifest in the S4-1 language-mode ADR scope.
- [ ] PR.8  Hand off to the Structure Sprint (SS-0 planning).

---

Out of scope: plan §2 non-goals (Vorbis encoding, >2-channel output, HLS-Vorbis, Theora, pure-Swift port) and the deferred items in `tasks/_context/deferred.md` (OGG Opus/FLAC/Speex decoders, real-time VBR display). A `LocalPlaybackBackend` redesign arises only if Phase 0b fails (plan §19).
