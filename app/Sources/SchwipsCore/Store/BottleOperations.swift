import Foundation
import SwiftData

extension Cellar {
    /// Marks an in-stock bottle as drunk on `day` (today by default). A day
    /// after today is refused.
    public func markDrunk(_ bottle: Bottle, on day: Date = .now, now: Date = .now) throws {
        guard bottle.status == .inStock else { return }
        guard !Day.isAfterToday(day, now: now) else {
            throw FieldError(String(localized: "The date can’t be in the future."))
        }
        try change(LocalizedStringResource("Mark as Drunk")) {
            bottle.status = .consumed
            bottle.drunkOn = Day.noon(of: day)
            bottle.updatedAt = now
        }
    }

    /// Mark as Drunk for the first in-stock bottle (⌘D).
    public func markFirstBottleDrunk(of wine: Wine, on day: Date = .now, now: Date = .now) throws {
        guard let bottle = wine.inStockBottles.first else { return }
        try markDrunk(bottle, on: day, now: now)
    }

    public func setDrunkDate(_ day: Date, of bottle: Bottle, now: Date = .now) throws {
        guard bottle.status == .consumed else { return }
        guard !Day.isAfterToday(day, now: now) else {
            throw FieldError(String(localized: "The date can’t be in the future."))
        }
        let noon = Day.noon(of: day)
        guard bottle.drunkOn != noon else { return }
        try change(LocalizedStringResource("Change Drunk Date")) {
            bottle.drunkOn = noon
            bottle.updatedAt = now
        }
    }

    /// Adds one 750 ml bottle in stock with the wine's price.
    @discardableResult
    public func addBottle(to wine: Wine, now: Date = .now) throws -> Bottle {
        try change(LocalizedStringResource("Add Bottle")) {
            let bottle = Bottle(wine: wine)
            bottle.price = wine.price
            bottle.createdAt = now
            bottle.updatedAt = now
            context.insert(bottle)
            wine.updatedAt = now
            return bottle
        }
    }

    /// Deletes a bottle added by mistake. Drunk bottles stay as history.
    public func removeBottle(_ bottle: Bottle) throws {
        guard bottle.status == .inStock else { return }
        try change(LocalizedStringResource("Remove Bottle")) {
            context.delete(bottle)
        }
    }

    public func setLocation(_ raw: String, of bottle: Bottle, now: Date = .now) throws {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = text.isEmpty ? nil : text
        guard bottle.location != location else { return }
        try change(LocalizedStringResource("Edit Location")) {
            bottle.location = location
            bottle.updatedAt = now
        }
    }
}
