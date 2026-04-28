# Todo: HLS Streaming Support

> Implementation checklist derived from `plan.md`. Each item is a discrete, verifiable unit of work.
> Sprint S3 wave S3-3. Branch `feat/hls-streaming-support`. PR #D.
> **Predecessors:** S3-1B `stream-pause-tail` AND S3-2 `video-audio-engine-routing` must be merged first.

---

## Pre-flight

- [ ] **PF.1** Confirm S3-1B (stream-pause-tail, PR #B) merged to main
- [ ] **PF.2** Confirm S3-2 (video-audio-engine-routing, PR #C) merged to main
- [ ] **PF.3** Re-read at HEAD: `StreamDecodePipeline.swift`, `StreamPlayer.swift`, `AudioFileStreamParser.swift` — note any line drift vs research §Appendix
- [ ] **PF.4** `git checkout -b feat/hls-streaming-support`
- [ ] **PF.5** Create folder `MacAmpApp/Audio/HLS/`
- [ ] **PF.6** Confirm Oracle plan score ≥ 9/10 (this plan), all findings dispositioned in plan.md §19

## Phase 1 — `M3U8Parser.swift`

- [ ] **P1.1** Write file `MacAmpApp/Audio/HLS/M3U8Parser.swift` with `Playlist`, `MasterPlaylist`, `MediaPlaylist`, `Variant`, `Segment`, `ParseFailure` types per plan §5.1
- [ ] **P1.2** Implement `parse(_ body: String, baseURL: URL) -> Result<Playlist, ParseFailure>`
- [ ] **P1.3** Implement single-pass tag scan (per plan §5.2): magic check, master/media disambiguation, encrypted/fMP4/byterange/i-frame-only rejection
- [ ] **P1.4** Implement attribute parser (CSV with quoted values) for `EXT-X-STREAM-INF`
- [ ] **P1.5** Implement `EXTINF` duration+title parsing
- [ ] **P1.6** Implement `EXT-X-DISCONTINUITY` flag-on-next-segment tracking
- [ ] **P1.7** Implement audio-only variant heuristic (`mp4a` codec + no `avc/hvc/hev`; `RESOLUTION == nil` fallback)
- [ ] **P1.8** Implement parser-side robustness: ignore unknown `#EXT-…`, handle BOM / CRLF / leading whitespace (Latin-1 fallback is a *caller* responsibility, NOT parser — see plan §5.2; M3U8Parser API takes `String`)
- [ ] **P1.9** Implement >1 MB body rejection — return `.malformed("playlist too large")`
- [ ] **P1.10** Add unit tests `Tests/MacAmpTests/HLSStreamingTests.swift` — M3U8Parser cases (17 enumerated in plan §5.3)
- [ ] **P1.11** `xcodegen generate`
- [ ] **P1.12** `xcodebuildmcp macos test --json '{"extraArgs":["-enableThreadSanitizer","YES"]}'` — all parser tests green
- [ ] **P1.13** Commit: `feat(audio/hls): add M3U8Parser (master + media playlists, AAC-only)`

## Phase 2 — `AudioFileStreamParser.reset()` + post-reset ASBD compare

- [ ] **P2.1** Add `reset()` method to `AudioFileStreamParser.swift` (plan §6.1)
- [ ] **P2.2** Preserve `formatHint` and `selfPtr` across reset
- [ ] **P2.3** Re-wire property listener and packets callbacks after reopen
- [ ] **P2.4** Surface reopen failure via `onError` (non-reconnectable)
- [ ] **P2.5** Add `previousInputFormat: AudioStreamBasicDescription?` AND `previousMagicCookie: Data?` fields. On post-reset DataFormat callback, compare against previous: `(mFormatID, mSampleRate, mChannelsPerFrame, mFramesPerPacket, mBitsPerChannel, mFormatFlags)` AND magic-cookie content (read via `kAudioFileStreamProperty_MagicCookieData`). Plan §6.3.
- [ ] **P2.6** Add `parserFatalState: Bool` field. On any compared-field mismatch: fire `onError("HLS segment format changed mid-stream (decoder swap not supported in v1)")` AND set `parserFatalState = true`.
- [ ] **P2.7** Short-circuit subsequent C-callbacks while `parserFatalState == true`: in `propertyListenerCallback` and `packetsCallback`, early-return at the boundary; in `parse(_:)`, early-return without invoking `AudioFileStreamParseBytes`.
- [ ] **P2.8** Add unit tests: reset on fresh parser (no-op), reset on open parser (continues to deliver packets), reset preserves format hint, reset+matching ASBD+matching cookie (no error), reset+mismatched ASBD `mFormatFlags` (e.g. AAC-LC → AAC-HE) → `onError` fired, reset+matching ASBD but mismatched cookie → `onError` fired, post-error `parse(_:)` is no-op (plan §6.5)
- [ ] **P2.9** TSan clean: build + test
- [ ] **P2.10** Commit: `feat(audio): add AudioFileStreamParser.reset() for HLS discontinuity flush`

## Phase 3 — `HLSSegmentFeeder.swift`

- [ ] **P3.1** Write file `MacAmpApp/Audio/HLS/HLSSegmentFeeder.swift`. Type signature per plan §7.1
- [ ] **P3.2** Implement `feederQueue` (serial DispatchQueue) and `@unchecked Sendable` confinement
- [ ] **P3.3** Implement `HLSURLSessionAdapter` protocol + `HLSURLSessionLiveAdapter` (production) per plan §7.6.1 — own URLSession, NOT `URLSession.shared`
- [ ] **P3.4** Implement `SessionDelegateProxy` mirror `fileprivate` to feeder (used by LiveAdapter)
- [ ] **P3.5** Implement `start()` → PARSE_INITIAL state machine (plan §7.2)
- [ ] **P3.6** Implement variant selection (plan §7.3)
- [ ] **P3.7** Implement RFC 8216 §6.3.4 refresh logic (plan §7.4) using `DispatchSourceTimer` (NOT `Task.sleep` — avoids leaks)
- [ ] **P3.8** Implement sequence diff (new segments by sequence, backward-jump handling)
- [ ] **P3.9** Implement segment download serial loop with format validation (plan §7.5: extension + Content-Type + ADTS-sync sniff)
- [ ] **P3.10** Implement BOTH gates before every `feedAudio` invocation:
  - Generation gating (`getPipelineGeneration() == capturedGeneration`) — rejects callbacks across pipeline restart (plan §7.8)
  - Pause-epoch gating (`pauseEpoch == taskEpoch`) — rejects callbacks across pause/resume cycles within the same pipeline lifetime (plan §8.5.1 invariant section)
  - Both checks must pass; either failure drops the bytes silently
- [ ] **P3.10b** Implement `pauseEpoch: UInt64` field (feederQueue-confined); increment in `pauseByUser` AND in `resumeByUser`; capture as `taskEpoch` at every segment task creation (plan §8.5.1)
- [ ] **P3.11** Implement `EXT-X-DISCONTINUITY` → `onParserReset` between segments (plan §7.5 step 4)
- [ ] **P3.12** Implement `EXTINF` title best-effort emission (plan §7.9)
- [ ] **P3.13** Implement `cancel()` (plan §7.7) — atomic flag, drop pending, `adapter.invalidateAndCancel()`, cancel timer
- [ ] **P3.14** Implement `FeederTermination` enum and termination paths (plan §7.1, revised in §9.1)
- [ ] **P3.15** Implement `pauseByUser(completion:)` and `resumeByUser(completion:)` per plan §8.5.1 — feeder-side network quiesce + parser-reset on resume per §8.5.2
- [ ] **P3.16** Add `HLSURLSessionStubAdapter` (test target only)
- [ ] **P3.17** Add unit tests: 11 cases enumerated in plan §7.10 + 1 case for pause/resume integration
- [ ] **P3.18** TSan clean: build + test (especially the cancel/restart and pause/resume cases)
- [ ] **P3.19** Commit: `feat(audio/hls): add HLSSegmentFeeder (variant pick, live refresh, generation-gated)`

## Phase 4 — Detection integration in `StreamDecodePipeline`

- [ ] **P4.1** Add 2 new `StreamTerminationReason` cases: `.streamFinished`, `.unsupportedFormat(String)` (plan §8.1)
- [ ] **P4.2** Add `OSAllocatedUnfairLock<UInt64>` generation snapshot field (plan §8.3.1)
- [ ] **P4.3** Add `updateGenerationSnapshot()` method; call at every site that mutates `generation` (`start(...)` and `stopInternal()` at minimum)
- [ ] **P4.4** Add `isLikelyM3UDialect(_:)` private static helper
- [ ] **P4.5** Add `classifyM3UDialect(_:)` private static async method (fetch + sniff, returns `ClassifyOutcome`)
- [ ] **P4.6** Implement `ClassifyError` and its mapping (plan §9.1 ClassifyError mapping table)
- [ ] **P4.7** Add `hlsFeeder: HLSSegmentFeeder?` field
- [ ] **P4.8** Add `fileprivate makeStreamMetadata(...)` factory (plan §17.1.1.A) — single line for OGG rebase
- [ ] **P4.9** Update `start(url:ringBuffer:)` to route `.m3u8`/`.m3u` through `classifyM3UDialect` first (plan §8.2)
- [ ] **P4.10** Add `startHLSStream(playlistURL:prefetchedBody:ringBuffer:generation:)` (plan §8.3.2)
- [ ] **P4.11** Add `DecodeContext.resetParserOnDecodeQueue()` internal method (plan §8.4)
- [ ] **P4.12** Wire feeder closures: `feedAudio`, `onParserReset`, `onMetadataTitle`, `onFinished`, `getPipelineGeneration` (plan §8.3.2)
- [ ] **P4.13** Update `stopInternal()` to cancel `hlsFeeder` (plan §8.5)
- [ ] **P4.14** Update post-S3-1B `pauseByUser()` / `resumeByUser()` to dispatch on `hlsFeeder.pauseByUser` / `resumeByUser` when feeder is present (plan §8.5.1)
- [ ] **P4.15** TSan clean: build + run existing test suite (no regressions)
- [ ] **P4.16** Commit: `feat(audio): integrate HLS detection + dispatch in StreamDecodePipeline`

## Phase 5 — Pipeline HLS termination handler

- [ ] **P5.1** Implement `handleHLSTermination(_:generation:)` (plan §9.1)
- [ ] **P5.2** Map `FeederTermination` → `StreamTerminationReason` per the table
- [ ] **P5.3** Verify `decodeContext.shutdown()` runs before terminating callbacks
- [ ] **P5.4** Test: induce each termination reason via mocked feeder, verify state + reason propagate to `onTermination`
- [ ] **P5.5** Commit: `feat(audio): map HLS feeder termination to StreamTerminationReason`

## Phase 6 — `StreamPlayer` reconnect + user-message updates

- [ ] **P6.1** Extend `StreamPlayer.isReconnectable(_:)` switch with `.streamFinished` (false), `.unsupportedFormat` (false) (plan §10.1)
- [ ] **P6.2** Extend `StreamTerminationReason.userMessage` switch (plan §9.2): `.streamFinished` → "Stream ended", `.unsupportedFormat(let msg)` → msg
- [ ] **P6.3** Verify legacy paths unchanged: progressive MP3/AAC streams behave identically
- [ ] **P6.4** Commit: `feat(audio): map HLS termination to reconnect policy + user messages`

## Phase 7 — Tests (final pass)

- [ ] **P7.1** Verify all M3U8Parser tests pass (P1.10)
- [ ] **P7.2** Verify all HLSSegmentFeeder tests pass (P3.16)
- [ ] **P7.3** Add end-to-end smoke test gated by `MACAMP_HLS_INTEGRATION=1` (plan §12.3)
- [ ] **P7.4** Verify legacy `M3UParser` tests still pass
- [ ] **P7.5** Verify `LockFreeRingBuffer` tests still pass
- [ ] **P7.6** Verify TSan clean across full test suite
- [ ] **P7.7** Commit: `test(hls): add end-to-end smoke + ensure regressions are caught`

## Phase 8 — Manual verification

- [ ] **P8.1** Smoke test 3+ live HLS stations (NPR / BBC / SomaFM-mirror or equivalent)
  - [ ] Plays within 5 s of click
  - [ ] No audible warble (would indicate boundary clicks — see kill-switch §16-2)
  - [ ] EQ slider bands respond
  - [ ] Spectrum analyzer animates
  - [ ] Balance slider pans
  - [ ] 30-min soak: no drift, no memory growth (Instruments Allocations)
  - [ ] Network flap: reconnect path engages, TSan clean
  - [ ] Stop: feeder + URLSession + ring buffer torn down (verified in logs)
- [ ] **P8.2** Regression: 3 legacy SHOUTcast/Icecast stations (MP3 + AAC) — ICY metadata, EQ, visualizer behave as today
- [ ] **P8.3** Regression: 1 legacy `.m3u` playlist file (single URL inside) — classifier routes through M3UParser → startDirectStream
- [ ] **P8.4** Regression: 1 legacy `.pls` file — routed through `resolvePlaylistURL` unchanged
- [ ] **P8.5** Regression: 5 local files (MP3, AAC, FLAC, WAV, M4A) — engine bridge sane
- [ ] **P8.6** Transition: HLS → local file → HLS — clean transitions, no `-10868`
- [ ] **P8.7** Encrypted HLS (find a test feed if possible, else skip): error message surfaces, no reconnect loop
- [ ] **P8.8** fMP4 / TS HLS (find test feeds, else skip): error message surfaces, no reconnect loop

## Phase 9 — Documentation

- [ ] **P9.1** Add "HLS audio path" subsection to `docs/MACAMP_ARCHITECTURE_GUIDE.md` §4
- [ ] **P9.2** Add "Closure-injection seam to preserve private visibility" pattern to `docs/IMPLEMENTATION_PATTERNS.md`
- [ ] **P9.3** Update `tasks/_context/tasks_index.md` — flip `hls-streaming-support` to ✅ COMPLETE on merge
- [ ] **P9.4** Update `tasks/_context/state.md` — append S3-3 outcome row
- [ ] **P9.5** Populate `placeholder.md` with deferrals discovered during implementation (likely: Content-Type promotion of non-`.m3u8`; sample-accurate HLS pause; per-segment vs per-discontinuity parser.reset() decision)
- [ ] **P9.6** Populate `depreciated.md` if any legacy code is removed (none expected)
- [ ] **P9.7** Update task `state.md` with final status and architecture diagram
- [ ] **P9.8** Commit: `docs(hls): document HLS audio path + closure-injection pattern`

## Phase 10 — Oracle code-review pass

- [ ] **P10.1** Run `mcp__codex-cli__codex` (`gpt-5.5`, `xhigh`) with all changed files attached
- [ ] **P10.2** Iterate up to 4 rounds; address all P1/P2 findings
- [ ] **P10.3** Score ≥ 9/10 OR all blockers dispositioned
- [ ] **P10.4** Append Oracle Code-Review Summary to `state.md`

## Phase 11 — PR

- [ ] **P11.1** Push branch to remote
- [ ] **P11.2** Open PR #D: `feat(audio): add HLS audio-only streaming (AAC ADTS, master+media, live+VOD)`
- [ ] **P11.3** Request CodeRabbit / Gemini-bot review
- [ ] **P11.4** Resolve all PR comments via `scripts/resolve-pr-comments.sh` workflow
- [ ] **P11.5** Merge after green CI + manual sign-off
- [ ] **P11.6** Delete branch after merge
- [ ] **P11.7** Move `tasks/hls-streaming-support/` → `tasks/done/hls-streaming-support/`

---

## Architecture constraints — verify at each commit

- [ ] All HLS code under `MacAmpApp/Audio/HLS/` ownership boundary
- [ ] No new top-level files in `Models/` or `Utilities/`
- [ ] No `private → internal` widening on existing types (closure-injection seam preserved)
- [ ] No changes to `AudioPlayer.swift` / `AudioEngineController.swift` / `PlaybackCoordinator.swift`
- [ ] No changes to `Track.swift` / `RadioStation.swift` / `M3UParser.swift`
- [ ] TSan clean every commit (no data-race warnings)
- [ ] No `// TODO` or `// FIXME` in production — track in `placeholder.md` instead
- [ ] No deprecated/legacy markers in code — track in `depreciated.md` instead
