import Foundation
import SwiftData

/// What an import added, for the banner, Settings and the ledger.
public struct ImportOutcome: Equatable, Sendable {
    public var bottleCount = 0
    public var photoCount = 0
    public var openQuestionCount = 0
    /// Numbers of the wines this import created, in file order.
    public var newWineNumbers: [Int] = []
    /// Numbers of existing wines that got a bottle, in file order.
    public var matchedWineNumbers: [Int] = []
}

/// The two halves of an import. `prepare` checks the photos and shrinks them
/// off the main actor; `Cellar.importReview` then writes everything in one
/// save. The caller deletes the originals from `incoming/` only after that
/// save succeeded, so a failed import never loses a photo.
public enum CellarImporter {
    /// The shrunk photos by file name.
    public typealias PreparedPhotos = [String: PhotoShrinker.Result]

    @concurrent
    public static func preparePhotos(for file: ReviewFile, incoming: URL) async throws(ImportError) -> PreparedPhotos {
        var paths: [String: URL] = [:]
        for (index, bottle) in file.bottles.enumerated() {
            for name in bottle.photos {
                let url = incoming.appending(path: name, directoryHint: .notDirectory)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ImportError(String(localized: "Bottle \(index + 1): the photo \(name) isn’t in incoming/."))
                }
                paths[name] = url
            }
        }
        do {
            return try await withThrowingTaskGroup(of: (String, PhotoShrinker.Result).self) { group in
                for (name, url) in paths {
                    group.addTask {
                        let data = try Data(contentsOf: url)
                        do {
                            return (name, try await PhotoShrinker.shrink(data))
                        } catch {
                            throw ImportError(String(localized: "The photo \(name) can’t be read as an image."))
                        }
                    }
                }
                var result: PreparedPhotos = [:]
                for try await (name, photo) in group { result[name] = photo }
                return result
            }
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError(error.localizedDescription)
        }
    }
}

