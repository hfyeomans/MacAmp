import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Whimsy & Animation States
    @State private var settingChangeGlow: String? = nil
    @State private var materialPreview: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MacAmp Preferences")
                .font(.title2)
                .fontWeight(.bold)
            
            Divider()
            
            GroupBox("Appearance Mode") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual Style")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(MaterialIntegrationLevel.allCases, id: \.rawValue) { level in
                            HStack {
                                Button(action: {
                                    settings.materialIntegration = level
                                }) {
                                    Image(systemName: settings.materialIntegration == level ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.materialIntegration = level
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Toggle("Enable Liquid Glass Effects", isOn: $settings.enableLiquidGlass)
                        .help("Add animated material effects to Hybrid and Modern modes")
                        .disabled(settings.materialIntegration == .classic)
                    
                    if settings.materialIntegration != .classic && !settings.enableLiquidGlass {
                        Text("Liquid Glass enhances \(settings.materialIntegration.displayName) mode with animated materials")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .conditionalGroupBoxBackground(enabled: settings.shouldUseContainerBackground)
            
            Spacer()
            
            HStack {
                Button("Restore Defaults") {
                    settings.enableLiquidGlass = true
                    settings.materialIntegration = .hybrid
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 400)
        .conditionalPreferencesBackground(enabled: true)
    }
    
    // MARK: - Whimsy Helper Functions
    private func triggerSettingGlow(_ settingKey: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            settingChangeGlow = settingKey
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                settingChangeGlow = nil
            }
        }
    }
    
    private func triggerMaterialPreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            materialPreview = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                materialPreview = false
            }
        }
    }
}

// MARK: - Liquid Glass Integration Extensions

private extension View {
    @ViewBuilder
    func conditionalGroupBoxBackground(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.background(.thickMaterial)
            } else {
                self
            }
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalPreferencesBackground(enabled: Bool) -> some View {
        if enabled {
            if #available(macOS 26.0, *) {
                self.containerBackground(.regularMaterial, for: .window)
            } else {
                self.background(.regularMaterial)
            }
        } else {
            self.background(.regularMaterial)
        }
    }
}

#if DEBUG
#Preview {
    PreferencesView()
        .environmentObject(AppSettings.instance())
}
#endif