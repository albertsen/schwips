import SwiftUI
import SchwipsCore

/// "Bottles · 2 in stock", every bottle with its size, location and status,
/// Mark as Drunk…, Remove…, the drunk date, and + Add Bottle.
struct BottleSection: View {
    let wine: Wine
    let cellar: Cellar
    let model: WindowModel
    let formatting: CellarFormatting
    @State private var drinking: Bottle?
    @State private var removing: Bottle?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Group {
                    if wine.inStockCount == 0 {
                        Text("Bottles · none in stock")
                    } else {
                        Text("Bottles · \(wine.inStockCount) in stock")
                    }
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                Spacer()
                Button("+ Add Bottle") { perform { try cellar.addBottle(to: wine) } }
                    .controlSize(.small)
            }
            let bottles = wine.inStockBottles + wine.drunkBottles + wine.allBottles.filter { $0.status == .gifted }
            if !bottles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(bottles.enumerated()), id: \.element.id) { index, bottle in
                        if index > 0 { Divider() }
                        row(bottle)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            }
        }
        .onChange(of: model.markDrunkRequest) {
            drinking = wine.inStockBottles.first
        }
        .alert(
            Text("Remove this bottle?"),
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            presenting: removing
        ) { bottle in
            Button("Remove Bottle", role: .destructive) { perform { try cellar.removeBottle(bottle) } }
            Button("Cancel", role: .cancel) {}
        } message: { bottle in
            Text("\(WineText.fullName(wine)), \(bottle.sizeML) ml. Remove a bottle that was added by mistake. To record a bottle you opened, use Mark as Drunk.")
        }
        .alert(Text(verbatim: errorMessage ?? ""), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        }
    }

    @ViewBuilder
    private func row(_ bottle: Bottle) -> some View {
        let drunk = bottle.status != .inStock
        HStack(spacing: 10) {
            Text(verbatim: "\(bottle.sizeML) ml")
                .frame(width: 60, alignment: .leading)
            InlineTextField(
                value: bottle.location ?? "", display: bottle.location ?? String(localized: "No location"),
                help: String(localized: "Double-click to edit"), accessibilityName: String(localized: "Location")
            ) { text in
                do {
                    try cellar.setLocation(text, of: bottle)
                    return nil
                } catch {
                    return error.message
                }
            }
            .foregroundStyle(bottle.location == nil ? .secondary : .primary)
            .frame(width: 120, alignment: .leading)
            switch bottle.status {
            case .inStock:
                Text("In stock")
                Spacer()
                Button("Mark as Drunk…") { drinking = bottle }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .popover(isPresented: Binding(get: { drinking?.id == bottle.id }, set: { if !$0 { drinking = nil } }), arrowEdge: .bottom) {
                        MarkDrunkPopover(bottle: bottle) { day in
                            drinking = nil
                            perform { try cellar.markDrunk(bottle, on: day) }
                        } cancel: {
                            drinking = nil
                        }
                    }
                Button("Remove…") { removing = bottle }
            case .consumed:
                Text("Drunk on").foregroundStyle(.secondary)
                DatePicker(
                    "Drunk on",
                    selection: Binding(
                        get: { bottle.drunkOn ?? .now },
                        set: { day in perform { try cellar.setDrunkDate(day, of: bottle) } }
                    ),
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .labelsHidden()
                .fieldDatePickerStyle()
                .fixedSize()
                Spacer()
            case .gifted:
                Text("Given away").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .font(.callout)
        .foregroundStyle(drunk ? .secondary : .primary)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.message }
    }
}

/// "Mark as Drunk": the day, today by default, never in the future.
private struct MarkDrunkPopover: View {
    let bottle: Bottle
    let confirm: (Date) -> Void
    let cancel: () -> Void
    @State private var day = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mark as Drunk").font(.headline)
            DatePicker("Drunk on", selection: $day, in: ...Date.now, displayedComponents: .date)
                .fieldDatePickerStyle()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Mark as Drunk") { confirm(day) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

/// The wine's photos as thumbnails, primary first.
struct PhotoStrip: View {
    let wine: Wine
    let open: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(wine.orderedPhotos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        open(index)
                    } label: {
                        StoredImage(data: photo.thumbnailData)
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                    }
                    .buttonStyle(.plain)
                    .help(Text(verbatim: photo.fileName))
                    .accessibilityLabel(Text("Open photo \(photo.fileName)"))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
