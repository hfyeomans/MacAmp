// MARK: - Audio Buffer Management Fixes
// This file contains fixes for audio buffer retention and cleanup issues

import Foundation
import AVFoundation
import Accelerate

// MARK: - Fix 1: Enhanced AudioPlayer Buffer Cleanup

extension AudioPlayer {
    
    /// FIXED: Comprehensive audio buffer cleanup
    func cleanupAudioBuffers() {
        print("🧹 Cleaning up audio buffers...")
        
        // Clear visualizer data arrays
        visualizerLevels.removeAll(keepingCapacity: false)
        visualizerPeaks.removeAll(keepingCapacity: false)
        
        // Reinitialize with clean arrays
        visualizerLevels = Array(repeating: 0.0, count: 20)
        visualizerPeaks = Array(repeating: 0.0, count: 20)
        
        // Remove audio tap to release buffer references
        if visualizerTapInstalled {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            visualizerTapInstalled = false
            print("🔇 Removed audio tap")
        }
        
        // Clear audio file reference
        audioFile = nil
        
        // Reset audio engine state
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.reset()
            print("🛑 Reset audio engine")
        }
        
        // Clear progress tracking
        playheadOffset = 0
        lastUpdateTime = CFAbsoluteTimeGetCurrent()
        
        print("✅ Audio buffer cleanup completed")
    }
    
    /// ENHANCED: Safe visualizer tap installation with cleanup
    private func installVisualizerTapSafe() {
        guard !visualizerTapInstalled else { return }
        
        // Remove any existing tap first
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        
        let mixer = audioEngine.mainMixerNode
        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            // Early exit if self is nil
            guard let self = self else { return }
            
            // Process audio data off main thread
            self.processAudioBuffer(buffer)
        }
        
        visualizerTapInstalled = true
        print("🎵 Installed visualizer tap")
    }
    
    /// ENHANCED: Safe audio buffer processing with memory management
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Use autoreleasepool for temporary objects
        autoreleasepool {
            guard let channelData = buffer.floatChannelData else { return }
            
            let channelCount = Int(buffer.format.channelCount)
            let frameCount = Int(buffer.frameLength)
            
            guard channelCount > 0 && frameCount > 0 else { return }
            
            // Mix down to mono efficiently
            var monoData = [Float](repeating: 0, count: frameCount)
            let invChannelCount = 1.0 / Float(channelCount)
            
            // Use vDSP for efficient processing
            for ch in 0..<channelCount {
                vDSP_vadd(channelData[ch], 1, &monoData, 1, &monoData, 1, vDSP_Length(frameCount))
            }
            vDSP_vsmul(&monoData, 1, &invChannelCount, &monoData, 1, vDSP_Length(frameCount))
            
            // Calculate frequency data
            let frequencyData = calculateFrequencyData(from: monoData, sampleRate: buffer.format.sampleRate)
            
            // Update UI on main thread with minimal data
            DispatchQueue.main.async { [weak self] in
                self?.updateVisualizerData(frequencyData)
            }
        }
    }
    
    /// ENHANCED: Efficient frequency data calculation
    private func calculateFrequencyData(from monoData: [Float], sampleRate: Float) -> [Float] {
        let bars = 20
        var rms = Array(repeating: Float(0), count: bars)
        var spectrum = Array(repeating: Float(0), count: bars)
        
        // Calculate RMS bars
        let bucketSize = max(1, monoData.count / bars)
        for b in 0..<bars {
            let start = b * bucketSize
            let end = min(start + bucketSize, monoData.count)
            
            if end > start {
                var sumSq: Float = 0
                vDSP_svsq(monoData[start..<end], 1, &sumSq)
                var rmsValue = sqrt(sumSq / Float(end - start))
                rmsValue = min(1.0, rmsValue * 4.0)
                rms[b] = rmsValue
            }
        }
        
        // Calculate spectrum using Goertzel algorithm (more efficient than FFT for few bins)
        let frequencies: [Float] = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]
        for b in 0..<bars {
            let targetFreq = frequencies[min(b, frequencies.count - 1)]
            spectrum[b] = goertzel(monoData, sampleRate: sampleRate, targetFreq: targetFreq)
        }
        
        return useSpectrumVisualizer ? spectrum : rms
    }
    
    /// Efficient Goertzel algorithm for single frequency detection
    private func goertzel(_ data: [Float], sampleRate: Float, targetFreq: Float) -> Float {
        let n = data.count
        let k = Int(round(Double(n) * Double(targetFreq) / Double(sampleRate)))
        let omega = 2.0 * Double.pi * Double(k) / Double(n)
        let cosine = cos(omega)
        let sine = sin(omega)
        
        var coeff = 2.0 * cosine
        var q0 = 0.0
        var q1 = 0.0
        var q2 = 0.0
        
        for i in 0..<n {
            q0 = coeff * q1 - q2 + Double(data[i])
            q2 = q1
            q1 = q0
        }
        
        let real = q1 - q2 * cosine / 2.0
        let imag = q2 * sine / 2.0
        let magnitude = sqrt(real * real + imag * imag)
        
        return min(1.0, Float(magnitude) * 4.0 / Float(n))
    }
    
    /// ENHANCED: Safe visualizer data update with memory management
    private func updateVisualizerData(_ newData: [Float]) {
        let now = CFAbsoluteTimeGetCurrent()
        let dt = max(0, Float(now - lastUpdateTime))
        lastUpdateTime = now
        
        let alpha = max(0, min(1, visualizerSmoothing))
        var smoothed = [Float](repeating: 0, count: newData.count)
        
        // Use vDSP for efficient vector operations
        vDSP_vsmul(&visualizerLevels, 1, &alpha, &smoothed, 1, vDSP_Length(newData.count))
        
        var oneMinusAlpha = 1.0 - alpha
        vDSP_vsmul(&newData, 1, &oneMinusAlpha, &newData, 1, vDSP_Length(newData.count))
        vDSP_vadd(smoothed, 1, newData, 1, &smoothed, 1, vDSP_Length(newData.count))
        
        // Update peak positions with falloff
        let fall = visualizerPeakFalloff * dt
        for b in 0..<visualizerPeaks.count {
            let dropped = max(0, visualizerPeaks[b] - fall)
            visualizerPeaks[b] = max(dropped, smoothed[b])
        }
        
        visualizerLevels = smoothed
    }
    
    /// ENHANCED: Improved stop method with comprehensive cleanup
    func stopWithCleanup() {
        print("🛑 Stopping audio playback with cleanup...")
        
        wasStopped = true
        playerNode.stop()
        
        // Clean up all audio resources
        cleanupAudioBuffers()
        
        // Reset playback state
        let _ = scheduleFrom(time: 0)
        currentTime = 0
        playbackProgress = 0
        
        // Clean up timers
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Reset state
        isPlaying = false
        isPaused = false
        isSeeking = false
        isHandlingCompletion = false
        
        // Reset audio properties when no track is loaded
        if currentTrack == nil {
            bitrate = 0
            sampleRate = 0
            channelCount = 2
        }
        
        print("✅ Audio stopped and cleaned up")
    }
    
    /// NEW: Method to check and report memory usage
    func getAudioMemoryReport() -> String {
        let visualizerMemory = visualizerLevels.count * MemoryLayout<Float>.size + visualizerPeaks.count * MemoryLayout<Float>.size
        let audioFileSize = audioFile != nil ? "Loaded" : "None"
        
        return """
        Audio Memory Report:
        - Visualizer Arrays: \(visualizerMemory) bytes
        - Audio File: \(audioFileSize)
        - Visualizer Tap: \(visualizerTapInstalled ? "Installed" : "Removed")
        - Engine Running: \(audioEngine.isRunning)
        """
    }
}

