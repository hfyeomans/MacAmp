# Docs Update Needed: Stream Track Counter

> **Purpose:** Track documentation updates needed for this task's changes.
> **When:** During next docs sweep or before a release.

---

## MACAMP_ARCHITECTURE_GUIDE.md

### Stream Elapsed Time (New Section or add to Audio section)

Document the anchor-based elapsed timer in StreamPlayer:

```
StreamPlayer Elapsed Timer (Anchor-Based)
├─ ContinuousClock.Instant as anchor point
├─ elapsedAccumulated: offset from previous pause/resume cycles
├─ elapsedTime = accumulated + (now - startedAt)
├─ Timer (0.1s) publishes to @Observable property
├─ Starts on .playing, stops on .paused/.buffering/.error
├─ Resets on play(station:)/play(url:)/stop()
├─ Preserved through reconnect (pause, don't reset)
└─ NO reset on ICY metadata change (Winamp classic behavior)
```

### Unified Display Time Flow Diagram

```
Local File Path:
  AudioEngineController.progressTimer
    → AudioPlayer.currentTime / currentDuration
      → PlaybackCoordinator.displayTime / displayDuration
        → MainWindowFullLayer.buildTimeDigits()
        → MainWindowShadeLayer.buildShadeTimeDisplay()

Stream Path:
  StreamPlayer.elapsedTimer (anchor-based)
    → StreamPlayer.elapsedTime (duration = 0)
      → PlaybackCoordinator.displayTime / displayDuration
        → MainWindowFullLayer.buildTimeDigits()
        → MainWindowShadeLayer.buildShadeTimeDisplay()
```

### Playlist Position Flow

```
PlaylistController.currentPosition (1-based, private currentIndex + 1)
  → AudioPlayer.playlistPosition / playlistCount
    → PlaybackCoordinator.trackPositionString ("3/15")
      → PlaybackCoordinator.displayTitle → "3/15. Artist - Title"
```

Guard: `trackPositionString` returns nil when `currentTrack` is nil (non-playlist playback).

### Three-Layer Update

| Layer | Component | Change |
|-------|-----------|--------|
| Mechanism | StreamPlayer.elapsedTime | New anchor-based timer |
| Mechanism | PlaylistController.currentPosition | New computed property |
| Bridge | PlaybackCoordinator.displayTime/displayDuration | New unified time source |
| Bridge | PlaybackCoordinator.trackPositionString | New position display |
| Presentation | MainWindowFullLayer/ShadeLayer | Switched from audioPlayer → coordinator |

## IMPLEMENTATION_PATTERNS.md

### New Pattern: Anchor-Based Timer (vs Accumulator)

```swift
// BAD: accumulator drifts when main run loop stalls
elapsedTime += 0.1  // each tick adds fixed delta — loses time on stalls

// GOOD: anchor-based timing
let elapsed = Self.durationSeconds(startedAt.duration(to: .now))
elapsedTime = elapsedAccumulated + elapsed  // always correct
```

**Why:** `ContinuousClock` is monotonic. The timer only drives UI update frequency — the actual elapsed value is computed from the clock, not accumulated from timer ticks.

### New Pattern: Coordinator-Owned Auto-Play

```swift
// BAD: auto-play as side effect of addTrack()
func addTrack(url: URL) {
    if currentTrack == nil { playTrack(track: placeholder) }  // bypasses coordinator
}

// GOOD: explicit auto-play through coordinator
let wasEmpty = audioPlayer.playlist.isEmpty
audioPlayer.addTrack(url: url)  // pure mutation
await autoPlayFirstTrack(audioPlayer: audioPlayer, coordinator: coordinator, wasEmpty: wasEmpty)
```

**Why:** Playlist mutation and playback orchestration are separate concerns. Side effects in `addTrack()` bypass the coordinator's state tracking (`currentSource`, `displayTime`, etc.).

### New Pattern: Async File Handling for Mixed Types

```swift
// BAD: sync plain files + fire-and-forget async M3U = dual auto-play triggers
handleSelectedURLs(urls)  // sync adds + async M3U Task.detached
autoPlay()  // runs before M3U parse completes

// GOOD: async handler awaits M3U parsing inline
await handleSelectedURLs(urls)  // awaits parseAndAddM3U inline
autoPlay()  // runs after ALL files added
```

### Lesson: Winamp Stream Timer Does NOT Reset on ICY Metadata

Verified from Winamp source code (`in_mp3/DecodeThread.cpp`, `giofile.cpp`):
- `decode_pos_ms` counts continuously from Play until Stop
- ICY metadata changes only update title strings + post `IPC_UPDTITLE`
- No code path resets `decode_pos_ms` on metadata change
- Timer pauses during buffer stalls, resumes counting

## PLAYLIST_WINDOW.md

### Auto-Play Ownership

Document that all auto-play routes through `PlaybackCoordinator.play(track:)`, never through `AudioPlayer.playTrack()` directly. `PlaylistWindowActions.autoPlayFirstTrack()` is the single entry point.

## BUILDING_RETRO_MACOS_APPS_SKILL.md

### Lesson: Anchor-Based Timers for UI Display

When showing elapsed time in a UI, use an anchor point (monotonic clock instant) plus accumulated offset — not a fixed-delta accumulator. Timer delivery is unreliable when the main run loop is busy (slider drags, menu interaction, etc.). The timer should only control update frequency, not the actual time value.

### Lesson: Verify Classic App Behavior from Source Code

Don't assume behavior based on UI observation. The ICY metadata reset was "obvious" from watching Winamp — but the source code showed it never actually resets. Always verify from source code when available (Winamp source at `github.com/alexfreud/winamp`).

### Lesson: loadAudioFile Must Guard Against Crash on Failure

`AVAudioFile` / `ExtAudioFileOpenURL` can fail for many reasons (file not found, remote storage offline, unsupported format). If `loadAudioFile()` fails but doesn't clear the engine state, a subsequent `play()` call will crash with "player started when in a disconnected state". Always clear engine file and transition to stopped on load failure.
