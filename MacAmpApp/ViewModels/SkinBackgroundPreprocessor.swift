import AppKit

/// Preprocess MAIN_WINDOW_BACKGROUND to black out static digit positions.
/// Some skins (e.g., Internet Archive) have "00:00" baked into MAIN.BMP.
/// We black out ONLY the 4 digit areas (9x13 each), keeping the ":" visible.
///
/// Time display coordinates: (39, 26) from top-left
/// Digit positions (relative to 39, 26):
/// - Minute tens: x:6, y:0 -> absolute (45, 26)
/// - Minute ones: x:17, y:0 -> absolute (56, 26)
/// - Colon: x:28, y:3 -> absolute (67, 29) <- NOT masked!
/// - Second tens: x:35, y:0 -> absolute (74, 26)
/// - Second ones: x:46, y:0 -> absolute (85, 26)
@MainActor
enum SkinBackgroundPreprocessor {
    static func preprocessMainBackground(_ image: NSImage) -> NSImage {
        let size = image.size
        let processedImage = NSImage(size: size)

        processedImage.lockFocus()
        defer { processedImage.unlockFocus() }

        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        // CRITICAL: NSImage uses BOTTOM-LEFT origin, SwiftUI uses TOP-LEFT
        // Flip y: imageHeight is 116, time display starts at y:26 from top
        let timeDisplayY = size.height - 26 - 13

        NSColor.black.setFill()

        // MINUTES BLOCK: x:45 to x:66 (both minute digits)
        NSRect(x: 45, y: timeDisplayY, width: 22, height: 13).fill()

        // COLON GAP: x:67-72 is LEFT UNTOUCHED

        // SECONDS BLOCK: x:74 to x:97 (both second digits)
        NSRect(x: 74, y: timeDisplayY, width: 24, height: 13).fill()

        AppLog.debug(.skin, "Preprocessed MAIN_WINDOW_BACKGROUND: 2 blocks leaving colon gap at y:\(timeDisplayY)")
        return processedImage
    }
}
