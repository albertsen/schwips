import Foundation
import SwiftData
import SchwipsCore

/// Watches `incoming/review/` and imports each new review file once, oldest
/// first. A file that isn't complete JSON yet and changed in the last 10 s is
/// retried every 2 s, three times, before it counts as failed: `/import-wines`
/// may still be writing it.
@MainActor
final class ReviewInbox {
    private unowned let state: AppState
    private var source: DispatchSourceFileSystemObject?
    private var watched: URL?
    private var debounce: Task<Void, Never>?
    private var isImporting = false
    private var rescanRequested = false
    private var retries: [String: Int] = [:]

    init(state: AppState) {
        self.state = state
    }

    /// Starts watching the folder's `incoming/review/` and scans it once.
    func start() {
        guard let review = state.folder.review else { return }
        if watched != review {
            source?.cancel()
            source = nil
            watched = review
            let descriptor = open(review.path, O_EVTONLY)
            if descriptor >= 0 {
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main
                )
                source.setEventHandler { [weak self] in
                    MainActor.assumeIsolated { self?.scheduleScan() }
                }
                source.setCancelHandler { close(descriptor) }
                source.resume()
                self.source = source
            }
        }
        scan()
    }

    private func scheduleScan(after delay: Duration = .seconds(1)) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    /// The review files in the folder, oldest first.
    private func files() -> [(url: URL, modified: Date)] {
        guard let review = state.folder.review,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: review, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
              ) else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "json" }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return (url, modified)
            }
            .sorted { $0.modified < $1.modified }
    }

    /// Files already there when the folder is chosen were imported by the web app.
    func markExistingAsSkipped() {
        try? state.cellar.recordSkipped(files().map { ($0.url.lastPathComponent, $0.modified) })
    }

    /// Imports every file that is new, or failed and changed since.
    func scan() {
        guard !isImporting else {
            rescanRequested = true
            return
        }
        guard let records = try? state.cellar.importRecords() else { return }
        let known = Dictionary(records.map { ($0.fileName, $0) }, uniquingKeysWith: { first, _ in first })
        let pending = files().filter { file in
            guard let record = known[file.url.lastPathComponent] else { return true }
            return record.status == .failed && !Self.sameDate(record.fileModified, file.modified)
        }
        guard let next = pending.first else { return }
        Task { await importFile(next.url, modified: next.modified) }
    }

    /// Try Again on a failed file.
    func retry(fileName: String) {
        guard let file = files().first(where: { $0.url.lastPathComponent == fileName }), !isImporting else { return }
        Task { await importFile(file.url, modified: file.modified) }
    }

    private func importFile(_ url: URL, modified: Date) async {
        guard !isImporting, let incoming = state.folder.incoming else { return }
        isImporting = true
        defer {
            isImporting = false
            let again = rescanRequested
            rescanRequested = false
            if again { scan() } else { scheduleScan(after: .milliseconds(200)) }
        }
        let name = url.lastPathComponent
        let file: ReviewFile
        do {
            file = try ReviewValidation.decode(try Data(contentsOf: url))
        } catch let error as ImportError {
            if error.isIncompleteJSON, Date.now.timeIntervalSince(modified) < 10, retries[name, default: 0] < 3 {
                retries[name, default: 0] += 1
                scheduleScan(after: .seconds(2))
                return
            }
            fail(name, modified: modified, message: error.message)
            return
        } catch {
            fail(name, modified: modified, message: error.localizedDescription)
            return
        }
        retries[name] = nil
        state.banner = .importing(
            date: modified, bottles: file.bottles.count, photos: file.bottles.reduce(0) { $0 + $1.photos.count }
        )
        do {
            let photos = try await CellarImporter.preparePhotos(for: file, incoming: incoming)
            let outcome = try state.cellar.importReview(file, photos: photos, fileName: name, fileModified: modified)
            // Only now that the save succeeded do the originals go.
            for bottle in file.bottles {
                for photo in bottle.photos {
                    try? FileManager.default.removeItem(at: incoming.appending(path: photo, directoryHint: .notDirectory))
                }
            }
            state.newWineNumbers.formUnion(outcome.newWineNumbers)
            let markdown = url.deletingPathExtension().appendingPathExtension("md")
            state.banner = .imported(ImportedBanner(
                text: ImportText.summary(outcome, cellar: state.cellar),
                newWineNumbers: outcome.newWineNumbers,
                reviewMarkdown: FileManager.default.fileExists(atPath: markdown.path) ? markdown : nil
            ))
        } catch {
            fail(name, modified: modified, message: error.message)
        }
    }

    private func fail(_ name: String, modified: Date, message: String) {
        state.cellar.recordImportFailure(fileName: name, fileModified: modified, message: message)
        state.banner = .failed(fileName: name, date: modified, message: message)
    }

    private static func sameDate(_ a: Date?, _ b: Date) -> Bool {
        guard let a else { return false }
        return abs(a.timeIntervalSince(b)) < 0.001
    }
}

/// The banner's sentence for an import.
enum ImportText {
    @MainActor
    static func summary(_ outcome: ImportOutcome, cellar: Cellar) -> String {
        var parts: [String] = []
        if !outcome.newWineNumbers.isEmpty {
            parts.append(String(localized: "\(outcome.newWineNumbers.count) new wines"))
        }
        let matched = outcome.bottleCount - outcome.newWineNumbers.count
        let matchedWines = Set(outcome.matchedWineNumbers)
        if matched > 0 {
            if matchedWines.count == 1, let number = matchedWines.first, let wine = try? cellar.wine(number: number) {
                parts.append(String(localized: "\(matched) more bottles of \(WineText.fullName(wine))"))
            } else {
                parts.append(String(localized: "\(matched) more bottles of wines you have"))
            }
        }
        var text = String(localized: "Imported \(outcome.bottleCount) bottles: \(parts.formatted(.list(type: .and))).")
        if outcome.openQuestionCount > 0 {
            text += " " + String(localized: "\(outcome.openQuestionCount) open questions.")
        }
        return text
    }
}
