# Internet Radio Review - Remediation Plan

**Date:** 2026-02-14
**Status:** BLOCKED on N1 fix before streaming-volume-control work proceeds
**Prerequisite for:** `tasks/internet-streaming-volume-control/`

---

## Phase 1: Critical Fix (N1) - MUST DO

### N1: Playlist Navigation Context During Stream Playback

**Problem:** `next()`/`previous()` on PlaybackCoordinator always jump to track 0 or do nothing during stream playback because `audioPlayer.currentTrack` is nil, causing PlaylistController to lose position context.

**Fix Strategy:** Pass coordinator's `currentTrack` into playlist navigation so PlaylistController can resolve the correct index even when AudioPlayer has been stopped for stream playback.

**Implementation Steps:**

1. **PlaylistController** - Add context-aware navigation overloads:
   - `nextTrack(from track: Track?, isManualSkip: Bool) -> AdvanceAction`
   - `previousTrack(from track: Track?) -> AdvanceAction`
   - When `from` track is non-nil, call `updatePosition(with: track)` before computing next/previous
   - This ensures `currentIndex` is correct even when `audioPlayer.currentTrack` is nil (stream playback)
   - File: `MacAmpApp/Audio/PlaylistController.swift`

2. **AudioPlayer** - Add `from:` parameter to navigation methods:
   - `nextTrack(from track: Track?, isManualSkip: Bool) -> PlaylistAdvanceAction`
   - `previousTrack(from track: Track?) -> PlaylistAdvanceAction`
   - These pass `track` through to PlaylistController's new overloads
   - The existing parameterless methods remain for backward compatibility (auto-advance on track end)
   - File: `MacAmpApp/Audio/AudioPlayer.swift` (lines 1028-1044)

3. **PlaybackCoordinator** - Use context-aware navigation:
   - `next()` at line 173: call `audioPlayer.nextTrack(from: self.currentTrack, isManualSkip: true)`
   - `previous()` at line 179: call `audioPlayer.previousTrack(from: self.currentTrack)`
   - This passes the coordinator's `currentTrack` (which IS set during stream playback, PlaybackCoordinator.swift:102) through to PlaylistController
   - File: `MacAmpApp/Audio/PlaybackCoordinator.swift` (lines 171-181)

4. **Edge case handling:**
   - `updatePosition(with: nil)` remains unchanged (PlaylistController.swift:141-144) -- the `from:` parameter avoids this path
   - Shuffle mode with streams works because PlaylistController already returns `.requestCoordinatorPlayback` for stream tracks
   - Repeat-one with streams already handled at PlaylistController.swift:179

**Files to modify:**
- `MacAmpApp/Audio/PlaylistController.swift` - Add `from:` navigation overloads
- `MacAmpApp/Audio/AudioPlayer.swift` - Add `from:` forwarding methods
- `MacAmpApp/Audio/PlaybackCoordinator.swift` - Use `from: self.currentTrack` in next()/previous()

**Verification:**
- Build with Thread Sanitizer
- Test: Play stream track, press Next -> should advance to next playlist entry (not track 0)
- Test: Play stream track, press Previous -> should go to previous playlist entry
- Test: Mixed playlist (local + stream) navigation in both directions
- Oracle review of fix

---

## Phase 2: UI State Correctness (N2 + N5) - SHOULD DO

### N2: PlayPause Indicator Desync from StreamPlayer

**Problem:** Coordinator maintains manual `isPlaying`/`isPaused` flags that don't reflect StreamPlayer's actual state during buffering or network errors.

**Fix Strategy:** Add observation of StreamPlayer state changes to keep coordinator flags in sync.

**Recommended Approach:** Option C -- Computed properties (simplest, no new observation infrastructure).

Both `StreamPlayer` and `AudioPlayer` are `@Observable`, so SwiftUI will automatically re-evaluate when their underlying properties change.

**Implementation Steps:**

1. Convert `PlaybackCoordinator.isPlaying` and `isPaused` from stored to computed properties:
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
2. Remove all imperative `isPlaying = ...` / `isPaused = ...` assignments throughout PlaybackCoordinator
   - Lines: ~83, ~93, ~96, ~112-113, ~134-135, ~142, ~145, ~150, ~156-157, ~187, ~191, ~196, ~228-229
3. Verify `@Observable` tracking works -- since `streamPlayer` and `audioPlayer` are both `@Observable`, accessing their `.isPlaying` inside a computed property triggers observation correctly

