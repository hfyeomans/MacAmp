import SwiftUI

/// Track info display with scrolling text using TEXT.bmp character sprites.
/// Only re-evaluates when displayTitle or scrollOffset changes.
struct MainWindowTrackInfoLayer: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    let interactionState: WinampMainWindowInteractionState

    private typealias Layout = WinampMainWindowLayout

    var body: some View {
        let trackText = playbackCoordinator.displayTitle.isEmpty ? "MacAmp" : playbackCoordinator.displayTitle
        let textWidth = trackText.count * 5
        let displayWidth = Int(Layout.trackInfo.width)

        if textWidth > displayWidth {
            HStack(spacing: 0) {
                buildTextSprites(for: trackText)
                    .offset(x: interactionState.scrollOffset, y: -2)
                    .onAppear { interactionState.startScrolling() }
                    .onChange(of: playbackCoordinator.displayTitle) { _, _ in interactionState.resetScrolling() }
            }
            .frame(width: Layout.trackInfo.width, height: Layout.trackInfo.height)
            .clipped()
            .at(CGPoint(x: Layout.trackInfo.minX, y: Layout.trackInfo.minY))
        } else {
            buildTextSprites(for: trackText)
                .offset(y: -2)
                .frame(width: Layout.trackInfo.width, height: Layout.trackInfo.height, alignment: .leading)
                .at(CGPoint(x: Layout.trackInfo.minX, y: Layout.trackInfo.minY))
        }
    }

    @ViewBuilder
    private func buildTextSprites(for text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, character in
                let charCode: UInt8 = {
                    if let ascii = character.asciiValue {
                        return character.isLetter && character.isUppercase ? ascii + 32 : ascii
                    }
                    return 32
                }()
                SimpleSpriteImage("CHARACTER_\(charCode)", width: 5, height: 6)
            }
        }
    }
}
