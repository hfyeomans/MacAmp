# Plan: Internet Radio N1-N6 Fixes

> **Purpose:** Implementation plan for fixing 6 issues discovered during Oracle validation of the internet radio streaming infrastructure. Fixes are prerequisite for `internet-streaming-volume-control` Phase 1.

---

## Status: ORACLE REVIEWED -- CORRECTIONS APPLIED (gpt-5.3-codex, xhigh reasoning, 2026-02-21)

## Overview

Fix 6 issues (1 HIGH, 2 MEDIUM, 3 LOW) in the internet radio streaming infrastructure. These were found by Oracle validation (gpt-5.3-codex, xhigh reasoning, 2026-02-14) after the PlaylistController extraction and memory/CPU optimization work resolved the original O1-O4 issues.

**Branch:** `fix/internet-radio-n1-n6`
**Unblocks:** `tasks/internet-streaming-volume-control/` Phase 1

---

## Phase 1: Critical Fix (N1) - Playlist Navigation During Streams

### Problem

When playing a stream track, `next()`/`previous()` on PlaybackCoordinator always jumps to the first track (or does nothing) because `audioPlayer.currentTrack` is nil during stream playback.

### Root Cause

PlaybackCoordinator stops AudioPlayer before starting StreamPlayer. AudioPlayer.stop() clears `currentTrack = nil`. Navigation then syncs position with nil, resetting PlaylistController's index. The coordinator HAS the correct `currentTrack` but doesn't pass it through.

### Implementation

#### Step 1.1: Add context-aware navigation to PlaylistController

**File:** `MacAmpApp/Audio/PlaylistController.swift`

Add overloads that accept an external track context for position resolution:

```swift
func nextTrack(from track: Track?, isManualSkip: Bool) -> AdvanceAction {
    if let track = track {
        updatePosition(with: track)
    }
    // ... existing nextTrack logic using now-correct currentIndex
}

func previousTrack(from track: Track?) -> AdvanceAction {
    if let track = track {
        updatePosition(with: track)
    }
    // ... existing previousTrack logic using now-correct currentIndex
}
```

**Key detail:** When `from` track is non-nil, call `updatePosition(with: track)` before computing next/previous. This ensures `currentIndex` is correct even when `audioPlayer.currentTrack` is nil.

The existing parameterless methods remain unchanged for backward compatibility (used by auto-advance on track end from AudioPlayer).

#### Step 1.2: Add forwarding methods to AudioPlayer

**File:** `MacAmpApp/Audio/AudioPlayer.swift` (around lines 1028-1044)

Add `from:` parameter variants that pass through to PlaylistController:

```swift
func nextTrack(from track: Track?, isManualSkip: Bool) -> PlaylistAdvanceAction {
    // Pass external track context to playlist controller
    let action = playlistController.nextTrack(from: track, isManualSkip: isManualSkip)
    return handleAdvanceAction(action)
}

func previousTrack(from track: Track?) -> PlaylistAdvanceAction {
    let action = playlistController.previousTrack(from: track)
    return handleAdvanceAction(action)
}
```

#### Step 1.3: Update PlaybackCoordinator to pass context

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift` (lines 171-181)

Update `next()` and `previous()` to pass the coordinator's `currentTrack`:

```swift
// Line 173: was audioPlayer.nextTrack(isManualSkip: true)
let action = audioPlayer.nextTrack(from: self.currentTrack, isManualSkip: true)

