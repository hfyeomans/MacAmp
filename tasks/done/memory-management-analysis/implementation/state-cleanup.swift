// MARK: - SwiftUI State Management Fixes
// This file contains fixes for state accumulation and cleanup issues

import SwiftUI
import Foundation

// MARK: - Fix 1: Enhanced WinampMainWindow State Management

extension WinampMainWindow {
    
    /// FIXED: Comprehensive state cleanup method
    private func cleanupViewState() {
        print("🧹 Cleaning up WinampMainWindow state...")
        
        // Clear animation state sets
        sliderGlows.removeAll()
        buttonHovers.removeAll()
        
        // Reset scroll state
        scrollOffset = 0
        
        // Reset interaction state
        isScrubbing = false
        wasPlayingPreScrub = false
        scrubbingProgress = 0.0
        
        // Reset display state
        showRemainingTime = false
        displayedTime = 0
        
        // Clear pause blink state
        pauseBlinkVisible = true
        
        print("✅ WinampMainWindow state cleaned up")
    }
    
    /// ENHANCED: Safe timer cleanup with state reset
    private func cleanupTimersAndState() {
        // Invalidate all timers
        scrollTimer?.invalidate()
        scrollTimer = nil
        pauseBlinkTimer?.invalidate()
        pauseBlinkTimer = nil
        
        // Reset timer-related state
        scrollOffset = 0
        pauseBlinkVisible = true
        
        print("⏰ Timers cleaned up")
    }
    
    /// ENHANCED: State reset for track changes
    private func resetTrackRelatedState() {
        // Reset scrolling when track changes
        scrollOffset = 0
        resetScrolling()
        
        // Clear any accumulated interaction state
        sliderGlows.removeAll()
        buttonHovers.removeAll()
        
        print("🎵 Track-related state reset")
    }
    
    /// FIXED: Improved onDisappear with comprehensive cleanup
    private func setupViewLifecycle() {
        .onDisappear {
            cleanupViewState()
            cleanupTimersAndState()
        }
        .onChange(of: audioPlayer.currentTitle) { _, _ in
            resetTrackRelatedState()
        }
    }
    
    /// ENHANCED: Safe slider glow management with size limits
    private func triggerSliderGlowSafe(index: Int) {
        // Prevent unlimited growth of sliderGlows set
        if sliderGlows.count >= 20 {
            // Remove oldest glows to prevent memory growth
            let sortedGlows = sliderGlows.sorted()
            let toRemove = sortedGlows.prefix(10)
            sliderGlows.subtract(toRemove)
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            sliderGlows.insert(index)
        }
        
        // Auto-remove after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                sliderGlows.remove(index)
            }
        }
    }
    
    /// ENHANCED: Safe button hover management with size limits
    private func setButtonHover(_ buttonId: String, hovering: Bool) {
        // Prevent unlimited growth of buttonHovers set
        if buttonHovers.count >= 10 {
            // Clear old hover states
            buttonHovers.removeAll()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if hovering {
                buttonHovers.insert(buttonId)
            } else {
                buttonHovers.remove(buttonId)
            }
        }
    }
}

// MARK: - Fix 2: EqualizerWindowView State Management

extension EqualizerWindowView {
    
    /// FIXED: Comprehensive state cleanup for equalizer
    private func cleanupEqualizerState() {
        print("🧹 Cleaning up EqualizerWindowView state...")
        
        // Clear animation state
        sliderGlows.removeAll()
        buttonHovers.removeAll()
        eqVisualization.removeAll()
        
        // Reset animation flags
        graphPulse = false
        preampGlow = false
        
        // Cleanup visualization timer
        visualizationTimer?.invalidate()
        visualizationTimer = nil
        
        print("✅ EqualizerWindowView state cleaned up")
    }
    
    /// ENHANCED: Safe slider glow management
    private func triggerSliderGlowSafe(index: Int) {
        // Limit slider glows to prevent memory growth
        if sliderGlows.count >= 10 {
            sliderGlows.removeAll()
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            sliderGlows.insert(index)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                sliderGlows.remove(index)
            }
        }
    }
    
    /// ENHANCED: Safe button hover management
    private func setButtonHoverSafe(_ buttonId: String, hovering: Bool) {
        // Limit button hovers to prevent memory growth
        if buttonHovers.count >= 5 {
            buttonHovers.removeAll()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if hovering {
                buttonHovers.insert(buttonId)
            } else {
                buttonHovers.remove(buttonId)
            }
        }
    }
    
    /// FIXED: Enhanced view lifecycle
    private func setupEqualizerLifecycle() {
        .onDisappear {
            cleanupEqualizerState()
        }
        .onChange(of: audioPlayer.currentTrack) { _, _ in
            // Reset visualization when track changes
            eqVisualization = Array(repeating: 0.0, count: 10)
        }
    }
}

// MARK: - Fix 3: UnifiedDockView State Management

extension UnifiedDockView {
    
    /// FIXED: Cleanup animation state
    private func cleanupDockState() {
        print("🧹 Cleaning up UnifiedDockView state...")
        
        // Reset animation state
        dockGlow = 1.0
        materialShimmer = false
        
        print("✅ UnifiedDockView state cleaned up")
    }
    
    /// ENHANCED: Safe animation management
    private func startDockAnimationsSafe() {
        // Cancel existing animations first
        withAnimation(.easeOut(duration: 0.1)) {
            dockGlow = 1.0
            materialShimmer = false
        }
        
        // Start new animations based on settings
        if settings.materialIntegration == .modern {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                dockGlow = 1.005
            }
        } else {
            dockGlow = 1.0
        }
        
