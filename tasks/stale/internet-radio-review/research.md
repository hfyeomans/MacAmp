## Context

- Feature adds internet radio streaming alongside local playback.
- `PlaybackCoordinator` mediates between `AudioPlayer` (local files) and new `StreamPlayer` (AVPlayer-based).
- Views depend on coordinator for transport commands and title display, while retaining `AudioPlayer` for playlist data, EQ, timers, and track metadata.

## File Walkthrough

- `AudioPlayer.swift`
  - `Track.isStream` identifies non-file HTTP(S) URLs.
  - `playTrack` now guards against streams, expecting coordinator to route them.
  - Playlist navigation (`nextTrack`, `previousTrack`) still assumes playable tracks.
- `StreamPlayer.swift`
  - Handles AVPlayer playback, buffering, metadata, and error state.
  - `play(url:title:artist:)` wraps bare URLs into `RadioStation`.
- `PlaybackCoordinator.swift`
  - Maintains unified state (`currentSource`, `currentTitle`, `currentTrack`).
  - `play(track:)` branches on `track.isStream` and forwards to proper backend.
  - `displayTitle` covers buffering/errors/metadata fallbacks.
  - `next`/`previous` delegate to `AudioPlayer.nextTrack/previousTrack` then re-call `play(track:)`.
- `WinampMainWindow.swift`
  - Transport buttons call coordinator, track display reads `coordinator.displayTitle`.
  - Still references `audioPlayer` for playback progress, shuffle/repeat toggles, and metadata displays.
- `WinampPlaylistWindow.swift`
  - Playlist double-click uses coordinator.
  - Mini transport buttons route through coordinator.
  - M3U parser and ADD URL append streams to `audioPlayer.playlist`.
- `MacAmpApp.swift`
  - Initializes shared `PlaybackCoordinator` in `@State` and injects into environment.

## Validated Findings (Oracle Review: 2026-02-14)

**Reviewer:** Oracle (gpt-5.3-codex, xhigh reasoning)
**Files Reviewed:** PlaybackCoordinator.swift, StreamPlayer.swift, PlaylistController.swift, AudioPlayer.swift, WinampMainWindow.swift, TrackInfoView.swift

### Original Issues (O1-O4): ALL FIXED

The PlaylistController extraction and AudioPlayer.stop() cleanup resolved all 4 original concerns:

| # | Original Issue | Status | Evidence |
|---|---------------|--------|----------|
| O1 | externalPlaybackHandler replaying on metadata refresh | **FIXED** | Local path routes through `updateLocalPlaybackState()` (PlaybackCoordinator.swift:272) -- only updates state, no replay |
| O2 | AudioPlayer.stop() leaves currentTrack populated | **FIXED** | AudioPlayer.swift:485 now clears `currentTrack = nil` on stop |
| O3 | nextTrack() plays streams directly | **FIXED** | PlaylistController returns `.requestCoordinatorPlayback(track)` for streams (PlaylistController.swift:179,189,199,206) |
| O4 | previousTrack() wrong context during stream | **FIXED** | Same PlaylistController action enum routing through coordinator (PlaybackCoordinator.swift:232-249) |

### New Issues Discovered (N1-N6)

#### N1: Playlist Navigation Broken During Stream Playback - HIGH

**Symptom:** `next()` always jumps to track 0; `previous()` does nothing.

**Root Cause Chain (with exact line references):**
1. `PlaybackCoordinator.next()` calls `audioPlayer.nextTrack(isManualSkip: true)` (PlaybackCoordinator.swift:173)
2. `AudioPlayer.nextTrack()` syncs with `playlistController.updatePosition(with: currentTrack)` (AudioPlayer.swift:1030)
3. During stream playback, `audioPlayer.currentTrack` is `nil` -- cleared by `audioPlayer.stop()` called at PlaybackCoordinator.swift:106, which clears at AudioPlayer.swift:485
4. `PlaylistController.updatePosition(with: nil)` sets `currentIndex = nil` (PlaylistController.swift:142-144)
5. `resolveActiveIndex()` falls through to return `-1` (PlaylistController.swift:266)
6. `nextIndex = -1 + 1 = 0` -- always jumps to first track (PlaylistController.swift:194)
7. For `previous()`, `currentIndex` is nil and `findCurrentTrackIndex()` returns nil (currentTrack is nil), so `.none` is returned (PlaylistController.swift:232)

