# Plan: Stream Track Counter

> **Purpose:** Implementation plan for stream elapsed time counter and playlist track position display.

**Status:** Revised after Oracle review (7/10 → revised). Ready for implementation.

---

## Scope

Two features:
1. **Stream elapsed time** — upward-counting timer in main window during internet radio playback
2. **Playlist track position** — "3/15" display showing current track number / total

## Changes

### Phase 1: Stream Elapsed Time (Mechanism Layer)

**File:** `MacAmpApp/Audio/StreamPlayer.swift`

Add anchor-based elapsed time tracking (not `+= 0.1` accumulation — Oracle finding: timer drift):

```swift
private(set) var elapsedTime: Double = 0
@ObservationIgnored private var elapsedTimer: Timer?
@ObservationIgnored private var elapsedAccumulated: Double = 0
@ObservationIgnored private var elapsedStartedAt: ContinuousClock.Instant?
```

**Logic:**
- When state → `.playing`: record `elapsedStartedAt = .now`
- Timer fires every 0.1s: publish `elapsedTime = elapsedAccumulated + startedAt.duration(to: .now)`
- When state → `.paused`/`.buffering`: accumulate `elapsedAccumulated += startedAt.duration(to: .now)`, clear `startedAt`
- On `play(station:)`, `play(url:)`, `stop()`: reset all to 0
- On ICY metadata change (new track): reset all to 0

**ICY metadata reset trigger** — Oracle finding: use normalized `(title, artist)` pair, not title alone. Ignore empty/duplicate updates. Track last seen pair to detect actual changes:

```swift
@ObservationIgnored private var lastNowPlayingIdentity: (String, String)?

// In metadata callback:
let identity = (metadata.title ?? "", metadata.artist ?? "")
if identity != lastNowPlayingIdentity && !identity.0.isEmpty {
    lastNowPlayingIdentity = identity
    resetElapsedTime()  // New track on same station
}
```

### Phase 2: Unified Time Properties (Bridge Layer)

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

Add computed display time properties (Oracle confirmed: computed, not stored):

```swift
var displayTime: Double {
    switch currentSource {
    case .radioStation: return streamPlayer.elapsedTime
    case .localTrack: return audioPlayer.currentTime
    case nil: return 0
    }
}

var displayDuration: Double {
    switch currentSource {
    case .radioStation: return 0  // streams have no known duration
    case .localTrack: return audioPlayer.currentDuration
    case nil: return 0
    }
}
```

### Phase 3: Playlist Position (Bridge Layer — Oracle finding: must be on coordinator)

**File:** `MacAmpApp/Audio/PlaylistController.swift`

Expose position:

```swift
var currentPosition: Int? {
    guard let idx = currentIndex else { return nil }
    return idx + 1
}
```

**File:** `MacAmpApp/Audio/PlaybackCoordinator.swift`

Coordinator-owned position string (Oracle finding: avoids stale values during non-playlist playback):

```swift
var trackPositionString: String? {
    // Only show position when playing from the playlist (not direct station URLs)
    guard currentSource != nil,
          let position = audioPlayer.playlistController.currentPosition else { return nil }
    let count = audioPlayer.playlist.count
    return "\(position)/\(count)"
}
```

Guard: returns nil when `currentTrack` is nil or during direct station playback not backed by a playlist entry.

### Phase 4: View Updates (Presentation Layer)

**Files:** `MainWindowFullLayer.swift`, `MainWindowShadeLayer.swift`

Change time display to read from `PlaybackCoordinator`:

```swift
// BEFORE:
let time = settings.timeDisplayMode == .remaining
    ? max(0.0, audioPlayer.currentDuration - audioPlayer.currentTime)
    : audioPlayer.currentTime

// AFTER:
let duration = playbackCoordinator.displayDuration
let time = settings.timeDisplayMode == .remaining && duration > 0
    ? max(0.0, duration - playbackCoordinator.displayTime)
    : playbackCoordinator.displayTime
```

When `displayDuration == 0` (streams), remaining mode suppressed — always shows elapsed. Minus-sign sprite hidden.

### Phase 5: Track Position Display (Presentation Layer)

Prepend track position to the title ticker in `PlaybackCoordinator.displayTitle`:

```swift
// In displayTitle computed property, for local tracks:
if let pos = trackPositionString {
    return "\(pos). \(title)"
}
```

This matches Winamp's pattern of showing "3/15. Artist - Title" in the title bar ticker.

## Non-Changes

- `TimeDisplayMode` enum unchanged
- `AppSettings` unchanged
- `AudioEngineController` unchanged
- No new files created
- No sprite changes

## Verification

1. Build with Thread Sanitizer — no new warnings
2. All tests pass
3. Manual: play internet radio — time counts up from 00:00
4. Manual: ICY metadata (title+artist) change — time resets to 00:00
5. Manual: pause stream — time stops
6. Manual: resume stream — time continues
7. Manual: reconnect — time pauses, continues after reconnect
8. Manual: play local file — elapsed/remaining works as before
9. Manual: remaining mode toggle during stream — stays in elapsed
10. Manual: playlist position shows "3/15" for local file playlists
11. Manual: direct stream URL (not from playlist) — no stale position shown
