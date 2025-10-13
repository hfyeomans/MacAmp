import SwiftUI

/// Pure functional slider control - works without any skin sprites
/// Provides drag interaction and value binding, no visual presentation
///
/// This is Layer 1 (Mechanism) - pure logic, no skin knowledge
struct BaseSliderControl: View {
    @Binding var value: Float
    let width: CGFloat
    let height: CGFloat
    let orientation: Orientation

    @State private var isDragging = false

    enum Orientation {
        case horizontal  // Volume, Balance, Position
        case vertical    // EQ, Preamp
    }

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            updateValue(from: drag, in: geo)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(width: width, height: height)
    }

    private func updateValue(from drag: DragGesture.Value, in geo: GeometryProxy) {
        switch orientation {
        case .horizontal:
            let x = min(max(0, drag.location.x), geo.size.width)
            value = Float(x / geo.size.width)

        case .vertical:
            let y = min(max(0, drag.location.y), geo.size.height)
            // Invert: top = 1.0, bottom = 0.0 (matches Winamp EQ behavior)
            value = Float(1.0 - (y / geo.size.height))
        }
    }
}

/// Plain visual feedback for sliders when no skin is loaded
/// Shows simple filled bar indicating current value
struct PlainSliderFeedback: View {
    let value: Float
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: width, height: height)

            // Filled portion
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: width * CGFloat(value), height: height)
        }
    }
}

/// Plain thumb indicator for sliders when no skin is loaded
struct PlainThumbIndicator: View {
    let position: CGFloat  // Absolute x or y position
    let size: CGSize
    let isVertical: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .stroke(Color.black, lineWidth: 1)
            .frame(width: size.width, height: size.height)
            .offset(
                x: isVertical ? 0 : position,
                y: isVertical ? position : 0
            )
    }
}
