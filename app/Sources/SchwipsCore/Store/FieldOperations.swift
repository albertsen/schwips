import Foundation
import SwiftData

extension Cellar {
    /// Saves an edit typed in place. The field is marked as entered by the
    /// user; an identity field recomputes the match key; the price goes to
    /// every bottle of the wine. Throws the message to show under the field.
    public func edit(_ field: WineField, to raw: String, on wine: Wine, now: Date = .now) throws {
        let value = try field.parse(raw, currentYear: Day.currentYear(now: now))
        try change(LocalizedStringResource("Edit \(field.title)")) {
            switch (field, value) {
            case (.producer, .text(let text)): wine.producer = text ?? wine.producer
            case (.name, .text(let text)): wine.name = text
            case (.qualityLevel, .text(let text)): wine.qualityLevel = text
            case (.appellation, .text(let text)): wine.appellation = text
            case (.region, .text(let text)): wine.region = text
            case (.country, .text(let text)): wine.country = text
            case (.vineyard, .text(let text)): wine.vineyard = text
            case (.servingTemp, .text(let text)): wine.servingTemp = text
            case (.foodPairing, .text(let text)): wine.foodPairing = text
            case (.notes, .text(let text)): wine.notes = text
            case (.userNotes, .text(let text)): wine.userNotes = text
            case (.vintage, .integer(let year)): wine.vintage = year
            case (.abv, .decimal(let number)): wine.abv = number
            case (.price, .decimal(let number)):
                for bottle in wine.allBottles {
                    bottle.price = number
                    bottle.updatedAt = now
                }
            case (.drinkingWindow, .range(let from, let until)):
                wine.drinkFrom = from
                wine.drinkUntil = until
            case (.wineType, .text(let text)): wine.wineTypeRaw = text.flatMap(WineType.init(rawValue:))?.rawValue
            case (.color, .text(let text)): wine.colorRaw = text.flatMap(WineColor.init(rawValue:))?.rawValue
            case (.sweetness, .text(let text)): wine.sweetnessRaw = text.flatMap(Sweetness.init(rawValue:))?.rawValue
            case (.closure, .text(let text)): wine.closureRaw = text.flatMap(Closure.init(rawValue:))?.rawValue
            default: break
            }
            markEdited(field, on: wine, now: now)
        }
    }

    /// Sets a choice field (type, colour, taste, closure) to a raw value, or
    /// removes it with nil.
    public func choose(_ field: WineField, rawValue: String?, on wine: Wine, now: Date = .now) throws {
        try edit(field, to: rawValue ?? "", on: wine, now: now)
    }

    /// 1–5 stars, or nil to clear.
    public func setRating(_ rating: Int?, on wine: Wine, now: Date = .now) throws {
        guard rating == nil || (1...5).contains(rating!) else { return }
        try change(LocalizedStringResource("Rate Wine")) {
            wine.rating = rating
            wine.updatedAt = now
        }
    }

    private func markEdited(_ field: WineField, on wine: Wine, now: Date) {
        var sources = wine.dataSources
        for key in field.provenanceKeys { sources[key] = .user }
        wine.dataSources = sources
        if field.isIdentity {
            wine.signature = Signature.compute(wine.signatureInput)
        }
        wine.updatedAt = now
    }
}
