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

        // Clamp to bounds: BMP heights vary across skins, and scaling would interpolate magenta separators.
        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let clampedRect = rect.intersection(imageBounds)
        guard !clampedRect.isNull, clampedRect.width > 0, clampedRect.height > 0 else {
            AppLog.error(.ui, "ImageSlicing: Rect \(rect) is outside image bounds \(imageBounds)")
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            AppLog.error(.ui, "ImageSlicing: CGImage.cropping failed for rect \(clampedRect)")
            return nil
        }

        // Create an independent copy via canonical RGBA8 CGContext to break the
        // parent-child buffer sharing that CGImage.cropping(to:) creates.
        // Without this, the parent BMP's full float pixel buffer stays alive
        // as long as any cropped sprite references it.
        let width = croppedCGImage.width
        let height = croppedCGImage.height
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
        context.draw(croppedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Winamp chroma key: RGB(255, 0, 255) marks transparent.
        if let data = context.data {
            let bytesPerRow = context.bytesPerRow
            for y in 0..<height {
                let rowPtr = data.advanced(by: y * bytesPerRow).bindMemory(to: UInt8.self, capacity: width * 4)
                for x in 0..<width {
                    let i = x * 4
                    if rowPtr[i] == 255, rowPtr[i + 1] == 0, rowPtr[i + 2] == 255 {
                        rowPtr[i] = 0
                        rowPtr[i + 1] = 0
                        rowPtr[i + 2] = 0
                        rowPtr[i + 3] = 0
                    }
                }
            }
        }

        guard let independentCGImage = context.makeImage() else {
            AppLog.error(.ui, "ImageSlicing: Failed to create independent CGImage for \(clampedRect)")
            return nil
        }
        return NSImage(cgImage: independentCGImage, size: CGSize(width: width, height: height))
    }
}
