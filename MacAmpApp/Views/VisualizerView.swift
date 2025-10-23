import SwiftUI
import Accelerate

/// Winamp-style spectrum analyzer visualization
struct VisualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var skinManager: SkinManager
    
    // Animation state
    @State private var barHeights: [CGFloat] = Array(repeating: 0, count: 19)
    @State private var peakPositions: [CGFloat] = Array(repeating: 0, count: 19)
    @State private var peakTimers: [Date] = Array(repeating: Date.distantPast, count: 19)
    @State private var updateTimer: Timer?
    
    // Winamp spectrum analyzer constants
    private let barCount = 19
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 1
    private let maxHeight: CGFloat = 16
    
    // Animation timing
    private let updateInterval: TimeInterval = 1.0/30.0  // 30 FPS for classic feel
    private let decayRate: CGFloat = 0.92  // Slower decay for more visible bars
    private let peakHoldTime: TimeInterval = 0.5
    private let peakDecayRate: CGFloat = 0.95
    
    // Sensitivity adjustment
    private let amplificationFactor: CGFloat = 1.5  // Boost signal for better visibility
    private let minBarHeight: CGFloat = 1.0  // Minimum visible height when playing
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                SpectrumBar(
                    height: barHeights[index],
                    peakPosition: peakPositions[index],
                    maxHeight: maxHeight
                )
                .frame(width: barWidth, height: maxHeight)
            }
        }
        .background(Color.black)
        .onAppear {
            startVisualization()
        }
        .onDisappear {
            stopVisualization()
        }
        .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
            if isPlaying {
                startVisualization()
            } else {
                // Keep bars visible when paused
                updateTimer?.invalidate()
                updateTimer = nil
            }
        }
    }
    
    private func startVisualization() {
        guard audioPlayer.isPlaying else { return }
        
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            updateBars()
        }
    }
    
    private func stopVisualization() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Animate bars to zero
        withAnimation(.easeOut(duration: 0.3)) {
            barHeights = Array(repeating: 0, count: barCount)
            peakPositions = Array(repeating: 0, count: barCount)
        }
    }
    
    private func updateBars() {
        // Get frequency data from audio player
        let frequencyData = audioPlayer.getFrequencyData(bands: barCount)
        
        withAnimation(.linear(duration: updateInterval)) {
            for i in 0..<barCount {
                // Apply frequency-specific amplification
                // Higher frequencies need more boost to be visible
                let frequencyBoost: CGFloat = 1.0 + (CGFloat(i) / CGFloat(barCount)) * 0.5
                
                // Update bar height with amplified frequency data
                var targetHeight = CGFloat(frequencyData[i]) * maxHeight * amplificationFactor * frequencyBoost
                
                // Add minimum height when playing to ensure visibility
                if audioPlayer.isPlaying && frequencyData[i] > 0.01 {
                    targetHeight = max(minBarHeight, targetHeight)
                }
                
                // Clamp to max height
                targetHeight = min(maxHeight, targetHeight)
                
                // Apply smoothing for more natural movement
                barHeights[i] = max(targetHeight, barHeights[i] * decayRate)
                
                // Update peak positions
                if barHeights[i] > peakPositions[i] {
                    peakPositions[i] = barHeights[i]
                    peakTimers[i] = Date()
                } else if Date().timeIntervalSince(peakTimers[i]) > peakHoldTime {
                    // Decay peak after hold time
                    peakPositions[i] = max(0, peakPositions[i] * peakDecayRate - 0.5)
                }
            }
        }
    }
}

/// Individual spectrum analyzer bar with VISCOLOR.TXT gradient
struct SpectrumBar: View {
    let height: CGFloat
    let peakPosition: CGFloat
    let maxHeight: CGFloat

    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background (VISCOLOR color 0 = black)
                Rectangle()
                    .fill(backgroundColor)

                // Active bar with VISCOLOR gradient (colors 2-17)
                Rectangle()
                    .fill(spectrumGradient)
                    .frame(height: height)

                // Peak indicator (VISCOLOR color 23 = peak dots)
                if peakPosition > 0 {
                    Rectangle()
                        .fill(peakColor)
                        .frame(height: 1)
                        .offset(y: -peakPosition)
                }
            }
        }
    }

    /// Get VISCOLOR color by index with fallback
    private func getColor(_ index: Int, fallback: Color) -> Color {
        guard let colors = skinManager.currentSkin?.visualizerColors,
              index >= 0 && index < colors.count else {
            return fallback
        }
        return colors[index]
    }

    /// Background color from VISCOLOR (color 0 = black)
    private var backgroundColor: Color {
        getColor(0, fallback: Color.black.opacity(0.8))
    }

    /// Peak dot color from VISCOLOR (color 23 = peak dots)
    private var peakColor: Color {
        getColor(23, fallback: Color.white)
    }

    /// Spectrum gradient using VISCOLOR colors 2-17 (16-color gradient)
    /// Color 2 (red) = top of spectrum, Color 17 (green) = bottom
    private var spectrumGradient: LinearGradient {
        guard let colors = skinManager.currentSkin?.visualizerColors,
              colors.count >= 18 else {
            // Fallback to classic green/yellow/red gradient
            return defaultGradient
        }

        // Map bar height to VISCOLOR indices 2-17
        // height 0 → bottom (color 17, green)
        // height maxHeight → top (color 2, red)
        let normalizedHeight = height / maxHeight

        // Create gradient from bottom (17) to current height position
        let colorStops: [Color] = stride(from: 17, through: 2, by: -1).map { index in
            colors[index]
        }

        return LinearGradient(
            colors: colorStops,
            startPoint: .bottom,
            endPoint: .top
        )
    }

    /// Fallback gradient if VISCOLOR not available
    private var defaultGradient: LinearGradient {
        let normalizedHeight = height / maxHeight

        if normalizedHeight < 0.4 {
            return LinearGradient(
                colors: [Color(red: 0, green: 0.6, blue: 0), Color(red: 0, green: 1, blue: 0)],
                startPoint: .bottom, endPoint: .top
            )
        } else if normalizedHeight < 0.65 {
            return LinearGradient(
                colors: [Color(red: 0.8, green: 0.8, blue: 0), Color(red: 1, green: 1, blue: 0)],
                startPoint: .bottom, endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.8, green: 0, blue: 0), Color(red: 1, green: 0, blue: 0)],
                startPoint: .bottom, endPoint: .top
            )
        }
    }
}

#Preview {
    VisualizerView()
        .environmentObject(AudioPlayer())
        .environmentObject(SkinManager())
        .frame(width: 76, height: 16)
        .background(Color.gray)
}