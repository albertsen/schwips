import Foundation
import SwiftData
import Testing
@testable import SchwipsCore

@MainActor
struct PersistenceTests {
    /// A store on disk keeps wines, bottles, grapes and photos across containers.
    /// `SCHWIPS_KEEP_STORE` keeps the folder and prints it, to read the schema
    /// the Claude Code commands query.
    @Test func roundTripOnDisk() throws {
        let folder = try temporaryFolder()
        let url = folder.appending(path: CellarLocation.storeFileName)
        do {
            let container = try CellarContainer.make(at: url)
            let cellar = Cellar(context: ModelContext(container))
            try addWine(cellar, number: 38, producer: "San Silvestro", price: 18, grapes: [("Barbera", "Barbera")], drunk: 1)
            let photo = Photo(fileName: "IMG_1.jpeg")
            photo.imageData = makeJPEG(width: 200, height: 300)
            cellar.context.insert(photo)
            photo.wine = try cellar.wine(number: 38)
            try cellar.recordSkipped([("old.json", nil)])
            try cellar.context.save()
        }
        let reopened = Cellar(context: ModelContext(try CellarContainer.make(at: url)))
        let wine = try #require(try reopened.wine(number: 38))
        #expect(wine.inStockCount == 1 && wine.drunkBottles.count == 1)
        #expect(wine.grapeDisplayNames == ["Barbera"])
        #expect(wine.orderedPhotos.first?.imageData != nil)
        if ProcessInfo.processInfo.environment["SCHWIPS_KEEP_STORE"] != nil {
            print("store: \(url.path)")
        } else {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
