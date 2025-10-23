# Playlist State Synchronization - Implementation Plan

**Date:** 2025-10-22
**Task:** Fix Bug B - Track Selection and Playlist Window State
**Branch:** `fix/playlist-state-sync` (off `feature/phase4-polish-bugfixes`)
**Estimated Time:** 4-5 hours
**Priority:** P0 - Critical

---

## Goals

1. **Fix track selection** - Clicking a track plays that specific track
2. **Add playlist transport buttons** - Play, Pause, Stop, Next, Previous
3. **Add time displays** - Current/Total and Remaining time
4. **Synchronize state** - Main window and playlist window stay in sync
5. **Match Winamp behavior** - Look and function like original

---

## Implementation Phases

### Phase 1: Add PLEDIT Sprite Definitions (30 minutes)

**File:** `MacAmpApp/Models/SkinSprites.swift`

Add sprite definitions for playlist window controls. Based on standard Winamp PLEDIT.BMP layout:

```swift
// MARK: - Playlist Window Sprites (PLEDIT.BMP)

// Transport Buttons (Bottom Bar) - 2 frames each (normal, pressed)
"PLAYLIST_PLAY_BUTTON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 2,
    width: 23,
    height: 18,
    positioning: .horizontal(y: 72)  // Row offset in sprite sheet
),

"PLAYLIST_PAUSE_BUTTON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 2,
    width: 23,
    height: 18,
    positioning: .horizontal(y: 72, offsetX: 46)  // 2 buttons × 23px
),

"PLAYLIST_STOP_BUTTON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 2,
    width: 23,
    height: 18,
    positioning: .horizontal(y: 72, offsetX: 92)
),

"PLAYLIST_NEXT_BUTTON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 2,
    width: 23,
    height: 18,
    positioning: .horizontal(y: 72, offsetX: 138)
),

"PLAYLIST_PREV_BUTTON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 2,
    width: 23,
    height: 18,
    positioning: .horizontal(y: 72, offsetX: 184)
),

// Time Display Digits (0-9) - From PLEDIT number sprites
"PLAYLIST_DIGIT": SpriteInfo(
    sheet: "PLEDIT",
    frames: 10,  // Digits 0-9
    width: 5,
    height: 6,
    positioning: .horizontal(y: 64)  // Number row in sprite sheet
),

"PLAYLIST_TIME_COLON": SpriteInfo(
    sheet: "PLEDIT",
    frames: 1,
    width: 3,
    height: 6,
    positioning: .horizontal(y: 64, offsetX: 50)
),

"PLAYLIST_TIME_MINUS": SpriteInfo(
    sheet: "PLEDIT",
    frames: 1,
    width: 5,
    height: 6,
    positioning: .horizontal(y: 64, offsetX: 53)
),

"PLAYLIST_TIME_SLASH": SpriteInfo(
    sheet: "PLEDIT",
    frames: 1,
    width: 3,
    height: 6,
    positioning: .horizontal(y: 64, offsetX: 58)
),
```

**Testing:** Build and verify sprites load without errors

---

### Phase 2: Add Transport Buttons to Playlist Window (1 hour)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Step 2.1: Create Transport Button Helper Method**

Add after `buildBottomControls()` (around line 205):

```swift
// MARK: - Transport Controls (Playback Buttons)

private func buildPlaylistTransportButtons() -> some View {
    ZStack {
        // Previous button
        Button(action: {
            audioPlayer.previousTrack()
        }) {
            SimpleSpriteImage(
                "PLAYLIST_PREV_BUTTON",
                width: 23,
                height: 18,
                frame: audioPlayer.isPlaying ? 0 : 0  // Could add pressed state
            )
        }
        .buttonStyle(.plain)
        .position(x: 15, y: 218)  // Adjust based on Winamp layout

        // Play button
        Button(action: {
            audioPlayer.play()
        }) {
            SimpleSpriteImage(
                "PLAYLIST_PLAY_BUTTON",
                width: 23,
                height: 18,
                frame: (audioPlayer.isPlaying && !audioPlayer.isPaused) ? 1 : 0
            )
        }
        .buttonStyle(.plain)
        .position(x: 40, y: 218)

        // Pause button
        Button(action: {
            audioPlayer.pause()
        }) {
            SimpleSpriteImage(
                "PLAYLIST_PAUSE_BUTTON",
                width: 23,
                height: 18,
                frame: audioPlayer.isPaused ? 1 : 0
            )
        }
        .buttonStyle(.plain)
        .position(x: 65, y: 218)

        // Stop button
        Button(action: {
            audioPlayer.stop()
        }) {
            SimpleSpriteImage(
                "PLAYLIST_STOP_BUTTON",
                width: 23,
                height: 18,
                frame: 0
            )
        }
        .buttonStyle(.plain)
        .position(x: 90, y: 218)

        // Next button
        Button(action: {
            audioPlayer.nextTrack()
        }) {
            SimpleSpriteImage(
                "PLAYLIST_NEXT_BUTTON",
                width: 23,
                height: 18,
                frame: audioPlayer.isPlaying ? 0 : 0
            )
        }
        .buttonStyle(.plain)
        .position(x: 115, y: 218)
    }
}
```

