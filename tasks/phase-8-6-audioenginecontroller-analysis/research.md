# Phase 8.6 AudioEngineController Analysis - Research

## Sources reviewed
- MacAmpApp/Audio/AudioPlayer.swift
- docs/MACAMP_ARCHITECTURE_GUIDE.md
- tasks/code-optimization/research.md
- tasks/code-optimization/plan.md

## AudioPlayer engine-related inventory (current)

### Engine-owned properties
- AVAudioEngine + nodes + file/timer state: `audioEngine`, `playerNode`, `eqNode`, `audioFile`, `progressTimer`, `playheadOffset` (AudioPlayer.swift:61-67)
- Playback guard state: `currentSeekID`, `isHandlingCompletion`, `seekGuardActive` (AudioPlayer.swift:95-97)
- Volume/balance directly touch `playerNode` (AudioPlayer.swift:105-113)

### Engine lifecycle / wiring
- `setupEngine()` attaches nodes (AudioPlayer.swift:624-630)
- `configureEQ()` wires EQ bands and applies current gains (AudioPlayer.swift:632-651)
- `rewireForCurrentFile()` handles stop/reset/reconnect/prepare/start + tap (AudioPlayer.swift:653-676)
- `startEngineIfNeeded()` (AudioPlayer.swift:744-748)

### Scheduling / playback progress
- `scheduleFrom(time:seekID:)` schedules AVAudioPlayerNode segment and installs completion handler (AudioPlayer.swift:678-742)
- `startProgressTimer()` keeps `currentTime`/`playbackProgress` in sync (AudioPlayer.swift:751-771)

### Seek guards + completion handling
- `shouldIgnoreCompletion(from:)` filters stale completions and seek-guarded transitions (AudioPlayer.swift:177-216)
- `seekToPercent(_:resume:)` and `seek(to:resume:)` manage seek guards, progress, and segment rescheduling (AudioPlayer.swift:786-889)
- `onPlaybackEnded(fromSeekID:)` handles completion, state transition, and next track action (AudioPlayer.swift:957-995)

### Playback entry points that touch the engine
- `playTrack(track:)` resets seek guards, stops player node, loads audio file, and starts playback (AudioPlayer.swift:302-371)
- `loadAudioFile(url:)` creates AVAudioFile, rewires engine, schedules segment, updates audio properties (AudioPlayer.swift:381-405)
- `play()` / `pause()` / `stop()` interact with engine + player node and timers (AudioPlayer.swift:407-498)

### Visualizer coupling
- Tap install/remove uses engine main mixer node (AudioPlayer.swift:775-782)
- Butterchurn snapshot only valid for local audio (AudioPlayer.swift:946-955)

### Cross-component coupling points
- Playlist state: `play()`, `playTrack()`, `onPlaybackEnded()` call `playlistController` and `nextTrack()` (AudioPlayer.swift:302-371, 407-435, 978-983)
- Video branching: `playTrack()`, `play()`, `pause()`, `seekToPercent()`, `seek()` check `currentMediaType` and delegate to `VideoPlaybackController` (AudioPlayer.swift:340-371, 414-455, 789-825)
- External callbacks: `onPlaybackEnded()` triggers `externalPlaybackHandler` (AudioPlayer.swift:978-982)
- Metadata: `loadAudioFile()` triggers `MetadataLoader.loadAudioProperties` (AudioPlayer.swift:395-400)

## Architecture guide pointers
- Audio Processing Pipeline and AVAudioEngine graph overview: docs/MACAMP_ARCHITECTURE_GUIDE.md ("Audio Processing Pipeline" section)
- Pitfall: AVAudioEngine state handling (docs/MACAMP_ARCHITECTURE_GUIDE.md "Pitfall 3: AVAudioEngine State")

## Prior plan notes (code-optimization task)
- AudioEngineController flagged as ★★★★★ highest risk due to core playback, seek guards, engine state
- Plan suggested stopping after 8.5 if AudioPlayer size is reasonable, otherwise consider extraction
- Alternative: extension-based refactor if extraction is too risky
