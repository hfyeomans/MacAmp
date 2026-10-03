# Research: AudioPlayer Seek Extraction

Updated: 2026-10-02

Seek-state coupling map for `MacAmpApp/Audio/AudioPlayer.swift`. Line numbers are at `b3894d9`; PR #91 (-4 lines) and S3-4 will move them, so re-measure at post-OGG HEAD (`plan.md` step 0).

## File

- 1,097 lines. `@Observable @MainActor final class AudioPlayer`.
- Suppressions: `// swiftlint:disable file_length` (`:1`), `// swiftlint:disable:this type_body_length` (`:9`).
- SwiftLint counts lines without comments and whitespace. Linting a copy with both suppressions removed gives `file_length` 758 (warns at 600, errors at 1,200) and a class body of 750 (`type_body_length` warns at 400, errors at 600), so the type suppression hides an error. Thresholds: `.swiftlint.yml:58-69`.
- The atomic unit (`:54-56`, `:422-428`, `:783-847`, `:965-976`, `:992-1040`) is about 109 of those counted lines. `AudioPlayer` keeps the `seek`/`seekToPercent` facade, so both counts end near 650 after extraction: `file_length` still warns and `type_body_length` still errors.
- `closure_body_length` (warns at 30) also fires at `:246` (32, video tap) and `:995` (32, the `onPlaybackEnded` closure, part of the atomic unit).
- SwiftLint is not in the build or CI; `.githooks/pre-commit` lints staged Swift files with `--strict`, where warnings fail.

## Section map

| Lines | Section | Seek-related |
|---|---|---|
| :15-48 | Engine controller (`engine` `:16`), extracted controllers, video-tap balance fan-out | — |
| :49-69 | Playback state | Guard vars `:54-56`, `pendingReconfigureSnapshot` `:63` |
| :70-175 | Stream bridge state, volume/balance and their video-tap fan-out, playlist, video, callbacks (`onPlaylistAdvanceRequest` `:151`, `onPlaybackFinished` `:152`) | Callbacks fired by `onPlaybackEnded` |
| :176-300 | Video Tap (in-place DSP on the AVPlayer audio path) | — |
| :301-333 | Equalizer forwarding | — |
| :334-401 | Init/deinit | Wires `engine.onPlaybackEnded` (`:363`), reconfigure callbacks (`:369-374`), video `onPlaybackEnded` (`:384`) |
| :402-429 | State machine: `transition(to:)` `:404`, `shouldIgnoreCompletion` `:422` | Core seek |
| :430-611 | Track management: `playTrack` `:511`, `detectMediaType` `:579`, `loadAudioFile` `:584` | Writes guards |
| :612-734 | Transport: `play` `:614`, `pause` `:652`, `stop` `:683`, `eject` `:716` | Writes guards |
| :735-782 | EQ and stream-bridge forwarding | — |
| :783-847 | Seeking: `seekToPercent` `:785`, `seek` `:801` | Core seek |
| :848-976 | Engine reconfiguration: `cancelPendingReconfigure` `:863`, `handleEngineWillReconfigure` `:883`, `handleEngineDidReconfigure` `:915`, `videoSeekCompletion` `:965` | Writes all three guards; `videoSeekCompletion` is core seek |
| :977-991 | Visualizer forwarding | — |
| :992-1040 | Playback completion: `onPlaybackEnded` `:994` | Core seek |
| :1041-1101 | Playlist navigation: `handlePlaylistAction` `:1080` | Calls `seek(to: 0)` at `:1085` |

## Guard access map

34 lines reference the three vars (2 of them comments, :857 and :902).

