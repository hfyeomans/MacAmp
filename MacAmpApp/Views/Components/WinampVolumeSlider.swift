import SwiftUI

/// Winamp-style volume slider using sprite backgrounds
struct WinampVolumeSlider: View {
    @Binding var volume: Float
    @Environment(SkinManager.self) var skinManager
    
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
        ZStack(alignment: .leading) {
            volumeTrack
            volumeInteractionArea
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }

    @ViewBuilder
    private var volumeTrack: some View {
        if let skin = skinManager.currentSkin,
           let volumeBg = skin.images["MAIN_VOLUME_BACKGROUND"] {
            Image(nsImage: volumeBg)
                .interpolation(.none)
                .frame(width: sliderWidth, height: sliderHeight, alignment: .top)
                .offset(y: calculateVolumeFrameOffset())
                .clipped()
                .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: trackFillHeight / 2)
                .fill(Color.black.opacity(0.3))
                .frame(width: sliderWidth, height: trackFillHeight)
                .offset(y: (sliderHeight - trackFillHeight) / 2)
            RoundedRectangle(cornerRadius: (trackFillHeight - 2) / 2)
                .fill(sliderColor)
                .frame(width: sliderWidth - 2, height: trackFillHeight - 2)
                .offset(x: 1, y: (sliderHeight - trackFillHeight + 2) / 2)
        }

        let thumbSprite = isDragging ? "MAIN_VOLUME_THUMB_SELECTED" : "MAIN_VOLUME_THUMB"
        SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
            .at(x: thumbPosition, y: 1)
    }

    private var volumeInteractionArea: some View {
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

    // Calculate VOLUME.BMP frame offset
    // Webamp uses ONLY first 420px (28 frames × 15px), ignoring last 13px
    private func calculateVolumeFrameOffset() -> CGFloat {
        let percent = min(max(CGFloat(volume), 0), 1)
        let sprite = Int(round(percent * 28.0))  // 0 to 28
        let frameIndex = min(27, max(0, sprite - 1))  // Clamp to 0-27
        let offset = CGFloat(frameIndex) * 15.0  // Each frame exactly 15px
        return -offset  // Negative shifts image up
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

/// Winamp-style balance slider with proper BALANCE.BMP support
/// Uses same solution as volume slider (frame→offset→clip order)
struct WinampBalanceSlider: View {
    @Binding var balance: Float  // -1.0 to 1.0
    @Environment(SkinManager.self) var skinManager

    @State private var isDragging = false
    @State private var isSnappedToCenter = false

    // Winamp balance slider specs
    private let sliderWidth: CGFloat = 38
    private let sliderHeight: CGFloat = 13
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11

    var body: some View {
        ZStack(alignment: .leading) {
            balanceTrack
            balanceInteractionArea
        }
        .frame(width: sliderWidth, height: sliderHeight)
    }

    @ViewBuilder
    private var balanceTrack: some View {
        if let skin = skinManager.currentSkin,
           let balanceBg = skin.images["MAIN_BALANCE_BACKGROUND"] {
            Image(nsImage: balanceBg)
                .interpolation(.none)
                .frame(width: sliderWidth, height: sliderHeight, alignment: .top)
                .offset(y: calculateBalanceFrameOffset())
                .clipped()
                .allowsHitTesting(false)

            let thumbSprite = isDragging ? "MAIN_BALANCE_THUMB_ACTIVE" : "MAIN_BALANCE_THUMB"
            SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
                .at(x: thumbPosition, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue.opacity(0.5))
                .frame(width: sliderWidth, height: 7)
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 7)
                .offset(x: sliderWidth / 2 - 1)
        }
    }

    private var balanceInteractionArea: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in handleDrag(value, in: geo) }
                        .onEnded { _ in
                            isDragging = false
                            isSnappedToCenter = false
                        }
                )
        }
    }

    private func handleDrag(_ value: DragGesture.Value, in geo: GeometryProxy) {
        isDragging = true
        let x = min(max(0, value.location.x), geo.size.width)
        let normalized = Float(x / geo.size.width)
        var newBalance = (normalized * 2.0) - 1.0

        let snapThreshold: Float = 0.12
        if abs(newBalance) < snapThreshold {
            newBalance = 0
            if !isSnappedToCenter {
                isSnappedToCenter = true
                #if os(macOS)
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
                #endif
            }
        } else {
            isSnappedToCenter = false
        }

        balance = max(-1, min(1, newBalance))
    }

    private var thumbPosition: CGFloat {
        let maxOffset = sliderWidth - thumbWidth
        let normalizedBalance = (balance + 1.0) / 2.0  // -1..1 → 0..1
        return CGFloat(normalizedBalance) * maxOffset
    }

    // BALANCE.BMP frame offset: frame 0 (green) at top, frame 27 (red) at bottom.
    // Symmetric mapping from center via abs(balance).
    // Matches webamp: Math.floor(Math.abs(balance) / 100 * 27) * 15
    private func calculateBalanceFrameOffset() -> CGFloat {
        let percent = min(max(CGFloat(abs(balance)), 0), 1)
        let sprite = Int(floor(percent * 27.0))
        let offset = CGFloat(sprite) * 15.0
        return -offset
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
    .environment(SkinManager())
}
