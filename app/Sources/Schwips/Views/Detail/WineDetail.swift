import SwiftUI
import SchwipsCore

/// The selected wine: header with stars and chips, the facts, the
/// description, links, photos, bottles and the history.
struct WineDetail: View {
    let wine: Wine
    let model: WindowModel
    let cellar: Cellar
    @Environment(\.locale) private var locale
    @Environment(\.openWindow) private var openWindow
    @State private var errorMessage: String?

    var body: some View {
        let formatting = CellarFormatting(locale: locale)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                FactsGrid(wine: wine, cellar: cellar, formatting: formatting)
                if let notes = wine.notes {
                    InlineTextField(
                        value: notes, font: .body, multiline: true,
                        help: WineText.provenance(wine.dataSources[WineField.notes.rawValue]),
                        accessibilityName: WineField.notes.title
                    ) { commit(.notes, $0) }
                    .lineSpacing(2)
                }
                NotesSection(wine: wine) { commit(.userNotes, $0) }
                if !wine.externalLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(wine.externalLinks, id: \.self) { link in
                            if let url = URL(string: link) {
                                Link(destination: url) { Text(verbatim: link).lineLimit(1).truncationMode(.middle) }
                                    .font(.caption)
                            }
                        }
                    }
                }
                if !(wine.photos ?? []).isEmpty {
                    PhotoStrip(wine: wine) { index in
                        openWindow(id: PhotoTarget.windowID, value: PhotoTarget(wineNumber: wine.number, index: index))
                    }
                }
                BottleSection(wine: wine, cellar: cellar, model: model, formatting: formatting)
                history(formatting)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: model.showPhotosRequest) {
            if !(wine.photos ?? []).isEmpty {
                openWindow(id: PhotoTarget.windowID, value: PhotoTarget(wineNumber: wine.number, index: 0))
            }
        }
        .alert(Text(verbatim: errorMessage ?? ""), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            InlineTextField(
                value: wine.producer, font: .callout.weight(.semibold),
                help: WineText.provenance(wine.dataSources[WineField.producer.rawValue]),
                accessibilityName: WineField.producer.title
            ) { commit(.producer, $0) }
            .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                InlineTextField(
                    value: wine.name ?? "", display: wine.name ?? wine.appellation ?? wine.vineyard ?? String(localized: "No name"),
                    font: .system(size: 28, weight: .semibold, design: .serif),
                    help: WineText.provenance(wine.dataSources[WineField.name.rawValue]),
                    accessibilityName: WineField.name.title
                ) { commit(.name, $0) }
                InlineTextField(
                    value: wine.vintage.map(String.init) ?? "", display: WineText.vintage(wine),
                    font: .system(size: 28, weight: .medium, design: .serif),
                    help: WineText.provenance(wine.dataSources[WineField.vintage.rawValue]),
                    accessibilityName: WineField.vintage.title
                ) { commit(.vintage, $0) }
                .foregroundStyle(.secondary)
            }
            let line = WineText.detailLine(wine)
            if !line.isEmpty {
                Text(verbatim: line).font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                StarRating(rating: wine.rating) { rating in
                    perform { try cellar.setRating(rating, on: wine) }
                }
                if let color = wine.color {
                    Chip(text: color.label, colors: Theme.chip(color))
                }
                if wine.inStockCount > 0 {
                    ReadinessChip(wine: wine)
                } else {
                    Chip(text: String(localized: "Not in stock"), colors: Theme.neutral)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func history(_ formatting: CellarFormatting) -> some View {
        let drunk = wine.drunkBottles.filter { $0.drunkOn != nil }
        if !drunk.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("History").font(.headline).foregroundStyle(.secondary)
                ForEach(drunk, id: \.id) { bottle in
                    let day = formatting.day(bottle.drunkOn!)
                    if let location = bottle.location {
                        Text("Drunk on \(day) · \(location)").font(.callout)
                    } else {
                        Text("Drunk on \(day)").font(.callout)
                    }
                }
            }
        }
    }

    private func commit(_ field: WineField, _ text: String) -> String? {
        do {
            try cellar.edit(field, to: text, on: wine)
            return nil
        } catch {
            return error.message
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.message }
    }
}

/// "Notes": the user's own notes, edited in place; Add Note… while empty.
private struct NotesSection: View {
    let wine: Wine
    let commit: (String) -> String?
    @State private var editRequest = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes").font(.headline).foregroundStyle(.secondary)
                Spacer()
                if wine.userNotes == nil {
                    Button("Add Note…") { editRequest += 1 }
                        .controlSize(.small)
                }
            }
            InlineTextField(
                value: wine.userNotes ?? "", font: .body, multiline: true,
                help: String(localized: "Double-click to edit"), accessibilityName: WineField.userNotes.title,
                editRequest: editRequest, commit: commit
            )
            .lineSpacing(2)
        }
    }
}

