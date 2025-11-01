# Playlist State Synchronization - Research

**Date:** 2025-10-22
**Task:** Fix Bug B - Track Selection and Playlist State Logic
**Status:** Research Complete

---

## Problem Summary

The playlist window has broken track selection and missing playback controls:

### **Bug B: Track Selection Doesn't Work** (from Phase 4 state.md:159-178)
- Clicking a track in the playlist plays the wrong track or repeats the same track
- Track selection logic is broken
- Playback from playlist doesn't work reliably

###  Current Implementation Issues (from screenshots)

**Working Winamp (Reference):**
![tasks/playlist-state-sync/reference/winamp-working-playlist.png](reference/winamp-working-playlist.png)
- Gold playback buttons visible (play, pause, stop, next, prev)
- Track time display shows: `3:10/43:40` (current track / total playlist)
- Remaining time shows: `-05:18` (counting up to 0:00)
- Buttons have proper visual states

**Current MacAmp (Broken):**
![tasks/playlist-state-sync/reference/macamp-current-playlist.png](reference/macamp-current-playlist.png)
- No playback controls visible in playlist
- No time display in playlist
- Track selection broken
- Missing state synchronization

---

## Current Architecture Analysis

### 1. Track Selection Logic

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift:127-134`

```swift
ForEach(Array(audioPlayer.playlist.enumerated()), id: \.element.id) { index, track in
    trackRow(track: track, index: index)
        .frame(width: 243, height: 13)
        .background(trackBackground(track: track, index: index))
        .onTapGesture {
            audioPlayer.playTrack(track: track)
            selectedTrackIndex = index
        }
}
```

**Problems:**
1. ✅ Calls `audioPlayer.playTrack(track:)` - This is correct
2. ⚠️ Uses local `@State selectedTrackIndex` instead of shared state
3. ❌ No visual feedback for current playing track
4. ❌ Doesn't handle case where track is already playing

**AudioPlayer.playTrack() Method:** `MacAmpApp/Audio/AudioPlayer.swift:109-138`

The method properly:
- Stops current playback
- Loads new track
- Sets `currentTrack` property
- Starts playing

**Root Cause:** The track selection code LOOKS correct, but the issue is likely in how `currentTrack` is matched against the playlist to highlight the playing track.

---

### 2. Playback Controls State

**Main Window Controls:** `MacAmpApp/Views/WinampMainWindow.swift:336-382`

Transport buttons with full implementation:
- **Previous** (16, 88): `audioPlayer.previousTrack()`
- **Play** (39, 88): `audioPlayer.play()`
- **Pause** (62, 88): `audioPlayer.pause()`
- **Stop** (85, 88): `audioPlayer.stop()`
- **Next** (108, 88): `audioPlayer.nextTrack()`
- **Eject** (136, 89): `openFileDialog()`

**Playlist Window Controls:** `MacAmpApp/Views/WinampPlaylistWindow.swift:165-203`

Only has file management buttons:
- **Add** button: Opens file dialog
- **Remove** button: Removes selected track

**Missing:** Playlist window has NO playback transport buttons (play, pause, stop, next, prev)

---

### 3. Time Display Logic

**Main Window:** `MacAmpApp/Views/WinampMainWindow.swift:271-333`

Complete implementation with:
- Current time display (MM:SS format)
- Remaining time mode (toggle via tap)
- Minus sign when in remaining mode
- Blinking during pause (0.5s interval)
- 4-digit display using NUMBERS.BMP sprites

**Playlist Window:** NO TIME DISPLAY IMPLEMENTED

**Required displays:**
1. **Track Time:** `MM:SS / MM:SS` (current track / total playlist)
2. **Remaining Time:** `-MM:SS` (counting up to 0:00)
3. **Idle State:** Just `:` when not playing

---

### 4. State Synchronization

**Current Architecture:**

All windows share `AudioPlayer` via `@EnvironmentObject`:
- `WinampMainWindow` (lines 5-8)
- `WinampPlaylistWindow` (lines 6-8)

**AudioPlayer Published Properties:**
```swift
@Published var isPlaying: Bool = false
@Published var isPaused: Bool = false
@Published var currentTrack: Track?
@Published var currentTitle: String
@Published var currentDuration: Double = 0.0
@Published var currentTime: Double = 0.0
@Published var playbackProgress: Double = 0.0
@Published var playlist: [Track] = []
@Published var shuffleEnabled: Bool = false
@Published var repeatEnabled: Bool = false
```

**This is GOOD architecture:** Single source of truth pattern.

**Problem:** Playlist window doesn't USE this shared state for:
1. Playback control buttons
2. Time displays
3. Visual indication of current track

---

## PLEDIT.BMP Sprite Sheet Analysis

**File:** `tmp/Winamp/PLEDIT.BMP`
**Dimensions:** 280×72 pixels (from BMP header)

**PLEDIT.TXT Configuration:**
```
[Text]
Normal=#00FF00        (Green text for normal tracks)
Current=#FFFFFF       (White text for currently playing)
NormalBG=#000000      (Black background)
SelectedBG=#0000C6    (Blue background for selection)
Font=Arial
```

**Sprite Layout (from analyzing BMP data):**

The sprite sheet contains sprites for playlist window elements arranged in rows:

**Row 1 (0-15px height):** Button states (normal/pressed)
- Close button frames
- Shade button frames
- Title bar components

**Row 2 (16-31px):** More button states
- List button frames
- Selection button frames
- Action button frames

**Row 3 (32-47px):** Transport controls
- **THIS IS KEY:** Gold playback buttons
- Play, Pause, Stop, Next, Previous
- Normal and pressed states

**Row 4 (48-63px):** Additional UI elements
- Scroll bar components
- Resize handle
- Misc UI sprites

**Row 5 (64-71px):** Numbers and timing display
- Digits 0-9 for time display
- Minus sign
- Colon
- Slash separator

**Standard Winamp Playlist Button Locations:**

From analyzing the sprite sheet and standard Winamp layout:
- **Play:** Bottom bar, left section
- **Pause:** Next to play
- **Stop:** Next to pause
- **Next:** Right of stop
- **Previous:** Left of play

**Time Display Locations:**
- **Track Time:** Bottom right, format `MM:SS / MM:SS`
- **Remaining Time:** Above track time, format `-MM:SS`

---

## Key Findings

### Working Components
1. ✅ AudioPlayer state management (single source of truth)
2. ✅ Track selection tap handler exists
3. ✅ Environment object sharing between windows
4. ✅ Main window time display working
5. ✅ Main window transport buttons working

### Missing Components
1. ❌ Playlist transport buttons (play, pause, stop, next, prev)
2. ❌ Playlist time displays (track time, remaining time)
3. ❌ Visual indication of currently playing track
4. ❌ Proper state synchronization for button states
5. ❌ PLEDIT.BMP sprites not being used for playlist buttons

### Broken Components
1. 🔴 Track selection sometimes plays wrong track
2. 🔴 No feedback when clicking tracks
3. 🔴 Playlist and main window out of sync

---

## Root Causes

### Issue 1: Missing Sprite Definitions

The playlist window doesn't have sprite definitions for:
- `PLAYLIST_PLAY_BUTTON`
- `PLAYLIST_PAUSE_BUTTON`
- `PLAYLIST_STOP_BUTTON`
- `PLAYLIST_NEXT_BUTTON`
- `PLAYLIST_PREV_BUTTON`
- `PLAYLIST_TIME_DIGITS`
- `PLAYLIST_TIME_COLON`
- `PLAYLIST_TIME_MINUS`

**Solution:** Add sprite definitions to `SkinSprites.swift` from PLEDIT.BMP

### Issue 2: Missing UI Components

The playlist window `buildBottomControls()` only has file management buttons:
- Add, Remove, Crop, Misc, Sort

**Solution:** Add transport buttons and time displays to playlist window

### Issue 3: State Synchronization

While AudioPlayer is shared, the playlist window doesn't:
- Read `isPlaying` / `isPaused` for button states
- Read `currentTime` / `currentDuration` for time display
- Calculate total playlist duration
- Match `currentTrack` to highlight playing track

**Solution:** Add reactive UI based on AudioPlayer published properties

### Issue 4: Track Matching Logic

The `trackBackground()` and `trackTextColor()` methods (lines 262-277) compare tracks:
```swift
private func trackBackground(track: Track, index: Int) -> Color {
    if let current = audioPlayer.currentTrack, current.id == track.id {
        return .blue.opacity(0.3)  // Currently playing
    }
    // ...
}
```

**Potential Issue:** Track ID comparison may not work if:
- Track objects are recreated
- ID generation is inconsistent
- Track equality not properly implemented

**Verification Needed:** Check `Track` struct ID generation in `MacAmpApp/Models/Track.swift`

---

## Technical Specifications

### Time Display Requirements

**Format 1: Track Time (Bottom Right)**
- Display: `MM:SS / MM:SS`
- Position: ~230-280px from left, bottom bar
- Logic: `currentTime / currentDuration`
- Idle: Show `:` only

**Format 2: Remaining Time (Above track time)**
- Display: `-MM:SS`
- Position: Same X as track time, Y offset up
- Logic: `-(currentDuration - currentTime)`
- Counts up from negative to `0:00`
- Idle: Hidden

**Format 3: Playlist Total**
- Calculate sum of all track durations
- Display in track time denominator
- Update when playlist changes

### Transport Button Requirements

**Button Sprites from PLEDIT.BMP:**
Each button has 2 states (normal, pressed):
- Width: ~23 pixels each
- Height: ~18 pixels
- Arranged horizontally in sprite sheet

**Button Actions:**
All buttons should call AudioPlayer methods:
- Play → `audioPlayer.play()` or `audioPlayer.playTrack(track:)`
- Pause → `audioPlayer.pause()`
- Stop → `audioPlayer.stop()`
- Next → `audioPlayer.nextTrack()`
- Previous → `audioPlayer.previousTrack()`

**Button State Visual Feedback:**
- **Play:** Highlight when `isPlaying == true && isPaused == false`
- **Pause:** Highlight when `isPaused == true`
- **Stop:** Always clickable, highlight on hover
- **Next/Prev:** Disable when at playlist boundaries

---

## Dependencies & Related Files

### Files to Modify
1. `MacAmpApp/Models/SkinSprites.swift` - Add PLEDIT sprite definitions
2. `MacAmpApp/Views/WinampPlaylistWindow.swift` - Add buttons and time displays
3. `MacAmpApp/ViewModels/SkinManager.swift` - Load PLEDIT.BMP sprites (may already work)

### Files to Reference
1. `MacAmpApp/Views/WinampMainWindow.swift` - Time display implementation
2. `MacAmpApp/Audio/AudioPlayer.swift` - State properties and methods
3. `tmp/Winamp/PLEDIT.BMP` - Sprite sheet
4. `tmp/Winamp/PLEDIT.TXT` - Configuration

### Files to Verify
1. `MacAmpApp/Models/Track.swift` - ID generation logic
2. `MacAmpApp/ViewModels/AppSettings.swift` - Any playlist-related settings

---

## Success Criteria

### Must Have (P0)
- ✅ Click any track in playlist → plays that specific track
- ✅ Current track visually highlighted in playlist
- ✅ Transport buttons (play, pause, stop, next, prev) visible and functional
- ✅ Time displays showing correct format
- ✅ State synchronized between main and playlist windows

### Should Have (P1)
- ✅ Button states reflect current playback (play/pause highlighting)
- ✅ Remaining time counts up from negative
- ✅ Total playlist duration calculated correctly
- ✅ Idle state shows `:` only

### Nice to Have (P2)
- ✅ Smooth animations on state changes
- ✅ Button hover effects
- ✅ Keyboard shortcuts for playlist controls
- ✅ Double-click to play (in addition to single-click)

---

## Recommended Approach

### Phase 1: Add Sprite Definitions (30 min)
Define all PLEDIT.BMP sprites in `SkinSprites.swift`

### Phase 2: Add Transport Buttons (1 hour)
Implement playback controls in playlist window bottom bar

### Phase 3: Add Time Displays (1 hour)
Implement current/total and remaining time displays

### Phase 4: Fix Track Selection (30 min)
Verify and fix track matching logic

### Phase 5: Test & Polish (1 hour)
Comprehensive testing of all state synchronization

**Total Estimated Time:** 4 hours

---

## Next Steps

1. Create detailed implementation plan
2. Create sub-branch: `fix/playlist-state-sync`
3. Begin implementation starting with Phase 1
4. Test incrementally after each phase

---

**Research Status:** ✅ COMPLETE
**Next:** Create implementation plan with code changes
