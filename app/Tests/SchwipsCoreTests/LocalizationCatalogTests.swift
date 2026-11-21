import Foundation
import Testing

/// Reads `Resources/Localizable.xcstrings` (through `#filePath`, not a bundle)
/// and fails when a text lacks English or German, a value still needs review,
/// or a plural lacks `one` or `other`.
struct LocalizationCatalogTests {
    private typealias JSON = [String: Any]

    private func loadStrings() throws -> [String: JSON] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try #require(object as? JSON)
        return try #require(root["strings"] as? [String: JSON])
    }

    private func units(_ localization: JSON) -> [(form: String?, unit: JSON)] {
        if let unit = localization["stringUnit"] as? JSON { return [(nil, unit)] }
        guard let plural = (localization["variations"] as? JSON)?["plural"] as? JSON else { return [] }
        return plural.compactMap { form, value in
            ((value as? JSON)?["stringUnit"] as? JSON).map { (form, $0) }
        }
    }

    @Test func everyKeyHasEnglishAndGerman() throws {
        let strings = try loadStrings()
        #expect(strings.count > 150)
        for (key, entry) in strings {
            #expect(!key.isEmpty, "an empty key")
            for language in ["en", "de"] {
                let localization = (entry["localizations"] as? JSON)?[language] as? JSON
                #expect(localization != nil, "\(key) has no \(language) value")
                let found = units(localization ?? [:])
                #expect(!found.isEmpty, "\(key) \(language) has no value")
                for (_, unit) in found {
                    #expect(!((unit["value"] as? String) ?? "").isEmpty, "\(key) has an empty \(language) value")
                    #expect(unit["state"] as? String == "translated", "\(key) \(language) is \(unit["state"] ?? "?")")
                }
                if let plural = (localization?["variations"] as? JSON)?["plural"] as? JSON {
                    #expect(plural["one"] != nil && plural["other"] != nil, "\(key) \(language) plural lacks one or other")
                }
            }
        }
    }

    /// German terms from the spec.
    @Test func germanTermsMatchTheSpec() throws {
        let strings = try loadStrings()
        func german(_ key: String) -> String? {
            let localization = ((strings[key]?["localizations"] as? JSON)?["de"] as? JSON) ?? [:]
            return units(localization).first?.unit["value"] as? String
        }
        #expect(german("In Stock") == "Im Bestand")
        #expect(german("Ready to Drink") == "Trinkreif")
        #expect(german("chip.readyToDrink") == "Trinkreif jetzt")
        #expect(german("Mark as Drunk…") == "Als getrunken markieren…")
        #expect(german("Copy Cellar") == "Keller kopieren")
        #expect(german("Welcome to Schwips") == "Willkommen bei Schwips")
    }
}
