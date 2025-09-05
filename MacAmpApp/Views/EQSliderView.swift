
import SwiftUI
import AppKit

struct EQSliderView: View {
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // Typically -12.0 to 12.0 dB
    let range: ClosedRange<Float>

    // Constants for slider dimensions (based on original skin, adjust as needed)
    let sliderHeight: CGFloat = 100 // Example height, will need to be precise
    let thumbHeight: CGFloat = 11

    var body: some View {
        GeometryReader {
            geometry in
            ZStack(alignment: .top) {
                Image(nsImage: background)
                    .resizable()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Image(nsImage: thumb)
                    .resizable()
                    .frame(width: thumb.size.width, height: thumb.size.height)
                    .offset(y: calculateThumbOffset(geometry.size.height))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newY = gesture.location.y
                                // Normalize Y from 0 to 1, then map to the given range
                                let normalizedY: Float = Float(1.0 - (newY / geometry.size.height))
                                let newValue: Float = range.lowerBound + (range.upperBound - range.lowerBound) * normalizedY
                                self.value = min(max(newValue, range.lowerBound), range.upperBound)
                            }
                    )
            }
        }
        .frame(width: background.size.width, height: sliderHeight) // Set container size based on original image
    }

    private func calculateThumbOffset(_ containerHeight: CGFloat) -> CGFloat {
        let trackHeight = containerHeight - thumbHeight
        // Map value from range to 0 to 1, then apply to trackHeight
        let normalizedValue = (CGFloat(value) - CGFloat(range.lowerBound)) / (CGFloat(range.upperBound) - CGFloat(range.lowerBound))
        let offset = trackHeight * (1.0 - normalizedValue)
        return offset
    }
}
