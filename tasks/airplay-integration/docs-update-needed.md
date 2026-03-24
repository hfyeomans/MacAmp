# Docs Update Needed: AirPlay Integration

> **Purpose:** Notes on architecture changes, customer-facing features, and flow diagrams needed for documentation and skills file updates.

**Date:** 2026-03-24
**Task:** airplay-integration (Sprint S2)

---

## Customer-Facing Features Added

### Now Playing Integration (Phase 2)
- **macOS Control Center:** Track title, artist, duration, and progress bar shown in Control Center "Now Playing" widget
- **Keyboard media keys:** Play/pause, next track, previous track work on Apple keyboards and Bluetooth headphones
- **Control Center transport:** Play/pause, next, previous, and seek (scrub) via Control Center UI
- **Stream metadata:** ICY/Shoutcast stream title and artist displayed in Control Center, updates live on metadata change
- **Bluetooth headphone buttons:** Play/pause and skip controls work on paired Bluetooth headphones
- **Seek scrubbing:** Progress bar in Control Center is interactive for local files; auto-disabled for live streams
- **Smart command enablement:** Next/previous disabled when no playlist context (e.g., playing a direct station); seek disabled for streams; all commands disabled on stop/playback finished
- **Lifecycle completeness:** Now Playing clears automatically when last track finishes, when playback stops, on stream terminal errors, and during reconnect backoff — no stale entries left in Control Center

### Time Display Bugfix (Phase 0)
- **Fixed:** Clicking the time digits now correctly toggles elapsed/remaining display
- **Previously:** Click target was displaced to the top-left bolt icon area due to `.contentShape()` after `.offset()` ordering bug

---

## Architecture Changes

### New: Now Playing Layer in PlaybackCoordinator (Bridge Layer)

```
Mechanism Layer:
├─ AudioPlayer
│  ├─ onPlaylistAdvanceRequest (existing) — coordinator handles track advance
│  ├─ onTrackMetadataUpdate (existing) — coordinator updates display
│  └─ onPlaybackFinished (NEW) — fires when playback ends with no next track
├─ StreamPlayer
│  ├─ onFormatReady (existing) — activates engine bridge
│  ├─ onStreamTerminated (existing) — deactivates engine bridge
│  ├─ onMetadataChanged (NEW) — fires on ICY title/artist update
│  └─ onStreamStateChanged (NEW) — fires on pipeline state transition + terminal/reconnect

Bridge Layer:
├─ PlaybackCoordinator
│  ├─ updateNowPlayingInfo() (NEW) — publishes to MPNowPlayingInfoCenter
│  │  ├─ Title: displayTitle (unified local + stream)
│  │  ├─ Artist: displayArtist (unified local + stream)
│  │  ├─ Elapsed: displayTime (unified local + stream)
│  │  ├─ Duration: displayDuration (0 for streams)
│  │  ├─ Rate: 1.0 (playing) / 0.0 (paused/stopped)
│  │  ├─ playbackState: .playing / .paused / .stopped (REQUIRED on macOS)
│  │  └─ Seek command: enabled for local, disabled for streams
│  ├─ clearNowPlayingInfo() (NEW) — clears info + sets .stopped + disables seek
│  └─ setupRemoteCommands() (NEW) — wires MPRemoteCommandCenter
│     ├─ play → resume()
│     ├─ pause → pause()
│     ├─ togglePlayPause → togglePlayPause()
│     ├─ nextTrack → next()
│     ├─ previousTrack → previous()
│     └─ changePlaybackPosition → audioPlayer.seek(to:)
│     All dispatch via Task { @MainActor } (handlers fire on arbitrary thread)

Presentation Layer:
├─ (No changes — Now Playing is system UI, not MacAmp UI)
```

### Now Playing Update Flow Diagram

```
                    ┌──────────────────────────────┐
                    │     updateNowPlayingInfo()    │
                    │  (PlaybackCoordinator)        │
                    └──────────────┬───────────────┘
                                   │
            Called from 10 trigger points:
                                   │
    ┌──────────────────────────────┼──────────────────────────────┐
    │ PlaybackCoordinator methods  │ Callback-driven              │
    ├──────────────────────────────┼──────────────────────────────┤
    │ 1. play(track:)              │ 8. onMetadataChanged         │
    │ 2. play(station:)            │    (ICY title/artist)        │
    │ 3. pause()                   │ 9. onStreamStateChanged      │
    │ 4. stop() → clearNowPlaying  │    (buffering/playing/error) │
    │ 5. resume()                  │ 10. onPlaybackFinished       │
    │ 6. handlePlaylistAdvance()   │     (local track ended,      │
    │ 7. updateTrackMetadata()     │      no next) → clear        │
    │    handleExtPlaylistAdvance()│                               │
    └──────────────────────────────┴──────────────────────────────┘
```

### Remote Command Flow Diagram

```
┌─────────────────────┐     ┌──────────────────────┐
│  Keyboard Media Key │     │  Bluetooth Headphone  │
│  Control Center UI  │     │  AirPlay Remote       │
└─────────┬───────────┘     └──────────┬───────────┘
          │                            │
          └──────────┬─────────────────┘
                     │
          ┌──────────▼──────────┐
          │ MPRemoteCommandCenter│
          │ (arbitrary thread)   │
          └──────────┬──────────┘
                     │
          Task { @MainActor }
                     │
          ┌──────────▼──────────┐
          │ PlaybackCoordinator  │
          │ play/pause/next/prev │
          │ seek (local only)    │
          └──────────┬──────────┘
                     │
          ┌──────────▼──────────┐
          │ AudioPlayer (local)  │
          │ StreamPlayer (radio) │
          └─────────────────────┘
```

