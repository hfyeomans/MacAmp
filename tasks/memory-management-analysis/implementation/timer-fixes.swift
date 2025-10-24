// MARK: - Timer Management Fixes
// This file contains fixes for critical timer memory leaks identified in the analysis

import Foundation
import SwiftUI

// MARK: - Fix 1: EqualizerWindowView Timer Leak

extension EqualizerWindowView {
    
    /// FIXED: Proper timer management with storage and cleanup
    @State private var visualizationTimer: Timer?
    
    /// FIXED: Timer that can be properly invalidated
    private func startVisualizationTimer() {
        // Cancel existing timer first
        visualizationTimer?.invalidate()
        
        visualizationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioPlayer] _ in
            Task { @MainActor in
                guard let audioPlayer = audioPlayer else { return }
                if audioPlayer.isPlaying && audioPlayer.isEqOn {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        eqVisualization = eqVisualization.map { _ in Float.random(in: 0...1) }
                    }
                }
            }
        }
    }
    
    /// FIXED: Cleanup method for timer
    private func cleanupVisualizationTimer() {
        visualizationTimer?.invalidate()
        visualizationTimer = nil
    }
    
    /// UPDATED: onDisappear with proper cleanup
    private func setupViewLifecycle() {
        .onDisappear {
            cleanupVisualizationTimer()
        }
        .onAppear {
            startVisualizationTimer()
        }
    }
}

// MARK: - Fix 2: Enhanced AudioPlayer Timer Management

extension AudioPlayer {
    
    /// ENHANCED: Comprehensive timer cleanup
    func cleanupAllTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Clear any other timer-related state
        isSeeking = false
        isHandlingCompletion = false
    }
    
    /// ENHANCED: Improved timer creation with error handling
    private func startProgressTimerSafe() {
        // Invalidate existing timer first
        progressTimer?.invalidate()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Early exit if not playing
                guard self.isPlaying else { return }
                
                if let nodeTime = self.playerNode.lastRenderTime,
                   let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                    let current = Double(playerTime.sampleTime) / playerTime.sampleRate + self.playheadOffset
                    self.currentTime = current
                    if self.currentDuration > 0 {
                        let newProgress = current / self.currentDuration
                        self.playbackProgress = newProgress
                    } else {
                        self.playbackProgress = 0
                    }
                }
            }
        }
        
        // Ensure timer runs on main run loop
        RunLoop.main.add(progressTimer!, forMode: .common)
    }
}

// MARK: - Fix 3: VisualizerView Timer Enhancement

extension VisualizerView {
    
    /// ENHANCED: Better timer lifecycle management
    private func startVisualizationSafe() {
        guard audioPlayer.isPlaying else { return }
        
        // Cancel existing timer
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateBars()
        }
        
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    /// ENHANCED: Comprehensive cleanup
    private func stopVisualizationSafe() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Clear animation state
        withAnimation(.easeOut(duration: 0.3)) {
            barHeights = Array(repeating: 0, count: barCount)
            peakPositions = Array(repeating: 0, count: barCount)
        }
    }
}

// MARK: - Fix 4: WinampMainWindow Timer Cleanup

extension WinampMainWindow {
    
    /// ENHANCED: Centralized timer cleanup
    private func cleanupAllTimers() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        pauseBlinkTimer?.invalidate()
        pauseBlinkTimer = nil
        
        // Reset animation state
        scrollOffset = 0
        pauseBlinkVisible = true
        isScrubbing = false
    }
    
    /// ENHANCED: Safe pause blink timer management
    private func startPauseBlinkTimerSafe() {
        pauseBlinkTimer?.invalidate()
        pauseBlinkVisible = true
        
        pauseBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.pauseBlinkVisible.toggle()
        }
        
        RunLoop.main.add(pauseBlinkTimer!, forMode: .common)
    }
    
    /// ENHANCED: Safe scroll timer management
    private func startScrollingSafe() {
        guard scrollTimer == nil else { return }
        
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak audioPlayer] _ in
            guard let audioPlayer = audioPlayer else { return }
            
            MainActor.assumeIsolated {
                let trackText = audioPlayer.currentTitle.isEmpty ? "MacAmp" : audioPlayer.currentTitle
                let textWidth = CGFloat(trackText.count * 5)
                let displayWidth = Coords.trackInfo.width
                
                if textWidth > displayWidth {
                    withAnimation(.linear(duration: 0.15)) {
                        scrollOffset -= 5
                        
                        if abs(scrollOffset) >= textWidth + 20 {
                            scrollOffset = displayWidth
                        }
                    }
                }
            }
        }
        
        RunLoop.main.add(scrollTimer!, forMode: .common)
    }
}

// MARK: - Utility: Timer Manager

/// Centralized timer management to prevent leaks
class TimerManager: ObservableObject {
    private var timers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "timer.manager", qos: .utility)
    
    /// Create a timer with automatic cleanup
    func createTimer(id: String, interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer? {
        // Cancel existing timer with same ID
        cancelTimer(id: id)
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
        
        queue.async {
            self.timers[id] = timer
        }
        
        return timer
    }
    
    /// Cancel timer by ID
    func cancelTimer(id: String) {
        queue.async {
            if let timer = self.timers[id] {
                timer.invalidate()
                self.timers.removeValue(forKey: id)
            }
        }
    }
    
    /// Cancel all timers
    func cancelAllTimers() {
        queue.async {
            self.timers.values.forEach { $0.invalidate() }
            self.timers.removeAll()
        }
    }
    
    /// Get active timer count
    var activeTimerCount: Int {
        return queue.sync {
            return timers.count
        }
    }
    
    deinit {
        cancelAllTimers()
    }
}

// MARK: - Usage Example

/*
// In a view:
@StateObject private var timerManager = TimerManager()

// Create timer:
timerManager.createTimer(id: "visualization", interval: 0.1, repeats: true) { _ in
    updateVisualization()
}

// Cleanup:
.onDisappear {
    timerManager.cancelTimer(id: "visualization")
}
*/

// MARK: - Debug Helper

extension TimerManager {
    
    /// Debug method to list all active timers
    func listActiveTimers() {
        queue.async {
            print("=== Active Timers ===")
            for (id, _) in self.timers {
                print("Timer: \(id)")
            }
            print("Total: \(self.timers.count)")
        }
    }
    
    /// Check for timer leaks
    func checkForLeaks() -> Bool {
        return queue.sync {
            return timers.count > 10 // Arbitrary threshold
        }
    }
}