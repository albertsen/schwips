import Foundation

extension Wine {
    public var wineType: WineType? {
        get { wineTypeRaw.flatMap(WineType.init(rawValue:)) }
        set { wineTypeRaw = newValue?.rawValue }
    }

    public var color: WineColor? {
        get { colorRaw.flatMap(WineColor.init(rawValue:)) }
        set { colorRaw = newValue?.rawValue }
    }

    public var sweetness: Sweetness? {
        get { sweetnessRaw.flatMap(Sweetness.init(rawValue:)) }
        set { sweetnessRaw = newValue?.rawValue }
    }

    public var closure: Closure? {
        get { closureRaw.flatMap(Closure.init(rawValue:)) }
        set { closureRaw = newValue?.rawValue }
    }

    public var allBottles: [Bottle] { bottles ?? [] }

    public var inStockBottles: [Bottle] {
        allBottles.filter { $0.status == .inStock }.sorted { $0.createdAt < $1.createdAt }
    }

    public var drunkBottles: [Bottle] {
        allBottles.filter { $0.status == .consumed }
            .sorted { ($0.drunkOn ?? .distantPast) < ($1.drunkOn ?? .distantPast) }
    }

    public var inStockCount: Int { allBottles.count { $0.status == .inStock } }

    /// The estimated price: the lowest bottle price, since every bottle of a
    /// wine carries the same one.
    public var price: Double? { allBottles.compactMap(\.price).min() }

    /// The grapes in label order.
    public var orderedGrapes: [WineGrape] { (grapes ?? []).sorted { $0.position < $1.position } }

    /// The names to show: as printed on the label, else the canonical name.
    public var grapeDisplayNames: [String] {
        orderedGrapes.compactMap { $0.labelName ?? $0.grape?.name }
    }

    /// The canonical names, for the match key and the Grape filter.
    public var canonicalGrapeNames: [String] { orderedGrapes.compactMap { $0.grape?.name } }

    /// The photos, primary first.
    public var orderedPhotos: [Photo] {
        (photos ?? []).sorted {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary }
            return $0.position < $1.position
        }
    }

    public var dataSources: [String: Provenance] {
        get {
            guard let data = dataSourcesJSON?.data(using: .utf8),
                  let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return raw.compactMapValues(Provenance.init(rawValue:))
        }
        set {
            let raw = newValue.mapValues(\.rawValue)
            dataSourcesJSON = (try? JSONEncoder.sorted.encode(raw)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    public var externalLinks: [String] {
        guard let data = externalLinksJSON?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Ready when the drinking window contains `year`.
    public func isReady(in year: Int) -> Bool {
        guard let from = drinkFrom, let until = drinkUntil else { return false }
        return from <= year && year <= until
    }

    public func isNotYetReady(in year: Int) -> Bool {
        guard let from = drinkFrom else { return false }
        return year < from
    }

    /// The fields the match key is computed from.
    public var signatureInput: Signature.Input {
        Signature.Input(
            producer: producer, vintage: vintage, appellation: appellation, vineyard: vineyard,
            name: name, qualityLevel: qualityLevel, wineType: wineTypeRaw, grapes: canonicalGrapeNames
        )
    }
}

extension Bottle {
    public var status: BottleStatus {
        get { BottleStatus(rawValue: statusRaw) ?? .inStock }
        set { statusRaw = newValue.rawValue }
    }
}

extension Grape {
    public var color: GrapeColor? { colorRaw.flatMap(GrapeColor.init(rawValue:)) }
}

extension ImportRecord {
    public var status: ImportStatus { ImportStatus(rawValue: statusRaw) ?? .imported }

    public var newNumbers: [Int] { Self.numbers(newWineNumbers) }
    public var matchedNumbers: [Int] { Self.numbers(matchedWineNumbers) }

    static func numbers(_ text: String?) -> [Int] {
        (text ?? "").split(separator: ",").compactMap { Int($0) }
    }
}

extension JSONEncoder {
    /// Sorted keys, so the stored JSON is stable and diffable.
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
