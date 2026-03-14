# Research: Audio Pipeline Regression Diagnosis

Date: 2026-03-14

## Scope
Analyzed:
- MacAmpApp/Audio/AudioPlayer.swift
- MacAmpApp/Audio/StreamPlayer.swift
- MacAmpApp/Audio/PlaybackCoordinator.swift
- MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift
- MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift
- MacAmpApp/Audio/Streaming/AudioFileStreamParser.swift
- MacAmpApp/Audio/Streaming/ICYFramer.swift
- MacAmpApp/Audio/LockFreeRingBuffer.swift
- MacAmpApp/Views/VisualizerView.swift

Also inspected call sites that route local-file playback:
- MacAmpApp/AppCommands.swift
- MacAmpApp/Views/PlaylistWindowActions.swift

## Local Playback Flow (Expected)
1. PlaybackCoordinator.play(track: local) should call:
   - audioPlayer.deactivateStreamBridge()
   - streamPlayer.stop()
   - audioPlayer.playTrack(track)
2. AudioPlayer.playTrack(track) should call:
   - loadAudioFile(url)
   - rewireForCurrentFile()
   - scheduleFrom(time: 0)
   - play() -> startEngineIfNeeded() + playerNode.play()

## Key Observations

### 1) Bypass paths exist that play local audio directly without coordinator routing
- AppCommands open panel adds local files via `audioPlayer.addTrack(url:)` directly.
- PlaylistWindowActions also adds tracks directly via `audioPlayer.addTrack(url:)`.

Why this matters after bridge integration:
- Stream bridge rewires graph away from `playerNode`.
- Direct local playback through `AudioPlayer` does not explicitly tear down active stream bridge first.
- If bridge is active, local playback can be scheduled on `playerNode` while graph is still source-node-driven.

### 2) `onStreamTerminated` is only fired on `.idle` / `.error` transitions
- No evidence it fires during app init by default.
- It is triggered by explicit `streamPlayer.stop()` because pipeline sets `.idle`.

### 3) `isEngineRendering` is pure computed state
- Used by visualizer/data snapshot paths only.
- No mutating side effects found.

### 4) Volume/balance propagation to `streamSourceNode` is side-effect free for local path
- didSet writes pan/volume to `playerNode` + optional source node.
- No graph mutation or engine lifecycle mutation here.

## Streaming Throughput / Sputter Observations

### 1) Decode path is single serial queue and allocation-heavy
Decode queue performs:
- ICY framing
- AudioFileStream parse
- Converter enqueue/decode
- Ring write

AudioConverterDecoder has expensive per-decode operations:
- `packetQueue.removeFirst()` on Array (O(n) shift)
- allocate/copy/free input buffers and packet description buffers per decode call

This can reduce headroom and increase underrun risk.

### 2) No underrun recovery state machine after startup
- `prebufferThreshold` gates only initial `onFormatReady`.
- After playback starts, underruns are zero-filled in render block, but pipeline does not re-enter buffering state to refill.

### 3) Potential clock-domain mismatch risk (inference)
In `activateStreamBridge`:
- source format uses detected stream sample rate
- connection graph format uses output node sample rate

If render demand effectively tracks output sample-rate while producer writes at stream sample-rate, continuous drain mismatch can cause chronic underruns/choppiness.

## Concurrency / Sendable Findings
- Project is Swift 6.2 with strict concurrency = complete.
- Build succeeds via XcodeBuildMCP.
- `DecodeContext` and `SessionDelegateProxy` are `@unchecked Sendable` with queue-confinement strategy.
- No immediate strict-concurrency violation in these files that would explain silent audio failure.

## Commit / Diff Context
- Unified bridge added in commit 1896c6a (AudioPlayer + PlaybackCoordinator).
- Current working changes increase ring buffer to 16384 and prebuffer threshold to 8192; add playlist URL resolution in StreamDecodePipeline.start.
