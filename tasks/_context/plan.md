# MacAmp Roadmap Plan

Updated: 2026-10-02

Future work only, in execution order. Current state, decisions in force and process rules live in `tasks/_context/state.md`. Unslotted deferred items are in `tasks/_context/deferred.md`, findings in `tasks/_context/research.md`, and the checklist in `tasks/_context/todo.md`. Each task folder holds its own detail.

## Flow

```text
S3-3 HLS ──► S3-4 OGG ──► Structure Sprint (SS-0..SS-8) ──► S4-1 ──► S4-2 ──► S4-3 ──► S4-4
                                                             ▲
                 S4-1 research half (no code), any time ─────┘

Structure Sprint:
SS-0 map ──┬──► SS-1 seek ────────┬──► SS-6 Audio/ ───────┐
           ├──► SS-2 decode ──────┘                       ├──► SS-7 App/Core/Shared ──► SS-8 tests ──► SS-9 (optional)
           ├──► SS-3 Windowing/ ──┬──► SS-5 Features/ ────┘
           └──► SS-4 Milkdrop ────┘

Now, before S3-3: AT-1 (#86)     After S3-4: AT-2 (Timer helper, best in SS-7)     Backlog: BL-1 (visualizer audit)
```

## Ordering rules

1. **S3-3 before S3-4** (state.md, S3 order). OGG rebases on post-HLS main using HLS plan §17.1.2.
2. **D-STRUCTURE** (state.md): all file moves wait for the Structure Sprint after S3-4 merges. Until then, new files go to their target location and decomposition splits files in place.
3. **D-S4** (state.md): S4-2 lands after the Structure Sprint and after S4-1, whose deprecation findings may change how the issues are fixed. The only exception so far is D-WIN78 (#78, done in PR #90).
4. **S4-1's research half is ungated.** It touches no code and may run any time. Only its implementation waits for the Structure Sprint.
5. S4-3 follows S4-1 (API findings). S4-4's predecessors are met, but it keeps its slot after S4-3.

Every item: one branch and PR, `xcodegen generate`, TSan build and test, one exhaustive `/codex:review --base main` before the PR, and the owner merges and deletes the branch. Close-out: `git mv` the folder to `tasks/done/` and update `_context/` (state, plan, todo, deferred, tasks_index, resume-prompt). There are no Oracle plan gates (owner, 2026-10-02).

## Summary

| ID | Item | Folder | Status | Predecessors |
|----|------|--------|--------|--------------|
| S3-3 | Audio-only HLS | `tasks/hls-streaming-support/` | NEXT | #82, #89 merged; PR #91 merge recommended first |
| S3-4 | OGG Vorbis | `tasks/ogg-vorbis-support/` | BLOCKED | S3-3 |
| SS-0 | Structure Sprint map | `tasks/swift-project-structure-research/` | QUEUED | S3-4 |
| SS-1 | AudioPlayer seek re-evaluation (D8) | `tasks/audioplayer-seek-extraction/` | DEFERRED | SS-0, S3-4 |
| SS-2 | StreamDecodePipeline re-evaluation | `tasks/streamdecodepipeline-decomposition/` | DEFERRED | SS-0, S3-4 |
| SS-3 | Windowing/ consolidation | `tasks/windowing-structure-consolidation/` | DEFERRED | SS-0 |
| SS-4 | Features/Milkdrop/ consolidation | `tasks/milkdrop-feature-consolidation/` | DEFERRED | SS-0 |
| SS-5 | Features/ consolidation | no folder yet | QUEUED | SS-0, SS-3, SS-4 |
| SS-6 | Audio/ consolidation | no folder yet | QUEUED | SS-0, SS-1, SS-2 |
| SS-7 | App/, Core/, Shared/ and composition root | no folder yet | QUEUED | SS-0, SS-5, SS-6 |
| SS-8 | Mirror tests to source layout | no folder yet | QUEUED | SS-3 to SS-7 |
| SS-9 | Local packages | no folder yet | OPTIONAL | SS-8 |
| S4-1 | macOS 27 / Swift 6.4 adoption | `tasks/swift64-macos27-readiness/` | QUEUED | Research: none. Implementation: Structure Sprint |
| S4-2 | GitHub issues #47, P-6, #79, #84 | `tasks/github-issues-triage/` | QUEUED | Structure Sprint, S4-1 |
| S4-3 | AirPlay route picker | no folder yet | QUEUED | S4-1 |
| S4-4 | Multichannel video output (#88) | `tasks/video-multichannel-output/` | QUEUED | S4-3 (roadmap order only) |
| AT-1 | #86 test isolation | no folder | IN REVIEW | PR #92 open; owner merges |
| AT-2 | Timer common-mode helper | no folder yet | DEFERRED | S3-4 (shares StreamPlayer/AudioEngineController); best in SS-7 |
| BL-1 | Visualizer fidelity audit | no folder yet | BACKLOG | None |

Status words: IN REVIEW = PR open; NEXT = start now; BLOCKED = waiting on a predecessor; QUEUED = waiting its turn; DEFERRED = parked until its slot or trigger; PENDING = needs an owner decision; OPTIONAL; BACKLOG = not scheduled.

## S3: streaming formats

### S3-3 Audio-only HLS

- **Scope:** M3U8 master and media playlists with AAC-ADTS segments, live and VOD. Adds `MacAmpApp/Audio/HLS/` (M3U8Parser ~225 LOC, HLSSegmentFeeder ~350 LOC) and `Tests/MacAmpTests/HLSStreamingTests` (~300 LOC). The feeder hands bytes to `DecodeContext.handleIncomingData` (`StreamDecodePipeline.swift:617`) through an injected `@Sendable (Data) -> Void` closure, so no visibility widens. Edits StreamDecodePipeline (M3U dialect classifier, HLS start, generation snapshot, pause/resume dispatch, non-reconnectable `.streamFinished` and `.unsupportedFormat`), AudioFileStreamParser (`reset()` with format and magic-cookie compare) and StreamPlayer (`isReconnectable`, `userMessage`). Two tokens gate stale callbacks: `pipelineGeneration` and `pauseEpoch`. Phase 4 also adds the missing generation guard to `StreamDecodePipeline.stop()` (`:275-280`). Branch `feat/hls-streaming-support`.
- **Non-goals:** MPEG-TS, fMP4, LL-HLS, ABR, DRM, HLS video, splitting StreamDecodePipeline, and any change to AudioPlayer, AudioEngineController, PlaybackCoordinator, Track, RadioStation or M3UParser.
- **Amp item:** optional, in Phase 6: delete the unused StreamPlayer DEBUG seams `pipelineStateForTesting` (`StreamPlayer.swift:640`) and `drainResumeWarmupForTesting` (`:683`).
- **Risks and gates:**
  - PF.3 first: re-read StreamDecodePipeline (825 lines), StreamPlayer (714) and AudioFileStreamParser (186) at branch time and confirm the anchors. They were refreshed at `b3894d9`; PR #91 does not touch these files, but later merges may shift them.
  - Open design call: `parser.reset()` per segment or only on `EXT-X-DISCONTINUITY`. Decide with listening and dump tests.
  - Re-derive the S3-3/S3-4 file-conflict map from both plans at start (current map in research.md).
  - Phase 7: full TSan suite, opt-in `MACAMP_HLS_INTEGRATION` smoke test, Instruments decoder-lifecycle leak check per `tasks/_context/instruments-allocations-workflow.md` (build constraints in research.md).
  - Phase 8 manual gates: 3+ live HLS stations, legacy .m3u/.pls/SHOUTcast, local formats, HLS↔local transitions, encrypted/fMP4/TS error paths. A manual-gate failure means an ADR amendment plus a targeted retry, never a soft-skip.

### S3-4 OGG Vorbis

- **Scope:** OGG Vorbis for local files and Icecast streams. Vendors libogg 1.3.5 and libvorbis 1.3.7 as one local package, `Vendor/COggVorbis` (Cogg, Cvorbis), wired through `project.yml`. Adds VorbisDecoder (QueueConfined), OggCodecSniffer, and a fileprivate StreamBackend, PipelineLifecycle and StreamFormatHint in StreamDecodePipeline. Collapses to one `formatReadyFired` gate and fixes the chained-format `onFormatReady` gap (onChainFormatChange → onStreamChainFormatChanged → PlaybackCoordinator). Local playback through VorbisFileSource and LocalAudioSource (chained `scheduleBuffer` on playerNode). Renames ICYMetadata to a top-level StreamMetadata and adds .ogg/.oga to MetadataLoader. Documents the Release-build confinement gap in `AudioConverterDecoder.clearQueue` / `QueueConfined`, which VorbisDecoder reuses. arm64 only, macOS 27. Branch `feat/ogg-vorbis-support`; throwaway spikes `spike/ogg-build-wiring` (0a) and `spike/ogg-local-playback` (0b).
- **Non-goals:** encoding, more than 2 output channels, HLS-Vorbis, Theora, Opus/FLAC/Speex.
- **Amp item:** root `Package.swift` cannot build (mixed Swift and ObjC with a bridging header, no Butterchurn resources), and nothing runs `swift build`. In commit C1 on `feat/ogg-vorbis-support`, not on the throwaway spike, delete `Package.swift`, `Package.resolved` and the `.swiftlint.yml` exclude (`.swiftlint.yml:44`). `Package.resolved` is the only tracked lockfile (`.gitignore:44` ignores `MacAmpApp.xcodeproj/`), so the same commit replaces the `from:` ranges in `project.yml` with exact pins at today's resolved versions: ZIPFoundation 0.9.20 and swift-atomics 1.3.0. Fallback slot: S4-1.
- **Risks and gates:**
  - Order: G1 after S3-3 merges, re-read every Files Affected at HEAD (no code); then the 0a/0b spikes; then cut `feat/ogg-vorbis-support` and apply the 5-step HLS hand-off (HLS plan §17.1.2) as its first work.
  - Owner call before Phase 1: run the 5-station live OGG spot-check or accept the risk. It also answers whether OGG is still worth doing.
  - Phase 0a/0b spikes are hard gates (0b: drift ≤100 ms over 60 s, exactly one completion, TSan clean). Record the results in research.md and delete both spike branches.
  - C9: Release binary size ≤500 KB stripped, plus an Instruments decoder-lifecycle leak check.
  - StreamDecodePipeline grows to about 1,225 raw / ~820 SwiftLint-counted lines, past the 600 `file_length` warning (research.md, Fired growth triggers), and the plan forbids splitting it; SS-2 handles that.
  - Manual gates follow the S3-3 failure rule (ADR amendment plus targeted retry).
  - Close-out: once root `Package.swift` is gone, the swift-tools-version decision in state.md refers only to `Vendor/COggVorbis/Package.swift`; update that line.

## Structure Sprint

Starts after S3-4 merges. Each consolidation task gets its own branch; there is no umbrella restructure branch.

### SS-0 Structure Sprint map

- **Scope:** one source-to-target map for every file in `MacAmpApp/` and `Tests/` against the approved layout: App/, Core/, Shared/, Features/, Audio/, Windowing/, Resources/, with no top-level ViewModels/ or Utilities/. Set the execution order and dependencies. Create task folders for SS-5, SS-6 and SS-7 (6-file layout; plan.md is created when planning starts). `project.yml` globs `MacAmpApp/`, so moves inside it need no edit; only the Butterchurn folder reference (`project.yml:25`) changes, plus an `excludes:` entry for the moved folder in the `MacAmpApp` sources entry (SS-4). Decide the ambiguous files and where the shared domain models left in Models/ go (list in `tasks/swift-project-structure-research/plan.md`, step 3). Reconcile Audio/ subfolder names with what exists: Streaming/, VideoDSP/ (not the planned Video/), ObjCBridge/, plus HLS/ and Vorbis/ from S3. Audit leftover early-project preprocessing workarounds.
- **Amp item:** folder misplacement across Models/, ViewModels/ and Utilities/, including the 8 placement-rule breaches listed in `tasks/swift-project-structure-research/state.md`. The map covers every file; SS-3 to SS-7 move them.
- **Gates:** run the SS-1 and SS-2 re-evaluations before any moves.

### SS-1 AudioPlayer seek re-evaluation (D8)

- **Why now:** D8 (AudioPlayer stays whole, Option C) is under re-evaluation, not in force. Two of its three triggers fired: size (`AudioPlayer.swift` is 1,101 lines) and new responsibility (the video-tap and engine-reconfigure sections); the testability trigger has not.
- **Scope:** re-evaluate Option B, a lean SeekController with direct references to the engine and videoPlaybackController and about 2 callbacks (onRequestNextTrack, onPlaylistAdvanceRequest). If go, move atomically: currentSeekID, seekGuardActive, isHandlingCompletion, shouldIgnoreCompletion, seek, seekToPercent, videoSeekCompletion and onPlaybackEnded. Decompose in place in Audio/, before SS-6. Replace the seek-guard `Task.sleep` delays with one structured guard-clear, only once tests exist. Decide the two swiftlint suppressions (`AudioPlayer.swift:1` file_length, `:9` type_body_length): after seek extraction both SwiftLint counts stay near 650, so `file_length` still warns and `type_body_length` still errors (`tasks/audioplayer-seek-extraction/research.md`).
- **Also:** the optional SS-1 rows in deferred.md (PreReconfigureSnapshot narrowing).
- **Risks and gates:** seek characterization tests come first (seek while playing or paused, seek to end, rapid seeks, guarded stream no-op, a user action during a pending engine reconfigure via cancelPendingReconfigure). Go/no-go ADR. Kill switch: cancel if state ownership would still be split. TSan, manual seek and remote-command checks.

### SS-2 StreamDecodePipeline re-evaluation

- **Scope:** re-baseline at post-OGG HEAD (825 lines today; projected growth in research.md, Fired growth triggers). Re-evaluate extracting DecodeContext (private becomes internal, Principle 5), SessionDelegateProxy (HLS adds a second fileprivate copy, still under the Rule of Three) and PlaylistResolver with formatHint; redraw the resolver boundary after HLS adds its M3U classifier. Retrofit DecodeContext (`@unchecked Sendable`, `StreamDecodePipeline.swift:525`) to the ADR-3a header contract plus gate test that the other ADR-3a types follow (list in state.md, Architecture invariants). Decompose in place in Audio/Streaming/.
- **Risks and gates:** preserve generation-token, shutdown and callback semantics. Go/no-go per the `tasks/_context/principles.md` checklist. TSan, manual radio test (metadata, reconnect, pause/resume).

### SS-3 Windowing/ consolidation

- **Scope:** move generic window infrastructure into `MacAmpApp/Windowing/` (Controllers/, Coordination/, Geometry/, Persistence/) after a dependency analysis of WindowCoordinator and WindowRegistry that rejects cycles. Classify each candidate: move as-is, move after a small abstraction, or leave. #78 follow-ups from PR #90: minimize injection into BorderlessWindow, ScreenClamp.restore plus tests, PlaylistWindowSizeState.pixelSize, a topAnchoredOrigin helper, an Option+Cmd+M check and the docs fixes. Add a WindowSizeState protocol for the duplicated Playlist, Video and Milkdrop size-state types. The docs-only #78 fixes may land any time.
- **Amp items:**
  - One `Size2D.quantizedDelta` helper replaces the 25×29 quantized resize math in 3 views (6 sites: PlaylistResizeHandle `:29/:46`, VideoWindowChromeView `:304/:322`, MilkdropWindowChromeView `:173/:190`). Do it with the shaded-Playlist pixel-size helper.
  - `SkinSprites.characterSpriteName(for:)` (#78 follow-up 6, extended by the amp review) for all 10 `CHARACTER_` sites in 8 files.
  - Move `Utilities/WinampWindowConfigurator.swift` and `Utilities/WindowResizePreviewOverlay.swift` into Windowing/.
- **Risks and gates:** the #78 and amp refactors are behavior-touching exceptions to the sprint's "no behavior change" rule. Manual multi-window checks: docking, visibility, persistence, resize, shade, double size.

### SS-4 Features/Milkdrop/ consolidation

- **Scope:** move Models/MilkdropWindowSizeState, ViewModels/ButterchurnBridge, ViewModels/ButterchurnPresetManager, Views/WinampMilkdropWindow, Views/Windows/ButterchurnWebView, Views/Windows/MilkdropWindowChromeView and Windows/WinampMilkdropWindowController into `Features/Milkdrop/`. Move the repo-root `Butterchurn/` to `Features/Milkdrop/Resources/Butterchurn/`, update `project.yml:25`, and exclude the moved folder from the `MacAmpApp` sources entry so XcodeGen does not add it twice. Generic windowing code stays out. Decide whether WinampMilkdropWindow/Controller keep the Winamp prefix, and whether the unreferenced `Butterchurn/test.html` keeps shipping.
- **Risks and gates:** bundle lookups use subdirectory "Butterchurn" (`ButterchurnWebView.swift:112/:157`) and change only if the bundled folder name changes. Verify Butterchurn loads in Debug and in a packaged Release build.

### SS-5 Features/ consolidation

- **Scope:** move feature-local views, state and window controllers into `Features/<Feature>/` for MainWindow, Playlist, Equalizer, Video, Preferences, Skins and Radio, by the proximity rule. Views/MainWindow/ and Views/PlaylistWindow/ are already subfolders; the EQ, Video and Views/Windows/ files are flat. Feature-local Models/ state (for example Playlist/VideoWindowSizeState) moves with its feature. Folder to create: `tasks/features-consolidation/`, seeded from SS-0's map.
- **Amp item:** optional `tileRow` helper for the tiled title-bar chrome repeated in 4 views (WinampPlaylistWindow, WinampVideoWindow, VideoWindowChromeView, MilkdropWindowChromeView).
- **Gates:** xcodegen, TSan, manual smoke per window.

### SS-6 Audio/ consolidation

- **Scope:** split Audio/ into Playback/ (AudioPlayer, PlaybackCoordinator, PlaylistController, AudioEngineController, AudioEngineConfigurationObserver, and SeekController if SS-1 goes ahead), Streaming/ (exists; add StreamPlayer, LockFreeRingBuffer and any SS-2 extractions), Equalizer/ (EqualizerController, EQPresetStore), Visualization/ (VisualizerPipeline, VisualizerFeed, VisualizerScratchBuffers, possibly VideoTapVisualizerRender), VideoDSP/ (keep the name; add VideoPlaybackController), Persistence/, ObjCBridge/, HLS/ and Vorbis/. SS-0's map places the rest, including MetadataLoader and RenderThreadSafe. Folder to create: `tasks/audio-consolidation/`.
- **Gates:** xcodegen, TSan, smoke for local audio, streams, video and Butterchurn.

### SS-7 App/, Core/, Shared/ and composition root

- **Scope:** App/ gets MacAmpApp.swift, AppCommands, SkinsCommands and the composition root. Core/ gets small, truly global code (AppLogger, TimeFormatting, WeakBox) and stays small. Shared/ gets cross-feature UI and primitives (today's Views/Shared/ and Views/Components/). Delete the top-level ViewModels/ and Utilities/. Replace the PlaylistWindowActions singleton (an NSMenuItem target with mutable selectedIndices that also holds the 3 `Task.detached`), which removes the manual playlist selection-state sync. Folder to create: `tasks/app-core-shared-consolidation/`, seeded from `tasks/done/playlistwindow-layer-decomposition/depreciated.md` §3-4.
- **Amp item:** one composition root in App/ replaces the `WindowCoordinator.shared` and `AppSettings.instance()` access paths and the init repeated across the 5 window controllers (counts in deferred.md, SS-7).
- **Gates:** xcodegen, TSan, manual multi-window and menu checks. AT-2 fits here once Core/ exists.

### SS-8 Mirror tests to source layout

- **Scope:** reorganize the flat `Tests/MacAmpTests/` (21 files) to mirror the new layout, for example Audio/Streaming/, Windowing/, Features/Milkdrop/. Pure moves, no test-behavior changes. Update `docs/context/xcode-testing-context.md`. Then one follow-up commit for the SS-8 rows in deferred.md (`Task.sleep` determinism, Swift Testing follow-ups). Tracked in `tasks/swift-project-structure-research/todo.md`.
- **Gates:** the full TSan suite stays green; the move commit keeps the same test count.

### SS-9 Local packages (optional)

- **Scope:** extract local Swift packages (Windowing, AudioStreamingCore, SkinEngine) only where a boundary is proven. Evaluate after the sprint; see `tasks/swift-project-structure-research/plan.md`.

## S4: platform adoption and issues

### S4-1 macOS 27 / Swift 6.4 adoption

- **Scope:** adoption task under D-TARGET27.
  - Replace the macOS-27 deprecations deferred from #87/#89: 14 production plus 2 test-only (`BiquadNumericalMatchTests.swift:246-247`). Recount from a build log; AudioEngineController alone now has 12 `.connect(` sites. The others are `AVAudioPlayerNode.play()`, `auAudioUnit` (→ `withAUAudioUnit`), `installTap(onBus:)` (`VisualizerPipeline.swift:123`) and `AVPlayerItemDidPlayToEndTime` (`VideoPlaybackController.swift:145`).
  - Adopt Span/MutableSpan/InlineArray in the DSP and visualizer buffers; evaluate `-strict-memory-safety`.
  - Swift 6.4 language-mode ADR (SWIFT_VERSION and tools-version are 6.2 today). It covers the ADR-3a containment gates, Atomic/Mutex, default MainActor isolation and the `Vendor/COggVorbis/Package.swift` manifest.
  - Strict-concurrency leftovers: `nonisolated(unsafe)` at `StreamDecodePipeline.swift:79`, 3 `Task.detached` at `PlaylistWindowActions.swift:103/257/288`, S3-2 P-2 (Mirror misses `~Copyable` fields) and P-3 (`@preconcurrency import AVFoundation`).
  - Fix the cosmetic `xcodeVersion: '26.0'` at `project.yml:6`. Record D-TARGET27 as ADR-1.
  - Deferred inputs slotted here: every S4-1 row in deferred.md (passthrough guard, NSMenu warnings recheck, ManagedAtomic → Synchronization.Atomic, the ring-capacity constant, stream-bridge lifecycle tests, ring-buffer benchmarks).
  - Liquid Glass work depends on the owner's Appearance Mode decision.
- **Amp items** (mechanism and line anchors in `tasks/swift64-macos27-readiness/state.md`, Amp-review items):
  - Skin Sendable: delete the unused `spriteResolver` environment helpers, then drop `@unchecked Sendable` from Skin. SpriteResolver is already plain `Sendable`.
  - LockFreeRingBuffer overrun race: the heads are already ManagedAtomic; the race is the producer's storage write over unread frames on overrun. Fix with drop-newest on overrun or a documented accepted-loss contract, and correct the "Known race (accepted)" doc comment. Add the overrun-during-read TSan stress test and replace `withKnownIssue` on the high-throughput test.
  - Fallback: the root `Package.swift` deletion and version pins, if S3-4 C1 did not land them.
- **Risks and gates:** the research half (Xcode doc bundle, deep research and point lookups on Swift 6.4, SwiftUI, and macOS 27 AppKit/WebKit/AVFoundation/AVAudioEngine) may start any time. Re-run the TSan baseline at pickup. The concurrency and ring-buffer changes are risky enough for the external review.

### S4-2 GitHub issues

- **Scope**, one branch and PR each, in this order:
  1. #47: Cmd+Shift+1-3 is bound to both bundled-skin switching (`SkinsCommands.swift`) and the window toggles (`AppCommands.swift:15-19`).
  2. P-6: after a video, loading an audio track does not auto-play. Close P-6 in `tasks/done/avplayer-native-video-dsp/placeholder.md` and in deferred.md.
  3. #79: drag and drop onto the window, Dock or app icon does nothing, and Finder double-click / Open With is greyed out. Leads: `Info.plist` CFBundleDocumentTypes lists only skins, there are no onDrop handlers, and Cmd+O is limited to `[.audio]` (`AppCommands.swift:107`).
  4. #84: Nucleo NLog v102 classic-skin rendering; verify across 3-5 skins and update the skin docs.
  - Also: VideoPlaybackController does not observe `timeControlStatus`, so an external AVPlayer pause is not mirrored in the UI. The RemoteLayerTreeDisplayLinkClient warning is in scope only if it recurs without a debugger. #86 joins here only if the owner folds AT-1 in. #78 is done (PR #90); #88 is S4-4.
- **Risks and gates:** re-fetch the issues and reproduce each on HEAD first. plan.md with a fix plan per issue, a file-conflict map and merge order, folding in S4-1's deprecation conclusions; owner sign-off before code. Close each issue with its PR link.

### S4-3 AirPlay route picker

- **Scope:** an in-app AVRoutePickerView over the Winamp logo, re-planned on Swift 6.4 and macOS 27. Inputs: the Oct 2025 plans in `tasks/depreciated/airplay/` and `tasks/depreciated/winamp-airplay-overlay/`, never implemented (AVRoutePickerView has never been in `MacAmpApp/` or `Tests/`). Folder to create: `tasks/airplay-route-picker/` (6-file layout).
- **Risks and gates:** on macOS, AVRoutePickerView routes a single AVPlayer and cannot redirect AVAudioEngine. AVAudioEngineConfigurationChange is not a general route-change signal, so route awareness needs a HAL default-output listener (`tasks/stale/airpods-route-gate-validation/`). S3-2 gate 8.9 (AirPlay 2) results feed the acceptance criteria. Details in research.md.

### S4-4 Multichannel video output (#88)

- **Scope:** today `VideoTap.preferredProcessingFormat` pins stereo Float32 at the source rate (`VideoTap.swift:220-227`). Recommended: pin the source layout, apply left gain to L/Ls/Lrs and right gain to R/Rs/Rrs, and fold Center (and LFE, if Apple's downmix includes it) into the near side. About 40-60 LOC in the tap plus a main-actor layout-to-role mapping, with no route detection and no item rebuild.
- **Risks and gates:** experiments 1-4 first (C/LFE downmix coefficients, negotiated channel count per route, effect on the Spatial/Atmos indicator, changing `allowedAudioSpatializationFormats` on a live item). Check passthrough routes (AVAudioContentSource_Passthrough) before pinning more than 2 channels. Keep the source-rate AirPlay 2 pumping fix (ADR-12). Layout-mapping and fold-math unit tests, then ear checks. The tracked `clapperboard-videos/` corpus (5 clips, one surround) suits the experiments (research.md).

## Outside the main sequence

### AT-1 #86 test isolation

- **Status:** IN REVIEW, PR #92 (`fix/86-test-repeat-mode`). The owner chose a small standalone test-only PR before S3-3 (2026-10-02). It is our own test defect, so it does not wait for S4-2 under D-S4.
- **Scope:** PlaylistNavigationTests "nextTrack returns stream handoff for mixed playlist" reads `PlaylistController.repeatMode` from the global AppSettings backed by real UserDefaults, so a saved repeat-one setting makes it return `.restartCurrent`. Pin `repeatMode` in the test and save/restore the UserDefaults key. Closes #86.
- **Gates:** TSan suite; record the result in state.md.

### AT-2 Timer common-mode helper

- **When:** after S3-4, because it edits StreamPlayer and AudioEngineController, which S3-3 and S3-4 also edit (research.md); best done in SS-7.
- **Scope:** add `Timer.scheduledOnMainCommon(every:repeats:_:)` and migrate the 7 `Timer` + `RunLoop.main.add(_, forMode: .common)` sites: VisualizerPipeline, AudioEngineController, StreamPlayer, VideoWindowChromeView, WinampMainWindowInteractionState and ButterchurnPresetManager (×2). Place it in Core/ once SS-7 creates it, otherwise in Utilities/ with a documented exception. A new .swift file needs only `xcodegen generate`.
- **Risks and gates:** review the `@Sendable` capture (`[weak self]`, `MainActor.assumeIsolated`) at each site. TSan; manual visualizer, timer and Butterchurn check.

## Backlog

### BL-1 Visualizer fidelity audit

- **Scope:** check band centres and bar mapping (20 Goertzel bands to 19 bars), per-band gains, log scaling, smoothing and peak falloff against Winamp/Webamp, across Main, the Main shade strip and Playlist. Includes the 2026-09-28 shade-strip bars stuck at max and the optional SwiftUI body-evaluation profiling (deferred.md BL-1 rows). Create the folder when started.
- **Amp item:** RMS/Goertzel is computed twice (`VisualizerPipeline.makeTapHandler` and `Audio/VideoDSP/VideoTapVisualizerRender.swift`, which says the two must match). Add a parity test first (preferred at two occurrences under Principle 4), or extract one shared function, before changing the math.
