# Internet Radio Review - Fix Tasks

**Priority:** Fix N1 (blocking) -> N2+N5 (recommended) -> N3+N4+N6 (deferred)

---

## Phase 1: Critical (Blocks streaming-volume-control)

- [ ] **N1: Fix playlist navigation during stream playback**
  - [ ] Add `nextTrack(from track: Track?, isManualSkip: Bool) -> AdvanceAction` to PlaylistController
  - [ ] Add `previousTrack(from track: Track?) -> AdvanceAction` to PlaylistController
  - [ ] Add `nextTrack(from: Track?, isManualSkip:) -> PlaylistAdvanceAction` forwarding to AudioPlayer
  - [ ] Add `previousTrack(from: Track?) -> PlaylistAdvanceAction` forwarding to AudioPlayer
  - [ ] Update `PlaybackCoordinator.next()` (line 173) to call `audioPlayer.nextTrack(from: self.currentTrack, isManualSkip: true)`
  - [ ] Update `PlaybackCoordinator.previous()` (line 179) to call `audioPlayer.previousTrack(from: self.currentTrack)`
  - [ ] Test: play stream -> next -> advances to correct next track (not track 0)
  - [ ] Test: play stream -> previous -> goes to correct previous track (not noop)
  - [ ] Test: mixed playlist (local + stream) navigation both directions
  - [ ] Test: shuffle + repeat modes with stream tracks
  - [ ] Oracle review of N1 fix

## Phase 2: Recommended (Before new features)

- [ ] **N2: Fix PlayPause indicator desync** (do before N5)
  - [ ] Convert `PlaybackCoordinator.isPlaying` from stored to computed property (derive from active source)
  - [ ] Convert `PlaybackCoordinator.isPaused` from stored to computed property
  - [ ] Remove all imperative `isPlaying = ...` / `isPaused = ...` assignments in PlaybackCoordinator
  - [ ] Verify `@Observable` tracking works with computed properties reading from `@Observable` dependencies
  - [ ] Test: stream buffering stall -> coordinator reflects non-playing state
  - [ ] Test: stream error -> coordinator reflects stopped state

- [ ] **N5: Rebind main window indicator to coordinator** (depends on N2)
  - [ ] Line 154: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused` (pause blink timer)
  - [ ] Line 316: `audioPlayer.isPlaying` -> `playbackCoordinator.isPlaying` (play indicator sprite)
  - [ ] Line 318: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused` (pause indicator sprite)
  - [ ] Line 367: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused` (time display blink)
  - [ ] Line 844: `audioPlayer.isPlaying` -> evaluate if scrubbing needs special handling (local-only feature)
  - [ ] Test: play local -> correct indicator; play stream -> correct indicator; pause/resume both

## Phase 3: Deferred (Can bundle later)

- [ ] **N4: Fix StreamPlayer metadata overwrite**
  - [ ] In `StreamPlayer.play(url:title:artist:)` (lines 75-90): reapply `streamTitle = title` / `streamArtist = artist` after `await play(station:)` returns
  - [ ] Guard with `if streamTitle == nil` to avoid overwriting ICY metadata if it arrived during connection

- [ ] **N6: Track Info live ICY metadata**
  - [ ] TrackInfoView.swift line 59: replace `playbackCoordinator.currentTitle` with `playbackCoordinator.displayTitle`

- [ ] **N3: Rename externalPlaybackHandler**
  - [ ] Rename `externalPlaybackHandler` to `onTrackMetadataUpdate` (or split into two callbacks)
  - [ ] Update AudioPlayer.swift declaration and call site
  - [ ] Update PlaybackCoordinator.swift init assignment

## Post-Fix Validation

- [ ] Build with Thread Sanitizer
- [ ] Full regression test (local playback, stream playback, mixed playlist)
- [ ] Oracle validation of all fixes
- [ ] Unblock streaming-volume-control task
