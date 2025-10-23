
import AppKit
import CoreGraphics

extension NSImage {
    // Crops the NSImage to the specified rectangle.
    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ ImageSlicing: Failed to get CGImage from NSImage")
            return nil
        }

        // CRITICAL FIX: CGImage uses bottom-left origin, but our sprite rects use top-left origin
        // Must flip the Y coordinate before cropping
        var flippedRect = rect
        flippedRect.origin.y = CGFloat(cgImage.height) - rect.origin.y - rect.height

        // Verify the flipped rect is within bounds
        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        if !imageBounds.contains(flippedRect) && !imageBounds.intersects(flippedRect) {
            print("❌ ImageSlicing: Flipped rect \(flippedRect) is outside image bounds \(imageBounds)")
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: flippedRect) else {
            print("❌ ImageSlicing: CGImage.cropping failed for flipped rect \(flippedRect)")
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: rect.size)
        return croppedImage
    }
}
