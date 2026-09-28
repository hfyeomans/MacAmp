import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Pixel-perfect recreation of Winamp's equalizer window using absolute positioning
struct WinampEqualizerWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(AppSettings.self) var settings
    @Environment(PlaybackCoordinator.self) var playbackCoordinator
    @Environment(WindowFocusState.self) var windowFocusState
    @State private var showPresetPicker: Bool = false

    // Computed: Is this window currently focused?
    private var isWindowActive: Bool {
        windowFocusState.isEqualizerKey
    }

    // Winamp EQ coordinate constants (CORRECTED from webamp reference)
    private struct EQCoords {
        // Preamp slider (leftmost) - CORRECTED
        static let preampSlider = CGPoint(x: 21, y: 38)
        
        // 10-band EQ sliders - CORRECTED positions from webamp  
        static let eqSliderPositions: [CGFloat] = [78, 96, 114, 132, 150, 168, 186, 204, 222, 240]
        static let eqSliderY: CGFloat = 38
        
        // ON/AUTO buttons - CORRECTED
        static let onButton = CGPoint(x: 14, y: 18)
        static let autoButton = CGPoint(x: 40, y: 18)  // Adjusted spacing
        
        // Presets button - CORRECTED
        static let presetsButton = CGPoint(x: 217, y: 18)
        
        // Titlebar buttons
        static let shadeButton = CGPoint(x: 254, y: 3) 
        static let closeButton = CGPoint(x: 264, y: 3)

        // Shade-strip slider wells
        static let shadeVolume = CGPoint(x: 61, y: 4)
        static let shadeVolumeWidth: CGFloat = 97
        static let shadeBalance = CGPoint(x: 164, y: 4)
        static let shadeBalanceWidth: CGFloat = 43
        
        // EQ curve graph area - CORRECTED
        static let graphArea = CGPoint(x: 86, y: 17)
    }

    private func importPresetFromFile() {
        let panel = NSOpenPanel()
        if let eqfType = UTType(filenameExtension: "eqf") {
            panel.allowedContentTypes = [eqfType]
        }
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                audioPlayer.importEqfPreset(from: url)
                showPresetPicker = false
            }
        }
    }
    
    // EQ slider specs - CORRECTED to match webamp exactly
    private let sliderWidth: CGFloat = 14  // CORRECTED: Each slider is 14px wide
    private let sliderHeight: CGFloat = 62  // CORRECTED: 62px active area (not 63)
    private let thumbWidth: CGFloat = 11
    private let thumbHeight: CGFloat = 11
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if !settings.isEqualizerWindowShaded {
                // Full window mode
                // Background - The EQMAIN sprite includes preamp text and frequency labels
                SimpleSpriteImage("EQ_WINDOW_BACKGROUND",
                                width: WinampSizes.equalizer.width,
                                height: WinampSizes.equalizer.height)

                // Title bar - apply .at() to drag handle itself for proper positioning
                WinampTitlebarDragHandle(windowKind: .equalizer, size: CGSize(width: 275, height: 14)) {
                    SimpleSpriteImage(isWindowActive ? "EQ_TITLE_BAR_SELECTED" : "EQ_TITLE_BAR",
                                    width: 275,
                                    height: 14)
                }
                .at(CGPoint(x: 0, y: 0))

                // Titlebar buttons (always active, never dimmed)
                buildTitlebarButtons(shaded: false)

                // EQ controls (dimmed briefly during stream prebuffering before bridge activates)
                Group {
                    // ON/AUTO buttons
                    buildControlButtons()

                    // Preamp slider
                    buildPreampSlider()

                    // 10-band EQ sliders
                    buildEQSliders()

                    // Presets button
                    buildPresetsButton()

                    // EQ curve visualization (simplified for now)
                    buildEQCurve()
                }
                .opacity(playbackCoordinator.supportsAudioProcessing ? 1.0 : 0.5)
                .allowsHitTesting(playbackCoordinator.supportsAudioProcessing)
            } else {
                // Shade mode
                buildShadeMode()
            }
        }
        .frame(
            width: WinampSizes.equalizer.width,
            height: settings.isEqualizerWindowShaded ? WinampSizes.equalizerShade.height : WinampSizes.equalizer.height,
            alignment: .topLeading
        )
        .scaleEffect(
            settings.isDoubleSizeMode ? 2.0 : 1.0,
            anchor: .topLeading
        )
        .frame(
            width: settings.isDoubleSizeMode ? WinampSizes.equalizer.width * 2 : WinampSizes.equalizer.width,
            height: settings.isEqualizerWindowShaded
                ? (settings.isDoubleSizeMode ? WinampSizes.equalizerShade.height * 2 : WinampSizes.equalizerShade.height)
                : (settings.isDoubleSizeMode ? WinampSizes.equalizer.height * 2 : WinampSizes.equalizer.height),
            alignment: .topLeading
        )
        .fixedSize()  // Lock measured size so background sees final geometry
        .background(Color.black) // Must be AFTER fixedSize to see scaled dimensions
    }
    
    /// The buttons are part of the titlebar bitmap; only the pressed sprite is drawn.
    @ViewBuilder
    private func buildTitlebarButtons(shaded: Bool) -> some View {
        SkinHitButton(pressedSprite: shaded ? "EQ_MINIMIZE_BUTTON_ACTIVE" : maximizePressedSprite, width: 9, height: 9) {
            settings.isEqualizerWindowShaded.toggle()
        }
        .at(EQCoords.shadeButton)

        SkinHitButton(pressedSprite: shaded ? "EQ_SHADE_CLOSE_BUTTON_ACTIVE" : "EQ_CLOSE_BUTTON_ACTIVE", width: 9, height: 9) {
            WindowCoordinator.shared?.hideEQWindow()
        }
        .at(EQCoords.closeButton)
    }

    /// EQ_EX.BMP is optional; without it the pressed shade button comes from EQMAIN.BMP.
    private var maximizePressedSprite: String {
        skinManager.currentSkin?.loadedSheets.contains("EQ_EX") == true
            ? "EQ_MAXIMIZE_BUTTON_ACTIVE" : "EQ_MAXIMIZE_BUTTON_ACTIVE_FALLBACK"
    }

    @ViewBuilder
    private func buildControlButtons() -> some View {
        Group {
            // ON button
            Button(action: {
                audioPlayer.toggleEq(isOn: !audioPlayer.isEqOn)
            }) {
                let spriteKey = audioPlayer.isEqOn ? "EQ_ON_BUTTON_SELECTED" : "EQ_ON_BUTTON"
                SimpleSpriteImage(spriteKey, width: 26, height: 12)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .at(EQCoords.onButton)

            // AUTO button
            Button(action: {
                audioPlayer.setAutoEQEnabled(!audioPlayer.eqAutoEnabled)
            }) {
                let spriteKey = audioPlayer.eqAutoEnabled ? "EQ_AUTO_BUTTON_SELECTED" : "EQ_AUTO_BUTTON"
                SimpleSpriteImage(spriteKey, width: 32, height: 12)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .at(EQCoords.autoButton)
        }
    }
    
    @ViewBuilder
    private func buildPreampSlider() -> some View {
        WinampVerticalSlider(
            value: Binding(
                get: { audioPlayer.preamp },
                set: { audioPlayer.setPreamp(value: $0) }  // Call setPreamp to affect audio
            ),
            range: -12.0...12.0,
            width: sliderWidth,   // 14px exactly
            height: sliderHeight, // 62px exactly
            thumbWidth: thumbWidth,
            thumbHeight: thumbHeight,
            backgroundSprite: "EQ_SLIDER_BACKGROUND",
            thumbSprite: "EQ_SLIDER_THUMB",
            thumbActiveSprite: "EQ_SLIDER_THUMB_SELECTED"
        )
        .at(EQCoords.preampSlider) // x: 21, y: 38 (exact webamp position)
    }
    
    @ViewBuilder
    private func buildEQSliders() -> some View {
        // 10 EQ band sliders using EXACT webamp positions
        ForEach(0..<10, id: \.self) { bandIndex in
            WinampVerticalSlider(
                value: Binding(
                    get: { audioPlayer.eqBands[bandIndex] },
                    set: { audioPlayer.setEqBand(index: bandIndex, value: $0) }
                ),
                range: -12.0...12.0,
                width: sliderWidth,
                height: sliderHeight,
                thumbWidth: thumbWidth,
                thumbHeight: thumbHeight,
                backgroundSprite: "EQ_SLIDER_BACKGROUND",
                thumbSprite: "EQ_SLIDER_THUMB",
                thumbActiveSprite: "EQ_SLIDER_THUMB_SELECTED"
            )
            .at(CGPoint(
                x: EQCoords.eqSliderPositions[bandIndex], // Use exact positions from webamp
                y: EQCoords.eqSliderY
            ))
        }
    }
    
    @ViewBuilder
    private func buildPresetsButton() -> some View {
        Button {
            showPresetPicker.toggle()
        } label: {
            SimpleSpriteImage("EQ_PRESETS_BUTTON", width: 44, height: 12)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .popover(isPresented: $showPresetPicker, arrowEdge: .bottom) {
            EQPresetPickerView(
                builtInPresets: EQPreset.builtIn,
                userPresets: audioPlayer.userPresets,
                onSelect: { preset in
                    audioPlayer.applyEQPreset(preset)
                    showPresetPicker = false
                },
                onSave: {
                    showSavePresetDialog()
                    showPresetPicker = false
                },
                onDeleteUserPreset: { presetID in
                    audioPlayer.deleteUserPreset(id: presetID)
                },
                onImport: {
                    importPresetFromFile()
                }
            )
        }
        .at(EQCoords.presetsButton)
    }

    private func showSavePresetDialog() {
        let alert = NSAlert()
        alert.messageText = "Save EQ Preset"
        alert.informativeText = "Enter a name for this preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "My Preset"
        textField.placeholderString = "Preset name"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let presetName = textField.stringValue
            audioPlayer.saveUserPreset(named: presetName)
        }
    }
    
    @ViewBuilder
    private func buildShadeMode() -> some View {
        ZStack(alignment: .topLeading) {
            WinampTitlebarDragHandle(windowKind: .equalizer, size: CGSize(width: 275, height: 14)) {
                SimpleSpriteImage(isWindowActive ? "EQ_SHADE_BACKGROUND_SELECTED" : "EQ_SHADE_BACKGROUND",
                                  width: 275, height: 14)
            }

            buildShadeSlider(value: Double(audioPlayer.volume), width: EQCoords.shadeVolumeWidth,
                             thumbPrefix: "EQ_SHADE_VOLUME_SLIDER",
                             set: { playbackCoordinator.setVolume(Float($0)) },
                             commit: { playbackCoordinator.commitVolume() })
                .at(EQCoords.shadeVolume)

            buildShadeSlider(value: Double(audioPlayer.balance + 1) / 2, width: EQCoords.shadeBalanceWidth,
                             thumbPrefix: "EQ_SHADE_BALANCE_SLIDER",
                             set: { value in
                                 let balance = Float(value * 2 - 1)
                                 playbackCoordinator.setBalance(abs(balance) < 0.12 ? 0 : balance)
                             },
                             commit: { playbackCoordinator.commitBalance() })
                .opacity(playbackCoordinator.supportsAudioProcessing ? 1.0 : 0.5)
                .allowsHitTesting(playbackCoordinator.supportsAudioProcessing)
                .at(EQCoords.shadeBalance)

            buildTitlebarButtons(shaded: true)
        }
    }

    /// Only the 3×7 thumb is drawn; its variant follows which third `value` (0...1) is in.
    private func buildShadeSlider(value: Double, width: CGFloat, thumbPrefix: String,
                                  set: @escaping (Double) -> Void, commit: @escaping () -> Void) -> some View {
        let variant = value < 1.0 / 3 ? "LEFT" : value < 2.0 / 3 ? "CENTER" : "RIGHT"
        return ZStack(alignment: .topLeading) {
            SimpleSpriteImage("\(thumbPrefix)_\(variant)", width: 3, height: 7)
                .offset(x: (width - 3) * value)
                .allowsHitTesting(false)
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { set(min(max($0.location.x / geo.size.width, 0), 1)) }
                            .onEnded { _ in commit() }
                    )
            }
        }
        .frame(width: width, height: 7, alignment: .topLeading)
    }

    @ViewBuilder
    private func buildEQCurve() -> some View {
        // Simplified EQ curve visualization
        SimpleSpriteImage("EQ_GRAPH_BACKGROUND", width: 113, height: 19)
            .at(EQCoords.graphArea)
            .overlay(
                // Draw EQ curve based on band values
                Path { path in
                    let graphWidth: CGFloat = 113
                    let graphHeight: CGFloat = 19
                    let bands = audioPlayer.eqBands
                    
                    if !bands.isEmpty {
                        let stepX = graphWidth / CGFloat(bands.count - 1)
                        let centerY = graphHeight / 2
                        
                        for (index, gain) in bands.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedGain = CGFloat(gain) / 24.0 // -12..12 to -0.5..0.5
                            let y = centerY - (normalizedGain * centerY)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                }
                .stroke(Color.green, lineWidth: 1)
                .at(EQCoords.graphArea)
            )
    }
}

#Preview {
    WinampEqualizerWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
}
