# Research: Stream Track Counter

> **Purpose:** Research Winamp track counter display behavior and stream elapsed time implementation.

**Status:** Complete (2026-03-23)

---

## Problem Statement

When playing internet radio, MacAmp's time display shows `00:00` forever. `audioPlayer.currentTime` is only updated by the local-file engine progress timer. During stream playback, no timer runs — the time digits are dead. Winamp classic shows an upward-counting elapsed timer for streams.

Additionally, Winamp shows a track position counter ("3/15") in the main window. MacAmp's `PlaylistController.currentIndex` is private and not exposed to views.

## Current Architecture

### Time Display Chain (Local Files — Working)

```
AudioEngineController.startProgressTimer()
    → onProgressUpdate callback
        → AudioPlayer.currentTime / playbackProgress
            → MainWindowFullLayer.buildTimeDigits()
            → MainWindowShadeLayer.buildShadeTimeDisplay()
```

### Time Display Chain (Streams — Broken)

```
StreamPlayer.isPlaying = true
    → NO timer, NO elapsed tracking
        → audioPlayer.currentTime stays at 0.0
            → Time display shows 00:00 forever
```

### Key Files and Lines

| File | Relevant Lines | Current Behavior |
|------|---------------|-----------------|
| `MainWindowFullLayer.swift:122-138` | `buildTimeDigits()` | Reads `audioPlayer.currentTime/currentDuration` — no stream branching |
| `MainWindowShadeLayer.swift:65-107` | `buildShadeTimeDisplay()` | Identical logic to full layer |
| `AppSettings.swift:235-251` | `TimeDisplayMode` enum | `.elapsed` / `.remaining` — remaining meaningless for streams |
| `PlaybackCoordinator.swift:63` | `currentSource` | `.localTrack` or `.radioStation` — determines stream vs local |
| `PlaybackCoordinator.swift:357-393` | `displayTitle` | Already has stream-specific branching — no time equivalent |
| `StreamPlayer.swift:37-43` | Observable state | `isPlaying`, `isBuffering`, etc. — NO time tracking |
| `PlaylistController.swift:37` | `currentIndex` | Private — not exposed to views |
| `PlaylistController.swift:77` | `count` | Public |

## Design Decisions

### Stream Elapsed Time

**Where to track:** `StreamPlayer` — it owns the stream lifecycle (play/pause/resume/stop/reconnect) and knows the exact state transitions.

**Timer approach:** Same `Timer.scheduledTimer` pattern as `AudioEngineController.startProgressTimer()` — 0.1s interval, fires on main actor.

**Reset behavior:**
- Reset to 0 on `play(station:)` (new stream)
- Reset to 0 on ICY metadata title change (new track on same station) — Winamp behavior
- Preserve during reconnect (Winamp continues counting during brief reconnects)
- Pause during buffering/reconnect (don't count time when no audio is playing)

### Remaining Mode for Streams

Streams have no duration — "remaining" mode is meaningless. **Option chosen:** Keep `TimeDisplayMode` enum as-is, have the view clamp to elapsed when duration is 0/unknown. Simplest approach, keeps the model clean.

### Unified Time Source

Views currently read directly from `audioPlayer`. For streams, they need a different source. **Option chosen:** Add `displayTime`/`displayDuration` to `PlaybackCoordinator` (bridge layer) that delegates to the right backend. Views switch to reading from coordinator instead of audioPlayer directly.

### Playlist Position

Expose `currentPosition` (1-based) on `PlaylistController`, forward through `AudioPlayer` or `PlaybackCoordinator`. Display as "3/15" format. Hide when no track is active or when playing a direct stream URL not in the playlist.

## Three-Layer Alignment

```
Mechanism Layer:
├─ StreamPlayer.elapsedTime (new Timer-based property)
├─ PlaylistController.currentPosition (expose 1-based index)

Bridge Layer:
├─ PlaybackCoordinator.displayTime (local → audioPlayer, stream → streamPlayer)
├─ PlaybackCoordinator.displayDuration (local → audioPlayer, stream → 0)
├─ PlaybackCoordinator.trackPositionString (from playlist controller)

Presentation Layer:
├─ MainWindowFullLayer.buildTimeDigits() → read from coordinator
├─ MainWindowShadeLayer → same
├─ Suppress remaining mode when displayDuration == 0
```
