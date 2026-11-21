import Foundation

/// A review file from `/import-wines`, the Swift mirror of the web app's
/// `reviewFileSchema`. Nullable fields may also be missing.
public struct ReviewFile: Decodable, Sendable {
    public var generatedAt: String?
    public var bottles: [ReviewBottle]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case bottles
    }
}

public struct ReviewBottle: Decodable, Sendable {
    public var photos: [String]
    public var dedup: Dedup
    public var wine: ReviewWine
    public var bottle: ReviewBottleData
    public var confidence: Double
    public var openQuestions: [String]?

    enum CodingKeys: String, CodingKey {
        case photos, dedup, wine, bottle, confidence
        case openQuestions = "open_questions"
    }
}

public enum Dedup: Decodable, Equatable, Sendable {
    case newWine
    case matchExisting(number: Int)

    enum CodingKeys: String, CodingKey {
        case action
        case wineID = "wine_id"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(String.self, forKey: .action)
        switch action {
        case "new_wine": self = .newWine
        case "match_existing": self = .matchExisting(number: try container.decode(Int.self, forKey: .wineID))
        default:
            throw DecodingError.dataCorruptedError(forKey: .action, in: container, debugDescription: action)
        }
    }
}

public struct ReviewGrape: Decodable, Sendable {
    public var canonical: String
    public var labelName: String?
    public var color: GrapeColor
    public var percentage: Double?

    enum CodingKeys: String, CodingKey {
        case canonical, color, percentage
        case labelName = "label_name"
    }
}

public struct ReviewWine: Decodable, Sendable {
    public var producer: String
    public var name: String?
    public var vintage: Int?
    public var wineType: WineType?
    public var color: WineColor?
    public var sweetness: Sweetness?
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
    public var closure: Closure?
    public var isOrganic: Bool?
    public var isVegan: Bool?
    public var externalLinks: [String]?
    public var extraData: [String: JSONValue]?
    public var dataSources: [String: Provenance]?
    public var importConfidence: Double
    public var grapes: [ReviewGrape]?

    enum CodingKeys: String, CodingKey {
        case producer, name, vintage, color, sweetness, region, country, appellation, vineyard, abv, closure, description, grapes
        case wineType = "wine_type"
        case qualityLevel = "quality_level"
        case residualSugar = "residual_sugar_gl"
        case acidity = "acidity_gl"
        case drinkFrom = "drink_from"
        case drinkUntil = "drink_until"
        case foodPairing = "food_pairing"
        case servingTemp = "serving_temp_c"
        case isOrganic = "is_organic"
        case isVegan = "is_vegan"
        case externalLinks = "external_links"
        case extraData = "extra_data"
        case dataSources = "data_sources"
        case importConfidence = "import_confidence"
    }
}

public struct ReviewBottleData: Decodable, Sendable {
    public var sizeML: Int?
    public var location: String?
    public var purchaseDate: String?
    public var purchasePrice: Double?
    public var vendor: String?
    public var price: Double?
    public var status: BottleStatus?
    public var drunkOn: String?
    public var personalRating: Int?

    enum CodingKeys: String, CodingKey {
        case location, status
        case sizeML = "bottle_size_ml"
        case purchaseDate = "purchase_date"
        case purchasePrice = "purchase_price"
        case vendor = "purchase_vendor"
        case price = "current_value"
        case drunkOn = "consumed_date"
        case personalRating = "personal_rating"
    }
}

/// Any JSON value, for `extra_data`, kept as it was written.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
