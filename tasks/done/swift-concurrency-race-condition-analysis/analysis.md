# Swift Concurrency Patterns and Race Conditions Analysis

## Executive Summary

This analysis identifies critical concurrency vulnerabilities and race conditions in the MacAmp codebase. The most severe issues are found in `AudioPlayer.swift`, with additional concerns in ViewModels and timer management throughout the application.

## Critical Findings

### 1. AudioPlayer.swift - Severe Race Conditions

#### 1.1 Progress Timer Race Condition (Lines 542-567)
**Vulnerability:** High
```swift
private func startProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        Task { @MainActor in
            guard let self = self else { return }
            if let nodeTime = self.playerNode.lastRenderTime,
               let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset
                self.currentTime = current
                // RACE CONDITION: playheadOffset can be modified by seek() while timer is running
                if self.currentDuration > 0 {
                    let newProgress = current / self.currentDuration
                    self.playbackProgress = newProgress
                }
            }
        }
    }
}
```

**Issue:** The timer accesses `playheadOffset` and `currentDuration` without synchronization while `seek()` method modifies these values concurrently.

**Impact:** Progress display can jump backward/forward, causing UI inconsistencies.

#### 1.2 Seek Completion Handler Race Condition (Lines 687-774)
**Vulnerability:** Critical
```swift
func seek(to time: Double, resume: Bool? = nil) {
    // CRITICAL FIX: Set isSeeking flag to prevent old completion handler from corrupting state
    currentSeekID = UUID()
    isSeeking = true
    
    // Stop progress timer BEFORE seeking
    progressTimer?.invalidate()
    
    // Schedule the new audio segment
    let audioScheduled = scheduleFrom(time: time, seekID: currentSeekID)
    
    // Update state AFTER scheduling
    currentTime = time
    playbackProgress = targetProgress
    
    // Clear isSeeking flag after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.isSeeking = false
    }
}
```

**Issue:** Despite the seek ID mechanism, there's still a window where old completion handlers can fire and corrupt state.

**Impact:** Playback can jump to wrong position, progress indicator becomes inconsistent.

#### 1.3 Visualizer Tap Concurrent Access (Lines 569-664)
**Vulnerability:** Medium
```swift
private func installVisualizerTapIfNeeded() {
    mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
        // Heavy computation off-main thread
        // ...
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // RACE CONDITION: Multiple concurrent updates to visualizer state
            let used = self.useSpectrumVisualizer ? spec : rms
            // ... state modifications without synchronization
            self.visualizerLevels = smoothed
        }
    }
}
```

**Issue:** Multiple concurrent visualizer updates can overwrite each other.

**Impact:** Visualizer display can flicker or show inconsistent data.

#### 1.4 Async Metadata Loading Race Condition (Lines 96-106)
**Vulnerability:** Medium
```swift
func addTrack(url: URL) {
    if playlist.contains(where: { $0.url == url }) {
        return
    }
    
    Task { @MainActor in
        let track = await loadTrackMetadata(url: url)
        self.playlist.append(track)  // RACE: Multiple calls can duplicate tracks
        
        if self.currentTrack == nil {
            self.playTrack(track: track)  // RACE: Multiple tracks might start playing
        }
    }
}
```

**Issue:** The duplicate check happens before async metadata loading, allowing race conditions.

**Impact:** Duplicate tracks in playlist, multiple tracks starting simultaneously.

### 2. ViewModels Analysis

#### 2.1 DockingController.swift - Combine Memory Management (Lines 53-62)
**Vulnerability:** Low-Medium
```swift
$panes
    .dropFirst()
    .sink { [weak self] panes in
        guard let self else { return }
        if let data = try? JSONEncoder().encode(panes) {
            UserDefaults.standard.set(data, forKey: self.persistKey)
        }
    }
    .store(in: &cancellables)
```

**Issue:** Proper weak self usage, but no explicit cancellation in deinit.

**Impact:** Potential memory leak if controller is deallocated unexpectedly.

#### 2.2 SkinManager.swift - MainActor Violations (Lines 89-140)
**Vulnerability:** Medium
```swift
func importSkin(from sourceURL: URL) async {
    // File operations on background thread
    let fileManager = FileManager.default
    // ...
    
    // UI operations without proper MainActor context
    let response = await alert.beginSheetModal(for: NSApp.keyWindow ?? NSApp.windows.first!)
    
    // State updates happen without explicit MainActor dispatch
    scanAvailableSkins()  // This updates @Published properties
}
```

**Issue:** Mixed async/await without proper MainActor synchronization for UI updates.

**Impact:** UI updates might happen on background threads, causing crashes.

### 3. Timer Management Issues

