import Foundation

/// Case- and diacritic-insensitive comparison with German collation, whatever
/// the UI language: "Ä" sorts with "A", "serilhan" finds "Sérilhan".
public enum TextFolding {
    static let locale = Locale(identifier: "de_DE")
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .numeric]

    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    }

    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: options, range: nil, locale: locale)
    }
}
