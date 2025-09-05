import Foundation
import SwiftUI

/// Central controller for unified-window docking state.
final class DockingController: ObservableObject {
    /// Visible panes
    @Published var showMain: Bool = true
    @Published var showPlaylist: Bool = false
    @Published var showEqualizer: Bool = false

    /// Docking parameters
    let snapDistance: CGFloat = 15

    func toggleMain() { showMain.toggle() }
    func togglePlaylist() { showPlaylist.toggle() }
    func toggleEqualizer() { showEqualizer.toggle() }
}

