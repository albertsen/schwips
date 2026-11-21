import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Shrinks label photos as they come in: JPEG, longest side 2400 px, quality
/// 0.85, EXIF orientation applied; plus a 240 px thumbnail for the detail.
public enum PhotoShrinker {
    public static let maxPixelSize = 2400
    public static let thumbnailPixelSize = 240

    public struct Result: Sendable {
        public let image: Data
        public let thumbnail: Data
    }

    public struct UnreadableImage: Error {}

    /// Runs off the main actor; returns values only.
    @concurrent
    public static func shrink(_ data: Data) async throws -> Result {
        try shrinkNow(data)
    }

    public static func shrinkNow(_ data: Data) throws -> Result {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw UnreadableImage() }
        return Result(
            image: try jpeg(source, maxPixelSize: maxPixelSize, quality: 0.85),
            thumbnail: try jpeg(source, maxPixelSize: thumbnailPixelSize, quality: 0.8)
        )
    }

    private static func jpeg(_ source: CGImageSource, maxPixelSize: Int, quality: Double) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw UnreadableImage()
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw UnreadableImage()
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw UnreadableImage() }
        return output as Data
    }
}
