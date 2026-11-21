import Foundation
import Observation
import SchwipsCore
import SchwipsWebCellar

/// The one-time copy of the web app's cellar: the counts before, progress by
/// wine while the photos shrink, then one save. All or nothing.
@MainActor
@Observable
final class WebCopyModel {
    enum Phase: Equatable {
        case idle
        case copying(done: Int, total: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    func counts(in folder: RuntimeFolder) -> WebCellarReader.Counts? {
        guard let url = folder.webDatabase, folder.hasWebCellar else { return nil }
        return try? WebCellarReader.counts(at: url)
    }

    func reset() {
        phase = .idle
    }

    /// Returns the outcome, or nil after a failure (the phase holds the message).
    func run(folder: RuntimeFolder, cellar: Cellar) async -> WebCopyOutcome? {
        guard let database = folder.webDatabase, let photosFolder = folder.webPhotos else { return nil }
        let web: WebCellar
        do {
            web = try WebCellarReader.read(at: database)
        } catch {
            phase = .failed(error.message)
            return nil
        }
        phase = .copying(done: 0, total: web.wines.count)

        // Photos shrink concurrently; a wine counts as done when its last photo is.
        var remaining = Dictionary(grouping: web.photos, by: \.wineID).mapValues(\.count)
        var done = web.wines.count { remaining[$0.id] == nil }
        phase = .copying(done: done, total: web.wines.count)
        var shrunk: [String: PhotoShrinker.Result] = [:]
        await withTaskGroup(of: (Int, String, PhotoShrinker.Result?).self) { group in
            for photo in web.photos {
                let url = photosFolder.appending(path: photo.path, directoryHint: .notDirectory)
                group.addTask {
                    guard let data = try? Data(contentsOf: url) else { return (photo.wineID, photo.path, nil) }
                    return (photo.wineID, photo.path, try? await PhotoShrinker.shrink(data))
                }
            }
            for await (wineID, path, result) in group {
                if let result { shrunk[path] = result }
                remaining[wineID, default: 1] -= 1
                if remaining[wineID] == 0 {
                    done += 1
                    phase = .copying(done: done, total: web.wines.count)
                }
            }
        }
        do {
            let outcome = try cellar.copyWebCellar(web, photos: shrunk)
            phase = .idle
            return outcome
        } catch {
            phase = .failed(String(localized: "Couldn’t save the cellar: \(error.localizedDescription)"))
            return nil
        }
    }
}

extension Error {
    /// The message to show: a `LocalizedError`'s description, else the system's.
    var message: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }
}
