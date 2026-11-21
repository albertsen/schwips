import Foundation
import Observation

/// The Schwips runtime folder the user chose (`incoming/`, `data/`, `photos/`),
/// kept as a security-scoped bookmark. Access starts once and stays open for
/// the app's lifetime: stopping it would silently end watching.
@MainActor
@Observable
final class RuntimeFolder {
    enum State: Equatable {
        case none
        case found(URL)
        case missing(String)
    }

    enum ChoiceError: LocalizedError {
        case noIncoming
        case notSaved(String)

        var errorDescription: String? {
            switch self {
            case .noIncoming:
                String(localized: "This folder has no incoming/ folder. Choose the runtime folder of your Schwips checkout.")
            case .notSaved(let reason): reason
            }
        }
    }

    private static let bookmarkKey = "runtimeFolderBookmark"
    private static let pathKey = "runtimeFolderPath"

    private(set) var state: State = .none
    private var accessed: URL?

    init() {
        resolve()
    }

    var url: URL? {
        if case .found(let url) = state { return url }
        return nil
    }

    var incoming: URL? { url?.appending(path: "incoming", directoryHint: .isDirectory) }
    var review: URL? { incoming?.appending(path: "review", directoryHint: .isDirectory) }
    var webDatabase: URL? { url?.appending(path: "data/schwips.db", directoryHint: .notDirectory) }
    var webPhotos: URL? { url?.appending(path: "photos", directoryHint: .isDirectory) }

    var hasWebCellar: Bool {
        webDatabase.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    /// The path to show, "~/dev/schwips/runtime", also when the folder is gone.
    var displayPath: String? {
        switch state {
        case .none: nil
        case .found(let url): Self.abbreviate(url.path)
        case .missing(let path): Self.abbreviate(path)
        }
    }

    /// Takes a folder from the open panel. It must hold `incoming/`.
    func choose(_ url: URL) throws(ChoiceError) {
        let started = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        let incoming = url.appending(path: "incoming", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: incoming.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            if started { url.stopAccessingSecurityScopedResource() }
            throw .noIncoming
        }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            UserDefaults.standard.set(url.path, forKey: Self.pathKey)
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            throw .notSaved(error.localizedDescription)
        }
        if let accessed, accessed != url { accessed.stopAccessingSecurityScopedResource() }
        accessed = started ? url : nil
        try? FileManager.default.createDirectory(at: incoming.appending(path: "review"), withIntermediateDirectories: true)
        state = .found(url)
    }

    /// Checks again whether the folder is still there (at activation).
    func refresh() {
        switch state {
        case .found(let url):
            if !FileManager.default.fileExists(atPath: url.appending(path: "incoming").path) {
                state = .missing(url.path)
            }
        case .missing:
            resolve()
        case .none:
            break
        }
    }

    private func resolve() {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            state = .none
            return
        }
        let path = UserDefaults.standard.string(forKey: Self.pathKey) ?? ""
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            state = .missing(path)
            return
        }
        if accessed == nil, url.startAccessingSecurityScopedResource() { accessed = url }
        guard FileManager.default.fileExists(atPath: url.appending(path: "incoming").path) else {
            state = .missing(url.path)
            return
        }
        if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: Self.bookmarkKey)
        }
        state = .found(url)
    }

    /// "/Users/x/dev/schwips/runtime" → "~/dev/schwips/runtime". The sandbox's
    /// home is the container, so the real home comes from the password database.
    static func abbreviate(_ path: String) -> String {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return path }
        let home = String(cString: directory)
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
