import SwiftData
import SwiftUI
import SchwipsCore

/// The main window: sidebar (lists and filters), wine list, detail.
struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Query private var wines: [Wine]
    @State private var model = WindowModel()
    @FocusState private var searchFocused: Bool

    private var cellar: Cellar { Cellar(context: modelContext, undoManager: undoManager) }

    private var query: CellarQuery {
        CellarQuery(list: model.list, filters: model.filters, search: model.search, sort: model.sort, year: Day.currentYear())
    }

    var body: some View {
        let query = query
        let listWines = query.listWines(wines)
        let results = query.results(wines)
        let selected = results.first { $0.number == model.selectedNumber }
            ?? wines.first { $0.number == model.selectedNumber && model.list == .all }

        NavigationSplitView {
            Sidebar(model: model, wines: wines, query: query)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 320)
        } content: {
            WineList(model: model, results: results, isCellarEmpty: wines.isEmpty, listIsEmpty: listWines.isEmpty)
                .navigationSplitViewColumnWidth(min: 320, ideal: 372, max: 520)
        } detail: {
            if let selected {
                WineDetail(wine: selected, model: model, cellar: cellar)
                    .id(selected.number)
            } else {
                Text("No wine selected")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(model.list.title)
        #if os(macOS)
        .navigationSubtitle(Self.counts(shown: results, total: listWines, filtered: !model.filters.isEmpty || !model.search.isEmpty))
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SortMenu(sort: Binding(get: { model.sort }, set: { model.sort = $0 }))
            }
        }
        .searchable(text: Binding(get: { model.search }, set: { model.search = $0 }), placement: .toolbar, prompt: Text("Search"))
        .searchFocused($searchFocused)
        .onChange(of: model.isSearchFocused) { _, now in
            if now {
                searchFocused = true
                model.isSearchFocused = false
            }
        }
        .onChange(of: app.requestedWine) { _, number in
            guard let number else { return }
            model.reveal(number)
            app.requestedWine = nil
        }
        .onOpenURL { app.open($0) }
        .alert(
            Text("Wine \(String(app.unknownWineNumber ?? 0)) isn’t in your cellar."),
            isPresented: Binding(get: { app.unknownWineNumber != nil }, set: { if !$0 { app.unknownWineNumber = nil } })
        ) {
            Button("OK") { app.unknownWineNumber = nil }
        }
        .sheet(isPresented: Binding(get: { app.showsWelcome }, set: { app.showsWelcome = $0 })) {
            WelcomeSheet()
        }
        .focusedSceneValue(\.windowModel, model)
        .focusedSceneValue(\.selectedWine, selected)
        .frame(minWidth: 960, minHeight: 600)
    }

    /// "36 wines · 58 bottles", or "9 of 36 wines · 11 of 58 bottles" while
    /// filtering. Bottles are the ones in stock.
    static func counts(shown: [Wine], total: [Wine], filtered: Bool) -> String {
        let shownBottles = CellarQuery.bottleCount(shown)
        let totalBottles = CellarQuery.bottleCount(total)
        if filtered {
            let wines = String(localized: "\(shown.count) of \(total.count) wines")
            let bottles = String(localized: "\(shownBottles) of \(totalBottles) bottles")
            return "\(wines) · \(bottles)"
        }
        if total.isEmpty { return String(localized: "No wines") }
        return "\(String(localized: "\(total.count) wines")) · \(WineText.bottles(totalBottles))"
    }
}

/// "Sort: Winery" with the fields and the two directions of the chosen one.
struct SortMenu: View {
    @Binding var sort: CellarSort

    var body: some View {
        Menu {
            Picker("Sort by", selection: Binding(get: { sort.field }, set: { sort = CellarSort(field: $0, ascending: true) })) {
                ForEach(SortField.allCases, id: \.self) { field in
                    Text(verbatim: field.title).tag(field)
                }
            }
            .pickerStyle(.inline)
            Picker("Order", selection: Binding(get: { sort.ascending }, set: { sort.ascending = $0 })) {
                Text(verbatim: sort.field.directions.ascending).tag(true)
                Text(verbatim: sort.field.directions.descending).tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            Label {
                Text("Sort: \(sort.field.title)")
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .labelStyle(.titleAndIcon)
        }
        .help(Text("Sort"))
    }
}
