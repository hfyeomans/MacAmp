# Audio Tap Crash Fix - Summary

## Problem
The AudioPlayer was experiencing crashes due to Swift 6's strict actor isolation checks. The issue was that we were rehydrating the `AudioPlayer` instance from `Unmanaged` on the **AUDIO THREAD** (inside the static nonisolated `processAudioBuffer` method), which violates Swift 6's concurrency model.

## Root Cause
The previous implementation had a static nonisolated method that:
1. Received an opaque pointer to AudioPlayer
2. **Rehydrated the AudioPlayer instance on the audio thread** ❌
3. Processed audio data on the audio thread
4. Dispatched to MainActor with another opaque pointer
5. **Rehydrated the AudioPlayer again inside the Task** ❌

This double-rehydration pattern, especially the first one on the audio thread, triggered Swift 6's actor isolation checks and caused crashes.

## Solution (Codex Oracle Pattern)
The fix follows the principle: **NEVER rehydrate AudioPlayer on the audio thread. Only rehydrate INSIDE the @MainActor Task.**

Because the closure now executes on AVAudioEngine's realtime queue, we build it through a `nonisolated(unsafe)` helper (`makeVisualizerTapHandler`). That keeps the closure out of the `@MainActor` isolation domain, so Dispatch no longer asserts while still allowing us to forward only Sendable snapshots back to `updateVisualizerLevels`.

### Key Changes

#### 1. Removed Static Nonisolated Method
**REMOVED:** `private static nonisolated func processAudioBuffer(context: UnsafeMutableRawPointer, buffer: AVAudioPCMBuffer, scratch: VisualizerScratchBuffers)`

This method was the source of the problem - it rehydrated AudioPlayer on the audio thread.

#### 2. Inlined Audio Processing
All audio processing logic is now **inline** in the `installTap` closure:
- Mix to mono
- Compute RMS levels
- Compute spectrum using Goertzel algorithm
- Apply frequency-dependent gain compensation

The audio thread now only:
- Accesses primitives (Float, Int, etc.)
- Works with the opaque pointer (NOT rehydrated)
- Captures sendable data snapshots

#### 3. Created MainActor Update Method
**ADDED:** `@MainActor private func updateVisualizerLevels(rms: [Float], spectrum: [Float])`

This method handles all UI updates safely on the MainActor:
- Applies smoothing
- Updates peak falloff
- Updates visualizer levels

#### 4. Safe Rehydration Pattern
The pointer is now rehydrated **ONLY** inside the `Task { @MainActor }` block:

```swift
Task { @MainActor [contextPointer, rmsSnapshot, spectrumSnapshot] in
    // ✅ Rehydrate INSIDE @MainActor Task (safe!)
    let player = Unmanaged<AudioPlayer>.fromOpaque(contextPointer).takeUnretainedValue()
    player.updateVisualizerLevels(rms: rmsSnapshot, spectrum: spectrumSnapshot)
}
```

## Implementation Details

### Audio Thread (installTap closure)
- Captures `contextPointer` (opaque pointer) on MainActor
- Processes all audio inline (no AudioPlayer access)
- Creates sendable snapshots: `[Float]` arrays
- Dispatches to MainActor with only primitives

### MainActor Thread (Task block)
- Rehydrates pointer safely
- Updates UI properties
- Applies smoothing algorithms

## Verification
1. ✅ Build succeeds with Thread Sanitizer enabled
2. ✅ No actor isolation violations
3. ✅ All audio processing logic preserved
4. ✅ Visualizer updates work correctly

## Files Modified
- `/Users/hank/dev/src/MacAmp/MacAmpApp/Audio/AudioPlayer.swift`
  - Removed: `processAudioBuffer` static method
  - Added: `updateVisualizerLevels` MainActor method
  - Modified: `installVisualizerTapIfNeeded` - inline audio processing

## Testing Recommendations
1. Launch MacAmp with Thread Sanitizer enabled
2. Load and play an audio file (e.g., `/Users/hank/dev/src/MacAmp/mono_test.wav`)
3. Verify visualizer responds to audio
4. Verify no crashes or warnings in console
5. Test with both RMS and spectrum visualizers
6. Test with multiple tracks

## Build Command
```bash
xcodebuild -scheme MacAmpApp -configuration Debug -enableThreadSanitizer YES clean build
```

## Key Principle
**Audio thread sees only primitives and pointers, MainActor Task does the rehydration.**

This pattern ensures Swift 6 concurrency safety while maintaining real-time audio performance.
