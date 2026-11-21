import SwiftUI
import SchwipsCore

/// Importing, Imported, Failed, or the copy's result, above the list.
struct ImportBannerView: View {
    let banner: Banner
    let model: WindowModel
    @Environment(AppState.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    var body: some View {
        let formatting = CellarFormatting(locale: locale)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    switch banner {
                    case .importing(let date, let bottles, let photos):
                        Text("Importing review of \(formatting.dayAndTime(date))… \(WineText.bottles(bottles)), \(String(localized: "\(photos) photos"))")
                    case .imported(let info):
                        Text(verbatim: info.text)
                    case .failed(_, let date, let message):
                        Text("Couldn’t import the review of \(formatting.dayAndTime(date))").fontWeight(.semibold)
                        Text(verbatim: message)
                        Text("Nothing was imported; the photos stay in incoming/.")
                    case .copied(let outcome):
                        Text("Copied \(outcome.wines) wines, \(outcome.bottles) bottles and \(outcome.photos) photos from the web app.")
                        if outcome.missingPhotos > 0 {
                            Text("\(outcome.missingPhotos) photos were missing and were skipped.")
                        }
                    }
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !isImporting {
                    Button {
                        app.banner = nil
                    } label: {
                        Image(systemName: "xmark").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Close"))
                }
            }
            buttons
                .controlSize(.small)
                .padding(.leading, 24)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(background))
    }

    private var isImporting: Bool {
        if case .importing = banner { return true }
        return false
    }

    @ViewBuilder private var icon: some View {
        switch banner {
        case .importing: ProgressView().controlSize(.small)
        case .imported, .copied: Image(systemName: "checkmark.circle").foregroundStyle(Theme.success)
        case .failed: Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.error)
        }
    }

    @ViewBuilder private var buttons: some View {
        switch banner {
        case .imported(let info):
            HStack {
                if !info.newWineNumbers.isEmpty {
                    Button("Show New Wines") {
                        if let first = info.newWineNumbers.first { model.reveal(first) }
                    }
                }
                if let markdown = info.reviewMarkdown {
                    Button("Open Review") { openURL(markdown) }
                }
            }
        case .failed(let fileName, _, _):
            HStack {
                Button("Show in Finder") {
                    if let review = app.folder.review { openURL(review) }
                }
                Button("Try Again") { app.inbox.retry(fileName: fileName) }
            }
        default:
            EmptyView()
        }
    }

    private var background: Color {
        switch banner {
        case .importing: Color.primary.opacity(0.06)
        case .imported, .copied: Theme.ready.0
        case .failed: Color(light: 0xFBE6E4, dark: 0x4A2220)
        }
    }
}