// MARK: - Fix 2: Audio Buffer Pool

/// Reusable audio buffer pool to reduce memory allocations
class AudioBufferPool {
    private var bufferPool: [AVAudioPCMBuffer] = []
    private let maxPoolSize: Int
    private let lock = NSLock()
    
    init(maxPoolSize: Int = 10) {
        self.maxPoolSize = maxPoolSize
    }
    
    /// Get a buffer from the pool or create a new one
    func getBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer {
        lock.lock()
        defer { lock.unlock() }
        
        // Find a compatible buffer in the pool
        if let index = bufferPool.firstIndex(where: { buffer in
            buffer.format.sampleRate == format.sampleRate &&
            buffer.format.channelCount == format.channelCount &&
            buffer.frameCapacity >= frameCapacity
        }) {
            let buffer = bufferPool.remove(at: index)
            buffer.frameLength = frameCapacity
            return buffer
        }
        
        // Create new buffer
        return AVAudioPCMBuffer(format: format, frameCapacity: frameCapacity)!
    }
    
    /// Return a buffer to the pool
    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        guard bufferPool.count < maxPoolSize else { return }
        
        // Clear buffer data
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(buffer.format.channelCount) {
                vDSP_vclr(channelData[channel], 1, vDSP_Length(buffer.frameCapacity))
            }
        }
        
        bufferPool.append(buffer)
    }
    
    /// Clear the buffer pool
    func clearPool() {
        lock.lock()
        defer { lock.unlock() }
        
        bufferPool.removeAll()
    }
    
    /// Get pool statistics
    var poolStatistics: String {
        lock.lock()
        defer { lock.unlock() }
        
        return "Buffer Pool: \(bufferPool.count)/\(maxPoolSize) buffers"
    }
}

