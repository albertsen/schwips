import SwiftData
import SwiftUI
import SchwipsCore

/// The four lists with their counts, the eight filters, and the import line.
struct Sidebar: View {
    @Bindable var model: WindowModel
    let wines: [Wine]
    let query: CellarQuery
    @Environment(AppState.self) private var app

    var body: some View {
        List(selection: Binding(get: { model.list }, set: { if let list = $0 { model.list = list } })) {
            Section("Cellar") {
                ForEach(CellarList.allCases, id: \.self) { list in
                    let count = CellarQuery(list: list, year: query.year).listWines(wines).count
                    Label {
                        HStack {
                            Text(verbatim: list.title)
                            Spacer()
                            Text(verbatim: String(count)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: Self.icon(list))
                    }
                    .tag(list)
                }
            }
            Section {
                if wines.isEmpty {
                    Text("Filters appear once there are wines.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(FilterFacet.allCases, id: \.self) { facet in
                        FilterPicker(facet: facet, model: model, options: query.options(for: facet, in: wines))
                    }
                }
            } header: {
                HStack {
                    Text("Filters")
                    Spacer()
                    if !model.filters.isEmpty {
                        Button("Reset") { model.filters = CellarFilters() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .font(.caption)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            ImportStatusLine()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func icon(_ list: CellarList) -> String {
        switch list {
        case .inStock: "wineglass"
        case .readyToDrink: "checkmark.seal"
        case .drunk: "clock.arrow.circlepath"
        case .all: "square.grid.3x3"
        }
    }
}

/// One filter: its title in a fixed column and a pop-up that takes the rest
/// of the width, so every pop-up has the same width. "All" and the values
/// that still give results; a set filter is drawn in the accent colour.
private struct FilterPicker: View {
    let facet: FilterFacet
    @Bindable var model: WindowModel
    let options: [FacetOption]

    var body: some View {
        let selection = model.filters[facet]
        // A selected value stays offered even if nothing else matches it.
        let all = options.contains { $0.value == selection } || selection == nil
            ? options : options + [FacetOption(value: selection!, label: selection!)]
        HStack(spacing: 8) {
            Text(verbatim: facet.title)
                .foregroundStyle(selection == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.accent))
                .frame(width: 78, alignment: .leading)
            // A Menu with its own label: a menu-style Picker keeps the width of
            // its widest value, whatever frame it gets.
            Menu {
                Picker(selection: Binding(get: { selection ?? "" }, set: { model.filters[facet] = $0.isEmpty ? nil : $0 })) {
                    Text("All").tag("")
                    Divider()
                    ForEach(all, id: \.value) { option in
                        Text(verbatim: option.label).tag(option.value)
                    }
                } label: {
                    Text(verbatim: facet.title)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: all.first { $0.value == selection }?.label ?? String(localized: "All"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selection == nil ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(Theme.accent.opacity(0.16)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(selection == nil ? AnyShapeStyle(.separator) : AnyShapeStyle(Theme.accent.opacity(0.5)))
                }
                .foregroundStyle(selection == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.accent))
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(verbatim: facet.title))
        }
        .fontWeight(selection == nil ? .regular : .semibold)
    }
}

/// "Last import 21 Nov, 14:02", or the missing folder in red.
private struct ImportStatusLine: View {
    @Environment(AppState.self) private var app
    @Environment(\.locale) private var locale
    @Query(filter: #Predicate<ImportRecord> { $0.statusRaw == "imported" }, sort: \ImportRecord.finishedAt, order: .reverse)
    private var imports: [ImportRecord]
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        Button {
            #if os(macOS)
            openSettings()
            #endif
        } label: {
            switch app.folder.state {
            case .missing:
                Label("Import folder not found", systemImage: "exclamationmark.circle")
                    .foregroundStyle(Theme.error)
            case .none:
                Text("No import folder chosen").foregroundStyle(.secondary)
            case .found:
                if let last = imports.first {
                    Text("Last import \(CellarFormatting(locale: locale).dayAndTime(last.finishedAt))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No imports yet").foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .font(.caption)
    }
}
