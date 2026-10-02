# MacAmp Roadmap Todo

Updated: 2026-10-02

Checklist derived from `tasks/_context/plan.md`, grouped by plan item ID in execution order. Each task folder's todo.md holds the detail. Check an item only when it is verifiably done.

## S3-3 Audio-only HLS ([tasks/hls-streaming-support/todo.md](../hls-streaming-support/todo.md))

- [x] PF.1 S3-1B merged (#82, `b60fd57`) and PF.2 S3-2 merged (#89, `ae15f5c`)
- [x] PF.6 plan approved (Oracle 9.0/10, round 4)
- [ ] PF.3 re-read StreamDecodePipeline, StreamPlayer and AudioFileStreamParser at branch time; confirm the anchors (refreshed at `b3894d9`)
- [ ] PF.4 cut `feat/hls-streaming-support`; PF.5 create `MacAmpApp/Audio/HLS/`
- [ ] Re-derive the S3-3/S3-4 file-conflict map from both plans
- [ ] Phases 1-3: M3U8Parser, `AudioFileStreamParser.reset()`, HLSSegmentFeeder, each with tests
- [ ] Phase 4: StreamDecodePipeline integration, including the `stop()` generation guard
- [ ] Phases 5-6: termination mapping, StreamPlayer `isReconnectable`/`userMessage`
- [ ] Amp (optional, Phase 6): delete the 2 unused StreamPlayer DEBUG seams
- [ ] Decide `parser.reset()` per segment vs only on `EXT-X-DISCONTINUITY`
- [ ] Phase 7: full TSan suite, `MACAMP_HLS_INTEGRATION` smoke test, Instruments leak check
- [ ] Phase 8: manual gates (failure means ADR amendment plus targeted retry)
- [ ] Phase 9: docs; record deferrals in `tasks/_context/deferred.md`
- [ ] One `/codex:review --base main`, PR; owner merges; close out

## S3-4 OGG Vorbis ([tasks/ogg-vorbis-support/todo.md](../ogg-vorbis-support/todo.md))

- [x] G0 plan approved (Oracle 9.3/10, round 3)
- [ ] G1 after S3-3 merges: re-read every Files Affected at HEAD (no code)
- [ ] Phase 0a spike (build wiring, arm64 only) and Phase 0b spike (local playback contract); results in research.md; delete both spike branches
- [ ] Cut `feat/ogg-vorbis-support`; apply the HLS plan §17.1.2 hand-off first
- [ ] C1: vendor `Vendor/COggVorbis`; amp: delete root `Package.swift`, `Package.resolved` and the `.swiftlint.yml` exclude, and pin exact ZIPFoundation and swift-atomics versions in `project.yml`
- [ ] C2-C8: VorbisDecoder, OggCodecSniffer, pipeline backend and lifecycle, VorbisFileSource/LocalAudioSource, StreamMetadata rename, detection routing, tests
- [ ] Document the Release-build confinement gap in `AudioConverterDecoder.clearQueue` / `QueueConfined`
- [ ] C9: Release binary size ≤500 KB stripped; Instruments leak check
- [ ] One `/codex:review --base main`, PR; owner merges; close out, including the tools-version decision line in state.md

## SS-0 Structure Sprint map ([tasks/swift-project-structure-research/todo.md](../swift-project-structure-research/todo.md))

- [ ] Source-to-target map for every file in `MacAmpApp/` and `Tests/`, including the post-2026-03-15 placement breaches (amp)
- [ ] Execution order; SS-1 and SS-2 re-evaluations before any moves
- [ ] `project.yml` migration analysis (Butterchurn folder reference plus an `excludes:` entry), ambiguous-file decisions, Audio/ subfolder names reconciled
- [ ] Create the SS-5, SS-6 and SS-7 task folders (6-file layout)
- [ ] Audit leftover early-project preprocessing workarounds

## SS-1 AudioPlayer seek re-evaluation ([tasks/audioplayer-seek-extraction/todo.md](../audioplayer-seek-extraction/todo.md))

- [ ] Re-measure the seek responsibility map at post-OGG HEAD
- [ ] Seek characterization tests, including a user action during a pending engine reconfigure
- [ ] Go/no-go ADR on Option B (D8 re-evaluation) with its kill switch
- [ ] If go: atomic extraction, structured guard-clear, TSan, manual seek and remote-command checks, PR
- [ ] Decide the `file_length` and `type_body_length` suppressions

## SS-2 StreamDecodePipeline re-evaluation ([tasks/streamdecodepipeline-decomposition/todo.md](../streamdecodepipeline-decomposition/todo.md))

- [ ] Re-baseline the responsibility map at post-OGG HEAD
- [ ] Go/no-go per the `tasks/_context/principles.md` checklist
- [ ] DecodeContext concurrency contract: header plus gate test
- [ ] If go: extract, TSan, manual radio test, PR

## SS-3 Windowing/ consolidation ([tasks/windowing-structure-consolidation/todo.md](../windowing-structure-consolidation/todo.md))

- [ ] Classify candidates; WindowCoordinator/WindowRegistry dependency analysis
- [ ] #78 follow-ups from PR #90
- [ ] Amp: `Size2D.quantizedDelta` for the 6 resize sites; `SkinSprites.characterSpriteName(for:)` for the 10 `CHARACTER_` sites; move the 2 Utilities/ window files
- [ ] WindowSizeState protocol
- [ ] #78 docs-only fixes (may land any time)
- [ ] Move, xcodegen, TSan, manual multi-window checks, PR

## SS-4 Features/Milkdrop/ consolidation ([tasks/milkdrop-feature-consolidation/todo.md](../milkdrop-feature-consolidation/todo.md))

- [ ] Map the Swift files and resources; decide the Winamp prefix and `Butterchurn/test.html`
- [ ] Move, update `project.yml:25` and exclude the moved folder from the `MacAmpApp` sources entry, xcodegen, TSan, verify Butterchurn in Debug and a packaged Release build, PR

## SS-5 Features/ consolidation (no folder yet)

- [ ] Create `tasks/features-consolidation/` from SS-0's map
- [ ] Move each feature area; xcodegen, TSan, manual smoke per window; PR
- [ ] Amp (optional): `tileRow` helper for the tiled title-bar chrome

## SS-6 Audio/ consolidation (no folder yet)

- [ ] Create `tasks/audio-consolidation/` from SS-0's map
- [ ] Move; xcodegen, TSan, local/stream/video/Butterchurn smoke; PR

## SS-7 App/, Core/, Shared/ and composition root (no folder yet)

- [ ] Create `tasks/app-core-shared-consolidation/`, seeded from `tasks/done/playlistwindow-layer-decomposition/depreciated.md` §3-4
- [ ] Amp: composition root in App/ injects WindowCoordinator and AppSettings and retires the `.shared`/`.instance()` call sites; shared window-controller init
- [ ] Replace the PlaylistWindowActions singleton; drop the manual selection sync
- [ ] Move Core/ and Shared/ files; delete ViewModels/ and Utilities/; xcodegen, TSan, manual multi-window and menu checks; PR

## SS-8 Mirror tests to source layout (no folder; tracked in [tasks/swift-project-structure-research/todo.md](../swift-project-structure-research/todo.md))

- [ ] Move the test files; xcodegen; full TSan suite green with the same count; update `docs/context/xcode-testing-context.md`
- [ ] Follow-up commit: the SS-8 rows in `deferred.md` (`Task.sleep` determinism, Swift Testing follow-ups)

## SS-9 Local packages (optional, no folder)

- [ ] Evaluate after the sprint; go/no-go

## S4-1 macOS 27 / Swift 6.4 adoption ([tasks/swift64-macos27-readiness/todo.md](../swift64-macos27-readiness/todo.md))

- [ ] Research half (any time, no code): Swift 6.4, SwiftUI, macOS 27 AppKit/WebKit/AVFoundation/AVAudioEngine
- [ ] Record D-TARGET27 as ADR-1
- [ ] Impact matrix; plan.md with an adopt/defer call per item; Swift 6.4 language-mode ADR
- [ ] Deprecations, recounted from a build log; `xcodeVersion` fix
- [ ] Amp: delete the unused spriteResolver environment helpers; drop Skin's `@unchecked Sendable`
- [ ] Amp: ring-buffer overrun fix and doc comment; overrun-during-read TSan stress test; replace `withKnownIssue`
- [ ] Fallback: root `Package.swift` deletion and version pins, if S3-4 C1 did not land them
- [ ] Span/InlineArray, `-strict-memory-safety`, strict-concurrency leftovers (P-2, P-3, `nonisolated(unsafe)`, `Task.detached`)
- [ ] Remaining S4-1 items in `tasks/_context/deferred.md`
- [ ] One `/codex:review --base main`, PR; owner merges

## S4-2 GitHub issues ([tasks/github-issues-triage/todo.md](../github-issues-triage/todo.md))

- [ ] Re-fetch the issues; reproduce each on HEAD; record in research.md
- [ ] plan.md: fix per issue, file-conflict map, merge order, S4-1 conclusions; owner sign-off
- [ ] #47 fix, PR
- [ ] P-6 fix, PR; close P-6 in `tasks/done/avplayer-native-video-dsp/placeholder.md` and `tasks/_context/deferred.md`
- [ ] #79 fix (document types, drop handling, Cmd+O content types), PR
- [ ] #84 fix, PR; update the skin docs
- [ ] VideoPlaybackController `timeControlStatus` residual
- [ ] RemoteLayerTree warning: act only if it recurs without a debugger
- [ ] Close each issue with its PR link; `git mv` the folder to `tasks/done/`

## S4-3 AirPlay route picker (no folder yet)

- [ ] Create `tasks/airplay-route-picker/`; seed research.md with the inputs listed in plan.md
- [ ] Plan, implement, one `/codex:review --base main`, PR

## S4-4 Multichannel video output, #88 ([tasks/video-multichannel-output/todo.md](../video-multichannel-output/todo.md))

- [ ] Experiments 1-4
- [ ] Passthrough route check before pinning more than 2 channels
- [ ] plan.md; implement with layout-mapping and fold-math tests; ear checks; one `/codex:review --base main`; PR

## AT-1 #86 test isolation (no folder)

- [x] Pin `repeatMode` and restore the saved value in PlaylistNavigationTests; reproduce and verify; TSan 137/21; PR #92 closing #86
- [ ] Owner merges PR #92

## AT-2 Timer common-mode helper (no folder; after S3-4, best in SS-7)

- [ ] Add the helper, migrate the 7 sites, TSan, manual visualizer/timer/Butterchurn check, PR

## BL-1 Visualizer fidelity audit (no folder)

- [ ] Create the folder when started; RMS/Goertzel parity test first (amp); then the fidelity research and fixes
- [ ] Shade-strip bars stuck at max (deferred.md)

## Owner

Owner decisions: see `tasks/_context/state.md` (Owner decisions pending); plus: ask for the `_context/` rewrite and folder moves to be committed.

## Housekeeping

- [x] Archive `_context/plan.md`, `_context/research.md` and `_context/s3-2-pivot.md` into `tasks/_context/depreciated/` (`waves-1-3-plan.md`, `waves-1-3-research.md`, `s3-2-pivot.md`); references in `tasks/done/avplayer-native-video-dsp/` repointed
- [x] Move the 11 vaer review-scratch folders to `tasks/stale/`; the `airpods-route-gate-validation` path in `s3-2-pivot.md` points there
- [x] Move pr81-gemini-timer-feedback, audioplayer-decomposition, lock-free-ring-buffer, visualizerpipeline-decomposition, agent-docs-history-search and ios-port-feasibility-research to `tasks/done/`
- [x] Rename `deprecated.md` to `depreciated.md` in windowing-structure-consolidation, milkdrop-feature-consolidation and streamdecodepipeline-decomposition
- [x] Move audioplayer-decomposition's 2 open swiftlint suppression items into `tasks/audioplayer-seek-extraction/todo.md`
- [x] Add the SUPERSEDED banner (`146a8b4`) to `tasks/done/visualizerpipeline-decomposition/state.md`
- [x] Mark `tasks/done/pr81-gemini-timer-feedback/state.md` shipped via PR #83 (`1d24258`)
- [x] Fix the build-config claim in `tasks/done/ios-port-feasibility-research/research.md` to macOS 27.0
- [x] Rewrite `tasks/_context/` state.md, deferred.md, research.md, depreciated.md, tasks_index.md and resume-prompt.md to the new layout
- [x] Refresh the active task folders with the 2026-10-02 corrections (anchors, S3-2 = PR #89, arm64-only OGG, one `/codex:review` gate, #78 out of S4-2, amp items)
- [x] Add a one-line PAUSED-AS-REFERENCE banner to `tasks/video-audio-engine-routing/state.md` and `todo.md`; change nothing else
- [x] Delete the local gitignored residue `tasks/video-audio-engine-routing/spike/.build` (already absent)
- [x] Note on the title line of `tasks/_context/instruments-allocations-workflow.md` that it is not yet re-checked on Xcode/Instruments 27
