import Foundation
import SwiftData

/// The second schema: `Wine.userNotes`, the user's own notes. Otherwise the
/// same as `SchemaV1` (see there for the rules), which stays as shipped; the
/// migration from it is lightweight.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Wine.self, Bottle.self, WineGrape.self, Grape.self, GrapeAlias.self, Photo.self, ImportRecord.self]
    }

    /// A distinct wine, the product. Stock is the count of its bottles in stock.
    @Model
    public final class Wine {
        public var id: UUID = UUID()
        /// The wine's number: the web app's id for copied wines, the next free
        /// one for new wines. Review files (`match_existing`) and
        /// `schwips://wine/<number>` links refer to it. Unique by the operations.
        public var number: Int = 0
        public var producer: String = ""
        public var name: String?
        public var vintage: Int?
        public var wineTypeRaw: String?
        public var colorRaw: String?
        public var sweetnessRaw: String?
        /// The bare legal tier ("DOCG", "VDP.Erste Lage"), never combined with a name.
        public var qualityLevel: String?
        public var region: String?
        public var country: String?
        /// The named designation ("Brunello di Montalcino", "Saint-Estèphe").
        public var appellation: String?
        public var vineyard: String?
        public var abv: Double?
        public var residualSugar: Double?
        public var acidity: Double?
        public var drinkFrom: Int?
        public var drinkUntil: Int?
        /// The description. Not `description`, which would shadow
        /// `CustomStringConvertible` in every interpolation.
        public var notes: String?
        /// The user's own notes ("Notizen"), always entered in the app.
        public var userNotes: String?
        public var foodPairing: String?
        /// A range like "10-12", as researched.
        public var servingTemp: String?
        public var closureRaw: String?
        public var isOrganic: Bool?
        public var isVegan: Bool?
        /// JSON array of URLs found during research.
        public var externalLinksJSON: String?
        /// JSON object of label facts without their own field.
        public var extraDataJSON: String?
        /// JSON object field name → `label` | `research` | `user`.
        public var dataSourcesJSON: String?
        public var importConfidence: Double?
        /// The personal rating, 1–5 stars.
        public var rating: Int?
        /// The normalized match key (`Signature.compute`).
        public var signature: String = ""
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \Bottle.wine)
        public var bottles: [Bottle]? = []
        @Relationship(deleteRule: .cascade, inverse: \WineGrape.wine)
        public var grapes: [WineGrape]? = []
        @Relationship(deleteRule: .cascade, inverse: \Photo.wine)
        public var photos: [Photo]? = []

        public init(number: Int, producer: String) {
            self.number = number
            self.producer = producer
        }
    }

    /// One physical bottle.
    @Model
    public final class Bottle {
        public var id: UUID = UUID()
        public var sizeML: Int = 750
        public var location: String?
        /// A calendar day, stored at local noon.
        public var purchaseDate: Date?
        public var purchasePrice: Double?
        public var vendor: String?
        /// The estimated current price in euros, the same on every bottle of a wine.
        public var price: Double?
        /// `in_stock`, `consumed` or `gifted`, the web app's values.
        public var statusRaw: String = BottleStatus.inStock.rawValue
        /// The day it was drunk, stored at local noon.
        public var drunkOn: Date?
        public var personalRating: Int?
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var wine: Wine?

        public init(wine: Wine? = nil) {
            self.wine = wine
        }
    }

    /// The ordered join between a wine and a canonical grape.
    @Model
    public final class WineGrape {
        public var id: UUID = UUID()
        public var percentage: Double?
        /// The name as printed on the label ("Pinot Grigio").
        public var labelName: String?
        public var position: Int = 0
        public var wine: Wine?
        public var grape: Grape?

        public init() {}
    }

    /// A canonical grape variety, German-preferred name.
    @Model
    public final class Grape {
        public var id: UUID = UUID()
        public var name: String = ""
        public var colorRaw: String?
        @Relationship(deleteRule: .cascade, inverse: \GrapeAlias.grape)
        public var aliases: [GrapeAlias]? = []
        @Relationship(deleteRule: .nullify, inverse: \WineGrape.grape)
        public var wineGrapes: [WineGrape]? = []

        public init(name: String, colorRaw: String?) {
            self.name = name
            self.colorRaw = colorRaw
        }
    }

    /// A synonym of a grape ("Pinot Grigio" → Grauburgunder).
    @Model
    public final class GrapeAlias {
        public var id: UUID = UUID()
        public var alias: String = ""
        public var grape: Grape?

        public init(alias: String) {
            self.alias = alias
        }
    }

    /// A label photo, shrunk to 2400 px on its longest side.
    @Model
    public final class Photo {
        public var id: UUID = UUID()
        /// The original file name ("IMG_5106.jpeg").
        public var fileName: String = ""
        public var isPrimary: Bool = false
        public var position: Int = 0
        @Attribute(.externalStorage)
        public var imageData: Data?
        /// 240 px, for the detail's strip.
        public var thumbnailData: Data?
        public var createdAt: Date = Date.now
        public var wine: Wine?

        public init(fileName: String) {
            self.fileName = fileName
        }
    }

    /// One review file the app has seen: imported, failed, or skipped because
    /// it was already in the folder when it was chosen. `/import-wines` polls
    /// it by file name.
    @Model
    public final class ImportRecord {
        public var id: UUID = UUID()
        public var fileName: String = ""
        public var fileModified: Date?
        /// `imported`, `failed` or `skipped`.
        public var statusRaw: String = ImportStatus.imported.rawValue
        /// The failure message, in the app's language.
        public var message: String?
        public var bottleCount: Int = 0
        public var newWineCount: Int = 0
        /// Comma-separated numbers of the wines this import created.
        public var newWineNumbers: String?
        /// Numbers of existing wines that got a bottle.
        public var matchedWineNumbers: String?
        public var openQuestionCount: Int = 0
        public var photoCount: Int = 0
        public var finishedAt: Date = Date.now

        public init(fileName: String, fileModified: Date?, status: ImportStatus) {
            self.fileName = fileName
            self.fileModified = fileModified
            self.statusRaw = status.rawValue
        }
    }
}

public enum SchwipsMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

public typealias Wine = SchemaV2.Wine
public typealias Bottle = SchemaV2.Bottle
public typealias WineGrape = SchemaV2.WineGrape
public typealias Grape = SchemaV2.Grape
public typealias GrapeAlias = SchemaV2.GrapeAlias
public typealias Photo = SchemaV2.Photo
public typealias ImportRecord = SchemaV2.ImportRecord
