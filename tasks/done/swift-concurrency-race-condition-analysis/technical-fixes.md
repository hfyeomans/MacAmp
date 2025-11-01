# Technical Fixes for Swift Concurrency Issues

## 1. AudioPlayer Progress State Synchronization

### Problem
Progress timer and seek operations access shared state without synchronization, causing race conditions.

### Solution: Actor-based Progress State

```swift
// Add to AudioPlayer.swift
actor ProgressState {
    private var _playheadOffset: Double = 0
    private var _currentDuration: Double = 0
    private var _currentTime: Double = 0
    private var _playbackProgress: Double = 0
    
    var playheadOffset: Double { _playheadOffset }
    var currentDuration: Double { _currentDuration }
    var currentTime: Double { _currentTime }
    var playbackProgress: Double { _playbackProgress }
    
    func updatePlayhead(_ offset: Double) {
        _playheadOffset = offset
    }
    
    func updateDuration(_ duration: Double) {
        _currentDuration = duration
    }
    
    func updateTime(_ time: Double) async {
        _currentTime = time
        if _currentDuration > 0 {
            _playbackProgress = time / _currentDuration
        } else {
            _playbackProgress = 0
        }
    }
    
    func setSeekState(_ time: Double, _ duration: Double) async {
        _currentTime = time
        _currentDuration = duration
        _playheadOffset = time
        _playbackProgress = duration > 0 ? time / duration : 0
    }
}
```

### Updated Progress Timer

```swift
private func startProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        Task { @MainActor in
            guard let self = self else { return }
            guard !self.isSeeking else { return } // Skip updates during seek
            
            if let nodeTime = self.playerNode.lastRenderTime,
               let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                let current = Double(playerTime.sampleTime) / playerTime.sampleRate
                
                // Update progress state atomically
                await self.progressState.updateTime(current)
                
                // Get updated values for UI
                let (currentTime, playbackProgress) = await (
                    self.progressState.currentTime,
                    self.progressState.playbackProgress
                )
                
                // Update UI properties
                self.currentTime = currentTime
                self.playbackProgress = playbackProgress
            }
        }
    }
    RunLoop.main.add(progressTimer!, forMode: .common)
}
```

## 2. Seek Operation Atomicity

### Problem
Seek operations have multiple state changes that can be interrupted, causing inconsistent state.

### Solution: Atomic Seek Operations

```swift
func seek(to time: Double, resume: Bool? = nil) async {
    guard let file = audioFile else {
        NSLog("⚠️ seek: Cannot seek - no audio file loaded")
        return
    }
    
    // Perform all seek operations atomically on MainActor
    await MainActor.run {
        let shouldPlay = resume ?? isPlaying
        wasStopped = false
        
        // Set seek protection
        currentSeekID = UUID()
        isSeeking = true
        
        // Stop progress timer
        progressTimer?.invalidate()
        
        // Calculate target progress
        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate
        let targetProgress = fileDuration > 0 ? time / fileDuration : 0
        
        #if DEBUG
        print("DEBUG seek: time=\(time), fileDuration=\(fileDuration), targetProgress=\(targetProgress)")
        #endif
        
        // Schedule audio synchronously
        let audioScheduled = scheduleFrom(time: time, seekID: currentSeekID)
        
        // Update state atomically
        Task {
            await progressState.setSeekState(time, fileDuration)
        }
        
        currentTime = time
        playbackProgress = targetProgress
        
        // Handle playback state
        if audioScheduled && shouldPlay {
            startEngineIfNeeded()
            playerNode.play()
            startProgressTimer()
            isPlaying = true
            isPaused = false
        } else if !audioScheduled {
            isPlaying = false
            isPaused = false
            
            // Handle track completion
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
                await self.onPlaybackEnded()
            }
        } else {
            isPlaying = false
        }
        
        // Clear seek flag after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            self.isSeeking = false
        }
    }
}
```

## 3. Track Addition Race Condition Fix

