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
    var id: String { type.rawValue }
    
    // Computed position for vertical stacking
    var position: Int {
        switch type {
        case .main: return 0      // Always top
        case .equalizer: return 1 // Always second when visible
        case .playlist: return 2  // Always third when visible
        }
    }
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
            // Default vertical stack: Main -> Equalizer -> Playlist (only Main visible initially)
            self.panes = [
                DockPaneState(type: .main, visible: true, isShaded: false),
                DockPaneState(type: .equalizer, visible: false, isShaded: false),
                DockPaneState(type: .playlist, visible: false, isShaded: false)
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

    // MARK: - Get sorted visible panes for vertical stack
    var sortedVisiblePanes: [DockPaneState] {
        panes
            .filter { $0.visible }
            .sorted { $0.position < $1.position }
    }

    // MARK: - Shade
    func toggleShade(_ type: DockPaneType) {
        guard let idx = panes.firstIndex(where: { $0.type == type }) else { return }
        panes[idx].isShaded.toggle()
    }

    // MARK: - Window arrangement helpers
    func getVisibleWindowsInOrder() -> [DockPaneType] {
        sortedVisiblePanes.map { $0.type }
    }
    
    func isEqualizerBetweenMainAndPlaylist() -> Bool {
        let visible = getVisibleWindowsInOrder()
        guard visible.count == 3 else { return false }
        return visible[0] == .main && visible[1] == .equalizer && visible[2] == .playlist
    }
}
