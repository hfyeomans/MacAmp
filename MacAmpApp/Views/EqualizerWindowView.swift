
import SwiftUI
import AppKit

struct EqualizerWindowView: View {
    @EnvironmentObject var skinManager: SkinManager
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var settings: AppSettings
    
    // Define the range for EQ sliders (typical Winamp range)
    let eqRange: ClosedRange<Float> = -12.0...12.0
    
    // MARK: - Whimsy & Animation States
    @State private var sliderGlows: Set<Int> = []
    @State private var eqVisualization: [Float] = Array(repeating: 0.0, count: 10)
    @State private var graphPulse: Bool = false
    @State private var preampGlow: Bool = false
    @State private var buttonHovers: Set<String> = []

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
                        .conditionalSemanticText(enabled: settings.shouldUseContainerBackground)
                        .overlay(
                            // Glass shimmer effect on title
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .opacity(settings.shouldUseContainerBackground ? 0.6 : 0)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: settings.shouldUseContainerBackground
                            )
                            .allowsHitTesting(false)
                        )

                    HStack(spacing: 5) {
                        // Preamp Slider with special glow
                        EQSliderView(
                            background: eqSliderBackground,
                            thumb: eqSliderThumb,
                            value: $audioPlayer.preamp,
                            range: eqRange
                        )
                        .environmentObject(skinManager)
                        .frame(width: 14, height: 62)  // Correct Winamp specs: 14px wide, 62px active area
                        .overlay(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .yellow.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .opacity(preampGlow ? 0.8 : 0)
                                .animation(.easeInOut(duration: 0.3), value: preampGlow)
                                .allowsHitTesting(false)
                        )
                        .onChange(of: audioPlayer.preamp) { _, _ in
                            triggerPreampGlow()
                        }

                        // 10 EQ Bands with individual glow effects
                        ForEach(0..<audioPlayer.eqBands.count, id: \.self) { index in
                            EQSliderView(
                                background: eqSliderBackground,
                                thumb: eqSliderThumb,
                                value: Binding(
                                    get: { audioPlayer.eqBands[index] },
                                    set: { newValue in
                                        audioPlayer.setEqBand(index: index, value: newValue)
                                        triggerSliderGlow(index: index)
                                    }
                                ),
                                range: eqRange
                            )
                            .environmentObject(skinManager)
                            .frame(width: 14, height: 62)  // Correct Winamp specs: 14px wide, 62px active area
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .clear,
                                                sliderColor(for: index).opacity(0.4),
                                                .clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(sliderGlows.contains(index) ? 1.0 : 0.2)
                                    .animation(.easeInOut(duration: 0.3), value: sliderGlows.contains(index))
                                    .allowsHitTesting(false)
                            )
                            .scaleEffect(sliderGlows.contains(index) ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sliderGlows.contains(index))
                        }
                    }
                    .padding()

                    // On/Off and Auto Buttons + EQF I/O
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                audioPlayer.toggleEq(isOn: !audioPlayer.isEqOn)
                                triggerGraphPulse()
                            }
                        }) {
                            Image(nsImage: eqOnButton)
                                .resizable()
                                .frame(width: 26, height: 12)
                                .scaleEffect(buttonHovers.contains("eq-on") ? 1.1 : 1.0)
                                .shadow(
                                    color: audioPlayer.isEqOn ? .green.opacity(0.6) : .gray.opacity(0.3),
                                    radius: audioPlayer.isEqOn ? 3 : 1
                                )
                        }
                        .conditionalEqButtonStyle(enabled: settings.shouldUseContainerBackground)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("eq-on") } else { buttonHovers.remove("eq-on") }
                            }
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                audioPlayer.eqAutoEnabled.toggle()
                            }
                        }) {
                            Image(nsImage: eqAutoButton)
                                .resizable()
                                .frame(width: 32, height: 12)
                                .scaleEffect(buttonHovers.contains("eq-auto") ? 1.1 : 1.0)
                                .shadow(
                                    color: audioPlayer.eqAutoEnabled ? .blue.opacity(0.6) : .gray.opacity(0.3),
                                    radius: audioPlayer.eqAutoEnabled ? 3 : 1
                                )
                        }
                        .conditionalEqButtonStyle(enabled: settings.shouldUseContainerBackground)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if hovering { buttonHovers.insert("eq-auto") } else { buttonHovers.remove("eq-auto") }
                            }
                        }

                        // Presets popover button
                        PresetsButton(eqPresetsBtn: eqPresetsBtn, eqPresetsBtnSel: eqPresetsBtnSel)
                            .environmentObject(audioPlayer)
                            .environmentObject(skinManager)
                    }
                    .padding(.top, 10)

                    // EQ Graph with pulse effect
                    EqGraphView(
                        background: eqGraphBg, 
                        preampLine: eqPreampLine, 
                        lineColorsImage: skin.images["EQ_GRAPH_LINE_COLORS"]
                    )
                    .environmentObject(audioPlayer)
                    .padding(.top, 6)
                    .scaleEffect(graphPulse ? 1.02 : 1.0)
                    .overlay(
                        Rectangle()
                            .stroke(
                                LinearGradient(
                                    colors: [.clear, .cyan.opacity(0.4), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                            .opacity(graphPulse ? 0.8 : 0)
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: graphPulse)

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
        .background(semanticBackground)
        .background(WindowAccessor { window in
            WindowSnapManager.shared.register(window: window, kind: .equalizer)
        })
        .onReceive(audioPlayer.$isEqOn) { isOn in
            if isOn {
                triggerGraphPulse()
            }
        }
        .onAppear {
            startVisualizationTimer()
        }
    }
    
    // MARK: - Whimsy Helper Functions
    private func triggerSliderGlow(index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = sliderGlows.insert(index)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                _ = sliderGlows.remove(index)
            }
        }
    }
    
    private func triggerPreampGlow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            preampGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                preampGlow = false
            }
        }
    }
    
    private func triggerGraphPulse() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            graphPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                graphPulse = false
            }
        }
    }
    
    private func sliderColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .mint, .indigo]
        return colors[index % colors.count]
    }
    
    private func startVisualizationTimer() {
        // Audio-reactive EQ visualization (simplified)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak audioPlayer] _ in
            Task { @MainActor in
                guard let audioPlayer = audioPlayer else { return }
                if audioPlayer.isPlaying && audioPlayer.isEqOn {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        eqVisualization = eqVisualization.map { _ in Float.random(in: 0...1) }
                    }
                }
            }
        }
    }
    
    // MARK: - Liquid Glass Background
    @ViewBuilder
    private var semanticBackground: some View {
        if settings.shouldUseContainerBackground {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.6)
                    .overlay(
                        // Audio-reactive background glow
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .purple.opacity(0.1),
                                        .blue.opacity(0.05),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 150
                                )
                            )
                            .opacity(audioPlayer.isPlaying && audioPlayer.isEqOn ? 0.8 : 0.3)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                     value: audioPlayer.isPlaying && audioPlayer.isEqOn)
                    )
            } else {
                Color.clear
            }
        } else {
            Color.clear
        }
    }
}

// MARK: - Liquid Glass Integration Extensions

private extension View {
    @ViewBuilder
    func conditionalSemanticText(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.foregroundStyle(.primary)
            } else {
                self
            }
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalEqButtonStyle(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.buttonStyle(.borderless)
                    .controlSize(.small)
            } else {
                self.buttonStyle(PlainButtonStyle())
            }
        } else {
            self.buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    EqualizerWindowView()
        .environmentObject(SkinManager())
        .environmentObject(AudioPlayer())
        .environmentObject(AppSettings.instance())
}
