import SwiftUI
import SchwipsCore

/// The middle column: the import banner, the wines, or an empty state.
struct WineList: View {
    @Bindable var model: WindowModel
    let results: [Wine]
    let isCellarEmpty: Bool
    let listIsEmpty: Bool
    @Environment(AppState.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if isCellarEmpty {
                EmptyCellarView()
            } else if listIsEmpty {
                ContentUnavailableView("No wines in this list", systemImage: "wineglass")
            } else if results.isEmpty {
                NoMatchesView(model: model)
            } else {
                List(selection: Binding(get: { model.selectedNumber }, set: { model.selectedNumber = $0 })) {
                    ForEach(results, id: \.number) { wine in
                        WineRow(wine: wine, isNew: app.newWineNumbers.contains(wine.number))
                            .tag(wine.number)
                    }
                }
                .listStyle(.inset)
                .onKeyPress(.space) {
                    guard let number = model.selectedNumber,
                          results.first(where: { $0.number == number })?.photos?.isEmpty == false else { return .ignored }
                    openWindow(id: PhotoTarget.windowID, value: PhotoTarget(wineNumber: number, index: 0))
                    return .handled
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let banner = app.banner {
                ImportBannerView(banner: banner, model: model)
                    .padding(8)
            }
        }
    }
}

/// One wine: winery and name, price; type · grapes · vintage; origin and tier;
/// chips, stars and bottles in stock.
struct WineRow: View {
    let wine: Wine
    let isNew: Bool
    @Environment(\.locale) private var locale
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let selected = prominence == .increased
        let formatting = CellarFormatting(locale: locale)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(selected ? Color.white.opacity(0.25) : Theme.accent))
                        .foregroundStyle(.white)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: wine.producer)
                    if let name = wine.name {
                        Text(verbatim: name).font(.system(.body, design: .serif))
                    }
                }
                .fontWeight(.semibold)
                .lineLimit(1)
                Spacer(minLength: 4)
                if let price = wine.price {
                    Text(verbatim: formatting.price(price))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 0) {
                if let type = wine.wineType {
                    Text(verbatim: type.label.uppercased())
                        .font(.caption.weight(.semibold))
                        .kerning(0.4)
                        .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.typeLabel))
                    Text(verbatim: " · ").foregroundStyle(.secondary)
                }
                Text(verbatim: WineText.grapesAndVintage(wine))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.callout)
            let origin = WineText.originLine(wine)
            if !origin.isEmpty {
                Text(verbatim: origin)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                if let color = wine.color {
                    Chip(text: color.label, colors: Theme.chip(color), inverted: selected)
                }
                if wine.inStockCount > 0 {
                    ReadinessChip(wine: wine, inverted: selected)
                } else {
                    Chip(text: String(localized: "Not in stock"), colors: Theme.neutral, inverted: selected)
                }
                if let rating = wine.rating {
                    Text(verbatim: String(repeating: "★", count: rating))
                        .font(.caption)
                        .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(Theme.star))
                        .accessibilityLabel(Text("Rated \(rating) of 5"))
                }
                Spacer()
                Text(verbatim: WineText.bottles(wine.inStockCount))
                    .font(.callout)
                    .monospacedDigit()
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
