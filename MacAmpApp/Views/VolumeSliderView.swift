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

    // VOLUME.BMP is 68x420px with 28 frames (each 15px tall)
    let backgroundFullHeight: CGFloat = 420
    let frameHeight: CGFloat = 15
    let frameCount: CGFloat = 28

    var body: some View {
        ZStack(alignment: .leading) {
            // Use actual VOLUME.BMP background with frame-based positioning
            // Following webamp's approach: calculate which frame to show based on volume
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

    private func calculateBackgroundOffset() -> CGFloat {
        // Calculate which frame to show: frameNumber = round(volume * 28)
        // Each frame is 15px tall, so offset = -(frameNumber * 15)
        let frameIndex = floor(CGFloat(value) * (frameCount - 1))
        let yOffset = -(frameIndex * frameHeight)
        return yOffset
    }
}