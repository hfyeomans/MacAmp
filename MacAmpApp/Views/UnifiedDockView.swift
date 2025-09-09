import SwiftUI
import AppKit

struct UnifiedDockView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var docking: DockingController
    @EnvironmentObject var settings: AppSettings

    private let snapDistance: CGFloat = 15
    @State private var frames: [String: CGRect] = [:]
    @State private var draggingID: String? = nil
    @State private var dragOffsetX: CGFloat = 0
    @State private var insertionIndex: Int? = nil
    @State private var insertionRow: Int? = nil
    
    // MARK: - Whimsy & Animation States
    @State private var dockGlow: Double = 1.0
    @State private var separatorPulse: Bool = false
    @State private var snapFeedback: Bool = false
    @State private var materialShimmer: Bool = false

    var body: some View {
        GeometryReader { geo in
            // Canvas width is the max of both rows' intrinsic widths; rows do not stretch
            let canvasWidth = max(rowWidth(0), rowWidth(1))
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    rowView(row: 0, geo: geo)
                        .frame(width: canvasWidth, alignment: .leading)
                    rowView(row: 1, geo: geo)
                        .frame(width: canvasWidth, alignment: .leading)
                }
                .frame(width: canvasWidth, alignment: .leading)
                .coordinateSpace(name: "dock2")
                .onPreferenceChange(RowFramesKey.self) { frames = $0 }

                if let row = insertionRow, let guideX = guideX(for: row) {
                    let rf = rowFrame(row: row)
                    // Enhanced insertion guide with glass effect
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.8), .blue.opacity(0.6), .white.opacity(0.8), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: rf.height)
                        .offset(x: guideX, y: rf.minY)
                        .scaleEffect(snapFeedback ? 1.2 : 1.0)
                        .shadow(color: .blue, radius: snapFeedback ? 4 : 2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: snapFeedback)
                }
            }
            // Keep the whole canvas left-aligned; outer window can be larger
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(backgroundView)
        .scaleEffect(dockGlow)
        .onAppear {
            ensureSkin()
            startDockAnimations()
        }
        .onChange(of: draggingID) { newValue in
            handleDragStateChange(newValue)
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
    
    private func handleDragStateChange(_ newDraggingID: String?) {
        if newDraggingID != nil {
            // Started dragging
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                separatorPulse = true
                snapFeedback = true
            }
        } else {
            // Stopped dragging
            withAnimation(.easeOut(duration: 0.4)) {
                separatorPulse = false
                snapFeedback = false
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

    // MARK: - Rows
    private func rowView(row: Int, geo: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 0) {
            let panes = docking.panes.filter { $0.visible && $0.row == row }
            ForEach(Array(panes.enumerated()), id: \.element.id) { (idx, pane) in
                Draggable2(
                    id: pane.id,
                    onChanged: { point in updateInsertion(for: point, container: geo.size) },
                    onEnded: commitDrop
                ) {
                    content(for: pane.type)
                        .frame(width: width(for: pane, in: geo.size.width), height: height(for: pane))
                        .containerBackground(for: pane.type)
                }
                .background(RowFrameReader(id: pane.id))

                if idx < panes.count - 1 { 
                    EnhancedSeparator(
                        height: height(for: pane),
                        isPulsing: separatorPulse,
                        useGlassEffect: settings.shouldUseContainerBackground
                    )
                }
            }
        }
    }

    @ViewBuilder private func content(for type: DockPaneType) -> some View {
        switch type {
        case .main:
            WinampMainWindow().environmentObject(skinManager).environmentObject(audioPlayer)
        case .playlist:
            WinampPlaylistWindow().environmentObject(skinManager).environmentObject(audioPlayer)
        case .equalizer:
            WinampEqualizerWindow().environmentObject(skinManager).environmentObject(audioPlayer)
        }
    }

    // MARK: - Sizes
    private func naturalSize(for type: DockPaneType) -> CGSize {
        switch type {
        case .main: return WinampSizes.main
        case .playlist: return CGSize(width: WinampSizes.playlistBase.width, height: WinampSizes.playlistBase.height)
        case .equalizer: return WinampSizes.equalizer
        }
    }
    private func height(for pane: DockPaneState) -> CGFloat {
        pane.isShaded ? 14 : naturalSize(for: pane.type).height
    }
    private func width(for pane: DockPaneState, in containerWidth: CGFloat) -> CGFloat {
        // Do not stretch to container width. Prefer per-row width, then legacy idealWidth, then natural size.
        let base = naturalSize(for: pane.type).width
        let w = pane.widthsByRow?[pane.row] ?? pane.idealWidth ?? base
        return max(w, base)
    }

    private func rowWidth(_ row: Int) -> CGFloat {
        let peers = docking.panes.filter { $0.visible && $0.row == row }
        if peers.isEmpty { return 0 }
        let bars = max(0, peers.count - 1)
        let panesSum = peers.reduce(CGFloat(0)) { sum, p in sum + width(for: p, in: 10000) }
        return panesSum + CGFloat(bars) * 1 // separator width (idle)
    }

    // MARK: - Drag/Snap
    private func updateInsertion(for point: CGPoint, container: CGSize) {
        var topMaxY = rowFrame(row: 0).maxY
        if topMaxY <= 0 { topMaxY = naturalSize(for: .main).height }
        let targetRow = point.y > topMaxY + 8 ? 1 : 0
        insertionRow = targetRow
        let panes = docking.panes.filter { $0.visible && $0.row == targetRow }
        guard !panes.isEmpty,
              let firstX = frames[panes.first!.id]?.minX,
              let lastMax = frames[panes.last!.id]?.maxX else { insertionIndex = nil; return }
        var boundaries: [CGFloat] = [firstX]
        for i in 1..<panes.count {
            if let l = frames[panes[i-1].id]?.minX, let r = frames[panes[i].id]?.minX { boundaries.append((l+r)/2) }
        }
        boundaries.append(lastMax)
        guard let nearest = boundaries.min(by: { abs($0 - point.x) < abs($1 - point.x) }), abs(nearest - point.x) <= snapDistance else {
            insertionIndex = nil; return
        }
        var idx = panes.count
        for (i,b) in boundaries.enumerated() where i < panes.count { if point.x < b { idx = i; break } }
        insertionIndex = idx
    }

    private func commitDrop() {
        guard let id = draggingID, let row = insertionRow, let idx = insertionIndex else { 
            draggingID = nil
            insertionIndex = nil
            insertionRow = nil
            return 
        }
        guard let type = docking.panes.first(where: { $0.id == id })?.type else { return }
        
        // Add delightful drop animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            docking.move(type: type, toRow: row, toVisibleIndex: idx)
        }
        
        // Trigger success feedback
        withAnimation(.easeOut(duration: 0.2)) {
            snapFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                snapFeedback = false
            }
        }
        
        draggingID = nil
        insertionIndex = nil
        insertionRow = nil
    }

    private func rowFrame(row: Int) -> CGRect {
        let panes = docking.panes.filter { $0.visible && $0.row == row }
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = CGFloat.leastNormalMagnitude
        for p in panes { if let f = frames[p.id] { minY = min(minY, f.minY); maxY = max(maxY, f.maxY) } }
        if minY == .greatestFiniteMagnitude { minY = 0 }
        if maxY == .leastNormalMagnitude { maxY = 0 }
        return CGRect(x: 0, y: minY, width: 0, height: max(0, maxY - minY))
    }

    private func guideX(for row: Int) -> CGFloat? {
        guard let index = insertionIndex else { return nil }
        let panes = docking.panes.filter { $0.visible && $0.row == row }
        guard !panes.isEmpty else { return nil }
        if index <= 0 { return frames[panes.first!.id]?.minX }
        if index >= panes.count { return frames[panes.last!.id]?.maxX }
        return frames[panes[index].id]?.minX
    }
}

