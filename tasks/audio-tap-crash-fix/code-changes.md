# Audio Tap Crash Fix - Code Changes

## File: MacAmpApp/Audio/AudioPlayer.swift

### Summary of Changes
1. **Marked** `VisualizerScratchBuffers` as `@unchecked Sendable` and introduced `VisualizerTapContext`
2. **Added** `@MainActor updateVisualizerLevels` method (~18 lines)
3. **Introduced** `nonisolated(unsafe)` helper `makeVisualizerTapHandler` (~130 lines)
4. **Updated** `installVisualizerTapIfNeeded` to use the helper

---

## Change 1: Sendable Scratch State & Context Wrapper

**Location:** Lines 7-59

**Purpose:** Allow the audio tap closure to run on AVAudioEngine's realtime queue without tripping Swift 6 isolation checks.

```swift
// Scratch buffers are confined to the audio tap queue, so @unchecked Sendable is safe.
private final class VisualizerScratchBuffers: @unchecked Sendable { ... }

private struct VisualizerTapContext: @unchecked Sendable {
    let playerPointer: UnsafeMutableRawPointer
}
```

---

## Change 2: Added MainActor Update Method

**Location:** Lines 834-852

**Purpose:** Safely update visualizer UI from audio thread data.

```swift
/// MainActor method for updating visualizer levels from audio thread data
@MainActor
private func updateVisualizerLevels(rms: [Float], spectrum: [Float]) {
    let used = self.useSpectrumVisualizer ? spectrum : rms
    let now = CFAbsoluteTimeGetCurrent()
    let dt = max(0, Float(now - self.lastUpdateTime))
    self.lastUpdateTime = now
    let alpha = max(0, min(1, self.visualizerSmoothing))
    var smoothed = [Float](repeating: 0, count: used.count)
    for b in 0..<used.count {
        let prev = (b < self.visualizerLevels.count) ? self.visualizerLevels[b] : 0
        smoothed[b] = alpha * prev + (1 - alpha) * used[b]
        let fall = self.visualizerPeakFalloff * dt
        let dropped = max(0, self.visualizerPeaks[b] - fall)
        self.visualizerPeaks[b] = max(dropped, smoothed[b])
    }
    self.visualizerLevels = smoothed
}
```

---

## Change 3: Added Tap Handler Factory

**Location:** Lines 854-957

**Purpose:** Build the tap closure outside the `@MainActor` isolation domain so AVAudioEngine can execute it on `RealtimeMessenger.mServiceQueue` without hitting `_dispatch_assert_queue_fail`. The helper performs all real-time processing and forwards only Sendable snapshots back to `updateVisualizerLevels`.

```swift
/// Build the tap handler in a nonisolated context so AVAudioEngine can call it on its realtime queue.
private nonisolated(unsafe) static func makeVisualizerTapHandler(
    context: VisualizerTapContext,
    scratch: VisualizerScratchBuffers
) -> @Sendable (AVAudioPCMBuffer, AVAudioTime?) -> Void {
    { buffer, _ in
        // [AUDIO THREAD] mix to mono, compute RMS, spectrum, etc.
        let rmsSnapshot = scratch.snapshotRms()
        let spectrumSnapshot = scratch.snapshotSpectrum()

        Task { @MainActor [context, rmsSnapshot, spectrumSnapshot] in
            let player = Unmanaged<AudioPlayer>.fromOpaque(context.playerPointer).takeUnretainedValue()
            player.updateVisualizerLevels(rms: rmsSnapshot, spectrum: spectrumSnapshot)
        }
    }
}
```

---

## Change 4: Modified installVisualizerTapIfNeeded

**Location:** Lines 959-975

**Key differences:**
1. Capture `VisualizerTapContext` on the MainActor
2. Build the tap using `makeVisualizerTapHandler`
3. Install the tap with the prebuilt closure

```swift
private func installVisualizerTapIfNeeded() {
    guard !visualizerTapInstalled else { return }
    let mixer = audioEngine.mainMixerNode
    mixer.removeTap(onBus: 0)
    visualizerTapInstalled = false
    let scratch = VisualizerScratchBuffers()

    let context = VisualizerTapContext(
        playerPointer: Unmanaged.passUnretained(self).toOpaque()
    )
    let handler = AudioPlayer.makeVisualizerTapHandler(
        context: context,
        scratch: scratch
    )

    mixer.installTap(onBus: 0, bufferSize: 1024, format: nil, block: handler)
}
```

**Key outcomes:**
- Audio thread never rehydrates `AudioPlayer`
- Only Sendable snapshots cross the actor boundary
- Dispatch no longer asserts about incorrect queues
*** End Patch
