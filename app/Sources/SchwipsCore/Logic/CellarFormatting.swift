import Foundation

/// Prices, numbers, years and days for one locale. Views pass the
/// environment's locale; tests pass a fixed one.
public struct CellarFormatting: Sendable {
    public let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    private var isGerman: Bool { locale.language.languageCode == .german }

    /// "€26.00" / "26,00 €".
    public func price(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(locale))
    }

    /// "12.5 %" / "12,5 %".
    public func percent(_ value: Double) -> String {
        "\(decimal(value)) %"
    }

    /// "12.5" / "12,5", at most two fraction digits.
    public func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }

    /// A year without grouping: "2023".
    public func year(_ value: Int) -> String { String(value) }

    /// "2026–2033", "2026–?", "?–2033".
    public func range(from: Int?, until: Int?) -> String? {
        guard from != nil || until != nil else { return nil }
        return "\(from.map(String.init) ?? "?")–\(until.map(String.init) ?? "?")"
    }

    /// "10-12" → "10–12 °C".
    public func servingTemp(_ text: String) -> String {
        "\(text.replacingOccurrences(of: "-", with: "–")) °C"
    }

    /// "21 Nov 2026" in English (in the region's order), "21.11.2026" in German.
    public func day(_ date: Date) -> String {
        if isGerman {
            return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// "21 Nov, 14:02" / "21. Nov., 14:02".
    public func dayAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale))
    }

    /// "21 Nov 2026, 14:02".
    public func fullDayAndTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(locale))
    }

    /// A number as typed in this locale: "12,5" or "12.5" both read as 12.5;
    /// "%", "€" and "°C" are ignored.
    public static func parseDecimal(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for symbol in ["%", "€", "°C", "°", "EUR"] {
            cleaned = cleaned.replacingOccurrences(of: symbol, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}