// MARK: - Enhanced UI Components
private struct EnhancedSeparator: View {
    let height: CGFloat
    let isPulsing: Bool
    let useGlassEffect: Bool
    
    var body: some View {
        Rectangle()
            .fill(
                useGlassEffect ? 
                LinearGradient(
                    colors: [.clear, .white.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ) :
                LinearGradient(
                    colors: [.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: isPulsing ? 2 : 1, height: height)
            .opacity(isPulsing ? 0.8 : 0.3)
            .shadow(color: .blue.opacity(0.3), radius: isPulsing ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isPulsing)
    }
}

// Legacy separator for compatibility
private struct Separator: View { 
    let height: CGFloat
    var body: some View { 
        Rectangle().fill(Color.clear).frame(width: 1, height: height) 
    } 
}

// MARK: - Container Background Wrapper
private struct ContainerBackgroundWrapper<Content: View>: View {
    let content: Content
    let type: DockPaneType
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        if settings.shouldUseContainerBackground && type != .main {
            // Apply container background to playlist and equalizer for semantic grouping
            // Main window preserves Winamp chrome regardless of setting
            if #available(macOS 26.0, *) {
                content.containerBackground(.regularMaterial, for: .window)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        // Glass reflection overlay
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear, .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                content
            }
        } else {
            content
        }
    }
}

private extension View {
    func containerBackground(for type: DockPaneType) -> some View {
        ContainerBackgroundWrapper(content: self, type: type)
            .overlay(
                // Add subtle interaction glow for glass effect
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(type != .main ? 0.5 : 0)
            )
    }
}

private struct RowFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}
private struct RowFrameReader: View { let id: String; var body: some View { GeometryReader { proxy in Color.clear.preference(key: RowFramesKey.self, value: [id: proxy.frame(in: .named("dock2"))]) } } }

private struct Draggable2<Content: View>: View {
    let id: String
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    @ViewBuilder var content: () -> Content
    @GestureState private var drag: CGSize = .zero
    @State private var draggingID: String? = nil
    var body: some View {
        content()
            .offset(x: draggingID == id ? drag.width : 0, y: 0)
            .scaleEffect(draggingID == id ? 1.05 : 1.0)
            .shadow(
                color: draggingID == id ? .blue.opacity(0.4) : .clear,
                radius: draggingID == id ? 6 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggingID)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("dock2"))
                    .updating($drag) { value, state, _ in 
                        state = value.translation
                    }
                    .onChanged { value in 
                        if draggingID == nil { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                draggingID = id
                            }
                        }
                        onChanged(value.location)
                    }
                    .onEnded { _ in 
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            draggingID = nil
                        }
                        onEnded()
                    }
            )
    }
}
