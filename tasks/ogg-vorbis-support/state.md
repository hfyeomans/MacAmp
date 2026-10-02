# State: OGG Vorbis Support

Updated: 2026-10-02

**Status:** BLOCKED (on S3-3). Plan approved (Oracle 9.3/10 in round 3; review record in `plan.md` §23). After S3-3 merges, the Phase 0a and 0b spikes are hard gates. First action after S3-3 merges: G1 in `todo.md`.

Adds OGG Vorbis decoding for local files and Icecast streams (a Winamp parity gap), and fixes the one-shot `onFormatReady` gap that chained streams expose. Sprint S3, wave S3-4, last in S3. Created 2026-03-14. Platform: arm64 only, macOS 27.

## Gates

- Predecessors: S3-1 (PR #80, #82) and S3-2 `avplayer-native-video-dsp` (PR #89) merged. S3-3 `hls-streaming-support` pending. `video-audio-engine-routing` is not a predecessor.
- Rebase on post-HLS main using `tasks/hls-streaming-support/plan.md` §17.1.2 (linked from `plan.md` §20).
- Successor: the Structure Sprint starts after this PR merges.
- Owner decision pending (todo G1b; listed in `tasks/_context/state.md`, Owner decisions pending): run the 5-station live OGG spot-check before vendoring, or accept the risk.

## Branches and PR

- `feat/ogg-vorbis-support` (implementation), plus throwaway `spike/ogg-build-wiring` (Phase 0a) and `spike/ogg-local-playback` (Phase 0b). None exist yet.
- PR number is assigned when the PR opens.
- Review gate: one exhaustive `/codex:review --base main` before the PR. The owner merges and deletes the branch (GH013 blocks CLI deletion).

## Key decisions

Detail and rationale live in `plan.md`.

| # | Decision |
|---|----------|
| 1 | Decoder: libvorbis + libogg; chained-stream support is required for Icecast. stb_vorbis ruled out for its chained-stream gap. |
| 2 | Local files: Path A-revised, chained `playerNode.scheduleBuffer` on the existing `AVAudioPlayerNode`, keeping transport contracts. |
| 3 | Streams: a fileprivate `StreamBackend` enum inside `StreamDecodePipeline.swift`, not a protocol; `DecodeContext` keeps all queue-confined state. |
| 4 | Sniff-then-decode lifecycle: Connecting → Sniffing → DecoderSelected → Buffering → Playing, buffering to the first complete BOS page (8 KB cap, 250 ms timeout). |
| 5 | `ICYMetadata` becomes a top-level `StreamMetadata`; ICY and Vorbis comments are adapters. |
| 6 | One decode-queue `formatReadyFired` gate; `onChainFormatChange` → `onStreamChainFormatChanged` → `PlaybackCoordinator` deactivates, re-activates and re-passes the workgroup. T13b verifies the plumbing. |
| 7 | `VorbisDecoder` has an immutable `Mode` sum type (`.stream` / `.seekableFile`) with disjoint state and per-method preconditions. |
| 8 | arm64 only on macOS 27. `project.yml` never set `ARCHS`; there is no universal-build requirement. |
| 9 | `scheduleBuffer` completion handlers never decode; a dedicated producer queue owns all libvorbis calls. |
| 10 | Phases 0a and 0b are hard gates: 0a fails → xcframework fallback; 0b fails → escalate, possibly abort. |
| 11 | C1 (on the feature branch, not the spike) deletes the root `Package.swift`, `Package.resolved` and the `.swiftlint.yml` exclude, and pins exact package versions in `project.yml` (`plan.md` §6). Fallback slot: S4-1. |

## Files

Estimate: ~1000 LOC new Swift, ~250 modified, ~3 MB vendored C, ~30 KB fixtures.

- Vendored C: one local package, `Vendor/COggVorbis` (`Cogg` and `Cvorbis` targets), wired through `project.yml`. Only the license files live in `Vendor/libogg/` and `Vendor/libvorbis/`.
- New Swift: `Audio/Vorbis/` (`VorbisDecoder`, `OggCodecSniffer`, `VorbisFileSource`), `Audio/Streaming/StreamMetadata.swift`, `Tests/MacAmpTests/VorbisDecoderTests.swift` plus fixtures.
- Modified (line counts at `b3894d9`; "HLS" marks files S3-3 also edits):

| File | Lines |
|------|------:|
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` (HLS) | 825 |
| `MacAmpApp/Audio/StreamPlayer.swift` (HLS) | 714 |
| `MacAmpApp/Audio/AudioEngineController.swift` | 580 |
| `MacAmpApp/Audio/AudioPlayer.swift` | 1101 |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` | 587 |
| `MacAmpApp/Audio/Streaming/ICYFramer.swift` | 200 |
| `MacAmpApp/Audio/MetadataLoader.swift` | 169 |
| `MacAmpApp/Views/PlaylistWindowActions.swift` (optional) | 318 |
| `project.yml`, `.swiftlint.yml`; root `Package.swift` and `Package.resolved` deleted | — |

`StreamDecodePipeline.swift` is already past its growth trigger, and HLS and OGG both add to it (projection in `tasks/_context/research.md`, Fired growth triggers). Both plans forbid splitting it; SS-2 re-evaluates it.
