import SwiftUI
import AppKit

/// Simple test version of MainWindow to verify sprite loading works
/// This replaces the complex broken MainWindowView for testing
struct SimpleTestMainWindow: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND", 
                            width: WinampSizes.main.width, 
                            height: WinampSizes.main.height)
            
            // Test some basic sprites at known positions
            VStack(alignment: .leading, spacing: 10) {
                Text("MacAmp - Sprite Test")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
                    .padding(5)
                
                HStack(spacing: 5) {
                    Text("Digits:")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                    
                    SimpleSpriteImage("DIGIT_0", width: 9, height: 13)
                    SimpleSpriteImage("DIGIT_1", width: 9, height: 13) 
                    SimpleSpriteImage("DIGIT_2", width: 9, height: 13)
                    SimpleSpriteImage("DIGIT_3", width: 9, height: 13)
                }
                .padding(.horizontal, 10)
                
                HStack(spacing: 5) {
                    Text("Transport:")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                        
                    Button(action: { audioPlayer.previousTrack() }) {
                        SimpleSpriteImage("MAIN_PREVIOUS_BUTTON", width: 23, height: 18)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { audioPlayer.play() }) {
                        SimpleSpriteImage("MAIN_PLAY_BUTTON", width: 23, height: 18)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { audioPlayer.pause() }) {
                        SimpleSpriteImage("MAIN_PAUSE_BUTTON", width: 23, height: 18)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { audioPlayer.stop() }) {
                        SimpleSpriteImage("MAIN_STOP_BUTTON", width: 23, height: 18)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { audioPlayer.nextTrack() }) {
                        SimpleSpriteImage("MAIN_NEXT_BUTTON", width: 23, height: 18)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                
                HStack(spacing: 5) {
                    Text("Titlebar:")
                        .foregroundColor(.white)
                        .font(.system(size: 10))
                        
                    SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
                    SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)  
                    SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
                }
                .padding(.horizontal, 10)
                
                Text("Current Track: \(audioPlayer.currentTitle)")
                    .foregroundColor(.white)
                    .font(.system(size: 10))
                    .padding(.horizontal, 10)
                    .lineLimit(1)
                    
                Spacer()
            }
        }
        .frame(width: WinampSizes.main.width, height: WinampSizes.main.height)
        .background(Color.black) // Fallback background
    }
}

#Preview {
    SimpleTestMainWindow()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
}