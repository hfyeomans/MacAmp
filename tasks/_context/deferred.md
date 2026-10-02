# Deferred Items

Updated: 2026-10-02

The one tracker for open deferred work across tasks. One row per item. The slot is a `plan.md` id or `owner`; the feature backlog at the end has no slot by design. When an item ships or is dropped, delete its row in the same change (git keeps the history). Where `plan.md` already describes a slotted item, the note here stays short; this file carries the detail for everything `plan.md` does not describe.

Sizes: Trivial, Small, Medium, Large.

## S3: streaming formats

| Item | Slot | Size | Note |
|------|------|------|------|
| `StreamDecodePipeline.stop()` fires `onTermination(.userStopped)` with no generation guard (theoretical double-fire) | S3-3 | Trivial | `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift:275-280`; HLS Phase 4 edits this code |
| Unused StreamPlayer DEBUG seams `pipelineStateForTesting` and `drainResumeWarmupForTesting` | S3-3 | Trivial | Optional delete in Phase 6. `MacAmpApp/Audio/StreamPlayer.swift:640/683`; no callers under `Tests/` |
| Root `Package.swift` does not build, and `Package.resolved` is the only tracked lockfile | S3-4 | Small | Commit C1 on `feat/ogg-vorbis-support`, which also pins exact package versions in `project.yml` (plan.md S3-4). Fallback S4-1 |
| The swift-tools-version decision line names a root manifest that C1 deletes | S3-4 | Trivial | At close-out, point it at `Vendor/COggVorbis/Package.swift`; S4-1's language-mode ADR covers that manifest |
| `AudioConverterDecoder.clearQueue()` relies on `assertConfinement()`, which only checks in Debug | S3-4 | Trivial | Document the Release-build gap. `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift:139-140`, `MacAmpApp/Audio/Streaming/QueueConfined.swift:12`; VorbisDecoder reuses the pattern |
| About-box link to `THIRD_PARTY_LICENSES.txt` | S3-4 | Trivial | Optional, at close-out. Shipping the file in the bundle already meets the license; `MacAmpApp/` has no custom About panel today |

## Structure Sprint

