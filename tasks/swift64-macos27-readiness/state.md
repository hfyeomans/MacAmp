# State: Swift 6.4 / macOS 27 Adoption (S4-1)

Updated: 2026-10-02

**Status:** QUEUED. Research not started; implementation waits for the Structure Sprint.

## Purpose

Adopt what the macOS 27 minimum (D-TARGET27, PR #87) and the Xcode 27 / Swift 6.4 toolchain allow: clear the macOS 27 deprecations, adopt `Span`/`MutableSpan`/`InlineArray` where they fit, evaluate strict memory safety, and decide the Swift 6.4 language mode in its own ADR. The task also carries the amp-review items and S3-2 follow-ups slotted to S4-1 (Scope below). This file is the home for their mechanisms and line anchors.

## Gating

- The research half touches no code and may run any time.
- Implementation starts after the Structure Sprint, which starts after S3-4 `ogg-vorbis-support` merges.
- S4-1 runs before S4-2 `github-issues-triage` (D-S4, `tasks/_context/state.md`). S4-3 `airplay-route-picker` also follows S4-1.

## Toolchain and pins

| Axis | Value | Note |
|------|-------|------|
| Host | macOS 27.0 (26A428) | |
| Toolchain | Xcode 27.0 (27A5194q), Swift 6.4 | |
| Language mode | `SWIFT_VERSION: '6.2'` (`project.yml:38,66`) | 6.4 is this task's ADR |
| Tools version | `swift-tools-version: 6.2` (root `Package.swift`) | Root manifest is slated for deletion; after S3-4 the remaining manifest is `Vendor/COggVorbis/Package.swift` |
| Deployment target | macOS 27.0 (`project.yml:5`) | Decided (D-TARGET27); no `#available`/`@available` gates remain in `MacAmpApp/` |
| `xcodeVersion` | `'26.0'` (`project.yml:6`) | Cosmetic drift; bump to 27 here |
| Test baseline | 137 tests in 21 suites pass under TSan on `main` | Run 2026-10-02 on Xcode 27 |

The Swift module is `MacAmp` (`PRODUCT_NAME`); `MacAmpApp` is the scheme. Anchors below are from `main` at `b3894d9`; the Structure Sprint will move files, so re-resolve them at pickup.

## Scope

### macOS 27 deprecations (warnings deferred from #87/#89)

- `AVAudioEngine.connect(_:to:format:)`: 12 sites in `MacAmpApp/Audio/AudioEngineController.swift` (lines 155-554). The #87 record counted 10.
- `AVAudioPlayerNode.play()` at `AudioEngineController.swift:295`; `auAudioUnit` (use `withAUAudioUnit`) at `:231`.
- `installTap(onBus:)` at `MacAmpApp/Audio/VisualizerPipeline.swift:123`.
- `.AVPlayerItemDidPlayToEndTime` (use `AVPlayerItem.didPlayToEndTimeNotification`) at `MacAmpApp/Audio/VideoPlaybackController.swift:145`.
- Test-only: `connect` x2 at `Tests/MacAmpTests/BiquadNumericalMatchTests.swift:246-247`.
- Recorded as 14 production + 2 test-only; recount from a build log at pickup.

### Language, concurrency and memory safety

- Adopt `Span`/`MutableSpan`/`InlineArray` in the DSP and visualizer buffers.
- Evaluate `-strict-memory-safety`.
- Swift 6.4 language-mode ADR: `SWIFT_VERSION` and tools-version together or staged, with rollback; the fate of the ADR-3a containment gates (header contract, `RenderThreadSafe`, Gate 3a/3b/3c tests) and of `Synchronization.Atomic`/`Mutex` in `MacAmpApp/Audio/VideoDSP/`.
- Default MainActor isolation (T8 Phase 5): questionable ROI; decide in the language-mode ADR. Blast radius: `tasks/done/swift-concurrency-62-cleanup/research.md`.
- Strict-concurrency leftovers: `nonisolated(unsafe)` x1 (`MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift:79`) and `Task.detached` x3 (`MacAmpApp/Views/PlaylistWindowActions.swift:103/257/288`; SS-7 may replace that singleton first).
- S3-2 P-2: `Mirror` cannot inspect `~Copyable` fields in the `VideoTapContext` Sendable-contract test (`Tests/MacAmpTests/VideoTapSendableContractTests.swift`, Test 3a). Revisit under 6.4 and strict memory safety.
- S3-2 P-3: `@preconcurrency import AVFoundation` in `MacAmpApp/Audio/VideoDSP/VideoTap.swift:1` and `MacAmpApp/Audio/AudioEngineConfigurationObserver.swift:1`. Drop it if the macOS 27 SDK annotations allow.
- P-2 and P-3 details: `tasks/done/avplayer-native-video-dsp/placeholder.md`.

### Amp-review items

- **Skin Sendable.** Only `Skin` is `@unchecked Sendable` (over `[String: NSImage]`, `MacAmpApp/Models/Skin.swift:10`). `SpriteResolver` is plain `Sendable` (`MacAmpApp/Models/SpriteResolver.swift:97`) and stores a `Skin` (`:98`). Delete the unused environment helpers (`SpriteResolver.swift:396-421`: `SpriteResolverKey`, `EnvironmentValues.spriteResolver`, `View.spriteResolver`; no callers) together with the MARK and `import SwiftUI` above them (`:392-394`), which only the helpers use. Then drop `@unchecked Sendable` from `Skin`; `SpriteResolver` loses `Sendable` with it.
- **LockFreeRingBuffer overrun race.** `writeHead` and `readHead` are already `ManagedAtomic` (`MacAmpApp/Audio/LockFreeRingBuffer.swift:23-24`). On overrun the producer advances `readHead` (`:83`) and then `memcpy`s into frames the consumer may still be reading (`:95-97`): a formal data race. Fix: drop-newest on overrun, or a documented accepted-loss contract. Rewrite the class doc comment (`:4-16`) to match: its "Known race (accepted)" paragraph (`:12-16`) is wrong, it calls the decode-queue producer real-time (`:7`), and its worst case is out of date (a zero-filled quantum since the `readHead` CAS in `c6a5b23`).

### Ring-buffer follow-ups

- Move `ManagedAtomic` (swift-atomics) to `Synchronization.Atomic`. Dropping the dependency also means migrating the stream silence gate in `AudioEngineController.swift` (`:53,338,377,397`) and the `ManagedAtomic` uses in `StreamPauseTailTests` and `LockFreeRingBufferTests`.
- Replace the `withKnownIssue(isIntermittent: true)` wrapper on the "High throughput" test (`Tests/MacAmpTests/LockFreeRingBufferTests.swift:440`) once overrun behavior changes.
- Add a TSan stress test for overrun during an active read.
- Replace the ring capacity hard-coded at 4 sites (32,768 frames, `MacAmpApp/Audio/StreamPlayer.swift:130/197/471/573`) with one named constant.
- Add unit tests for `activateStreamBridge` / `deactivateStreamBridge` (`MacAmpApp/Audio/AudioEngineController.swift:391/453`).
- Optional: benchmarks (write/read under 1 µs at 512 frames, zero hot-path allocations), using `tasks/_context/instruments-allocations-workflow.md`. Allocations runs on Debug builds only (`tasks/_context/research.md`).

### Root Package.swift (fallback)

S3-4 decides this in commit C1 on `feat/ogg-vorbis-support`: delete root `Package.swift`, `Package.resolved` and the `.swiftlint.yml:44` exclude, and in the same change pin exact ZIPFoundation and swift-atomics versions in `project.yml`, because `Package.resolved` is the only tracked lockfile (`MacAmpApp.xcodeproj` is gitignored). It pins zipfoundation 0.9.20 and swift-atomics 1.3.0 today. If S3-4 did not land it, do it here.

### Other inputs

- Passthrough guard (`tasks/done/unified-audio-pipeline/todo.md:142`, item 2.3): confirm stream decode output stays Float32 PCM if `AVAudioContentSource_Passthrough` can deliver encoded frames. HDMI/optical-only risk. The macOS 27 SDK header describes it as an encoder content-source value (`AVFAudio/AVAudioSettings.h:110`), so check whether the risk is real.
- NSMenu "Internal inconsistency" console warnings (system-injected text menus in SwiftUI/AppKit bridging): harmless; recheck on macOS 27.

## Owner decisions affecting this task

Listed in `tasks/_context/state.md` (Owner decisions pending).

- **Appearance Mode:** Liquid Glass work here happens only if the owner keeps the Material/Liquid Glass preferences (`materialIntegration`, `enableLiquidGlass` in `MacAmpApp/Models/AppSettings.swift`).

## Next step

Phase 0 research (`todo.md`).
