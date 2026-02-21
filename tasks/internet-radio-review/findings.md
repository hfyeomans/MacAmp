# Internet Radio Review - Oracle Validation Findings

**Date:** 2026-02-14
**Reviewer:** Oracle (gpt-5.3-codex, xhigh reasoning)
**Files Reviewed:**
- `MacAmpApp/Audio/PlaybackCoordinator.swift`
- `MacAmpApp/Audio/StreamPlayer.swift`
- `MacAmpApp/Audio/PlaylistController.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`

---

## Original Issues (from initial review) - ALL FIXED

| # | Issue | Status | Evidence |
|---|-------|--------|----------|
| O1 | externalPlaybackHandler replaying tracks on metadata refresh | FIXED | Local path now goes through `updateLocalPlaybackState()` (PlaybackCoordinator.swift:272) which only updates state, does not replay |
| O2 | AudioPlayer.stop() leaves currentTrack populated (stale UI during stream) | FIXED | AudioPlayer.swift:485 now clears `currentTrack = nil` on stop |
| O3 | AudioPlayer.nextTrack() plays streams directly instead of routing to coordinator | FIXED | PlaylistController returns `.requestCoordinatorPlayback(track)` for streams (PlaylistController.swift:179,189,199,206) |
| O4 | AudioPlayer.previousTrack() operates on wrong context during stream playback | FIXED | Same PlaylistController extraction returns action enums, coordinator handles routing (PlaybackCoordinator.swift:232-249) |

---

## New Issues Found

### N1: Playlist Navigation Broken During Stream Playback - HIGH

**Description:** When playing a stream track, calling next()/previous() on PlaybackCoordinator always jumps to the first track in the playlist instead of advancing sequentially from the stream's position.

**Root Cause Chain:**
1. `PlaybackCoordinator.next()` calls `audioPlayer.nextTrack(isManualSkip: true)` (PlaybackCoordinator.swift:173)
2. `AudioPlayer.nextTrack()` syncs position with `playlistController.updatePosition(with: currentTrack)` (AudioPlayer.swift:1030)
3. During stream playback, `audioPlayer.currentTrack` is `nil` (cleared by `audioPlayer.stop()` at PlaybackCoordinator.swift:106 -> AudioPlayer.swift:485)
4. `PlaylistController.updatePosition(with: nil)` sets `currentIndex = nil` (PlaylistController.swift:143)
5. `resolveActiveIndex()` returns `-1` (PlaylistController.swift:266)
6. `nextIndex = -1 + 1 = 0` - always jumps to first track (PlaylistController.swift:194)
7. For `previous()`, `currentIndex` is nil and `findCurrentTrackIndex()` returns nil, so `.none` is returned (PlaylistController.swift:232)

**Severity:** HIGH - Navigation is fundamentally broken during stream playback.

**Recommendation:** Pass coordinator's `currentTrack` context into navigation. Options:
- Add `nextTrack(from track: Track?)` / `previousTrack(from track: Track?)` to PlaylistController
- Make PlaybackCoordinator sync its `currentTrack` into `playlistController.updatePosition()` before calling navigation
- Make `updatePosition(with: nil)` a no-op when stream context is active

---

### N2: PlayPause Indicator Desync from StreamPlayer - MEDIUM

**Description:** PlaybackCoordinator maintains manual `isPlaying`/`isPaused` flags that can desync from StreamPlayer's actual state.

**Root Cause:**
- Coordinator sets flags imperatively at play/pause/resume time (PlaybackCoordinator.swift:42-43, 93, 145, 191)
- StreamPlayer updates asynchronously via `AVPlayer.timeControlStatus` KVO (StreamPlayer.swift:111-131)
- Events like buffering stalls (`waitingToPlayAtSpecifiedRate`) or network errors change StreamPlayer.isPlaying without coordinator awareness
- No subscription or observation link exists between coordinator and stream player state

**Severity:** MEDIUM - UI indicators (play/pause button state, timer display) may show wrong state during network interruptions.

**Recommendation:** Derive coordinator `isPlaying`/`isPaused` from active source as computed properties, or add callback/observation to sync from StreamPlayer state changes.

---

### N3: externalPlaybackHandler Called on Metadata Refresh (Clarification) - LOW (Not a Bug)

**Description:** `externalPlaybackHandler` is still called when a placeholder track is replaced with loaded metadata (AudioPlayer.swift:270), but the actual behavior is correct.