// MARK: - Fix 3: Memory-Efficient Visualizer

extension VisualizerView {
    
    /// ENHANCED: Memory-efficient visualizer with buffer reuse
    private func updateBarsEfficiently() {
        guard audioPlayer.isPlaying else { return }
        
        // Get frequency data efficiently
        let frequencyData = audioPlayer.getFrequencyData(bands: barCount)
        
        // Update with minimal allocations
        withAnimation(.linear(duration: updateInterval)) {
            // Reuse existing arrays instead of creating new ones
            for i in 0..<barCount {
                // Apply frequency-specific amplification
                let frequencyBoost: CGFloat = 1.0 + (CGFloat(i) / CGFloat(barCount)) * 0.5
                
                var targetHeight = CGFloat(frequencyData[i]) * maxHeight * amplificationFactor * frequencyBoost
                
                if audioPlayer.isPlaying && frequencyData[i] > 0.01 {
                    targetHeight = max(minBarHeight, targetHeight)
                }
                
                targetHeight = min(maxHeight, targetHeight)
                
                // Update in place
                barHeights[i] = max(targetHeight, barHeights[i] * decayRate)
                
                // Update peak positions
                if barHeights[i] > peakPositions[i] {
                    peakPositions[i] = barHeights[i]
                    peakTimers[i] = Date()
                } else if Date().timeIntervalSince(peakTimers[i]) > peakHoldTime {
                    peakPositions[i] = max(0, peakPositions[i] * peakDecayRate - 0.5)
                }
            }
        }
    }
    
    /// ENHANCED: Cleanup method for visualizer
    private func cleanupVisualizer() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Clear arrays efficiently
        barHeights.removeAll(keepingCapacity: false)
        peakPositions.removeAll(keepingCapacity: false)
        peakTimers.removeAll(keepingCapacity: false)
        
        // Reinitialize with clean arrays
        barHeights = Array(repeating: 0, count: barCount)
        peakPositions = Array(repeating: 0, count: barCount)
        peakTimers = Array(repeating: Date.distantPast, count: barCount)
    }
}

// MARK: - Usage Example

/*
// In AudioPlayer:
private let bufferPool = AudioBufferPool()

// When processing audio:
let buffer = bufferPool.getBuffer(format: format, frameCapacity: 1024)
// ... use buffer ...
bufferPool.returnBuffer(buffer)

// In view lifecycle:
.onDisappear {
    audioPlayer.cleanupAudioBuffers()
    visualizer.cleanupVisualizer()
}
*/