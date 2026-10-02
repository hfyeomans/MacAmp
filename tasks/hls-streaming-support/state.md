# State: HLS Streaming Support

Updated: 2026-10-02

**Status:** NEXT. Plan approved (Oracle 9.0/10 in round 4; review record in `plan.md` §19). Implementation not started. First action: PF.3 in `todo.md`.

Adds audio-only HLS (M3U8 master/media playlists, AAC ADTS segments, live + VOD) to the stream decode pipeline. Sprint S3, wave S3-3. Created 2026-03-14.

**Today:** an HLS URL goes through the legacy M3U path, plays its first ~6 s segment, reports `serverClosed`, and reconnect-loops.

## Gates

- Predecessors merged: S3-1B `stream-pause-tail` (PR #82, `b60fd57`) and S3-2 `avplayer-native-video-dsp` (PR #89, `ae15f5c`). `video-audio-engine-routing` is paused as reference and is not a predecessor.
- Recommended, not required: the owner merges PR #91 (`chore/amp-review-dead-code`) first so the branch starts from the cleaned main.
- Successor: S3-4 `ogg-vorbis-support` rebases on post-HLS main using `plan.md` §17.1.2.

## Branch and PR

- Branch `feat/hls-streaming-support`, cut from main at PF.4 (does not exist yet). No spike.
- PR number is assigned when the PR opens.
- Review gate: one exhaustive `/codex:review --base main` before the PR. The owner merges and deletes the branch (GH013 blocks CLI deletion).

## Key decisions

Detail and rationale live in `plan.md`.

| # | Decision |
|---|----------|
| 1 | v1 scope: AAC ADTS only; master + media playlists; live + VOD. No MPEG-TS, fMP4, LL-HLS, ABR, DRM or HLS video. |
| 2 | Integration Option A: `HLSSegmentFeeder` feeds bytes to `DecodeContext.handleIncomingData` through an injected `@Sendable (Data) -> Void` closure; no visibility widening. |
| 3 | Two new non-reconnectable `StreamTerminationReason` cases: `.streamFinished` (VOD end) and `.unsupportedFormat` (DRM, fMP4, no audio variant). |
| 4 | New `MacAmpApp/Audio/HLS/` folder, separate from `Audio/Streaming/`. |
| 5 | Two orthogonal stale-callback tokens: `pipelineGeneration` and the feeder's `pauseEpoch`. |
| 6 | The feeder reads the generation through an `OSAllocatedUnfairLock<UInt64>` snapshot, never `MainActor.assumeIsolated`. |
| 7 | `AudioFileStreamParser.reset()` plus a post-reset ASBD (incl. `mFormatFlags`) and magic-cookie compare; a mismatch sets `parserFatalState` and is a fatal decode error, not a decoder swap. |
| 8 | HLS pause plugs into S3-1B's `pauseByUser`/`resumeByUser`; v1 re-fetches the playlist and calls `parser.reset()` on resume. |
| 9 | No `StreamFormatHint` enum here; S3-4 OGG introduces it as the third codec. |
| 10 | `ClassifyError` mapping is fixed where the error is built: malformed HLS maps to `.unsupportedFormat`, malformed legacy playlist to `.playlistResolutionFailed`. |

## Files

New (~750-1000 LOC): `MacAmpApp/Audio/HLS/M3U8Parser.swift` (~225), `MacAmpApp/Audio/HLS/HLSSegmentFeeder.swift` (~350), `Tests/MacAmpTests/HLSStreamingTests.swift` (~300).

Modified (line counts at `b3894d9`):

| File | Lines | Planned delta |
|------|------:|---------------|
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | 825 | +~160 / -10 |
| `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` | 186 | +~40 (`reset()` plus the ASBD/cookie compare and `parserFatalState`) |
| `MacAmpApp/Audio/StreamPlayer.swift` | 714 | +~12 (optionally minus the two unused DEBUG seams, P6.3b) |

`StreamDecodePipeline.swift` is already past its 800-line growth trigger (projection after HLS and OGG in `tasks/_context/research.md`, Fired growth triggers). The plan forbids splitting it here; SS-2 re-evaluates it.

## Open calls during implementation

- `parser.reset()` per segment or only on `EXT-X-DISCONTINUITY` (todo P8.9).
- Gemini re-run only if implementation raises a question the plan does not answer (plan §4).