**Analysis:**
- Callback fires only when the replaced placeholder is the current track (AudioPlayer.swift:262)
- `PlaybackCoordinator.handleExternalPlaylistAdvance()` routes local tracks to `updateLocalPlaybackState()` (PlaybackCoordinator.swift:272)
- `updateLocalPlaybackState()` only updates display state (title, source, etc.) - does NOT replay (PlaybackCoordinator.swift:220-230)
- Stream tracks would call `play(track:)` but metadata refresh for streams is not handled through `addTrack()` path

**Severity:** LOW (non-bug, naming/clarity issue only)

**Recommendation:** Rename or split `externalPlaybackHandler` into two callbacks (metadata-update vs advance-event) for code clarity. No functional fix needed.

---

### N4: StreamPlayer Metadata Overwrite on play(url:title:artist:) - LOW

**Description:** `StreamPlayer.play(url:title:artist:)` sets initial metadata from Track, then immediately calls `play(station:)` which clears both `streamTitle` and `streamArtist` to nil.

**Root Cause:**
- Lines 83-84 set `streamTitle = title` and `streamArtist = artist`
- Line 87 calls `await play(station:)` which clears them at lines 60-61
- Result: initial Track metadata is lost until ICY metadata arrives from the stream

**Severity:** LOW - Coordinator's `displayTitle` falls back to `currentTrack?.title` (PlaybackCoordinator.swift:295), so the title is still shown. However, `streamTitle`/`streamArtist` are nil during the initial connection period.

**Recommendation:** Either:
- Reapply title/artist after `await play(station:)` returns
- Skip the nil-clearing in `play(station:)` when called from the URL variant
- Add parameters to `play(station:)` for initial metadata preservation

---

### N5: Main Window Indicator Bound to AudioPlayer, Not Coordinator - MEDIUM (NEW)

**Description:** The main window play/pause indicator reads state from `AudioPlayer` directly instead of `PlaybackCoordinator`, causing incorrect display during stream playback.

**Evidence:** WinampMainWindow.swift binds to `audioPlayer.isPlaying` / `audioPlayer.isPaused` for indicator state rather than `playbackCoordinator.isPlaying`.

**Severity:** MEDIUM - Play/pause button shows wrong state during stream playback.

**Recommendation:** Bind main window transport indicators to `playbackCoordinator.isPlaying` / `playbackCoordinator.isPaused`.

---

### N6: Track Info Dialog Missing Live ICY Metadata - LOW (NEW)

**Description:** Track Info dialog displays `playbackCoordinator.currentTitle` which is set at play-time, not `displayTitle` which includes live ICY metadata.

**Evidence:** TrackInfoView.swift uses `currentTitle` rather than `displayTitle`.

**Severity:** LOW - Static station name shown instead of live song title in Track Info.

**Recommendation:** Use `playbackCoordinator.displayTitle` in Track Info view.

---

## Summary Table

| ID | Issue | Severity | Blocks Proceed? |
|----|-------|----------|-----------------|
| N1 | Playlist navigation broken during stream | HIGH | YES |
| N2 | PlayPause indicator desync | MEDIUM | Recommended |
| N5 | Main window indicator source mismatch | MEDIUM | Recommended |
| N3 | externalPlaybackHandler naming | LOW | NO |
| N4 | StreamPlayer metadata overwrite | LOW | NO |
| N6 | Track Info missing live ICY | LOW | NO |

---

## Recommendation: Fix Before Proceeding

**Must fix (blocking):**
- N1: Playlist navigation during stream playback (HIGH)

**Should fix in same pass:**
- N2: PlayPause state sync from StreamPlayer (MEDIUM)
- N5: Main window indicator binding (MEDIUM)

**Can bundle or defer:**
- N4: StreamPlayer metadata preservation (LOW)
- N6: Track Info live ICY display (LOW)
- N3: Naming cleanup only (LOW)

---

## Documentation Updates Needed

### research.md
- Replace "Emerging Risks / Questions" section (line 31+) with validated findings
- Mark original concerns as confirmed-fixed with evidence
- Add new findings N1-N6 with code references

### plan.md
- Add remediation steps for:
  - Stream navigation context fix (N1)
  - State sync model for coordinator-stream (N2)
  - UI binding audit for stream state (N5)
  - Stream metadata preservation (N4)
- Add verification test cases for each fix

### state.md
- Replace outdated issue list (line 5) with current status:
  - Original 4 issues: ALL FIXED
  - New findings: 6 issues (1 HIGH, 2 MEDIUM, 3 LOW)
  - Blocking decision: Fix N1 before proceeding
  - Status: BLOCKED on N1 fix