/// Five stars. Clicking a star sets it; clicking the current one clears it.
struct StarRating: View {
    let rating: Int?
    let set: (Int?) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    set(rating == star ? nil : star)
                } label: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(star <= (rating ?? 0) ? Theme.star : Theme.starEmpty)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(star) stars"))
            }
        }
        .font(.system(size: 15))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rating.map { Text("Rated \($0) of 5") } ?? Text("Not rated"))
    }
}

/// The facts in two columns, each only when it has a value.
private struct FactsGrid: View {
    let wine: Wine
    let cellar: Cellar
    let formatting: CellarFormatting

    private struct Fact: Identifiable {
        let id: String
        let label: String
        let content: AnyView
    }

    var body: some View {
        let shown = facts()
        let half = (shown.count + 1) / 2
        HStack(alignment: .top, spacing: 28) {
            column(Array(shown.prefix(half)))
            column(Array(shown.dropFirst(half)))
        }
    }

    private func column(_ facts: [Fact]) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(facts) { fact in
                GridRow {
                    Text(verbatim: fact.label)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.leading)
                    fact.content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func help(_ field: WineField) -> String {
        WineText.provenance(wine.dataSources[field.rawValue])
    }

    private func text(_ field: WineField, _ value: String?, display: String? = nil) -> Fact? {
        guard let value else { return nil }
        return Fact(id: field.rawValue, label: field.title, content: AnyView(
            InlineTextField(value: value, display: display, help: help(field), accessibilityName: field.title) { text in
                do {
                    try cellar.edit(field, to: text, on: wine)
                    return nil
                } catch {
                    return error.message
                }
            }
        ))
    }

    private func choice(_ field: WineField, current: String?, display: String?, options: [InlineChoice.Option], allowsNone: Bool) -> Fact? {
        guard let display else { return nil }
        return Fact(id: field.rawValue, label: field.title, content: AnyView(
            InlineChoice(current: current, display: display, options: options, allowsNone: allowsNone,
                         help: help(field), accessibilityName: field.title) { raw in
                try? cellar.choose(field, rawValue: raw, on: wine)
            }
        ))
    }

    private func plain(_ id: String, _ label: String, _ value: String?) -> Fact? {
        guard let value else { return nil }
        return Fact(id: id, label: label, content: AnyView(Text(verbatim: value).font(.callout)))
    }

    private func facts() -> [Fact] {
        let all: [Fact?] = [
            choice(.wineType, current: wine.wineTypeRaw, display: wine.wineType?.label,
                   options: WineType.allCases.map { .init(raw: $0.rawValue, label: $0.label) }, allowsNone: false),
            choice(.color, current: wine.colorRaw, display: wine.color?.label,
                   options: WineColor.allCases.map { .init(raw: $0.rawValue, label: $0.label) }, allowsNone: false),
            choice(.sweetness, current: wine.sweetnessRaw, display: wine.sweetness?.label,
                   options: Sweetness.allCases.map { .init(raw: $0.rawValue, label: $0.label) }, allowsNone: true),
            text(.qualityLevel, wine.qualityLevel),
            plain("grapes", String(localized: "Grapes"), grapes),
            text(.appellation, wine.appellation),
            text(.region, wine.region),
            text(.country, wine.country),
            text(.vineyard, wine.vineyard),
            text(.abv, wine.abv.map(formatting.decimal), display: wine.abv.map(formatting.percent)),
            text(.price, wine.price.map(formatting.decimal), display: wine.price.map(formatting.price)),
            plain("residual_sugar_gl", String(localized: "Residual sugar"), wine.residualSugar.map { "\(formatting.decimal($0)) g/l" }),
            plain("acidity_gl", String(localized: "Acidity"), wine.acidity.map { "\(formatting.decimal($0)) g/l" }),
            text(.drinkingWindow, formatting.range(from: wine.drinkFrom, until: wine.drinkUntil)),
            text(.servingTemp, wine.servingTemp, display: wine.servingTemp.map(formatting.servingTemp)),
            choice(.closure, current: wine.closureRaw, display: wine.closure?.label,
                   options: Closure.allCases.map { .init(raw: $0.rawValue, label: $0.label) }, allowsNone: true),
            text(.foodPairing, wine.foodPairing),
            plain("is_organic", String(localized: "Organic"), wine.isOrganic == true ? "✓" : nil),
            plain("is_vegan", String(localized: "Vegan"), wine.isVegan == true ? "✓" : nil),
        ]
        return all.compactMap { $0 }
    }

    /// "Merlot 60 %, Cabernet Sauvignon 40 %".
    private var grapes: String? {
        let names = wine.orderedGrapes.compactMap { grape -> String? in
            guard let name = grape.labelName ?? grape.grape?.name else { return nil }
            return grape.percentage.map { "\(name) \(formatting.decimal($0)) %" } ?? name
        }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}
