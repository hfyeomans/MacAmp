import SwiftUI
import AppKit

struct UnifiedDockView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var docking: DockingController

    private let snapDistance: CGFloat = 15
    @State private var frames: [String: CGRect] = [:]
    @State private var draggingID: String? = nil
    @State private var dragOffsetX: CGFloat = 0
    @State private var insertionIndex: Int? = nil
    @State private var insertionRow: Int? = nil

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
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1, height: rf.height)
                        .offset(x: guideX, y: rf.minY)
                }
            }
            // Keep the whole canvas left-aligned; outer window can be larger
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.black)
        .onAppear(perform: ensureSkin)
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
                }
                .background(RowFrameReader(id: pane.id))

                if idx < panes.count - 1 { Separator(height: height(for: pane)) }
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
        // Do not stretch to container width. Use persisted idealWidth if present; otherwise natural size.
        let w = pane.idealWidth ?? naturalSize(for: pane.type).width
        return max(w, naturalSize(for: pane.type).width)
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
        guard let id = draggingID, let row = insertionRow, let idx = insertionIndex else { draggingID=nil; insertionIndex=nil; insertionRow=nil; return }
        guard let type = docking.panes.first(where: { $0.id == id })?.type else { return }
        docking.move(type: type, toRow: row, toVisibleIndex: idx)
        draggingID=nil; insertionIndex=nil; insertionRow=nil
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

// MARK: - Helpers
private struct Separator: View { let height: CGFloat; var body: some View { Rectangle().fill(Color.clear).frame(width: 1, height: height) } }

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
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("dock2"))
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onChanged { value in if draggingID == nil { draggingID = id }; onChanged(value.location) }
                    .onEnded { _ in draggingID = nil; onEnded() }
            )
    }
}
