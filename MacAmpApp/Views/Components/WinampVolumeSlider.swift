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
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        // Winamp-style volume slider - matches position slider appearance  
        ZStack(alignment: .leading) {
            // Dark recessed background like Winamp
            Rectangle()
                .fill(Color.black)
                .frame(width: sliderWidth, height: sliderHeight)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.8), lineWidth: 1)
                )

            // Orange volume bar (thinner to match Winamp look)
            Rectangle()
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.6, blue: 0.0), // Winamp orange
                        Color(red: 1.0, green: 0.8, blue: 0.0)  // Winamp yellow
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: max(0, sliderWidth * CGFloat(volume) - thumbWidth/2), height: trackFillHeight)
                .offset(y: (sliderHeight - trackFillHeight) / 2)

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
    private let thumbWidth: CGFloat = 14
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        // Winamp-style balance slider - matches volume/position slider appearance
        ZStack(alignment: .leading) {
            // Dark recessed background like volume slider
            Rectangle()
                .fill(Color.black)
                .frame(width: sliderWidth, height: sliderHeight)
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.8), lineWidth: 1)
                )

            // Orange balance bar from center (thinner)
            if balance != 0.0 {
                let fillWidth = CGFloat(abs(balance)) * (sliderWidth / 2)
                let fillX = balance > 0 ? sliderWidth / 2 : (sliderWidth / 2) - fillWidth

                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.0),
                            Color(red: 1.0, green: 0.8, blue: 0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: fillWidth, height: trackFillHeight)
                    .offset(x: fillX, y: (sliderHeight - trackFillHeight) / 2)
            }

            // Subtle center indicator
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 1, height: trackFillHeight)
                .offset(x: sliderWidth / 2, y: (sliderHeight - trackFillHeight) / 2)

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
