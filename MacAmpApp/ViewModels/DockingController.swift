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
                DockPaneState(type: .main, visible: true, isShaded: false, idealWidth: nil),
                DockPaneState(type: .playlist, visible: false, isShaded: false, idealWidth: nil),
                DockPaneState(type: .equalizer, visible: false, isShaded: false, idealWidth: nil)
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
        let targetOverallIndex = overallIndex(forVisibleIndex: targetVisibleIndex)
        guard targetOverallIndex != currentOverallIndex else { return }
        var new = panes
        let item = new.remove(at: currentOverallIndex)
        // Adjust target if removing before it
        let adjustedTarget = targetOverallIndex > currentOverallIndex ? targetOverallIndex - 1 : targetOverallIndex
        new.insert(item, at: max(0, min(new.count, adjustedTarget)))
        panes = new
    }

    private func overallIndex(forVisibleIndex vIndex: Int) -> Int {
        var count = 0
        for (i, p) in panes.enumerated() {
            if p.visible {
                if count == vIndex { return i }
                count += 1
            }
        }
        // If vIndex points after last visible, place at end
        return panes.count
    }
}
