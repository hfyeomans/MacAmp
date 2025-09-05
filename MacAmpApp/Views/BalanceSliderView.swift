
import SwiftUI
import AppKit

struct BalanceSliderView: View {
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // -1.0 (left) to 1.0 (right)

    // Winamp balance track is 38x14
    let sliderWidth: CGFloat = 38
    let thumbWidth: CGFloat = 14

    var body: some View {
        GeometryReader {
            geometry in
            ZStack(alignment: .leading) {
                Image(nsImage: background)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                Image(nsImage: thumb)
                    .resizable()
                    .frame(width: thumb.size.width, height: thumb.size.height)
                    .offset(x: calculateThumbOffset(geometry.size.width))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newX = gesture.location.x
                                // Normalize X from 0 to 1, then map to -1 to 1
                                let normalizedX = (newX / geometry.size.width)
                                self.value = Float(max(-1.0, min(1.0, (normalizedX * 2.0) - 1.0)))
                            }
                    )
            }
        }
        .frame(width: sliderWidth, height: 14)
    }

    private func calculateThumbOffset(_ containerWidth: CGFloat) -> CGFloat {
        let trackWidth = containerWidth - thumbWidth
        // Map value from -1 to 1 to 0 to 1, then apply to trackWidth
        let normalizedValue = (CGFloat(value) + 1.0) / 2.0
        let offset = trackWidth * normalizedValue
        return offset
    }
}
