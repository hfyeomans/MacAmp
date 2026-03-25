import SwiftUI

/// Modern popover view for selecting EQ presets
struct EQPresetPickerView: View {
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
