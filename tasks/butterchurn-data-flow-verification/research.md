# Butterchurn Data Flow Research

## Data flow (tap -> Butterchurn)
- AVAudioEngine tap is installed on `audioEngine.mainMixerNode` in `AudioPlayer.installVisualizerTapIfNeeded()` (called in `play()` and `rewireForCurrentFile()`).
- Tap handler in `VisualizerPipeline.makeTapHandler(...)`:
  - Mixes channels to mono.
  - Computes RMS, spectrum (Goertzel) and waveform.
  - Runs `processButterchurnFFT(samples:)` on mono data to populate `butterchurnSpectrum` and `butterchurnWaveform` in scratch buffers.
  - Creates `VisualizerData` with Butterchurn arrays and dispatches to MainActor via `Task`.
- `VisualizerPipeline.updateLevels(with:useSpectrum:)` stores `butterchurnSpectrum`, `butterchurnWaveform`, and updates `lastButterchurnUpdate`.
- `AudioPlayer.snapshotButterchurnFrame()` returns `visualizerPipeline.snapshotButterchurnFrame()` only if `currentMediaType == .audio` and `isPlaying`.
- `ButterchurnBridge.sendAudioFrame()` (30 FPS task started on `ready` message) calls `audioPlayer.snapshotButterchurnFrame()` and sends arrays into JS via `window.macampButterchurn?.setAudioData(spectrum, waveform)`.

## Verification points
- Tap installation: `AudioPlayer.installVisualizerTapIfNeeded()` and `VisualizerPipeline.installTap(on:)` logs `AppLog.debug(.audio, "VisualizerPipeline: Tap installed")`.
- Butterchurn updates: `ButterchurnBridge` logs `Started 30 FPS audio updates` on `ready`.
- `AudioPlayer.snapshotButterchurnFrame()` is the gate: returns nil for video/stream or when not playing.
- Observable fields in `VisualizerPipeline` (Butterchurn arrays) can be inspected in debugger to confirm non-zero data.

## Potential breaks after extraction
- `ButterchurnBridge` must be configured with `AudioPlayer` (`bridge.configure(audioPlayer:)`).
- Tap must be installed (playback path uses AVAudioEngine only, not streams or AVPlayer video).
- Guard in `snapshotButterchurnFrame()` can silently stop data if `currentMediaType != .audio` or `isPlaying == false`.
- Butterchurn arrays update only on tap handler -> MainActor `updateLevels`; if Task never runs (main thread blocked) data may be stale.

## References
- `MacAmpApp/Audio/VisualizerPipeline.swift`
- `MacAmpApp/Audio/AudioPlayer.swift`
- `MacAmpApp/ViewModels/ButterchurnBridge.swift`
- `MacAmpApp/Views/WinampMilkdropWindow.swift`
