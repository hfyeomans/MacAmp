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
        // Winamp-style volume slider - matches position slider appearance
        ZStack(alignment: .leading) {
            // STEP 1 TEST: Try rendering VOLUME.BMP from skin
            // Keep programmatic gradient as backup to compare
            if let skin = skinManager.currentSkin,
               let volumeBg = skin.images["MAIN_VOLUME_BACKGROUND"] {
                // Simplest approach: image, frame, clip - that's it!
                Image(nsImage: volumeBg)
                    .interpolation(.none)
                    .frame(width: sliderWidth, height: sliderHeight, alignment: .top)
                    .offset(y: calculateVolumeFrameOffset())
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                // Fallback: Dark groove background with rounded ends
                RoundedRectangle(cornerRadius: trackFillHeight / 2)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: sliderWidth, height: trackFillHeight)
                    .offset(y: (sliderHeight - trackFillHeight) / 2)

                // Colored channel with rounded ends (solid color that changes)
                RoundedRectangle(cornerRadius: (trackFillHeight - 2) / 2)
                    .fill(sliderColor)
                    .frame(width: sliderWidth - 2, height: trackFillHeight - 2)
                    .offset(x: 1, y: (sliderHeight - trackFillHeight + 2) / 2)
            }

            // Sprite thumb (from skin) - vertically centered on slider
            let thumbSprite = isDragging ? "MAIN_VOLUME_THUMB_SELECTED" : "MAIN_VOLUME_THUMB"
            // Slider height: 13px, Thumb height: 11px
            // Center: (13 - 11) / 2 = 1px
            SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
                .at(x: thumbPosition, y: 1)  // Vertically center on 13px slider

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

    // Winamp balance slider specs
    private let sliderWidth: CGFloat = 38
    private let sliderHeight: CGFloat = 13
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11

    var body: some View {
        ZStack(alignment: .leading) {
            // BALANCE.BMP frame rendering (same technique as volume)
            if let skin = skinManager.currentSkin,
               let balanceBg = skin.images["MAIN_BALANCE_BACKGROUND"] {
                // Use BALANCE.BMP frames - CRITICAL: frame→offset→clip order!
                Image(nsImage: balanceBg)
                    .interpolation(.none)
                    .frame(width: sliderWidth, height: sliderHeight, alignment: .top)
                    .offset(y: calculateBalanceFrameOffset())
                    .clipped()
                    .allowsHitTesting(false)

                // Thumb sprite
                let thumbSprite = isDragging ? "MAIN_BALANCE_THUMB_ACTIVE" : "MAIN_BALANCE_THUMB"
                SimpleSpriteImage(thumbSprite, width: thumbWidth, height: thumbHeight)
                    .at(x: thumbPosition, y: 1)  // Vertically centered

            } else {
                // Fallback: simple gradient
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: sliderWidth, height: 7)

                // Center line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 7)
                    .offset(x: sliderWidth / 2 - 1)
            }

            // Invisible interaction area
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let x = min(max(0, value.location.x), geo.size.width)
                                let normalized = Float(x / geo.size.width)
                                var newBalance = (normalized * 2.0) - 1.0

                                // Gentle snap to center with haptic feedback
                                let snapThreshold: Float = 0.08  // 8% threshold for gentle catch
                                if abs(newBalance) < snapThreshold {
                                    newBalance = 0

                                    // Provide haptic feedback when catching center
                                    #if os(macOS)
                                    NSHapticFeedbackManager.defaultPerformer.perform(
                                        .alignment,
                                        performanceTime: .default
                                    )
                                    #endif
                                }

                                balance = max(-1, min(1, newBalance))
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
        let normalizedBalance = (balance + 1.0) / 2.0  // -1..1 → 0..1
        return CGFloat(normalizedBalance) * maxOffset
    }

    private func calculateBalanceFrameOffset() -> CGFloat {
        // Balance uses gradient TWICE - mirrored from center:
        // -1.0 (left/red) → 0.0 (center/green) → 1.0 (right/red)
        // Distance from center determines color intensity

        let absBalance = abs(balance)  // 0.0 to 1.0 (distance from center)
        let percent = min(max(CGFloat(absBalance), 0), 1)

        // Map to frame range where green is in middle
        // At center (abs=0): want frame 14 (green)
        // At edges (abs=1): want frame 27 (red)
        // This means: frame = 14 + (abs * 13)
        let baseFrame = 14  // Green/center frame
        let additionalFrames = Int(round(percent * 13.0))  // 0 to 13
        let frameIndex = min(27, baseFrame + additionalFrames)

        return -CGFloat(frameIndex) * 15.0
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