| Item | Slot | Size | Note |
|------|------|------|------|
| Pass-through facades: `AudioPlayer` (~25 one-line forwarders), `WindowCoordinator` (~30), the `PlaybackCoordinator → AudioPlayer → AudioEngineController` stream-bridge chain | SS-1, SS-7, SS-2/SS-6 | Medium | From the 2026-09-08 review (`review/codebase-audit-2026-09`, finding 8). Apply Principle 6 when each file is re-evaluated or moved; remove only forwarders with no policy |
| Early-project preprocessing workarounds that may no longer be needed | SS-0 | Small | `SkinBackgroundPreprocessor` was removed in #75 after it caused skin artifacts; look for similar pixel fixups while mapping |
| 8 files added to `Utilities/`, `ViewModels/` and `Models/` after D-STRUCTURE | SS-0 | Small | File list in `tasks/swift-project-structure-research/state.md` (Placement-rule breaches) |
| Seek characterization tests, including a user action during a pending engine reconfigure (`cancelPendingReconfigure`) | SS-1 | Medium | Precondition for any seek extraction. No test references the seek guards or `cancelPendingReconfigure` |
| Seek-guard `Task.sleep` delays (50, 100, 150, 200 ms) | SS-1 | Small | Replace with one structured guard-clear, only after the characterization tests. `MacAmpApp/Audio/AudioPlayer.swift:527/835/843/950/954/1035` |
| AudioPlayer swiftlint suppressions (`file_length` at `:1`, `type_body_length` at `:9`) | SS-1 | Small | After seek extraction both SwiftLint counts stay near 650: `file_length` still warns and `type_body_length` still errors (`tasks/audioplayer-seek-extraction/research.md`), so this needs its own threshold or split decision |
| `PreReconfigureSnapshot` carries more than the MacAmp-owned bridge flags | SS-1 | Small | Optional clarity refactor from the vaer branch. Defined at `MacAmpApp/Audio/AudioEngineController.swift:14`, consumed in AudioPlayer's engine-reconfigure section; `wasVideoBridge` is already gone (`ffd77c1`) |
| `DecodeContext` concurrency-contract retrofit (ADR-3a header contract plus gate test) | SS-2 | Small | `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift:525`; `docs/MACAMP_ARCHITECTURE_GUIDE.md:1514` names it the next candidate |
| #78 follow-ups from PR #90: minimize injection into `BorderlessWindow`, `ScreenClamp.restore`, shaded-Playlist pixel-size helper, top-anchored-origin helper, Option+Cmd+M check | SS-3 | Medium | `tasks/windowing-structure-consolidation/todo.md` |
| #78 docs fixes: `docs/context/xcode-testing-context.md` tag rows, `docs/MACAMP_ARCHITECTURE_GUIDE.md:1095`, `docs/VIDEO_WINDOW.md:391`, `docs/MILKDROP_WINDOW.md:556` | SS-3 | Trivial | Docs only; may land any time |
| TEXT.BMP glyph naming spread across views | SS-3 | Small | One helper, also covering `MainWindowIndicatorsLayer` (x2) and `SpriteResolver`; windowing todo |
| Quantized 25x29 resize math in 3 views (6 sites) | SS-3 | Small | One `Size2D` helper, done with the shaded-Playlist helper; windowing todo |
| No shared `WindowSizeState` protocol: size persistence is duplicated in the Playlist, Video and Milkdrop size-state types | SS-3 | Small | `MacAmpApp/Models/*WindowSizeState.swift`; do it with the resize helper |
| `Utilities/WinampWindowConfigurator.swift` and `Utilities/WindowResizePreviewOverlay.swift` are window code in `Utilities/` | SS-3 | Trivial | Move to `Windowing/`; windowing todo |
| `Butterchurn/test.html` is referenced nowhere but ships through the folder reference (`project.yml:25`) | SS-4 | Trivial | Keep or drop during the resource move |
| Tiled title-bar chrome repeated in 4 views | SS-5 | Small | Optional `tileRow` helper |
| Shared objects reached two ways besides environment injection: `WindowCoordinator.shared` (24 refs, 21 in `Views/`) and `AppSettings.instance()` (14); the 5 window controllers repeat the same init | SS-7 | Medium | Fix once at the App/ composition root |
| `PlaylistWindowActions` singleton (an NSMenuItem target with mutable `selectedIndices`) | SS-7 | Large | It also holds the 3 `Task.detached` in the S4-1 row below |
| Manual playlist selection-state sync | SS-7 | Small | Goes away with the singleton |
| Tests wait with `Task.sleep` (async-test determinism) | SS-8 | Medium | Follow-up commit after the pure moves, which stay behavior-free. `EngineConfigObserverTests` (8), `VideoTapLifecycleTests` (2), `VideoSeekStateMatrixTests` (2), `SkinManagerTests` (1) |
| Swift Testing follow-ups | SS-8 | Small | Same follow-up commit: `WindowFrameStoreTests` UserDefaults setup into `init()`; collapse the 2 `AudioPlayerStateTests` state-transition tests into one parameterized test; optional `.bug` traits |

## S4: platform adoption and issues