// Line 179: was audioPlayer.previousTrack()
let action = audioPlayer.previousTrack(from: self.currentTrack)
```

The coordinator's `currentTrack` IS set during stream playback (set at PlaybackCoordinator.swift:102), so this passes valid context through to PlaylistController.

#### Edge Cases

- `updatePosition(with: nil)` remains unchanged (PlaylistController.swift:141-144) -- the `from:` parameter avoids this path when coordinator has a track
- Shuffle mode with streams: PlaylistController already returns `.requestCoordinatorPlayback` for stream tracks
- Repeat-one with streams: already handled at PlaylistController.swift:179
- Auto-advance (no coordinator context): existing parameterless methods still work for local file auto-advance
- **Station not from playlist (Oracle correction #4):** When playing a station directly via `play(station:)`, coordinator sets `currentTrack = nil` (PlaybackCoordinator.swift:133). The `from:` overload receives nil, so `updatePosition` is skipped. In this case, the overload must fall back to the existing behavior (use PlaylistController's last known index or return `.none`). This is acceptable -- station-only playback has no meaningful "next" in the playlist context. Document this explicitly: if `from` is nil AND `audioPlayer.currentTrack` is nil (both contexts absent), next/previous should return `.none` or fall back to index 0 deterministically (prefer `.none` to avoid silent wrong behavior)

### Verification

- [ ] Play stream track -> Next -> advances to correct next playlist entry (not track 0)
- [ ] Play stream track -> Previous -> goes to correct previous playlist entry (not no-op)
- [ ] Mixed playlist (local + stream) navigation both directions
- [ ] Shuffle + repeat modes with stream tracks
- [ ] Auto-advance on local file end (existing behavior, no regression)
- [ ] Play station directly (not from playlist) -> Next/Previous -> returns `.none` or handles gracefully (Oracle correction #4)
- [ ] Build with Thread Sanitizer -- no data races

---

## Phase 2: UI State Correctness (N2 + N5)

### N2: PlayPause Indicator Desync from StreamPlayer

#### Problem

Coordinator maintains manual `isPlaying`/`isPaused` flags that can desync from StreamPlayer's actual state during buffering stalls or network errors.

#### Implementation

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

**Approach:** Convert `isPlaying` and `isPaused` from stored to computed properties (Option C -- simplest, no new observation infrastructure).

```swift
var isPlaying: Bool {
    switch currentSource {
    case .localTrack: return audioPlayer.isPlaying
    case .radioStation: return streamPlayer.isPlaying
    case .none: return false
    }
}

var isPaused: Bool {
    switch currentSource {
    case .localTrack: return audioPlayer.isPaused
    case .radioStation: return !streamPlayer.isPlaying && !streamPlayer.isBuffering
    case .none: return false
    }
}
```

**Cleanup required:** Remove ALL imperative `isPlaying = ...` / `isPaused = ...` assignments throughout PlaybackCoordinator. These are scattered across multiple methods:
- Lines ~83, ~93, ~96, ~112-113, ~134-135, ~142, ~145, ~150, ~156-157, ~187, ~191, ~196, ~228-229

**Why this works:** Both `StreamPlayer` and `AudioPlayer` are `@Observable`. Accessing their `.isPlaying` inside a computed property on an `@Observable` coordinator triggers SwiftUI observation correctly -- changes to the underlying source properties propagate to any view reading `coordinator.isPlaying`.

**Risk assessment:** LOW. The computed properties derive from existing `@Observable` properties. The imperative flag assignments were the source of desync -- removing them eliminates the root cause.

**Critical: StreamPlayer buffering state semantics (Oracle correction #1):**

StreamPlayer's `handleStatusChange()` (StreamPlayer.swift:118-131) does NOT set `isPlaying = false` during `.waitingToPlayAtSpecifiedRate` -- it only sets `isBuffering = true` while leaving `isPlaying` at its previous value (typically `true` from a prior `.playing` state). This means `streamPlayer.isPlaying` can be `true` during a buffering stall.

**Chosen rule:** The coordinator's `isPlaying` should mean "audio is actively being rendered to speakers." During buffering stalls, audio is NOT being rendered, so `isPlaying` should be `false`.

**Computation (corrected):**
```swift
var isPlaying: Bool {
    switch currentSource {
    case .localTrack: return audioPlayer.isPlaying
    case .radioStation: return streamPlayer.isPlaying && !streamPlayer.isBuffering
    case .none: return false
    }
}

