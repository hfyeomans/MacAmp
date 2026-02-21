# TODO: Internet Radio N1-N6 Fixes

> **Purpose:** Broken-down task checklist derived from the plan. Each item is a discrete, verifiable unit of work.

---

## Status: COMPLETE -- All 6 fixes implemented and committed (2026-02-21)

---

## Phase 1: Critical Fix (N1 - HIGH) -- COMPLETE (commit 9c5b530)

### PlaylistController Context-Aware Navigation
- [x] **1.1a** Add `nextTrack(from track: Track?, isManualSkip: Bool) -> AdvanceAction` overload to PlaylistController
- [x] **1.1b** Add `previousTrack(from track: Track?) -> AdvanceAction` overload to PlaylistController
- [x] **1.1c** Verify existing parameterless methods remain unchanged for backward compatibility
- [x] **1.1d** (Oracle correction) Always call `updatePosition(with: track)` including nil to clear stale index

### AudioPlayer Forwarding
- [x] **1.2a** Add `nextTrack(from:isManualSkip:) -> PlaylistAdvanceAction` to AudioPlayer
- [x] **1.2b** Add `previousTrack(from:) -> PlaylistAdvanceAction` to AudioPlayer

### PlaybackCoordinator Context Passing
- [x] **1.3a** Update `PlaybackCoordinator.next()` to use `from: self.currentTrack`
- [x] **1.3b** Update `PlaybackCoordinator.previous()` to use `from: self.currentTrack`

### Phase 1 Oracle Verification
- [x] **T1.Oracle** Oracle review PASS (gpt-5.3-codex, xhigh) -- nil-context edge case fixed

---

## Phase 2: UI State Correctness (N2 + N5 - MEDIUM) -- COMPLETE (commits a4d60ba + 983b363)

### N2: Convert Coordinator Play State to Computed Properties (commit a4d60ba)
- [x] **2.1a** Convert `isPlaying` to computed: `streamPlayer.isPlaying && !streamPlayer.isBuffering` for streams
- [x] **2.1b** Convert `isPaused` to computed: `!streamPlayer.isPlaying && !streamPlayer.isBuffering && streamPlayer.error == nil` for streams
- [x] **2.1c** Verified StreamPlayer exposes `isBuffering` (StreamPlayer.swift:122,127)
- [x] **2.1d** Removed ALL ~15 imperative `isPlaying`/`isPaused` assignments
- [x] **2.1e** Verified `@Observable` tracking works with computed properties

### N2 Oracle Verification
- [x] **T2.Oracle** Oracle review PASS (gpt-5.3-codex, xhigh)

### N5: Rebind Main Window Indicators to Coordinator (commit 983b363)
- [x] **2.2a** Pause blink timer: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused`
- [x] **2.2b** Play indicator sprite: `audioPlayer.isPlaying` -> `playbackCoordinator.isPlaying`
- [x] **2.2c** Pause indicator sprite: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused`
- [x] **2.2d** Time display blink: `audioPlayer.isPaused` -> `playbackCoordinator.isPaused`
- [x] **2.2e** Scrubbing pre-state: kept as `audioPlayer.isPlaying` (local-file-only feature)

### N5 Oracle Verification
- [x] **T5.Oracle** Oracle review PASS (gpt-5.3-codex, xhigh) -- all 4 sites confirmed, scrubbing correct

---

## SwiftLint Cleanup -- COMPLETE (commit 862fc09)

- [x] Extract helpers/scrolling/options menu to `WinampMainWindow+Helpers.swift`
- [x] Extract view builders to extension for type_body_length reduction
- [x] Fix 22 `multiple_closures_with_trailing_closure` violations (Button syntax)
- [x] Fix 4 `closure_body_length` violations (split into smaller methods)
- [x] Fix `unused_closure_parameter`, `vertical_whitespace`, `vertical_whitespace_closing_braces`
- [x] Add new file to Xcode project

**Note:** Access widened from `private` to `internal` on 7 @State vars + Coords struct to support cross-file extension. Both Gemini and Oracle (2026-02-21) recommend this be refactored to layer subview decomposition + @Observable interaction state as a future task.

---

## Phase 3: Low-Priority Cleanup (N4, N6, N3 - LOW) -- COMPLETE

### N4: Fix StreamPlayer Metadata Overwrite (commit 79db5a5)
- [x] **3.1a** Reapply `streamTitle`/`streamArtist` after `await play(station:)` with nil guard
- [x] **3.1b** ICY metadata arriving during connection is NOT overwritten (guard handles this)

### N6: Fix Track Info Live ICY Metadata (commit 87cc107)
- [x] **3.2a** Gate stream section on `case .radioStation = playbackCoordinator.currentSource`
- [x] **3.2b** Use `playbackCoordinator.displayTitle` for live ICY metadata
- [x] **3.2c** Idle state preserved: stream section hidden when no source active
- [x] **3.2d** Refactored TrackInfoView to fix pre-existing closure_body_length violations

### N3: Split externalPlaybackHandler (commit 3f3effd)
- [x] **3.3a** Split into `onTrackMetadataUpdate` + `onPlaylistAdvanceRequest`
- [x] **3.3b** Metadata refresh (AudioPlayer.swift:270) -> `onTrackMetadataUpdate`
- [x] **3.3c** End-of-track advance (AudioPlayer.swift:992) -> `onPlaylistAdvanceRequest`
- [x] **3.3d** Coordinator init wires both callbacks correctly
- [x] **3.3e** WinampPlaylistWindow comment updated (commit 5f2cef2, lint debt resolved in same commit)

---

## Post-Fix Validation -- PARTIAL

- [x] **V.1** Build succeeds (Thread Sanitizer not run in this session -- manual testing recommended)
- [x] **V.6** Oracle full-branch review PASS (gpt-5.3-codex, xhigh, 2026-02-21)
- [x] **V.app** Manual app smoke test -- no visual regressions observed
- [ ] **V.2** Full regression test: local file playback (manual testing recommended)
- [ ] **V.3** Full regression test: stream playback (manual testing recommended)
- [ ] **V.4** Full regression test: mixed playlist navigation
- [ ] **V.5** No regressions in video playback
- [ ] **V.7** Update `tasks/internet-streaming-volume-control/state.md` -- pending PR merge
- [ ] **V.8** Update `tasks/internet-radio-review/state.md` -- pending PR merge
- [ ] **V.9** Update `tasks/_context/tasks_index.md` -- pending PR merge