### Phase 1 AirPlay Failure — Architecture Lesson

```
macOS Audio Routing Architecture:

┌──────────────────────────────────────────────────┐
│                   macOS System                    │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────┐          ┌─────────────────┐    │
│  │ AVAudioEngine│          │    AVPlayer      │    │
│  │ (Core Audio  │          │ (AVFoundation    │    │
│  │  HAL-bound)  │          │  per-instance)   │    │
│  └──────┬───────┘          └──────┬──────────┘    │
│         │                         │               │
│  System Default            Per-App AirPlay 2      │
│  Output Device             Route (isolated)       │
│         │                         │               │
│  ┌──────▼───────┐          ┌──────▼──────────┐    │
│  │ Speakers/USB/ │          │ AirPlay Target  │    │
│  │ HDMI/AirPlay  │          │ (this player    │    │
│  │ (ALL system   │          │  only)           │    │
│  │  audio)       │          │                  │    │
│  └───────────────┘          └─────────────────┘    │
│                                                    │
│  AVRoutePickerView ──────► AVPlayer ONLY           │
│  (cannot redirect AVAudioEngine)                   │
└──────────────────────────────────────────────────┘

MacAmp uses AVAudioEngine (left path) for EQ + visualizer.
Per-app AirPlay (right path) requires AVPlayer or
AVSampleBufferAudioRenderer — a complete architecture rewrite.
```

---

## Files Modified

| File | Changes | Lines |
|---|---|---|
| `PlaybackCoordinator.swift` | `import MediaPlayer`, `updateNowPlayingInfo()`, `clearNowPlayingInfo()`, `setupRemoteCommands()`, 6 callback wirings | ~100 new lines |
| `StreamPlayer.swift` | `onMetadataChanged` callback, `onStreamStateChanged` callback, fired from 4 locations | ~10 new lines |
| `AudioPlayer.swift` | `onPlaybackFinished` callback, fired from `onPlaybackEnded` when `.none` | ~5 new lines |
| `MainWindowFullLayer.swift` | Time display hit area fix (Phase 0) | ~5 changed lines |
| `MainWindowShadeLayer.swift` | Time display hit area fix (Phase 0) | ~5 changed lines |

---

## Skills File Updates Needed

### BUILDING_RETRO_MACOS_APPS_SKILL.md

**Lesson #31** already added (AirPlay failure). Additional content needed:

- **Now Playing pattern:** How to integrate MPNowPlayingInfoCenter + MPRemoteCommandCenter with a bridge-layer coordinator pattern. Explicit `playbackState` required on macOS. All handlers need `Task { @MainActor }`. No periodic timer — Apple auto-extrapolates elapsed time.
- **Callback lifecycle pattern:** Complete callback chain from mechanism (AudioPlayer/StreamPlayer) through bridge (PlaybackCoordinator) for Now Playing updates. Shows how to cover ALL state transitions including edge cases (stream reconnect, terminal error, local playback finished with no next track).
- **SwiftUI modifier ordering bug:** `.contentShape()` and `.onTapGesture` must come BEFORE `.offset()` / `.at()`, with explicit `.frame()` for hit area sizing.

---

## Command Enablement Flow (Oracle-Driven)

```
updateNowPlayingInfo()                clearNowPlayingInfo()
┌─────────────────────────┐          ┌───────────────────────┐
│ seek: localTrack only   │          │ seek: DISABLED        │
│ next: currentTrack !=   │          │ next: DISABLED        │
│       nil + playlist >0 │          │ prev: DISABLED        │
│ prev: same              │          │ playbackState: stopped│
└─────────────────────────┘          │ nowPlayingInfo: nil   │
                                     └───────────────────────┘
Called from:                         Called from:
- play/pause/resume/advance          - stop()
- metadata/state changes             - onPlaybackFinished
                                       (also clears source state)
```

---

## Lessons Learned (This Task)

1. **AI review misses framework-level incompatibilities** — Oracle gave 8/10 feasibility for AVRoutePickerView + AVAudioEngine. Only hands-on testing revealed the fundamental incompatibility.
2. **Now Playing lifecycle requires exhaustive coverage** — Oracle caught 5+ gaps across 5 review rounds (6→7→6→7→9/10). Every state transition path must call `updateNowPlayingInfo()`, including error/reconnect/auto-advance/playback-finished.
3. **macOS requires explicit `playbackState`** — unlike iOS, Control Center won't infer state from `nowPlayingInfo` alone.
4. **SwiftUI `.offset()` doesn't move hit areas** — `.contentShape()` and gesture modifiers applied after `.offset()` create hit areas at the original (0,0) position, not the visual position. Need explicit `.frame()` before `.contentShape()`.
5. **Stream callbacks need to fire AFTER state mutations** — `onStreamStateChanged` must fire after `error`/`isReconnecting` are set, not from the pipeline callback that fires before terminal handling.
6. **Remote command enablement must be context-aware** — next/previous should check `currentTrack != nil` (playlist position context), not just `playlistCount > 0`. A loaded playlist doesn't imply the current source is from that playlist.
7. **clearNowPlayingInfo must disable ALL context-dependent commands** — seek, next, and previous must all be disabled on stop/playback-finished. Stale enabled commands allow unintended track jumps.
8. **Playback-finished must clear coordinator source state** — without clearing `currentSource`/`currentTrack`/`currentTitle`, late async metadata callbacks can repopulate stale Now Playing info after playback has ended.
9. **stopAllBackends() is too aggressive for .playLocally handoffs** — when AudioPlayer already started a track before returning `.playLocally`, calling `stopAllBackends()` kills it. Only tear down the stream side for this case.
