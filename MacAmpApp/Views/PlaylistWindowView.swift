
import SwiftUI

struct PlaylistWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var settings: AppSettings
    
    // MARK: - Whimsy & Animation States
    @State private var trackHover: String? = nil
    @State private var playingTrackPulse: Bool = false
    @State private var listGlow: Double = 0.0
    @State private var headerShimmer: Bool = false

    var body: some View {
        let style = skinManager.currentSkin?.playlistStyle
        let bgColor = style?.backgroundColor ?? .black
        let normalText = style?.normalTextColor ?? .white
        let currentText = style?.currentTextColor ?? .white
        let selectedBG = style?.selectedBackgroundColor ?? Color.blue.opacity(0.5)
        let textFont: Font = {
            if let name = style?.fontName { return .custom(name, size: 12) }
            return .system(size: 12)
        }()

        return VStack(spacing: 0) {
            playlistHeader(normalText: normalText, bgColor: bgColor)
            
            playlistList(textFont: textFont, normalText: normalText, currentText: currentText, selectedBG: selectedBG, bgColor: bgColor)
        }
        .frame(width: WindowSpec.playlist.size.width, height: WindowSpec.playlist.size.height)
        .background(semanticBackground(bgColor))
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .playlist)
        })
        .overlay(
            // List glow effect overlay
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.blue.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(listGlow)
                .opacity(listGlow > 1.0 ? 0.6 : 0)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.8), value: listGlow)
        )
        .onReceive(audioPlayer.$currentTrack) { _ in
            // Trigger pulse animation when track changes
            withAnimation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)) {
                playingTrackPulse.toggle()
            }
        }
    }
    
    // MARK: - Whimsy Helper Functions
    private func triggerListGlow() {
        withAnimation(.easeOut(duration: 0.6)) {
            listGlow = 2.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                listGlow = 1.0
            }
        }
    }
    
    // MARK: - View Components
    @ViewBuilder
    private func playlistHeader(normalText: Color, bgColor: Color) -> some View {
        Text("Playlist Editor")
            .font(.headline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(normalText)
            .background(bgColor)
            .overlay(
                // Header shimmer effect
                LinearGradient(
                    colors: [.clear, .white.opacity(0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(headerShimmer ? 0.6 : 0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), 
                          value: headerShimmer)
            )
            .onAppear {
                if settings.shouldUseContainerBackground {
                    headerShimmer = true
                }
            }
    }
    
    @ViewBuilder
    private func playlistList(textFont: Font, normalText: Color, currentText: Color, selectedBG: Color, bgColor: Color) -> some View {
        List(audioPlayer.playlist) { track in
            Text(track.title)
                .foregroundColor(normalText)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bgColor)
        .conditionalSemanticList(enabled: settings.shouldUseContainerBackground)
    }
    
    // MARK: - Liquid Glass Background
    @ViewBuilder
    private func semanticBackground(_ fallbackColor: Color) -> some View {
        if settings.shouldUseContainerBackground {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.8)
                    .overlay(
                        // Animated glass refraction
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.1), .clear, .blue.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(audioPlayer.isPlaying ? 0.4 : 0.2)
                        .animation(
                            .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                            value: audioPlayer.isPlaying
                        )
                    )
            } else {
                fallbackColor
            }
        } else {
            fallbackColor
        }
    }
}

// MARK: - Liquid Glass Integration Extensions

private extension View {
    @ViewBuilder
    func conditionalSemanticList(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.background(.regularMaterial)
            } else {
                self
            }
        } else {
            self
        }
    }
}

#Preview {
    PlaylistWindowView()
        .environmentObject(AppSettings.instance())
}
