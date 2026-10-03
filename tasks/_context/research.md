# Cross-Task Research

Updated: 2026-10-02

Findings that inform `plan.md` and apply across tasks. Open work from these findings is tracked in `deferred.md`; superseded approaches are in `depreciated.md`. Line counts are at `main` `b3894d9`.

## Amp code review (2026-10-02)

Checked against `main` at `f12bb7b`. Slotted items have a row in `deferred.md`. The amp text is a summary of the read-only review on the local branch `review/codebase-audit-2026-09` (`4c3702d`, 2026-09-08); its finding 8 (pass-through facades) was not in the summary and is slotted below.

| Finding | Verdict | Reason or slot |
|---------|---------|----------------|
| Pass-through facades: about 25 one-line forwarders in `AudioPlayer`, about 30 in `WindowCoordinator`, and the `PlaybackCoordinator → AudioPlayer → AudioEngineController` stream-bridge chain (Principle 6) | Slotted | SS-1 (AudioPlayer), SS-7 (WindowCoordinator), SS-2/SS-6 (stream bridge) |
| Dead `EqualizerController.useLogScaleBands` and its `AudioPlayer` forwarder | Fixed (#91, `30d9de3`) | `chore/amp-review-dead-code` (`a032bcd`); still on `main` until the owner merges |
| Dead `EqualizerController.autoEQTask` | Fixed (#91) | |
| Unused `AppSettings.shouldPreserveWinampChrome` and `shouldUseFullSystemMaterials` | Fixed (#91) | |
| Chat transcripts committed at the repo root | Fixed | `b3894d9`: moved to the gitignored `chats/` |
| `module-cache/` and `weak_struct` tracked | Fixed | `b3894d9`: untracked and ignored |
| Root `Package.swift` cannot build (mixed Swift and ObjC with a bridging header, no Butterchurn resources) | Slotted | S3-4 commit C1, with exact version pins in `project.yml`; fallback S4-1 |
| `Skin`/`SpriteResolver` are `@unchecked Sendable` | Slotted, corrected | S4-1. Only `Skin` is `@unchecked Sendable`; `SpriteResolver` is plain `Sendable` |
| LockFreeRingBuffer overrun race; fix with "drop-newest or atomics on both heads" | Slotted, corrected | S4-1. Both heads are already `ManagedAtomic`; the race is the producer's storage write over unread frames, so the fix is drop-newest (or a documented accepted-loss contract) |
| Quantized 25x29 resize math in 3 places | Slotted | SS-3 |
| AppKit window files in `Utilities/` | Slotted | SS-3 |
| TEXT.BMP glyph naming duplicated | Slotted | SS-3, extended to `MainWindowIndicatorsLayer` and `SpriteResolver` |
| Tiled title-bar chrome in 4 places | Slotted, optional | SS-5 |
| Two access paths to shared objects; 5 window controllers repeat the same init | Slotted, corrected | SS-7. `WindowCoordinator.shared` has 24 refs app-wide (21 in `Views/`), not ~22 |
| Files in `Models/`, `ViewModels/` and `Utilities/` that belong elsewhere | Slotted | SS-0 map |
| RMS/Goertzel computed twice | Slotted | BL-1, parity test first |
| Unused StreamPlayer `...ForTesting` DEBUG seams | Slotted, optional | S3-3 Phase 6 deletes the two with no callers; the other seams are test-only with no Release impact |
| #86 test reads the real UserDefaults Repeat setting | Fixed (#92, `f7c480c`) | The test pins repeat mode |
| Appearance Mode preferences only restyle the Preferences window | Fixed (#91): removed with the Preferences window and Cmd+, (owner, 2026-10-02, after two adversarial reviews) | |
| Git history still holds `new-architecture-convresation.md` and `module-cache/` | Owner decision | `tasks/_context/state.md`; a purge needs a force-push to `main` |
| DockingController and its broken menu items | Rejected, stale | Deleted in PR #90 (`757fc8d`) |
| macOS 15/26 deployment-target mismatch | Rejected, stale | The target is 27.0 since #87 |
| Redundant `#available` checks | Rejected, stale | Removed in #87; none remain in `MacAmpApp/` |
| `SkinnedText`, `areConnected`, `DockPaneState.position`, `snapDistance` | Rejected, stale | Deleted in PR #90: `SkinnedText` in `7523b6d`, `areConnected` in `46e3056`, `DockPaneState` and `snapDistance` with DockingController in `757fc8d` |
| Title-bar buttons duplicated four times | Rejected, stale | PR #90 (`7523b6d`) replaced them with `SkinHitButton` hit areas over the skin bitmaps (`MacAmpApp/Views/Shared/SkinHitButton.swift`) |
| `didSet` UserDefaults persistence blocks | Rejected | The documented house pattern (single source of truth) |
| Playlist model under `Audio/` | Rejected | Follows the approved placement policy |

## Fired growth triggers

| File | Lines | Trigger | Status | Re-evaluate in |
|------|------:|---------|--------|----------------|
| `MacAmpApp/Audio/AudioPlayer.swift` | 1,097 | D8 Option B: over 800 lines; a new responsibility; seek logic testable on its own | Two of three fired: size, and the video-tap and engine-reconfigure sections. Testability has not (`tasks/audioplayer-seek-extraction/state.md`) | SS-1 |
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` | 825 | Over 800 lines, or a new responsibility | Size fired. The plans add ~150 (HLS) and ~250 (OGG) net, about 1,225 raw / ~820 SwiftLint-counted lines, past the 600 `file_length` warning and below the 1,200 error; both plans forbid splitting it | SS-2 |
| `MacAmpApp/Audio/VisualizerPipeline.swift` | 416 | Over 800 lines; a new consumer needs the shared buffers; the audio-thread model changes | The consumer trigger fired and S3-2 Phase 1 (`146a8b4`) resolved it; the others have not fired | None |

Largest files (at `30d9de3`): AudioPlayer 1,097; StreamDecodePipeline 825; StreamPlayer 714; PlaybackCoordinator 587; AudioEngineController 580; SkinSprites 487; SkinManager 441; SpriteResolver 421; VisualizerPipeline 416; WinampEqualizerWindow 365. `MacAmpApp/` has 121 `.swift` files and `Tests/MacAmpTests/` has 21.

SwiftLint (`.swiftlint.yml:58-69`): `type_body_length` warns at 400 and errors at 600; `file_length` warns at 600 and errors at 1,200, ignoring comment-only and blank lines. AudioPlayer suppresses both; SkinManager suppresses `type_body_length`.

## File-conflict map: S3-3, S3-4 and later

From the HLS plan §11 and the OGG plan §15, with paths and line counts checked at HEAD. Re-derive from both plans at S3-3 PF.3.

| File (lines) | S3-3 HLS | S3-4 OGG | Later |
|--------------|----------|----------|-------|
| `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift` (825) | +~160/-10: M3U classifier, HLS start, generation snapshot, 2 termination cases | ~+250 net: StreamBackend, PipelineLifecycle, StreamFormatHint, sniffer, `onChainFormatChange` | SS-2 |
| `MacAmpApp/Audio/StreamPlayer.swift` (714) | +~12: `isReconnectable`, `userMessage`; optional seam delete | ~20: `onMetadata` signature, `onStreamChainFormatChanged` | SS-6 move to `Streaming/`; AT-2 timer (`:358`) |
| `MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift` (186) | +~40: `reset()`, post-reset ASBD/magic-cookie compare, `parserFatalState` | none | none |
| `MacAmpApp/Audio/Streaming/ICYFramer.swift` (200) | none | `ICYMetadata` becomes a top-level `StreamMetadata` | none |
| `MacAmpApp/Audio/PlaybackCoordinator.swift` (587) | none expected | ~25: chain-format bridge rewire | SS-6 |
| `MacAmpApp/Audio/AudioEngineController.swift` (580) | none expected | ~120: `LocalAudioSource`, Vorbis load and schedule | SS-6; S4-1 deprecations; AT-2 timer (`:269`) |
| `MacAmpApp/Audio/AudioPlayer.swift` (1,097) | none expected | 4 `engine.audioFile != nil` sites (`:628/791/808/927`) become `hasLoadedSource` | SS-1 |
| `MacAmpApp/Audio/MetadataLoader.swift` (169) | none | ~80: `.ogg`/`.oga` branch | SS-0 placement |
| `MacAmpApp/Views/PlaylistWindowActions.swift` (318) | none | optional `.ogg`/`.oga` UTTypes | SS-7 singleton |
| `project.yml` | none | COggVorbis package, license resource, exact pins (C1) | SS-4 Butterchurn path (`:25`) |
| `Package.swift`, `Package.resolved`, `.swiftlint.yml:44` | none | Deleted, exclude removed (C1) | none |
| New `MacAmpApp/Audio/HLS/` | M3U8Parser, HLSSegmentFeeder | Rebases onto it | SS-0 places it |
| New `MacAmpApp/Audio/Vorbis/`, `Vendor/COggVorbis/`, `MacAmpApp/Audio/Streaming/StreamMetadata.swift`, `MacAmpApp/Resources/THIRD_PARTY_LICENSES.txt` | none | Adds them | SS-0 places them |

- **HLS-to-OGG seams** (HLS plan §17.1.1-17.1.2): HLS adds a fileprivate `makeStreamMetadata` factory so the OGG rename is a one-line edit; OGG turns the HLS `formatHint` into `.audioFileStream(kAudioFileAAC_ADTSType)`; HLS's `DecodeContext` starts in OGG's `.buffering` lifecycle state; HLS does not opt into `onChainFormatChange`. The OGG plan's rebase step (§20) applies §17.1.2.
- **Any-time items vs S3:** AT-2 edits StreamPlayer and AudioEngineController, which S3-4 also edits, so run it after S3-4 (plan.md puts it in SS-7). BL-1 (VisualizerPipeline, VideoTapVisualizerRender) and the S4-1 research half do not overlap S3. The #78 docs fixes and the S3-3 close-out both edit `docs/MACAMP_ARCHITECTURE_GUIDE.md`, in different sections.
- **Inside the Structure Sprint:** SS-3 and SS-4 both edit `MilkdropWindowChromeView` (SS-3's resize helper at `:173/:190`, SS-4's move); land one before branching the other. SS-5 moves `VideoWindowChromeView` only after SS-3. SS-1 and SS-2 split files in place before SS-6 moves them. Work after the sprint (S4-1 onward) uses the new paths, for example LockFreeRingBuffer under `Audio/Streaming/`.

## Toolchain and verification

- Build, test and sandbox commands are in `tasks/_context/state.md` (Verification).
- **Leak checks:** Instruments Allocations works only on Debug builds, because dylib injection is blocked on every hardened-runtime build. `xcrun heap <pid>` works on any build that carries `get-task-allow`. The Developer-ID Release build does not (`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`), but an Xcode Run injects `get-task-allow`, so a Release configuration launched from Xcode can be inspected with LLDB or `xcrun heap` without re-signing.
- **Procedure:** `tasks/_context/instruments-allocations-workflow.md` (WWDC24 session 10173). Filter Recorded Types with `MacAmp.` (the PRODUCT_NAME); `MacAmpApp.` matches nothing and reads as a false pass. The doc does not state the Debug-only limit above, and its UI steps have not been re-checked on Xcode/Instruments 27. S3-3 Phase 7 (P7.6b) and S3-4 C9 use it.
- **LLDB:** the Xcode IDE MCP (`RunProject` with the debugger, `InvokeDebuggerCommand`, `GetConsoleOutput`, `StopProject`) for a run Xcode launches; `xcodebuildmcp debugging attach --pid` for a process that is already running (needs `get-task-allow`). The xcodebuildmcp daemon does not auto-start in the sandboxed shell. Set breakpoints by symbol: the S3-2 telemetry breakpoint `EqualizerController.swift:106` (in `pollVideoTapSampleRates`) shifts when PR #91 merges.
- **Test corpus:** `clapperboard-videos/` holds 5 tracked clips (about 3 s each, one surround) used by the video-tap tests and the Instruments recipe; suitable for the S4-4 experiments.

## Platform and design findings

- **AirPlay and routes (input to S4-3):** on macOS, AVRoutePickerView routes a single AVPlayer and cannot redirect AVAudioEngine (S2, `tasks/done/airplay-integration/`). `AVAudioEngineConfigurationChange` fires only when the engine's I/O format changes, not on general route changes, so route awareness needs a HAL default-output listener (`tasks/stale/airpods-route-gate-validation/`); none exists in `MacAmpApp/`. AVRoutePickerView has never been in `MacAmpApp/` or `Tests/`; the commits that mention it touch only docs and task files.
- **HAL log noise:** `!obj`, `!dev` and `nope` lines on AirPlay-to-built-in switches are OS device-teardown chatter (Apple's own apps print the same), not a MacAmp bug.
- **D-TARGET27 APIs:** only `MTAudioProcessingTapCreateWithPreferredFormat` is in use (`MacAmpApp/Audio/VideoDSP/VideoTap.swift:289`). S4-1 candidates: whole-mix taps (`AVAudioMixInputParametersTrackMixID`), `InlineArray`, `Span`/`MutableSpan`, `Array.mutableSpan` and `-strict-memory-safety`. No `#available` or `@available` remains in `MacAmpApp/`.
- **S3-2 CPU gate:** the automated 8.1 pass is a Debug (`-Onone`) regression guard, p99 about 11% of the 21,333 µs deadline. The real gate, 8.1b (Release plus Time Profiler), is PARTIAL: `tapProcess` costs about 0.4-1.0% of the budget. Never summarize it as "the CPU gate passed". Record: `tasks/done/avplayer-native-video-dsp/verification.md`.
- **Swift 6.2 isolation:** closures defined inside `@MainActor` methods inherit that isolation, so real-time render and tap blocks come from `nonisolated static` factories (`AudioEngineController.makeStreamRenderBlock`, `VisualizerPipeline.makeTapHandler`).
- **Principle 4 applied to the amp items:** RMS/Goertzel is a second occurrence, so a parity test fits better than an extraction. The quantized resize math (3 views, 6 sites) and the tiled chrome (4 views) are past the Rule of Three, so extraction is justified.
- **Debugging lessons from S3-1A:** diagnose the whole pipeline, since symptoms show at the consumer while causes often sit at the producer; and run a structural search (ast-grep) before editing setter chains or timers. Both are in `BUILDING_RETRO_MACOS_APPS_SKILL.md:577-579`.
