# TODO: AirPlay Integration

> **Purpose:** Implementation checklist derived from plan.md. Each item is actionable.

**Date:** 2026-02-07 (original), **Updated:** 2026-03-23
**Status:** Pending Implementation

---

## Prerequisites (DONE)

- [x] Verify `com.apple.security.network.client` entitlement exists
- [x] Verify `com.apple.security.device.audio-output` entitlement exists
- [x] Confirm no Info.plist changes needed
- [x] Research logo coordinates (webamp: 253, 91)
- [x] Identify dual-trigger approach (bolt primary + logo secondary)
- [x] Identify time display hit area bug (prerequisite for bolt trigger)
- [x] Oracle plan review — Round 1: 7/10, Round 2: 8/10, Round 3: 8/10 (3 refinements)

---

## Phase 0: Fix Time Display Hit Area Bug

### MainWindowFullLayer (full mode)
- [x] Add `.frame(width: 56, height: 13)` after ZStack to set full MM:SS bounds
- [x] Move `.contentShape(Rectangle())` and `.onTapGesture` BEFORE `.at(Layout.timeDisplay)`
- [x] Verify: clicking time digits toggles elapsed/remaining (all 4 digits)
- [x] Verify: clicking bolt icon area does NOT toggle time display

### MainWindowShadeLayer (shade mode)
- [x] Add `.frame(width: 56, height: 13)` after ZStack to set full MM:SS bounds
- [x] Move `.contentShape(Rectangle())` and `.onTapGesture` BEFORE `.at(Layout.timeDisplay).scaleEffect(0.7).at(...)`
- [x] Verify: clicking shade time digits toggles elapsed/remaining
- [x] Verify: clicking shade bolt area does NOT toggle time display

### Build & Test
- [x] XcodeBuildMCP build — no compiler errors
- [x] XcodeBuildMCP test — all 53 tests pass (Thread Sanitizer enabled)

---

## ~~Phase 1: Core AirPlay + Engine Restart~~ — DEFUNCT

> **Status:** ABANDONED (2026-03-24). AVRoutePickerView on macOS routes per-AVPlayer only, not system-wide. Cannot redirect AVAudioEngine audio to AirPlay. See `research.md` section 8 for full analysis. Engine config observer deferred to future work (needed when users switch output via macOS Control Center).
>
> All Phase 1 items below are cancelled. In-app AirPlay trigger is not viable with current architecture.

---

## Phase 2: Now Playing Integration

### MPNowPlayingInfoCenter
- [x] Add `import MediaPlayer` to PlaybackCoordinator.swift
- [x] Implement `updateNowPlayingInfo()` method
  - [x] Set title (`displayTitle`)
  - [x] Set artist (`displayArtist`)
  - [x] Set elapsed time (`displayTime`)
  - [x] Set duration (`displayDuration`, 0 for streams)
  - [x] Set playback rate (1.0 / 0.0)
  - [x] Set explicit `playbackState` (.playing / .paused / .stopped) — REQUIRED on macOS
  - [x] Handle stream buffering as `.paused` (not `.stopped`)
- [x] Implement `clearNowPlayingInfo()` method
  - [x] Set `nowPlayingInfo = nil`
  - [x] Set `playbackState = .stopped`
- [x] Call `updateNowPlayingInfo()` at all transition points:
  - [x] `play(track:)`
  - [x] `play(station:)`
  - [x] `pause()`
  - [x] `stop()` (via `clearNowPlayingInfo()`)
  - [x] `resume()`
  - [x] `handlePlaylistAdvance(action:)`
  - [x] `updateTrackMetadata(_:)`
  - [x] StreamPlayer `onMetadataChanged` callback (NEW)

### MPRemoteCommandCenter
- [x] Implement `setupRemoteCommands()` in PlaybackCoordinator
- [x] All handlers dispatch via `Task { @MainActor }`:
  - [x] play → `resume()`
  - [x] pause → `pause()`
  - [x] togglePlayPause → `togglePlayPause()`
  - [x] nextTrack → `next()`
  - [x] previousTrack → `previous()`
  - [x] changePlaybackPosition → `audioPlayer.seek(to:)`
- [x] Disable seek command when `currentSource == .radioStation`
- [x] Re-enable seek command when switching to local playback
- [ ] Evaluate command enablement during testing: skip forward/backward, seek, repeat, shuffle — MacAmp has UI for these already, decide which to wire vs disable based on Control Center space
- [x] Call `setupRemoteCommands()` from init

### Stream Metadata Callback
- [x] Add `onMetadataChanged` callback to StreamPlayer
- [x] Fire from ICY metadata handler (alongside streamTitle/streamArtist updates)
- [x] Wire in PlaybackCoordinator init → calls `updateNowPlayingInfo()`

### Build & Test Phase 2
- [x] XcodeBuildMCP build with Thread Sanitizer — no warnings
- [x] XcodeBuildMCP test — all 53 tests pass
- [x] Play local file — Control Center shows title/artist/progress
- [x] Play internet radio — Control Center shows stream title
- [x] Keyboard play/pause — works (Apple keyboard + Bluetooth headphones)
- [x] Keyboard next/previous — advances playlist
- [x] Seek via Control Center — works for local files
- [x] Seek disabled for streams
- [x] ICY metadata change — Control Center updates
- [x] Switch local → stream → local — Now Playing updates each time
- [x] Stop playback — Now Playing clears
- [ ] Test with AirPlay active (deferred — system-wide routing via macOS Control Center)

### Oracle Review Phase 2
- [x] Oracle Round 1: 6/10 — 3 findings (stream state, auto-advance, seek cleanup)
- [x] Oracle Round 2: 7/10 — 2 findings (local finished, terminal timing)
- [x] Oracle Round 3: 6/10 — 2 findings (.playLocally regression, station next jump)
- [x] Oracle Round 4: 7/10 — 1 finding (playlist context guard)
- [x] Oracle Round 5: 9/10 — 1 finding (disable next/prev in clearNowPlayingInfo)

---

## ~~Phase 3: Discoverability & UX Polish~~ — DEFUNCT

> **Status:** ABANDONED (2026-03-24). No in-app AirPlay trigger exists, so discoverability UI is moot. All items below are cancelled.

---

## Documentation & Closeout

- [ ] Update state.md with final status
- [x] Create docs-update-needed.md for architecture docs
- [x] Check for deprecated code → depreciated.md (black masks documented)
- [ ] Check for placeholders → placeholder.md
- [ ] Update shared _context/state.md and tasks_index.md
- [x] Final Oracle review — 9/10
- [ ] Create PR
