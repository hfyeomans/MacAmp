# Research: StreamDecodePipeline Decomposition

Updated: 2026-10-02

Responsibility map and constraints for SS-2. Line numbers are at `b3894d9`; S3-3 and S3-4 will move them (`plan.md` step 1).

## File

`MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`: 825 lines. Imports `Foundation`, `AudioToolbox`, `@preconcurrency import os`.

| Type | Lines | Notes |
|---|---|---|
| `StreamDecodePipeline` (`@MainActor final class`) | :25-515 | Lifecycle, HTTP, completion, playlist resolution, format hint, DEBUG test seams |
| `DecodeContext` (`private final class`, `@unchecked Sendable`) | :525-783 | Queue-confined decode chain; DEBUG test seams at :768-782 |
| `SessionDelegateProxy` (`private final class`, `NSObject`, `URLSessionDataDelegate`, `@unchecked Sendable`) | :792-825 | Forwards delegate callbacks to closures set once in init |

SwiftLint (comments and whitespace excluded): `file_length` 555, under the 600 warning; no suppressions in the file. `startDirectStream` (:148) warns on `function_body_length` (72 lines, limit 60). `.githooks/pre-commit` lints staged files with `--strict`, where warnings fail.

## Section map: StreamDecodePipeline

| Lines | Section | Extractability |
|---|---|---|
| :27-52 | `StreamState`, `StreamTerminationReason` | Stays; `StreamPlayer.swift:691` extends `StreamTerminationReason` with `userMessage` |
| :53-63 | Callbacks to `StreamPlayer` | Inherent |
| :64-84 | Ring buffer, audio workgroup (`setAudioWorkgroup` :76, `nonisolated(unsafe)` :79) | Coupled to `decodeContext` and `decodeQueue` |
| :85-109 | Decode context, URLSession, generation token (`generation` :100), prebuffer tracking (`formatReadyFired` :104) | Inherent |
| :110-310 | Lifecycle: `start` :112, `startDirectStream` :148, `pauseByUser` :240, `resumeByUser` :257, `stop` :275, `stopInternal` :290, `setState` :306 | Core; stays |
| :311-357 | HTTP response: `handleHTTPResponse` :313, `extractICYMetaInt` :346 (`nonisolated static`) | Pure static helper |
| :358-390 | Stream completion: `handleStreamComplete` :360 | Self-contained |
| :391-467 | Playlist resolution: `isPlaylistURL` :394, `resolvePlaylistURL` :401, `parsePLS` :437, `PlaylistResolveError` :456; uses `M3UParser` | All `private static`, no instance state; called only from `start` |
| :468-482 | `formatHint(for:)` :470 | `private static` |
| :483-514 | DEBUG test seams | Move with what they test |

## DecodeContext

- Owns `ICYFramer`, `AudioFileStreamParser` and `AudioConverterDecoder`, and writes the `LockFreeRingBuffer`.
- Entry points: `configureFramer` :608, `handleIncomingData` :617, `setPausedByUser` :643, `resetPrebufferTracking` :657, `shutdown` :668. Private: workgroup join/leave :685/:691, `handleFormatAvailable` :698, `handlePackets` :719.
- State includes `formatReadyFired` (:535) and the user-pause gate `isPausedByUser` (:540).
- Confinement today: the doc comment (:519-524) says all mutable state is confined to the decode serial queue; `dispatchPrecondition` checks run at :586, :699 and :720. Fields are plain `var`s, so the render-thread contract's field rules do not apply as written.
- `QueueConfined` (`Audio/Streaming/QueueConfined.swift`) provides a DEBUG `assertConfinement()`; `AudioFileStreamParser` and `AudioConverterDecoder` adopt it, `DecodeContext` does not.

## Concurrency contract (ADR-3a)

`docs/MACAMP_ARCHITECTURE_GUIDE.md` § Audio Mechanism Concurrency Contract (:1510). `@unchecked Sendable` is acceptable only as a gated exception: the boundary needs it, the contract is written at the top of the type, stored fields are restricted, and tests enforce it. `VideoTapContext` (enforced by `VideoTapSendableContractTests`), `VisualizerFeed`, `VisualizerScratchBuffers` and `BiquadCascade` (via the `RenderThreadSafe` marker in `Audio/RenderThreadSafe.swift`) follow it. `DecodeContext` is named as the next retrofit (:1514).

## Threading

| Context | Runs |
|---|---|
| `@MainActor` | All `StreamDecodePipeline` API and state |
| Decode serial queue | `DecodeContext`: framer, parser, decoder, ring-buffer writes |
| URLSession delegate queue | `SessionDelegateProxy` callbacks (`onResponse`, `onData`, `onComplete`) |
| Render thread (outside this file) | Ring-buffer reads in the stream `AVAudioSourceNode` |

A generation token (`UInt64`, bumped on start and stop) makes every callback drop stale work.

## Consumers and tests

- `StreamPlayer` (`StreamPlayer.swift:47`) is the only owner. S3-3's `HLSSegmentFeeder` will read the generation and feed `DecodeContext.handleIncomingData` (:617) through an injected `@Sendable (Data) -> Void` closure, so no visibility widens.
- `StreamPauseTailTests` (9 tests) covers the pause gate through the DEBUG seams.

## Upcoming changes from S3-3 and S3-4

- **S3-3 HLS** (about +160/-10 lines): `classifyM3UDialect`, `startHLSStream`, an `OSAllocatedUnfairLock` generation snapshot, pause/resume dispatch to the feeder, and two non-reconnectable termination cases (`.streamFinished`, `.unsupportedFormat`). HLS bypasses `configureFramer` and `SessionDelegateProxy`; `HLSSegmentFeeder` carries its own fileprivate proxy.
- **S3-4 OGG** (about +250 lines): fileprivate `StreamBackend` (an enum, not a protocol), `PipelineLifecycle` and `StreamFormatHint` enums; new `DecodeContext` fields that store them (backend, lifecycle, sniffer, format hint, detected channels; OGG `plan.md` §16); `formatHint(for:)` becomes `formatHint(for:contentType:) -> StreamFormatHint`; the two `formatReadyFired` gates (:104 main actor, :535 decode queue) collapse to the decode-queue copy; an `onChainFormatChange` callback.
- Projected size after both: about 1,225 lines (825 + 150 + 250). At today's ratio of counted to raw lines (555/825) that is roughly 820 counted lines: past the 600 `file_length` warning, well below the 1,200 error. Neither plan splits the file; the split stays with this task.
