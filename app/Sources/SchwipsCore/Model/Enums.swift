import Foundation

/// The coarse wine category, checked on import in this order: Kabinett on the
/// label, Champagne appellation, any other sparkling, everything else.
public enum WineType: String, CaseIterable, Codable, Sendable {
    case wine, sparkling, champagne, kabinett

    public var label: String {
        switch self {
        case .wine: String(localized: "wineType.wine", defaultValue: "Wine")
        case .sparkling: String(localized: "wineType.sparkling", defaultValue: "Sparkling")
        case .champagne: String(localized: "wineType.champagne", defaultValue: "Champagne")
        case .kabinett: String(localized: "wineType.kabinett", defaultValue: "Kabinett")
        }
    }
}

public enum WineColor: String, CaseIterable, Codable, Sendable {
    case white, red, rose, orange

    public var label: String {
        switch self {
        case .white: String(localized: "color.white", defaultValue: "White")
        case .red: String(localized: "color.red", defaultValue: "Red")
        case .rose: String(localized: "color.rose", defaultValue: "Rosé")
        case .orange: String(localized: "color.orange", defaultValue: "Orange")
        }
    }
}

public enum Sweetness: String, CaseIterable, Codable, Sendable {
    case dry
    case offDry = "off-dry"
    case medium
    case sweet
    case nobleSweet = "noble-sweet"

    public var label: String {
        switch self {
        case .dry: String(localized: "sweetness.dry", defaultValue: "Dry")
        case .offDry: String(localized: "sweetness.offDry", defaultValue: "Off-dry")
        case .medium: String(localized: "sweetness.medium", defaultValue: "Medium")
        case .sweet: String(localized: "sweetness.sweet", defaultValue: "Sweet")
        case .nobleSweet: String(localized: "sweetness.nobleSweet", defaultValue: "Noble sweet")
        }
    }
}

public enum Closure: String, CaseIterable, Codable, Sendable {
    case cork, screwcap, glass, crown

    public var label: String {
        switch self {
        case .cork: String(localized: "closure.cork", defaultValue: "Cork")
        case .screwcap: String(localized: "closure.screwcap", defaultValue: "Screw cap")
        case .glass: String(localized: "closure.glass", defaultValue: "Glass stopper")
        case .crown: String(localized: "closure.crown", defaultValue: "Crown cap")
        }
    }
}

/// The web app's values, so `sqlite3` queries read the same words.
public enum BottleStatus: String, CaseIterable, Codable, Sendable {
    case inStock = "in_stock"
    case consumed
    case gifted
}

public enum GrapeColor: String, CaseIterable, Codable, Sendable {
    case white, red
}

/// Where a field's value came from.
public enum Provenance: String, Codable, Sendable {
    case label, research, user
}

public enum ImportStatus: String, Codable, Sendable {
    case imported, failed, skipped
}
