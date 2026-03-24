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
- [ ] Verify: clicking time digits toggles elapsed/remaining (all 4 digits)
- [ ] Verify: clicking bolt icon area does NOT toggle time display

### MainWindowShadeLayer (shade mode)
- [x] Add `.frame(width: 56, height: 13)` after ZStack to set full MM:SS bounds
- [x] Move `.contentShape(Rectangle())` and `.onTapGesture` BEFORE `.at(Layout.timeDisplay).scaleEffect(0.7).at(...)`
- [ ] Verify: clicking shade time digits toggles elapsed/remaining
- [ ] Verify: clicking shade bolt area does NOT toggle time display

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
- [ ] Play local file — Control Center shows title/artist/progress
- [ ] Play internet radio — Control Center shows stream title
- [ ] Keyboard play/pause — works
- [ ] Keyboard next/previous — advances playlist
- [ ] Seek via Control Center — works for local files
- [ ] Seek disabled for streams
- [ ] ICY metadata change — Control Center updates
- [ ] Switch local → stream → local — Now Playing updates each time
- [ ] Stop playback — Now Playing clears
- [ ] Test with AirPlay active

### Oracle Review Phase 2
- [ ] Submit Phase 2 implementation to Oracle for code review

---

## ~~Phase 3: Discoverability & UX Polish~~ — DEFUNCT

> **Status:** ABANDONED (2026-03-24). No in-app AirPlay trigger exists, so discoverability UI is moot. All items below are cancelled.

---

## Documentation & Closeout

- [ ] Update state.md with final status
- [ ] Create docs-update-needed.md for architecture docs
- [ ] Check for deprecated code → depreciated.md
- [ ] Check for placeholders → placeholder.md
- [ ] Update shared _context/state.md and tasks_index.md
- [ ] Final Oracle review of complete implementation
- [ ] Create PR
