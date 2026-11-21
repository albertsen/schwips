import Foundation
import SwiftData

/// The undoable part of the cellar as values: every wine's own fields and every
/// bottle. Photos, grapes and import records are left out, because no
/// undoable action changes them (imports are not undoable).
struct CellarSnapshot: Equatable, Sendable {
    var wines: [UUID: WineRecord]
    var bottles: [UUID: BottleRecord]

    struct WineRecord: Equatable, Sendable {
        var producer: String
        var name: String?
        var vintage: Int?
        var wineTypeRaw: String?
        var colorRaw: String?
        var sweetnessRaw: String?
        var qualityLevel: String?
        var region: String?
        var country: String?
        var appellation: String?
        var vineyard: String?
        var abv: Double?
        var drinkFrom: Int?
        var drinkUntil: Int?
        var notes: String?
        var userNotes: String?
        var foodPairing: String?
        var servingTemp: String?
        var closureRaw: String?
        var dataSourcesJSON: String?
        var rating: Int?
        var signature: String
        var updatedAt: Date

        init(_ wine: Wine) {
            producer = wine.producer
            name = wine.name
            vintage = wine.vintage
            wineTypeRaw = wine.wineTypeRaw
            colorRaw = wine.colorRaw
            sweetnessRaw = wine.sweetnessRaw
            qualityLevel = wine.qualityLevel
            region = wine.region
            country = wine.country
            appellation = wine.appellation
            vineyard = wine.vineyard
            abv = wine.abv
            drinkFrom = wine.drinkFrom
            drinkUntil = wine.drinkUntil
            notes = wine.notes
            userNotes = wine.userNotes
            foodPairing = wine.foodPairing
            servingTemp = wine.servingTemp
            closureRaw = wine.closureRaw
            dataSourcesJSON = wine.dataSourcesJSON
            rating = wine.rating
            signature = wine.signature
            updatedAt = wine.updatedAt
        }

        func apply(to wine: Wine) {
            wine.producer = producer
            wine.name = name
            wine.vintage = vintage
            wine.wineTypeRaw = wineTypeRaw
            wine.colorRaw = colorRaw
            wine.sweetnessRaw = sweetnessRaw
            wine.qualityLevel = qualityLevel
            wine.region = region
            wine.country = country
            wine.appellation = appellation
            wine.vineyard = vineyard
            wine.abv = abv
            wine.drinkFrom = drinkFrom
            wine.drinkUntil = drinkUntil
            wine.notes = notes
            wine.userNotes = userNotes
            wine.foodPairing = foodPairing
            wine.servingTemp = servingTemp
            wine.closureRaw = closureRaw
            wine.dataSourcesJSON = dataSourcesJSON
            wine.rating = rating
            wine.signature = signature
            wine.updatedAt = updatedAt
        }
    }

    struct BottleRecord: Equatable, Sendable {
        var wineID: UUID?
        var sizeML: Int
        var location: String?
        var purchaseDate: Date?
        var purchasePrice: Double?
        var vendor: String?
        var price: Double?
        var statusRaw: String
        var drunkOn: Date?
        var personalRating: Int?
        var createdAt: Date
        var updatedAt: Date

        init(_ bottle: Bottle) {
            wineID = bottle.wine?.id
            sizeML = bottle.sizeML
            location = bottle.location
            purchaseDate = bottle.purchaseDate
            purchasePrice = bottle.purchasePrice
            vendor = bottle.vendor
            price = bottle.price
            statusRaw = bottle.statusRaw
            drunkOn = bottle.drunkOn
            personalRating = bottle.personalRating
            createdAt = bottle.createdAt
            updatedAt = bottle.updatedAt
        }

        func apply(to bottle: Bottle) {
            bottle.sizeML = sizeML
            bottle.location = location
            bottle.purchaseDate = purchaseDate
            bottle.purchasePrice = purchasePrice
            bottle.vendor = vendor
            bottle.price = price
            bottle.statusRaw = statusRaw
            bottle.drunkOn = drunkOn
            bottle.personalRating = personalRating
            bottle.createdAt = createdAt
            bottle.updatedAt = updatedAt
        }
    }

    @MainActor
    static func capture(_ context: ModelContext) -> CellarSnapshot {
        let wines = (try? context.fetch(FetchDescriptor<Wine>())) ?? []
        let bottles = (try? context.fetch(FetchDescriptor<Bottle>())) ?? []
        return CellarSnapshot(
            wines: Dictionary(wines.map { ($0.id, WineRecord($0)) }, uniquingKeysWith: { first, _ in first }),
            bottles: Dictionary(bottles.map { ($0.id, BottleRecord($0)) }, uniquingKeysWith: { first, _ in first })
        )
    }

}

/// What one action changed, as the values to write: wines whose fields
/// differ, bottles to recreate, bottles to delete and bottles to update. Only
/// these are touched, so anything that changed meanwhile (an import, another
/// action) survives an undo.
struct CellarDiff: Sendable {
    var wines: [UUID: CellarSnapshot.WineRecord] = [:]
    var insertBottles: [UUID: CellarSnapshot.BottleRecord] = [:]
    var deleteBottles: Set<UUID> = []
    var updateBottles: [UUID: CellarSnapshot.BottleRecord] = [:]

    /// The change that turns `from` into `to`.
    init(from: CellarSnapshot, to: CellarSnapshot) {
        for (id, record) in to.wines where from.wines[id] != nil && from.wines[id] != record {
            wines[id] = record
        }
        for (id, record) in to.bottles {
            if let old = from.bottles[id] {
                if old != record { updateBottles[id] = record }
            } else {
                insertBottles[id] = record
            }
        }
        deleteBottles = Set(from.bottles.keys).subtracting(to.bottles.keys)
    }

    var isEmpty: Bool {
        wines.isEmpty && insertBottles.isEmpty && deleteBottles.isEmpty && updateBottles.isEmpty
    }

    @MainActor
    func apply(to context: ModelContext) {
        let wines = Dictionary(
            ((try? context.fetch(FetchDescriptor<Wine>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (id, record) in self.wines {
            if let wine = wines[id] { record.apply(to: wine) }
        }
        let bottles = Dictionary(
            ((try? context.fetch(FetchDescriptor<Bottle>())) ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (id, record) in updateBottles {
            if let bottle = bottles[id] { record.apply(to: bottle) }
        }
        for id in deleteBottles {
            if let bottle = bottles[id] { context.delete(bottle) }
        }
        for (id, record) in insertBottles where bottles[id] == nil {
            guard let wineID = record.wineID, let wine = wines[wineID] else { continue }
            let bottle = Bottle(wine: wine)
            bottle.id = id
            context.insert(bottle)
            record.apply(to: bottle)
        }
    }
}