#### 3.1 VisualizerView.swift - Timer Lifecycle (Lines 62-70)
**Vulnerability:** Medium
```swift
private func startVisualization() {
    guard audioPlayer.isPlaying else { return }
    
    updateTimer?.invalidate()  // Good: invalidates existing timer
    updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
        updateBars()
    }
}

private func stopVisualization() {
    updateTimer?.invalidate()
    updateTimer = nil  // Good: clears reference
}
```

**Assessment:** Proper timer management, but potential race if `startVisualization()` called rapidly.

#### 3.2 WinampMainWindow.swift - Multiple Timers (Lines 614-647)
**Vulnerability:** Medium
```swift
private func startScrolling() {
    guard scrollTimer == nil else { return }  // Good guard
    
    scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak audioPlayer] _ in
        MainActor.assumeIsolated {  // PROPER: Explicit MainActor isolation
            // UI updates
        }
    }
}
```

**Assessment:** Good MainActor usage, but multiple independent timers can cause resource contention.

### 4. WindowSnapManager.swift - Thread Safety

#### 4.1 Delegate Method Concurrency (Lines 33-136)
**Vulnerability:** Low
```swift
func windowDidMove(_ notification: Notification) {
    guard !isAdjusting else { return }  // Good: prevents re-entrancy
    
    // Complex calculations and window manipulations
    isAdjusting = true
    // ... window position calculations
    isAdjusting = false
}
```

**Assessment:** Proper re-entrancy protection with `isAdjusting` flag.

## Recommendations

### Critical Priority

1. **Fix AudioPlayer Progress Timer Race Condition**
   ```swift
   // Add actor-based synchronization
   actor ProgressState {
       var playheadOffset: Double = 0
       var currentDuration: Double = 0
       var currentTime: Double = 0
       var playbackProgress: Double = 0
   }
   
   private let progressState = ProgressState()
   ```

2. **Improve Seek Operation Atomicity**
   ```swift
   func seek(to time: Double, resume: Bool? = nil) async {
       await MainActor.run {
           // All seek operations atomically
           isSeeking = true
           currentSeekID = UUID()
           progressTimer?.invalidate()
           
           let audioScheduled = scheduleFrom(time: time, seekID: currentSeekID)
           
           if audioScheduled {
               currentTime = time
               playbackProgress = targetProgress
               // ... rest of seek logic
           }
           
           isSeeking = false
       }
   }
   ```

3. **Fix Track Addition Race Condition**
   ```swift
   func addTrack(url: URL) async {
       // Check duplicates atomically with playlist modification
       await MainActor.run {
           guard !playlist.contains(where: { $0.url == url }) else { return }
           // Add placeholder track immediately to prevent duplicates
           let placeholder = Track(url: url, title: "Loading...", artist: "", duration: 0)
           playlist.append(placeholder)
       }
       
       // Load metadata asynchronously
       let track = await loadTrackMetadata(url: url)
       
       await MainActor.run {
           // Replace placeholder with actual track
           if let index = playlist.firstIndex(where: { $0.url == url }) {
               playlist[index] = track
           }
       }
   }
   ```

### High Priority

4. **Synchronize Visualizer Updates**
   ```swift
   private let visualizerQueue = DispatchQueue(label: "visualizer", qos: .userInteractive)
   
   // In installVisualizerTapIfNeeded:
   visualizerQueue.async { [weak self] in
       // Process audio data
       DispatchQueue.main.async {
           // Single, synchronized UI update
       }
   }
   ```

5. **Add Explicit Cancellation in ViewModels**
   ```swift
   deinit {
       cancellables.forEach { $0.cancel() }
       cancellables.removeAll()
   }
   ```

### Medium Priority

6. **Improve Timer Management**
   - Use single timer coordinator for multiple timers
   - Add timer state validation before operations
   - Implement proper cleanup in view disappearance

7. **Add MainActor Annotations**
   - Explicitly mark UI-updating methods
   - Use `@MainActor` for all UI state modifications
   - Add proper async/await for background operations

## Testing Recommendations

1. **Concurrency Testing**
   - Test rapid seek operations during playback
   - Test track addition during active playback
   - Test visualizer during seek operations

2. **Stress Testing**
   - Rapid timer start/stop operations
   - Multiple concurrent track additions
   - Memory pressure during audio processing

3. **Thread Sanitizer**
   - Enable Thread Sanitizer in Xcode build settings
   - Run comprehensive tests with TSan enabled
   - Fix all detected data races

## Conclusion

The MacAmp codebase has several critical race conditions, primarily in `AudioPlayer.swift`. The seeking logic and progress timer management require immediate attention to prevent UI inconsistencies and potential crashes. While some good practices are already in place (MainActor usage, weak self patterns), the concurrent audio operations need stronger synchronization mechanisms.

The most critical issue is the progress timer accessing shared state during seek operations, which can cause significant user experience problems. Implementing actor-based synchronization for shared audio state would resolve most of the identified issues.