import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Pixel-perfect recreation of Winamp's equalizer window using absolute positioning
struct WinampEqualizerWindow: View {
    @Environment(SkinManager.self) var skinManager
    @Environment(AudioPlayer.self) var audioPlayer

    @State private var isShadeMode: Bool = false
    @State private var showPresetPicker: Bool = false

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
        
        // Titlebar buttons (same as main window)
        static let minimizeButton = CGPoint(x: 244, y: 3)
        static let shadeButton = CGPoint(x: 254, y: 3) 
        static let closeButton = CGPoint(x: 264, y: 3)
        
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
            if !isShadeMode {
                // Full window mode
                // Background - The EQMAIN sprite includes preamp text and frequency labels
                SimpleSpriteImage("EQ_WINDOW_BACKGROUND",
                                width: WinampSizes.equalizer.width,
                                height: WinampSizes.equalizer.height)

                // Title bar with "Winamp Equalizer" text
                // Make ONLY the title bar draggable using custom drag (magnetic snapping)
                // CRITICAL: Apply .at() to drag handle itself, not content inside (Oracle fix)
                WinampTitlebarDragHandle(windowKind: .equalizer, size: CGSize(width: 275, height: 14)) {
                    SimpleSpriteImage("EQ_TITLE_BAR_SELECTED",
                                    width: 275,
                                    height: 14)
                }
                .at(CGPoint(x: 0, y: 0))

                // Build all EQ components
                Group {
                    // Titlebar buttons
                    buildTitlebarButtons()

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
            } else {
                // Shade mode
                buildShadeMode()
            }
        }
        .frame(width: WinampSizes.equalizer.width,
               height: isShadeMode ? WinampSizes.equalizerShade.height : WinampSizes.equalizer.height)
        .background(Color.black) // Fallback
    }
    
    @ViewBuilder
    private func buildTitlebarButtons() -> some View {
        Group {
            // Minimize button
            Button(action: {
                NSApp.keyWindow?.miniaturize(nil)
            }) {
                SimpleSpriteImage("MAIN_MINIMIZE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.minimizeButton)
            
            // Shade button
            Button(action: {
                isShadeMode.toggle()
            }) {
                SimpleSpriteImage("MAIN_SHADE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.shadeButton)
            
            // Close button
            Button(action: {
                NSApp.keyWindow?.close()
            }) {
                SimpleSpriteImage("MAIN_CLOSE_BUTTON", width: 9, height: 9)
            }
            .buttonStyle(.plain)
            .at(EQCoords.closeButton)
        }
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
            .at(EQCoords.onButton)
            
            // AUTO button
            Button(action: {
                audioPlayer.setAutoEQEnabled(!audioPlayer.eqAutoEnabled)
            }) {
                let spriteKey = audioPlayer.eqAutoEnabled ? "EQ_AUTO_BUTTON_SELECTED" : "EQ_AUTO_BUTTON"
                SimpleSpriteImage(spriteKey, width: 32, height: 12)
            }
            .buttonStyle(.plain)
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
        .popover(isPresented: $showPresetPicker, arrowEdge: .bottom) {
            PresetPickerView(
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
        // EQ shade mode shows a compact 275×14px bar
        ZStack {
            // Shade background
            SimpleSpriteImage("EQ_SHADE_BACKGROUND", width: 275, height: 14)
                .at(CGPoint(x: 0, y: 0))

            // Compact volume and balance sliders in shade mode
            // Volume slider (left side)
            HStack(spacing: 1) {
                SimpleSpriteImage("EQ_SHADE_VOLUME_SLIDER_LEFT", width: 3, height: 7)
                SimpleSpriteImage("EQ_SHADE_VOLUME_SLIDER_CENTER", width: 3, height: 7)
                SimpleSpriteImage("EQ_SHADE_VOLUME_SLIDER_RIGHT", width: 3, height: 7)
            }
            .at(CGPoint(x: 20, y: 4))

            // Balance slider (right side)
            HStack(spacing: 1) {
                SimpleSpriteImage("EQ_SHADE_BALANCE_SLIDER_LEFT", width: 3, height: 7)
                SimpleSpriteImage("EQ_SHADE_BALANCE_SLIDER_CENTER", width: 3, height: 7)
                SimpleSpriteImage("EQ_SHADE_BALANCE_SLIDER_RIGHT", width: 3, height: 7)
            }
            .at(CGPoint(x: 180, y: 4))

            // Titlebar buttons
            buildTitlebarButtons()
        }
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

/// Vertical slider component for EQ bands
struct WinampVerticalSlider: View {
    @Environment(SkinManager.self) var skinManager
    @Binding var value: Float
    let range: ClosedRange<Float>
    let width: CGFloat
    let height: CGFloat
    let thumbHeight: CGFloat
    let backgroundSprite: String
    let thumbSprite: String
    let thumbActiveSprite: String

    @State private var isDragging = false

    // EQ_SLIDER_BACKGROUND 2D grid constants (14×2 layout, 28 frames total)
    private let frameWidth: CGFloat = 15
    private let frameHeight: CGFloat = 65
    private let gridColumns: Int = 14
    private let totalFrames: Int = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Render colored gradient background from EQ_SLIDER_BACKGROUND
            // Uses 2D grid positioning (14 columns × 2 rows)
            if let skin = skinManager.currentSkin,
               let eqBackground = skin.images[backgroundSprite] {
                // CRITICAL: frame→offset→clip order (proven from Volume slider)
                Image(nsImage: eqBackground)
                    .interpolation(.none)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .offset(x: calculateFrameXOffset(), y: calculateFrameYOffset())
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                // Fallback: programmatic gradient if sprite missing
                Rectangle()
                    .fill(sliderColor)
                    .frame(width: width, height: height)
            }

            // Slider thumb sprite (11x11 pixels)
            SimpleSpriteImage(isDragging ? thumbActiveSprite : thumbSprite,
                            width: 11, height: 11)
                .offset(x: 1.5, y: thumbPosition) // Position based on webamp formula

            // Invisible interaction area - EXACTLY constrained
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                updateValue(from: gesture, in: geo)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .frame(width: width, height: height) // FORCE exact constraint
        }
        .frame(width: width, height: height) // DOUBLE ensure constraints
        .clipped() // CRITICAL: Clip any overflow
    }
    
    // Solid color that changes based on slider position
    private var sliderColor: Color {
        // Map value to color: green (-12) -> yellow (0) -> red (+12)
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        if normalizedValue <= 0.5 {
            // Green to Yellow (bottom to center)
            let t = normalizedValue * 2 // 0 to 1 for this half
            return Color(
                red: Double(t * 0.9),      // 0 -> 0.9
                green: Double(0.8),         // Stay high
                blue: 0
            )
        } else {
            // Yellow to Red (center to top)
            let t = (normalizedValue - 0.5) * 2 // 0 to 1 for this half
            return Color(
                red: Double(0.9 + t * 0.1), // 0.9 -> 1.0
                green: Double(0.8 * (1 - t)), // 0.8 -> 0
                blue: 0
            )
        }
    }
    
    
    private var thumbPosition: CGFloat {
        // Position the thumb sprite based on value using webamp's formula
        let thumbSize: CGFloat = 11 // Actual thumb sprite height
        let trackHeight = height - thumbSize
        
        // Normalize value from range to 0-1
        // At -12dB: normalizedValue = 0 (bottom)
        // At 0dB: normalizedValue = 0.5 (center)  
        // At +12dB: normalizedValue = 1 (top)
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        
        // Use webamp's formula: offset = floor((height - handleHeight) * value)
        // But inverted since our coordinate system has 0 at top
        return floor(trackHeight * (1.0 - CGFloat(normalizedValue)))
    }
    
    private func updateValue(from gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let gestureHeight = geometry.size.height
        let y = min(max(0, gesture.location.y), gestureHeight)

        // Invert Y coordinate (top = high value, bottom = low value)
        let normalizedPosition = 1.0 - Float(y / gestureHeight)
        var newValue = range.lowerBound + (normalizedPosition * (range.upperBound - range.lowerBound))

        // Center snapping: if within ±0.5dB of center (0), snap to exactly 0
        let snapThreshold: Float = 0.5
        if abs(newValue) < snapThreshold {
            newValue = 0
        }

        value = max(range.lowerBound, min(range.upperBound, newValue))
    }

    // Calculate which frame (0-27) to display based on EQ value
    private func calculateFrameIndex() -> Int {
        // Normalize value from range (-12 to +12) to 0.0-1.0
        let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let percent = min(max(CGFloat(normalizedValue), 0), 1)

        // Map to frame 0-27
        let frameIndex = Int(round(percent * CGFloat(totalFrames - 1)))
        return min(max(frameIndex, 0), totalFrames - 1)
    }

    // Calculate X offset for 2D grid (column selection)
    private func calculateFrameXOffset() -> CGFloat {
        let frameIndex = calculateFrameIndex()
        let gridX = frameIndex % gridColumns  // Column: 0-13
        return -CGFloat(gridX) * frameWidth
    }

    // Calculate Y offset for 2D grid (row selection)
    private func calculateFrameYOffset() -> CGFloat {
        let frameIndex = calculateFrameIndex()
        let gridY = frameIndex / gridColumns  // Row: 0-1
        return -CGFloat(gridY) * frameHeight
    }
}

/// Modern popover view for selecting EQ presets
struct PresetPickerView: View {
    let builtInPresets: [EQPreset]
    let userPresets: [EQPreset]
    let onSelect: (EQPreset) -> Void
    let onSave: () -> Void
    let onDeleteUserPreset: (UUID) -> Void
    let onImport: () -> Void

    @State private var hoveredPreset: EQPreset.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("EQ Presets")
                    .font(.headline)
                Spacer()
                Button {
                    onSave()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Save custom preset")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Scrollable preset list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !userPresets.isEmpty {
                        Text("Saved Presets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                        presetSection(userPresets, allowDeletion: true)
                    }

                    Text("Built-in Presets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    presetSection(builtInPresets, allowDeletion: false)
                }
                .padding(.vertical, 8)
            }
            .frame(width: 240, height: 320)

            Divider()

            // Footer with file import option
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                Text("Load from .eqf file")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.05))
            .onTapGesture {
                onImport()
            }
        }
        .frame(width: 240)
    }

    private func presetSection(_ presets: [EQPreset], allowDeletion: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(presets) { preset in
                Button {
                    onSelect(preset)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(preset.name)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if hoveredPreset == preset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hoveredPreset == preset.id ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .onHover { hovering in
                    hoveredPreset = hovering ? preset.id : nil
                }
                .contextMenu {
                    if allowDeletion {
                        Button(role: .destructive) {
                            onDeleteUserPreset(preset.id)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    WinampEqualizerWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
}
