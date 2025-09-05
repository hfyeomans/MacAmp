
import SwiftUI
import AppKit

struct EqualizerWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    // Auto follows AudioPlayer.eqAutoEnabled

    // Define the range for EQ sliders (typical Winamp range)
    let eqRange: ClosedRange<Float> = -12.0...12.0

    var body: some View {
        ZStack {
            if let skin = skinManager.currentSkin,
               let eqBackground = skin.images["EQ_WINDOW_BACKGROUND"],
               let eqSliderBackground = skin.images["EQ_SLIDER_BACKGROUND"],
               let eqSliderThumb = skin.images["EQ_SLIDER_THUMB"],
               let eqOnButton = skin.images[ audioPlayer.isEqOn ? "EQ_ON_BUTTON_SELECTED" : "EQ_ON_BUTTON" ] ?? skin.images["EQ_ON_BUTTON"],
               let eqAutoButton = skin.images[ audioPlayer.eqAutoEnabled ? "EQ_AUTO_BUTTON_SELECTED" : "EQ_AUTO_BUTTON" ] ?? skin.images["EQ_AUTO_BUTTON"],
               let eqGraphBg = skin.images["EQ_GRAPH_BACKGROUND"],
               let eqPreampLine = skin.images["EQ_PREAMP_LINE"],
               let eqPresetsBtn = skin.images["EQ_PRESETS_BUTTON"],
               let eqPresetsBtnSel = skin.images["EQ_PRESETS_BUTTON_SELECTED"] {

                Image(nsImage: eqBackground)
                    .interpolation(.none)
                    .antialiased(false)

                VStack {
                    Text("Equalizer")
                        .font(.title)
                        .padding()

                    HStack(spacing: 5) {
                        // Preamp Slider
                        EQSliderView(
                            background: eqSliderBackground,
                            thumb: eqSliderThumb,
                            value: $audioPlayer.preamp,
                            range: eqRange
                        )
                        .frame(width: eqSliderBackground.size.width / 10, height: eqSliderBackground.size.height) // Adjust frame as needed

                        // 10 EQ Bands
                        ForEach(0..<audioPlayer.eqBands.count, id: \.self) {
                            index in
                            EQSliderView(
                                background: eqSliderBackground,
                                thumb: eqSliderThumb,
                                value: Binding(
                                    get: { audioPlayer.eqBands[index] },
                                    set: { audioPlayer.setEqBand(index: index, value: $0) }
                                ),
                                range: eqRange
                            )
                            .frame(width: eqSliderBackground.size.width / 10, height: eqSliderBackground.size.height) // Adjust frame as needed
                        }
                    }
                    .padding()

                    // On/Off and Auto Buttons + EQF I/O
                    HStack(spacing: 8) {
                        Button(action: {
                            audioPlayer.toggleEq(isOn: !audioPlayer.isEqOn)
                        }) {
                            Image(nsImage: eqOnButton)
                                .resizable()
                                .frame(width: 26, height: 12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            audioPlayer.eqAutoEnabled.toggle()
                        }) {
                            Image(nsImage: eqAutoButton)
                                .resizable()
                                .frame(width: 32, height: 12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Presets popover button
                        PresetsButton(eqPresetsBtn: eqPresetsBtn, eqPresetsBtnSel: eqPresetsBtnSel)
                            .environmentObject(audioPlayer)
                            .environmentObject(skinManager)
                    }
                    .padding(.top, 10)

                    // EQ Graph (ticks + curve + preamp line)
                    EqGraphView(background: eqGraphBg, preampLine: eqPreampLine, lineColorsImage: skin.images["EQ_GRAPH_LINE_COLORS"])
                        .environmentObject(audioPlayer)
                    .padding(.top, 6)

                    // Auto-applied indicator (skinned banner)
                    if let trackName = audioPlayer.appliedAutoPresetTrack {
                        SkinnedBanner(fill: skin.images["GEN_BOTTOM_FILL"]) {
                            SkinnedText("Applied to: \(trackName)")
                                .environmentObject(skinManager)
                        }
                    }

                    Spacer()
                }
            } else {
                Text("Loading Skin...")
                    .frame(width: WindowSpec.equalizer.size.width, height: WindowSpec.equalizer.size.height)
                    .background(Color.gray)
            }
        }
        .frame(width: WindowSpec.equalizer.size.width, height: WindowSpec.equalizer.size.height)
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .equalizer)
        })
    }
}

#Preview {
    EqualizerWindowView()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
}
