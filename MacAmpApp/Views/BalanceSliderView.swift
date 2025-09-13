import SwiftUI
import AppKit

struct BalanceSliderView: View {
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // -1.0 (left) to 1.0 (right)

    // Winamp balance slider is horizontal: 38x13 pixels
    let sliderWidth: CGFloat = 38
    let sliderHeight: CGFloat = 13
    let thumbWidth: CGFloat = 14
    let thumbHeight: CGFloat = 11
    let channelHeight: CGFloat = 6  // Height of the colored channel

    var body: some View {
        ZStack(alignment: .leading) {
            // Dark groove background with rounded ends
            RoundedRectangle(cornerRadius: channelHeight / 2)
                .fill(Color.black.opacity(0.3))
                .frame(width: sliderWidth, height: channelHeight)
                .offset(y: (sliderHeight - channelHeight) / 2)

            // Colored channel with rounded ends (solid color that changes)
            RoundedRectangle(cornerRadius: channelHeight / 2)
                .fill(sliderColor)
                .frame(width: sliderWidth, height: channelHeight - 2)  // Slightly smaller than groove
                .offset(y: (sliderHeight - channelHeight + 2) / 2)

            // Center notch indicator (visual reference for center position)
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 1, height: channelHeight)
                .offset(x: sliderWidth / 2 - 0.5, y: (sliderHeight - channelHeight) / 2)

            // Draw the thumb slider
            Image(nsImage: thumb)
                .resizable()
                .interpolation(.none)
                .frame(width: thumbWidth, height: thumbHeight)
                .offset(x: calculateThumbOffset(sliderWidth), y: 1)  // y:1 to center vertically

            // Invisible interaction area
            Color.clear
                .contentShape(Rectangle())
                .frame(width: sliderWidth, height: sliderHeight)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newX = gesture.location.x
                            // Normalize X from 0 to 1, then map to -1 to 1
                            let normalizedX = (newX / sliderWidth)
                            self.value = Float(max(-1.0, min(1.0, (normalizedX * 2.0) - 1.0)))
                        }
                )
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }

    private func calculateThumbOffset(_ containerWidth: CGFloat) -> CGFloat {
        let trackWidth = containerWidth - thumbWidth
        // Map value from -1 to 1 to 0 to 1, then apply to trackWidth
        let normalizedValue = (CGFloat(value) + 1.0) / 2.0
        let offset = trackWidth * normalizedValue
        return offset
    }

    // Calculate color based on balance distance from center
    // Green at center (0), transitions to red as it moves away
    private var sliderColor: Color {
        let absValue = abs(value)

        if absValue <= 0.25 {
            // Pure green at center
            return Color(red: 0, green: 0.8, blue: 0)
        } else if absValue <= 0.5 {
            // Green to Yellow (25% to 50% off-center)
            let t = (absValue - 0.25) * 4
            return Color(
                red: Double(t * 0.9),
                green: 0.8,
                blue: 0
            )
        } else if absValue <= 0.75 {
            // Yellow to Orange (50% to 75% off-center)
            let t = (absValue - 0.5) * 4
            return Color(
                red: 0.9,
                green: Double(0.8 - t * 0.3),
                blue: 0
            )
        } else {
            // Orange to Red (75% to 100% off-center)
            let t = (absValue - 0.75) * 4
            return Color(
                red: Double(0.9 + t * 0.1),
                green: Double(0.5 - t * 0.5),
                blue: 0
            )
        }
    }
}