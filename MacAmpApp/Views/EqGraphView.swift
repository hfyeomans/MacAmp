import SwiftUI
import AppKit

struct EqGraphView: View {
    let background: NSImage
    let preampLine: NSImage
    let lineColors: [Color]?
    @EnvironmentObject var audioPlayer: AudioPlayer

    init(background: NSImage, preampLine: NSImage, lineColorsImage: NSImage? = nil) {
        self.background = background
        self.preampLine = preampLine
        if let img = lineColorsImage {
            self.lineColors = EqGraphView.extractVerticalColors(from: img)
        } else {
            self.lineColors = nil
        }
    }

    private static func extractVerticalColors(from image: NSImage) -> [Color] {
        guard let rep = NSBitmapImageRep(data: image.tiffRepresentation!) else { return [] }
        var colors: [Color] = []
        let h = Int(rep.pixelsHigh)
        let x = min(0, Int(rep.pixelsWide - 1))
        for y in 0..<h {
            if let nsColor = rep.colorAt(x: x, y: y) {
                colors.append(Color(nsColor: nsColor))
            }
        }
        return colors
    }

    private func yForDB(_ db: Float, height: CGFloat) -> CGFloat {
        let percent = CGFloat((db + 12.0) / 24.0)
        return max(0, min(height - 1, (1 - percent) * (height - 1)))
    }

    private func colorForY(_ y: CGFloat, height: CGFloat) -> Color {
        guard let strip = lineColors, !strip.isEmpty else { return .white }
        let idx = Int(round((y / max(1, height - 1)) * CGFloat(strip.count - 1)))
        return strip[min(max(idx, 0), strip.count - 1)]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: background)
                .resizable()
                .frame(width: background.size.width, height: background.size.height)

            Canvas { ctx, size in
                let h = size.height
                let w = size.width
                let bands = audioPlayer.eqBands
                guard !bands.isEmpty else { return }

                // Tick marks and curve points
                let count = bands.count
                var points: [CGPoint] = []
                for i in 0..<count {
                    let x = CGFloat(i) / CGFloat(count - 1) * (w - 1)
                    let y = yForDB(bands[i], height: h)
                    points.append(CGPoint(x: x, y: y))
                    // Draw tick
                    var tick = Path()
                    tick.addRect(CGRect(x: x.rounded(), y: h - 3, width: 1, height: 3))
                    let tickColor = colorForY(y, height: h).opacity(0.8)
                    ctx.fill(tick, with: .color(tickColor))
                }

                // Draw curve in colored segments based on Y
                if points.count >= 2 {
                    for i in 1..<points.count {
                        let p0 = points[i - 1]
                        let p1 = points[i]
                        let midY = (p0.y + p1.y) / 2
                        let color = colorForY(midY, height: h)
                        var seg = Path()
                        seg.move(to: p0)
                        seg.addLine(to: p1)
                        ctx.stroke(seg, with: .color(color), lineWidth: 1)
                    }
                }
            }
            .frame(width: background.size.width, height: background.size.height)

            // Preamp horizontal line
            let h = background.size.height
            let y = yForDB(audioPlayer.preamp, height: h)
            Image(nsImage: preampLine)
                .resizable()
                .frame(width: preampLine.size.width, height: preampLine.size.height)
                .offset(x: 0, y: y)
        }
    }
}
