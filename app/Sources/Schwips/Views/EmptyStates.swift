import SwiftUI
import SchwipsCore

/// No wines at all: how bottles arrive.
struct EmptyCellarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Your cellar is empty").font(.system(.title2, design: .serif)).fontWeight(.semibold)
            } icon: {
                Image(systemName: "wineglass").foregroundStyle(Theme.accent)
            }
        } description: {
            Text("Put label photos in incoming/ and run /import-wines in Claude Code. New bottles appear here by themselves.")
        } actions: {
            if let incoming = app.folder.incoming {
                Button("Show Incoming Folder") { openURL(incoming) }
            } else {
                Button("Choose Folder…") { app.showsWelcome = true }
            }
        }
    }
}

/// Nothing matches the search or filters.
struct NoMatchesView: View {
    let model: WindowModel

    var body: some View {
        ContentUnavailableView {
            if model.search.isEmpty {
                Text("No wines match these filters")
            } else {
                Text("No wines match “\(model.search)”")
            }
        } description: {
            if !model.filters.isEmpty {
                Text("with the filters \(Self.filterList(model.filters)).")
            }
        } actions: {
            Button("Reset Filters and Search") { model.resetFiltersAndSearch() }
        }
    }

    /// "Colour: Red, Winery: Diel" in the sidebar's order.
    @MainActor
    static func filterList(_ filters: CellarFilters) -> String {
        FilterFacet.allCases.compactMap { facet in
            guard let value = filters[facet] else { return nil }
            let shown: String = switch facet {
            case .color: WineColor(rawValue: value)?.label ?? value
            case .wineType: WineType(rawValue: value)?.label ?? value
            case .price: "\(value)–\((Int(value) ?? 0) + 10) €"
            case .rating: String(repeating: "★", count: Int(value) ?? 0)
            default: value
            }
            return "\(facet.title): \(shown)"
        }
        .joined(separator: ", ")
    }
}
