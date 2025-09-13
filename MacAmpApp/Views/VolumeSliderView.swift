import SwiftUI
import AppKit

struct VolumeSliderView: View {
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // 0.0 to 1.0

    // Winamp volume slider is horizontal: 68x13 pixels
    let sliderWidth: CGFloat = 68
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
                            let normalizedX = newX / sliderWidth
                            self.value = Float(max(0.0, min(1.0, normalizedX)))
                        }
                )
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }

    private func calculateThumbOffset(_ containerWidth: CGFloat) -> CGFloat {
        // The actual input width is 65px (3px shorter than background)
        let inputWidth: CGFloat = 65
        let trackWidth = inputWidth - thumbWidth
        let offset = trackWidth * CGFloat(value)
        return offset
    }

    // Calculate color based on volume (green -> yellow -> orange -> red)
    private var sliderColor: Color {
        let normalizedValue = value

        if normalizedValue <= 0.25 {
            // Pure green at low volume
            return Color(red: 0, green: 0.8, blue: 0)
        } else if normalizedValue <= 0.5 {
            // Green to Yellow (25% to 50%)
            let t = (normalizedValue - 0.25) * 4
            return Color(
                red: Double(t * 0.9),
                green: 0.8,
                blue: 0
            )
        } else if normalizedValue <= 0.75 {
            // Yellow to Orange (50% to 75%)
            let t = (normalizedValue - 0.5) * 4
            return Color(
                red: 0.9,
                green: Double(0.8 - t * 0.3),
                blue: 0
            )
        } else {
            // Orange to Red (75% to 100%)
            let t = (normalizedValue - 0.75) * 4
            return Color(
                red: Double(0.9 + t * 0.1),
                green: Double(0.5 - t * 0.5),
                blue: 0
            )
        }
    }
}