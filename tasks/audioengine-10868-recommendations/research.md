# Research: AVAudioEngine -10868 Diagnosis

Date: 2026-03-14

## Scope
- Runtime symptom provided by user:
  - `AVAudioEngine` initialize failure with `Code=-10868`
  - repeated `Engine could not initialize`
  - tap installs anyway
  - `AVAudioPlayerNode` later reports engine is not running
- Code reviewed:
  - `MacAmpApp/Audio/AudioPlayer.swift`
  - `MacAmpApp/Audio/PlaybackCoordinator.swift`
  - `MacAmpApp/Audio/StreamPlayer.swift`
  - `MacAmpApp/Audio/Streaming/StreamDecodePipeline.swift`
  - `MacAmpApp/Audio/Streaming/AudioConverterDecoder.swift`
  - `MacAmpApp/Audio/VisualizerPipeline.swift`
  - `tasks/unified-audio-pipeline/*`
  - `tasks/airplay-integration/research.md`

## Ground Truth
- `-10868` maps to `kAudioUnitErr_FormatNotSupported` in the macOS SDK header:
  - `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/AudioToolbox.framework/Versions/A/Headers/AUComponent.h`
- The failure is therefore a graph format/configuration issue, not primarily a player-node state issue.

## Current Graph Setup

### Local file path
- `AudioPlayer.rewireForCurrentFile()` now reconnects:
  - `playerNode -> eqNode -> mainMixerNode -> outputNode`
- It uses an explicit graph format:
  - Float32
  - sample rate from `outputNode.inputFormat(forBus: 0)`
  - `channels: 2`
  - `interleaved: false`

### Stream bridge path
- `AudioPlayer.activateStreamBridge()` reconnects:
  - `streamSourceNode -> eqNode -> mainMixerNode -> outputNode`
- It also uses an explicit non-interleaved Float32 graph format at the output-device sample rate.
- Source node itself is created with interleaved stereo Float32 at the stream sample rate.

## Key Observations

### 1) The local-file graph now inherits stream-oriented assumptions
- `rewireForCurrentFile()` hardcodes `channels: 2`.
- That is appropriate for the stream bridge, because the stream decoder always normalizes to stereo.
- It is not inherently safe for local files, whose `AVAudioFile.processingFormat` may be mono, stereo, or other layouts.
- This is the strongest candidate for the current `kAudioUnitErr_FormatNotSupported` failure.

### 2) The engine start failure is not treated as fatal
- `startEngineIfNeeded()` logs the error but returns no success/failure signal.
- `rewireForCurrentFile()` continues to install the visualizer tap after a failed start.
- `play()` continues to call `playerNode.play()` after a failed start.
- This exactly matches the log sequence the user pasted:
  - engine init fails
  - tap still installs
  - player node later complains that engine is not running

### 3) The graph is started in more than one place
- `rewireForCurrentFile()` starts the engine.
- `play()` starts the engine again.
- `PlaybackCoordinator.play(url:)` also has a local path that can stack on top of `AudioPlayer.addTrack(url:)` auto-play behavior.
- These duplicate starts do not cause `-10868`, but they amplify it and make logs noisier.

### 4) Unified-pipeline task is still missing the verification phase
- `tasks/unified-audio-pipeline/todo.md` still shows:
  - build/verify incomplete
  - stream/local switching verification incomplete
  - local playback regression verification incomplete
- This makes a partially integrated graph-management regression plausible.

### 5) No `AVAudioEngineConfigurationChange` handling was found
- `tasks/airplay-integration/research.md` already identified this as critical.
- No observer exists in current audio code.
- This is not the primary explanation for the pasted log by itself, but it is a real graph-lifecycle gap and can re-trigger format failures after hardware/sample-rate changes.

## Most Likely Root Cause
- The local playback rewire path was changed to use a fixed stereo hardware-format graph to avoid post-bridge EQ format stickiness.
- That likely fixed one class of bridge-transition issue, but it introduced or exposed another:
  - local files no longer reconnect using their actual file/output negotiation
  - the EQ chain now receives a connection format that can be invalid for some local-file source formats
- Because the error is `kAudioUnitErr_FormatNotSupported`, this format mismatch is a better fit than tap timing or player-node scheduling.

## Secondary Risk Areas
- Duplicate engine-start attempts after failed initialization
- Tap installation after failed engine start
- Multiple playback entry points (`play(url:)`, `addTrack(url:)`, `playTrack(track:)`) increasing graph lifecycle complexity
- Missing engine configuration-change recovery
