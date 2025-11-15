import Foundation

/// Represents window size in resize segments (not pixels)
/// Used for quantized window resizing matching Winamp's 25×29px grid
struct Size2D: Equatable, Codable, Hashable {
    var width: Int   // Number of 25px segments beyond base width
    var height: Int  // Number of 29px segments beyond base height

    /// Zero size (minimum dimensions)
    static let zero = Size2D(width: 0, height: 0)

    // MARK: - Video Window Presets

    /// Video window minimum size: 275×116 (matches Main/EQ)
    static let videoMinimum = Size2D(width: 0, height: 0)  // 275×116

    /// Video window default size: 275×232 (current standard)
    static let videoDefault = Size2D(width: 0, height: 4)  // 275×232

    /// Video window 2x size: 550×464 (double the default)
    static let video2x = Size2D(width: 11, height: 12)  // 550×464

    // MARK: - Conversion Methods

    /// Convert segments to pixel dimensions for VIDEO window
    /// Formula: baseWidth + (segments × segmentSize)
    func toVideoPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }

    /// Convert segments to pixel dimensions for PLAYLIST window
    /// Formula: baseWidth + (segments × segmentSize)
    func toPlaylistPixels() -> CGSize {
        CGSize(
            width: 275 + width * 25,
            height: 116 + height * 29
        )
    }

    // MARK: - Validation

    /// Create Size2D from pixel dimensions, quantizing to nearest segment
    static func fromVideoPixels(_ size: CGSize) -> Size2D {
        let widthSegments = max(0, Int(round((size.width - 275) / 25)))
        let heightSegments = max(0, Int(round((size.height - 116) / 29)))
        return Size2D(width: widthSegments, height: heightSegments)
    }

    /// Clamp size to minimum (no negative segments)
    func clamped(min: Size2D = .zero, max: Size2D? = nil) -> Size2D {
        var result = self

        // Minimum constraint
        result.width = Swift.max(min.width, result.width)
        result.height = Swift.max(min.height, result.height)

        // Maximum constraint (if provided)
        if let max = max {
            result.width = Swift.min(max.width, result.width)
            result.height = Swift.min(max.height, result.height)
        }

        return result
    }
}

// MARK: - CustomStringConvertible

extension Size2D: CustomStringConvertible {
    var description: String {
        "[\(width),\(height)]"
    }
}