extension Cellar {
    /// Imports a decoded review file with its prepared photos, all or nothing,
    /// and records it in the ledger. Not undoable.
    @discardableResult
    public func importReview(
        _ file: ReviewFile, photos: CellarImporter.PreparedPhotos,
        fileName: String, fileModified: Date?, now: Date = .now
    ) throws(ImportError) -> ImportOutcome {
        do {
            let outcome = try writeReview(file, photos: photos, now: now)
            let record = try ledgerRecord(fileName: fileName)
            record.fileModified = fileModified
            record.statusRaw = ImportStatus.imported.rawValue
            record.message = nil
            record.bottleCount = outcome.bottleCount
            record.photoCount = outcome.photoCount
            record.newWineCount = outcome.newWineNumbers.count
            record.newWineNumbers = outcome.newWineNumbers.map(String.init).joined(separator: ",")
            record.matchedWineNumbers = outcome.matchedWineNumbers.map(String.init).joined(separator: ",")
            record.openQuestionCount = outcome.openQuestionCount
            record.finishedAt = now
            try context.save()
            return outcome
        } catch let error as ImportError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw ImportError(error.localizedDescription)
        }
    }

    /// Records a failed file, so it is only retried by Try Again or a change.
    public func recordImportFailure(fileName: String, fileModified: Date?, message: String, now: Date = .now) {
        context.rollback()
        guard let record = try? ledgerRecord(fileName: fileName) else { return }
        record.fileModified = fileModified
        record.statusRaw = ImportStatus.failed.rawValue
        record.message = message
        record.bottleCount = 0
        record.newWineCount = 0
        record.newWineNumbers = nil
        record.matchedWineNumbers = nil
        record.finishedAt = now
        try? context.save()
    }

    /// Records files that were in the folder before it was chosen as done.
    public func recordSkipped(_ files: [(name: String, modified: Date?)], now: Date = .now) throws {
        let known = Set(try importRecords().map(\.fileName))
        for file in files where !known.contains(file.name) {
            let record = ImportRecord(fileName: file.name, fileModified: file.modified, status: .skipped)
            record.finishedAt = now
            context.insert(record)
        }
        try save()
    }

    public func importRecords() throws -> [ImportRecord] {
        try context.fetch(FetchDescriptor<ImportRecord>())
    }

    /// The last successful import, for Settings and the sidebar.
    public func lastImport() throws -> ImportRecord? {
        let imported = ImportStatus.imported.rawValue
        var descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.statusRaw == imported },
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func ledgerRecord(fileName: String) throws -> ImportRecord {
        var descriptor = FetchDescriptor<ImportRecord>(predicate: #Predicate { $0.fileName == fileName })
        descriptor.fetchLimit = 1
        if let record = try context.fetch(descriptor).first { return record }
        let record = ImportRecord(fileName: fileName, fileModified: nil, status: .imported)
        context.insert(record)
        return record
    }

    private func writeReview(_ file: ReviewFile, photos: CellarImporter.PreparedPhotos, now: Date) throws -> ImportOutcome {
        var outcome = ImportOutcome()
        var nextNumber = try nextWineNumber()
        var bySignature: [String: Wine] = [:]
        for wine in try wines() where bySignature[wine.signature] == nil {
            bySignature[wine.signature] = wine
        }
        var grapes = GrapeIndex(try self.grapes())

        for (index, item) in file.bottles.enumerated() {
            // Grapes first: canonical varieties and the aliases learned from labels.
            let resolved = (item.wine.grapes ?? []).map { grape in
                (grapes.resolve(name: grape.canonical, color: grape.color.rawValue, in: context), grape)
            }
            for (grape, entry) in resolved {
                if let label = entry.labelName, label != entry.canonical {
                    grapes.learnAlias(label, for: grape, in: context)
                }
            }

            let wine: Wine
            var isNew = false
            switch item.dedup {
            case .matchExisting(let number):
                guard let existing = try self.wine(number: number) else {
                    throw ImportError(String(localized: "Bottle \(index + 1): wine \(number) isn’t in the cellar."))
                }
                wine = existing
            case .newWine:
                let signature = Signature.compute(Signature.Input(
                    producer: item.wine.producer, vintage: item.wine.vintage, appellation: item.wine.appellation,
                    vineyard: item.wine.vineyard, name: item.wine.name, qualityLevel: item.wine.qualityLevel,
                    wineType: item.wine.wineType?.rawValue, grapes: resolved.map { $0.0.name }
                ))
                if let match = bySignature[signature] {
                    wine = match
                } else {
                    wine = Wine(number: nextNumber, producer: item.wine.producer)
                    nextNumber += 1
                    context.insert(wine)
                    apply(item.wine, to: wine, signature: signature, now: now)
                    for (position, (grape, entry)) in resolved.enumerated() {
                        let link = WineGrape()
                        link.position = position
                        link.labelName = entry.labelName
                        link.percentage = entry.percentage
                        context.insert(link)
                        link.wine = wine
                        link.grape = grape
                    }
                    bySignature[signature] = wine
                    isNew = true
                }
            }
            if isNew {
                outcome.newWineNumbers.append(wine.number)
            } else if !outcome.newWineNumbers.contains(wine.number) {
                outcome.matchedWineNumbers.append(wine.number)
            }

            let bottle = Bottle()
            context.insert(bottle)
            bottle.wine = wine
            apply(item.bottle, to: bottle, now: now)
            outcome.bottleCount += 1

            let existingPhotos = wine.photos?.count ?? 0
            for (position, name) in item.photos.enumerated() {
                guard let prepared = photos[name] else {
                    throw ImportError(String(localized: "Bottle \(index + 1): the photo \(name) isn’t in incoming/."))
                }
                let photo = Photo(fileName: name)
                photo.imageData = prepared.image
                photo.thumbnailData = prepared.thumbnail
                photo.position = existingPhotos + position
                photo.isPrimary = isNew && position == 0
                photo.createdAt = now
                context.insert(photo)
                photo.wine = wine
                outcome.photoCount += 1
            }
            outcome.openQuestionCount += item.openQuestions?.count ?? 0
            wine.updatedAt = now
        }
        return outcome
    }

    private func apply(_ values: ReviewWine, to wine: Wine, signature: String, now: Date) {
        wine.producer = values.producer
        wine.name = values.name
        wine.vintage = values.vintage
        wine.wineType = values.wineType
        wine.color = values.color
        wine.sweetness = values.sweetness
        wine.qualityLevel = values.qualityLevel
        wine.region = values.region
        wine.country = values.country
        wine.appellation = values.appellation
        wine.vineyard = values.vineyard
        wine.abv = values.abv
        wine.residualSugar = values.residualSugar
        wine.acidity = values.acidity
        wine.drinkFrom = values.drinkFrom
        wine.drinkUntil = values.drinkUntil
        wine.notes = values.description
        wine.foodPairing = values.foodPairing
        wine.servingTemp = values.servingTemp
        wine.closure = values.closure
        wine.isOrganic = values.isOrganic
        wine.isVegan = values.isVegan
        wine.externalLinksJSON = Self.json(values.externalLinks ?? [])
        wine.extraDataJSON = Self.json(values.extraData ?? [:])
        wine.dataSources = values.dataSources ?? [:]
        wine.importConfidence = values.importConfidence
        wine.signature = signature
        wine.createdAt = now
        wine.updatedAt = now
    }

    private func apply(_ values: ReviewBottleData, to bottle: Bottle, now: Date) {
        bottle.sizeML = values.sizeML ?? 750
        bottle.location = values.location
        bottle.purchaseDate = Day.parse(iso: values.purchaseDate)
        bottle.purchasePrice = values.purchasePrice
        bottle.vendor = values.vendor
        bottle.price = values.price
        bottle.status = values.status ?? .inStock
        bottle.drunkOn = Day.parse(iso: values.drunkOn)
        bottle.personalRating = values.personalRating
        bottle.createdAt = now
        bottle.updatedAt = now
    }

    static func json<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder.sorted.encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Canonical grapes by name and aliases by text, growing as a batch adds them.
@MainActor
struct GrapeIndex {
    private var byName: [String: Grape] = [:]
    private var aliases: Set<String> = []

    init(_ grapes: [Grape]) {
        for grape in grapes {
            byName[grape.name] = byName[grape.name] ?? grape
            for alias in grape.aliases ?? [] { aliases.insert(alias.alias) }
        }
    }

    mutating func resolve(name: String, color: String?, in context: ModelContext) -> Grape {
        if let grape = byName[name] { return grape }
        let grape = Grape(name: name, colorRaw: color)
        context.insert(grape)
        byName[name] = grape
        return grape
    }

    mutating func learnAlias(_ alias: String, for grape: Grape, in context: ModelContext) {
        guard !aliases.contains(alias) else { return }
        let entry = GrapeAlias(alias: alias)
        context.insert(entry)
        entry.grape = grape
        aliases.insert(alias)
    }
}
