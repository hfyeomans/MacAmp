# Todo: Stream Track Counter

> **Purpose:** Track implementation tasks derived from plan.md.

---

## Phase 1: Stream Elapsed Time (Mechanism)

- [x] Add `elapsedTime`, `elapsedAccumulated`, `elapsedStartedAt` properties to `StreamPlayer`
- [x] Add `startElapsedTimer()` — 0.1s Timer publishing anchor-based elapsed time
- [x] Add `stopElapsedTimer()` — invalidate + accumulate + publish final value
- [x] Add `resetElapsedTime()` — reset all to 0
- [x] Wire timer start/stop to pipeline state transitions (.playing, .paused, .buffering, etc.)
- [x] Reset elapsed on `play(station:)`, `play(url:)`, `stop()`
- [x] Timer preserved through reconnect (pause, don't reset)
- [x] Verified: NO ICY metadata reset (Winamp classic behavior confirmed from source code)

## Phase 2: Unified Time Properties (Bridge)

- [x] Add `displayTime` computed property to `PlaybackCoordinator`
- [x] Add `displayDuration` computed property to `PlaybackCoordinator`

## Phase 3: Playlist Position (Mechanism + Bridge)

- [x] Add `currentPosition` computed property to `PlaylistController`
- [x] Add `playlistPosition` / `playlistCount` forwarding on `AudioPlayer`
- [x] Add `trackPositionString` computed property to `PlaybackCoordinator`
- [x] Guard: return nil when `currentTrack` is nil (non-playlist playback)

## Phase 4: View Updates (Presentation)

- [x] Update `MainWindowFullLayer.buildTimeDigits()` to use `playbackCoordinator.displayTime/displayDuration`
- [x] Update `MainWindowShadeLayer.buildShadeTimeDisplay()` same way
- [x] Suppress remaining mode when `displayDuration == 0`
- [x] Hide minus-sign sprite during stream playback
- [x] Prepend track position to `displayTitle` for local tracks ("3/15. Title")

## Bugfixes Discovered During Implementation

- [x] Remove dead `PlaybackCoordinator.play(url:)` method (Oracle residual)
- [x] Align PlaybackCoordinator doc comment with production API
- [x] Remove auto-play from `AudioPlayer.addTrack()` (pre-existing bug — bypassed coordinator)
- [x] Consolidate auto-play into `autoPlayFirstTrack()` — single source of truth
- [x] Make `handleSelectedURLs()` async — await M3U parsing inline (no dual-trigger)
- [x] Add `parseAndAddM3U()` — awaitable M3U parse + add (no fire-and-forget)
- [x] Add `addEntries()` — shared M3U entry → track addition (eliminates duplication)
- [x] Pass coordinator explicitly through all auto-play paths
- [x] Fix `AppCommands.presentOpenPanel()` — add coordinator + auto-play via coordinator
- [x] Fix `loadAudioFile()` crash guard — clear engine + transition to stopped on file open failure

## Build & Test

- [x] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [x] XcodeBuildMCP test — all 53 tests pass

## Manual Testing

- [x] Play internet radio — time counts up from 00:00
- [x] ICY metadata change — time continues (Winamp behavior, verified)
- [x] Pause stream — time stops
- [x] Resume stream — time continues
- [x] Reconnect (wifi kill/restore) — time preserves through reconnect
- [x] Play local file — elapsed/remaining works as before
- [x] Remaining mode during stream — stays in elapsed (no minus sign)
- [x] Playlist position shows "3/15. Title" for local playlists
- [x] Mixed M3U (local + stream) — forward/backward navigation works
- [x] Unreachable local file in M3U — skips gracefully, no crash
- [x] Add files to empty playlist — auto-plays first track with working counter

## Review & PR

- [x] Oracle plan review — 9/10
- [x] Oracle code reviews — 9/10 (stream timer), 9/10 (auto-play refactor), 8/10 (final)
- [x] Create PR #68 — merged (2026-03-23)
- [x] PR review comments — 4 resolved (1 actionable fixed, 1 nitpick fixed, 1 nitpick accepted, 1 false positive)
