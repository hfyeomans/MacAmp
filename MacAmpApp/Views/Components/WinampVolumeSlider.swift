import SwiftUI

/// Winamp-style volume slider using sprite backgrounds
struct WinampVolumeSlider: View {
    @Binding var volume: Float
    @EnvironmentObject var skinManager: SkinManager
    
    @State private var isDragging = false
    
    // Winamp volume slider specs - CORRECTED
    // The VOLUME.BMP is a vertical sprite sheet, we need just the horizontal slider portion
    private let sliderWidth: CGFloat = 68
    private let sliderHeight: CGFloat = 13  // Just the horizontal slider part, not the full 420px sheet
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
            
            // Orange volume bar (matches position slider style from good.png)
            Rectangle()
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.6, blue: 0.0), // Winamp orange
                        Color(red: 1.0, green: 0.8, blue: 0.0)  // Winamp yellow
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: sliderWidth * CGFloat(volume), height: sliderHeight - 2)
                .padding(1)
            
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
            
            // Orange balance bar from center (matches Winamp colors)
            if balance != 0.0 {
                let fillWidth = CGFloat(abs(balance)) * (sliderWidth / 2)
                let fillX = balance > 0 ? sliderWidth / 2 : (sliderWidth / 2) - fillWidth
                
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.0), // Same Winamp orange as volume
                            Color(red: 1.0, green: 0.8, blue: 0.0)  // Same Winamp yellow as volume
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: fillWidth, height: sliderHeight - 2)
                    .offset(x: fillX, y: 0)
                    .padding(1)
            }
            
            // Subtle center indicator (not prominent)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: sliderHeight - 4)
                .offset(x: sliderWidth / 2, y: 0)
                .padding(2)
            
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