# Research: AudioPlayer Seek Extraction

> **Description:** Responsibility map focused on seek state machine extraction from AudioPlayer.swift.
> **Updated:** 2026-03-24 (responsibility map complete — reflects current 740 lines post-S2)

---

## File Overview

**File:** `MacAmpApp/Audio/AudioPlayer.swift`
**Lines:** 740 (grew from 719 at planning time — S2 added stream-track-counter and Now Playing hooks)
**Class:** `AudioPlayer` — `@Observable @MainActor final class`

## SwiftLint Suppressions

| Line | Suppression |
|------|-------------|
| 1 | `// swiftlint:disable file_length` |
| 9 | `// swiftlint:disable:this type_body_length` |

Both removed when file drops below ~600 lines.

---

## Line Count Breakdown by Section

| Section | Lines | Content | Seek-Related? |
|---------|-------|---------|---------------|
| A: Imports/decl | 9 | Boilerplate | swiftlint suppressions |
| B: Controllers | 10 | Engine, EQ, Viz refs | No |
| C: Viz props | 20 | Forwarding | No |
| D: Playback state | 15 | Properties | **3 seek vars** |
| E: Misc props | 86 | Volume, playlist, video, EQ | No |
| F: Init/deinit | 54 | Setup + callbacks | **Wires seek callbacks** |
| G: State machine | 27 | transition + shouldIgnore | **shouldIgnoreCompletion** |
| H: Track mgmt | 74 | Add/remove tracks | No |
| I: playTrack | 59 | Load + play track | **Writes seek state** |
| J: loadAudioFile | 27 | File loading | **Writes currentSeekID** |
| K: Transport | 102 | play/pause/stop/eject | **Writes seek state** |
| L: EQ forwarding | 20 | Method forwarding | No |
| M: Stream bridge | 17 | Method forwarding | No |
| N: Seeking | 79 | seek + seekToPercent | **CORE SEEK** |
| O: Viz forwarding | 18 | Method forwarding | No |
| P: Completion | 41 | onPlaybackEnded | **CORE SEEK** |
| Q: Playlist nav | 56 | next/prev/handle | **Calls seek** |

**Seek-dedicated lines (N+P+shouldIgnore):** ~127
**Seek-touching lines in other sections:** ~59
**Total seek-coupled code:** ~186 lines

---

## Seek State Variable Access Map

### `currentSeekID` (line 48)

| Line | Op | Context |
|------|-----|---------|
| 48 | Decl | `private var currentSeekID: UUID = UUID()` |
| 221 | Read | `shouldIgnoreCompletion` — compares incoming seekID |
| 317 | Write | `playTrack` — invalidates pending completions |
| 377 | Write | `loadAudioFile` — new ID for scheduled segment |
| 378 | Read | `loadAudioFile` — passed to `engine.scheduleFrom` |
| 467 | Write | `stop` — invalidates pending completions |
| 468 | Read | `stop` — passed to `engine.scheduleFrom` |
| 591 | Write | `seek` — new ID for seek operation |
| 597 | Read | `seek` — passed to `engine.scheduleFrom` |

### `seekGuardActive` (line 50)

| Line | Op | Context |
|------|-----|---------|
| 50 | Decl | `private var seekGuardActive = false` |
| 222 | Read | `shouldIgnoreCompletion` — suppresses nil-ID completions |
| 318 | Write T | `playTrack` — guard window start |
| 325 | Write F | `playTrack` — delayed guard end (50ms) |
| 335 | Write F | `playTrack` — synchronous clear |
| 437 | Write F | `play` — clear after successful start |
| 453 | Write F | `pause` — clear on pause |
| 482 | Write F | `stop` — clear on stop |
| 590 | Write T | `seek` — guard window start |
| 620 | Write F | `seek` — delayed guard end (100ms) |
| 676 | Write F | `onPlaybackEnded` — clear after handling |

### `isHandlingCompletion` (line 49)

| Line | Op | Context |
|------|-----|---------|
| 49 | Decl | `private var isHandlingCompletion = false` |
| 648 | Read | `onPlaybackEnded` — reentrancy guard |
| 652 | Write T | `onPlaybackEnded` — lock |
| 680 | Write F | `onPlaybackEnded` — delayed unlock (200ms) |

