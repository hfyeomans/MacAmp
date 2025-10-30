import SwiftUI

/// Proper ToggleStyle for clutter bar buttons with skin-driven images
///
/// Uses configuration.isOn to avoid manual state passing and ensure
/// proper accessibility semantics for VoiceOver compatibility.
struct SkinToggleStyle: ToggleStyle {
    let normalImage: NSImage
    let activeImage: NSImage

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(nsImage: configuration.isOn ? activeImage : normalImage)
                .interpolation(.none)  // Pixel-perfect rendering
                .frame(width: 9, height: 9)  // Standard clutter button size
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// Extension for easy discovery and usage
extension ToggleStyle where Self == SkinToggleStyle {
    static func skin(normal: NSImage, active: NSImage) -> SkinToggleStyle {
        SkinToggleStyle(normalImage: normal, activeImage: active)
    }
}