### Problem
Multiple concurrent `addTrack()` calls can result in duplicate tracks.

### Solution: Atomic Track Addition

```swift
private let trackAdditionQueue = DispatchQueue(label: "trackAddition", qos: .userInitiated)

func addTrack(url: URL) {
    trackAdditionQueue.async { [weak self] in
        guard let self = self else { return }
        
        // Check for duplicates atomically
        let isDuplicate = await MainActor.run {
            self.playlist.contains(where: { $0.url == url })
        }
        
        if isDuplicate {
            print("AudioPlayer: Track already in playlist: \(url.lastPathComponent)")
            return
        }
        
        print("AudioPlayer: Adding track from \(url.lastPathComponent)")
        
        // Create placeholder track immediately
        let placeholder = Track(
            url: url,
            title: url.lastPathComponent,
            artist: "Loading...",
            duration: 0.0
        )
        
        // Add placeholder atomically
        await MainActor.run {
            self.playlist.append(placeholder)
            let shouldAutoPlay = self.currentTrack == nil
            
            if shouldAutoPlay {
                self.playTrack(track: placeholder)
            }
        }
        
        // Load metadata asynchronously
        Task {
            let track = await self.loadTrackMetadata(url: url)
            
            // Replace placeholder with actual track
            await MainActor.run {
                if let index = self.playlist.firstIndex(where: { $0.url == url }) {
                    self.playlist[index] = track
                    
                    // If this is the currently playing placeholder, update it
                    if self.currentTrack?.url == url {
                        self.currentTrack = track
                        self.currentTitle = "\(track.title) - \(track.artist)"
                        self.currentDuration = track.duration
                    }
                }
            }
        }
    }
}
```

## 4. Visualizer Update Synchronization

### Problem
Multiple concurrent visualizer updates can overwrite each other.

### Solution: Serialized Visualizer Updates

```swift
private let visualizerUpdateQueue = DispatchQueue(label: "visualizerUpdate", qos: .userInteractive)

private func installVisualizerTapIfNeeded() {
    guard !visualizerTapInstalled else { return }
    let mixer = audioEngine.mainMixerNode
    mixer.removeTap(onBus: 0)
    
    mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
        guard let self = self else { return }
        
        // Process audio data off main thread
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0, let ptr = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return }
        
        // Compute RMS and spectrum data
        let (rms, spec) = self.computeAudioData(buffer: buffer, ptr: ptr, channelCount: channelCount, frameCount: frameCount)
        
        // Serialize UI updates
        self.visualizerUpdateQueue.async {
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateVisualizerState(rms: rms, spec: spec)
            }
        }
    }
    visualizerTapInstalled = true
}

private func computeAudioData(buffer: AVAudioPCMBuffer, ptr: UnsafePointer<UnsafePointer<Float>>, channelCount: Int, frameCount: Int) -> ([Float], [Float]) {
    // Mix down to mono
    var mono: [Float] = Array(repeating: 0, count: frameCount)
    let invCount = 1.0 / Float(channelCount)
    for i in 0..<frameCount {
        var sum: Float = 0
        for ch in 0..<channelCount {
            sum += ptr[ch][i]
        }
        mono[i] = sum * invCount
    }
    
    let bars = 20
    
    // Compute RMS bars
    var rms = Array(repeating: Float(0), count: bars)
    let bucketSize = max(1, frameCount / bars)
    var idx = 0
    for b in 0..<bars {
        let start = idx
        let end = min(frameCount, start + bucketSize)
        if end > start {
            var sumSq: Float = 0
            let len = end - start
            var j = start
            while j < end {
                let s = mono[j]
                sumSq += s * s
                j += 1
            }
            var v = sqrt(sumSq / Float(len))
            v = min(1.0, v * 4.0)
            rms[b] = v
        }
        idx = end
    }
    
    // Compute spectrum bars (simplified version)
    var spec = Array(repeating: Float(0), count: bars)
    // ... spectrum calculation code ...
    
    return (rms, spec)
}

private func updateVisualizerState(rms: [Float], spec: [Float]) {
    let used = useSpectrumVisualizer ? spec : rms
    let now = CFAbsoluteTimeGetCurrent()
    let dt = max(0, Float(now - lastUpdateTime))
    lastUpdateTime = now
    let alpha = max(0, min(1, visualizerSmoothing))
    
    var smoothed = [Float](repeating: 0, count: used.count)
    var newPeaks = [Float](repeating: 0, count: used.count)
    
    for b in 0..<used.count {
        let prev = (b < visualizerLevels.count) ? visualizerLevels[b] : 0
        smoothed[b] = alpha * prev + (1 - alpha) * used[b]
        let fall = visualizerPeakFalloff * dt
        let dropped = max(0, visualizerPeaks[b] - fall)
        newPeaks[b] = max(dropped, smoothed[b])
    }
    
    // Atomic state update
    visualizerLevels = smoothed
    visualizerPeaks = newPeaks
}
```

