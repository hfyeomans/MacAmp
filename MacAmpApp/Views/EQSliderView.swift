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
    let sliderHeight: CGFloat = 63 // Correct Winamp spec (was 62, should be 63)

    // EQ_SLIDER_BACKGROUND from EQMAIN.bmp is 209×129px
    // Contains 28 colored gradient frames in 14×2 grid layout:
    // Row 0 (frames 0-13):  Green → Yellow (left to right)
    // Row 1 (frames 14-27): Orange → Red (left to right)
    // Each frame: ~15px wide × ~65px tall
    let frameWidth: CGFloat = 15
    let frameHeight: CGFloat = 65
    let gridColumns: Int = 14
    let totalFrames: Int = 28

    var body: some View {
        ZStack(alignment: .top) {
            // Render colored gradient background from EQ_SLIDER_BACKGROUND
            // Uses 2D grid positioning (like Volume but with X+Y offsets)
            if let skin = skinManager.currentSkin,
               let eqBackground = skin.images["EQ_SLIDER_BACKGROUND"] {
                // CRITICAL: frame→offset→clip order (proven from Volume slider)
                Image(nsImage: eqBackground)
                    .interpolation(.none)
                    .frame(width: sliderWidth, height: sliderHeight, alignment: .topLeading)
                    .offset(x: calculateFrameXOffset(), y: calculateFrameYOffset())
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                // Fallback: simple gradient based on value
                Rectangle()
                    .fill(fallbackColor)
                    .frame(width: sliderWidth, height: sliderHeight)
            }

            // Thumb sprite moves over the colored gradient
            let thumbSprite = isDragging ? "EQ_SLIDER_THUMB_SELECTED" : "EQ_SLIDER_THUMB"
            SimpleSpriteImage(thumbSprite, width: 11, height: 11)
                .offset(x: 1.5, y: calculateThumbOffset(sliderHeight))
                .allowsHitTesting(false)

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

    // Calculate which frame (0-27) to display based on EQ value
    private func calculateFrameIndex() -> Int {
        // Normalize value from range (-12 to +12) to 0.0-1.0
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let percent = min(max(CGFloat(normalizedValue), 0), 1)

        // Map to frame 0-27
        let frameIndex = Int(round(percent * CGFloat(totalFrames - 1)))
        return min(max(frameIndex, 0), totalFrames - 1)
    }

    // Calculate X offset for 2D grid (column selection)
    private func calculateFrameXOffset() -> CGFloat {
        let frameIndex = calculateFrameIndex()
        let gridX = frameIndex % gridColumns  // Column: 0-13
        return -CGFloat(gridX) * frameWidth
    }

    // Calculate Y offset for 2D grid (row selection)
    private func calculateFrameYOffset() -> CGFloat {
        let frameIndex = calculateFrameIndex()
        let gridY = frameIndex / gridColumns  // Row: 0-1
        return -CGFloat(gridY) * frameHeight
    }

    // Fallback color when no skin loaded
    private var fallbackColor: Color {
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let percent = min(max(CGFloat(normalizedValue), 0), 1)

        if percent <= 0.5 {
            // Green to yellow (0-50%)
            let t = percent * 2
            return Color(red: Double(t), green: 0.8, blue: 0)
        } else {
            // Yellow to red (50-100%)
            let t = (percent - 0.5) * 2
            return Color(red: 1.0, green: Double(0.8 - t * 0.8), blue: 0)
        }
    }

}

