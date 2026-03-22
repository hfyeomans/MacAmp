# Task State: AudioPlayer.swift Decomposition

> **Description:** Tracks the current state of the AudioPlayer decomposition task including progress, blockers, and decisions.
> **Purpose:** Single source of truth for task status, updated as implementation progresses.

---

## Current Phase: Phase 4 COMPLETE — PR #60 merged (2026-03-22)

## Status: Phases 1-4 complete. Seek extraction (Phase 5) deferred.

## Branch: `refactor/audioplayer-phase4-transport` (merged)

## Final Results

| Metric | Before (original) | After Ph1-3 (PR #52) | After T7/T8 | After Ph4 (PR #60) |
|--------|-------------------|---------------------|-------------|---------------------|
| AudioPlayer.swift | 1,095 lines | 945 lines | 1,143 lines | **705 lines** |
| EqualizerController.swift | — | 195 lines | 195 lines | 195 lines |
| AudioEngineController.swift | — | — | — | **413 lines** |
| swiftlint suppressions | 2 | 2 | 2 | 2 (still needed at 705/~690) |
| Tests | 40 | 40 | 40 | **53** (+13 characterization) |

---

## Architecture After Phase 4

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     AudioPlayer (705 lines)                      │
│                     Facade + State Machine                       │
│                                                                  │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐  │
│  │   Seek State Machine │  │   Track Management               │  │
│  │   • currentSeekID    │  │   • addTrack, playTrack          │  │
│  │   • seekGuardActive  │  │   • loadAudioFile → engine       │  │
│  │   • isHandlingCompl. │  │   • detectMediaType              │  │
│  │   • shouldIgnoreComp │  │                                  │  │
│  └─────────────────────┘  └──────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐  │
│  │   Transport (orch.)  │  │   Playlist Navigation            │  │
│  │   • play/pause/stop  │  │   • next/previous/handleAction   │  │
│  │   • eject            │  │   • PlaylistAdvanceAction enum   │  │
│  │   (video + audio)    │  │                                  │  │
│  └─────────────────────┘  └──────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │   Forwarding (facade) → EQ, Visualizer, Stream Bridge       ││
│  └─────────────────────────────────────────────────────────────┘│
│                          │                                       │
│            ┌─────────────┼─────────────────┐                    │
│            ▼             ▼                  ▼                    │
│  ┌──────────────┐ ┌───────────────┐ ┌──────────────────┐       │
│  │ Equalizer    │ │ AudioEngine   │ │ VideoPlayback    │       │
│  │ Controller   │ │ Controller    │ │ Controller       │       │
│  │ (195 lines)  │ │ (413 lines)   │ │ (297 lines)      │       │
│  └──────────────┘ └───────────────┘ └──────────────────┘       │
│                                                                  │
│  ┌──────────────┐ ┌───────────────┐ ┌──────────────────┐       │
│  │ Playlist     │ │ Visualizer    │ │ EQPresetStore    │       │
│  │ Controller   │ │ Pipeline      │ │ (187 lines)      │       │
│  │ (273 lines)  │ │ (677 lines)   │ │                  │       │
│  └──────────────┘ └───────────────┘ └──────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### AudioEngineController Responsibility Diagram

```
┌────────────────────────────────────────────────────┐
│           AudioEngineController (413 lines)         │
│           Owns: AVAudioEngine + all graph nodes      │
│                                                      │
│  ┌──────────────────────────────────────────┐       │
│  │  Engine Graph (Local File Path)           │       │
│  │                                           │       │
│  │  playerNode → eqNode → mixer → output     │       │
│  │                                           │       │
│  │  • setupEngine()                          │       │
│  │  • rewireForFile(_ file:)                 │       │
│  │  • scheduleFrom(time:seekID:) → Bool      │       │
│  │  • startEngineIfNeeded()                  │       │
│  └──────────────────────────────────────────┘       │
│                                                      │
│  ┌──────────────────────────────────────────┐       │
│  │  Stream Bridge (Internet Radio Path)      │       │
│  │                                           │       │
│  │  streamSourceNode → eqNode → mixer → out  │       │
│  │                                           │       │
│  │  • activateStreamBridge(ringBuffer:rate:)  │       │
│  │  • deactivateStreamBridge()               │       │
│  │  • makeStreamRenderBlock() [nonisolated]  │       │
│  └──────────────────────────────────────────┘       │
│                                                      │
│  ┌──────────────────────────────────────────┐       │
│  │  Node Transport + Progress                │       │
│  │                                           │       │
│  │  • playAudio() / pauseAudio() / stopAudio │       │
│  │  • startProgressTimer() → callback        │       │
│  │  • setVolume() / setBalance()             │       │
│  │  • installVisualizerTapIfNeeded()         │       │
│  │  • removeVisualizerTapIfNeeded()          │       │
│  └──────────────────────────────────────────┘       │
│                                                      │
│  Callbacks to AudioPlayer:                           │
│  • onProgressUpdate(currentTime, progress)           │
│  • onPlaybackEnded(fromSeekID)                       │
│  • onBridgeStateChanged(isActive)                    │
└────────────────────────────────────────────────────┘
```

### Data Flow: Local File Playback

```
User presses Play
    │
    ▼
PlaybackCoordinator.play(track:)
    │
    ▼
AudioPlayer.playTrack(track:)
    ├── seekGuardActive = true, currentSeekID = UUID()
    ├── engine.stopAudio()
    ├── engine.invalidateProgressTimer()
    ├── loadAudioFile(url:)
    │       ├── engine.loadFile(url:)  ← AVAudioFile + rewireForFile
    │       ├── engine.scheduleFrom(time: 0, seekID:)
    │       └── engine.setVolume() / setBalance()
    └── play()
            ├── engine.startEngineIfNeeded()
            ├── engine.installVisualizerTapIfNeeded()
            ├── engine.playAudio()  ← playerNode.play()
            └── engine.startProgressTimer()
                    │
                    ▼ (every 0.1s)
            engine.onProgressUpdate → AudioPlayer.currentTime/playbackProgress
```

### Data Flow: Internet Radio Streaming

```
User opens stream URL
    │
    ▼
PlaybackCoordinator.play(url:)  [remote URL detected]
    ├── audioPlayer.stop()
    ├── streamPlayer.play(url:)
    │       │
    │       ▼ (async: URLSession + AudioFileStream + AudioConverter)
    │   StreamDecodePipeline produces PCM → LockFreeRingBuffer
    │       │
    │       ▼ (onFormatReady callback)
    └── audioPlayer.activateStreamBridge(ringBuffer:, sampleRate:)
            │
            ▼
        AudioPlayer forwards → engine.activateStreamBridge(...)
            ├── Stop/reset engine
            ├── Detach playerNode path
            ├── Attach streamSourceNode → eqNode → mixer → output
            ├── engine.startEngineIfNeeded()
            ├── engine.installVisualizerTapIfNeeded()
            └── engine.setVolume() / setBalance()
                    │
                    ▼ (real-time audio thread)
            streamSourceNode reads from LockFreeRingBuffer
            → EQ → mixer → output (speakers)
```

### Data Flow: Seek Operation

```
User drags position slider
    │
    ▼
WinampMainWindowInteractionState.handlePositionDrag()
    ├── audioPlayer.pause()  [if was playing]
    │       └── engine.pauseAudio()
    │
    ▼ (on release)
handlePositionDragEnd()
    ├── audioPlayer.seekToPercent(progress, resume: wasPlaying)
    │       │
    │       ▼
    │   AudioPlayer.seek(to: time, resume:)
    │       ├── seekGuardActive = true
    │       ├── currentSeekID = UUID()  [invalidate old completions]
    │       ├── engine.invalidateProgressTimer()
    │       ├── engine.scheduleFrom(time:, seekID:)  ← playerNode.stop + scheduleSegment
    │       ├── currentTime = time, playbackProgress = progress
    │       ├── if audioScheduled && shouldPlay:
    │       │       ├── engine.startEngineIfNeeded()
    │       │       ├── engine.playAudio()
    │       │       └── engine.startProgressTimer()
    │       └── Task { seekGuardActive = false }  [100ms delay]
    │
    ▼ (when segment completes)
engine.onPlaybackEnded(seekID) → AudioPlayer.onPlaybackEnded(fromSeekID:)
    ├── shouldIgnoreCompletion(from: seekID)?
    │       ├── seekID != currentSeekID → IGNORE (stale)
    │       ├── seekGuardActive && seekID == nil → IGNORE
    │       └── stopped(.manual/.ejected) → IGNORE
    ├── transition(.stopped(.completed))
    └── nextTrack() → playlist advance
```

---

## Docs That Need Updating

The following `docs/` files reference AudioPlayer architecture and should be updated to reflect the new AudioEngineController extraction:

| Doc File | Section | What to Update |
|----------|---------|----------------|
| `docs/MACAMP_ARCHITECTURE_GUIDE.md` | §3 Audio subsystem, §4 Unified pipeline | Add AudioEngineController to component list, update ownership diagram |
| `docs/IMPLEMENTATION_PATTERNS.md` | Audio patterns section | Add AudioEngineController facade pattern, callback wiring pattern |
| `docs/MILKDROP_WINDOW.md` | Audio data flow | Update visualizer tap path (now via engine controller) |

---

## Phase 4 Oracle Review (2026-03-22)

Oracle (gpt-5.3-codex, xhigh reasoning) reviewed extraction strategy + post-extraction code. Key decisions:

1. **One AudioEngineController** for engine wiring + stream bridge (shared format invariants)
2. **Keep seek state machine in AudioPlayer** — partial move splits one state machine across two owners
3. **Transport must follow nodes** — play/pause/stop touch playerNode directly
4. **Facade preserved** — all AudioPlayer public API signatures unchanged
5. **Tests BEFORE extraction** — 13 characterization tests added first

Post-extraction findings (all addressed):
- [MEDIUM] currentDuration regression — fixed with engine.currentFileDuration sync
- [LOW] No-op task in scheduleFrom — removed
- [LOW] Completion-ID defensiveness — acceptable (all callers pass non-nil)

## Architecture Alignment

Phase 4 does **not** conflict with `swift-project-structure-research`:
- New files in `MacAmpApp/Audio/` (current location)
- Folder moves to `Audio/Playback/` deferred to post-S3 Structure Sprint

## Blockers

None.

## Open Questions

None remaining.
