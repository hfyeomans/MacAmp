import SwiftUI

/// Vertical slider component for EQ bands
struct WinampVerticalSlider: View {
    @Environment(SkinManager.self) var skinManager
    @Binding var value: Float
    let range: ClosedRange<Float>
    let width: CGFloat
    let height: CGFloat
    let thumbHeight: CGFloat
    let backgroundSprite: String
    let thumbSprite: String
    let thumbActiveSprite: String

    @State private var isDragging = false

    // EQ_SLIDER_BACKGROUND 2D grid constants (14×2 layout, 28 frames total)
    private let frameWidth: CGFloat = 15
    private let frameHeight: CGFloat = 65
    private let gridColumns: Int = 14
    private let totalFrames: Int = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Render colored gradient background from EQ_SLIDER_BACKGROUND
            // Uses 2D grid positioning (14 columns × 2 rows)
            if let skin = skinManager.currentSkin,
               let eqBackground = skin.images[backgroundSprite] {
                // CRITICAL: frame→offset→clip order (proven from Volume slider)
                Image(nsImage: eqBackground)
                    .interpolation(.none)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .offset(x: calculateFrameXOffset(), y: calculateFrameYOffset())
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                // Fallback: programmatic gradient if sprite missing
                Rectangle()
                    .fill(sliderColor)
                    .frame(width: width, height: height)
            }

            // Slider thumb sprite (11x11 pixels)
            SimpleSpriteImage(isDragging ? thumbActiveSprite : thumbSprite,
                            width: 11, height: 11)
                .offset(x: 1.5, y: thumbPosition) // Position based on webamp formula

            // Invisible interaction area - EXACTLY constrained
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(from: gesture, in: geo)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(width: width, height: height) // FORCE exact constraint
        }
        .frame(width: width, height: height) // DOUBLE ensure constraints
        .clipped() // CRITICAL: Clip any overflow
    }

    /// Value normalized to 0.0–1.0 within the slider range.
    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    // Solid color that changes based on slider position
    private var sliderColor: Color {
        // Map value to color: green (-12) -> yellow (0) -> red (+12)

        if normalizedValue <= 0.5 {
            // Green to Yellow (bottom to center)
            let t = normalizedValue * 2 // 0 to 1 for this half
            return Color(
                red: Double(t * 0.9),      // 0 -> 0.9
                green: Double(0.8),         // Stay high
                blue: 0
            )
        } else {
            // Yellow to Red (center to top)
            let t = (normalizedValue - 0.5) * 2 // 0 to 1 for this half
            return Color(
                red: Double(0.9 + t * 0.1), // 0.9 -> 1.0
                green: Double(0.8 * (1 - t)), // 0.8 -> 0
                blue: 0
            )
        }
    }


    private var thumbPosition: CGFloat {
        let thumbSize: CGFloat = 11
        let trackHeight = height - thumbSize
        // Inverted: our coordinate system has 0 at top
        return floor(trackHeight * (1.0 - CGFloat(normalizedValue)))
    }

    private func updateValue(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let gestureHeight = geometry.size.height
        let y = min(max(0, gesture.location.y), gestureHeight)

        // Invert Y coordinate (top = high value, bottom = low value)
        let normalizedPosition = 1.0 - Float(y / gestureHeight)
        var newValue = range.lowerBound + (normalizedPosition * (range.upperBound - range.lowerBound))

        // Center snapping: if within ±0.5dB of center (0), snap to exactly 0
        let snapThreshold: Float = 0.5
        if abs(newValue) < snapThreshold {
            newValue = 0
        }

        value = max(range.lowerBound, min(range.upperBound, newValue))
    }

    // Calculate which frame (0-27) to display based on EQ value
    private func calculateFrameIndex() -> Int {
        let percent = min(max(CGFloat(normalizedValue), 0), 1)
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
}
