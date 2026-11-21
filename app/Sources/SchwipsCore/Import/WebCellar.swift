import Foundation
import SwiftData

/// The web app's cellar as values, read by `SchwipsWebCellar` from
/// `data/schwips.db`. Field names follow the web app's columns.
public struct WebCellar: Sendable {
    public struct WineRow: Sendable {
        public var id: Int
        public var producer: String
        public var name: String?
        public var vintage: Int?
        public var wineType: String?
        public var color: String?
        public var sweetness: String?
        public var qualityLevel: String?
        public var region: String?
        public var country: String?
        public var appellation: String?
        public var vineyard: String?
        public var abv: Double?
        public var residualSugar: Double?
        public var acidity: Double?
        public var drinkFrom: Int?
        public var drinkUntil: Int?
        public var description: String?
        public var foodPairing: String?
        public var servingTemp: String?
        public var closure: String?
        public var isOrganic: Bool?
        public var isVegan: Bool?
        public var externalLinksJSON: String?
        public var extraDataJSON: String?
        public var dataSourcesJSON: String?
        public var importConfidence: Double?
        public var rating: Int?
        public var signature: String
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: Int, producer: String, signature: String, createdAt: Date, updatedAt: Date) {
            self.id = id
            self.producer = producer
            self.signature = signature
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    public struct WineGrapeRow: Sendable {
        public var wineID: Int
        public var grapeName: String
        public var labelName: String?
        public var percentage: Double?
        public init(wineID: Int, grapeName: String, labelName: String?, percentage: Double?) {
            self.wineID = wineID
            self.grapeName = grapeName
            self.labelName = labelName
            self.percentage = percentage
        }
    }

    public struct GrapeRow: Sendable {
        public var name: String
        public var color: String?
        public var aliases: [String]
        public init(name: String, color: String?, aliases: [String]) {
            self.name = name
            self.color = color
            self.aliases = aliases
        }
    }

    public struct BottleRow: Sendable {
        public var wineID: Int
        public var sizeML: Int
        public var location: String?
        public var purchaseDate: String?
        public var purchasePrice: Double?
        public var vendor: String?
        public var price: Double?
        public var status: String
        public var drunkOn: String?
        public var personalRating: Int?
        public var createdAt: Date
        public var updatedAt: Date
        public init(wineID: Int, sizeML: Int, status: String, createdAt: Date, updatedAt: Date) {
            self.wineID = wineID
            self.sizeML = sizeML
            self.status = status
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    public struct PhotoRow: Sendable {
        public var wineID: Int
        /// Relative to `photos/`, like "12/IMG_5106.jpeg".
        public var path: String
        public var isPrimary: Bool
        public var createdAt: Date
        public init(wineID: Int, path: String, isPrimary: Bool, createdAt: Date) {
            self.wineID = wineID
            self.path = path
            self.isPrimary = isPrimary
            self.createdAt = createdAt
        }
    }

    public var wines: [WineRow]
    public var wineGrapes: [WineGrapeRow]
    public var grapes: [GrapeRow]
    public var bottles: [BottleRow]
    public var photos: [PhotoRow]

    public init(wines: [WineRow], wineGrapes: [WineGrapeRow], grapes: [GrapeRow], bottles: [BottleRow], photos: [PhotoRow]) {
        self.wines = wines
        self.wineGrapes = wineGrapes
        self.grapes = grapes
        self.bottles = bottles
        self.photos = photos
    }
}

/// What the copy brought over.
public struct WebCopyOutcome: Equatable, Sendable {
    public var wines = 0
    public var bottles = 0
    public var photos = 0
    public var missingPhotos = 0
}

extension Cellar {
    /// Copies the web app's cellar into an empty cellar, all or nothing. Every
    /// wine keeps its number (the web id). `photos` holds the shrunk photos by
    /// their path; a path missing from it counts as a missing photo. Not undoable.
    @discardableResult
    public func copyWebCellar(_ web: WebCellar, photos: [String: PhotoShrinker.Result]) throws -> WebCopyOutcome {
        guard try isEmpty() else {
            throw ImportError(String(localized: "The cellar isn’t empty."))
        }
        var outcome = WebCopyOutcome()
        do {
            var grapeIndex = GrapeIndex(try grapes())
            for row in web.grapes {
                let grape = grapeIndex.resolve(name: row.name, color: row.color, in: context)
                for alias in row.aliases { grapeIndex.learnAlias(alias, for: grape, in: context) }
            }
            var wines: [Int: Wine] = [:]
            for row in web.wines {
                let wine = Wine(number: row.id, producer: row.producer)
                context.insert(wine)
                apply(row, to: wine)
                wines[row.id] = wine
                outcome.wines += 1
            }
            var positions: [Int: Int] = [:]
            for row in web.wineGrapes {
                guard let wine = wines[row.wineID] else { continue }
                let link = WineGrape()
                link.labelName = row.labelName
                link.percentage = row.percentage
                link.position = positions[row.wineID, default: 0]
                positions[row.wineID, default: 0] += 1
                context.insert(link)
                link.wine = wine
                link.grape = grapeIndex.resolve(name: row.grapeName, color: nil, in: context)
            }
            // The web app's stored keys go stale when a field's values change
            // (39 of 45 still say "sekt" for sparkling), so they are recomputed.
            for wine in wines.values {
                wine.signature = Signature.compute(wine.signatureInput)
            }
            for row in web.bottles {
                guard let wine = wines[row.wineID] else { continue }
                let bottle = Bottle()
                context.insert(bottle)
                bottle.wine = wine
                bottle.sizeML = row.sizeML
                bottle.location = row.location
                bottle.purchaseDate = Day.parse(iso: row.purchaseDate)
                bottle.purchasePrice = row.purchasePrice
                bottle.vendor = row.vendor
                bottle.price = row.price
                bottle.statusRaw = BottleStatus(rawValue: row.status)?.rawValue ?? BottleStatus.inStock.rawValue
                bottle.drunkOn = Day.parse(iso: row.drunkOn)
                bottle.personalRating = row.personalRating
                bottle.createdAt = row.createdAt
                bottle.updatedAt = row.updatedAt
                outcome.bottles += 1
            }
            var photoPositions: [Int: Int] = [:]
            for row in web.photos {
                guard let wine = wines[row.wineID] else { continue }
                guard let prepared = photos[row.path] else {
                    outcome.missingPhotos += 1
                    continue
                }
                let photo = Photo(fileName: URL(fileURLWithPath: row.path).lastPathComponent)
                photo.imageData = prepared.image
                photo.thumbnailData = prepared.thumbnail
                photo.isPrimary = row.isPrimary
                photo.position = photoPositions[row.wineID, default: 0]
                photoPositions[row.wineID, default: 0] += 1
                photo.createdAt = row.createdAt
                context.insert(photo)
                photo.wine = wine
                outcome.photos += 1
            }
            try context.save()
            return outcome
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Fills an empty cellar's grape list with the common varieties and their
    /// aliases (Start Empty), so "Pinot Grigio" resolves to Grauburgunder.
    public func seedGrapes() throws {
        var index = GrapeIndex(try grapes())
        for seed in GrapeSeed.all {
            let grape = index.resolve(name: seed.name, color: seed.color, in: context)
            for alias in seed.aliases { index.learnAlias(alias, for: grape, in: context) }
        }
        try save()
    }

    private func apply(_ row: WebCellar.WineRow, to wine: Wine) {
        wine.name = row.name
        wine.vintage = row.vintage
        wine.wineTypeRaw = row.wineType
        wine.colorRaw = row.color
        wine.sweetnessRaw = row.sweetness
        wine.qualityLevel = row.qualityLevel
        wine.region = row.region
        wine.country = row.country
        wine.appellation = row.appellation
        wine.vineyard = row.vineyard
        wine.abv = row.abv
        wine.residualSugar = row.residualSugar
        wine.acidity = row.acidity
        wine.drinkFrom = row.drinkFrom
        wine.drinkUntil = row.drinkUntil
        wine.notes = row.description
        wine.foodPairing = row.foodPairing
        wine.servingTemp = row.servingTemp
        wine.closureRaw = row.closure
        wine.isOrganic = row.isOrganic
        wine.isVegan = row.isVegan
        wine.externalLinksJSON = row.externalLinksJSON
        wine.extraDataJSON = row.extraDataJSON
        wine.dataSourcesJSON = row.dataSourcesJSON
        wine.importConfidence = row.importConfidence
        wine.rating = row.rating
        wine.signature = row.signature
        wine.createdAt = row.createdAt
        wine.updatedAt = row.updatedAt
    }
}

/// The web app's grape seed (`scripts/seed-grapes.ts`).
enum GrapeSeed {
    struct Entry {
        let name: String
        let color: String
        let aliases: [String]
    }

    static let all: [Entry] = [
        Entry(name: "Grauburgunder", color: "white", aliases: ["Pinot Gris", "Pinot Grigio", "Ruländer"]),
        Entry(name: "Weißburgunder", color: "white", aliases: ["Pinot Blanc", "Pinot Bianco", "Klevner"]),
        Entry(name: "Spätburgunder", color: "red", aliases: ["Pinot Noir", "Pinot Nero", "Blauburgunder"]),
        Entry(name: "Müller-Thurgau", color: "white", aliases: ["Rivaner"]),
        Entry(name: "Zweigelt", color: "red", aliases: ["Blauer Zweigelt"]),
        Entry(name: "Riesling", color: "white", aliases: []),
        Entry(name: "Silvaner", color: "white", aliases: []),
        Entry(name: "Chardonnay", color: "white", aliases: []),
        Entry(name: "Sauvignon Blanc", color: "white", aliases: []),
        Entry(name: "Nebbiolo", color: "red", aliases: []),
        Entry(name: "Sangiovese", color: "red", aliases: []),
        Entry(name: "Merlot", color: "red", aliases: []),
        Entry(name: "Cabernet Sauvignon", color: "red", aliases: []),
    ]
}
