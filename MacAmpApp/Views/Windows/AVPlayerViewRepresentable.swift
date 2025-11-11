import SwiftUI
import AVKit

/// NSViewRepresentable wrapper for AVPlayerView (native video playback)
struct AVPlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none  // Use our VIDEO.bmp controls instead
        view.videoGravity = .resizeAspect  // Maintain aspect ratio
        view.showsFullScreenToggleButton = false  // No native fullscreen button
        view.showsSharingServiceButton = false  // No sharing button
        view.allowsPictureInPicturePlayback = false  // No PiP for now
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Update player if it changes
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
