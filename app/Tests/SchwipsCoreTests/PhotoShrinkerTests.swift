import Foundation
import Testing
@testable import SchwipsCore

struct PhotoShrinkerTests {
    @Test func longestSideBecomes2400() throws {
        let result = try PhotoShrinker.shrinkNow(makeJPEG(width: 4032, height: 3024))
        let size = pixelSize(of: result.image)
        #expect(size.width == 2400 && size.height == 1800)
        #expect(max(pixelSize(of: result.thumbnail).width, pixelSize(of: result.thumbnail).height) == 240)
    }

    /// Orientation 6 (rotated 90°): the stored pixels are upright.
    @Test func appliesOrientation() throws {
        let result = try PhotoShrinker.shrinkNow(makeJPEG(width: 4000, height: 3000, orientation: 6))
        let size = pixelSize(of: result.image)
        #expect(size.width == 1800 && size.height == 2400)
    }

    @Test func smallImagesStayUnscaled() throws {
        let result = try PhotoShrinker.shrinkNow(makeJPEG(width: 800, height: 600))
        let size = pixelSize(of: result.image)
        #expect(size.width == 800 && size.height == 600)
    }

    @Test func refusesNonImages() {
        #expect(throws: (any Error).self) { try PhotoShrinker.shrinkNow(Data("nope".utf8)) }
    }
}
