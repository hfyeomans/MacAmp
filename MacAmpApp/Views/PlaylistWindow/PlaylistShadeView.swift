import SwiftUI

/// The 14 px shade strip with the current title and length in TEXT.BMP characters (Webamp `PlaylistShade`).
struct PlaylistShadeView: View {
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(SkinManager.self) private var skinManager

    let windowWidth: CGFloat
    let isWindowActive: Bool
    let sizeState: PlaylistWindowSizeState
    @Binding var dragStartSize: Size2D?
    @Binding var isDragging: Bool
    let resizePreview: WindowResizePreviewOverlay
    let onShadeToggle: () -> Void
    let onClose: () -> Void

    private let characterWidth: CGFloat = 5

    var body: some View {
        ZStack(alignment: .topLeading) {
            WinampTitlebarDragHandle(windowKind: .playlist, size: CGSize(width: windowWidth, height: 14)) {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<Int((windowWidth - 75) / 25), id: \.self) { i in
                        SimpleSpriteImage("PLAYLIST_SHADE_BACKGROUND", width: 25, height: 14)
                            .offset(x: 25 + CGFloat(i) * 25)
                    }
                    SimpleSpriteImage("PLAYLIST_SHADE_BACKGROUND_LEFT", width: 25, height: 14)
                    SimpleSpriteImage(isWindowActive ? "PLAYLIST_SHADE_BACKGROUND_RIGHT_SELECTED" : "PLAYLIST_SHADE_BACKGROUND_RIGHT",
                                      width: 50, height: 14)
                        .offset(x: windowWidth - 50)
                }
            }

            let name = trackName
            characters(trimmed(name ?? "[No file]"))
                .offset(x: 5, y: 4)
                .allowsHitTesting(false)

            if name != nil {
                let time = TimeFormatting.formatDuration(playbackCoordinator.displayDuration)
                characters(time)
                    .offset(x: windowWidth - 30 - CGFloat(time.count) * characterWidth, y: 4)
                    .allowsHitTesting(false)
            }

            PlaylistResizeHandle(windowWidth: windowWidth, windowHeight: WinampSizes.playlistShade.height,
                                 sizeState: sizeState, dragStartSize: $dragStartSize, isDragging: $isDragging,
                                 resizePreview: resizePreview, widthOnly: true)

            PlaylistTitleBarButtons(windowWidth: windowWidth, shaded: true,
                                    onShadeToggle: onShadeToggle, onClose: onClose)
        }
        .frame(width: windowWidth, height: 14, alignment: .topLeading)
    }

    private var trackName: String? {
        playbackCoordinator.currentTrack == nil ? nil : playbackCoordinator.displayTitle
    }

    /// Room for 205 px of text at the minimum width, growing with the window.
    private func trimmed(_ name: String) -> String {
        let limit = Int((205 + windowWidth - 275) / characterWidth)
        return name.count > limit ? String(name.prefix(limit - 1)) + "…" : name
    }

    private func characters(_ text: String) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                let glyph = character.isASCII ? Character(character.lowercased()) : character
                let code = String(glyph).utf16.first ?? 32
                // Characters TEXT.BMP doesn't have render as spaces.
                SimpleSpriteImage("CHARACTER_\(skinManager.currentSkin?.images["CHARACTER_\(code)"] != nil ? code : 32)",
                                  width: 5, height: 6)
            }
        }
    }
}
