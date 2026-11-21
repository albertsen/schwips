import Foundation
import SwiftData
import Testing
@testable import SchwipsCore

@MainActor
struct MigrationTests {
    /// A store written with SchemaV1 opens with the current schema: its wines
    /// and bottles stay, the new notes are empty and can be set.
    @Test func v1StoreOpensAsV2() throws {
        let url = try temporaryFolder().appending(path: CellarLocation.storeFileName)
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
            )
            let context = ModelContext(container)
            let wine = SchemaV1.Wine(number: 12, producer: "Diel")
            wine.notes = "Im Stil eines Großen Gewächses"
            context.insert(wine)
            let bottle = SchemaV1.Bottle(wine: wine)
            context.insert(bottle)
            try context.save()
        }
        let cellar = Cellar(context: ModelContext(try CellarContainer.make(at: url)))
        let wine = try #require(try cellar.wine(number: 12))
        #expect(wine.notes == "Im Stil eines Großen Gewächses")
        #expect(wine.userNotes == nil)
        #expect(wine.inStockCount == 1)
        try cellar.edit(.userNotes, to: "Zum Geburtstag öffnen", on: wine)
        #expect(wine.userNotes == "Zum Geburtstag öffnen")
    }
}
