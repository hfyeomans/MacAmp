import AppKit
import CoreGraphics

extension NSImage {
    // Crops the NSImage to the specified rectangle.
    // Creates an independent CGImage copy to break parent buffer reference chains,
    // preventing the parent BMP's full pixel buffer from being retained by cropped sprites.
    func cropped(to rect: CGRect) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            AppLog.error(.ui, "ImageSlicing: Failed to get CGImage from NSImage")
            return nil
        }

        // Verify the rect is within bounds
        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        if !imageBounds.contains(rect) && !imageBounds.intersects(rect) {
            AppLog.error(.ui, "ImageSlicing: Rect \(rect) is outside image bounds \(imageBounds)")
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: rect) else {
            AppLog.error(.ui, "ImageSlicing: CGImage.cropping failed for rect \(rect)")
            return nil
        }

        // Create an independent copy via canonical RGBA8 CGContext to break the
        // parent-child buffer sharing that CGImage.cropping(to:) creates.
        // Without this, the parent BMP's full float pixel buffer stays alive
        // as long as any cropped sprite references it.
        let width = Int(rect.width)
        let height = Int(rect.height)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            AppLog.error(.ui, "ImageSlicing: Failed to create independent CGContext for \(rect)")
            return nil
        }
        context.draw(croppedCGImage, in: CGRect(origin: .zero, size: rect.size))
        guard let independentCGImage = context.makeImage() else {
            AppLog.error(.ui, "ImageSlicing: Failed to create independent CGImage for \(rect)")
            return nil
        }
        return NSImage(cgImage: independentCGImage, size: rect.size)
    }
}
