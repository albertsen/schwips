import Foundation

/// A review file the importer refuses. The message names the first problem in
/// the app's language ("Bottle 2: “vintage” must be a whole number.").
public struct ImportError: LocalizedError, Equatable, Sendable {
    public let message: String
    /// The file is not complete JSON: it may still be being written.
    public let isIncompleteJSON: Bool
    public var errorDescription: String? { message }

    public init(_ message: String, isIncompleteJSON: Bool = false) {
        self.message = message
        self.isIncompleteJSON = isIncompleteJSON
    }
}

public enum ReviewValidation {
    /// Decodes and checks a review file. Photos and wine numbers are checked by
    /// the importer, which knows the folder and the cellar.
    public static func decode(_ data: Data) throws(ImportError) -> ReviewFile {
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError(String(localized: "The file isn’t valid JSON."), isIncompleteJSON: true)
        }
        let file: ReviewFile
        do {
            file = try JSONDecoder().decode(ReviewFile.self, from: data)
        } catch let error as DecodingError {
            throw ImportError(message(for: error))
        } catch {
            throw ImportError(error.localizedDescription)
        }
        try check(file)
        return file
    }

    static func check(_ file: ReviewFile) throws(ImportError) {
        guard !file.bottles.isEmpty else {
            throw ImportError(String(localized: "The file has no bottles."))
        }
        for (index, bottle) in file.bottles.enumerated() {
            let number = index + 1
            func fail(_ key: String, _ rule: String) -> ImportError {
                ImportError(String(localized: "Bottle \(number): “\(key)” \(rule)"))
            }
            if bottle.wine.producer.trimmingCharacters(in: .whitespaces).isEmpty {
                throw fail("producer", String(localized: "must not be empty."))
            }
            if !(0...1).contains(bottle.confidence) {
                throw fail("confidence", String(localized: "must be between 0 and 1."))
            }
            if !(0...1).contains(bottle.wine.importConfidence) {
                throw fail("import_confidence", String(localized: "must be between 0 and 1."))
            }
            if let rating = bottle.bottle.personalRating, !(1...5).contains(rating) {
                throw fail("personal_rating", String(localized: "must be between 1 and 5."))
            }
            for grape in bottle.wine.grapes ?? [] where grape.canonical.trimmingCharacters(in: .whitespaces).isEmpty {
                throw fail("canonical", String(localized: "must not be empty."))
            }
        }
    }

    /// "Bottle 2: “vintage” must be a whole number." from a decoding error's path.
    static func message(for error: DecodingError) -> String {
        let path: [any CodingKey]
        let rule: String
        switch error {
        case .typeMismatch(let type, let context):
            path = context.codingPath
            rule = typeRule(type)
        case .valueNotFound(let type, let context):
            path = context.codingPath
            rule = type == String.self
                ? String(localized: "must not be empty.")
                : typeRule(type)
        case .keyNotFound(let key, let context):
            path = context.codingPath + [key]
            rule = String(localized: "is missing.")
        case .dataCorrupted(let context):
            path = context.codingPath
            rule = String(localized: "has a value that isn’t allowed.")
        @unknown default:
            return error.localizedDescription
        }
        let key = path.last { $0.intValue == nil }?.stringValue ?? "?"
        if path.first?.stringValue == "bottles", path.count > 1, let index = path[1].intValue {
            return String(localized: "Bottle \(index + 1): “\(key)” \(rule)")
        }
        return String(localized: "“\(key)” \(rule)")
    }

    private static func typeRule(_ type: Any.Type) -> String {
        if type == Int.self { return String(localized: "must be a whole number.") }
        if type == Double.self { return String(localized: "must be a number.") }
        if type == Bool.self { return String(localized: "must be true or false.") }
        if type == String.self { return String(localized: "must be text.") }
        if String(describing: type).hasPrefix("Array") { return String(localized: "must be a list.") }
        return String(localized: "has the wrong type.")
    }
}