---

## shouldIgnoreCompletion Call Chain

```
AudioEngineController.scheduleFrom(time:seekID:)
  -> completionHandler fires on playerNode segment end
    -> engine.onPlaybackEnded?(completionID)
      -> AudioPlayer.onPlaybackEnded(fromSeekID:)
        -> shouldIgnoreCompletion(from: fromSeekID)

Also triggered (nil seekID):
  videoPlaybackController.onPlaybackEnded -> AudioPlayer.onPlaybackEnded()
  AudioPlayer.play() at end-of-track -> AudioPlayer.onPlaybackEnded()
  AudioPlayer.seek() on schedule failure -> delayed AudioPlayer.onPlaybackEnded()
```

---

## onPlaybackEnded Coupling to Playlist Navigation

`onPlaybackEnded` (line 645) calls `nextTrack()` (line 664) returning `PlaylistAdvanceAction`:
- `.requestCoordinatorPlayback(track)` / `.playLocally(track)` -> fires `onPlaylistAdvanceRequest?(track)` callback
- `.none` -> fires `onPlaybackFinished?()` callback

These callbacks are wired by PlaybackCoordinator.

---

## Atomic Unit — What MUST Move Together

### Properties (3 lines):
- `currentSeekID: UUID` (line 48)
- `isHandlingCompletion: Bool` (line 49)
- `seekGuardActive: Bool` (line 50)

### Methods (~147 lines):
- `shouldIgnoreCompletion(from:)` (lines 220-226) — 7 lines
- `seekToPercent(_:resume:)` (lines 546-568) — 23 lines
- `seek(to:resume:)` (lines 570-622) — 53 lines
- `onPlaybackEnded(fromSeekID:)` (lines 645-683) — 39 lines

### What CANNOT move (stays in AudioPlayer):
- `transition(to:)` — called from 15+ locations
- `playTrack(track:)` — writes seek state but handles track loading, media type switching, EQ
- `play()` / `pause()` / `stop()` — write seekGuardActive but are core transport
- `loadAudioFile(url:)` — writes currentSeekID but is playTrack helper
- `handlePlaylistAction(_:)` — calls `seek(to: 0, ...)` for restart

---

## Extraction Strategy

The extracted `SeekController` would need to expose to AudioPlayer:
- `invalidateSeekID() -> UUID` — returns new ID for `scheduleFrom` calls
- `setSeekGuardActive(_:)` — for playTrack/play/pause/stop to manage guard window
- `resetCompletionGuard()` — clear all seek state

AudioPlayer methods that currently write seek state directly would call through the controller.

---

## AudioEngineController Methods Called by Seek Path

| Method | Called From |
|--------|------------|
| `scheduleFrom(time:seekID:)` | loadAudioFile, stop, seek |
| `invalidateProgressTimer()` | playTrack, seek, onPlaybackEnded |
| `startProgressTimer()` | seek |
| `stopAudio()` | playTrack, stop |
| `playAudio()` | seek |
| `startEngineIfNeeded()` | seek |
| `installVisualizerTapIfNeeded()` | seek |
| `removeVisualizerTapIfNeeded()` | onPlaybackEnded |
| `currentFileDuration` | seekToPercent, seek, onPlaybackEnded |
| `audioFile` | seekToPercent, seek (nil-check guard) |

SeekController needs reference to AudioEngineController.

---

## S2 Impact on Seek Path

- **Stream Track Counter:** No direct impact — streams bypass AudioPlayer.seek()
- **Now Playing:** PlaybackCoordinator uses `audioPlayer.seek(to:)` for remote command. Facade pattern preserved.

## Prior Oracle Recommendation (Phase 4, 2026-03-22)

> "Keep seek state machine in AudioPlayer for this phase, unless you also move onPlaybackEnded completion filtering as one atomic unit. Partial move is the risky path."

This task implements the atomic-unit extraction the Oracle recommended deferring.

## Expected Result

AudioPlayer.swift: 740 -> ~554 lines (below 600 warning and error thresholds)
Both swiftlint suppressions removed.
