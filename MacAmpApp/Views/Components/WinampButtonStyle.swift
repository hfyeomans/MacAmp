import SwiftUI

/// Global button style for MacAmp that removes focus rings and provides
/// consistent Winamp-like button behavior across all windows.
///
/// Usage:
/// ```swift
/// Button(action: { ... }) {
///     SimpleSpriteImage("BUTTON_NAME", width: 23, height: 18)
/// }
/// .buttonStyle(WinampButtonStyle())
/// ```
///
/// This style automatically:
/// - Removes the blue focus ring (.focusable(false))
/// - Applies plain button styling (no macOS chrome)
/// - Maintains proper hit testing
///
/// For future buttons, use this style instead of manually adding:
/// `.buttonStyle(.plain).focusable(false)`
struct WinampButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .focusable(false)
    }
}

/// Convenience extension for cleaner syntax
extension View {
    /// Apply Winamp button styling with no focus ring
    /// Usage: .winampButton()
    func winampButton() -> some View {
        self
            .buttonStyle(.plain)
            .focusable(false)
    }
}