var isPaused: Bool {
    switch currentSource {
    case .localTrack: return audioPlayer.isPaused
    case .radioStation:
        // Paused = user explicitly paused (not buffering, not playing, no error)
        return !streamPlayer.isPlaying && !streamPlayer.isBuffering && streamPlayer.error == nil
    case .none: return false
    }
}
```

**State table for streams:**

| AVPlayer Status | isPlaying | isBuffering | error | Coordinator isPlaying | Coordinator isPaused |
|----------------|-----------|-------------|-------|-----------------------|---------------------|
| .playing | true | false | nil | **true** | false |
| .waitingToPlayAtSpecifiedRate | true* | true | nil | **false** | false |
| .paused (user) | false | false | nil | false | **true** |
| .paused (error) | false | false | non-nil | false | **false** |

*`isPlaying` stays true from prior `.playing` state -- this is why we add `&& !streamPlayer.isBuffering`

**Error state:** When StreamPlayer has a non-nil error, the coordinator should report neither playing nor paused. UI should show stopped/error state. The `displayTitle` already handles error display ("buffer 0%").

Review StreamPlayer's state properties to confirm:
- `isBuffering` tracks `AVPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate` -- CONFIRMED (StreamPlayer.swift:126-127)
- `isPlaying` is set to `true` for `.playing`, `false` for `.paused` -- CONFIRMED (StreamPlayer.swift:120-124)
- `error` property exists and is set on item failures -- MUST VERIFY during implementation

### N5: Main Window Indicator Bound to AudioPlayer

#### Problem

WinampMainWindow reads `audioPlayer.isPlaying`/`audioPlayer.isPaused` directly, showing wrong state during stream playback.

#### Implementation

**File:** `MacAmpApp/Views/WinampMainWindow.swift`

**Prerequisite:** N2 must be completed first (coordinator computed properties must be correct).

Rebind 5 references:

| Line | Current | New |
|------|---------|-----|
| 154 | `audioPlayer.isPaused` (pause blink timer) | `playbackCoordinator.isPaused` |
| 316 | `audioPlayer.isPlaying` (play indicator sprite) | `playbackCoordinator.isPlaying` |
| 318 | `audioPlayer.isPaused` (pause indicator sprite) | `playbackCoordinator.isPaused` |
| 367 | `audioPlayer.isPaused` (time display blink) | `playbackCoordinator.isPaused` |
| 844 | `audioPlayer.isPlaying` (scrubbing pre-state) | Evaluate: scrubbing is local-file-only, may keep as `audioPlayer.isPlaying` or guard with source check |

**Line 844 special case:** `wasPlayingPreScrub = audioPlayer.isPlaying` captures state before scrubbing begins. Scrubbing (seeking) only applies to local files, not live streams. Two options:
1. Keep as `audioPlayer.isPlaying` since scrubbing only triggers during local playback
2. Change to `playbackCoordinator.isPlaying` for consistency

Recommend option 1 (keep) since scrubbing inherently implies local file context.

**PlaybackCoordinator access:** Already available via `@Environment(PlaybackCoordinator.self)` in the view.

### Phase 2 Verification

- [ ] Play local file -> play/pause button shows correct state
- [ ] Play stream -> play/pause button shows correct state
- [ ] Pause/resume local file -> button toggles correctly
- [ ] Pause/resume stream -> button toggles correctly
- [ ] Stream buffering stall -> indicator reflects non-playing state
- [ ] Pause blink timer works for both backends
- [ ] Time display blink works for both backends
- [ ] Build with Thread Sanitizer -- no data races

---

## Phase 3: Low-Priority Cleanup (N4, N6, N3)

### N4: StreamPlayer Metadata Overwrite

**File:** `MacAmpApp/Audio/StreamPlayer.swift` (lines 75-90)

**Fix:** Reapply initial metadata after `await play(station:)` returns, guarded to avoid overwriting ICY data:

```swift
func play(url: URL, title: String? = nil, artist: String? = nil) async {
    let station = RadioStation(name: title ?? url.host ?? "Internet Radio", streamURL: url)
    await play(station: station)
    // Reapply initial metadata if ICY hasn't arrived yet
    if streamTitle == nil { streamTitle = title }
    if streamArtist == nil { streamArtist = artist }
}
```

### N6: Track Info Live ICY Metadata (Oracle correction #3)

**File:** `MacAmpApp/Views/Components/TrackInfoView.swift` (line 59)

**Oracle finding:** Direct replacement of `currentTitle` with `displayTitle` can regress idle-state behavior. `currentTitle` is optional (`String?`) and the view gates on `!streamTitle.isEmpty`. `displayTitle` is non-optional and returns `"MacAmp"` when `currentSource` is `.none` (PlaybackCoordinator.swift:310-311). A naive replacement would show "MacAmp" in the stream info section when idle instead of hiding it.

**Fix (corrected):** Gate the stream display section by source type, THEN use `displayTitle`:

```swift
} else if case .radioStation = playbackCoordinator.currentSource {
    // Stream playback -- use displayTitle for live ICY metadata
    InfoRow(label: "Stream:", value: playbackCoordinator.displayTitle)
    // ... rest of stream section
}
```

This ensures the stream info section only appears during actual stream playback, and when it does, it shows live ICY metadata via `displayTitle`. When idle, the section is hidden (existing behavior preserved).

**Note:** Verify that `currentSource` is accessible from TrackInfoView (check access control).

### N3: externalPlaybackHandler Rename (Oracle correction #2)

**Files:**
- `MacAmpApp/Audio/AudioPlayer.swift` (declaration + call sites at lines 270 and 992)
- `MacAmpApp/Audio/PlaybackCoordinator.swift` (init assignment at line ~59, handler at line ~268)

**Oracle finding:** The callback serves TWO purposes:
1. Metadata refresh (line 270): when a placeholder track is replaced with loaded metadata
2. End-of-track auto-advance (line 992): when playback completes and the next track action returns `.requestCoordinatorPlayback` or `.playLocally`

Renaming to `onTrackMetadataUpdate` only covers use case #1 and is semantically wrong for use case #2.

**Fix (corrected):** Rename to `onTrackChangeRequest` -- a neutral name that covers both "metadata updated, re-evaluate current track" and "track ended, here's the next one." Both cases result in the coordinator being asked to handle a track. Alternatively, split into two callbacks:
- `onTrackMetadataUpdate` for metadata refresh (line 270)
- `onPlaylistAdvanceRequest` for end-of-track advance (line 992)

**Recommended:** Use the split approach for maximum clarity. The coordinator already handles these differently (`updateLocalPlaybackState` vs `play(track:)`).

Search for all references to `externalPlaybackHandler` across the entire codebase.

### Phase 3 Verification

- [ ] N4: Play stream from URL with title -- title visible during initial connection (before ICY arrives)
- [ ] N4: ICY metadata arrives -- overrides initial title correctly
- [ ] N6: Open Track Info during stream -- shows live ICY metadata, not static station name
- [ ] N6: Open Track Info when idle (no playback) -- does NOT show stream section (Oracle correction #3)
- [ ] N3: Build succeeds after rename/split; all call sites updated
- [ ] N3: End-of-track auto-advance callback still works (Oracle correction #2 -- tests both callback paths)
- [ ] No regressions in local file playback

---

## Post-Fix Validation

- [ ] Build with Thread Sanitizer passes (zero warnings)
- [ ] Stream next/previous navigates correctly in mixed playlist
- [ ] Play/pause indicator correct for both local and stream backends
- [ ] Track Info shows live ICY metadata during stream
- [ ] No regressions in local file playback (play, pause, seek, next, prev, shuffle, repeat)
- [ ] No regressions in video playback
- [ ] Oracle validation of all fixes
- [ ] Update `tasks/internet-streaming-volume-control/state.md` -- unblock Phase 1
- [ ] Update `tasks/internet-radio-review/state.md` -- mark N1-N6 resolved
- [ ] Update `tasks/_context/tasks_index.md` -- reflect new task status

---

## Dependencies

- **Upstream:** None -- this task has no blockers
- **Downstream:** `internet-streaming-volume-control` Phase 1 is blocked on at least N1 (HIGH), N2 (MEDIUM), N5 (MEDIUM)
- **Branch:** `fix/internet-radio-n1-n6`
- **Ordering:** Phase 1 (N1) -> Phase 2 (N2 then N5) -> Phase 3 (N4, N6, N3)

---

## Oracle Review (gpt-5.3-codex, xhigh reasoning, 2026-02-21)

### Readiness: NEEDS CORRECTIONS -> CORRECTIONS APPLIED

### Issues Found and Applied

| # | Severity | Finding | Correction |
|---|----------|---------|------------|
| 1 | HIGH | N2 buffering stall: `streamPlayer.isPlaying` stays `true` during `.waitingToPlayAtSpecifiedRate` -- computed `isPlaying` would falsely show playing | Added `&& !streamPlayer.isBuffering` to `isPlaying` computation; added full state table; defined error-state behavior |
| 2 | MEDIUM | N3 rename: `externalPlaybackHandler` serves both metadata refresh (line 270) AND end-of-track advance (line 992) -- `onTrackMetadataUpdate` doesn't cover advance path | Changed to split approach: `onTrackMetadataUpdate` + `onPlaylistAdvanceRequest` |
| 3 | MEDIUM | N6 displayTitle: `displayTitle` is non-optional and returns "MacAmp" when idle -- direct replacement regresses idle TrackInfoView | Changed to gate on `currentSource == .radioStation` then use `displayTitle` |
| 4 | MEDIUM | N1 station not from playlist: `currentTrack = nil` for direct station playback (line 133) -- `from: nil` would inherit stale playlist index | Added explicit nil behavior: when both contexts absent, prefer `.none` over stale index |
| 5 | LOW | Verification gaps: missing tests for idle Track Info after N6, end-of-track callback after N3, station-not-from-playlist after N1 | Added 3 additional verification items |
