import SwiftUI
import AppKit

struct UnifiedDockView: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(DockingController.self) var docking
    @Environment(AppSettings.self) var settings

    // MARK: - Whimsy & Animation States
    @State private var dockGlow: Double = 1.0
    @State private var materialShimmer: Bool = false

    // MARK: - Window Reference
    @State private var dockWindow: NSWindow?

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
                    let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
                    let baseSize = baseNaturalSize(for: pane.type)

                    windowContent(for: pane.type)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: baseSize.width * scale,
                               height: pane.isShaded ? 14 * scale : baseSize.height * scale,
                               alignment: .topLeading)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: calculateTotalWidth(),
                   height: calculateTotalHeight(),
                   alignment: .topLeading)
            .fixedSize() // This tells SwiftUI to use the exact frame size
            .animation(.easeInOut(duration: 0.2), value: settings.isDoubleSizeMode)
            .background(backgroundView)
            .scaleEffect(dockGlow)
            .onAppear {
                startDockAnimations()
            }
            .onChange(of: settings.materialIntegration) { _, _ in
                startDockAnimations()
            }
            .onChange(of: settings.enableLiquidGlass) { _, _ in
                startDockAnimations()
            }
            .onChange(of: settings.isAlwaysOnTop) { _, isOn in
                // Toggle THIS window's level (not NSApp.keyWindow!)
                dockWindow?.level = isOn ? .floating : .normal
            }
            .background(
                WindowAccessor { window in
                    // Store reference to THIS specific window
                    if dockWindow == nil {
                        dockWindow = window
                    }
                    configureWindow(window)
                    // Set initial window level based on persisted state
                    window.level = settings.isAlwaysOnTop ? .floating : .normal
                }
            )
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
            skinManager.loadInitialSkin()
        }
    }

    // MARK: - Window Configuration
    private func configureWindow(_ window: NSWindow) {
        // Configure window style mask to remove title bar completely
        window.styleMask.insert(.borderless)
        window.styleMask.remove(.titled)

        // DO NOT make entire window draggable - causes slider conflicts
        // We'll use custom DragGesture on title bars only
        window.isMovableByWindowBackground = false

        // Remove title bar appearance completely
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Ensure no separator line between title bar and content
        if #available(macOS 11.0, *) {
            window.toolbar = nil
        }

        // Allow window to be in front of other windows
        window.level = .normal

        // Remove shadow if you want truly pixel-perfect edges (optional)
        // Uncomment if you want no shadow:
        // window.hasShadow = false

        // Prevent window from being resized (already handled by .windowResizability(.contentSize))
        window.isMovable = true
    }

    // MARK: - Animation Helper Functions
    private func startDockAnimations() {
        // Only apply glow effect in modern mode
        if settings.materialIntegration == .modern {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                dockGlow = 1.005
            }
        } else {
            dockGlow = 1.0
        }
        
        // Start material shimmer for hybrid and modern modes with liquid glass
        if settings.enableLiquidGlass && (settings.materialIntegration == .hybrid || settings.materialIntegration == .modern) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                materialShimmer = true
            }
        } else {
            materialShimmer = false
        }
    }
    
    // MARK: - Appearance Mode Background
    @ViewBuilder
    private var backgroundView: some View {
        switch settings.materialIntegration {
        case .classic:
            // Classic mode: Pure Winamp skin appearance
            Color.black
                .id("classic-mode")
                
        case .hybrid:
            // Hybrid mode: Subtle material effects with Winamp chrome
            ZStack {
                Color.black
                
                if settings.enableLiquidGlass {
                    // Subtle material overlay for hybrid mode
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.05),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(materialShimmer ? 0.5 : 0.2)
                            .animation(
                                .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
                                value: materialShimmer
                            )
                        )
                }
            }
            .id("hybrid-mode-\(settings.enableLiquidGlass)")
            
        case .modern:
            // Modern mode: Full SwiftUI materials
            if settings.enableLiquidGlass {
                ZStack {
                    // Base material layer
                    Rectangle()
                        .fill(.regularMaterial)
                        .ignoresSafeArea()
                    
                    // Animated shimmer overlay
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
                    
                    // Audio-reactive glow
                    RadialGradient(
                        colors: [
                            audioPlayer.isPlaying ? .green.opacity(0.15) : .blue.opacity(0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                    .opacity(audioPlayer.isPlaying ? 0.6 : 0.3)
                    .animation(.easeInOut(duration: 1.0), value: audioPlayer.isPlaying)
                    .blendMode(.overlay)
                }
                .id("modern-mode-liquid")
            } else {
                // Modern without liquid glass - just material
                Rectangle()
                    .fill(.regularMaterial)
                    .id("modern-mode-basic")
            }
        }
    }

    // MARK: - Window Content
    @ViewBuilder 
    private func windowContent(for type: DockPaneType) -> some View {
        switch type {
        case .main:
            WinampMainWindow()
                .environment(skinManager)
                .environment(audioPlayer)
        case .equalizer:
            WinampEqualizerWindow()
                .environment(skinManager)
                .environment(audioPlayer)
        case .playlist:
            WinampPlaylistWindow()
                .environment(skinManager)
                .environment(audioPlayer)
        }
    }

    // MARK: - Sizes

    /// Returns base size without scaling (for internal use)
    private func baseNaturalSize(for type: DockPaneType) -> CGSize {
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

    /// Returns size with double-size scaling applied if enabled
    private func naturalSize(for type: DockPaneType) -> CGSize {
        let baseSize = baseNaturalSize(for: type)
        let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
        return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }
    
    // Calculate total width - should be the width of the widest visible window
    private func calculateTotalWidth() -> CGFloat {
        guard !docking.sortedVisiblePanes.isEmpty else { return 275 }

        let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
        return docking.sortedVisiblePanes.map { pane in
            baseNaturalSize(for: pane.type).width * scale
        }.max() ?? (275 * scale)
    }
    
    // Calculate total height - sum of all visible window heights
    private func calculateTotalHeight() -> CGFloat {
        guard !docking.sortedVisiblePanes.isEmpty else { return WinampSizes.main.height }

        let scale: CGFloat = settings.isDoubleSizeMode ? 2.0 : 1.0
        return docking.sortedVisiblePanes.reduce(0) { total, pane in
            let height = pane.isShaded ? 14 : baseNaturalSize(for: pane.type).height
            return total + (height * scale)
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
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

#Preview {
    UnifiedDockView()
        .environment(SkinManager())
        .environment(AudioPlayer())
        .environment(DockingController())
        .environment(AppSettings.instance())
}