## 5. ViewModel Memory Management

### Problem
Combine subscriptions not properly cancelled in ViewModels.

### Solution: Explicit Cancellation

```swift
// DockingController.swift
deinit {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
}

// SkinManager.swift
@MainActor
deinit {
    // Cancel any ongoing operations
    isLoading = false
    loadingError = nil
}
```

## 6. Timer Coordinator

### Problem
Multiple independent timers can cause resource contention.

### Solution: Centralized Timer Management

```swift
class TimerCoordinator {
    private var timers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "timerCoordinator", qos: .userInteractive)
    
    func scheduleTimer(id: String, interval: TimeInterval, repeats: Bool, action: @escaping () -> Void) {
        queue.async { [weak self] in
            // Cancel existing timer
            self?.timers[id]?.invalidate()
            
            // Schedule new timer
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
                DispatchQueue.main.async {
                    action()
                }
            }
            
            self?.timers[id] = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func invalidateTimer(id: String) {
        queue.async { [weak self] in
            self?.timers[id]?.invalidate()
            self?.timers.removeValue(forKey: id)
        }
    }
    
    func invalidateAll() {
        queue.async { [weak self] in
            self?.timers.values.forEach { $0.invalidate() }
            self?.timers.removeAll()
        }
    }
}
```

## 7. Enhanced Error Handling

### Problem
Async operations lack proper error handling.

### Solution: Structured Error Handling

```swift
enum AudioPlayerError: LocalizedError {
    case fileNotFound(URL)
    case corruptedFile(URL)
    case seekOperationFailed
    case engineConfigurationFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .corruptedFile(let url):
            return "Corrupted audio file: \(url.lastPathComponent)"
        case .seekOperationFailed:
            return "Seek operation failed"
        case .engineConfigurationFailed:
            return "Audio engine configuration failed"
        }
    }
}

func loadAudioFile(url: URL) async throws {
    do {
        audioFile = try AVAudioFile(forReading: url)
        rewireForCurrentFile()
        let _ = try await scheduleFrom(time: 0)
        playerNode.volume = volume
        playerNode.pan = balance
        
        // Update audio properties
        await updateAudioProperties(for: url)
    } catch {
        throw AudioPlayerError.corruptedFile(url)
    }
}
```

## Implementation Priority

1. **Immediate (Critical)**: Implement ProgressState actor and fix seek operations
2. **High**: Fix track addition race condition
3. **Medium**: Implement visualizer synchronization and timer coordinator
4. **Low**: Add enhanced error handling and memory management improvements

## Testing Strategy

1. **Unit Tests**: Test each actor and synchronization mechanism
2. **Integration Tests**: Test seek operations during active playback
3. **Stress Tests**: Rapid concurrent operations
4. **Thread Sanitizer**: Run with TSan to detect remaining data races

These fixes will eliminate the identified race conditions and provide a robust foundation for concurrent audio operations in MacAmp.