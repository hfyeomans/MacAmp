import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's equalizer window using absolute positioning
struct WinampEqualizerWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    // Winamp EQ coordinate constants (CORRECTED from webamp reference)
    private struct EQCoords {
        // Preamp slider (leftmost) - CORRECTED
        static let preampSlider = CGPoint(x: 21, y: 38)
        
        // 10-band EQ sliders - CORRECTED positions from webamp  
        static let eqSliderPositions: [CGFloat] = [78, 96, 114, 132, 150, 168, 186, 204, 222, 240]
        static let eqSliderY: CGFloat = 38
        
        // ON/AUTO buttons - CORRECTED
        static let onButton = CGPoint(x: 14, y: 18)
        static let autoButton = CGPoint(x: 40, y: 18)  // Adjusted spacing
        
        // Presets button - CORRECTED
        static let presetsButton = CGPoint(x: 217, y: 18)
        
        // Titlebar buttons (same as main window)
        static let minimizeButton = CGPoint(x: 244, y: 3)
        static let shadeButton = CGPoint(x: 254, y: 3) 
        static let closeButton = CGPoint(x: 264, y: 3)
        
        // EQ curve graph area - CORRECTED
        static let graphArea = CGPoint(x: 86, y: 17)
    }
    
    // EQ slider specs - CORRECTED to match webamp exactly
    private let sliderWidth: CGFloat = 14  // CORRECTED: Each slider is 14px wide
    private let sliderHeight: CGFloat = 62  // CORRECTED: 62px active area (not 63)
    private let thumbWidth: CGFloat = 11
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            SimpleSpriteImage("EQ_WINDOW_BACKGROUND", 
                            width: WinampSizes.equalizer.width, 
                            height: WinampSizes.equalizer.height)
            
            // Build all EQ components
            Group {
                // Titlebar buttons
                buildTitlebarButtons()
                
                // ON/AUTO buttons
                buildControlButtons()
                
                // Preamp slider
                buildPreampSlider()
                
                // 10-band EQ sliders
                buildEQSliders()
                
                // Presets button
                buildPresetsButton()
                
                // EQ curve visualization (simplified for now)
                buildEQCurve()
            }
        }
        .frame(width: WinampSizes.equalizer.width, height: WinampSizes.equalizer.height)
        .background(Color.black) // Fallback
    }
    
    @ViewBuilder
    private func buildTitlebarButtons() -> some View {
        Group {
            // Minimize button
            Button(action: {
                NSApp.keyWindow?.miniaturize(nil)
            }) {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.minimizeButton)
            
            // Shade button
            Button(action: {
                // TODO: Implement EQ shade mode
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.shadeButton)
            
            // Close button
            Button(action: {
                NSApp.keyWindow?.close()
            }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.closeButton)
        }
    }
    
    @ViewBuilder
    private func buildControlButtons() -> some View {
        Group {
            // ON button
            Button(action: {
                audioPlayer.toggleEq(isOn: !audioPlayer.isEqOn)
            }) {
                let spriteKey = audioPlayer.isEqOn ? "EQ_ON_BUTTON_SELECTED" : "EQ_ON_BUTTON"
                SimpleSpriteImage(spriteKey, width: 26, height: 12)
            }
            .buttonStyle(.plain)
            .at(EQCoords.onButton)
            
            // AUTO button
            Button(action: {
                audioPlayer.eqAutoEnabled.toggle()
            }) {
                let spriteKey = audioPlayer.eqAutoEnabled ? "EQ_AUTO_BUTTON_SELECTED" : "EQ_AUTO_BUTTON"
                SimpleSpriteImage(spriteKey, width: 32, height: 12)
            }
            .buttonStyle(.plain)
            .at(EQCoords.autoButton)
        }
    }
    
    @ViewBuilder
    private func buildPreampSlider() -> some View {
        WinampVerticalSlider(
            value: $audioPlayer.preamp,
            range: -12.0...12.0,
            width: sliderWidth,   // 14px exactly
            height: sliderHeight, // 62px exactly  
            thumbHeight: thumbHeight,
            backgroundSprite: "EQ_SLIDER_BACKGROUND",
            thumbSprite: "EQ_SLIDER_THUMB",
            thumbActiveSprite: "EQ_SLIDER_THUMB_SELECTED"
        )
        .at(EQCoords.preampSlider) // x: 21, y: 38 (exact webamp position)
    }
    
    @ViewBuilder
    private func buildEQSliders() -> some View {
        // 10 EQ band sliders using EXACT webamp positions
        ForEach(0..<10, id: \.self) { bandIndex in
            WinampVerticalSlider(
                value: Binding(
                    get: { audioPlayer.eqBands[bandIndex] },
                    set: { audioPlayer.setEqBand(index: bandIndex, value: $0) }
                ),
                range: -12.0...12.0,
                width: sliderWidth,
                height: sliderHeight,
                thumbHeight: thumbHeight,
                backgroundSprite: "EQ_SLIDER_BACKGROUND",
                thumbSprite: "EQ_SLIDER_THUMB",
                thumbActiveSprite: "EQ_SLIDER_THUMB_SELECTED"
            )
            .at(CGPoint(
                x: EQCoords.eqSliderPositions[bandIndex], // Use exact positions from webamp
                y: EQCoords.eqSliderY
            ))
        }
    }
    
    @ViewBuilder
    private func buildPresetsButton() -> some View {
        Button(action: {
            // TODO: Open presets menu
        }) {
            SimpleSpriteImage("EQ_PRESETS_BUTTON", width: 44, height: 12)
        }
        .buttonStyle(.plain)
        .at(EQCoords.presetsButton)
    }
    
    @ViewBuilder
    private func buildEQCurve() -> some View {
        // Simplified EQ curve visualization
        SimpleSpriteImage("EQ_GRAPH_BACKGROUND", width: 113, height: 19)
            .at(EQCoords.graphArea)
            .overlay(
                // Draw EQ curve based on band values
                Path { path in
                    let graphWidth: CGFloat = 113
                    let graphHeight: CGFloat = 19
                    let bands = audioPlayer.eqBands
                    
                    if !bands.isEmpty {
                        let stepX = graphWidth / CGFloat(bands.count - 1)
                        let centerY = graphHeight / 2
                        
                        for (index, gain) in bands.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedGain = CGFloat(gain) / 24.0 // -12..12 to -0.5..0.5
                            let y = centerY - (normalizedGain * centerY)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                }
                .stroke(Color.green, lineWidth: 1)
                .at(EQCoords.graphArea)
            )
    }
}

/// Vertical slider component for EQ bands
struct WinampVerticalSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let width: CGFloat
    let height: CGFloat
    let thumbHeight: CGFloat
    let backgroundSprite: String
    let thumbSprite: String
    let thumbActiveSprite: String
    
    @State private var isDragging = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // CONSTRAINED: Temporary simple background to avoid sprite overflow  
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: width, height: height) // EXACTLY 14×62px
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
            
            // Visual fill to show EQ level (like volume slider)
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.yellow, Color.orange],
                    startPoint: .bottom,
                    endPoint: .top
                ))
                .frame(width: width - 2, height: sliderFillHeight)
                .offset(x: 1, y: height - sliderFillHeight - 1)
            
            // Center line at 0dB
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: width - 4, height: 1)
                .offset(x: 2, y: height / 2)
            
            // Small thumb indicator
            Rectangle()
                .fill(isDragging ? Color.white : Color.gray)
                .frame(width: width - 2, height: 3)
                .offset(x: 1, y: thumbPosition)
            
            // Invisible interaction area - EXACTLY constrained
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(from: gesture, in: geo)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(width: width, height: height) // FORCE exact constraint
        }
        .frame(width: width, height: height) // DOUBLE ensure constraints
        .clipped() // CRITICAL: Clip any overflow
    }
    
    // Calculate visual fill height based on EQ value
    private var sliderFillHeight: CGFloat {
        if value >= 0 {
            // Positive gain - fill from center upward
            let normalizedValue = CGFloat(value) / CGFloat(range.upperBound)
            return normalizedValue * (height / 2)
        } else {
            // Negative gain - fill from center downward  
            let normalizedValue = CGFloat(abs(value)) / CGFloat(abs(range.lowerBound))
            return normalizedValue * (height / 2)
        }
    }
    
    private var thumbPosition: CGFloat {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let maxOffset = height - thumbHeight
        // Invert Y because slider moves from top (high) to bottom (low)
        return maxOffset * CGFloat(1.0 - normalizedValue)
    }
    
    private func updateValue(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let gestureHeight = geometry.size.height
        let y = min(max(0, gesture.location.y), gestureHeight)
        
        // Invert Y coordinate (top = high value, bottom = low value)
        let normalizedPosition = 1.0 - Float(y / gestureHeight)
        let newValue = range.lowerBound + (normalizedPosition * (range.upperBound - range.lowerBound))
        
        value = max(range.lowerBound, min(range.upperBound, newValue))
    }
}

#Preview {
    WinampEqualizerWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
}