**Impact:** Navigation is fundamentally broken when any stream track is playing. This blocks streaming-volume-control work.

---

#### N2: PlayPause Indicator Desync from StreamPlayer - MEDIUM

**Symptom:** Coordinator `isPlaying`/`isPaused` flags diverge from StreamPlayer's actual AVPlayer state during buffering or network interruptions.

**Root Cause:**
- Coordinator sets flags imperatively at play/pause/resume time (PlaybackCoordinator.swift:42-43, 93, 113, 145, 191)
- StreamPlayer updates asynchronously via `AVPlayer.timeControlStatus` KVO (StreamPlayer.swift:111-131)
- Buffering stalls (`waitingToPlayAtSpecifiedRate`) or network errors change `StreamPlayer.isPlaying` without coordinator awareness
- No subscription, observation, or callback link exists between coordinator and stream player state

**Impact:** UI play/pause button and timer may show wrong state during network disruptions.

---

#### N3: externalPlaybackHandler Naming Ambiguity - LOW (Not a Bug)

**Analysis:** The handler fires when a placeholder track is replaced with loaded metadata (AudioPlayer.swift:270), but coordinator correctly routes through `updateLocalPlaybackState()` (PlaybackCoordinator.swift:272) which only updates display state. The name "externalPlaybackHandler" implies it initiates playback, but it does not. No functional fix needed; rename for clarity.

---

#### N4: StreamPlayer Metadata Overwrite on play(url:title:artist:) - LOW

**Root Cause:**
- StreamPlayer.swift:83-84 set `streamTitle = title` and `streamArtist = artist`
- StreamPlayer.swift:87 calls `await play(station:)` which clears them at StreamPlayer.swift:60-61
- Result: initial Track metadata is lost until ICY metadata arrives from the stream

**Mitigation:** Coordinator's `displayTitle` falls back to `currentTrack?.title` (PlaybackCoordinator.swift:295), so title is still visible. But `streamTitle`/`streamArtist` are nil during initial connection period, which may confuse any code reading those properties directly.

---

#### N5: Main Window Indicator Bound to AudioPlayer, Not Coordinator - MEDIUM

**Evidence:** WinampMainWindow.swift references `audioPlayer.isPlaying` / `audioPlayer.isPaused` in multiple locations:
- `buildPlayPauseIndicator()` at line 316-319: reads `audioPlayer.isPlaying` / `audioPlayer.isPaused` for indicator sprite
- Pause blink timer at line 154: reads `audioPlayer.isPaused`
- Time display blink at line 367: reads `audioPlayer.isPaused`
- Scrubbing state at line 844: reads `audioPlayer.isPlaying`

**Impact:** Play/pause indicator shows "stopped" during stream playback because `audioPlayer.isPlaying` is false (audioPlayer was stopped when stream started).

---

#### N6: Track Info Dialog Missing Live ICY Metadata - LOW

**Evidence:** TrackInfoView.swift line 59 uses `playbackCoordinator.currentTitle` (set once at play-time) instead of `playbackCoordinator.displayTitle` (which includes live ICY metadata updates from StreamPlayer).

**Impact:** Shows static station name instead of live song title in Track Info dialog during radio playback.

---

### Priority Summary

| ID | Issue | Severity | Blocks Progress? |
|----|-------|----------|-----------------|
| N1 | Playlist navigation broken during stream | **HIGH** | YES -- blocks streaming-volume-control |
| N2 | PlayPause indicator desync from StreamPlayer | MEDIUM | Recommended before new features |
| N5 | Main window indicator bound to AudioPlayer | MEDIUM | Recommended before new features |
| N3 | externalPlaybackHandler naming | LOW | No |
| N4 | StreamPlayer metadata overwrite | LOW | No |
| N6 | Track Info missing live ICY | LOW | No |

**Full Oracle analysis with extended context:** See `findings.md`
