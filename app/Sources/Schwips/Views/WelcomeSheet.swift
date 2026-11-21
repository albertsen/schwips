import SwiftUI
import UniformTypeIdentifiers
import SchwipsCore
import SchwipsWebCellar

/// First launch: choose the runtime folder; when the web app's cellar is in
/// it and Schwips is empty, copy it or start empty. Also opened from Settings
/// (`Copy Cellar from Web App…`) and from the empty cellar.
struct WelcomeSheet: View {
    @Environment(AppState.self) private var app
    @State private var choosing = false
    @State private var folderError: String?
    @State private var counts: WebCellarReader.Counts?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch app.webCopy.phase {
            case .copying(let done, let total):
                copying(done: done, total: total)
            case .failed(let message):
                failed(message)
            case .idle:
                welcome
            }
        }
        .padding(24)
        .frame(width: 460)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do {
                try app.folder.choose(url)
                folderError = nil
                app.folderChosen()
                refreshCounts()
            } catch {
                folderError = error.message
            }
        }
        .onAppear(perform: refreshCounts)
        .interactiveDismissDisabled(isCopying)
    }

    private var isCopying: Bool {
        if case .copying = app.webCopy.phase { return true }
        return false
    }

    private func refreshCounts() {
        counts = app.isCellarEmpty ? app.webCopy.counts(in: app.folder) : nil
    }

    @ViewBuilder private var welcome: some View {
        Image(systemName: "wineglass").font(.system(size: 36)).foregroundStyle(Theme.accent)
        Text("Welcome to Schwips").font(.system(.title2, design: .serif)).fontWeight(.semibold)
        Text("Schwips adds new bottles from the review files that /import-wines writes. Choose your Schwips runtime folder, the one that holds incoming/ and data/.")
            .fixedSize(horizontal: false, vertical: true)
        HStack {
            Text(verbatim: app.folder.displayPath ?? String(localized: "No folder chosen"))
                .foregroundStyle(app.folder.url == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).strokeBorder(folderError == nil ? AnyShapeStyle(.separator) : AnyShapeStyle(Theme.error)))
            Button("Choose Folder…") { choosing = true }
        }
        if let folderError {
            Text(verbatim: folderError).font(.callout).foregroundStyle(Theme.error)
        }
        if let counts {
            VStack(alignment: .leading, spacing: 4) {
                Text("The web app’s cellar is in this folder").fontWeight(.semibold)
                Text("\(String(localized: "\(counts.wines) wines")) · \(WineText.bottles(counts.bottles)) · \(String(localized: "\(counts.photos) photos"))")
                    .foregroundStyle(.secondary)
                Text("Copying leaves the web app’s files as they are.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        }
        HStack {
            Spacer()
            if app.folder.url == nil {
                Button("Later") { finish(seed: true) }
                    .keyboardShortcut(.cancelAction)
                Button("Continue") {}.disabled(true)
            } else if counts != nil {
                Button("Start Empty") { finish(seed: true) }
                Button("Copy Cellar") { copy() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else {
                Button("Continue") { finish(seed: true) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func copying(done: Int, total: Int) -> some View {
        Text("Copying your cellar…").font(.headline)
        ProgressView(value: Double(done), total: Double(max(total, 1)))
            .tint(Theme.accent)
        Text("\(done) of \(total) wines").foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func failed(_ message: String) -> some View {
        Text("Couldn’t copy the cellar").font(.headline)
        Text(verbatim: message).fixedSize(horizontal: false, vertical: true)
        Text("Nothing was copied.").foregroundStyle(.secondary)
        HStack {
            Spacer()
            Button("Start Empty") {
                app.webCopy.reset()
                finish(seed: true)
            }
            Button("Try Again") { copy() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    private func copy() {
        Task {
            if let outcome = await app.webCopy.run(folder: app.folder, cellar: app.cellar) {
                app.banner = .copied(outcome)
                finish(seed: false)
            }
        }
    }

    /// Start Empty, Continue and Later: an empty cellar gets the common grapes.
    private func finish(seed: Bool) {
        if seed, app.isCellarEmpty, (try? app.cellar.grapes().isEmpty) == true {
            try? app.cellar.seedGrapes()
        }
        app.finishWelcome()
    }
}
