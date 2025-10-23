
import AppKit
import CoreGraphics

extension NSImage {
    // Crops the NSImage to the specified rectangle.
    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ ImageSlicing: Failed to get CGImage from NSImage")
            return nil
        }
        
        // Verify the rect is within bounds
        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        if !imageBounds.contains(rect) && !imageBounds.intersects(rect) {
            print("❌ ImageSlicing: Rect \(rect) is outside image bounds \(imageBounds)")
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            print("❌ ImageSlicing: CGImage.cropping failed for rect \(rect)")
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: rect.size)
        return croppedImage
    }
}
