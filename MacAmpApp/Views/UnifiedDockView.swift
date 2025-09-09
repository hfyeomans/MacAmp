import SwiftUI
import AppKit

struct UnifiedDockView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var docking: DockingController
    @EnvironmentObject var settings: AppSettings
    
    // MARK: - Whimsy & Animation States
    @State private var dockGlow: Double = 1.0
    @State private var materialShimmer: Bool = false

    var body: some View {
        if skinManager.isLoading {
            // Show loading state while skin loads
            VStack {
                ProgressView("Loading Winamp skin...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundView)
            .onAppear {
                ensureSkin()
            }
        } else if skinManager.currentSkin != nil {
            // Vertical stack of windows with leading alignment
            VStack(alignment: .leading, spacing: 0) {
                // Windows in proper vertical order
                ForEach(docking.sortedVisiblePanes) { pane in
                    windowContent(for: pane.type)
                        .frame(width: naturalSize(for: pane.type).width, 
                               height: pane.isShaded ? 14 : naturalSize(for: pane.type).height,
                               alignment: .topLeading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(backgroundView)
            .scaleEffect(dockGlow)
            .onAppear {
                startDockAnimations()
            }
        } else {
            // Skin not loaded yet - trigger loading
            Color.clear
                .onAppear {
                    ensureSkin()
                }
        }
    }

    private func ensureSkin() {
        if skinManager.currentSkin == nil {
            var urlToLoad: URL? = Bundle.main.url(forResource: "Winamp", withExtension: "wsz")
            #if SWIFT_PACKAGE
            if urlToLoad == nil { urlToLoad = Bundle.module.url(forResource: "Winamp", withExtension: "wsz") }
            #endif
            if let skinURL = urlToLoad { skinManager.loadSkin(from: skinURL) }
        }
    }
    
    // MARK: - Whimsy Helper Functions
    private func startDockAnimations() {
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            dockGlow = 1.005
        }
        if settings.shouldUseContainerBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                materialShimmer = true
            }
        }
    }
    
    // MARK: - Liquid Glass Background
    @ViewBuilder
    private var backgroundView: some View {
        if settings.shouldUseContainerBackground {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                    .overlay(
                        // Animated material shimmer
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.1),
                                .blue.opacity(0.05),
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(materialShimmer ? 0.8 : 0.3)
                        .animation(
                            .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                            value: materialShimmer
                        )
                    )
                    .overlay(
                        // Audio-reactive glow
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [.green.opacity(0.1), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 200
                                )
                            )
                            .opacity(audioPlayer.isPlaying ? 0.6 : 0.2)
                            .animation(.easeInOut(duration: 1.0), value: audioPlayer.isPlaying)
                            .blendMode(.overlay)
                    )
            } else {
                Color.black
            }
        } else {
            Color.black
        }
    }

    // MARK: - Window Content
    @ViewBuilder 
    private func windowContent(for type: DockPaneType) -> some View {
        switch type {
        case .main:
            WinampMainWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        case .equalizer:
            WinampEqualizerWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        case .playlist:
            WinampPlaylistWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        }
    }

    // MARK: - Sizes
    private func naturalSize(for type: DockPaneType) -> CGSize {
        switch type {
        case .main: 
            return WinampSizes.main
        case .equalizer: 
            return WinampSizes.equalizer
        case .playlist: 
            return CGSize(width: WinampSizes.playlistBase.width, 
                          height: WinampSizes.playlistBase.height)
        }
    }
}

// MARK: - Liquid Glass Extensions
extension View {
    @ViewBuilder
    func containerBackground(for type: DockPaneType) -> some View {
        self // Background is handled at the container level
    }
}

// MARK: - Support Types (Keep for compatibility)
struct EnhancedSeparator: View {
    let height: CGFloat
    let isPulsing: Bool
    let useGlassEffect: Bool
    
    var body: some View {
        // No separators needed in vertical stack
        EmptyView()
    }
}

// Keep these for compatibility but they're no longer used
struct Draggable2<Content: View>: View {
    let id: String
    var onChanged: ((CGPoint) -> Void)?
    var onEnded: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
    }
}

struct RowFrameReader: View {
    let id: String
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
    }
}

struct RowFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

#Preview {
    UnifiedDockView()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(DockingController())
        .environmentObject(AppSettings.instance())
}