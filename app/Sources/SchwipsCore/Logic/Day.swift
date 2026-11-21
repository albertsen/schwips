import Foundation

/// Calendar days. A drunk or purchase date is stored at local noon, so a time
/// zone change never moves it to another day.
public enum Day {
    public static func noon(of date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    /// "2026-11-14" → that day at local noon; nil for anything else.
    public static func parse(iso text: String?, calendar: Calendar = .current) -> Date? {
        guard let text else { return nil }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return calendar.date(from: components)
    }

    public static func isAfterToday(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    public static func currentYear(now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: now)
    }
}
