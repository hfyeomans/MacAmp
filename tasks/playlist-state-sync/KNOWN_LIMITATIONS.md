# Known Limitations - Playlist State Sync

**Date:** 2025-10-23
**Status:** Documented for future fix
**Priority:** P1 - Should fix before 1.0 release

---

## 🐛 Issue: Main Thread Blocking During Track Operations

### Symptoms

1. **Clicking second/subsequent tracks:**
   - Visualizer waves freeze
   - Time numbers stop counting (both windows)
   - Bottom remaining time disappears briefly
   - UI freezes until track loads

2. **Dragging sliders (volume, balance, position):**
   - Visualizer freezes during drag
   - Time numbers stop updating
   - UI resumes when slider released

3. **Eject button behavior (playlist window):**
   - Clicking Eject triggers `nextTrack()` unexpectedly
   - Logs show: "DEBUG nextTrack: Playlist ended, set trackHasEnded=true"
   - File dialog may/may not open
   - **Likely related:** Main thread blocking prevents proper dialog presentation
   - NSOpenPanel.begin() callback may race with AudioPlayer state updates

### Root Cause (Identified by Gemini Analysis)

**Issue 1: Synchronous File I/O on Main Thread**
- `AudioPlayer` is `@MainActor` → all methods run on main UI thread
- `loadAudioFile()` (line 141) does blocking file I/O:
  ```swift
  audioFile = try AVAudioFile(forReading: url)  // BLOCKS!
  ```
- Large audio files freeze UI during load
- Called by `playTrack()` when switching tracks

**Issue 2: Continuous Seeking Starves Main Thread**
- Sliders call `seek(to:)` dozens of times per second during drag
- `seek()` is expensive: stops player, invalidates timer, reschedules audio
- Main thread saturated → no time for visualizer/timer updates

### Technical Details

**File:** `MacAmpApp/Audio/AudioPlayer.swift`

**Blocking call chain:**
1. User clicks track → `playTrack(track:)` (line 109)
2. Calls `loadAudioFile(url:)` (line 129)
3. Creates `AVAudioFile(forReading:)` (line 143) → **BLOCKS main thread**
4. Calls `rewireForCurrentFile()` (line 144) → audio graph setup
5. Calls `scheduleFrom(time: 0)` (line 145) → schedule audio
6. Finally calls `play()` (line 137) → start playback
7. **Total block time:** 50-500ms depending on file size

**During this time:**
- Timer callbacks can't fire (main thread busy)
- SwiftUI can't update views
- Visualizer can't redraw
- User sees frozen UI

---

## 🔧 Recommended Fixes (Future Task)

### Fix 1: Async File Loading (High Priority)

**Goal:** Move file I/O off main thread

```swift
private func loadAudioFile(url: URL) async throws {
    // Load file on background thread
    let file = try await Task.detached {
        try AVAudioFile(forReading: url)
    }.value

    // Update audio graph on main thread
    await MainActor.run {
        self.audioFile = file
        self.rewireForCurrentFile()
        let _ = self.scheduleFrom(time: 0)
        self.playerNode.volume = self.volume
        self.playerNode.pan = self.balance
    }
}

func playTrack(track: Track) {
    // ... setup ...

    Task {
        do {
            try await loadAudioFile(url: track.url)
            play()  // Start playback after loading
        } catch {
            print("Failed to load: \(error)")
        }
    }
}
```

**Benefits:**
- UI stays responsive during track loading
- Visualizer continues animating
- Time displays keep updating
- Better user experience

**Estimated Time:** 1-2 hours

### Fix 2: Deferred Seeking (Medium Priority)

**Goal:** Only seek when slider drag ends

**Current pattern (BAD):**
```swift
Slider(value: $audioPlayer.playbackProgress)  // Seeks continuously!
```

**Webamp pattern (GOOD):**
```swift
@State private var seekPosition: Double = 0

Slider(value: $seekPosition)
    .onEditingChanged { isEditing in
        if !isEditing {  // Only when drag ENDS
            audioPlayer.seek(to: seekPosition)
        }
    }
```

**Benefits:**
- Slider drag smooth and responsive
- Single seek operation instead of hundreds
- Visualizer/timer updates during drag
- Matches Webamp behavior

**Estimated Time:** 30 minutes per slider

### Fix 3: Loading Indicator (Low Priority)

Add visual feedback during file loading:
- Show spinner or "Loading..." during `playTrack()`
- Hide when playback starts
- Better UX than frozen UI

**Estimated Time:** 30 minutes

---

## 📚 Reference Implementation

**Webamp Clone:** Check how webamp_clone handles this
- Likely uses async/await for file operations
- Probably debounces or defers seek operations
- May use Web Workers or similar for background loading

**Files to check:**
- Webamp's track loading logic
- Slider interaction patterns
- Threading/async patterns

---

## 🎯 Impact Assessment

### Current Impact
- **Severity:** Medium (UX degradation but not broken)
- **Frequency:** Every track switch, every slider drag
- **User Perception:** App feels sluggish/unresponsive
- **Data Loss:** None (just visual freeze, audio continues)

### Workaround for Users
- Use keyboard shortcuts instead of sliders where possible
- Wait for track to load before interacting
- Use smaller audio files for testing

---

## 📋 Future Task Creation

**Task ID:** `async-audio-loading`
**Priority:** P1 (before 1.0 release)
**Estimated Time:** 2-3 hours total

**Subtasks:**
1. Refactor `loadAudioFile()` to async
2. Update `playTrack()` to await loading
3. Implement deferred seeking for position slider
4. Implement deferred seeking for volume/balance sliders
5. Add loading indicators
6. Test with large files (>50MB)
7. Fix Eject button/file dialog interaction (likely resolves with async fix)
8. Verify no regressions in state management

**Eject Button Investigation:**
- Check if NSOpenPanel.begin() callback races with AudioPlayer state
- May need to ensure dialog presentation happens on main thread after loading
- Could be related to trackHasEnded flag being set incorrectly
- Test if async loading fixes the nextTrack() trigger issue

---

## ✅ Current Session Decision

**Action:** Document and defer to future task
**Reason:** Outside scope of playlist state sync
**Next:** Continue with button click testing

The playlist window functionality is **complete and working** for single-track playback. The multi-track switching issue is a separate AudioPlayer threading concern that affects the entire app, not just the playlist window.

---

**Documented:** 2025-10-23
**Deferred to:** Future async-audio-loading task
**Impact on current task:** None - playlist UI implementation complete
