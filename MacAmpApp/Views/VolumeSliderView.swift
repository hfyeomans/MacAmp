
import SwiftUI
import AppKit

struct VolumeSliderView: View {
    let background: NSImage
    let thumb: NSImage
    @Binding var value: Float // 0.0 to 1.0

    // Winamp volume track is 14px tall; the BMP contains many stacked frames (420px)
    let sliderHeight: CGFloat = 14
    let thumbHeight: CGFloat = 11

    var body: some View {
        GeometryReader {
            geometry in
            ZStack(alignment: .top) {
                Image(nsImage: background)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                Image(nsImage: thumb)
                    .resizable()
                    .frame(width: thumb.size.width, height: thumb.size.height)
                    .offset(y: calculateThumbOffset(geometry.size.height))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newY = gesture.location.y
                                let normalizedY = 1.0 - (newY / geometry.size.height)
                                self.value = Float(max(0.0, min(1.0, normalizedY)))
                            }
                    )
            }
        }
        .frame(width: background.size.width, height: sliderHeight)
    }

    private func calculateThumbOffset(_ containerHeight: CGFloat) -> CGFloat {
        let trackHeight = containerHeight - thumbHeight
        let offset = trackHeight * (1.0 - CGFloat(value))
        return offset
    }
}