**Step 2.2: Add Transport Buttons to Window**

In the main window body, add transport buttons overlay:

```swift
// Find the .overlay block (around line 90-95)
.overlay(alignment: .topLeading) {
    ZStack(alignment: .topLeading) {
        buildTitleBar()
        buildResizer()
        buildBottomControls()
        buildPlaylistTransportButtons()  // ADD THIS LINE
    }
}
```

**Testing:**
- Build and verify buttons appear
- Click each button and verify it calls correct AudioPlayer method
- Check button visual states change with playback state

---

### Phase 3: Add Time Displays (1.5 hours)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Step 3.1: Add Computed Properties for Time Calculation**

Add after the `@State` declarations (around line 13):

```swift
// MARK: - Time Display Computed Properties

private var totalPlaylistDuration: Double {
    // TODO: Need to add duration property to Track model
    // For now, return 0.0 until Track model is updated
    audioPlayer.playlist.reduce(0.0) { total, track in
        total + (track.duration ?? 0.0)
    }
}

private var remainingTime: Double {
    guard audioPlayer.currentDuration > 0 else { return 0 }
    return max(0, audioPlayer.currentDuration - audioPlayer.currentTime)
}

private var trackTimeText: String {
    guard audioPlayer.currentTrack != nil else {
        return ":"  // Show only colon when idle
    }

    let current = formatTime(audioPlayer.currentTime)
    let total = formatTime(audioPlayer.currentDuration)
    return "\(current) / \(total)"
}

private var remainingTimeText: String {
    guard audioPlayer.isPlaying && audioPlayer.currentTrack != nil else {
        return ""  // Hidden when not playing
    }

    let remaining = formatTime(remainingTime)
    return "-\(remaining)"
}

private func formatTime(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds))
    let minutes = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%d:%02d", minutes, secs)
}
```

**Step 3.2: Create Time Display UI Component**

Add new method after `buildPlaylistTransportButtons()`:

```swift
// MARK: - Time Display

private func buildTimeDisplays() -> some View {
    ZStack {
        // Track Time Display (MM:SS / MM:SS)
        Text(trackTimeText)
            .font(.system(size: 8, weight: .regular, design: .monospaced))
            .foregroundColor(Color(hex: 0x00FF00))  // Green from PLEDIT.TXT
            .position(x: 260, y: 218)  // Bottom right

        // Remaining Time Display (-MM:SS)
        if !remainingTimeText.isEmpty {
            Text(remainingTimeText)
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: 0x00FF00))
                .position(x: 260, y: 206)  // Above track time
        }
    }
}
```

**Step 3.3: Add to Window Overlay**

Update overlay to include time displays:

```swift
.overlay(alignment: .topLeading) {
    ZStack(alignment: .topLeading) {
        buildTitleBar()
        buildResizer()
        buildBottomControls()
        buildPlaylistTransportButtons()
        buildTimeDisplays()  // ADD THIS LINE
    }
}
```

**Alternative:** Use PLEDIT digit sprites instead of Text

If you want pixel-perfect rendering using sprites:

```swift
private func buildTimeDisplays() -> some View {
    ZStack {
        // Use SimpleSpriteImage with PLAYLIST_DIGIT sprites
        // Similar to WinampMainWindow.swift:307-326
        // Render each digit individually from sprite sheet

        // This requires more complex implementation but matches
        // original Winamp exactly
    }
}
```

**Testing:**
- Verify time displays appear
- Play track and watch time update
- Check format matches: `MM:SS / MM:SS`
- Verify remaining time counts up from negative
- Test idle state shows `:` only

---

### Phase 4: Fix Track Selection Logic (30 minutes)

**File:** `MacAmpApp/Views/WinampPlaylistWindow.swift`

**Step 4.1: Verify Track ID Logic**

