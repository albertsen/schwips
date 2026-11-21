import Foundation
import Observation
import SwiftData
import SchwipsCore

/// What the banner above the wine list shows.
enum Banner: Equatable {
    case importing(date: Date, bottles: Int, photos: Int)
    case imported(ImportedBanner)
    case failed(fileName: String, date: Date, message: String)
    case copied(WebCopyOutcome)
}

struct ImportedBanner: Equatable {
    var text: String
    var newWineNumbers: [Int]
    /// The Markdown record next to the review file, when it exists.
    var reviewMarkdown: URL?
}

/// The app's shared state: the store, the folder, the inbox, the banner and
/// requests to show a wine (from a link or Show New Wines).
@MainActor
@Observable
final class AppState {
    let container: ModelContainer
    let folder = RuntimeFolder()
    @ObservationIgnored private(set) var inbox: ReviewInbox!
    let webCopy = WebCopyModel()

    var banner: Banner?
    /// Wines an import created during this run, marked NEW.
    var newWineNumbers: Set<Int> = []
    /// A wine to select: switches to All Wines and clears filters and search.
    var requestedWine: Int?
    /// A link to a number the cellar doesn't have.
    var unknownWineNumber: Int?
    var showsWelcome = false

    private static let welcomeDoneKey = "welcomeDone"

    init(container: ModelContainer) {
        self.container = container
        inbox = ReviewInbox(state: self)
        let isEmpty = (try? Cellar(context: container.mainContext).isEmpty()) ?? true
        let done = UserDefaults.standard.bool(forKey: Self.welcomeDoneKey)
        showsWelcome = !done && folder.state == .none && isEmpty
        if folder.url != nil { inbox.start() }
    }

    var cellar: Cellar { Cellar(context: container.mainContext) }

    var isCellarEmpty: Bool { (try? cellar.isEmpty()) ?? true }

    func finishWelcome() {
        UserDefaults.standard.set(true, forKey: Self.welcomeDoneKey)
        showsWelcome = false
    }

    /// A folder was chosen (Welcome or Settings): files already in it count as
    /// imported, then watching starts.
    func folderChosen() {
        inbox.markExistingAsSkipped()
        inbox.start()
    }

    // MARK: Links

    /// `schwips://wine/38`.
    func open(_ url: URL) {
        guard url.scheme == "schwips", url.host() == "wine", let number = Int(url.lastPathComponent) else { return }
        show(wine: number)
    }

    func show(wine number: Int) {
        if (try? cellar.wine(number: number)) == nil {
            unknownWineNumber = number
        } else {
            requestedWine = number
        }
    }

    func activated() {
        folder.refresh()
        if folder.url != nil { inbox.start() }
        inbox.scan()
    }
}
