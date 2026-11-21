import Foundation

/// The four sidebar lists.
public enum CellarList: String, CaseIterable, Codable, Sendable {
    case inStock, readyToDrink, drunk, all

    public var title: String {
        switch self {
        case .inStock: String(localized: "In Stock")
        case .readyToDrink: String(localized: "Ready to Drink")
        case .drunk: String(localized: "Drunk")
        case .all: String(localized: "All Wines")
        }
    }

    @MainActor
    public func contains(_ wine: Wine, year: Int) -> Bool {
        switch self {
        case .inStock: wine.inStockCount > 0
        case .readyToDrink: wine.inStockCount > 0 && wine.isReady(in: year)
        case .drunk: wine.allBottles.contains { $0.status == .consumed }
        case .all: true
        }
    }
}

/// The eight filter pop-ups.
public enum FilterFacet: String, CaseIterable, Codable, Sendable {
    case color, wineType, grape, country, region, producer, price, rating

    public var title: String {
        switch self {
        case .color: String(localized: "Colour")
        case .wineType: String(localized: "Type")
        case .grape: String(localized: "Grape")
        case .country: String(localized: "Country")
        case .region: String(localized: "Region")
        case .producer: String(localized: "Winery")
        case .price: String(localized: "Price")
        case .rating: String(localized: "Rating")
        }
    }
}

/// The selected value per facet. Colour and type hold raw values, price the
/// lower end of a 10-euro step, rating the stars.
public struct CellarFilters: Codable, Equatable, Sendable {
    public var values: [FilterFacet: String] = [:]

    public init(values: [FilterFacet: String] = [:]) {
        self.values = values
    }

    public var isEmpty: Bool { values.isEmpty }

    public subscript(facet: FilterFacet) -> String? {
        get { values[facet] }
        set { values[facet] = newValue }
    }
}

public enum SortField: String, CaseIterable, Codable, Sendable {
    case winery, vintage, price, rating, drinkingWindow, dateAdded

    public var title: String {
        switch self {
        case .winery: String(localized: "Winery")
        case .vintage: String(localized: "Vintage")
        case .price: String(localized: "Price")
        case .rating: String(localized: "Rating")
        case .drinkingWindow: String(localized: "Drinking Window")
        case .dateAdded: String(localized: "Date Added")
        }
    }

    /// The names of the two directions, ascending first.
    public var directions: (ascending: String, descending: String) {
        switch self {
        case .winery: (String(localized: "A to Z"), String(localized: "Z to A"))
        case .vintage, .dateAdded: (String(localized: "Oldest first"), String(localized: "Newest first"))
        case .price, .rating: (String(localized: "Lowest first"), String(localized: "Highest first"))
        case .drinkingWindow: (String(localized: "Soonest first"), String(localized: "Latest first"))
        }
    }
}

public struct CellarSort: Codable, Equatable, Sendable {
    public var field: SortField
    public var ascending: Bool

    public init(field: SortField = .winery, ascending: Bool = true) {
        self.field = field
        self.ascending = ascending
    }
}

/// One option of a filter pop-up: the stored value and what it shows.
public struct FacetOption: Hashable, Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

/// The wines the list shows, and the options each filter still offers. Runs
/// in memory over the fetched wines: German collation, folding and "a
/// grape matches by its label name too" are beyond `#Predicate`.
@MainActor
public struct CellarQuery {
    public var list: CellarList
    public var filters: CellarFilters
    public var search: String
    public var sort: CellarSort
    public var year: Int

    public init(list: CellarList, filters: CellarFilters = CellarFilters(), search: String = "", sort: CellarSort = CellarSort(), year: Int) {
        self.list = list
        self.filters = filters
        self.search = search
        self.sort = sort
        self.year = year
    }

    /// The list's wines, before filters and search.
    public func listWines(_ wines: [Wine]) -> [Wine] {
        wines.filter { list.contains($0, year: year) }
    }

    /// The wines to show, sorted.
    public func results(_ wines: [Wine]) -> [Wine] {
        sorted(listWines(wines).filter { matches($0, except: nil) })
    }

