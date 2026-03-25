# Plan: AudioPlayer Seek Extraction

> **Description:** Implementation plan for extracting the seek state machine from AudioPlayer.swift (734 lines).
> **Updated:** 2026-03-25 (line numbers refreshed post-Phase 2.5 cleanup)

---

## Objective

Extract the seek state machine (~117 lines of methods + 3 properties) from `AudioPlayer.swift` into a `SeekController`, reducing AudioPlayer from 734 to ~554 lines (below both 600-line swiftlint thresholds) and removing the last 2 inline suppressions.

## Key Design Decision

The Oracle (Phase 4, 2026-03-22) recommended deferring this extraction because the seek state machine is tightly coupled. This task implements the atomic-unit extraction the Oracle said was the safe path: moving **all** seek guards + shouldIgnoreCompletion + seek methods + onPlaybackEnded **together**.

## Extraction Plan

### Step 1: Expand seek characterization tests

Before moving code, ensure comprehensive test coverage:
- Seek during playback → position updates + resumes
- Seek while paused → position updates + stays paused
- Seek at end-of-track → completion handling
- Rapid seeks → only last seek takes effect (seekID invalidation)
- Seek during stream (no-op) → guard behavior

### Step 2: Create `SeekController.swift` (Moderate-High, ~186 lines)

New `@MainActor` class in `Audio/`.

**Properties (move from AudioPlayer):**
- `currentSeekID: UUID`
- `seekGuardActive: Bool`
- `isHandlingCompletion: Bool`

**Methods (move from AudioPlayer):**
- `shouldIgnoreCompletion(from:)` — guard logic
- `seekToPercent(_:resume:)` — video delegation + audio seek
- `seek(to:resume:)` — core audio seek implementation
- `onPlaybackEnded(fromSeekID:)` — completion handler

**Oracle finding addressed — onPlaybackEnded scope clarification:**

`onPlaybackEnded` does MORE than just seek guard filtering. It also:
1. Sets `isHandlingCompletion = true` (seek state — moves)
2. Calls `transition(to: .stopped(.completed))` (playback state — via callback)
3. Calls `engine.invalidateProgressTimer()` (engine — via engine reference)
4. Updates `playbackProgress` and `currentTime` (playback state — via callback)
5. Calls `nextTrack()` → `PlaylistAdvanceAction` (playlist — via callback)
6. Handles advance result: fires `onPlaylistAdvanceRequest` or `onPlaybackFinished` (callbacks)
7. Calls `engine.removeVisualizerTapIfNeeded()` (engine — via engine reference)
8. Sets `seekGuardActive = false` (seek state — moves)
9. Sets `isHandlingCompletion = false` after delay (seek state — moves)

Items 1, 8, 9 are seek state — move with SeekController.
Items 2, 3, 4, 5, 6, 7 are NOT seek state — handled via callbacks back to AudioPlayer.

**Expanded callback contract:**

```swift
@MainActor
final class SeekController {
    // Dependencies (set at init)
    var engine: AudioEngineController!
    weak var videoPlaybackController: VideoPlaybackController?

    // Callbacks to AudioPlayer (set at init)
    var onTransition: ((PlaybackState) -> Void)?
    var onProgressUpdate: ((Double, TimeInterval) -> Void)?  // (progress, time)
    var onRequestNextTrack: (() -> PlaylistAdvanceAction)?
    var onPlaylistAdvanceRequest: ((Track) -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onRemoveVisualizerTap: (() -> Void)?

    // Public API for AudioPlayer to manage seek guards
    func invalidateSeekID() -> UUID
    func activateSeekGuard()   // sets true + auto-clear after delay
    func clearSeekGuard()      // sets false immediately
}
```

### Step 3: Update AudioPlayer call sites

| AudioPlayer method | Current code | After extraction |
|---|---|---|
| `playTrack` | `currentSeekID = UUID(); seekGuardActive = true` | `seekController.activateSeekGuard(); let id = seekController.invalidateSeekID()` |
| `loadAudioFile` | `currentSeekID = UUID()` | `let id = seekController.invalidateSeekID()` |
| `play()` | `seekGuardActive = false` | `seekController.clearSeekGuard()` |
| `pause()` | `seekGuardActive = false` | `seekController.clearSeekGuard()` |
| `stop()` | `currentSeekID = UUID(); seekGuardActive = false` | `let id = seekController.invalidateSeekID(); seekController.clearSeekGuard()` |

### Step 4: Wire callbacks in AudioPlayer.init

```swift
seekController.onTransition = { [weak self] state in self?.transition(to: state) }
seekController.onProgressUpdate = { [weak self] progress, time in
    self?.playbackProgress = progress
    self?.currentTime = time
}
seekController.onRequestNextTrack = { [weak self] in self?.nextTrack() ?? .none }
seekController.onPlaylistAdvanceRequest = { [weak self] track in self?.onPlaylistAdvanceRequest?(track) }
seekController.onPlaybackFinished = { [weak self] in self?.onPlaybackFinished?() }
seekController.onRemoveVisualizerTap = { [weak self] in self?.engine.removeVisualizerTapIfNeeded() }
```

### Step 5: Remove swiftlint suppressions

After extraction, AudioPlayer should be ~554 lines (734 - ~180):
- Remove `// swiftlint:disable file_length` (line 1)
- Remove `// swiftlint:disable:this type_body_length` (line 9)

## New Files Created

| File | Lines | Source |
|------|-------|--------|
| `Audio/SeekController.swift` | ~170 | Seek state machine atomic extraction (117 lines methods + boilerplate/callbacks) |

**Total new files: 1**
**Residual AudioPlayer.swift: ~554 lines**

## Constraints

- **Atomic extraction only** — all three guards + shouldIgnoreCompletion + seek + seekToPercent + onPlaybackEnded move together
- Preserve seek guard timing (50ms, 100ms, 200ms delays) exactly as-is
- Preserve Now Playing remote command seek via PlaybackCoordinator facade
- SeekController does NOT know about playlists — uses callbacks for all playlist/state operations
- Decompose in place within `Audio/` — no moves to `Audio/Playback/` (post-S3)
- Do not change seek behavior — pure structural refactor
- Expand tests BEFORE extraction, not after

## Verification

- Seek during playback: slider drag updates position, resumes correctly
- Seek while paused: position updates, stays paused
- Seek to end: triggers completion → next track
- Rapid seeks: no stale completions, no phantom playback stops
- Stream playback: seek disabled (no regression)
- Remote command seek (Now Playing): still works via PlaybackCoordinator
- Video seek: still delegates to VideoPlaybackController
- `xcodegen generate` + XcodeBuildMCP build + test pass
- Thread Sanitizer clean
- swiftlint passes without suppressions
