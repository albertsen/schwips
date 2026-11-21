import Foundation
import SwiftData
import Testing
@testable import SchwipsCore

@MainActor
struct UndoTests {
    private func refetch(_ cellar: Cellar, _ number: Int) throws -> Wine {
        let fresh = ModelContext(cellar.context.container)
        return try #require(try fresh.fetch(FetchDescriptor<Wine>(predicate: #Predicate { $0.number == number })).first)
    }

    @Test func markDrunkUndoesAndRedoesAndPersists() throws {
        let cellar = try makeCellar(undo: true)
        let wine = try addWine(cellar, number: 1, producer: "Diel", inStock: 2)
        try cellar.markFirstBottleDrunk(of: wine)
        #expect(cellar.undoManager?.undoActionName == "Mark as Drunk")
        cellar.undoManager?.undo()
        #expect(wine.inStockCount == 2)
        #expect(try refetch(cellar, 1).inStockCount == 2)
        cellar.undoManager?.redo()
        #expect(try refetch(cellar, 1).inStockCount == 1)
    }

    @Test func removeBottleComesBack() throws {
        let cellar = try makeCellar(undo: true)
        let wine = try addWine(cellar, number: 1, producer: "Diel", price: 12)
        let bottle = try #require(wine.inStockBottles.first)
        let id = bottle.id
        try cellar.removeBottle(bottle)
        #expect(wine.allBottles.isEmpty)
        cellar.undoManager?.undo()
        let restored = try #require(try refetch(cellar, 1).allBottles.first)
        #expect(restored.id == id && restored.price == 12)
    }

    @Test func editAndRatingUndo() throws {
        let cellar = try makeCellar(undo: true)
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        let signature = wine.signature
        try cellar.edit(.producer, to: "Schlossgut Diel", on: wine)
        try cellar.setRating(5, on: wine)
        cellar.undoManager?.undo()
        #expect(wine.rating == nil)
        cellar.undoManager?.undo()
        #expect(wine.producer == "Diel" && wine.signature == signature)
        #expect(wine.dataSources["producer"] == nil)
    }

    @Test func userNotesUndo() throws {
        let cellar = try makeCellar(undo: true)
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        try cellar.edit(.userNotes, to: "Passt zu Spargel", on: wine)
        #expect(wine.userNotes == "Passt zu Spargel")
        #expect(wine.dataSources["user_notes"] == .user)
        #expect(cellar.undoManager?.undoActionName == "Edit Notes")
        cellar.undoManager?.undo()
        #expect(wine.userNotes == nil)
        try cellar.edit(.userNotes, to: "", on: wine)
        #expect(wine.userNotes == nil)
    }

    /// An import between an action and its undo keeps its bottles.
    @Test func undoKeepsLaterImports() throws {
        let cellar = try makeCellar(undo: true)
        let wine = try addWine(cellar, number: 1, producer: "Diel")
        try cellar.addBottle(to: wine)
        let imported = Bottle(wine: wine)
        cellar.context.insert(imported)
        try cellar.context.save()
        cellar.undoManager?.undo()
        #expect(try refetch(cellar, 1).allBottles.count == 2)
    }
}
