import Foundation
import Testing
@testable import SchwipsCore

@MainActor
struct CellarQueryTests {
    private func sample() throws -> (Cellar, [Wine]) {
        let cellar = try makeCellar()
        try addWine(cellar, number: 1, producer: "Diel", name: "Eierfels", vintage: 2023, price: 26, rating: 4, drink: 2026...2033,
                    grapes: [("Riesling", nil)], inStock: 2, created: Date(timeIntervalSince1970: 100))
        try addWine(cellar, number: 2, producer: "Diel", name: "Goldloch GG", vintage: 2023, price: 44, drink: 2027...2041,
                    grapes: [("Riesling", nil)], created: Date(timeIntervalSince1970: 300))
        try addWine(cellar, number: 3, producer: "Château Sérilhan", vintage: 2019, color: .red, price: 19,
                    grapes: [("Merlot", nil)], inStock: 0, drunk: 1, created: Date(timeIntervalSince1970: 200))
        try addWine(cellar, number: 4, producer: "Ägidius", color: .white, type: .sparkling,
                    grapes: [("Grauburgunder", "Pinot Grigio")], drunk: 1)
        return (cellar, try cellar.wines())
    }

    @Test func lists() throws {
        let (_, wines) = try sample()
        func numbers(_ list: CellarList) -> [Int] { CellarQuery(list: list, year: 2026).results(wines).map(\.number) }
        #expect(numbers(.inStock) == [4, 1, 2])
        #expect(numbers(.readyToDrink) == [1])
        #expect(numbers(.drunk) == [4, 3])
        #expect(numbers(.all).count == 4)
    }

    @Test func facetsIgnoreTheirOwnFilter() throws {
        let (_, wines) = try sample()
        var query = CellarQuery(list: .all, year: 2026)
        query.filters[.producer] = "Diel"
        #expect(query.results(wines).map(\.number) == [1, 2])
        #expect(query.options(for: .producer, in: wines).count == 3)
        #expect(query.options(for: .color, in: wines).map(\.value) == ["white"])
        #expect(query.options(for: .price, in: wines).map(\.value) == ["20", "40"])
    }

    @Test func searchFoldsAndFindsLabelNames() throws {
        let (_, wines) = try sample()
        var query = CellarQuery(list: .all, year: 2026)
        query.search = "serilhan"
        #expect(query.results(wines).map(\.number) == [3])
        query.search = "pinot grigio"
        #expect(query.results(wines).map(\.number) == [4])
        query.search = "grauburgunder"
        #expect(query.results(wines).map(\.number) == [4])
    }

    @Test func sortingWithMissingValuesLast() throws {
        let (_, wines) = try sample()
        var query = CellarQuery(list: .all, year: 2026)
        #expect(query.results(wines).map(\.producer) == ["Ägidius", "Château Sérilhan", "Diel", "Diel"])
        query.sort = CellarSort(field: .price, ascending: false)
        #expect(query.results(wines).map(\.number) == [2, 1, 3, 4])
        query.sort = CellarSort(field: .price, ascending: true)
        #expect(query.results(wines).map(\.number) == [3, 1, 2, 4])
        query.sort = CellarSort(field: .vintage, ascending: true)
        #expect(query.results(wines).map(\.number) == [3, 1, 2, 4])
        query.sort = CellarSort(field: .rating, ascending: true)
        #expect(query.results(wines).first?.number == 1)
        query.sort = CellarSort(field: .dateAdded, ascending: false)
        #expect(query.results(wines).map(\.number).prefix(3) == [4, 2, 3])
    }

    @Test func bottleCounts() throws {
        let (_, wines) = try sample()
        #expect(CellarQuery.bottleCount(wines) == 4)
    }
}
