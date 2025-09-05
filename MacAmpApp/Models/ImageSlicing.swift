
import AppKit
import CoreGraphics

extension NSImage {
    // Crops the NSImage to the specified rectangle.
    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: rect.size)
        return croppedImage
    }
}
