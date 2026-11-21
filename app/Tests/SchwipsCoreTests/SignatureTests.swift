import Foundation
import Testing
@testable import SchwipsCore

/// `Fixtures/signatures.json` holds every wine of the web app's cellar plus two
/// edge cases, with the key the web app's own `computeSignature` gives.
struct SignatureTests {
    struct Row: Decodable {
        var producer: String?
        var vintage: Int?
        var appellation: String?
        var vineyard: String?
        var name: String?
        var quality_level: String?
        var wine_type: String?
        var grapes: [String]
        var signature: String
    }

    @Test func matchesTheWebAppForEveryWine() throws {
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: fixtureURL("signatures.json")))
        #expect(rows.count > 40)
        for row in rows {
            let key = Signature.compute(Signature.Input(
                producer: row.producer, vintage: row.vintage, appellation: row.appellation, vineyard: row.vineyard,
                name: row.name, qualityLevel: row.quality_level, wineType: row.wine_type, grapes: row.grapes
            ))
            #expect(key == row.signature, "\(row.producer ?? "") \(row.name ?? "")")
        }
    }

    @Test func grapeOrderDoesNotMatter() {
        let a = Signature.Input(producer: "X", vintage: 2020, appellation: nil, vineyard: nil, name: nil,
                                qualityLevel: nil, wineType: "wine", grapes: ["Merlot", "Cabernet Sauvignon"])
        var b = a
        b.grapes = ["Cabernet Sauvignon", "Merlot"]
        #expect(Signature.compute(a) == Signature.compute(b))
    }
}