**Files to modify:**
- `MacAmpApp/Audio/PlaybackCoordinator.swift` - Replace stored flags with computed properties

**Verification:**
- Simulate network interruption during stream -> UI should show paused/buffering
- Resume after interruption -> UI should show playing

### N5: Main Window Indicator Bound to AudioPlayer

**Problem:** WinampMainWindow reads `audioPlayer.isPlaying` instead of `playbackCoordinator.isPlaying`, showing wrong state during streams.

**Fix Strategy:** Rebind main window transport indicators to PlaybackCoordinator.

**Implementation Steps:**

1. Audit WinampMainWindow.swift for all `audioPlayer.isPlaying` / `audioPlayer.isPaused` references:
   - Line 154: `if audioPlayer.isPaused` (pause blink timer) -> `playbackCoordinator.isPaused`
   - Line 316: `if audioPlayer.isPlaying` (play indicator sprite) -> `playbackCoordinator.isPlaying`
   - Line 318: `else if audioPlayer.isPaused` (pause indicator sprite) -> `playbackCoordinator.isPaused`
   - Line 367: `!audioPlayer.isPaused || pauseBlinkVisible` (time display blink) -> `!playbackCoordinator.isPaused`
   - Line 844: `wasPlayingPreScrub = audioPlayer.isPlaying` (scrubbing state) -> this one may need special handling since scrubbing is local-file only
2. Replace with `playbackCoordinator.isPlaying` / `playbackCoordinator.isPaused`
3. PlaybackCoordinator is already in the view's environment (`@Environment(PlaybackCoordinator.self)`)
4. **Note:** After N2 is fixed (computed properties), these bindings will automatically reflect stream state too

**Files to modify:**
- `MacAmpApp/Views/WinampMainWindow.swift` - Rebind indicator properties (5 references)

**Dependency:** N2 should be fixed first so that `playbackCoordinator.isPlaying` is derived correctly from the active source.

**Verification:**
- Play local file -> play/pause button shows correct state
- Play stream -> play/pause button shows correct state
- Pause/resume both backends -> button toggles correctly

---

## Phase 3: Low-Priority Cleanup (N3, N4, N6) - CAN DEFER

### N4: StreamPlayer Metadata Overwrite

**Problem:** `play(url:title:artist:)` sets `streamTitle`/`streamArtist` (lines 83-84), then `await play(station:)` clears them (lines 60-61).

**Fix:** Reapply `title`/`artist` after `await play(station:)` returns:
```swift
func play(url: URL, title: String? = nil, artist: String? = nil) async {
    let station = RadioStation(name: title ?? url.host ?? "Internet Radio", streamURL: url)
    await play(station: station)
    // Reapply initial metadata (ICY will override when it arrives)
    if streamTitle == nil { streamTitle = title }
    if streamArtist == nil { streamArtist = artist }
}
```

**Files:** `MacAmpApp/Audio/StreamPlayer.swift` (lines 75-90)

### N6: Track Info Missing Live ICY Metadata

**Problem:** TrackInfoView.swift line 59 reads `playbackCoordinator.currentTitle` (static, set at play-time).

**Fix:** Replace with `playbackCoordinator.displayTitle` which includes live ICY metadata, buffering status, and proper fallbacks.

**Files:** `MacAmpApp/Views/Components/TrackInfoView.swift` (line 59)

### N3: externalPlaybackHandler Naming Clarity

**Problem:** The name "externalPlaybackHandler" implies playback initiation, but it only updates metadata display state for local tracks (and routes streams to coordinator).

**Fix:** Rename to `onTrackMetadataUpdate` or split into separate `onMetadataUpdate` and `onPlaylistAdvance` callbacks. This is naming-only -- no logic change.

**Files:** `MacAmpApp/Audio/AudioPlayer.swift` (declaration + call site), `MacAmpApp/Audio/PlaybackCoordinator.swift` (init assignment)

---

## Verification Checklist (Post-Fix)

- [ ] Build with Thread Sanitizer passes
- [ ] Stream next/previous navigates correctly in mixed playlist
- [ ] Play/pause indicator correct for both local and stream
- [ ] Track Info shows live ICY metadata during stream
- [ ] No regressions in local file playback
- [ ] Oracle validation of all fixes
- [ ] Unblock streaming-volume-control task
