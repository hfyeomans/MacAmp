import Foundation
import SwiftUI

/// Window specifications matching original Winamp dimensions
struct WindowSpec {
    let size: CGSize
    let isResizable: Bool
    let minSize: CGSize?
    let maxSize: CGSize?
    
    // MARK: - Standard Winamp Window Sizes
    
    /// Main player window - 275×116 (classic Winamp size)
    static let main = WindowSpec(
        size: CGSize(width: 275, height: 116),
        isResizable: false,
        minSize: nil,
        maxSize: nil
    )
    
    /// Main window in shade mode - 275×14
    static let mainShade = WindowSpec(
        size: CGSize(width: 275, height: 14),
        isResizable: false,
        minSize: nil,
        maxSize: nil
    )
    
    /// Equalizer window - 275×116 (same as main)
    static let equalizer = WindowSpec(
        size: CGSize(width: 275, height: 116),
        isResizable: false,
        minSize: nil,
        maxSize: nil
    )
    
    /// Playlist window - resizable with quantized increments
    static let playlist = WindowSpec(
        size: CGSize(width: 275, height: 232), // Base size for ~8 tracks
        isResizable: true,
        minSize: CGSize(width: 275, height: 232),
        maxSize: CGSize(width: 550, height: 580) // Max ~20 tracks, double width
    )
    
    // MARK: - Layout Constants
    
    /// Height increment for playlist resizing (matches Winamp behavior)
    static let playlistRowHeight: CGFloat = 29
    
    /// Minimum playlist height (shows ~8 tracks)
    static let playlistMinRows: Int = 8
    
    /// Maximum practical playlist height  
    static let playlistMaxRows: Int = 20
    
    /// Snap distance for window docking (matches Webamp)
    static let snapDistance: CGFloat = 15
}

// MARK: - Convenience Extensions

extension WindowSpec {
    /// Calculate playlist height for given number of visible rows
    static func playlistHeight(forRows rows: Int) -> CGFloat {
        let clampedRows = max(playlistMinRows, min(rows, playlistMaxRows))
        return 232 + CGFloat(clampedRows - playlistMinRows) * playlistRowHeight
    }
    
    /// Calculate number of rows that fit in given playlist height
    static func playlistRows(forHeight height: CGFloat) -> Int {
        let extraHeight = height - 232
        let extraRows = Int(extraHeight / playlistRowHeight)
        return playlistMinRows + max(0, extraRows)
    }
}

// MARK: - Window Type Enumeration

enum WindowType: CaseIterable {
    case main
    case mainShade
    case equalizer
    case playlist
    
    var spec: WindowSpec {
        switch self {
        case .main: return .main
        case .mainShade: return .mainShade
        case .equalizer: return .equalizer
        case .playlist: return .playlist
        }
    }
    
    var title: String {
        switch self {
        case .main, .mainShade: return "Winamp"
        case .equalizer: return "Winamp Equalizer"  
        case .playlist: return "Winamp Playlist"
        }
    }
}
