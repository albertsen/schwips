import Foundation
import Testing
@testable import SchwipsCore

@MainActor
struct FieldOperationTests {
    private let now = Day.parse(iso: "2026-11-21")!

    @Test func editMarksTheFieldAsUsers() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        try cellar.edit(.vineyard, to: " Dorsheimer Eierfels ", on: wine, now: now)
        #expect(wine.vineyard == "Dorsheimer Eierfels")
        #expect(wine.dataSources["vineyard"] == .user)
        try cellar.edit(.vineyard, to: "", on: wine, now: now)
        #expect(wine.vineyard == nil)
    }

    @Test func identityFieldsRecomputeTheSignature() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel", grapes: [("Riesling", nil)])
        try cellar.edit(.producer, to: "Schlossgut Diel", on: wine, now: now)
        #expect(wine.signature.hasPrefix("schlossgut diel|"))
        #expect(wine.signature == Signature.compute(wine.signatureInput))
    }

    @Test func validation() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        #expect(throws: FieldError.self) { try cellar.edit(.vintage, to: "20x3", on: wine, now: now) }
        #expect(throws: FieldError.self) { try cellar.edit(.vintage, to: "2027", on: wine, now: now) }
        #expect(throws: FieldError.self) { try cellar.edit(.producer, to: "  ", on: wine, now: now) }
        #expect(throws: FieldError.self) { try cellar.edit(.abv, to: "40", on: wine, now: now) }
        #expect(throws: FieldError.self) { try cellar.edit(.drinkingWindow, to: "2033–2026", on: wine, now: now) }
        #expect(throws: FieldError.self) { try cellar.edit(.price, to: "-1", on: wine, now: now) }
        try cellar.edit(.abv, to: "12,5 %", on: wine, now: now)
        #expect(wine.abv == 12.5)
        try cellar.edit(.drinkingWindow, to: "2026-2033", on: wine, now: now)
        #expect(wine.drinkFrom == 2026 && wine.drinkUntil == 2033)
        #expect(wine.dataSources["drink_until"] == .user)
    }

    @Test func priceGoesToEveryBottle() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel", price: 20, inStock: 2, drunk: 1)
        try cellar.edit(.price, to: "27,50", on: wine, now: now)
        #expect(wine.allBottles.allSatisfy { $0.price == 27.5 })
    }

    @Test func choices() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        try cellar.choose(.sweetness, rawValue: "off-dry", on: wine, now: now)
        #expect(wine.sweetness == .offDry)
        try cellar.choose(.sweetness, rawValue: nil, on: wine, now: now)
        #expect(wine.sweetness == nil)
    }

    @Test func bottles() throws {
        let cellar = try makeCellar()
        let wine = try addWine(cellar, number: 1, producer: "Diel", price: 26, inStock: 2)
        #expect(throws: FieldError.self) {
            try cellar.markFirstBottleDrunk(of: wine, on: now.addingTimeInterval(86_400 * 2), now: now)
        }
        try cellar.markFirstBottleDrunk(of: wine, on: now, now: now)
        #expect(wine.inStockCount == 1)
        let drunk = try #require(wine.drunkBottles.first)
        try cellar.removeBottle(drunk)
        #expect(wine.allBottles.count == 2)
        let added = try cellar.addBottle(to: wine, now: now)
        #expect(added.price == 26 && wine.inStockCount == 2)
        try cellar.setLocation("Regal 2", of: added)
        #expect(added.location == "Regal 2")
    }
}
