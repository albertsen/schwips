import Foundation

/// A wine field that can be edited in place. The raw value is the key in the
/// provenance map, the same names the review files use.
public enum WineField: String, CaseIterable, Sendable {
    case producer
    case name
    case vintage
    case qualityLevel = "quality_level"
    case appellation
    case region
    case country
    case vineyard
    case abv
    case drinkingWindow = "drink_from"
    case servingTemp = "serving_temp_c"
    case foodPairing = "food_pairing"
    case notes = "description"
    case userNotes = "user_notes"
    case wineType = "wine_type"
    case color
    case sweetness
    case closure
    case price = "current_value"

    /// The fields the match key is computed from.
    public var isIdentity: Bool {
        switch self {
        case .producer, .name, .vintage, .wineType, .qualityLevel, .appellation, .vineyard: true
        default: false
        }
    }

    /// The provenance keys this field writes. The drinking window is two.
    var provenanceKeys: [String] {
        self == .drinkingWindow ? ["drink_from", "drink_until"] : [rawValue]
    }

    public var title: String {
        switch self {
        case .producer: String(localized: "Winery")
        case .name: String(localized: "Name")
        case .vintage: String(localized: "Vintage")
        case .qualityLevel: String(localized: "Quality")
        case .appellation: String(localized: "Appellation")
        case .region: String(localized: "Region")
        case .country: String(localized: "Country")
        case .vineyard: String(localized: "Vineyard")
        case .abv: String(localized: "Alcohol")
        case .drinkingWindow: String(localized: "Drinking window")
        case .servingTemp: String(localized: "Serving temp.")
        case .foodPairing: String(localized: "Food pairing")
        case .notes: String(localized: "Description")
        case .userNotes: String(localized: "Notes")
        case .wineType: String(localized: "Type")
        case .color: String(localized: "Colour")
        case .sweetness: String(localized: "Taste")
        case .closure: String(localized: "Closure")
        case .price: String(localized: "Price")
        }
    }
}

/// A value the cellar refuses, with the message shown under the field.
public struct FieldError: LocalizedError, Equatable, Sendable {
    public let message: String
    public var errorDescription: String? { message }

    public init(_ message: String) {
        self.message = message
    }
}

/// The parsed value of an edit.
enum FieldValue: Equatable {
    case text(String?)
    case integer(Int?)
    case decimal(Double?)
    case range(Int?, Int?)
}

extension WineField {
    /// Parses and validates what was typed. An empty text removes the value,
    /// except for the winery.
    func parse(_ raw: String, currentYear: Int) throws(FieldError) -> FieldValue {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .producer:
            guard !text.isEmpty else { throw FieldError(String(localized: "The winery can’t be empty.")) }
            return .text(text)
        case .name, .qualityLevel, .appellation, .region, .country, .vineyard, .servingTemp, .foodPairing, .notes, .userNotes:
            return .text(text.isEmpty ? nil : text)
        case .vintage:
            guard !text.isEmpty else { return .integer(nil) }
            guard let year = Int(text), (1900...currentYear).contains(year) else {
                throw FieldError(String(localized: "Enter a year between 1900 and \(String(currentYear)), or leave it empty for a wine without vintage."))
            }
            return .integer(year)
        case .abv:
            guard !text.isEmpty else { return .decimal(nil) }
            guard let value = CellarFormatting.parseDecimal(text), (0...25).contains(value) else {
                throw FieldError(String(localized: "Enter an alcohol content between 0 and 25 %."))
            }
            return .decimal(value)
        case .price:
            guard !text.isEmpty else { return .decimal(nil) }
            guard let value = CellarFormatting.parseDecimal(text), value >= 0 else {
                throw FieldError(String(localized: "Enter a price of 0 or more."))
            }
            return .decimal(value)
        case .drinkingWindow:
            return try Self.parseRange(text)
        case .wineType, .color, .sweetness, .closure:
            return .text(text.isEmpty ? nil : text)
        }
    }

    /// "2026–2033", "2026-2033", "2026–" or "–2033"; empty removes both.
    private static func parseRange(_ text: String) throws(FieldError) -> FieldValue {
        guard !text.isEmpty else { return .range(nil, nil) }
        let invalid = FieldError(String(localized: "Enter the years like 2026–2033, each between 1900 and 2100."))
        let normalized = text.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        let parts = normalized.split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(parts.count) else { throw invalid }
        func year(_ part: String) throws(FieldError) -> Int? {
            if part.isEmpty || part == "?" { return nil }
            guard let value = Int(part), (1900...2100).contains(value) else { throw invalid }
            return value
        }
        let from = try year(parts[0])
        let until = parts.count == 2 ? try year(parts[1]) : from
        if let from, let until, from > until {
            throw FieldError(String(localized: "The first year can’t be after the second."))
        }
        return .range(from, until)
    }
}
