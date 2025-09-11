
import SwiftUI
import AppKit

struct EQSliderView: View {
    @EnvironmentObject var skinManager: SkinManager
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // Typically -12.0 to 12.0 dB
    let range: ClosedRange<Float>
    @State private var isDragging: Bool = false

    // Winamp EQ slider dimensions
    let sliderWidth: CGFloat = 14  // Correct Winamp spec
    let sliderHeight: CGFloat = 62 // Correct Winamp spec
    let thumbHeight: CGFloat = 2   // Thin white line

    var body: some View {
        ZStack(alignment: .top) {
            // Groove overlay - dark channel
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: sliderWidth - 3, height: sliderHeight)
                .offset(x: 1.5, y: 0)
            
            // Colored channel (6px wide)
            Rectangle()
                .fill(sliderColor)
                .frame(width: 6, height: sliderHeight - 4)  // 6px wide channel
                .offset(x: 4, y: 2)  // Center the channel
            
            // Center line at 0dB reference
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: sliderWidth - 4, height: 1)
                .offset(x: 2, y: sliderHeight / 2)
            
            // Slider thumb sprite (11x11 pixels)
            if let thumbImage = skinManager.currentSkin?.images[isDragging ? "EQ_SLIDER_THUMB_SELECTED" : "EQ_SLIDER_THUMB"] {
                Image(nsImage: thumbImage)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .frame(width: 11, height: 11)
                    .offset(x: 1.5, y: calculateThumbOffset(sliderHeight)) // Properly centered
            }
            
            // Invisible interaction area
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let newY = gesture.location.y
                                // Normalize Y from 0 to 1, then map to the given range
                                let normalizedY: Float = Float(1.0 - (newY / geo.size.height))
                                var newValue: Float = range.lowerBound + (range.upperBound - range.lowerBound) * normalizedY
                                
                                // Center snapping: if within ±1dB of center (0), snap to exactly 0
                                let snapThreshold: Float = 1.0
                                if abs(newValue) < snapThreshold {
                                    newValue = 0
                                }
                                
                                self.value = min(max(newValue, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(width: sliderWidth, height: sliderHeight)
        }
        .frame(width: sliderWidth, height: sliderHeight)
        .clipped() // Prevent any overflow
    }

    private func calculateThumbOffset(_ containerHeight: CGFloat) -> CGFloat {
        let thumbSize: CGFloat = 11 // Actual thumb sprite height
        let trackHeight = containerHeight - thumbSize
        // Map value from range to 0 to 1, then apply to trackHeight
        let normalizedValue = (CGFloat(value) - CGFloat(range.lowerBound)) / (CGFloat(range.upperBound) - CGFloat(range.lowerBound))
        let offset = trackHeight * (1.0 - normalizedValue)
        
        // When at 0dB (center), ensure thumb is centered on the middle line
        // The middle line is at containerHeight / 2
        if abs(value) < 0.01 {
            return (containerHeight / 2) - (thumbSize / 2)
        }
        
        return offset
    }
    
    // Gradient color that changes based on slider position (green->yellow->red)
    private var sliderColor: Color {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        if normalizedValue <= 0.5 {
            // Green to Yellow (bottom to center)
            let t = normalizedValue * 2
            return Color(
                red: Double(t * 0.9),
                green: Double(0.8),
                blue: 0
            )
        } else {
            // Yellow to Red (center to top)
            let t = (normalizedValue - 0.5) * 2
            return Color(
                red: Double(0.9 + t * 0.1),
                green: Double(0.8 * (1 - t)),
                blue: 0
            )
        }
    }
}
