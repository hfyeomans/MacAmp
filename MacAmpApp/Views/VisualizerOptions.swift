import SwiftUI

struct VisualizerOptions: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @State private var show = false

    var body: some View {
        VStack(spacing: 4) {
            Button(show ? "Hide Options" : "Options") { show.toggle() }
                .font(.system(size: 10))
            if show {
                HStack(spacing: 8) {
                    Toggle("Spec", isOn: $audioPlayer.useSpectrumVisualizer)
                        .toggleStyle(.switch)
                        .labelsHidden()
                    Toggle("Log", isOn: $audioPlayer.useLogScaleBands)
                        .toggleStyle(.switch)
                        .labelsHidden()
                    HStack(spacing: 4) {
                        Text("Sm").font(.system(size: 9))
                        Slider(value: Binding(get: {
                            Double(audioPlayer.visualizerSmoothing)
                        }, set: { audioPlayer.visualizerSmoothing = Float($0) }), in: 0...0.95)
                            .frame(width: 80)
                    }
                    HStack(spacing: 4) {
                        Text("Pk").font(.system(size: 9))
                        Slider(value: Binding(get: {
                            Double(audioPlayer.visualizerPeakFalloff)
                        }, set: { audioPlayer.visualizerPeakFalloff = Float($0) }), in: 0...2)
                            .frame(width: 80)
                    }
                }
            }
        }
    }
}

