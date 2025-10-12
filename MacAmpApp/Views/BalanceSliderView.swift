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

    // BALANCE.BMP is 38x420px with 28 frames (each 15px tall)
    let backgroundFullHeight: CGFloat = 420
    let frameHeight: CGFloat = 15
    let frameCount: CGFloat = 28

    var body: some View {
        ZStack(alignment: .leading) {
            // Use actual BALANCE.BMP background with frame-based positioning
            // Following webamp's approach: calculate which frame to show based on balance
            Image(nsImage: background)
                .resizable()
                .interpolation(.none)
                .frame(width: sliderWidth, height: backgroundFullHeight)
                .offset(y: calculateBackgroundOffset())
                .frame(width: sliderWidth, height: sliderHeight)
                .clipped()

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

    private func calculateBackgroundOffset() -> CGFloat {
        // Balance uses same frame-based approach as volume
        // Map value from -1..1 to 0..1 for frame calculation
        let normalizedValue = (CGFloat(value) + 1.0) / 2.0
        let frameIndex = floor(normalizedValue * (frameCount - 1))
        let yOffset = -(frameIndex * frameHeight)
        return yOffset
    }
}