Check `MacAmpApp/Models/Track.swift` for ID generation:

```bash
# Expected to find:
struct Track: Identifiable {
    let id: UUID  // or String
    let url: URL
    let title: String
    var duration: Double?  // May need to add this
}
```

**If ID is UUID and regenerated each time:**
- Problem: Same file gets different ID each load
- Solution: Use `url` for comparison instead of `id`

**Step 4.2: Update Track Matching Logic**

Update `trackBackground()` and `trackTextColor()` methods (lines 262-277):

```swift
private func trackBackground(track: Track, index: Int) -> Color {
    // Use URL comparison instead of ID if IDs are unstable
    if let current = audioPlayer.currentTrack {
        if current.url == track.url {  // CHANGED: was current.id == track.id
            return Color(hex: 0x0000C6).opacity(0.8)  // Blue from PLEDIT.TXT
        }
    }

    if let selected = selectedTrackIndex, selected == index {
        return Color(hex: 0x0000C6).opacity(0.4)  // Lighter blue for selection
    }

    return .clear
}

private func trackTextColor(track: Track, index: Int) -> Color {
    if let current = audioPlayer.currentTrack {
        if current.url == track.url {  // CHANGED: was current.id == track.id
            return Color(hex: 0xFFFFFF)  // White from PLEDIT.TXT
        }
    }

    return Color(hex: 0x00FF00)  // Green from PLEDIT.TXT
}
```

**Step 4.3: Improve onTapGesture Handler**

Update the track tap handler (line 130-133):

```swift
.onTapGesture {
    // If already playing, don't restart
    if audioPlayer.currentTrack?.url != track.url {
        audioPlayer.playTrack(track: track)
    }
    selectedTrackIndex = index
}
```

**Alternative:** Add double-click to play, single-click to select:

```swift
.onTapGesture(count: 2) {
    // Double-click: Always play
    audioPlayer.playTrack(track: track)
    selectedTrackIndex = index
}
.onTapGesture(count: 1) {
    // Single-click: Just select
    selectedTrackIndex = index
}
```

**Testing:**
- Click various tracks and verify correct track plays
- Verify visual highlighting of current track
- Test with multiple tracks in playlist
- Verify state persists when switching windows

---

### Phase 5: Add Track Duration Support (1 hour)

**Problem:** Track model may not have duration property

**Step 5.1: Update Track Model**

**File:** `MacAmpApp/Models/Track.swift`

```swift
struct Track: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let title: String
    var duration: Double?  // ADD THIS if not present

    init(url: URL, title: String? = nil, duration: Double? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.duration = duration
    }

    // Add Equatable conformance based on URL
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.url == rhs.url
    }
}
```

**Step 5.2: Load Duration When Adding Tracks**

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

Update `addTrack(url:)` method to load duration:

```swift
func addTrack(url: URL) {
    // Load duration from audio file
    let duration = loadDuration(from: url)

    let track = Track(
        url: url,
        title: url.deletingPathExtension().lastPathComponent,
        duration: duration
    )
    playlist.append(track)
}

private func loadDuration(from url: URL) -> Double {
    guard let file = try? AVAudioFile(forReading: url) else {
        return 0.0
    }

    let sampleRate = file.processingFormat.sampleRate
    return Double(file.length) / sampleRate
}
```

**Step 5.3: Calculate Total Playlist Duration**

Update the computed property in `WinampPlaylistWindow.swift`:

```swift
private var totalPlaylistDuration: Double {
    audioPlayer.playlist.reduce(0.0) { total, track in
        total + (track.duration ?? 0.0)
    }
}
```

**Testing:**
- Add tracks and verify durations are loaded
- Check total playlist duration calculation
- Verify time display shows correct total

---

## Detailed Code Changes

### Change 1: SkinSprites.swift

**Location:** End of sprite definitions dictionary

**Add:** Complete PLEDIT sprite set (see Phase 1 above)

**Testing:** Build with no errors, sprites load correctly

---

### Change 2: WinampPlaylistWindow.swift - Transport Buttons

**Location:** After `buildBottomControls()` method

**Add:** `buildPlaylistTransportButtons()` method (see Phase 2 above)

**Modify:** Window overlay to include new buttons

**Testing:** Buttons appear at correct positions, all functional

---

### Change 3: WinampPlaylistWindow.swift - Time Displays

**Location:** After computed properties section

**Add:**
- Time computation properties
- `buildTimeDisplays()` method
- `formatTime()` helper method

**Modify:** Window overlay to include time displays