| Item | Slot | Size | Note |
|------|------|------|------|
| macOS 27 deprecations: 14 production, 2 test-only | S4-1 | Medium | Recount from a build log at pickup; known sites in plan.md S4-1 |
| `Skin` is `@unchecked Sendable` over `[String: NSImage]` | S4-1 | Small | Delete the unused `spriteResolver` environment helpers (`MacAmpApp/Models/SpriteResolver.swift:392-421`, no callers), then drop `@unchecked Sendable` (`MacAmpApp/Models/Skin.swift:10`). `SpriteResolver` is already plain `Sendable` |
| LockFreeRingBuffer overrun is a data race on storage, not an accepted trade-off | S4-1 | Small | Drop-newest on overrun, or a documented accepted-loss contract; mechanism in plan.md S4-1. The class doc comment (`MacAmpApp/Audio/LockFreeRingBuffer.swift:4-16`) also calls the decode-queue producer real-time (`:7`), and since `c6a5b23` a lost race makes `read` return 0 and the render block plays a zero-filled quantum, not garbled samples |
| TSan stress test for an overrun during an active read | S4-1 | Small | With the race fix |
| The "High throughput" test has a flaky overrun threshold, wrapped in `withKnownIssue(isIntermittent: true)` | S4-1 | Small | `Tests/MacAmpTests/LockFreeRingBufferTests.swift:440`. The race fix changes overrun behavior; redesign around throughput instead of an overrun cap |
| LockFreeRingBuffer uses `ManagedAtomic` (swift-atomics); VideoDSP uses `Synchronization` | S4-1 | Small | Move to `Synchronization.Atomic` with the race fix. Dropping swift-atomics also means migrating `AudioEngineController.swift`, `StreamPauseTailTests.swift` and `LockFreeRingBufferTests.swift`, which `import Atomics` |
| StreamPlayer hard-codes the ring capacity, 32,768 frames, at 4 sites | S4-1 | Trivial | One named constant, with the race fix. `MacAmpApp/Audio/StreamPlayer.swift:130/197/471/573`; LockFreeRingBuffer's 4096 is only the init default |
| No unit tests for `activateStreamBridge` / `deactivateStreamBridge` | S4-1 | Small | With the race fix. `MacAmpApp/Audio/AudioEngineController.swift:391/453`; `StreamPauseTailTests` covers the render block, not the lifecycle methods |
| Ring buffer benchmarks: write and read under 1 µs at 512 frames, zero hot-path allocations | S4-1 | Small | Optional; the planned benchmarks task was never created. Instruments Allocations works only on Debug builds (research.md) |
| Strict-concurrency leftovers: `nonisolated(unsafe)` at `StreamDecodePipeline.swift:79`; `Task.detached` at `MacAmpApp/Views/PlaylistWindowActions.swift:103/257/288` | S4-1 | Small | Both came back after T8 reached zero. The `Task.detached` sites may go with the SS-7 singleton |
| Default MainActor isolation (T8 Phase 5) | S4-1 | Large | Questionable ROI; decide in the Swift 6.4 language-mode ADR. Blast radius: `tasks/done/swift-concurrency-62-cleanup/research.md` |
| S3-2 P-2: Mirror reflection misses `~Copyable` fields in the VideoTapContext Sendable-contract test | S4-1 | Small | Documented limitation; revisit under strict memory safety. `tasks/done/avplayer-native-video-dsp/placeholder.md` |
| S3-2 P-3: `@preconcurrency import AVFoundation` workaround | S4-1 | Small | `MacAmpApp/Audio/VideoDSP/VideoTap.swift:1`, `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift:1`. Check whether the macOS 27 SDK annotations make it unnecessary |
| Passthrough guard: confirm stream decode output stays Float32 PCM if a passthrough route delivers encoded frames | S4-1 | Small | `AVAudioContentSource_Passthrough` is in the macOS 27 SDK (`AVFAudio/AVAudioSettings.h`). HDMI/optical-only risk; from `tasks/done/unified-audio-pipeline/todo.md` 2.3. Also check before S4-4 pins more than 2 channels |
| NSMenu "Internal inconsistency" console warnings from system-injected text menus | S4-1 | Small | Harmless and pre-existing; recheck on macOS 27 |
| `project.yml:6` says `xcodeVersion: '26.0'` | S4-1 | Trivial | Cosmetic |
| P-6: after a video, loading an audio track does not auto-play (needs Next) | S4-2 | Small | Found 2026-05-28 (S3-2 todo 2.40). Suspects: transport state left by the video-to-audio cleanup, or the async `loadAudioFile` racing `play()` |
| `VideoPlaybackController` does not observe `AVPlayer.timeControlStatus`, so an external pause is not mirrored in the UI | S4-2 | Small | Found in the S3-2 Phase B route gates; `timeControlStatus` appears nowhere in `MacAmpApp/` |
| Watch item: "RemoteLayerTreeDisplayLinkClient stuck 0.50s" main-thread warnings | S4-2 | Unknown | Seen only while LLDB was paused. Act only if they recur with no debugger attached (likely the Butterchurn WebView plus SwiftUI at 2x) |

