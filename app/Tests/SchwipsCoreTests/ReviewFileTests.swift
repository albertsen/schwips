import Foundation
import Testing
@testable import SchwipsCore

struct ReviewFileTests {
    /// A review file `/import-wines` wrote for the web app.
    @Test func decodesARealReviewFile() throws {
        let file = try ReviewValidation.decode(Data(contentsOf: fixtureURL("review.json")))
        #expect(!file.bottles.isEmpty)
        #expect(file.bottles.allSatisfy { !$0.wine.producer.isEmpty })
    }

    private func decode(_ bottle: String) -> ImportError? {
        let json = #"{"generated_at":"2026-11-21T14:02:00Z","bottles":[\#(Self.valid),\#(bottle)]}"#
        do {
            _ = try ReviewValidation.decode(Data(json.utf8))
            return nil
        } catch {
            return error
        }
    }

    static let valid = #"""
    {"photos":["A.jpeg"],"dedup":{"action":"new_wine"},"confidence":0.9,
     "wine":{"producer":"Diel","name":"Eierfels","vintage":2023,"wine_type":"wine","color":"white",
             "sweetness":"dry","import_confidence":0.9,"grapes":[{"canonical":"Riesling","color":"white"}]},
     "bottle":{"bottle_size_ml":750,"current_value":26.0,"status":"in_stock"}}
    """#

    @Test func validFileHasNoError() {
        #expect(decode(Self.valid) == nil)
    }

    @Test func wrongTypeNamesBottleAndField() {
        let bottle = Self.valid.replacingOccurrences(of: #""vintage":2023"#, with: #""vintage":"20x3""#)
        #expect(decode(bottle)?.message == "Bottle 2: “vintage” must be a whole number.")
    }

    @Test func missingKey() {
        let bottle = Self.valid.replacingOccurrences(of: #""producer":"Diel","#, with: "")
        #expect(decode(bottle)?.message == "Bottle 2: “producer” is missing.")
    }

    @Test func unknownEnumValue() {
        let bottle = Self.valid.replacingOccurrences(of: #""color":"white","#, with: #""color":"blue","#)
        #expect(decode(bottle)?.message == "Bottle 2: “color” has a value that isn’t allowed.")
    }

    @Test func rangeCheck() {
        let bottle = Self.valid.replacingOccurrences(of: #""confidence":0.9,"#, with: #""confidence":1.5,"#)
        #expect(decode(bottle)?.message == "Bottle 2: “confidence” must be between 0 and 1.")
    }

    @Test func matchExistingNeedsANumber() {
        let bottle = Self.valid.replacingOccurrences(of: #"{"action":"new_wine"}"#, with: #"{"action":"match_existing"}"#)
        #expect(decode(bottle)?.message == "Bottle 2: “wine_id” is missing.")
    }

    @Test func truncatedJSONIsIncomplete() {
        let error = try? #require(decode(String(Self.valid.dropLast(20))))
        #expect(error?.isIncompleteJSON == true)
    }
}