| Var | Reads | Writes |
|---|---|---|
| `currentSeekID` (`:54`) | `shouldIgnoreCompletion` `:423`; passed to `engine.scheduleFrom` in `loadAudioFile` `:588`, `stop` `:698`, `seek` `:821`, `handleEngineDidReconfigure` `:928` | `playTrack` `:520`, `loadAudioFile` `:587`, `stop` `:697`, `seek` `:815`, `handleEngineWillReconfigure` `:905` |
| `seekGuardActive` (`:56`) | `shouldIgnoreCompletion` `:424` | true: `playTrack` `:521`, `seek` `:814`, `handleEngineWillReconfigure` `:906`. false: `playTrack` `:528` (50 ms) and `:538`, `play` `:648`, `pause` `:679`, `stop` `:712`, `seek` `:844` (100 ms), `cancelPendingReconfigure` `:865`, `handleEngineDidReconfigure` `:951` (100 ms), `onPlaybackEnded` `:1032` |
| `isHandlingCompletion` (`:55`) | `onPlaybackEnded` `:997` (re-entrancy guard) | true: `handleEngineWillReconfigure` `:907`, `onPlaybackEnded` `:1001`. false: `cancelPendingReconfigure` `:866`, `handleEngineDidReconfigure` `:955` (200 ms), `onPlaybackEnded` `:1036` (200 ms) |

`play`, `pause`, `stop`, `seek` and `playTrack` call `cancelPendingReconfigure()` first.

## Completion call chain

```text
engine.scheduleFrom(time:seekID:) -> playerNode segment ends
  -> engine.onPlaybackEnded?(seekID) -> AudioPlayer.onPlaybackEnded(fromSeekID:)
    -> shouldIgnoreCompletion(from:)

nil seekID callers:
  videoPlaybackController.onPlaybackEnded (:386)
  play() at end of track (:635)
  seek() when scheduling fails, after 150 ms (:836)
```

## What the atomic unit touches outside seek state

- `seek`: reads `currentMediaType`, `isPlaying`; writes `currentTime`, `playbackProgress`; calls `transition(to:)`.
- `onPlaybackEnded`: calls `transition(to:)`, `visualizerPipeline.stopVideoVisualization()` (video), `engine.invalidateProgressTimer()`, writes `playbackProgress` and `currentTime` (engine file duration for audio, `currentDuration` for video), calls `nextTrack()` and fires `onPlaylistAdvanceRequest` or `onPlaybackFinished`, calls `engine.removeVisualizerTapIfNeeded()` when not playing.
- `videoSeekCompletion`: writes `currentTime`, `playbackProgress`, `currentDuration`; calls `transition(to:)`.
- `transition(to:)` has 17 call sites in the file.
- Engine members used: `audioFile`, `currentFileDuration`, `scheduleFrom`, `invalidateProgressTimer`, `startEngineIfNeeded`, `installVisualizerTapIfNeeded`, `playAudio`, `startProgressTimer`, `removeVisualizerTapIfNeeded`.

## External callers

- `MacAmpApp/Views/MainWindow/WinampMainWindowInteractionState.swift:97`: `seekToPercent(progress, resume:)` (slider scrub).
- `MacAmpApp/Audio/PlaybackCoordinator.swift:582`: `seek(to:)` (Now Playing remote command).
- Streams do not use `AudioPlayer.seek`.

## Test coverage

- `AudioPlayerStateTests` has 17 tests, including the Phase 4 characterization block. None exercises seek.
- `VideoSeekStateMatrixTests` covers `VideoPlaybackController.seek`, not `AudioPlayer`.
- `EngineConfigObserverTests` covers the observer, not `AudioPlayer`'s handlers.
- No test references `currentSeekID`, `seekGuardActive`, `isHandlingCompletion` or `cancelPendingReconfigure`.

## Prior review input

- Oracle, Phase 4 (2026-03-22): "Keep seek state machine in AudioPlayer for this phase, unless you also move onPlaybackEnded completion filtering as one atomic unit. Partial move is the risky path."
- Oracle preferred a separate `SeekController` over growing `AudioEngineController`: engine transport and the seek state machine are distinct responsibilities.
