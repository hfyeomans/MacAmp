import Foundation
import SwiftUI
import Combine

/// A pane in the unified docking container
enum DockPaneType: String, Codable, CaseIterable, Identifiable {
    case main
    case playlist
    case equalizer
    var id: String { rawValue }
}

struct DockPaneState: Identifiable, Codable, Equatable {
    var type: DockPaneType
    var visible: Bool
    var isShaded: Bool
    var idealWidth: CGFloat?
    var widthsByRow: [Int: CGFloat]? // Optional per-row width persistence
    var row: Int // 0 = top, 1 = bottom
    var id: String { type.rawValue }
}

/// Central controller for unified-window docking state and persistence.
final class DockingController: ObservableObject {
    @Published var panes: [DockPaneState]

    /// Docking parameters
    let snapDistance: CGFloat = 15

    private let persistKey = "DockLayoutV1"
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let data = UserDefaults.standard.data(forKey: persistKey),
           let decoded = try? JSONDecoder().decode([DockPaneState].self, from: data),
           !decoded.isEmpty {
            self.panes = decoded
        } else {
            // Default order matches classic Winamp: Main | Playlist | Equalizer (only Main visible initially)
            self.panes = [
                DockPaneState(type: .main, visible: true, isShaded: false, idealWidth: nil, widthsByRow: nil, row: 0),
                DockPaneState(type: .playlist, visible: false, isShaded: false, idealWidth: nil, widthsByRow: nil, row: 1),
                DockPaneState(type: .equalizer, visible: false, isShaded: false, idealWidth: nil, widthsByRow: nil, row: 1)
            ]
        }

        $panes
            .dropFirst()
            .sink { [weak self] panes in
                guard let self else { return }
                if let data = try? JSONEncoder().encode(panes) {
                    UserDefaults.standard.set(data, forKey: self.persistKey)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Convenience flags used by menu commands
    var showMain: Bool { pane(for: .main)?.visible ?? false }
    var showPlaylist: Bool { pane(for: .playlist)?.visible ?? false }
    var showEqualizer: Bool { pane(for: .equalizer)?.visible ?? false }

    func toggleMain() { toggleVisibility(.main) }
    func togglePlaylist() { toggleVisibility(.playlist) }
    func toggleEqualizer() { toggleVisibility(.equalizer) }

    func toggleVisibility(_ type: DockPaneType) {
        guard let idx = panes.firstIndex(where: { $0.type == type }) else { return }
        panes[idx].visible.toggle()
    }

    func pane(for type: DockPaneType) -> DockPaneState? { panes.first(where: { $0.type == type }) }

    // MARK: - Reordering among visible panes
    func moveVisiblePane(type: DockPaneType, toVisibleIndex newVisibleIndex: Int) {
        guard let currentOverallIndex = panes.firstIndex(where: { $0.type == type }) else { return }
        movePane(fromOverallIndex: currentOverallIndex, toVisibleIndex: newVisibleIndex)
    }

    private func movePane(fromOverallIndex currentOverallIndex: Int, toVisibleIndex targetVisibleIndex: Int) {
        // Map visible index -> overall index
        let row = panes[currentOverallIndex].row
        let targetOverallIndex = overallIndex(forVisibleIndex: targetVisibleIndex, withinRow: row)
        guard targetOverallIndex != currentOverallIndex else { return }
        var new = panes
        let item = new.remove(at: currentOverallIndex)
        // Adjust target if removing before it
        let adjustedTarget = targetOverallIndex > currentOverallIndex ? targetOverallIndex - 1 : targetOverallIndex
        new.insert(item, at: max(0, min(new.count, adjustedTarget)))
        panes = new
    }

    private func overallIndex(forVisibleIndex vIndex: Int, withinRow row: Int? = nil) -> Int {
        var count = 0
        for (i, p) in panes.enumerated() {
            if p.visible && (row == nil || p.row == row) {
                if count == vIndex { return i }
                count += 1
            }
        }
        return panes.count
    }

    // MARK: - Shade
    func toggleShade(_ type: DockPaneType) {
        guard let idx = panes.firstIndex(where: { $0.type == type }) else { return }
        panes[idx].isShaded.toggle()
    }

    // MARK: - Move across rows
    func move(type: DockPaneType, toRow: Int, toVisibleIndex: Int) {
        guard let fromIndex = panes.firstIndex(where: { $0.type == type }) else { return }
        var item = panes.remove(at: fromIndex)
        item.row = toRow
        // Deterministic order for bottom row: Playlist left, Equalizer right
        let forceOrder = (toRow == 1)
        // Find start of target row in overall order
        let indicesInRow = panes.enumerated().filter { $0.element.row == toRow }
        let rowStart = indicesInRow.map { $0.offset }.min() ?? panes.count
        var insertAt = min(panes.count, max(rowStart, rowStart + toVisibleIndex))
        if forceOrder {
            if item.type == .playlist {
                insertAt = rowStart // always at leftmost
            } else if item.type == .equalizer {
                // place after any playlist present in row
                let playlistsInRow = indicesInRow.filter { $0.element.type == .playlist }
                if let lastPlaylist = playlistsInRow.map({ $0.offset }).max() {
                    insertAt = lastPlaylist + 1
                }
            }
        }
        panes.insert(item, at: insertAt)
    }

    // MARK: - Persist width for specific row
    func setWidth(_ type: DockPaneType, row: Int, width: CGFloat) {
        guard let idx = panes.firstIndex(where: { $0.type == type }) else { return }
        if panes[idx].widthsByRow == nil { panes[idx].widthsByRow = [:] }
        panes[idx].widthsByRow?[row] = width
        // Maintain legacy idealWidth for compatibility
        panes[idx].idealWidth = width
    }
}
