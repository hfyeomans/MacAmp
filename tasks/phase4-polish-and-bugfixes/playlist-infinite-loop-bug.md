# Critical Bug: Playlist Infinite Loop & Duplication

**Date:** 2025-10-13
**Severity:** 🔴 CRITICAL - App becomes unusable
**Status:** Under investigation

---

## 🐛 The Bugs

### Bug 1: Infinite Loop with Repeat Enabled

**Symptoms:**
- Enable repeat mode
- Track ends (or seek to end)
- App enters infinite loop loading same track over and over
- Console floods with logs exponentially
- App becomes unresponsive

**Log Evidence:**
```
DEBUG onPlaybackEnded: Track actually ended
AudioPlayer: Stop
AudioPlayer: Loaded track from 01 Zero_DB-05-04-SAT-2009.mp3
DEBUG onPlaybackEnded: Track actually ended
AudioPlayer: Stop
AudioPlayer: Loaded track from 01 Zero_DB-05-04-SAT-2009.mp3
(repeats exponentially faster...)
```

### Bug 2: Playlist Duplication on Click

**Symptoms:**
- Click track in playlist → Track duplicates
- Click again → More duplicates (exponential growth)
- Same track appears 2x, 4x, 8x, 16x times

**Log Evidence:**
```
AudioPlayer: Loaded track from 01 Zero_DB-05-04-SAT-2009.mp3
(Track gets added to playlist again)
```

### Bug 3: Add Track Duplicates

**Symptoms:**
- Add first track → Works OK
- Add second track → Both tracks duplicate
- Clicking tracks causes more duplication

---

## 🔍 Root Cause Analysis

### Issue 1: loadTrack() Always Appends

**File:** `MacAmpApp/Audio/AudioPlayer.swift` lines 78-151

**Current Code:**
```swift
func loadTrack(url: URL) {
    stop()
    currentTrackURL = url
    // ...

    Task { @MainActor in
        do {
            // ... load metadata ...
            let newTrack = Track(url: url, title: title, artist: artist, duration: duration)
            self.playlist.append(newTrack)  // ❌ ALWAYS appends!
            if self.currentTrack == nil { self.currentTrack = newTrack }
        }
    }

    // ... schedule audio ...
}
```

**Problem:**
- `loadTrack()` ALWAYS appends to playlist
- Doesn't check if track already exists
- Called by both "add to playlist" AND "play existing track"

### Issue 2: playTrack() Re-loads Track

**File:** `MacAmpApp/Audio/AudioPlayer.swift` lines 154-158

**Current Code:**
```swift
func playTrack(track: Track) {
    loadTrack(url: track.url)  // ❌ Re-loads track that's already in playlist!
    currentTrack = track
    play()
}
```

**Problem:**
- `playTrack()` is meant to play a track from the playlist
- But it calls `loadTrack()` which adds the track AGAIN
- Should just switch `currentTrack` and schedule audio

### Issue 3: Infinite Loop Chain

**The Cycle:**
```
onPlaybackEnded()
  → nextTrack()
    → playTrack(playlist[0])  (with repeat)
      → loadTrack(track.url)
        → playlist.append(track)  ❌ Duplicate!
        → play()
          → Eventually ends
            → onPlaybackEnded()  ← LOOP!
```

---

## 🎯 Required Fixes

### Fix 1: Separate Load vs Play

**Need TWO distinct operations:**

1. **loadTrack(url)** - Add new track to playlist
   - Check if already exists
   - Add to playlist
   - Load audio file
   - Do NOT auto-play

2. **playTrack(track)** - Play existing playlist track
   - Set as currentTrack
   - Load audio file from track.url
   - Do NOT add to playlist
   - Start playback

### Fix 2: Deduplicate Playlist

```swift
func loadTrack(url: URL) {
    // Check if already in playlist
    if playlist.contains(where: { $0.url == url }) {
        #if DEBUG
        print("Track already in playlist, not adding duplicate")
        #endif
        return
    }

    // ... add to playlist ...
}
```

### Fix 3: Fix playTrack to Not Re-add

```swift
func playTrack(track: Track) {
    // DON'T call loadTrack!
    currentTrack = track
    currentTrackURL = track.url

    // Load the audio file (but don't add to playlist)
    do {
        audioFile = try AVAudioFile(forReading: track.url)
        rewireForCurrentFile()
        let _ = scheduleFrom(time: 0)
        playerNode.volume = volume
        playerNode.pan = balance
    } catch {
        print("Failed to load audio file: \(error)")
    }

    play()
}
```

---

## 📋 Gemini Prompt

Here's what to ask Gemini:

```
I have a critical bug in my Swift AudioPlayer class causing infinite loops and playlist duplication.

SYMPTOMS:
1. When repeat mode is enabled, onPlaybackEnded() enters infinite loop
2. Clicking tracks in playlist duplicates them exponentially
3. Adding tracks duplicates existing tracks

ROOT CAUSE:
- loadTrack(url) ALWAYS appends to playlist (line 127: playlist.append(newTrack))
- playTrack(track) calls loadTrack() which re-adds the track (line 155)
- This creates infinite loop: onPlaybackEnded → nextTrack → playTrack → loadTrack → append → eventually ends → onPlaybackEnded

CURRENT CODE:

func loadTrack(url: URL) {
    stop()
    Task { @MainActor in
        let newTrack = Track(...)
        self.playlist.append(newTrack)  // ALWAYS appends!
    }
    audioFile = try AVAudioFile(forReading: url)
    scheduleFrom(time: 0)
}

func playTrack(track: Track) {
    loadTrack(url: track.url)  // Re-loads existing track!
    currentTrack = track
    play()
}

func nextTrack() {
    if repeatEnabled {
        playTrack(track: playlist[0])  // Triggers loadTrack!
    }
}

QUESTION:
How should I restructure these methods to:
1. loadTrack() - Add NEW tracks to playlist (deduplicate)
2. playTrack() - Play EXISTING playlist tracks (don't re-add)
3. Avoid infinite loops in nextTrack()

Provide Swift code for macOS with proper async/await handling.
```

---

## 🔧 My Proposed Fix

**Restructure the methods:**

```swift
// Add track to playlist (from file picker, drag-drop)
func addTrack(url: URL) {
    // Check for duplicates
    if playlist.contains(where: { $0.url == url }) {
        return
    }

    // Load metadata async
    Task { @MainActor in
        let track = await loadTrackMetadata(url: url)
        self.playlist.append(track)

        // Auto-play first track
        if self.currentTrack == nil {
            self.playTrack(track: track)
        }
    }
}

// Play existing track from playlist
func playTrack(track: Track) {
    stop()
    currentTrack = track
    currentTrackURL = track.url

    // Load audio file (don't modify playlist!)
    do {
        audioFile = try AVAudioFile(forReading: track.url)
        rewireForCurrentFile()
        let _ = scheduleFrom(time: 0)
        playerNode.volume = volume
        playerNode.pan = balance
    } catch {
        print("Failed to load: \(error)")
        return
    }

    play()
}

// Helper to load metadata
private func loadTrackMetadata(url: URL) async -> Track {
    let asset = AVURLAsset(url: url)
    // ... async loading ...
    return Track(url: url, title: title, artist: artist, duration: duration)
}
```

---

**Priority:** 🔴 CRITICAL - Must fix before committing more changes
**Impact:** App unusable with repeat mode or multiple tracks
**Next Step:** Get Gemini's input and implement fix
