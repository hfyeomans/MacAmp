import SwiftUI

/// Winamp coordinate constants (from original Winamp and webamp reference).
/// Used by all MainWindow child views for pixel-perfect absolute positioning.
enum WinampMainWindowLayout {
    // Transport buttons (all at y: 88)
    static let prevButton = CGPoint(x: 16, y: 88)
    static let playButton = CGPoint(x: 39, y: 88)
    static let pauseButton = CGPoint(x: 62, y: 88)
    static let stopButton = CGPoint(x: 85, y: 88)
    static let nextButton = CGPoint(x: 108, y: 88)
    static let ejectButton = CGPoint(x: 136, y: 89)

    // Time display
    static let timeDisplay = CGPoint(x: 39, y: 26)

    // Play/Pause indicator
    static let playPauseIndicator = CGPoint(x: 24, y: 28)

    // Track info display area (scrolling text)
    static let trackInfo = CGRect(x: 111, y: 27, width: 152, height: 11)

    // Spectrum analyzer (visualizer)
    static let spectrumAnalyzer = CGPoint(x: 24, y: 43)

    // Volume and Balance
    static let volumeSlider = CGPoint(x: 107, y: 57)
    static let balanceSlider = CGPoint(x: 177, y: 57)

    // Position slider
    static let positionSlider = CGPoint(x: 16, y: 72)

    // Shuffle/Repeat buttons (to the right of eject)
    static let shuffleButton = CGPoint(x: 164, y: 89)
    static let repeatButton = CGPoint(x: 211, y: 89)

    // EQ/Playlist buttons
    static let eqButton = CGPoint(x: 219, y: 58)
    static let playlistButton = CGPoint(x: 242, y: 58)

    // Titlebar buttons (at top)
    static let minimizeButton = CGPoint(x: 244, y: 3)
    static let shadeButton = CGPoint(x: 254, y: 3)
    static let closeButton = CGPoint(x: 264, y: 3)

    // Clutter bar (vertical button strip, left side)
    static let clutterBar = CGPoint(x: 10, y: 22)
    static let clutterButtonO = CGPoint(x: 10, y: 25)
    static let clutterButtonA = CGPoint(x: 10, y: 33)
    static let clutterButtonI = CGPoint(x: 10, y: 40)
    static let clutterButtonD = CGPoint(x: 10, y: 47)
    static let clutterButtonV = CGPoint(x: 10, y: 55)
}
