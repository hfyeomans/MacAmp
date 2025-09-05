import Foundation
import SwiftUI

/// Sprite positioning constants ported from Webamp's main-window.css and skinSprites.ts
/// These define exactly where each UI element should be positioned on the main window
struct SpritePositions {
    
    // MARK: - Main Window Positions (from main-window.css)
    
    /// Play/Pause indicator position
    static let playPause = CGPoint(x: 26, y: 28)
    static let playPauseSize = CGSize(width: 9, height: 9)
    
    /// Time display position  
    static let timeDisplay = CGPoint(x: 39, y: 26)
    static let timeDisplaySize = CGSize(width: 59, height: 13)
    
    /// Transport control buttons (all at y: 88)
    static let previousButton = CGPoint(x: 16, y: 88)
    static let playButton = CGPoint(x: 39, y: 88)
    static let pauseButton = CGPoint(x: 62, y: 88)
    static let stopButton = CGPoint(x: 85, y: 88)
    static let nextButton = CGPoint(x: 108, y: 88)
    static let transportButtonSize = CGSize(width: 23, height: 18)
    
    /// Volume control
    static let volume = CGPoint(x: 107, y: 57)
    static let volumeSize = CGSize(width: 68, height: 13)
    
    /// Balance control  
    static let balance = CGPoint(x: 177, y: 57)
    static let balanceSize = CGSize(width: 38, height: 13)
    
    /// Position slider
    static let position = CGPoint(x: 16, y: 72)
    static let positionSize = CGSize(width: 248, height: 10)
    
    /// EQ button
    static let eqButton = CGPoint(x: 219, y: 58)
    static let eqButtonSize = CGSize(width: 23, height: 12)
    
    /// Playlist button
    static let plButton = CGPoint(x: 242, y: 58) 
    static let plButtonSize = CGSize(width: 23, height: 12)
    
    /// Shuffle button
    static let shuffleButton = CGPoint(x: 164, y: 89)
    static let shuffleButtonSize = CGSize(width: 47, height: 15)
    
    /// Repeat button  
    static let repeatButton = CGPoint(x: 210, y: 89)
    static let repeatButtonSize = CGSize(width: 28, height: 15)
    
    // MARK: - Title Bar (top of window)
    
    /// Minimize button
    static let minimizeButton = CGPoint(x: 244, y: 3)
    static let minimizeButtonSize = CGSize(width: 9, height: 9)
    
    /// Shade button
    static let shadeButton = CGPoint(x: 254, y: 3)
    static let shadeButtonSize = CGSize(width: 9, height: 9)
    
    /// Close button
    static let closeButton = CGPoint(x: 264, y: 3)
    static let closeButtonSize = CGSize(width: 9, height: 9)
    
    // MARK: - Sprite Sheet Coordinates (from skinSprites.ts)
    
    struct SpriteCoords {
        /// Transport button sprites from CBUTTONS.bmp
        static let previousButton = CGRect(x: 0, y: 0, width: 23, height: 18)
        static let previousButtonActive = CGRect(x: 0, y: 18, width: 23, height: 18)
        static let playButton = CGRect(x: 23, y: 0, width: 23, height: 18)
        static let playButtonActive = CGRect(x: 23, y: 18, width: 23, height: 18)
        static let pauseButton = CGRect(x: 46, y: 0, width: 23, height: 18)
        static let pauseButtonActive = CGRect(x: 46, y: 18, width: 23, height: 18)
        static let stopButton = CGRect(x: 69, y: 0, width: 23, height: 18)
        static let stopButtonActive = CGRect(x: 69, y: 18, width: 23, height: 18)
        static let nextButton = CGRect(x: 92, y: 0, width: 23, height: 18)
        static let nextButtonActive = CGRect(x: 92, y: 18, width: 23, height: 18)
        
        /// Number sprites from NUMBERS.bmp (each digit is 9x13)
        static let numberWidth: CGFloat = 9
        static let numberHeight: CGFloat = 13
        static let minusSign = CGRect(x: 20, y: 6, width: 5, height: 1)
        
        /// Volume/Balance from VOLUME.bmp and BALANCE.bmp
        static let volumeBackground = CGRect(x: 0, y: 0, width: 68, height: 420)
        static let volumeThumb = CGRect(x: 15, y: 422, width: 14, height: 11)
        static let balanceBackground = CGRect(x: 9, y: 0, width: 38, height: 420)
        static let balanceThumb = CGRect(x: 15, y: 422, width: 14, height: 11)
        
        /// Position slider from POSBAR.bmp
        static let positionBackground = CGRect(x: 0, y: 0, width: 248, height: 10)
        static let positionThumb = CGRect(x: 248, y: 0, width: 29, height: 10)
    }
}