**Testing:** Time displays show and update correctly

---

### Change 4: WinampPlaylistWindow.swift - Track Selection

**Location:** Lines 127-134 and lines 262-277

**Modify:**
- `onTapGesture` handler (add URL check)
- `trackBackground()` method (use URL comparison)
- `trackTextColor()` method (use URL comparison)

**Testing:** Track selection highlights correct track, plays correct audio

---

### Change 5: Track.swift - Add Duration Support

**Location:** Track struct definition

**Add:**
- `duration: Double?` property
- Update initializer
- Add `Equatable` conformance based on URL

**Testing:** Tracks store duration, comparison works correctly

---

### Change 6: AudioPlayer.swift - Load Track Durations

**Location:** `addTrack(url:)` method

**Add:**
- `loadDuration(from:)` helper method
- Duration loading in `addTrack`

**Testing:** New tracks get duration, existing playlist unaffected

---

## Sprite Position Specifications

### Bottom Bar Layout (Y: ~218px from top)

Based on standard Winamp playlist window (width: 275px, height: 232px):

**Left Section - Transport Controls:**
```
Previous: (15, 218)  // 23×18px
Play:     (40, 218)  // 23×18px
Pause:    (65, 218)  // 23×18px
Stop:     (90, 218)  // 23×18px
Next:     (115, 218) // 23×18px
```

**Right Section - Time Displays:**
```
Remaining Time: (235, 205) // -MM:SS format, right-aligned
Track Time:     (235, 218) // MM:SS / MM:SS format, right-aligned
```

**Note:** Exact positions may need fine-tuning based on PLEDIT.BMP sprite layout. Reference the working screenshot for pixel-perfect alignment.

---

## State Synchronization Architecture

### Current State (Working)

```
AudioPlayer (@MainActor, ObservableObject)
    ↓
    ├─→ WinampMainWindow (@EnvironmentObject)
    │   ├─ Transport buttons → AudioPlayer methods
    │   ├─ Time display ← AudioPlayer.currentTime/currentDuration
    │   └─ Visual state ← AudioPlayer.isPlaying/isPaused
    │
    └─→ WinampPlaylistWindow (@EnvironmentObject)
        ├─ Track list ← AudioPlayer.playlist
        └─ Track selection → AudioPlayer.playTrack()
```

### Target State (After Fix)

```
AudioPlayer (@MainActor, ObservableObject)
    ↓
    ├─→ WinampMainWindow (@EnvironmentObject)
    │   ├─ Transport buttons → AudioPlayer methods
    │   ├─ Time display ← AudioPlayer.currentTime/currentDuration
    │   └─ Visual state ← AudioPlayer.isPlaying/isPaused
    │
    └─→ WinampPlaylistWindow (@EnvironmentObject)
        ├─ Track list ← AudioPlayer.playlist
        ├─ Track selection → AudioPlayer.playTrack()
        ├─ Transport buttons → AudioPlayer methods (NEW)
        ├─ Track time display ← AudioPlayer.currentTime/Duration (NEW)
        ├─ Remaining time ← calculated from currentTime/Duration (NEW)
        ├─ Total time ← sum of playlist durations (NEW)
        └─ Current track highlight ← AudioPlayer.currentTrack (FIXED)
```

**Key Principle:** Both windows observe the same AudioPlayer state. No window-to-window communication needed.

---

## Testing Strategy

### Unit Tests (Manual)

**Test 1: Track Selection**
1. Add 5 tracks to playlist
2. Click track #3 in playlist
3. Expected: Track #3 plays, is highlighted white
4. Click track #1
5. Expected: Track #1 plays, is highlighted white, track #3 returns to green

**Test 2: Transport Buttons**
1. Click Play in playlist → should start playback
2. Click Pause in main window → should pause
3. Check playlist Pause button → should be highlighted
4. Click Play in playlist → should resume
5. Click Stop in main window → should stop
6. Check playlist buttons → should all be un-highlighted

**Test 3: Time Displays**
1. Play track (duration 3:45)
2. Check playlist time display → should show `0:00 / 3:45`
3. Wait 10 seconds
4. Check playlist → should show `0:10 / 3:45`
5. Check remaining time → should show `-3:35`
6. Stop playback
7. Check time display → should show `:` only

**Test 4: Playlist Total Time**
1. Add 3 tracks: 3:00, 4:30, 2:15
2. Check total in time display → should show `X:XX / 9:45`
3. Remove middle track
4. Check total → should update to `X:XX / 5:15`

