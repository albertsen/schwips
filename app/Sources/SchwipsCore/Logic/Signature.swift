import Foundation

/// The normalized match key of a wine, an exact port of the web app's
/// `computeSignature`: a new bottle whose wine has the same key as an existing
/// wine is added to it instead of creating a duplicate. Grapes are canonical
/// names, so "Pinot Grigio" and "Grauburgunder" give the same key.
public enum Signature {
    public struct Input: Equatable, Sendable {
        public var producer: String?
        public var vintage: Int?
        public var appellation: String?
        public var vineyard: String?
        public var name: String?
        public var qualityLevel: String?
        public var wineType: String?
        public var grapes: [String]

        public init(
            producer: String?, vintage: Int?, appellation: String?, vineyard: String?, name: String?,
            qualityLevel: String?, wineType: String?, grapes: [String]
        ) {
            self.producer = producer
            self.vintage = vintage
            self.appellation = appellation
            self.vineyard = vineyard
            self.name = name
            self.qualityLevel = qualityLevel
            self.wineType = wineType
            self.grapes = grapes
        }
    }

    public static func compute(_ input: Input) -> String {
        let grapes = input.grapes.map(normalize).filter { !$0.isEmpty }.sorted().joined(separator: ",")
        return [
            normalize(input.producer),
            normalize(input.vintage.map(String.init)),
            normalize(input.appellation),
            normalize(input.vineyard),
            normalize(input.name),
            normalize(input.qualityLevel),
            normalize(input.wineType),
            grapes,
        ].joined(separator: "|")
    }

    /// Lowercase, German umlauts folded first (ä → a, ß → ss), remaining
    /// diacritics stripped, whitespace runs collapsed and trimmed.
    static func normalize(_ part: String?) -> String {
        guard let part else { return "" }
        var text = part.lowercased()
        for (from, to) in [("ä", "a"), ("ö", "o"), ("ü", "u"), ("ß", "ss")] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        let scalars = text.decomposedStringWithCompatibilityMapping.unicodeScalars
            .filter { !(0x300...0x36F).contains($0.value) }
        text = String(String.UnicodeScalarView(scalars))
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
