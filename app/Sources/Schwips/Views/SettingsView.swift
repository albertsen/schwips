import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import SchwipsCore

/// Settings › General: the Schwips folder and the last import.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Query(filter: #Predicate<ImportRecord> { $0.statusRaw == "imported" }, sort: \ImportRecord.finishedAt, order: .reverse)
    private var imports: [ImportRecord]
    @Query private var wines: [Wine]
    @State private var choosing = false
    @State private var folderError: String?

    var body: some View {
        let formatting = CellarFormatting(locale: locale)
        Form {
            LabeledContent("Schwips folder:") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label {
                            Text(verbatim: app.folder.displayPath ?? String(localized: "No folder chosen"))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } icon: {
                            Image(systemName: "folder")
                        }
                        .padding(.horizontal, 8)
                        .frame(minWidth: 260, minHeight: 24, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 5).strokeBorder(isMissing ? AnyShapeStyle(Theme.error) : AnyShapeStyle(.separator)))
                        Button("Choose…") { choosing = true }
                            .buttonStyle(.borderedProminent)
                            .tint(isMissing ? Theme.accent : .secondary)
                    }
                    if isMissing {
                        Text("This folder can’t be found. Choose it again to keep importing.")
                            .foregroundStyle(Theme.error)
                    } else if let folderError {
                        Text(verbatim: folderError).foregroundStyle(Theme.error)
                    } else {
                        Text("Schwips watches incoming/review/ in this folder and imports each new review file once, with its photos from incoming/.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = app.folder.url {
                            Button("Show in Finder") { openURL(url) }
                                .linkButtonStyle()
                        }
                    }
                }
                .font(.callout)
            }
            LabeledContent("Last import:") {
                if let last = imports.first {
                    Text("\(formatting.fullDayAndTime(last.finishedAt)) · \(WineText.bottles(last.bottleCount))")
                } else {
                    Text("None yet")
                }
            }
            if wines.isEmpty, app.folder.hasWebCellar {
                LabeledContent {
                    Button("Copy Cellar from Web App…") { app.showsWelcome = true }
                } label: {
                    EmptyView()
                }
            }
        }
        .padding(24)
        .frame(width: 580)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do {
                try app.folder.choose(url)
                folderError = nil
                app.folderChosen()
            } catch {
                folderError = error.message
            }
        }
    }

    private var isMissing: Bool {
        if case .missing = app.folder.state { return true }
        return false
    }
}
