import SwiftUI
import SchwipsCore

/// The main window's selection and view state, shared with the menus.
@MainActor
@Observable
final class WindowModel {
    var list: CellarList {
        didSet { UserDefaults.standard.set(list.rawValue, forKey: Keys.list) }
    }
    var filters: CellarFilters {
        didSet { Self.store(filters, Keys.filters) }
    }
    var sort: CellarSort {
        didSet { Self.store(sort, Keys.sort) }
    }
    var selectedNumber: Int? {
        didSet { UserDefaults.standard.set(selectedNumber ?? 0, forKey: Keys.selected) }
    }
    var search = ""
    var isSearchFocused = false

    /// Set by the detail so the Wine menu acts on the shown wine.
    var markDrunkRequest = 0
    var showPhotosRequest = 0

    private enum Keys {
        static let list = "list"
        static let filters = "filters"
        static let sort = "sort"
        static let selected = "selectedWine"
    }

    init() {
        let defaults = UserDefaults.standard
        list = defaults.string(forKey: Keys.list).flatMap(CellarList.init(rawValue:)) ?? .inStock
        filters = Self.load(Keys.filters) ?? CellarFilters()
        sort = Self.load(Keys.sort) ?? CellarSort()
        let selected = defaults.integer(forKey: Keys.selected)
        selectedNumber = selected == 0 ? nil : selected
    }

    func resetFiltersAndSearch() {
        filters = CellarFilters()
        search = ""
    }

    /// From a link or Show New Wines: All Wines, nothing filtered, the wine selected.
    func reveal(_ number: Int) {
        list = .all
        resetFiltersAndSearch()
        selectedNumber = number
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func store<T: Encodable>(_ value: T, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

extension FocusedValues {
    @Entry var windowModel: WindowModel?
    /// The selected wine, for the Wine menu.
    @Entry var selectedWine: Wine?
}
