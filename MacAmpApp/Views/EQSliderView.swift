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

    // EQ_SLIDER_BACKGROUND from EQMAIN.bmp is 209x129px
    // This contains 19 vertical sliders (11 bands + preamp) laid out horizontally
    // Each individual slider column is 14px wide
    // The full height shows all possible positions (129px contains multiple frames)
    let backgroundFullWidth: CGFloat = 209
    let backgroundFullHeight: CGFloat = 129

    var body: some View {
        ZStack(alignment: .top) {
            // Use actual EQ_SLIDER_BACKGROUND from skin
            // For vertical EQ sliders, the background shifts vertically based on value
            Image(nsImage: background)
                .resizable()
                .interpolation(.none)
                .frame(width: sliderWidth, height: backgroundFullHeight)
                .offset(y: calculateBackgroundOffset())
                .frame(width: sliderWidth, height: sliderHeight)
                .clipped()

            // Slider thumb sprite (11x11 pixels)
            if let thumbImage = skinManager.currentSkin?.images[isDragging ? "EQ_SLIDER_THUMB_SELECTED" : "EQ_SLIDER_THUMB"] {
                Image(nsImage: thumbImage)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .frame(width: 11, height: 11)
                    .offset(x: 1.5, y: calculateThumbOffset(sliderHeight))
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

                                // Center snapping: if within ±0.5dB of center (0), snap to exactly 0
                                let snapThreshold: Float = 0.5
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
        .clipped()
    }

    private func calculateThumbOffset(_ containerHeight: CGFloat) -> CGFloat {
        let thumbSize: CGFloat = 11
        let trackHeight = containerHeight - thumbSize

        // Map value from range to 0 to 1 (normalized from -12 to +12)
        let normalizedValue = (CGFloat(value) - CGFloat(range.lowerBound)) / (CGFloat(range.upperBound) - CGFloat(range.lowerBound))

        // Invert since our coordinate system has 0 at top
        let offset = floor(trackHeight * (1.0 - normalizedValue))

        return offset
    }

    private func calculateBackgroundOffset() -> CGFloat {
        // Map value from range to 0 to 1
        let normalizedValue = (CGFloat(value) - CGFloat(range.lowerBound)) / (CGFloat(range.upperBound) - CGFloat(range.lowerBound))

        // The EQ slider background is 129px tall and represents all possible positions
        // We need to shift the background to show the appropriate section
        // Similar to volume/balance but for vertical orientation
        let totalBackgroundRange = backgroundFullHeight - sliderHeight
        let yOffset = -(totalBackgroundRange * (1.0 - normalizedValue))

        return yOffset
    }
}
