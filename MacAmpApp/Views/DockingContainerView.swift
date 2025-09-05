import SwiftUI

/// Hosts Main, Playlist, and Equalizer panes in a single macOS window.
struct DockingContainerView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var docking: DockingController

    private let interPaneSpacing: CGFloat = 0
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var draggingID: String? = nil
    @State private var dragOffsetX: CGFloat = 0
    @State private var insertionIndex: Int? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: interPaneSpacing) {
                ForEach(visiblePanes()) { pane in
                    DraggablePane(
                        id: pane.id,
                        draggingID: $draggingID,
                        dragOffsetX: $dragOffsetX,
                        onDragChanged: { point in
                            updateInsertionIndex(with: point.x)
                        },
                        onDragEnded: {
                            commitReorderIfNeeded()
                        }
                    ) {
                        contentView(for: pane.type)
                    }
                    .background(PaneFrameReader(id: pane.id))
                }
            }
            .coordinateSpace(name: "dock")
            .onPreferenceChange(PaneFramesKey.self) { itemFrames = $0 }

            // Snap guide overlay
            if let guide = guideX() {
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1, height: maxPaneHeight())
                    .offset(x: guide, y: 0)
            }
        }
        .background(Color.black)
        .onAppear(perform: loadDefaultSkinIfNeeded)
    }

    private func loadDefaultSkinIfNeeded() {
        if skinManager.currentSkin == nil {
            var urlToLoad: URL? = Bundle.main.url(forResource: "Winamp", withExtension: "wsz")
            #if SWIFT_PACKAGE
            if urlToLoad == nil {
                urlToLoad = Bundle.module.url(forResource: "Winamp", withExtension: "wsz")
            }
            #endif
            if let skinURL = urlToLoad {
                skinManager.loadSkin(from: skinURL)
            }
        }
    }
}

#Preview {
    DockingContainerView()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(DockingController())
}

// MARK: - Helpers

extension DockingContainerView {
    private func visiblePanes() -> [DockPaneState] {
        docking.panes.filter { $0.visible }
    }

    @ViewBuilder
    private func contentView(for type: DockPaneType) -> some View {
        switch type {
        case .main:
            WinampMainWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        case .playlist:
            WinampPlaylistWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        case .equalizer:
            WinampEqualizerWindow()
                .environmentObject(skinManager)
                .environmentObject(audioPlayer)
        }
    }

    private func updateInsertionIndex(with dragX: CGFloat) {
        let panes = visiblePanes()
        guard !panes.isEmpty else { insertionIndex = nil; return }
        // Build ordered minX positions
        let xs: [CGFloat] = panes.compactMap { itemFrames[$0.id]?.minX }.sorted()
        guard xs.count == panes.count else { insertionIndex = nil; return }
        // Compute cut points between panes
        var cuts: [CGFloat] = []
        for i in 0..<xs.count {
            if i == 0 {
                cuts.append(xs[i])
            } else {
                let mid = (xs[i-1] + xs[i]) / 2.0
                cuts.append(mid)
            }
        }
        // Determine index: first cut with dragX < cut => that index, else at end
        var idx = xs.count
        for (i, cut) in cuts.enumerated() {
            if dragX < cut { idx = i; break }
        }
        insertionIndex = idx
    }

    private func commitReorderIfNeeded() {
        guard let draggingID, let insertionIndex else { resetDragState(); return }
        let panes = visiblePanes()
        guard let fromVisibleIndex = panes.firstIndex(where: { $0.id == draggingID }) else { resetDragState(); return }
        var target = insertionIndex
        // Adjust for removal if moving forward
        if insertionIndex > fromVisibleIndex { target -= 1 }
        if target != fromVisibleIndex && target >= 0 {
            if let type = panes.first(where: { $0.id == draggingID })?.type {
                docking.moveVisiblePane(type: type, toVisibleIndex: target)
            }
        }
        resetDragState()
    }

    private func resetDragState() {
        self.draggingID = nil
        self.dragOffsetX = 0
        self.insertionIndex = nil
    }

    private func guideX() -> CGFloat? {
        guard let insertionIndex else { return nil }
        let panes = visiblePanes()
        guard !panes.isEmpty else { return nil }
        if insertionIndex <= 0 { return itemFrames[panes.first!.id]?.minX }
        if insertionIndex >= panes.count { return itemFrames[panes.last!.id]?.maxX }
        let id = panes[insertionIndex].id
        return itemFrames[id]?.minX
    }

    private func maxPaneHeight() -> CGFloat {
        visiblePanes().compactMap { itemFrames[$0.id]?.height }.max() ?? WinampSizes.main.height
    }
}

// MARK: - Pane frame reporting

private struct PaneFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct PaneFrameReader: View {
    let id: String
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: PaneFramesKey.self, value: [id: proxy.frame(in: .named("dock"))])
        }
    }
}

// MARK: - Draggable wrapper

private struct DraggablePane<Content: View>: View {
    let id: String
    @Binding var draggingID: String?
    @Binding var dragOffsetX: CGFloat
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void
    @ViewBuilder var content: () -> Content

    @GestureState private var drag: CGSize = .zero

    var body: some View {
        content()
            .offset(x: active ? dragOffsetX : 0, y: 0)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("dock"))
                    .updating($drag) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { value in
                        if draggingID == nil { draggingID = id }
                        if draggingID == id {
                            dragOffsetX = value.translation.width
                            onDragChanged(value.location)
                        }
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
            .animation(.easeOut(duration: 0.15), value: draggingID)
    }

    private var active: Bool { draggingID == id }
}
