# Todo: Stream Track Counter

> **Purpose:** Track implementation tasks derived from plan.md.

---

## Phase 1: Stream Elapsed Time (Mechanism)

- [ ] Add `elapsedTime`, `elapsedAccumulated`, `elapsedStartedAt` properties to `StreamPlayer`
- [ ] Add `startElapsedTimer()` — 0.1s Timer publishing anchor-based elapsed time
- [ ] Add `stopElapsedTimer()` — invalidate + accumulate
- [ ] Add `resetElapsedTime()` — reset all to 0
- [ ] Wire timer start/stop to pipeline state transitions (.playing, .paused, .buffering, etc.)
- [ ] Reset elapsed on `play(station:)`, `play(url:)`, `stop()`
- [ ] Add `lastNowPlayingIdentity` tracking for ICY metadata change detection
- [ ] Reset elapsed on normalized (title, artist) change (ignore empty/duplicate)
- [ ] Preserve elapsed during reconnect (pause timer, don't reset)

## Phase 2: Unified Time Properties (Bridge)

- [ ] Add `displayTime` computed property to `PlaybackCoordinator`
- [ ] Add `displayDuration` computed property to `PlaybackCoordinator`

## Phase 3: Playlist Position (Mechanism + Bridge)

- [ ] Add `currentPosition` computed property to `PlaylistController`
- [ ] Add `trackPositionString` computed property to `PlaybackCoordinator`
- [ ] Guard: return nil for non-playlist playback

## Phase 4: View Updates (Presentation)

- [ ] Update `MainWindowFullLayer.buildTimeDigits()` to use `playbackCoordinator.displayTime/displayDuration`
- [ ] Update `MainWindowShadeLayer.buildShadeTimeDisplay()` same way
- [ ] Suppress remaining mode when `displayDuration == 0`
- [ ] Hide minus-sign sprite during stream playback

## Phase 5: Track Position Display (Presentation)

- [ ] Prepend track position to `displayTitle` for local tracks

## Build & Test

- [ ] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [ ] XcodeBuildMCP test — all tests pass
- [ ] `ast-grep` check for duplicate timer/elapsed patterns

## Manual Testing

- [ ] Play internet radio — time counts up from 00:00
- [ ] ICY metadata change — time resets to 00:00
- [ ] Pause stream — time stops
- [ ] Resume stream — time continues
- [ ] Reconnect — time pauses, continues after
- [ ] Play local file — elapsed/remaining works as before
- [ ] Remaining mode during stream — stays in elapsed
- [ ] Playlist position shows "3/15" for local playlists
- [ ] Direct stream URL — no stale position shown

## Review & PR

- [ ] Oracle code review — address all findings
- [ ] Create PR for user review
