# Research: VisualizerPipeline Extraction Review

## Scope
- VisualizerPipeline extraction from AudioPlayer
- Architecture adherence (Mechanism layer boundaries)
- Memory safety with Unmanaged pointer in tap callback
- Thread safety and Swift 6 concurrency readiness
- API surface and AudioPlayer forwarding

## Notes
- VisualizerPipeline lives in Mechanism layer and depends only on AVFoundation/Accelerate and AppSettings.
- Tap callback uses Unmanaged passUnretained + takeUnretainedValue in Task on MainActor.
- Tap lifecycle is managed via installTap/removeTap; AudioPlayer holds pipeline strongly.

## Potential Risk Areas
- Unmanaged pointer lifetime if tap outlives pipeline; deinit currently does not remove tap.
- Sendable requirements for data passed into @Sendable Task closure.
- Audio-thread allocations in FFT helpers and waveform snapshot.
