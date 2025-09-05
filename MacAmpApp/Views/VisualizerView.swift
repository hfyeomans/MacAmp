import SwiftUI

struct VisualizerView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var skinManager: SkinManager

    var body: some View {
        GeometryReader { geo in
            let levels = audioPlayer.visualizerLevels
            // Peak markers derived implicitly from AudioPlayer (approximate via max tracking)
            let count = max(1, levels.count)
            let spacing: CGFloat = 1
            let totalSpacing = spacing * CGFloat(count - 1)
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(count))
            let bg = (skinManager.currentSkin?.playlistStyle.backgroundColor ?? .black).opacity(0.6)
            let palette = skinManager.currentSkin?.visualizerColors ?? []

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let valueF = min(max(levels[i], 0), 1)
                    let value = CGFloat(valueF)
                    let height = max(1, value * geo.size.height)
                    let color: Color = palette.isEmpty ? .green : palette[min(palette.count - 1, Int(value * CGFloat(palette.count - 1)))]
                    Rectangle()
                        .fill(color)
                        .frame(width: barWidth, height: height)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: barWidth, height: 1)
                                .offset(y: -(max(1, CGFloat(min(1.0, valueF + 0.1)) * geo.size.height)))
                        , alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(bg)
        }
    }
}