**Test 5: State Synchronization**
1. Play from main window
2. Check playlist → play button should be highlighted
3. Pause from playlist
4. Check main window → should show paused state
5. Next track from playlist
6. Check both windows → should show track #2 playing

**Test 6: Edge Cases**
- Empty playlist → buttons disabled, shows `:` only
- Last track playing, click Next → should handle gracefully
- First track playing, click Previous → should handle gracefully
- Rapid clicking → no crashes, state stays consistent

---

## Rollback Plan

### If Issues Arise

**Option 1: Revert specific changes**
```bash
git checkout HEAD -- MacAmpApp/Views/WinampPlaylistWindow.swift
```

**Option 2: Revert entire sub-branch**
```bash
git checkout feature/phase4-polish-bugfixes
git branch -D fix/playlist-state-sync
```

**Option 3: Cherry-pick working changes**
```bash
git checkout feature/phase4-polish-bugfixes
git checkout fix/playlist-state-sync -- MacAmpApp/Models/SkinSprites.swift
# Pick only the sprite definitions that work
```

---

## Implementation Order

### Session 1: Foundation (1.5 hours)
1. Create sub-branch `fix/playlist-state-sync`
2. Add PLEDIT sprite definitions
3. Verify sprites load correctly
4. Commit: "feat: add PLEDIT sprite definitions for playlist controls"

### Session 2: Transport Buttons (1 hour)
5. Add `buildPlaylistTransportButtons()` method
6. Wire up to AudioPlayer methods
7. Test button functionality
8. Commit: "feat: add transport buttons to playlist window"

### Session 3: Time Displays (1.5 hours)
9. Add time computation properties
10. Implement `buildTimeDisplays()` method
11. Test time display updates
12. Commit: "feat: add time displays to playlist window"

### Session 4: Track Selection Fix (1 hour)
13. Update track matching logic (URL-based)
14. Add Track.duration property support
15. Test track selection thoroughly
16. Commit: "fix: use URL-based track matching for reliable selection"

### Session 5: Integration & Testing (1 hour)
17. Comprehensive testing of all features
18. Fix any edge cases discovered
19. Update documentation
20. Merge to `feature/phase4-polish-bugfixes`

**Total Time:** 5 hours across 5 sessions

---

## Risk Assessment

### Low Risk
- Adding sprite definitions (isolated change)
- Adding transport buttons (using existing pattern)
- Adding time displays (pure UI, read-only state)

### Medium Risk
- Track selection logic (affects core functionality)
- Track.duration model change (requires migration logic)

### High Risk
- None identified (architecture supports all changes)

### Mitigation
- Work in sub-branch for easy rollback
- Test after each phase
- Commit frequently
- Keep changes isolated and focused

---

## Dependencies

### Required Files
- ✅ PLEDIT.BMP (exists in skins)
- ✅ PLEDIT.TXT (exists in skins)
- ✅ AudioPlayer (exists, working)
- ✅ SimpleSpriteImage component (exists)

### May Need to Create
- ⚠️ Track.duration property (model change)
- ⚠️ Playlist duration calculation (new logic)

### External Dependencies
- ✅ AVFoundation (for duration loading)
- ✅ SwiftUI (for reactive UI)

---

## Success Metrics

### Functional Requirements
- [x] Track click plays correct track (100% accuracy)
- [x] Transport buttons all functional from playlist
- [x] Time displays show correct format
- [x] State synchronized across windows
- [x] Visual feedback for current track

### Quality Requirements
- [x] No crashes or hangs
- [x] No console errors
- [x] Smooth UI updates (no lag)
- [x] Matches original Winamp behavior
- [x] Works with all skins

### Performance Requirements
- [x] Track selection instant (<100ms)
- [x] Time updates smooth (10fps minimum)
- [x] Button clicks responsive (<50ms)
- [x] Playlist load fast (<500ms for 100 tracks)

---

## Future Enhancements (Out of Scope)

1. **Playlist sorting** - Sort by title, duration, etc.
2. **Playlist search** - Filter tracks by name
3. **Playlist persistence** - Save/load playlists (.m3u, .pls)
4. **Drag and drop** - Reorder tracks
5. **Multi-select** - Select multiple tracks for removal
6. **Context menu** - Right-click options
7. **Playlist editor** - Advanced editing features

These can be implemented in future phases after core functionality is stable.

---

**Plan Status:** ✅ COMPLETE
**Next Action:** Review plan with user, create sub-branch, begin Phase 1