    /// The values a facet still offers: every other filter, the list and the
    /// search apply, this facet's own selection does not.
    public func options(for facet: FilterFacet, in wines: [Wine]) -> [FacetOption] {
        let candidates = listWines(wines).filter { matches($0, except: facet) }
        var values = Set<String>()
        for wine in candidates { values.formUnion(Self.values(of: wine, for: facet)) }
        switch facet {
        case .color:
            return WineColor.allCases.filter { values.contains($0.rawValue) }.map { FacetOption(value: $0.rawValue, label: $0.label) }
        case .wineType:
            return WineType.allCases.filter { values.contains($0.rawValue) }.map { FacetOption(value: $0.rawValue, label: $0.label) }
        case .price:
            return values.compactMap(Int.init).sorted().map { FacetOption(value: String($0), label: "\($0)–\($0 + 10) €") }
        case .rating:
            return values.compactMap(Int.init).sorted(by: >).map {
                FacetOption(value: String($0), label: String(repeating: "★", count: $0) + String(repeating: "☆", count: 5 - $0))
            }
        default:
            return values.sorted { TextFolding.compare($0, $1) == .orderedAscending }.map { FacetOption(value: $0, label: $0) }
        }
    }

    func matches(_ wine: Wine, except excluded: FilterFacet?) -> Bool {
        for (facet, value) in filters.values where facet != excluded {
            guard Self.values(of: wine, for: facet).contains(value) else { return false }
        }
        return matchesSearch(wine)
    }

    static func values(of wine: Wine, for facet: FilterFacet) -> Set<String> {
        switch facet {
        case .color: Set([wine.colorRaw].compactMap { $0 })
        case .wineType: Set([wine.wineTypeRaw].compactMap { $0 })
        case .grape: Set(wine.canonicalGrapeNames)
        case .country: Set([wine.country].compactMap { $0 })
        case .region: Set([wine.region].compactMap { $0 })
        case .producer: Set([wine.producer])
        case .price: Set([wine.price.map { String(Int(($0 / 10).rounded(.down)) * 10) }].compactMap { $0 })
        case .rating: Set([wine.rating.map(String.init)].compactMap { $0 })
        }
    }

    // MARK: Search

    func matchesSearch(_ wine: Wine) -> Bool {
        let words = TextFolding.fold(search).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = TextFolding.fold(searchText(wine))
        return words.allSatisfy { haystack.contains($0) }
    }

    private func searchText(_ wine: Wine) -> String {
        var parts: [String?] = [
            wine.producer, wine.name, wine.vintage.map(String.init), wine.appellation, wine.region,
            wine.country, wine.vineyard, wine.qualityLevel, wine.foodPairing,
        ]
        for grape in wine.orderedGrapes {
            parts.append(grape.grape?.name)
            parts.append(grape.labelName)
        }
        return parts.compactMap { $0 }.joined(separator: " ")
    }

    // MARK: Sorting

    /// The chosen field in its direction; missing values last either way; ties
    /// by winery, name, vintage.
    public func sorted(_ wines: [Wine]) -> [Wine] {
        wines.sorted { a, b in
            switch compareField(a, b) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return Self.tieBreak(a, b) == .orderedAscending
            }
        }
    }

    private func compareField(_ a: Wine, _ b: Wine) -> ComparisonResult {
        switch sort.field {
        case .winery:
            let result = TextFolding.compare(a.producer, b.producer)
            return sort.ascending ? result : result.reversed
        case .vintage: return compare(a.vintage.map(Double.init), b.vintage.map(Double.init))
        case .price: return compare(a.price, b.price)
        case .rating: return compare(a.rating.map(Double.init), b.rating.map(Double.init))
        case .drinkingWindow: return compare(a.drinkFrom.map(Double.init), b.drinkFrom.map(Double.init))
        case .dateAdded: return compare(a.createdAt.timeIntervalSinceReferenceDate, b.createdAt.timeIntervalSinceReferenceDate)
        }
    }

    private func compare(_ a: Double?, _ b: Double?) -> ComparisonResult {
        switch (a, b) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (a?, b?):
            if a == b { return .orderedSame }
            return (a < b) == sort.ascending ? .orderedAscending : .orderedDescending
        }
    }

    static func tieBreak(_ a: Wine, _ b: Wine) -> ComparisonResult {
        let producer = TextFolding.compare(a.producer, b.producer)
        if producer != .orderedSame { return producer }
        let name = TextFolding.compare(a.name ?? "", b.name ?? "")
        if name != .orderedSame { return name }
        switch ((a.vintage ?? 0), (b.vintage ?? 0)) {
        case let (x, y) where x < y: return .orderedAscending
        case let (x, y) where x > y: return .orderedDescending
        default: return a.number < b.number ? .orderedAscending : .orderedDescending
        }
    }

    // MARK: Counts

    public static func bottleCount(_ wines: [Wine]) -> Int {
        wines.reduce(0) { $0 + $1.inStockCount }
    }
}

extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}
