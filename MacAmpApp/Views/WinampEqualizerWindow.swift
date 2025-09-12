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
            // Background - The EQMAIN sprite includes preamp text and frequency labels
            SimpleSpriteImage("EQ_WINDOW_BACKGROUND", 
                            width: WinampSizes.equalizer.width, 
                            height: WinampSizes.equalizer.height)
            
            // Title bar with "Winamp Equalizer" text
            SimpleSpriteImage("EQ_TITLE_BAR_SELECTED",
                            width: 275,
                            height: 14)
                .at(CGPoint(x: 0, y: 0))
            
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
            value: Binding(
                get: { audioPlayer.preamp },
                set: { audioPlayer.setPreamp(value: $0) }  // Call setPreamp to affect audio
            ),
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
            // Groove overlay - transparent to show background through
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: width - 3, height: height)
                .offset(x: 1.5, y: 0)
            
            // Colored channel (6px wide)
            Rectangle()
                .fill(sliderColor)
                .frame(width: 6, height: height - 4)  // 6px wide channel
                .offset(x: 4, y: 2)  // Center the channel
            
            // Center line at 0dB (thin dark line for reference)
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: width - 4, height: 1)
                .offset(x: 2, y: height / 2)
            
            // Slider thumb sprite (11x11 pixels) 
            SimpleSpriteImage(isDragging ? "EQ_SLIDER_THUMB_SELECTED" : "EQ_SLIDER_THUMB", 
                            width: 11, height: 11)
                .offset(x: 1.5, y: thumbPosition) // Position based on webamp formula
            
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
    
    // Solid color that changes based on slider position
    private var sliderColor: Color {
        // Map value to color: green (-12) -> yellow (0) -> red (+12)
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        if normalizedValue <= 0.5 {
            // Green to Yellow (bottom to center)
            let t = normalizedValue * 2 // 0 to 1 for this half
            return Color(
                red: Double(t * 0.9),      // 0 -> 0.9
                green: Double(0.8),         // Stay high
                blue: 0
            )
        } else {
            // Yellow to Red (center to top)
            let t = (normalizedValue - 0.5) * 2 // 0 to 1 for this half
            return Color(
                red: Double(0.9 + t * 0.1), // 0.9 -> 1.0
                green: Double(0.8 * (1 - t)), // 0.8 -> 0
                blue: 0
            )
        }
    }
    
    
    private var thumbPosition: CGFloat {
        // Position the thumb sprite based on value using webamp's formula
        let thumbSize: CGFloat = 11 // Actual thumb sprite height
        let trackHeight = height - thumbSize
        
        // Normalize value from range to 0-1
        // At -12dB: normalizedValue = 0 (bottom)
        // At 0dB: normalizedValue = 0.5 (center)  
        // At +12dB: normalizedValue = 1 (top)
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        // Use webamp's formula: offset = floor((height - handleHeight) * value)
        // But inverted since our coordinate system has 0 at top
        return floor(trackHeight * (1.0 - CGFloat(normalizedValue)))
    }
    
    private func updateValue(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let gestureHeight = geometry.size.height
        let y = min(max(0, gesture.location.y), gestureHeight)
        
        // Invert Y coordinate (top = high value, bottom = low value)
        let normalizedPosition = 1.0 - Float(y / gestureHeight)
        var newValue = range.lowerBound + (normalizedPosition * (range.upperBound - range.lowerBound))
        
        // Center snapping: if within ±0.5dB of center (0), snap to exactly 0
        let snapThreshold: Float = 0.5
        if abs(newValue) < snapThreshold {
            newValue = 0
        }
        
        value = max(range.lowerBound, min(range.upperBound, newValue))
    }
}

#Preview {
    WinampEqualizerWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
}