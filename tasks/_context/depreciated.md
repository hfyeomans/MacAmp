# Depreciated

Updated: 2026-10-02

Superseded decisions and approaches, one line each, with a pointer to the record. Archived `_context` documents live in `tasks/_context/depreciated/`. Task-specific retirements stay in each task's own `depreciated.md`.

## Audio architecture

- **Dual backend** (AVAudioEngine for local files, a black-box AVPlayer for streams, Oct 2025): replaced by the Winamp in_mp3-style unified decode pipeline (#57). Record: `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`, `tasks/done/unified-audio-pipeline/`.
- **T5 Phase 2 loopback bridge** (`MTAudioProcessingTap` on streaming AVPlayerItems feeding the engine): the tap never fires for streams (QA1716); replaced by T7, the unified pipeline (#57). Record: `tasks/_context/depreciated/claude-mistakes-stream-loopback-bridge.md`.
- **CoreAudio process tap** (`AudioHardwareCreateProcessTap`) for self-capture: rejected because tapping our own process loops back and device isolation within one process is unreliable. Record: `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`, `tasks/_context/depreciated/deep-research-avplayer-bridge.md`.
- **Deep-research AVPlayer-to-engine bridge report** (2026-02-22): its conclusion, a custom decode pipeline, became T7. Two claims are wrong: taps do not work on progressive SHOUTcast/Icecast streams either, and a PAC failure crashes the process, not the kernel. Record: `tasks/_context/depreciated/deep-research-avplayer-bridge.md`.
- **Thesis "never use AVPlayer if you process its audio":** narrowed by S3-2. In-place tap DSP works for file-based AVPlayerItems such as local video and fails only for streaming items. Record: `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`.
- **Stale symbol names in the lessons archive:** `rewireForCurrentFile` is now `AudioEngineController.rewireForFile(_:)`, and `isEngineRendering` is now `isVisualizerRendering`. Record: `tasks/_context/depreciated/lessons-dual-backend-dead-end.md`.
- **LockFreeRingBuffer Loopback Bridge design** (tap-thread writer, AudioBufferList API, flush resets heads to 0): the writer is StreamDecodePipeline's decode queue (#57), the API is pointer-based, the AudioBufferList overloads were deleted in `f2ff7c3`, and heads are monotonic. Record: `tasks/done/lock-free-ring-buffer/`.
- **LockFreeRingBuffer "Known race (accepted)" on overrun:** no longer accepted; the fix is slotted to S4-1 (`deferred.md`). Record: `tasks/done/lock-free-ring-buffer/state.md`.

## Video audio (S3-2)

- **video-audio-engine-routing (vaer):** routing video audio through AVAudioEngine. Superseded on 2026-05-01 by the in-place AVPlayer tap (S3-2 `avplayer-native-video-dsp`, PR #89). Paused at Phase 7 partial; branch `feat/video-audio-engine-routing` at `5af91eb`, 44 commits ahead of `main`. The SHAs cited in its `state.md` and `todo.md` (`0a88d37`, `f34c4a0`..`d34b882`, `d5081e9`..`e7f8eed`) are orphaned pre-rebase objects; Phase 1 (the engine configuration observer) reached `main` as `ef6668d`..`0c82a7d` via PR #89. Record: `tasks/video-audio-engine-routing/`, `tasks/_context/depreciated/s3-2-pivot.md`.
- **Why vaer stopped:** `AVAudioEngineConfigurationChange` is not a macOS route-change signal; AVPlayer's audio is the video master clock, so ring under-runs stall frames; and engine-vs-AVPlayer clock drift plus a second sample-rate conversion caused artifacts. Record: `tasks/_context/depreciated/s3-2-pivot.md`, `tasks/stale/airpods-route-gate-validation/`.
- **vaer plan decisions** (4-step A/V sync ladder, a `.video` branch on `supportsAudioProcessing`, `VideoAudioTap` with `Unmanaged<Context>` callbacks, 3-path engine mutual exclusion, tap watchdog plus fallback flag): replaced by the S3-2 ADRs. Only the engine configuration observer shipped. Record: `tasks/done/avplayer-native-video-dsp/plan.md`.
- **vaer open items D.1-D.4** (fallback UI banner, watchdog cadence, auto-recovery, chapter-aware sync), its `supportsAudioProcessing` dimming for tap fallback, and the `VideoTapFallbackTests` TSan flake: tied to the abandoned approach; the tests exist only on the vaer branch. Record: `tasks/video-audio-engine-routing/todo.md`.
- **vaer review-scratch folders** (11, Phase 3 and Phase 7 arcs): closed. Record: `tasks/stale/`.
- **S2 deferral of vaer to S3 pending A/V sync research:** superseded by the S3-2 pivot. Record: `tasks/_context/depreciated/s3-2-pivot.md`.
- **S4-4 alternatives** (pin 2 channels only on stereo devices, an AVSampleBufferAudioRenderer rebuild, a Core Audio process tap): rejected in favor of pinning the source layout. Record: `tasks/video-multichannel-output/research.md`.

## Platform and build

- **macOS 15/26 support** and the availability-gated `InlineArray`/`Span` plans: superseded by D-TARGET27 (macOS 27 minimum, #87). v1.3 is the last release for macOS 15/26. Record: `tasks/_context/state.md`.
- **S4-1 research question (d), the deployment-target ADR:** answered by D-TARGET27. Record: `tasks/swift64-macos27-readiness/`.
- **OGG universal arm64 + x86_64 build and macOS 15/26 verification:** the target is arm64 only on macOS 27. Record: `tasks/ogg-vorbis-support/`.
- **spm-multiple-producers fix / "swift test passes via SwiftPM":** moot; root `Package.swift` has not built since `80540c2`. Record: `tasks/done/spm-multiple-producers-fix/`.
- **"swift-tools-version 6.2 matches the installed 6.2.4 toolchain":** the toolchain is Swift 6.4 (Xcode 27); tools-version and `SWIFT_VERSION` stay 6.2 by decision. Record: `tasks/_context/state.md`.
- **In-app AirPlay triggers** (S2 airplay-integration Phase 1): dropped because AVRoutePickerView routes only a single AVPlayer on macOS. The Oct 2025 plans in `tasks/depreciated/airplay/` and `tasks/depreciated/winamp-airplay-overlay/` are inputs to the S4-3 re-plan. Record: `tasks/done/airplay-integration/`.
- **D4 pbxproj merge order:** obsolete under XcodeGen; `.xcodeproj` is generated and gitignored. Record: `tasks/_context/depreciated/waves-1-3-plan.md`.

## Structure and decomposition

- **Waves 1-3 cross-task plan and research** (T1-T8, 2026-02-21; done by 2026-03-14): archived. Record: `tasks/_context/depreciated/waves-1-3-plan.md`, `tasks/_context/depreciated/waves-1-3-research.md`.
- **Wave decisions D1-D6:** all executed. D3 (T1 Phase 4 must follow T5 Phase 2) is moot: T5 Phase 2 was abandoned and Phase 4 shipped in #60. Record: `tasks/_context/depreciated/waves-1-3-plan.md`.
- **AudioEngineTransport** (a seek/transport Phase 4 extraction): replaced on Oracle advice by AudioEngineController (engine graph plus stream bridge, #60). Record: `tasks/done/audioplayer-decomposition/plan.md`.
- **6-callback SeekController:** rejected 2026-03-25 (D8, Option C). Only the lean Option B is under re-evaluation (SS-1). Record: `tasks/audioplayer-seek-extraction/depreciated.md`.
- **visualizerpipeline-decomposition:** NO-GO under Principle 5, then superseded when S3-2 Phase 1 (`146a8b4`) extracted VisualizerFeed and VisualizerScratchBuffers under the ADR-3a contract. Record: `tasks/done/visualizerpipeline-decomposition/`.
- **MainWindowVisualizerLayer extraction:** skipped; the cause was the visualizer poll timer in `.default` run-loop mode, fixed in #80. Record: `tasks/done/mainwindow-visualizer-isolation/`.
- **"Consolidate after S1" structure timing:** superseded by D-STRUCTURE (one Structure Sprint after S3-4). Record: `tasks/swift-project-structure-research/depreciated.md`.
- **DockingController** (with its debounce, `toggleMain` and tests): deleted in PR #90 (`757fc8d`) and replaced by DockGraph and WindowVisibilityController. Record: `tasks/done/window-docking-78/`.
- **#78 in S4-2:** pulled ahead by D-WIN78 and done in PR #90. Record: `tasks/done/window-docking-78/`.
- **HLS research approaches** (`Audio/Streaming/` placement, `.decodeError` rejection mapping, Content-Type promotion, Task-based refresh): superseded by the HLS plan. Record: `tasks/hls-streaming-support/depreciated.md`.
- **OGG research approaches** (Cogg/Cvorbis as root `Package.swift` targets, a StreamDecoder protocol with a 4-case StreamFormatHint, AVAudioSourceNode for local Vorbis): superseded by the OGG plan's `Vendor/COggVorbis` package wired through `project.yml`, StreamBackend enum and chained `scheduleBuffer` (Path A-revised). Record: `tasks/ogg-vorbis-support/depreciated.md`.

## Process

- **Per-commit Oracle reviews** via `mcp__codex-cli__codex` and up-to-4-round PR Oracle loops: dropped 2026-09-24 for one exhaustive `/codex:review --base main` before each PR. The plan-level Oracle ≥9/10 gate was dropped on 2026-10-02 (owner). Record: `tasks/_context/state.md`.
- **5-file task-folder layout and the `deprecated.md` spelling:** replaced by six files (`plan.md` created when planning starts) and `depreciated.md`. Record: `tasks/_context/state.md` (Process).
- **Dedicated docs branch for `_context` updates:** replaced by committing `_context` directly to `main` when the owner asks. Record: `tasks/swift-project-structure-research/depreciated.md`.
- **S4-1/S4-2 "ordering is an assumption":** confirmed by the owner on 2026-09-05 (D-S4). Record: `tasks/_context/state.md`.