## Any time and backlog

| Item | Slot | Size | Note |
|------|------|------|------|
| #86: a `PlaylistNavigationTests` case depends on the saved Repeat setting | AT-1 | Small | Standalone test-only PR before S3-3 (owner, 2026-10-02) |
| Seven `Timer` + `RunLoop.main.add(_, forMode: .common)` call sites with no shared helper | AT-2 | Medium | plan.md AT-2 |
| Shade-strip visualizer bars stuck at max until restart (2026-09-28, after minimize/hide cycles) | BL-1 | Small | Suspects: a non-finite value persisting in `VisualizerPipeline.updateLevels` smoothing, or NaN at the Goertzel clamp (`min(1.0, NaN)` returns 1.0). If it recurs, read `visualizerPipeline.levels` over LLDB |
| RMS/Goertzel math exists twice (engine tap and video tap) | BL-1 | Small | Parity test before changing the math (plan.md BL-1) |
| Instruments profiling of SwiftUI body-evaluation counts (T3, MainWindow decomposition) | BL-1 | Small | Optional, low priority; covers the same Main, shade-strip and Playlist views |

## Feature backlog (unscheduled by design)

No plan slot. Revisit on user demand; promote a row to `plan.md` when it is picked up.

| Item | Size | Note |
|------|------|------|
| HLS video: AVPlayer plays it natively, but with no EQ, visualizer or balance (the tap does not fire for streaming items, QA1716) | Small | Options: (1) ship with controls that silently do nothing, not recommended; (2) dim them through `PlaybackCoordinator.supportsAudioProcessing` for video plus HLS, ~50 LOC, recommended if built; (3) reject HLS-video URLs at detection with a non-reconnectable error. Also revisit with a Features/Video consolidation, or if AVFoundation lifts QA1716. Today such a URL fails through the legacy M3U path; re-check after S3-3 adds its classifier |
| HLS: promote extensionless URLs to HLS by Content-Type | Small | v1 routes only `.m3u8`/`.m3u` through the M3U classifier |
| HLS: sample-accurate pause instead of stop, re-fetch and warmup | Medium | Revisit on user feedback |
| HLS VOD `displayDuration` (sum of segment durations) | Small | v1 leaves it at 0 |
| HLS v2: MPEG-TS demuxer, fMP4 init segments, adaptive bitrate, decoder swap after a post-discontinuity format change | Large | Separate task if needed |
| HLS v3: Low-Latency HLS, AES-128 segment decryption | Large | Probably never needed for radio |
| OGG Opus, OGG FLAC and OGG Speex decoders | Medium each | S3-4's sniffer rejects them with a clear error; new tasks if wanted |
| Real-time VBR bitrate display, including Vorbis | Medium | Winamp updates it during playback; MacAmp reads it once at load (`MacAmpApp/Audio/MetadataLoader.swift:88-116`) |
| Accessibility: `WinampVerticalSlider`, `WinampVolumeSlider` and `WinampBalanceSlider` have no adjustable action | Small | Add `.accessibilityAdjustableAction` for VoiceOver (`MacAmpApp/Views/Components/`) |
| Accessibility: the `EQPresetPickerView` import footer is an `HStack` with `onTapGesture` | Trivial | Make it a `Button`. `MacAmpApp/Views/Components/EQPresetPickerView.swift:58-71` |

## Owner

| Item | Slot | Size | Note |
|------|------|------|------|
| PR #81 review threads #2 and #3 have no reply | owner | Trivial | `./scripts/resolve-pr-comments.sh 81 list`; also in state.md, Owner decisions pending |
