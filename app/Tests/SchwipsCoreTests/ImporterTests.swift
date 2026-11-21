import Foundation
import SwiftData
import Testing
@testable import SchwipsCore

@MainActor
struct ImporterTests {
    private func review(_ bottles: [String]) throws -> ReviewFile {
        try ReviewValidation.decode(Data(#"{"generated_at":"x","bottles":[\#(bottles.joined(separator: ","))]}"#.utf8))
    }

    private func bottle(producer: String = "Diel", name: String = "Eierfels", photos: [String] = [],
                        dedup: String = #"{"action":"new_wine"}"#, grapes: String = #"[{"canonical":"Riesling","color":"white"}]"#) -> String {
        let photoList = photos.map { "\"\($0)\"" }.joined(separator: ",")
        return #"""
        {"photos":[\#(photoList)],"dedup":\#(dedup),"confidence":0.9,"open_questions":["Jahrgang?"],
         "wine":{"producer":"\#(producer)","name":"\#(name)","vintage":2023,"wine_type":"wine","color":"white",
                 "import_confidence":0.9,"data_sources":{"producer":"label"},"grapes":\#(grapes)},
         "bottle":{"current_value":26.0}}
        """#
    }

    private func incoming(_ names: [String]) throws -> URL {
        let folder = try temporaryFolder()
        for name in names { try makeJPEG(width: 30, height: 40).write(to: folder.appending(path: name)) }
        return folder
    }

    @Test func newWinesGetTheNextNumbersAndSecondBottleMatchesBySignature() async throws {
        let cellar = try makeCellar()
        try addWine(cellar, number: 41, producer: "Korrell")
        let file = try review([bottle(photos: ["A.jpeg", "B.jpeg"]), bottle(), bottle(producer: "Bamberger", name: "Réserve")])
        let folder = try incoming(["A.jpeg", "B.jpeg"])
        let photos = try await CellarImporter.preparePhotos(for: file, incoming: folder)
        let outcome = try cellar.importReview(file, photos: photos, fileName: "r.json", fileModified: nil)

        #expect(outcome.newWineNumbers == [42, 43])
        #expect(outcome.bottleCount == 3)
        #expect(outcome.photoCount == 2)
        #expect(outcome.openQuestionCount == 3)
        let diel = try #require(try cellar.wine(number: 42))
        #expect(diel.inStockCount == 2)
        #expect(diel.price == 26)
        #expect(diel.orderedPhotos.first?.isPrimary == true)
        #expect(diel.orderedPhotos.first?.thumbnailData != nil)
        #expect(diel.dataSources["producer"] == .label)
        #expect(try cellar.importRecords().first?.status == .imported)
    }

    @Test func matchExistingByNumberAndLearnedAlias() async throws {
        let cellar = try makeCellar()
        try addWine(cellar, number: 7, producer: "Korrell", grapes: [("Grauburgunder", nil)])
        let file = try review([bottle(
            dedup: #"{"action":"match_existing","wine_id":7}"#,
            grapes: #"[{"canonical":"Grauburgunder","label_name":"Pinot Grigio","color":"white"}]"#
        )])
        let outcome = try cellar.importReview(file, photos: [:], fileName: "r.json", fileModified: nil)
        #expect(outcome.matchedWineNumbers == [7])
        #expect(try cellar.wine(number: 7)?.inStockCount == 2)
        let aliases = try cellar.context.fetch(FetchDescriptor<GrapeAlias>()).map(\.alias)
        #expect(aliases == ["Pinot Grigio"])
    }

    @Test func unknownNumberFailsTheWholeFile() throws {
        let cellar = try makeCellar()
        let file = try review([bottle(producer: "Neu"), bottle(dedup: #"{"action":"match_existing","wine_id":99}"#)])
        #expect(throws: ImportError.self) {
            try cellar.importReview(file, photos: [:], fileName: "r.json", fileModified: nil)
        }
        #expect(try cellar.wines().isEmpty)
        #expect(try cellar.grapes().isEmpty)
        cellar.recordImportFailure(fileName: "r.json", fileModified: nil, message: "x")
        #expect(try cellar.importRecords().first?.status == .failed)
    }

    @Test func missingPhotoFailsBeforeWriting() async throws {
        let file = try review([bottle(photos: ["missing.jpeg"])])
        await #expect(throws: ImportError.self) {
            _ = try await CellarImporter.preparePhotos(for: file, incoming: try temporaryFolder())
        }
    }

    @Test func skippedFilesAreRecordedOnce() throws {
        let cellar = try makeCellar()
        try cellar.recordSkipped([("a.json", nil), ("b.json", nil)])
        try cellar.recordSkipped([("a.json", nil)])
        #expect(try cellar.importRecords().count == 2)
        #expect(try cellar.lastImport() == nil)
    }
}
