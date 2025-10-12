import SwiftUI
import AppKit

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
    @State private var hoveredSeparatorIndex: Int? = nil
    @State private var resizingSeparatorIndex: Int? = nil
    private let snapDistance: CGFloat = 15
    private let windowFrameKey = "DockWindowFrameV1"
    @State private var hostWindow: NSWindow?
    @State private var observersInstalled: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(alignment: .top, spacing: interPaneSpacing) {
                    let panes = visiblePanes()
                    ForEach(Array(panes.enumerated()), id: \.element.id) { (idx, pane) in
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
                                .frame(
                                    width: widthForPane(pane, containerWidth: geo.size.width),
                                    height: heightForPane(pane)
                                )
                                .overlay(targetOverlay(for: pane))
                        }
                        .background(PaneFrameReader(id: pane.id))

                        // Resizer handle between panes
                        if idx < panes.count - 1 {
                            let active = (hoveredSeparatorIndex == idx) || (resizingSeparatorIndex == idx)
                            ResizerBar(active: active)
                                .frame(width: active ? 3 : 1, height: heightForPane(pane))
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    hoveredSeparatorIndex = hovering ? idx : nil
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("dock"))
                                        .onChanged { value in
                                            resizingSeparatorIndex = idx
                                            resizeBetween(left: panes[idx], right: panes[idx+1], delta: value.translation.width, containerWidth: geo.size.width)
                                        }
                                        .onEnded { _ in
                                            resizingSeparatorIndex = nil
                                        }
                                )
                        }
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
            .onAppear {
                loadDefaultSkinIfNeeded()
                restoreWindowFrameIfAvailable()
            }
            .onChange(of: geo.size) { _, _ in
                saveWindowFrame()
            }
        }
        .background(Color.black)
        .background(WindowAccessor { window in
            self.hostWindow = window
            if !observersInstalled {
                NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { _ in
                    saveWindowFrame()
                }
                NotificationCenter.default.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { _ in
                    saveWindowFrame()
                }
                observersInstalled = true
            }
        })
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
        // Build ordered boundaries: first minX, mids, last maxX
        guard let firstX = itemFrames[panes.first!.id]?.minX,
              let lastMax = itemFrames[panes.last!.id]?.maxX else { insertionIndex = nil; return }
        var boundaries: [CGFloat] = [firstX]
        for i in 1..<panes.count {
            if let left = itemFrames[panes[i-1].id]?.minX, let right = itemFrames[panes[i].id]?.minX {
                boundaries.append((left + right) / 2.0)
            }
        }
        boundaries.append(lastMax)
        // Snap only if within snapDistance of any boundary
        let nearest = boundaries.min(by: { abs($0 - dragX) < abs($1 - dragX) })
        guard let nearestBoundary = nearest, abs(nearestBoundary - dragX) <= snapDistance else {
            insertionIndex = nil; return
        }
        // Compute index by counting boundaries strictly greater than dragX
        var idx = panes.count
        for (i, b) in boundaries.enumerated() where i < panes.count {
            if dragX < b { idx = i; break }
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
        // Vertical stacking - no reordering needed
        // Windows now stack in fixed order: Main -> EQ -> Playlist
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

// MARK: - Width/Height and overlays

extension DockingContainerView {
    private func naturalSize(for type: DockPaneType) -> CGSize {
        switch type {
        case .main: return WinampSizes.main
        case .playlist: return CGSize(width: WinampSizes.playlistBase.width, height: WinampSizes.playlistBase.height)
        case .equalizer: return WinampSizes.equalizer
        }
    }

    private func shadeHeight(for type: DockPaneType) -> CGFloat { 14 }

    private func heightForPane(_ pane: DockPaneState) -> CGFloat {
        pane.isShaded ? shadeHeight(for: pane.type) : naturalSize(for: pane.type).height
    }

    private func widthForPane(_ pane: DockPaneState, containerWidth: CGFloat) -> CGFloat {
        // Sum natural widths of visible panes
        let panes = visiblePanes()
        let naturalSum = panes.reduce(CGFloat(0)) { $0 + naturalSize(for: $1.type).width }
        let extra = max(0, containerWidth - naturalSum)
        // Prefer giving extra to playlist; else the last visible pane
        if let playlist = panes.first(where: { $0.type == .playlist }) {
            if playlist.id == pane.id { return naturalSize(for: pane.type).width + extra }
        } else if pane.id == panes.last?.id {
            return naturalSize(for: pane.type).width + extra
        }
        return naturalSize(for: pane.type).width
    }

    @ViewBuilder
    private func targetOverlay(for pane: DockPaneState) -> some View {
        if let insertionIndex, let targetID = targetPaneID(for: insertionIndex), targetID == pane.id {
            Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1)
        } else {
            EmptyView()
        }
    }

    private func targetPaneID(for index: Int) -> String? {
        let panes = visiblePanes()
        guard !panes.isEmpty else { return nil }
        if index <= 0 { return panes.first?.id }
        if index >= panes.count { return panes.last?.id }
        return panes[index].id
    }
}

// MARK: - Window size persistence

extension DockingContainerView {
    private func saveWindowFrame() {
        guard let win = hostWindow else { return }
        let frame = win.frame
        let dict: [String: CGFloat] = ["x": frame.origin.x, "y": frame.origin.y, "w": frame.size.width, "h": frame.size.height]
        UserDefaults.standard.set(dict, forKey: windowFrameKey)
    }

    private func restoreWindowFrameIfAvailable() {
        guard let dict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat],
              let x = dict["x"], let y = dict["y"], let w = dict["w"], let h = dict["h"],
              let win = hostWindow else { return }
        let newFrame = NSRect(x: x, y: y, width: w, height: h)
        win.setFrame(newFrame, display: true)
    }
}

// MARK: - Resizing support

extension DockingContainerView {
    private func resizeBetween(left: DockPaneState, right: DockPaneState, delta: CGFloat, containerWidth: CGFloat) {
        let leftCurrent = widthForPane(left, containerWidth: containerWidth)
        let rightCurrent = widthForPane(right, containerWidth: containerWidth)
        let minLeft = naturalSize(for: left.type).width
        let minRight = naturalSize(for: right.type).width
        var newLeft = max(minLeft, leftCurrent + delta)
        var newRight = max(minRight, rightCurrent - delta)
        // If pushing beyond min on one side, clamp and adjust counterpart
        if newLeft == minLeft { newRight = leftCurrent + rightCurrent - newLeft }
        if newRight == minRight { newLeft = leftCurrent + rightCurrent - newRight }
        dockingSetWidth(left.type, newLeft)
        dockingSetWidth(right.type, newRight)
    }

    private func dockingSetWidth(_ type: DockPaneType, _ width: CGFloat) {
        // Width is fixed in vertical stacking - all windows use standard Winamp width
        // No need to persist width changes
    }
}

// MARK: - Resizer bar visual

private struct ResizerBar: View {
    var active: Bool
    @State private var pulse: Bool = false
    var body: some View {
        Rectangle()
            .fill(active ? Color.white.opacity(0.5) : Color.clear)
            .overlay(Rectangle().stroke(Color.white.opacity(active ? 0.7 : 0.2), lineWidth: active ? 1 : 0.5))
            .shadow(color: Color.white.opacity(active ? (pulse ? 0.5 : 0.2) : 0.0), radius: active ? (pulse ? 3 : 1) : 0)
            .onAppear {
                if active {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse.toggle()
                    }
                }
            }
    }
}
