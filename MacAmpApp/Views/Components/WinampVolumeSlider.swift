import SwiftUI

/// Winamp-style volume slider using sprite backgrounds
struct WinampVolumeSlider: View {
    @Binding var volume: Float
    @EnvironmentObject var skinManager: SkinManager
    
    @State private var isDragging = false
    
    // Winamp volume slider specs
    // Matches Winamp sprite sizes; track visually thinned for accuracy
    private let sliderWidth: CGFloat = 68
    private let sliderHeight: CGFloat = 13
    private let trackFillHeight: CGFloat = 7   // thinner visual track inside the recess
    private let trackInset: CGFloat = 1        // 1px inset inside the recessed border
    private let trackYBias: CGFloat = 1        // nudge to visually center inside channel
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        // Winamp-style volume slider - matches position slider appearance
        ZStack(alignment: .leading) {
            // Dark groove background with rounded ends
            RoundedRectangle(cornerRadius: trackFillHeight / 2)
                .fill(Color.black.opacity(0.3))
                .frame(width: sliderWidth, height: trackFillHeight)
                .offset(y: (sliderHeight - trackFillHeight) / 2)

            // Colored channel with rounded ends (solid color that changes)
            RoundedRectangle(cornerRadius: (trackFillHeight - 2) / 2)
                .fill(sliderColor)
                .frame(width: sliderWidth - 2, height: trackFillHeight - 2)
                .offset(x: 1, y: (sliderHeight - trackFillHeight + 2) / 2)

            // Sprite thumb (from skin)
            let thumbSprite = isDragging ? "MAIN_VOLUME_THUMB_SELECTED" : "MAIN_VOLUME_THUMB"
            SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
                .at(x: thumbPosition, y: (sliderHeight - thumbHeight) / 2)

            // Invisible interaction area
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                updateVolume(from: value, in: geo)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }
    
    private var thumbPosition: CGFloat {
        let maxOffset = sliderWidth - thumbWidth
        return CGFloat(volume) * maxOffset
    }
    
    private func updateVolume(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let width = geometry.size.width
        let x = min(max(0, gesture.location.x), width)
        let newVolume = Float(x / width)
        volume = max(0, min(1, newVolume))
    }

    // Calculate color based on volume (green -> yellow -> orange -> red)
    private var sliderColor: Color {
        let normalizedValue = volume

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

/// Winamp-style balance slider using sprite backgrounds  
struct WinampBalanceSlider: View {
    @Binding var balance: Float
    @EnvironmentObject var skinManager: SkinManager
    
    @State private var isDragging = false
    
    // Winamp balance slider specs
    private let sliderWidth: CGFloat = 38
    private let sliderHeight: CGFloat = 13
    private let trackFillHeight: CGFloat = 7   // thinner visual track
    private let trackInset: CGFloat = 1        // 1px inset inside the recessed border
    private let trackYBias: CGFloat = 1        // nudge to visually center inside channel
    private let minCenterFill: CGFloat = 2     // ensure visible fill at center
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        // Winamp-style balance slider - matches volume/position slider appearance
        ZStack(alignment: .leading) {
            // Dark groove background with rounded ends
            RoundedRectangle(cornerRadius: trackFillHeight / 2)
                .fill(Color.black.opacity(0.3))
                .frame(width: sliderWidth, height: trackFillHeight)
                .offset(y: (sliderHeight - trackFillHeight) / 2)

            // Colored channel with rounded ends (solid color that changes)
            RoundedRectangle(cornerRadius: (trackFillHeight - 2) / 2)
                .fill(sliderColor)
                .frame(width: sliderWidth - 2, height: trackFillHeight - 2)
                .offset(x: 1, y: (sliderHeight - trackFillHeight + 2) / 2)

            // Center notch indicator (visual reference for center position)
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 1, height: trackFillHeight)
                .offset(x: sliderWidth / 2 - 0.5, y: (sliderHeight - trackFillHeight) / 2)

            // Sprite thumb (from skin)
            let thumbSprite = isDragging ? "MAIN_BALANCE_THUMB_ACTIVE" : "MAIN_BALANCE_THUMB"
            SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
                .at(x: thumbPosition, y: (sliderHeight - thumbHeight) / 2)

            // Invisible interaction area
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                updateBalance(from: value, in: geo)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }
    
    private var thumbPosition: CGFloat {
        let maxOffset = sliderWidth - thumbWidth
        let normalizedBalance = (balance + 1.0) / 2.0 // Convert -1..1 to 0..1
        return CGFloat(normalizedBalance) * maxOffset
    }
    
    private func updateBalance(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let width = geometry.size.width
        let x = min(max(0, gesture.location.x), width)
        let normalizedPosition = Float(x / width) // 0..1
        let newBalance = (normalizedPosition * 2.0) - 1.0 // Convert to -1..1
        balance = max(-1, min(1, newBalance))
    }

    // Calculate color based on balance distance from center
    // Green at center (0), transitions to red as it moves away
    private var sliderColor: Color {
        let absValue = abs(balance)

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

#Preview {
    VStack(spacing: 20) {
        WinampVolumeSlider(volume: .constant(0.7))
            .background(Color.black)
        
        WinampBalanceSlider(balance: .constant(0.2))
            .background(Color.black)
    }
    .padding()
    .environmentObject(SkinManager())
}