        if settings.enableLiquidGlass && 
           (settings.materialIntegration == .hybrid || settings.materialIntegration == .modern) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                materialShimmer = true
            }
        } else {
            materialShimmer = false
        }
    }
    
    /// FIXED: Enhanced view lifecycle
    private func setupDockLifecycle() {
        .onDisappear {
            cleanupDockState()
        }
        .onChange(of: settings.materialIntegration) { _, _ in
            startDockAnimationsSafe()
        }
        .onChange(of: settings.enableLiquidGlass) { _, _ in
            startDockAnimationsSafe()
        }
    }
}

// MARK: - Fix 4: Generic State Management Utilities

/// Utility for managing state with automatic cleanup
@propertyWrapper
struct CleanupState<T: Hashable> {
    @State private var value: T
    @State private var lastCleanup = Date()
    private let maxAge: TimeInterval
    private let maxSize: Int
    
    init(wrappedValue: T, maxAge: TimeInterval = 300, maxSize: Int = 100) {
        self._value = State(wrappedValue: wrappedValue)
        self.maxAge = maxAge
        self.maxSize = maxSize
    }
    
    var wrappedValue: T {
        get { value }
        set { 
            value = newValue
            checkCleanup()
        }
    }
    
    private func checkCleanup() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > maxAge {
            // Trigger cleanup based on type
            if var set = value as? Set<AnyHashable> {
                if set.count > maxSize {
                    // Remove oldest items (simplified)
                    let array = Array(set)
                    let toKeep = Set(array.suffix(maxSize))
                    value = toKeep as! T
                }
            }
            lastCleanup = now
        }
    }
}

/// Utility for managing timer-based state
@propertyWrapper
struct TimerState<T> {
    @State private var value: T
    @State private var timer: Timer?
    private let resetInterval: TimeInterval
    private let resetValue: T
    
    init(wrappedValue: T, resetInterval: TimeInterval = 60, resetValue: T) {
        self._value = State(wrappedValue: wrappedValue)
        self.resetInterval = resetInterval
        self.resetValue = resetValue
    }
    
    var wrappedValue: T {
        get { value }
        set { 
            value = newValue
            scheduleReset()
        }
    }
    
    private func scheduleReset() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: resetInterval, repeats: false) { _ in
            self.value = self.resetValue
        }
    }
}

// MARK: - Fix 5: Memory-Efficient Animation State

/// Manages animation state with memory limits
class AnimationStateManager: ObservableObject {
    @Published private var activeAnimations: [String: AnimationState] = [:]
    private let maxAnimations: Int
    
    private struct AnimationState {
        let startTime: Date
        let duration: TimeInterval
        var isCompleted: Bool = false
    }
    
    init(maxAnimations: Int = 20) {
        self.maxAnimations = maxAnimations
    }
    
    /// Start an animation with automatic cleanup
    func startAnimation(id: String, duration: TimeInterval) {
        // Remove completed animations
        cleanupCompletedAnimations()
        
        // Limit total animations
        if activeAnimations.count >= maxAnimations {
            removeOldestAnimation()
        }
        
        activeAnimations[id] = AnimationState(
            startTime: Date(),
            duration: duration
        )
    }
    
    /// Check if animation is active
    func isAnimationActive(id: String) -> Bool {
        guard let state = activeAnimations[id] else { return false }
        
        let elapsed = Date().timeIntervalSince(state.startTime)
        return elapsed < state.duration && !state.isCompleted
    }
    
    /// Complete an animation
    func completeAnimation(id: String) {
        activeAnimations[id]?.isCompleted = true
    }
    
    /// Clean up all animations
    func cleanupAllAnimations() {
        activeAnimations.removeAll()
    }
    
    private func cleanupCompletedAnimations() {
        activeAnimations = activeAnimations.filter { !$0.value.isCompleted }
    }
    
    private func removeOldestAnimation() {
        guard let oldestId = activeAnimations.min(by: { $0.value.startTime < $1.value.startTime })?.key else { return }
        activeAnimations.removeValue(forKey: oldestId)
    }
    
    /// Get animation statistics
    var statistics: String {
        return "Active Animations: \(activeAnimations.count)/\(maxAnimations)"
    }
}

// MARK: - Usage Examples

/*
// In a view:
@CleanupState<Set<Int>> private var sliderGlows = []
@TimerState<Bool> private var pulseState = false

// Or using the manager:
@StateObject private var animationManager = AnimationStateManager()

// Start animation:
animationManager.startAnimation(id: "sliderGlow", duration: 0.4)

// Check if active:
if animationManager.isAnimationActive(id: "sliderGlow") {
    // Animation is running
}

// Complete animation:
animationManager.completeAnimation(id: "sliderGlow")

// Cleanup:
.onDisappear {
    animationManager.cleanupAllAnimations()
}
*/

// MARK: - Debug Helper

extension View {
    
    /// Debug modifier to track state changes
    func debugState(_ name: String) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .init("StateChange"))) { _ in
            print("🔄 State changed in \(name)")
        }
    }
    
    /// Debug modifier to track memory usage
    func debugMemory(_ name: String) -> some View {
        self.onAppear {
            print("💾 \(name) appeared")
        }
        .onDisappear {
            print("🗑️ \(name) disappeared")
        }
    }
}